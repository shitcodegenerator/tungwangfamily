class_name ThrownProjectile
extends Area2D
## 投擲中的物品：沿面向直線飛行、視覺上畫拋物線，碰到 Boss 受擊區（物理層 5）發出 hit_boss，
## 飛到射程盡頭（或牆前）發出 landed。落點在起飛時就以 landing_point 決定，不會飛進牆裡。

signal hit_boss(projectile: ThrownProjectile, hurtbox: Area2D)
signal landed(projectile: ThrownProjectile, world_position: Vector2)

const BOSS_LAYER_BIT := 16
const SPEED := 230.0
const RANGE := 150.0
const ARC_HEIGHT := 26.0
const STEP := 8.0
## 起飛後多久內不判定命中（避免剛離手就碰到貼身的 Boss 算兩次）
const ARM_DELAY := 0.03

var item_id: String = ""
var home_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.DOWN
var start_position: Vector2 = Vector2.ZERO
var travel_distance: float = RANGE
var traveled: float = 0.0
var finished: bool = false

var _sprite: Sprite2D
var _age: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = BOSS_LAYER_BIT
	monitorable = false


## is_walkable(Vector2) -> bool：用來把射程截短到牆前。
func setup(id: String, from: Vector2, facing: Vector2i, home: Vector2, is_walkable: Callable) -> void:
	item_id = id
	home_position = home
	direction = Vector2(facing).normalized()
	start_position = from
	position = from
	name = "Projectile_" + id
	var landing := landing_point(from, direction, RANGE, STEP, is_walkable)
	travel_distance = from.distance_to(landing)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14.0, 14.0)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = CarryableItem.frame_texture(id, CarryableItem.FRAME_FLY)
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.flip_h = direction.x < 0.0
	add_child(_sprite)
	z_index = 8
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if finished:
		return
	_age += delta
	var step := minf(SPEED * delta, travel_distance - traveled)
	traveled += step
	position += direction * step
	var t := traveled / maxf(travel_distance, 1.0)
	_sprite.position.y = -arc_height(t, ARC_HEIGHT)
	_sprite.rotation += delta * 9.0
	if traveled >= travel_distance - 0.01:
		finished = true
		landed.emit(self, position)


func _on_area_entered(area: Area2D) -> void:
	if finished or _age < ARM_DELAY:
		return
	finished = true
	hit_boss.emit(self, area)


func _finish_and_free() -> void:
	set_physics_process(false)
	queue_free()


## 純函式：拋物線高度（t 0→1）。
static func arc_height(t: float, height: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	return 4.0 * height * clamped * (1.0 - clamped)


## 純函式：沿方向每 step 檢查一次可走性，回傳最後一個可走點（射程盡頭或牆前）。
static func landing_point(from: Vector2, dir: Vector2, max_range: float, step: float, is_walkable: Callable) -> Vector2:
	var last := from
	var distance := step
	while distance <= max_range:
		var candidate := from + dir * distance
		if not bool(is_walkable.call(candidate)):
			break
		last = candidate
		distance += step
	return last
