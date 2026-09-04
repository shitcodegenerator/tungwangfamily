class_name FriedFoodDemon
extends CharacterBody2D
## 炸物魔王（戴王冠的炸全雞）：一次性、搞笑型教學 Boss。純狀態機：待機 → 移動 → 攻擊預兆 → 攻擊（衝撞）→ 待機，
## 受擊時插入受擊狀態，生命歸零進入倒地。只發 signal，不知道任務、旗標或場景（由 BattleDirector 接線）。
## 精靈表 480×80：0 待機、1 走 A、2 走 B、3 攻擊（舉翅）、4 受擊、5 倒地。

signal hit_taken(hp: int)
signal attack_landed(body: Node2D)
signal defeated

enum State { IDLE, MOVE, WINDUP, ATTACK, HIT, DOWN }

const FRAME_IDLE := 0
const FRAME_WALK_A := 1
const FRAME_WALK_B := 2
const FRAME_ATTACK := 3
const FRAME_HIT := 4
const FRAME_DOWN := 5

const IDLE_SECONDS := 0.8
const MOVE_SECONDS := 1.4
const MOVE_SPEED := 42.0
const WINDUP_SECONDS := 0.75
const ATTACK_SECONDS := 0.4
const ATTACK_SPEED := 240.0
const HIT_SECONDS := 0.35
const SHAKE_PIXELS := 3.0
## 預兆／受擊時的顏色
const WINDUP_TINT := Color(1.0, 0.45, 0.35)
const HIT_TINT := Color(2.2, 2.2, 2.2)

var max_hp: int = 5
var hp: int = 5
var state: State = State.IDLE
## 暫停時停在待機不移動、不攻擊（測試與過場用）。
var paused: bool = false
## 提供目標位置（通常是領頭角色）的 Callable，回傳 Vector2。
var target_provider: Callable

var _timer: float = 0.0
var _attack_direction: Vector2 = Vector2.DOWN
var _walk_toggle: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	_rng.seed = 20260904
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox_shape.disabled = true
	sprite.frame = FRAME_IDLE
	_enter(State.IDLE)


func setup(hit_points: int, provider: Callable) -> void:
	max_hp = hit_points
	hp = hit_points
	target_provider = provider


func is_alive() -> bool:
	return hp > 0


## 活動上限（世界座標 y）：由 BattleDirector 依場景 battle.min_y 設定，避免 Boss 走到上緣讓頭被裁掉。
var min_y: float = -INF


func _physics_process(delta: float) -> void:
	if paused and state != State.HIT and state != State.DOWN:
		velocity = Vector2.ZERO
		sprite.frame = FRAME_IDLE
		return
	_timer -= delta
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_enter(State.MOVE)
		State.MOVE:
			var to_target := _target_position() - global_position
			velocity = to_target.normalized() * MOVE_SPEED if to_target.length() > 40.0 else Vector2.ZERO
			_animate_walk(delta)
			if _timer <= 0.0:
				_enter(State.WINDUP)
		State.WINDUP:
			velocity = Vector2.ZERO
			var pulse := 0.5 + 0.5 * sin(_timer * 30.0)
			visual_root.modulate = Color.WHITE.lerp(WINDUP_TINT, pulse)
			visual_root.position.x = roundf(sin(_timer * 40.0) * 1.5)
			if _timer <= 0.0:
				_enter(State.ATTACK)
		State.ATTACK:
			velocity = _attack_direction * ATTACK_SPEED
			_animate_walk(delta * 2.0)
			if _timer <= 0.0:
				_enter(State.IDLE)
		State.HIT:
			velocity = Vector2.ZERO
			visual_root.position.x = roundf(sin(_timer * 60.0) * SHAKE_PIXELS)
			if _timer <= 0.0:
				_enter(State.DOWN if hp <= 0 else State.IDLE)
		State.DOWN:
			velocity = Vector2.ZERO
	if velocity.y < 0.0 and global_position.y <= min_y:
		velocity.y = 0.0
	move_and_slide()
	if global_position.y < min_y:
		global_position.y = min_y


func _animate_walk(delta: float) -> void:
	_walk_toggle += delta
	sprite.frame = FRAME_WALK_A if fmod(_walk_toggle, 0.36) < 0.18 else FRAME_WALK_B


func _enter(new_state: State) -> void:
	state = new_state
	visual_root.modulate = Color.WHITE
	visual_root.position = Vector2.ZERO
	hitbox_shape.set_deferred("disabled", new_state != State.ATTACK)
	match new_state:
		State.IDLE:
			_timer = IDLE_SECONDS
			sprite.frame = FRAME_IDLE
		State.MOVE:
			_timer = MOVE_SECONDS
			sprite.frame = FRAME_WALK_A
		State.WINDUP:
			_timer = WINDUP_SECONDS
			sprite.frame = FRAME_ATTACK
			_attack_direction = (_target_position() - global_position).normalized()
			if _attack_direction.is_zero_approx():
				_attack_direction = Vector2.DOWN
		State.ATTACK:
			_timer = ATTACK_SECONDS
			sprite.frame = FRAME_WALK_A
		State.HIT:
			_timer = HIT_SECONDS
			sprite.frame = FRAME_HIT
			visual_root.modulate = HIT_TINT
		State.DOWN:
			sprite.frame = FRAME_DOWN
			hurtbox.set_deferred("monitorable", false)
			defeated.emit()


func _target_position() -> Vector2:
	if target_provider.is_valid():
		return target_provider.call()
	return global_position


## 有效命中：扣血、進入受擊；倒地後不再受擊。回傳是否有效。
func take_hit(damage: int = 1) -> bool:
	if state == State.DOWN or hp <= 0:
		return false
	hp = maxi(0, hp - damage)
	hit_taken.emit(hp)
	_enter(State.HIT)
	return true


## 立刻進入攻擊預兆（測試用）。
func force_attack() -> void:
	if state != State.DOWN and state != State.HIT:
		_enter(State.WINDUP)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if state == State.ATTACK:
		attack_landed.emit(body)


## 純函式：受擊後剩餘生命。
static func hp_after_hit(current: int, damage: int) -> int:
	return maxi(0, current - maxi(0, damage))
