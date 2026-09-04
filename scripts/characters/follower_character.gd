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
## 停下時若與任一隊員（含領頭者、寵物）距離小於此值，以較慢速度推開，避免同格重疊。
const SEPARATION_GAP := 26.0
const SEPARATION_SPEED_SCALE := 0.5

var leader: PlayableCharacter
var active: bool = false
## 其他隊員（由 PartyController 設定），只用來做停下後的分離；不影響跟隨鏈。
var others: Array[Node2D] = []
## 兩人完全重疊時的推開方向（PartyController 依序給不同方向，避免兩人往同一邊走而永遠分不開）。
var tie_break: Vector2 = Vector2.RIGHT

var _stuck_time: float = 0.0
var _recover_time: float = 0.0
var _last_position: Vector2 = Vector2.INF

@onready var body: Node2D = get_parent() as Node2D


func compute_velocity(base_speed: float, delta: float) -> Vector2:
	if not active or leader == null or body == null:
		return Vector2.ZERO
	# 領頭者尚未移動（軌跡只有出生點／切換當下的那一點）時不追軌跡，只做分離，避免出生、切換或返回時整隊疊在同一點。
	if leader.trail.points.size() < 2 and _recover_time <= 0.0:
		return separation_velocity(body.global_position, _other_positions(), base_speed * SEPARATION_SPEED_SCALE, tie_break)
	var target := leader.trail_point_behind(FOLLOW_DISTANCE)
	if _recover_time > 0.0:
		_recover_time -= delta
		target = leader.global_position
	var result := decide_velocity(body.global_position, leader.global_position, target, base_speed, delta)
	if result.is_zero_approx():
		result = separation_velocity(body.global_position, _other_positions(), base_speed * SEPARATION_SPEED_SCALE, tie_break)
	_update_stuck_state(result, delta)
	return result


func _other_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for other: Node2D in others:
		if other != null and is_instance_valid(other) and other != body:
			positions.append(other.global_position)
	return positions


## 純函式：停下時被其他隊員擠到（距離 < SEPARATION_GAP）就朝遠離他們的方向慢慢走開；沒有人靠太近則回傳零向量。
## 完全重疊（距離趨近 0）時用 tie_break 決定方向。
static func separation_velocity(body_position: Vector2, other_positions: Array[Vector2], speed: float, tie_break_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	var push := Vector2.ZERO
	for other: Vector2 in other_positions:
		var away := body_position - other
		var distance := away.length()
		if distance >= SEPARATION_GAP:
			continue
		var direction := away / distance if distance > 0.5 else tie_break_direction.normalized()
		push += direction * (1.0 - distance / SEPARATION_GAP)
	if push.is_zero_approx():
		return Vector2.ZERO
	return push.normalized() * speed


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
