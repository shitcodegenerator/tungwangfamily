class_name TownProp
extends Node2D
## 城鎮道具：一張貼圖（底部中央為原點，便於 Y-sort）加上可選的 StaticBody2D 碰撞。
## Phase 2 增加純視覺的生命感選項：多幀循環（燈籠、旗幟）、水平飄移（雲霧）、夜間光暈（燈籠）。
## Phase 5 增加大型 props 的接地選項：foot_x（接地點距貼圖左緣的像素，預設貼圖中央）、
## foot_inset（接地線距貼圖底緣的像素，例如拱門的石板地面）、glow_x（光暈中心距貼圖左緣）、
## collision_boxes（多個碰撞盒 [寬, 高, dx, dy]，例如拱門的兩隻腳）。
## 這些選項只改變 Sprite2D 子節點，不移動道具本體、碰撞盒或 Y-sort 基準。
## Phase 6 增加 shader（assets/shaders/<名稱>.gdshader 套在 Sprite2D 的 ShaderMaterial，只作環境氣氛：
## 不套在碰撞、互動區或光暈；載入失敗只警告，道具照常運作）。

const GLOW_TEXTURE := preload("res://assets/effects/lamp_glow.png")
const SHADER_DIR := "res://assets/shaders/"
## 光暈隨燈籠幀數微微呼吸，讓夜晚的燈光不會死板。
const GLOW_FLICKER: Array[float] = [1.0, 0.85, 1.1, 0.92]

@onready var sprite: Sprite2D = $Sprite2D
@onready var body: StaticBody2D = $StaticBody2D
@onready var shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

var frame_count: int = 1
var frames_per_second: float = 6.0
var drift_amplitude: float = 0.0
var drift_period: float = 8.0
var glow: Sprite2D
## 額外碰撞盒（collision_boxes）佔用的矩形（世界座標），供 TownWorld 登記封鎖格。
var extra_collision_rects: Array[Rect2] = []
var _time: float = 0.0
var _drift_phase: float = 0.0
var _glow_strength: float = 0.0
var _shader_name: String = ""


## collision_size 為 Vector2.ZERO 且沒有 collision_boxes 時不建立碰撞（純裝飾）。
## options：frames（橫向幀數）、fps、drift = [振幅 px, 週期秒]、glow = true、glow_y（光暈距離貼圖頂端的像素）、
## glow_x（光暈中心距貼圖左緣的像素，預設接地點）、foot_x、foot_inset、collision_boxes。
func setup(texture: Texture2D, collision_size: Vector2, alpha: float = 1.0, z_bias: int = 0, options: Dictionary = {}) -> void:
	frame_count = maxi(1, int(options.get("frames", 1)))
	frames_per_second = float(options.get("fps", 6.0))
	sprite.texture = texture
	sprite.centered = false
	sprite.hframes = frame_count
	var frame_width := float(texture.get_width()) / float(frame_count)
	var height := float(texture.get_height())
	var foot_x := float(options.get("foot_x", frame_width / 2.0))
	var foot_inset := float(options.get("foot_inset", 0.0))
	sprite.offset = sprite_offset_for(frame_width, height, foot_x, foot_inset)
	sprite.modulate.a = alpha
	z_index = z_bias
	var drift: Variant = options.get("drift")
	if typeof(drift) == TYPE_ARRAY and drift.size() == 2:
		drift_amplitude = float(drift[0])
		drift_period = maxf(0.1, float(drift[1]))
		_drift_phase = fmod(position.x * 0.013 + position.y * 0.007, TAU)
	if options.has("shader"):
		_apply_shader(String(options["shader"]))
	if bool(options.get("glow", false)):
		var glow_offset := Vector2(float(options.get("glow_x", foot_x)) - foot_x, -(height - float(options.get("glow_y", 14.0))) + foot_inset)
		_add_glow(glow_offset)
	set_process(frame_count > 1 or drift_amplitude > 0.0)
	var boxes := collision_boxes_from(options.get("collision_boxes"))
	if collision_size == Vector2.ZERO and boxes.is_empty():
		body.queue_free()
		return
	if collision_size == Vector2.ZERO:
		shape.queue_free()
	else:
		var rect := RectangleShape2D.new()
		rect.size = collision_size
		shape.shape = rect
		shape.position = Vector2(0.0, -collision_size.y / 2.0)
	for box: Rect2 in boxes:
		var extra := CollisionShape2D.new()
		var extra_rect := RectangleShape2D.new()
		extra_rect.size = box.size
		extra.shape = extra_rect
		extra.position = box.get_center()
		body.add_child(extra)
		extra_collision_rects.append(Rect2(position + box.position, box.size))


