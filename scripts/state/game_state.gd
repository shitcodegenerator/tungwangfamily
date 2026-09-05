class_name GameState
extends RefCounted
## 集中式遊戲狀態：場景、隊伍、日夜、旗標、任務、物品、寵物。所有系統讀寫這一份，不各自保存變數。
## 可序列化為 Dictionary（供 SaveManager 存成 JSON），並帶 schema_version 供欄位遷移：
##   v1（Phase 3）：場景、隊伍、日夜、旗標、任務、已開放場景
##   v2（Phase 4）：新增 inventory（物品 id → 數量）與 pet_id（跟隨中的寵物）；讀到 v1 存檔時以空值補齊
##   v3（Phase 5）：新增 day（第幾天，從 1 起）、day_seed（該天的亂數種子）、daily_state（當天的暫時旗標，
##                 休息進入下一天時由 reset_daily_state() 清空）；讀到 v1／v2 存檔時 day 1、空 daily_state，
##                 既有旗標、任務、背包與寵物原樣保留。

signal flag_changed(flag_name: String, value: bool)
signal inventory_changed(item_id: String, count: int)
## 休息確認後進入新的一天（day 已 +1、daily_state 已清空）時發出；每日重置的系統接這個 signal。
signal day_advanced(day: int)

const SCHEMA_VERSION := 3
const DEFAULT_SCENE := "tide_root_town"
## day_seed 的基底：之後若要改成「真實日期種子」，只需改 seed_for_day。
const DAY_SEED_BASE := 20260905
const REQUIRED_KEYS: Array[String] = ["schema_version", "current_scene_id", "flags", "quests"]

var schema_version: int = SCHEMA_VERSION
var current_scene_id: String = DEFAULT_SCENE
var return_scene_id: String = ""
var return_position: Vector2 = Vector2.ZERO
## 角色 id 依隊伍順序（第 0 位為領頭者）。
var party_order: PackedStringArray = PackedStringArray()
## 角色 id → 世界座標。
var party_positions: Dictionary = {}
var time_of_day: int = 0
var flags: Dictionary = {}
## quest_id → {"state": String, "progress": {objective_id: int}}
var quests: Dictionary = {}
var unlocked_scenes: PackedStringArray = PackedStringArray([DEFAULT_SCENE])
## item_id → 數量（任務物品，例如香椿乾拌麵）。
var inventory: Dictionary = {}
## 跟隨中的寵物 id（空字串代表沒有）。
var pet_id: String = ""
## 第幾天（從 1 起）。只有 advance_day() 會改變；切換場景、讀檔、F5 日夜都不會。
var day: int = 1
## 當天的亂數種子（每日掉落、裝飾、隨機事件可重現）。
var day_seed: int = seed_for_day(1)
## 當天的暫時狀態（每日旗標 → true）；休息進入下一天時整份清空。
var daily_state: Dictionary = {}


func set_flag(flag_name: String, value: bool = true) -> void:
	if value:
		flags[flag_name] = true
	else:
		flags.erase(flag_name)
	flag_changed.emit(flag_name, value)


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false) == true


func unlock_scene(scene_id: String) -> void:
	if not unlocked_scenes.has(scene_id):
		unlocked_scenes.append(scene_id)


func add_item(item_id: String, amount: int = 1) -> void:
	var count := item_count(item_id) + amount
	if count <= 0:
		inventory.erase(item_id)
		count = 0
	else:
		inventory[item_id] = count
	inventory_changed.emit(item_id, count)


## 數量不足時回傳 false 且不扣除。
func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_count(item_id) < amount:
		return false
	add_item(item_id, -amount)
	return true


func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func has_item(item_id: String) -> bool:
	return item_count(item_id) > 0


# --- 每日系統（Phase 5）------------------------------------------------------

## 進入下一天：只在共享家庭屋休息確認後由 Main 呼叫一次。
func advance_day() -> void:
	day += 1
	day_seed = seed_for_day(day)
	reset_daily_state()
	day_advanced.emit(day)


## 每日重置 hook：清空 daily_state。永久旗標、任務、背包、寵物都不在這裡，不會被清掉。
func reset_daily_state() -> void:
	daily_state = {}


func set_daily_flag(flag_name: String, value: bool = true) -> void:
	if value:
		daily_state[flag_name] = true
	else:
		daily_state.erase(flag_name)


func has_daily_flag(flag_name: String) -> bool:
	return daily_state.get(flag_name, false) == true


