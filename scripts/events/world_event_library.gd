class_name WorldEventLibrary
extends RefCounted
## 世界事件資料庫（Phase 6）：載入 assets/events/*.json 的事件定義，依「場景 + 觸發」找出符合條件的事件。
## 只做資料查詢與驗證；執行交給 WorldEventRunner，接線在 Main。
##
## 事件格式：
##   event_id、scene_id、trigger {type, interactable_id}、once、complete_flag、requires（同對話的 requires）、actions[]
## once 事件以 complete_flag 判斷是否已完成（永久旗標，不在 daily_state）；旗標本身由 actions 裡的 set_flag 在
## unlock_input 之前寫入，因此中途中斷不會留下完成旗標。

const EVENT_PATHS: Array[String] = [
	"res://assets/events/captain_room_moving_item.json",
]
const REQUIRED_KEYS: Array[String] = ["event_id", "scene_id", "trigger", "actions"]
const TRIGGER_INTERACT_COMPLETE := "interact_complete"

var events: Dictionary = {}


func load_all() -> void:
	events = {}
	for path: String in EVENT_PATHS:
		var event := parse_event(FileAccess.get_file_as_string(path))
		if event.is_empty():
			push_error("事件定義為空或無法解析：%s" % path)
			continue
		var errors := validate(event)
		if not errors.is_empty():
			push_error("事件定義錯誤 %s：%s" % [path, ", ".join(errors)])
			continue
		events[String(event["event_id"])] = event


static func parse_event(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## 純函式：回傳錯誤訊息（空陣列代表通過）。
static func validate(event: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for key: String in REQUIRED_KEYS:
		if not event.has(key):
			errors.append("缺少 %s" % key)
	if typeof(event.get("trigger", null)) != TYPE_DICTIONARY:
		errors.append("trigger 必須是字典")
	if typeof(event.get("actions", null)) != TYPE_ARRAY:
		errors.append("actions 必須是陣列")
		return errors
	var types := PackedStringArray()
	for action: Variant in event["actions"]:
		if typeof(action) != TYPE_DICTIONARY or not action.has("type"):
			errors.append("動作缺少 type")
			continue
		types.append(String(action["type"]))
	if bool(event.get("once", false)):
		var flag := String(event.get("complete_flag", ""))
		if flag.is_empty():
			errors.append("once 事件必須有 complete_flag")
		elif not _sets_flag_before_unlock(event["actions"], flag):
			errors.append("once 事件的 actions 必須在 unlock_input 之前 set_flag %s" % flag)
	return errors


static func _sets_flag_before_unlock(actions: Array, flag: String) -> bool:
	for action: Variant in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var type := String(action.get("type", ""))
		if type == "unlock_input":
			return false
		if type == "set_flag" and String(action.get("flag", "")) == flag:
			return true
	return false


## 找出第一個符合「場景、觸發種類、觸發 id、requires、未完成」的事件；沒有則回傳空字典。
func find_triggered(trigger_type: String, trigger_id: String, scene_id: String, state: GameState, quests: QuestManager) -> Dictionary:
	for event_id: String in events:
		var event: Dictionary = events[event_id]
		if String(event.get("scene_id", "")) != scene_id:
			continue
		var trigger: Dictionary = event.get("trigger", {})
		if String(trigger.get("type", "")) != trigger_type or String(trigger.get("interactable_id", "")) != trigger_id:
			continue
		if not DialogueResolver.requires_met(event.get("requires", {}), state, quests):
			continue
		if bool(event.get("once", false)) and state != null and state.has_flag(String(event.get("complete_flag", ""))):
			continue
		return event
	return {}


## 事件對話：對話 JSON 的 id 可以是一般對話（單一字典或版本陣列）或 {segments: [...]}（多人依序反應）。
## 每個 segment 可帶 requires（例如 CC 加入後才多一句）；回傳已 normalize 的段落陣列，供 Main 依序播放。
static func dialogue_segments(entry: Variant, state: GameState, quests: QuestManager) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("segments", null)) == TYPE_ARRAY:
		for segment: Variant in entry["segments"]:
			if typeof(segment) != TYPE_DICTIONARY:
				continue
			if DialogueResolver.requires_met(segment.get("requires", {}), state, quests):
				result.append(DialogueResolver.normalize(segment))
		return result
	if entry == null:
		return result
	result.append(DialogueResolver.resolve(entry, state, quests))
	return result