func _add_glow(offset: Vector2) -> void:
	glow = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = GLOW_TEXTURE
	glow.centered = true
	glow.position = offset
	glow.z_index = 1
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.visible = false
	add_child(glow)


func _apply_shader(shader_name: String) -> void:
	var path := SHADER_DIR + shader_name + ".gdshader"
	if not ResourceLoader.exists(path):
		push_warning("找不到道具 Shader：%s（略過，道具照常顯示）" % path)
		return
	var shader: Shader = load(path)
	if shader == null:
		push_warning("道具 Shader 無法載入：%s" % path)
		return
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	_shader_name = shader_name


func has_shader() -> bool:
	return sprite.material is ShaderMaterial


func shader_name() -> String:
	return _shader_name


## 事件執行器用：暫時改 Shader uniform（例如舷窗 event_pulse）。沒有 Shader 時回傳 null／不做事。
func get_shader_param(parameter: String) -> Variant:
	if not has_shader():
		return null
	var material := sprite.material as ShaderMaterial
	var value: Variant = material.get_shader_parameter(parameter)
	if value == null:
		# 尚未覆寫過的 uniform：從 Shader 原始碼讀宣告的預設值（headless 沒有 RenderingServer 可查）。
		value = shader_default(material.shader.code, parameter)
	return value


func set_shader_param(parameter: String, value: Variant) -> void:
	if not has_shader():
		return
	(sprite.material as ShaderMaterial).set_shader_parameter(parameter, value)


func has_glow() -> bool:
	return glow != null


## 0 = 熄滅（白天），1 = 全亮（夜晚）。
func set_glow_strength(strength: float) -> void:
	_glow_strength = clampf(strength, 0.0, 1.0)
	if glow == null:
		return
	glow.visible = _glow_strength > 0.0
	glow.modulate.a = _glow_strength


func _process(delta: float) -> void:
	_time += delta
	if frame_count > 1:
		var frame := int(_time * frames_per_second) % frame_count
		sprite.frame = frame
		if glow != null and glow.visible:
			glow.modulate.a = _glow_strength * GLOW_FLICKER[frame % GLOW_FLICKER.size()]
	if drift_amplitude > 0.0:
		# 只位移 Sprite2D，道具本體座標不變，因此 Y-sort 與（若有）碰撞都不受影響。
		sprite.position.x = roundf(sin(_time * TAU / drift_period + _drift_phase) * drift_amplitude)


## 純函式：從 Shader 原始碼找 `uniform float <name> ... = <值>;` 的預設值；找不到或不是 float 回傳 null。
static func shader_default(code: String, parameter: String) -> Variant:
	var pattern := RegEx.create_from_string("uniform\\s+float\\s+%s\\b[^;=]*=\\s*([-+0-9.eE]+)\\s*;" % parameter)
	var found := pattern.search(code)
	return float(found.get_string(1)) if found != null else null


## 純函式：貼圖左上角相對於原點（接地點）的位移。接地點在貼圖的 (foot_x, height - foot_inset)。
static func sprite_offset_for(frame_width: float, height: float, foot_x: float, foot_inset: float) -> Vector2:
	return Vector2(-foot_x, -height + foot_inset)


## 純函式：collision_boxes JSON（[[寬, 高, dx, dy], ...]，dx/dy 為盒子底部中央相對原點的位移）→ 相對原點的 Rect2。
static func collision_boxes_from(raw: Variant) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for box: Variant in raw:
		if typeof(box) != TYPE_ARRAY or box.size() < 2:
			continue
		var size := Vector2(float(box[0]), float(box[1]))
		var dx := float(box[2]) if box.size() > 2 else 0.0
		var dy := float(box[3]) if box.size() > 3 else 0.0
		result.append(Rect2(Vector2(dx - size.x / 2.0, dy - size.y), size))
	return result


## 純函式：目前時間對應的幀索引（供測試）。
static func frame_at(time: float, fps: float, frames: int) -> int:
	if frames <= 1:
		return 0
	return int(time * fps) % frames
