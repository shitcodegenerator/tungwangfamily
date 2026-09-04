class_name ChickenWing
extends Node2D
## 命中回饋：一隻炸雞翅從 Boss 身上彈出、落地彈跳一次、淡出消失。純視覺，不進背包、不可撿取。
## 位置以「地面 y」為基準：shadow 留在地面，貼圖以 height 往上畫。

signal vanished

const GRAVITY := 420.0
const BOUNCE_DAMPING := 0.45
const FADE_SECONDS := 0.45
const REST_SECONDS := 0.25
const WING_TEXTURE := preload("res://assets/effects/fx_chicken_wing.png")

var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_speed: float = 0.0
var bounces: int = 0
var _rest: float = 0.0
var _fade: float = -1.0

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = WING_TEXTURE
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	z_index = 7


## 從 Boss 位置彈出：水平方向隨機、往上拋。
func launch(ground_position: Vector2, start_height: float, horizontal: Vector2, upward: float) -> void:
	position = ground_position
	height = start_height
	velocity = horizontal
	vertical_speed = -upward


func _process(delta: float) -> void:
	if _fade >= 0.0:
		_fade -= delta
		_sprite.modulate.a = maxf(0.0, _fade / FADE_SECONDS)
		_sprite.scale = Vector2.ONE * maxf(0.2, _fade / FADE_SECONDS)
		if _fade <= 0.0:
			vanished.emit()
			queue_free()
		return
	var result := simulate_step(height, vertical_speed, delta)
	height = result["height"]
	vertical_speed = result["speed"]
	if result["bounced"]:
		bounces += 1
		velocity *= 0.5
	position += velocity * delta
	_sprite.position.y = -height
	_sprite.rotation += delta * 6.0
	if bounces >= 1 and height <= 0.01 and absf(vertical_speed) < 8.0:
		_rest += delta
		if _rest >= REST_SECONDS:
			_fade = FADE_SECONDS


## 純函式：一步垂直運動（高度 ≥ 0，落地時以 BOUNCE_DAMPING 反彈，太慢時停下）。
static func simulate_step(current_height: float, speed: float, delta: float) -> Dictionary:
	var new_speed := speed + GRAVITY * delta
	var new_height := current_height - new_speed * delta
	var bounced := false
	if new_height <= 0.0:
		new_height = 0.0
		if new_speed > 30.0:
			new_speed = -new_speed * BOUNCE_DAMPING
			bounced = true
		else:
			new_speed = 0.0
	return {"height": new_height, "speed": new_speed, "bounced": bounced}
