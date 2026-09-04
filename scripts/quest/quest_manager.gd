class_name QuestManager
extends Node
## 資料驅動的最小任務系統：定義來自 JSON，進度存在 GameState.quests。
## 目標依序完成（第一個未完成的目標是「目前目標」）；狀態 available → active → completed。
## 條件與完成動作都集中在這裡，公告欄、NPC 與場景不各自保存任務變數。

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal item_received(item_id: String)
signal item_removed(item_id: String)

const QUEST_PATH := "res://assets/quests/phase3_demo_quest.json"
## 所有任務定義檔（依序載入；同 id 後者覆蓋）。
const QUEST_PATHS: Array[String] = [
	"res://assets/quests/phase3_demo_quest.json",
	"res://assets/quests/phase4_cc_quest.json",
]
const STATE_AVAILABLE := "available"
const STATE_ACTIVE := "active"
const STATE_COMPLETED := "completed"
const STATE_FAILED := "failed"  # 保留相容性，本階段不使用

var definitions: Dictionary = {}
var state: GameState


func _ready() -> void:
	if definitions.is_empty():
		load_all_definitions()


func load_all_definitions() -> void:
	definitions = {}
	for path: String in QUEST_PATHS:
		var parsed := parse_definitions(FileAccess.get_file_as_string(path))
		if parsed.is_empty():
			push_error("任務定義為空或無法解析：%s" % path)
		definitions.merge(parsed, true)


func load_definitions(path: String) -> void:
	definitions = parse_definitions(FileAccess.get_file_as_string(path))
	if definitions.is_empty():
		push_error("任務定義為空或無法解析：%s" % path)


