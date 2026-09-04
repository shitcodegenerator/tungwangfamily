class_name PartyController
extends Node2D
## 隊伍控制：生成四位角色、切換主要操控者、維護跟隨鏈。
## 切換時不傳送任何人：新領頭者立刻接受輸入，其餘成員依新的順序改追前一位。

signal leader_changed(leader: PlayableCharacter, roster_index: int)

const CHARACTER_SCENE := preload("res://scenes/characters/playable_character.tscn")
const DEFAULT_ROSTER_PATHS: Array[String] = [
	"res://assets/characters/playable/big_brother.tres",
	"res://assets/characters/playable/calm_brother.tres",
	"res://assets/characters/playable/sister_sheep.tres",
	"res://assets/characters/playable/younger_brother.tres",
]

## 跟隨者完全重疊時的推開方向，依隊伍序位輪流指派。
const TIE_BREAKS: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]

@export var roster: Array[CharacterData] = []

## 依名冊順序的成員（1～4 鍵對應此順序）。
var members: Array[PlayableCharacter] = []
## 目前隊伍順序：第 0 位是領頭者，之後依序跟隨前一位。
var order: Array[PlayableCharacter] = []
var switch_count: int = 0
## 對話中鎖定：領頭者不讀移動輸入、也不能切換角色；隊伍位置與跟隨鏈完全不變。
var input_locked: bool = false
## 非戰鬥型寵物：跟在隊伍最後一位後面，不在 order／members 裡，不能被切換。
var pet: PetFollower


func _ready() -> void:
	if roster.is_empty():
		for path: String in DEFAULT_ROSTER_PATHS:
			var data: CharacterData = load(path)
			if data == null:
				push_error("無法載入角色資料：%s" % path)
				continue
			roster.append(data)


func spawn_party(positions: Array[Vector2]) -> void:
	if positions.is_empty():
		push_error("沒有出生點，無法生成隊伍")
		return
	for index: int in range(roster.size()):
		var character: PlayableCharacter = CHARACTER_SCENE.instantiate()
		character.data = roster[index]
		add_child(character)
		var spawn_position := positions[index] if index < positions.size() else positions[0]
		character.global_position = spawn_position
		members.append(character)
	order = members.duplicate()
	_rebuild_follow_chain()
	leader_changed.emit(get_leader(), 0)


## 第一次呼叫生成隊伍，之後改為瞬移（換場景、讀檔用）；順序依 order。
func place(positions: Array[Vector2]) -> void:
	if members.is_empty():
		spawn_party(positions)
	else:
		teleport_to(positions)


func teleport_to(positions: Array[Vector2]) -> void:
	if positions.is_empty():
		push_error("沒有落點，無法放置隊伍")
		return
	for index: int in range(order.size()):
		var target := positions[mini(index, positions.size() - 1)]
		order[index].global_position = target
		order[index].velocity = Vector2.ZERO
		order[index].clear_trail()
	if pet != null:
		pet.global_position = positions[positions.size() - 1] + Vector2(0.0, 14.0)
		pet.velocity = Vector2.ZERO
		pet.clear_trail()


## 設定寵物（null 移除）；寵物跟在目前隊伍最後一位後面。
func set_pet(new_pet: PetFollower, world_position: Vector2 = Vector2.INF) -> void:
	if pet != null and pet != new_pet:
		pet.queue_free()
	pet = new_pet
	if pet == null:
		return
	if pet.get_parent() != self:
		add_child(pet)
	if world_position != Vector2.INF:
		pet.global_position = world_position
	elif not order.is_empty():
		pet.global_position = order.back().global_position + Vector2(0.0, 14.0)
	_rebuild_follow_chain()


func has_pet() -> bool:
	return pet != null and is_instance_valid(pet)


func order_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for member: PlayableCharacter in order:
		ids.append(String(member.data.id))
	return ids


func member_by_id(id: String) -> PlayableCharacter:
	for member: PlayableCharacter in members:
		if String(member.data.id) == id:
			return member
	return null


## 依角色 id 重排隊伍（讀檔用）；未列出的成員排在後面。
func set_order_by_ids(ids: PackedStringArray) -> void:
	var new_order: Array[PlayableCharacter] = []
	for id: String in ids:
		var member := member_by_id(id)
		if member != null and not new_order.has(member):
			new_order.append(member)
	for member: PlayableCharacter in members:
		if not new_order.has(member):
			new_order.append(member)
	if new_order.is_empty():
		return
	order = new_order
	_rebuild_follow_chain()
	leader_changed.emit(get_leader(), get_roster_index(get_leader()))


func get_leader() -> PlayableCharacter:
	return order[0] if not order.is_empty() else null


func get_roster_index(character: PlayableCharacter) -> int:
	return members.find(character)


func set_leader_by_index(roster_index: int) -> void:
	if roster_index < 0 or roster_index >= members.size():
		return
	set_leader(members[roster_index])


func set_leader(character: PlayableCharacter) -> void:
	if character == null or character == get_leader():
		return
	var new_order: Array[PlayableCharacter] = [character]
	for member: PlayableCharacter in order:
		if member != character:
			new_order.append(member)
	order = new_order
	switch_count += 1
	_rebuild_follow_chain()
	leader_changed.emit(character, get_roster_index(character))


func cycle_leader() -> void:
	if members.is_empty():
		return
	var next_index := (get_roster_index(get_leader()) + 1) % members.size()
	set_leader_by_index(next_index)


func set_input_locked(locked: bool) -> void:
	input_locked = locked
	for member: PlayableCharacter in members:
		member.input_locked = locked


func _rebuild_follow_chain() -> void:
	var everyone: Array[Node2D] = []
	for member: PlayableCharacter in order:
		everyone.append(member)
	if pet != null and is_instance_valid(pet):
		everyone.append(pet)
	for index: int in range(order.size()):
		var member := order[index]
		member.set_controlled(index == 0)
		member.input_locked = input_locked
		member.follower.leader = order[index - 1] if index > 0 else null
		member.follower.others = everyone
		member.follower.tie_break = TIE_BREAKS[index % TIE_BREAKS.size()]
		# 清掉舊軌跡：舊軌跡可能指向與新隊形相反的方向，跟隨者改以直線靠近新目標即可。
		member.clear_trail()
	if pet != null and is_instance_valid(pet) and not order.is_empty():
		pet.follower.leader = order.back()
		pet.follower.others = everyone
		pet.follower.tie_break = Vector2.DOWN
		pet.clear_trail()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or input_locked:
		return
	for index: int in range(4):
		if event.is_action_pressed("select_member_%d" % (index + 1)):
			set_leader_by_index(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("party_cycle"):
		cycle_leader()
		get_viewport().set_input_as_handled()


func describe_order() -> String:
	var names: PackedStringArray = PackedStringArray()
	for member: PlayableCharacter in order:
		names.append(member.data.display_name.split("（")[0])
	return " → ".join(names)
