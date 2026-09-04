class_name FollowerCharacter
extends Node
## 跟隨行為：追蹤前一位隊員的歷史軌跡。掛在 PlayableCharacter 底下，只負責「算出想要的速度」，
## 實際移動與碰撞仍由 CharacterBody2D.move_and_slide 處理，因此不會穿牆。

## 沿軌跡保持的距離。
const FOLLOW_DISTANCE := 40.0
## 與前一位隊員的直線距離小於此值時停下，避免重疊。
const MIN_GAP := 30.0
## 直線距離超過此值時加速追趕。
const CATCH_UP_DISTANCE := 90.0
const MAX_SPEED_SCALE := 1.4
const ARRIVE_RADIUS := 1.5
const EASE_IN_RADIUS := 12.0
## 卡住判定：有速度卻幾乎沒位移持續超過此秒數，改為直線朝前一位隊員走。
const STUCK_SECONDS := 0.4
const RECOVER_SECONDS := 0.6

var leader: PlayableCharacter
var active: bool = false

var _stuck_time: float = 0.0
var _recover_time: float = 0.0
var _last_position: Vector2 = Vector2.INF

@onready var body: Node2D = get_parent() as Node2D


func compute_velocity(base_speed: float, delta: float) -> Vector2:
	if not active or leader == null or body == null:
		return Vector2.ZERO
	# 領頭者尚未移動（軌跡只有出生點／切換當下的那一點）時保持原位，避免出生或切換時整隊擠成一團。
	if leader.trail.points.size() < 2 and _recover_time <= 0.0:
		return Vector2.ZERO
	var target := leader.trail_point_behind(FOLLOW_DISTANCE)
	if _recover_time > 0.0:
		_recover_time -= delta
		target = leader.global_position
	var result := decide_velocity(body.global_position, leader.global_position, target, base_speed, delta)
	_update_stuck_state(result, delta)
	return result


func _update_stuck_state(desired: Vector2, delta: float) -> void:
	var moved := _last_position == Vector2.INF or body.global_position.distance_to(_last_position) > 0.3
	_last_position = body.global_position
	if desired.length_squared() > 1.0 and not moved:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_stuck_time = 0.0
			_recover_time = RECOVER_SECONDS
	else:
		_stuck_time = 0.0


## 純函式：依位置關係決定想要的速度向量。
## - 與前一位隊員太近：停下。
## - 距離太遠：以 MAX_SPEED_SCALE 加速。
## - 接近目標：減速，且不超過剩餘距離（避免抖動）。
static func decide_velocity(body_position: Vector2, leader_position: Vector2, target: Vector2, base_speed: float, delta: float) -> Vector2:
	var leader_gap := body_position.distance_to(leader_position)
	if leader_gap < MIN_GAP:
		return Vector2.ZERO
	var to_target := target - body_position
	var distance := to_target.length()
	if distance <= ARRIVE_RADIUS:
		return Vector2.ZERO
	var scale := 1.0
	if leader_gap > CATCH_UP_DISTANCE:
		scale = MAX_SPEED_SCALE
	elif distance < EASE_IN_RADIUS:
		scale = clampf(distance / EASE_IN_RADIUS, 0.35, 1.0)
	var speed := base_speed * scale
	if delta > 0.0:
		speed = minf(speed, distance / delta)
	return to_target / distance * speed
