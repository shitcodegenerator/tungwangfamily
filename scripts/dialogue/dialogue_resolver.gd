class_name DialogueResolver
extends RefCounted
## 依遊戲狀態從對話資料挑出要播放的版本。
## 對話 JSON 的每個 id 可以是單一字典，或「版本陣列」：依序檢查 requires，第一個符合的版本勝出；
## 全部不符時使用最後一個版本（因此請把預設版本放在最後）。
##
## requires 支援：flags、not_flags、quest {id: 狀態或狀態陣列}、quest_objective {id: 目前目標 id}。
## on_complete 為動作陣列，交給 QuestManager.apply_actions 處理。

const FALLBACK_LINE := "……"


static func resolve(entry: Variant, state: GameState, quests: QuestManager) -> Dictionary:
	if typeof(entry) == TYPE_ARRAY:
		var variants: Array = entry
		for variant: Variant in variants:
			if typeof(variant) == TYPE_DICTIONARY and requires_met(variant.get("requires", {}), state, quests):
				return normalize(variant)
		if not variants.is_empty() and typeof(variants.back()) == TYPE_DICTIONARY:
			return normalize(variants.back())
		return normalize({})
	if typeof(entry) == TYPE_DICTIONARY:
		return normalize(entry)
	return normalize({})


static func normalize(variant: Dictionary) -> Dictionary:
	var lines := PackedStringArray()
	for line: Variant in variant.get("lines", []):
		lines.append(String(line))
	if lines.is_empty():
		lines.append(FALLBACK_LINE)
	var actions: Array = []
	var raw_actions: Variant = variant.get("on_complete", [])
	if typeof(raw_actions) == TYPE_ARRAY:
		actions = raw_actions
	return {
		"speaker": String(variant.get("speaker", "")),
		"lines": lines,
		"portrait": String(variant.get("portrait", "")),
		"on_complete": actions,
	}


## 沒有條件 → 永遠成立；有條件但沒有狀態可查 → 不成立。
static func requires_met(requires: Variant, state: GameState, quests: QuestManager) -> bool:
	if typeof(requires) != TYPE_DICTIONARY or requires.is_empty():
		return true
	if state == null:
		return false
	for flag: Variant in requires.get("flags", []):
		if not state.has_flag(String(flag)):
			return false
	for flag: Variant in requires.get("not_flags", []):
		if state.has_flag(String(flag)):
			return false
	var quest_conditions: Variant = requires.get("quest", {})
	if typeof(quest_conditions) == TYPE_DICTIONARY and not quest_conditions.is_empty():
		if quests == null:
			return false
		for quest_id: String in quest_conditions:
			var allowed: Variant = quest_conditions[quest_id]
			var current := quests.quest_state(quest_id)
			if typeof(allowed) == TYPE_ARRAY:
				if not allowed.has(current):
					return false
			elif String(allowed) != current:
				return false
	var objective_conditions: Variant = requires.get("quest_objective", {})
	if typeof(objective_conditions) == TYPE_DICTIONARY and not objective_conditions.is_empty():
		if quests == null:
			return false
		for quest_id: String in objective_conditions:
			if not quests.is_objective_current(quest_id, String(objective_conditions[quest_id])):
				return false
	return true
