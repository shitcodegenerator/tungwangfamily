class_name CarrySystem
extends Node
## 撿取／舉物／投擲：只有目前操控角色能撿與丟。撿起時物品從世界移除、貼圖掛到角色 VisualRoot/CarryAnchor；
## 投擲時生成 ThrownProjectile 交給世界，並通知 BattleDirector（item_thrown）。
## 四位角色共用同一流程；被切換成跟隨者的角色會繼續舉著物品（不自動投擲），切回來再丟。

signal item_picked(character: PlayableCharacter, item_id: String)
signal item_thrown(projectile: ThrownProjectile)

const PROJECTILE_SCRIPT := preload("res://scripts/battle/thrown_projectile.gd")

var party: PartyController
var world: TownWorld
## 角色 → {"item_id": String, "home": Vector2, "sprite": Sprite2D}
var carried: Dictionary = {}


func bind(party_controller: PartyController) -> void:
	party = party_controller


func set_world(new_world: TownWorld) -> void:
	world = new_world


func is_carrying(character: PlayableCharacter) -> bool:
	return character != null and carried.has(character)


func is_leader_carrying() -> bool:
	return party != null and is_carrying(party.get_leader())


func carried_item_id(character: PlayableCharacter) -> String:
	return String(carried.get(character, {}).get("item_id", ""))


## 領頭者撿起地上的物品；已經舉著東西時回傳 false。
func pick_up(item: CarryableItem) -> bool:
	var leader := party.get_leader() if party != null else null
	if leader == null or is_carrying(leader) or item == null:
		return false
	var sprite := Sprite2D.new()
	sprite.name = "CarriedItem"
	sprite.texture = CarryableItem.frame_texture(item.item_id, CarryableItem.FRAME_CARRY)
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	leader.carry_anchor.add_child(sprite)
	carried[leader] = {"item_id": item.item_id, "home": item.home_position, "sprite": sprite}
	leader.set_carrying(true)
	item_picked.emit(leader, item.item_id)
	item.queue_free()
	return true


## 領頭者朝面向投擲；沒舉東西時回傳 null。
func throw() -> ThrownProjectile:
	var leader := party.get_leader() if party != null else null
	if leader == null or not is_carrying(leader) or world == null:
		return null
	var entry: Dictionary = carried[leader]
	var projectile: ThrownProjectile = PROJECTILE_SCRIPT.new()
	var from: Vector2 = leader.carry_anchor.global_position + Vector2(leader.facing) * 6.0
	world.add_child(projectile)
	projectile.setup(String(entry["item_id"]), from, leader.facing, entry["home"], _is_world_walkable)
	_drop_visual(leader)
	leader.play_throw()
	item_thrown.emit(projectile)
	return projectile


## 換場景、讀檔或戰鬥結束時清掉所有人手上的物品（物品不進背包）。
func clear_all() -> void:
	for character: Variant in carried.keys():
		if is_instance_valid(character):
			_drop_visual(character)
	carried.clear()


func _drop_visual(character: PlayableCharacter) -> void:
	var entry: Dictionary = carried.get(character, {})
	var sprite: Sprite2D = entry.get("sprite")
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	carried.erase(character)
	character.set_carrying(false)


func _is_world_walkable(world_position: Vector2) -> bool:
	if world == null or not is_instance_valid(world):
		return false
	return world.is_tile_walkable(world.world_to_tile(world_position))
