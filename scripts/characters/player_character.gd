class_name PlayableCharacter
extends CharacterBody2D
## 單一角色：輸入、移動、方向與動畫。被操控時讀取玩家輸入；否則交由 Follower 子節點決定速度。
## 站立微晃動只移動 VisualRoot，CharacterBody2D 與碰撞盒維持不動。

const FRAME_SIZE := Vector2i(48, 64)
const FRAMES_PER_DIRECTION := 4
## 精靈表若有 5 欄（Phase 2 正式素材）：第 0 欄為站立、第 1～4 欄為行走；4 欄（Phase 1 合成）：第 0 欄兼作站立。
const IDLE_SHEET_COLUMNS := 5
const DIRECTION_ROWS: Array[StringName] = [&"down", &"left", &"right", &"up"]
const WALK_FPS := 8.0
const BOB_PERIOD := 0.8
const BOB_OFFSETS: Array[float] = [0.0, -1.0, 0.0, 1.0]
## 精靈原點對齊腳底：單格 48×64，腳底位於 y=62。
const SPRITE_OFFSET := Vector2(-24.0, -62.0)

@export var data: CharacterData

var facing: Vector2i = Vector2i.DOWN
var is_controlled: bool = false
## 對話等情境下鎖定輸入：被操控者不讀取移動輸入，但仍會被物理與跟隨鏈正常處理。
var input_locked: bool = false
var trail: PartyTrail = PartyTrail.new()
var _bob_time: float = 0.0
var _is_moving: bool = false

## 面前的 Area2D 進入／離開可互動物件（第 3 層 Interactable）時發出。InteractionController 以輪詢為主，這兩個 signal 供除錯與擴充。
signal interactable_entered(node: Node2D)
signal interactable_exited(node: Node2D)

## 互動偵測區相對於角色的距離（沿面向方向）。
const INTERACTION_REACH := 18.0

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var follower: FollowerCharacter = $Follower
@onready var interaction_origin: Marker2D = $InteractionOrigin
@onready var interaction_area: Area2D = $InteractionOrigin/InteractionArea


func _ready() -> void:
	interaction_area.area_entered.connect(func(area: Area2D) -> void: interactable_entered.emit(area))
	interaction_area.area_exited.connect(func(area: Area2D) -> void: interactable_exited.emit(area))
	interaction_area.body_entered.connect(func(body: Node2D) -> void: interactable_entered.emit(body))
	interaction_area.body_exited.connect(func(body: Node2D) -> void: interactable_exited.emit(body))
	if data == null:
		push_error("PlayableCharacter 缺少 CharacterData：%s" % name)
		return
	apply_data(data)


func apply_data(character_data: CharacterData) -> void:
	data = character_data
	name = String(data.id) if not String(data.id).is_empty() else name
	sprite.sprite_frames = build_sprite_frames(data.sprite_sheet)
	sprite.centered = false
	sprite.offset = SPRITE_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rect := RectangleShape2D.new()
	rect.size = data.collision_size
	collision_shape.shape = rect
	collision_shape.position = Vector2(0.0, -data.collision_size.y / 2.0)
	_bob_time = data.bob_phase
	_play_animation()


func set_controlled(controlled: bool) -> void:
	is_controlled = controlled
	follower.active = not controlled


func _physics_process(delta: float) -> void:
	if data == null:
		return
	var desired_velocity := Vector2.ZERO
	if is_controlled:
		desired_velocity = Vector2.ZERO if input_locked else read_input_direction() * data.walk_speed
	else:
		desired_velocity = follower.compute_velocity(data.walk_speed, delta)
	velocity = desired_velocity
	move_and_slide()
	trail.record(global_position)
	_is_moving = desired_velocity.length_squared() > 0.01
	if _is_moving:
		facing = direction_to_facing(desired_velocity, facing)
	_update_interaction_area()
	_play_animation()


## 互動偵測區永遠位於角色面向的前方；只有被操控者需要偵測。
func _update_interaction_area() -> void:
	interaction_area.position = Vector2(facing) * INTERACTION_REACH
	interaction_area.monitoring = is_controlled


func _process(delta: float) -> void:
	if _is_moving:
		_bob_time = data.bob_phase if data != null else 0.0
		visual_root.position.y = 0.0
		return
	_bob_time += delta
	var phase := fmod(_bob_time, BOB_PERIOD) / BOB_PERIOD
	var index := clampi(int(phase * BOB_OFFSETS.size()), 0, BOB_OFFSETS.size() - 1)
	visual_root.position.y = BOB_OFFSETS[index]


func read_input_direction() -> Vector2:
	var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if raw.length_squared() < 0.04:
		return Vector2.ZERO
	return raw.normalized()


func clear_trail() -> void:
	trail.clear()


func trail_point_behind(distance: float) -> Vector2:
	return trail.point_behind(global_position, distance)


func facing_name() -> StringName:
	match facing:
		Vector2i.LEFT:
			return &"left"
		Vector2i.RIGHT:
			return &"right"
		Vector2i.UP:
			return &"up"
		_:
			return &"down"


func _play_animation() -> void:
	var animation := StringName(("walk_" if _is_moving else "idle_") + String(facing_name()))
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return
	if sprite.animation != animation:
		sprite.play(animation)
	elif not sprite.is_playing():
		sprite.play(animation)


## 由移動向量決定四方向面向；水平分量較大時取左右，否則取上下。零向量保留原方向。
static func direction_to_facing(direction: Vector2, previous: Vector2i) -> Vector2i:
	if direction.length_squared() < 0.0001:
		return previous
	if absf(direction.x) > absf(direction.y):
		return Vector2i.RIGHT if direction.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if direction.y > 0.0 else Vector2i.UP


## 由 Sprite Sheet 建立 idle/walk × 四方向的 SpriteFrames。
## 240×256（5 欄）：第 0 欄站立、第 1～4 欄行走；192×256（4 欄）：第 0 欄同時作為站立。
static func build_sprite_frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var columns := int(sheet.get_width()) / FRAME_SIZE.x
	var walk_start := 1 if columns >= IDLE_SHEET_COLUMNS else 0
	for row: int in range(DIRECTION_ROWS.size()):
		var direction_name := DIRECTION_ROWS[row]
		var walk_name := StringName("walk_" + String(direction_name))
		var idle_name := StringName("idle_" + String(direction_name))
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WALK_FPS)
		frames.set_animation_loop(walk_name, true)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, _frame_texture(sheet, 0, row))
		for column: int in range(FRAMES_PER_DIRECTION):
			frames.add_frame(walk_name, _frame_texture(sheet, walk_start + column, row))
	return frames


static func _frame_texture(sheet: Texture2D, column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(Vector2(column * FRAME_SIZE.x, row * FRAME_SIZE.y), Vector2(FRAME_SIZE))
	return atlas
