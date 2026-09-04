class_name BattleDirector
extends Node
## 只服務炸物魔王這一場戰鬥的最小控制器：生成 Boss、接投擲命中、掉炸雞翅、扣玩家生命、判定勝負。
## Boss 戰邏輯集中在此與 FriedFoodDemon；主城、CC、物品、角色腳本都不知道戰鬥存在。
## 勝負只發 signal，旗標、任務與返回 CC 由 Main 處理。

signal boss_hp_changed(hp: int, max_hp: int)
signal player_hp_changed(hp: int, max_hp: int)
signal boss_hit(hp: int)
signal battle_won
signal battle_lost

const BOSS_SCENE := preload("res://scenes/characters/fried_food_demon.tscn")
const WING_SCRIPT := preload("res://scripts/battle/chicken_wing.gd")
const HIT_SPARKLE := preload("res://assets/effects/fx_hit_sparkle.png")
const POOF := preload("res://assets/effects/fx_poof.png")
const VICTORY := preload("res://assets/effects/fx_victory.png")
const ITEM_RESPAWN_SECONDS := 2.0
const DOWN_TO_VICTORY_SECONDS := 1.4
const LOST_DELAY_SECONDS := 0.9
const WING_UPWARD := 170.0

var world: TownWorld
var party: PartyController
var carry: CarrySystem
var boss: FriedFoodDemon
var active: bool = false
var player_hp: int = 3
var player_max_hp: int = 3
var wings_spawned: int = 0
var hits_landed: int = 0
var _finished: bool = false
var _rng := RandomNumberGenerator.new()


func bind(party_controller: PartyController, carry_system: CarrySystem) -> void:
	party = party_controller
	carry = carry_system
	carry.item_thrown.connect(_on_item_thrown)
	_rng.seed = 4


## 進入戰鬥場景時呼叫：依登錄表的 battle 設定生成 Boss。
func start(new_world: TownWorld, config: Dictionary) -> void:
	stop()
	world = new_world
	active = true
	_finished = false
	wings_spawned = 0
	hits_landed = 0
	player_max_hp = int(config.get("player_hp", 3))
	player_hp = player_max_hp
	boss = BOSS_SCENE.instantiate()
	boss.position = Vector2(float(config.get("x", 384.0)), float(config.get("y", 150.0)))
	world.props.add_child(boss)
	boss.setup(int(config.get("boss_hp", 5)), _leader_position)
	boss.hit_taken.connect(_on_boss_hit_taken)
	boss.attack_landed.connect(_on_boss_attack_landed)
	boss.defeated.connect(_on_boss_defeated)
	boss_hp_changed.emit(boss.hp, boss.max_hp)
	player_hp_changed.emit(player_hp, player_max_hp)


## 離開戰鬥場景或戰鬥結束：清掉 Boss 與手上的物品（本次戰鬥暫態全部丟棄）。
func stop() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	active = false
	if carry != null:
		carry.clear_all()


func boss_hp() -> int:
	return boss.hp if boss != null and is_instance_valid(boss) else 0


func set_boss_paused(paused: bool) -> void:
	if boss != null:
		boss.paused = paused


func force_boss_attack() -> void:
	if boss != null:
		boss.force_attack()


func _leader_position() -> Vector2:
	var leader := party.get_leader() if party != null else null
	return leader.global_position if leader != null else Vector2.ZERO


func _on_item_thrown(projectile: ThrownProjectile) -> void:
	if not active:
		projectile.landed.connect(func(node: ThrownProjectile, at: Vector2) -> void: _respawn_item(node.item_id, at, node.home_position); node.queue_free())
		return
	projectile.hit_boss.connect(_on_projectile_hit)
	projectile.landed.connect(_on_projectile_landed)


## 沒打中：物品掉在落點，可以再撿。
func _on_projectile_landed(projectile: ThrownProjectile, at: Vector2) -> void:
	_respawn_item(projectile.item_id, at, projectile.home_position)
	projectile.queue_free()


## 打中：命中特效、Boss 受擊、掉一隻炸雞翅；物品消耗，稍後在原位重新生成。
func _on_projectile_hit(projectile: ThrownProjectile, _hurtbox: Area2D) -> void:
	var item_id := projectile.item_id
	var home := projectile.home_position
	var at := projectile.global_position
	projectile.queue_free()
	if boss == null or not is_instance_valid(boss):
		return
	EffectSprite.spawn(world, CarryableItem.frame_texture(item_id, CarryableItem.FRAME_HIT), at, 0.45)
	EffectSprite.spawn(world, HIT_SPARKLE, at + Vector2(6.0, -8.0), 0.35)
	if boss.take_hit(CarryableItem.damage_for(item_id)):
		hits_landed += 1
		_spawn_wing()
	get_tree().create_timer(ITEM_RESPAWN_SECONDS).timeout.connect(func() -> void: _respawn_item(item_id, home, home))


func _respawn_item(item_id: String, at: Vector2, home: Vector2) -> void:
	if world == null or not is_instance_valid(world):
		return
	world.spawn_item(item_id, at, home)


func _spawn_wing() -> void:
	var wing: ChickenWing = WING_SCRIPT.new()
	world.add_child(wing)
	var horizontal := Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(20.0, 50.0))
	wing.launch(boss.global_position + Vector2(0.0, 4.0), 40.0, horizontal, WING_UPWARD)
	wings_spawned += 1


func _on_boss_hit_taken(hp: int) -> void:
	boss_hit.emit(hp)
	boss_hp_changed.emit(hp, boss.max_hp)


func _on_boss_attack_landed(body: Node2D) -> void:
	if not active or _finished or not body is PlayableCharacter:
		return
	var character := body as PlayableCharacter
	if not character.is_controlled or character.is_invincible():
		return
	player_hp = maxi(0, player_hp - 1)
	character.flash_hurt()
	player_hp_changed.emit(player_hp, player_max_hp)
	if player_hp <= 0:
		_finished = true
		get_tree().create_timer(LOST_DELAY_SECONDS).timeout.connect(func() -> void: battle_lost.emit())


## 第五次命中後 Boss 進入倒地，等倒地演出結束才算勝利。
func _on_boss_defeated() -> void:
	if _finished:
		return
	_finished = true
	var boss_position := boss.global_position
	get_tree().create_timer(DOWN_TO_VICTORY_SECONDS).timeout.connect(func() -> void:
		if world != null and is_instance_valid(world):
			EffectSprite.spawn(world, POOF, boss_position + Vector2(0.0, -20.0), 0.7)
			EffectSprite.spawn(world, VICTORY, _leader_position() + Vector2(0.0, -30.0), 1.2)
		if boss != null and is_instance_valid(boss):
			boss.visible = false
		battle_won.emit()
	)


## 測試用：直接把玩家生命設為指定值。
func set_player_hp(value: int) -> void:
	player_hp = clampi(value, 0, player_max_hp)
	player_hp_changed.emit(player_hp, player_max_hp)