## 以 day_seed 建立的亂數產生器（同一天每次呼叫序列相同）。
func daily_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed
	return rng


## 第 day 天的種子：確定性雜湊，與存檔內容無關。
static func seed_for_day(day_number: int) -> int:
	return int(hash("%d:%d" % [DAY_SEED_BASE, day_number])) & 0x7FFFFFFF


func to_dict() -> Dictionary:
	var positions := {}
	for id: String in party_positions:
		var p: Vector2 = party_positions[id]
		positions[id] = [p.x, p.y]
	return {
		"schema_version": SCHEMA_VERSION,
		"current_scene_id": current_scene_id,
		"return_scene_id": return_scene_id,
		"return_position": [return_position.x, return_position.y],
		"party_order": Array(party_order),
		"party_positions": positions,
		"time_of_day": time_of_day,
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"unlocked_scenes": Array(unlocked_scenes),
		"inventory": inventory.duplicate(true),
		"pet_id": pet_id,
		"day": day,
		"day_seed": day_seed,
		"daily_state": daily_state.duplicate(true),
	}


## 回傳 {"state": GameState 或 null, "error": String}。缺欄位、型別不對或版本過新都視為錯誤；
## 舊版（v1）存檔缺少的欄位以預設值補齊。
static func from_dict(data: Dictionary) -> Dictionary:
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			return {"state": null, "error": "存檔缺少欄位 %s" % key}
	var version: Variant = data["schema_version"]
	if typeof(version) != TYPE_FLOAT and typeof(version) != TYPE_INT:
		return {"state": null, "error": "schema_version 不是數字"}
	if int(version) > SCHEMA_VERSION:
		return {"state": null, "error": "存檔版本 %d 比遊戲支援的 %d 新" % [int(version), SCHEMA_VERSION]}
	if typeof(data["flags"]) != TYPE_DICTIONARY or typeof(data["quests"]) != TYPE_DICTIONARY:
		return {"state": null, "error": "flags 或 quests 格式錯誤"}
	if typeof(data["current_scene_id"]) != TYPE_STRING or String(data["current_scene_id"]).is_empty():
		return {"state": null, "error": "current_scene_id 格式錯誤"}
	var state := GameState.new()
	state.schema_version = SCHEMA_VERSION
	state.current_scene_id = String(data["current_scene_id"])
	state.return_scene_id = String(data.get("return_scene_id", ""))
	state.return_position = _vector_from(data.get("return_position"), Vector2.ZERO)
	state.time_of_day = int(data.get("time_of_day", 0))
	state.flags = (data["flags"] as Dictionary).duplicate(true)
	state.quests = (data["quests"] as Dictionary).duplicate(true)
	state.party_order = PackedStringArray()
	for id: Variant in data.get("party_order", []):
		state.party_order.append(String(id))
	state.party_positions = {}
	var raw_positions: Variant = data.get("party_positions", {})
	if typeof(raw_positions) == TYPE_DICTIONARY:
		for id: String in raw_positions:
			state.party_positions[id] = _vector_from(raw_positions[id], Vector2.ZERO)
	state.unlocked_scenes = PackedStringArray()
	for id: Variant in data.get("unlocked_scenes", [DEFAULT_SCENE]):
		state.unlocked_scenes.append(String(id))
	if not state.unlocked_scenes.has(DEFAULT_SCENE):
		state.unlocked_scenes.append(DEFAULT_SCENE)
	# v2 欄位：v1 存檔沒有，補空值
	state.inventory = {}
	var raw_inventory: Variant = data.get("inventory", {})
	if typeof(raw_inventory) == TYPE_DICTIONARY:
		for item_id: String in raw_inventory:
			var count := int(raw_inventory[item_id])
			if count > 0:
				state.inventory[item_id] = count
	state.pet_id = String(data.get("pet_id", ""))
	# v3 欄位：v1／v2 存檔沒有，補 day 1 與空 daily_state；不合法的值也退回預設
	state.day = maxi(1, int(data.get("day", 1)))
	state.day_seed = int(data.get("day_seed", seed_for_day(state.day)))
	state.daily_state = {}
	var raw_daily: Variant = data.get("daily_state", {})
	if typeof(raw_daily) == TYPE_DICTIONARY:
		for key: String in raw_daily:
			if raw_daily[key] == true:
				state.daily_state[key] = true
	return {"state": state, "error": ""}


static func _vector_from(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and raw.size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback
