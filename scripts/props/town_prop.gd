class_name TownProp
extends Node2D
## 城鎮道具：一張貼圖（底部中央為原點，便於 Y-sort）加上可選的 StaticBody2D 碰撞。
## Phase 2 增加純視覺的生命感選項：多幀循環（燈籠、旗幟）、水平飄移（雲霧）、夜間光暈（燈籠）。
## 這些選項只改變 Sprite2D 子節點，不移動道具本體、碰撞盒或 Y-sort 基準。

const GLOW_TEXTURE := preload("res://assets/effects/lamp_glow.png")
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
var _time: float = 0.0
var _drift_phase: float = 0.0
var _glow_strength: float = 0.0


## collision_size 為 Vector2.ZERO 時不建立碰撞（純裝飾）。
## options：frames（橫向幀數）、fps、drift = [振幅 px, 週期秒]、glow = true、glow_y（光暈距離貼圖頂端的像素）。
func setup(texture: Texture2D, collision_size: Vector2, alpha: float = 1.0, z_bias: int = 0, options: Dictionary = {}) -> void:
	frame_count = maxi(1, int(options.get("frames", 1)))
	frames_per_second = float(options.get("fps", 6.0))
	sprite.texture = texture
	sprite.centered = false
	sprite.hframes = frame_count
	var frame_width := float(texture.get_width()) / float(frame_count)
	sprite.offset = Vector2(-frame_width / 2.0, -float(texture.get_height()))
	sprite.modulate.a = alpha
	z_index = z_bias
	var drift: Variant = options.get("drift")
	if typeof(drift) == TYPE_ARRAY and drift.size() == 2:
		drift_amplitude = float(drift[0])
		drift_period = maxf(0.1, float(drift[1]))
		_drift_phase = fmod(position.x * 0.013 + position.y * 0.007, TAU)
	if bool(options.get("glow", false)):
		_add_glow(float(texture.get_height()) - float(options.get("glow_y", 14.0)))
	set_process(frame_count > 1 or drift_amplitude > 0.0)
	if collision_size == Vector2.ZERO:
		body.queue_free()
		return
	var rect := RectangleShape2D.new()
	rect.size = collision_size
	shape.shape = rect
	shape.position = Vector2(0.0, -collision_size.y / 2.0)


func _add_glow(height_above_base: float) -> void:
	glow = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = GLOW_TEXTURE
	glow.centered = true
	glow.position = Vector2(0.0, -height_above_base)
	glow.z_index = 1
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.visible = false
	add_child(glow)


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


## 純函式：目前時間對應的幀索引（供測試）。
static func frame_at(time: float, fps: float, frames: int) -> int:
	if frames <= 1:
		return 0
	return int(time * fps) % frames
