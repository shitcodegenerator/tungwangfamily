class_name InteractionController
extends Node2D
## 互動控制：每個 physics frame 讀取領頭角色 InteractionArea 內的 Interactable，挑出最近者作為目前目標，
## 在目標上方顯示提示圖示；按下 interact（E）時若對話進行中則推進對話，否則觸發目標的 interact()。
## Phase 4：領頭者舉著投擲物時，E 改為投擲（撿取仍走一般互動流程：地上的物品就是 Interactable）。
## 不包含任何對話內容或角色移動邏輯。

signal target_changed(target: Interactable)
signal interaction_requested(target: Interactable)

const PROMPT_TEXTURE := preload("res://assets/ui/interact_prompt.png")
const PROMPT_BOB_SPEED := 4.0

var party: PartyController
var dialogue: DialogueManager
var carry: CarrySystem
var current_target: Interactable

var _prompt: Sprite2D
var _bob_time: float = 0.0


func _ready() -> void:
	_prompt = Sprite2D.new()
	_prompt.name = "InteractPrompt"
	_prompt.texture = PROMPT_TEXTURE
	_prompt.centered = true
	_prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_prompt.z_index = 30
	_prompt.visible = false
	add_child(_prompt)


func bind(party_controller: PartyController, dialogue_manager: DialogueManager, carry_system: CarrySystem = null) -> void:
	party = party_controller
	dialogue = dialogue_manager
	carry = carry_system


func is_leader_carrying() -> bool:
	return carry != null and carry.is_leader_carrying()


func _physics_process(delta: float) -> void:
	if party == null or party.get_leader() == null:
		return
	var leader := party.get_leader()
	var candidates: Array[Area2D] = []
	if leader.interaction_area.monitoring:
		candidates = leader.interaction_area.get_overlapping_areas()
	var nearest := pick_nearest(candidates, leader.global_position)
	if nearest != current_target:
		current_target = nearest
		target_changed.emit(nearest)
	_update_prompt(delta)


func _update_prompt(delta: float) -> void:
	var show_prompt := current_target != null and not is_dialogue_active() and not is_leader_carrying()
	_prompt.visible = show_prompt
	if not show_prompt:
		return
	_bob_time += delta
	_prompt.global_position = current_target.prompt_position() + Vector2(0.0, roundf(sin(_bob_time * PROMPT_BOB_SPEED)))


func is_dialogue_active() -> bool:
	return dialogue != null and dialogue.is_active


func prompt_visible() -> bool:
	return _prompt.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("interact"):
		return
	if is_dialogue_active():
		dialogue.advance()
	elif is_leader_carrying():
		if party.input_locked:
			return
		carry.throw()
	elif current_target != null:
		interaction_requested.emit(current_target)
		current_target.interact()
	else:
		return
	get_viewport().set_input_as_handled()


## 純函式：從候選 Area2D 中挑出距離 from 最近的 Interactable；沒有則回傳 null。
static func pick_nearest(candidates: Array, from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for candidate: Variant in candidates:
		if not candidate is Interactable:
			continue
		var distance: float = (candidate as Interactable).global_position.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
