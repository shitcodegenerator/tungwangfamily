class_name PetFollower
extends CharacterBody2D
## 非戰鬥型寵物（CC）：跟在四人隊伍最後一位後面，沿用 FollowerCharacter 的軌跡跟隨；不在可切換的 party order 裡，
## 不撿東西、不投擲、不受傷。站著沒事時偶爾做小動作（跳一下、左右張望）。掛在 PartyController 底下，換場景不會遺失。

const SPRITE_OFFSET := PlayableCharacter.SPRITE_OFFSET
const HOP_HEIGHT := 5.0
const HOP_SECONDS := 0.35
const IDLE_ACTION_MIN := 3.0
const IDLE_ACTION_MAX := 6.5

@export var data: CharacterData

var facing: Vector2i = Vector2i.DOWN
var trail: PartyTrail = PartyTrail.new()
var idle_actions_done: int = 0
var _is_moving: bool = false
var _next_action: float = 4.0
var _hop_time: float = -1.0
var _rng := RandomNumberGenerator.new()

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var follower: FollowerCharacter = $Follower


func _ready() -> void:
	_rng.seed = 77
	if data != null:
		apply_data(data)


func apply_data(character_data: CharacterData) -> void:
	data = character_data
	name = "Pet_" + String(data.id)
	sprite.sprite_frames = PlayableCharacter.build_sprite_frames(data.sprite_sheet)
	sprite.centered = false
	sprite.offset = SPRITE_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rect := RectangleShape2D.new()
	rect.size = data.collision_size
	collision_shape.shape = rect
	collision_shape.position = Vector2(0.0, -data.collision_size.y / 2.0)
	follower.active = true
	_play_animation()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	velocity = follower.compute_velocity(data.walk_speed, delta)
	move_and_slide()
	trail.record(global_position)
	_is_moving = velocity.length_squared() > 0.01
	if _is_moving:
		facing = PlayableCharacter.direction_to_facing(velocity, facing)
	_play_animation()


func _process(delta: float) -> void:
	if _hop_time >= 0.0:
		_hop_time += delta
		var t := _hop_time / HOP_SECONDS
		visual_root.position.y = -roundf(ThrownProjectile.arc_height(t, HOP_HEIGHT))
		if _hop_time >= HOP_SECONDS:
			_hop_time = -1.0
			visual_root.position.y = 0.0
		return
	if _is_moving:
		_next_action = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)
		return
	_next_action -= delta
	if _next_action <= 0.0:
		do_idle_action()
		_next_action = _rng.randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)


## 小動作：跳一下，並隨機轉頭。
func do_idle_action() -> void:
	_hop_time = 0.0
	var options: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
	facing = options[_rng.randi_range(0, options.size() - 1)]
	idle_actions_done += 1
	_play_animation()


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
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