static func parse_definitions(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	var result := {}
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	for quest: Variant in parsed.get("quests", []):
		if typeof(quest) == TYPE_DICTIONARY and quest.has("id"):
			result[String(quest["id"])] = quest
	return result


func bind(game_state: GameState) -> void:
	state = game_state
	_ensure_entries()


func _ensure_entries() -> void:
	for quest_id: String in definitions:
		if not state.quests.has(quest_id):
			state.quests[quest_id] = {
				"state": String(definitions[quest_id].get("state", STATE_AVAILABLE)),
				"progress": {},
			}


func quest_state(quest_id: String) -> String:
	if state == null or not state.quests.has(quest_id):
		return ""
	return String(state.quests[quest_id].get("state", STATE_AVAILABLE))


func start_quest(quest_id: String) -> bool:
	if not definitions.has(quest_id) or quest_state(quest_id) != STATE_AVAILABLE:
		return false
	state.quests[quest_id]["state"] = STATE_ACTIVE
	quest_started.emit(quest_id)
	quest_updated.emit(quest_id)
	return true


func objectives(quest_id: String) -> Array:
	return definitions.get(quest_id, {}).get("objectives", [])


func objective_progress(quest_id: String, objective_id: String) -> int:
	if state == null or not state.quests.has(quest_id):
		return 0
	return int(state.quests[quest_id].get("progress", {}).get(objective_id, 0))


func is_objective_done(quest_id: String, objective: Dictionary) -> bool:
	return objective_progress(quest_id, String(objective["id"])) >= int(objective.get("count", 1))


## 目前目標：第一個未完成的目標；任務不在進行中或全部完成時回傳空字典。
func current_objective(quest_id: String) -> Dictionary:
	if quest_state(quest_id) != STATE_ACTIVE:
		return {}
	for objective: Dictionary in objectives(quest_id):
		if not is_objective_done(quest_id, objective):
			return objective
	return {}


func is_objective_current(quest_id: String, objective_id: String) -> bool:
	return String(current_objective(quest_id).get("id", "")) == objective_id


func notify_interact(target_id: String) -> void:
	_advance_matching("interact", target_id)


func notify_scene_entered(scene_id: String) -> void:
	_advance_matching("enter_scene", scene_id)


## 系統事件（例如 Boss 被擊倒、物品交付）：對應 kind = "event" 的目標。
func notify_event(event_id: String) -> void:
	_advance_matching("event", event_id)


func _advance_matching(kind: String, target: String) -> void:
	if state == null:
		return
	for quest_id: String in definitions:
		var objective := current_objective(quest_id)
		if objective.is_empty():
			continue
		if String(objective.get("kind", "")) != kind or String(objective.get("target", "")) != target:
			continue
		_add_progress(quest_id, String(objective["id"]), 1)


func _add_progress(quest_id: String, objective_id: String, amount: int) -> void:
	var progress: Dictionary = state.quests[quest_id].get("progress", {})
	progress[objective_id] = int(progress.get(objective_id, 0)) + amount
	state.quests[quest_id]["progress"] = progress
	quest_updated.emit(quest_id)
	if current_objective(quest_id).is_empty():
		_complete(quest_id)


func _complete(quest_id: String) -> void:
	state.quests[quest_id]["state"] = STATE_COMPLETED
	var rewards: Dictionary = definitions[quest_id].get("rewards", {})
	for flag: Variant in rewards.get("flags", []):
		state.set_flag(String(flag), true)
	for scene: Variant in rewards.get("unlock_scenes", []):
		state.unlock_scene(String(scene))
	quest_completed.emit(quest_id)
	quest_updated.emit(quest_id)


## 對話 on_complete 動作：quest_start、set_flag、clear_flag、unlock_scene、quest_objective {quest, objective}、
## give_item、take_item、quest_event。teleport／show_anger 等場景動作不在此處理（Main 另外接）。
func apply_actions(actions: Array) -> void:
	if state == null:
		return
	for action: Variant in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if action.has("give_item"):
			state.add_item(String(action["give_item"]))
			item_received.emit(String(action["give_item"]))
		if action.has("take_item"):
			if state.remove_item(String(action["take_item"])):
				item_removed.emit(String(action["take_item"]))
		if action.has("quest_event"):
			notify_event(String(action["quest_event"]))
		if action.has("quest_start"):
			start_quest(String(action["quest_start"]))
		if action.has("set_flag"):
			state.set_flag(String(action["set_flag"]), true)
		if action.has("clear_flag"):
			state.set_flag(String(action["clear_flag"]), false)
		if action.has("unlock_scene"):
			state.unlock_scene(String(action["unlock_scene"]))
		if action.has("quest_objective"):
			var target: Dictionary = action["quest_objective"]
			var quest_id := String(target.get("quest", ""))
			var objective_id := String(target.get("objective", ""))
			if is_objective_current(quest_id, objective_id):
				var objective := current_objective(quest_id)
				_add_progress(quest_id, objective_id, int(objective.get("count", 1)))


## HUD 一行摘要：第一個進行中的主線任務與目前目標。
func active_summary() -> String:
	for quest_id: String in definitions:
		if quest_state(quest_id) != STATE_ACTIVE:
			continue
		var objective := current_objective(quest_id)
		if objective.is_empty():
			continue
		var done := objective_progress(quest_id, String(objective["id"]))
		var count := int(objective.get("count", 1))
		var progress_text := "（%d/%d）" % [done, count] if count > 1 else ""
		return "%s%s" % [String(objective.get("text", objective["id"])), progress_text]
	return ""


## 任務日誌用：每個任務的標題、狀態與目標清單。
func list_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id: String in definitions:
		var definition: Dictionary = definitions[quest_id]
		var rows: Array[Dictionary] = []
		for objective: Dictionary in objectives(quest_id):
			rows.append({
				"text": String(objective.get("text", objective["id"])),
				"done": is_objective_done(quest_id, objective),
				"current": is_objective_current(quest_id, String(objective["id"])),
			})
		result.append({
			"id": quest_id,
			"title": String(definition.get("title", quest_id)),
			"description": String(definition.get("description", "")),
			"state": quest_state(quest_id),
			"objectives": rows,
		})
	return result


static func state_label(quest_state_name: String) -> String:
	match quest_state_name:
		STATE_ACTIVE:
			return "進行中"
		STATE_COMPLETED:
			return "已完成"
		STATE_FAILED:
			return "失敗"
		_:
			return "可接取"
