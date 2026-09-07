class_name WorldEventRunner
extends Node
## 資料驅動的世界事件執行器（Phase 6）：只接受事件資料（actions 陣列）依序執行，完成或取消時發出 signal。
## 不知道角色、隊伍、戰鬥、NPC 或任何特定劇情；所有外部能力都透過 Callable 注入（由 Main 接線）：
##   resolve_target(id) → Node、lock_input(bool)、start_dialogue(id) → bool、set_flag(flag)、add_clue(id)
## 支援動作：lock_input、wait、tween_node、dialogue、shader_param、clue、set_flag、unlock_input。
## 事件中的暫態（原始 transform、Shader 原值、輸入鎖）只存在本節點，不進 GameState；
## cancel() 會殺掉 Tween、還原所有被動過的節點與 Shader 參數並解鎖輸入，之後可安全重播。

signal event_started(event_id: String)
signal event_finished(event_id: String)
signal event_cancelled(event_id: String)
## 內部：每個阻塞步驟（wait／tween／dialogue／shader 維持）完成時發出，cancel 也會發出以喚醒 run()。
signal step_done

const TWEEN_PROPERTIES: Array[String] = ["position", "rotation", "scale"]

var resolve_target: Callable = Callable()
var lock_input: Callable = Callable()
var start_dialogue: Callable = Callable()
var set_flag: Callable = Callable()
var add_clue: Callable = Callable()
## 測試用加速：wait 與 tween 的時間都除以它。
var speed_scale: float = 1.0

var current_event_id: String = ""
var _running: bool = false
var _cancelled: bool = false
var _input_locked: bool = false
var _waiting_dialogue: bool = false
var _step_token: int = 0
var _tween: Tween
## Node → {property: 原值}
var _originals: Dictionary = {}
## Node → {parameter: 原值}
var _shader_originals: Dictionary = {}


func is_running() -> bool:
	return _running


func is_input_locked() -> bool:
	return _input_locked


## 依序執行事件的 actions；回傳 true 代表完整完成、false 代表沒有啟動或中途被 cancel。
func run(event: Dictionary) -> bool:
	if _running:
		push_warning("事件進行中，忽略：%s" % event.get("event_id", ""))
		return false
	_running = true
	_cancelled = false
	_originals = {}
	_shader_originals = {}
	current_event_id = String(event.get("event_id", ""))
	event_started.emit(current_event_id)
	for action: Variant in event.get("actions", []):
		if _cancelled:
			break
		if typeof(action) == TYPE_DICTIONARY:
			await _perform(action)
	if _cancelled:
		return false
	var event_id := current_event_id
	_running = false
	current_event_id = ""
	_originals = {}
	_shader_originals = {}
	# 資料忘記 unlock_input 也不能把玩家鎖死。
	if _input_locked:
		_set_lock(false)
	event_finished.emit(event_id)
	return true


## 中斷：還原被動過的節點與 Shader、解鎖輸入、不寫任何旗標；沒有事件進行時不做事。
func cancel() -> void:
	if not _running:
		return
	_cancelled = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_restore_all()
	_running = false
	_waiting_dialogue = false
	var event_id := current_event_id
	current_event_id = ""
	_set_lock(false)
	event_cancelled.emit(event_id)
	_finish_step(_step_token)


## Main 在事件對話（含多段反應）全部播完時呼叫。
func notify_dialogue_finished() -> void:
	if not _waiting_dialogue:
		return
	_waiting_dialogue = false
	_finish_step(_step_token)


func _perform(action: Dictionary) -> void:
	match String(action.get("type", "")):
		"lock_input":
			_set_lock(true)
		"unlock_input":
			_set_lock(false)
		"wait":
			await _wait(float(action.get("seconds", 0.0)))
		"tween_node":
			await _tween_node(action)
		"dialogue":
			await _dialogue(String(action.get("dialogue_id", "")))
		"shader_param":
			await _shader_param(action)
		"set_flag":
			if set_flag.is_valid():
				set_flag.call(String(action.get("flag", "")))
		"clue":
			if add_clue.is_valid():
				add_clue.call(String(action.get("clue_id", "")))
		_:
			push_warning("未知的事件動作：%s" % action.get("type", ""))


func _set_lock(locked: bool) -> void:
	_input_locked = locked
	if lock_input.is_valid():
		lock_input.call(locked)


func _find_target(id: String) -> Node:
	if not resolve_target.is_valid():
		return null
	var node: Variant = resolve_target.call(id)
	return node if node is Node and is_instance_valid(node) else null


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var token := _next_token()
	get_tree().create_timer(seconds / speed_scale).timeout.connect(_finish_step.bind(token))
	await step_done


func _tween_node(action: Dictionary) -> void:
	var target := _find_target(String(action.get("target", "")))
	var property := String(action.get("property", "position"))
	if target == null or not TWEEN_PROPERTIES.has(property):
		push_warning("tween_node 找不到目標或屬性不支援：%s.%s" % [action.get("target", ""), property])
		return
	_remember(target, property)
	var final: Variant = final_value(target.get(property), action)
	_tween = create_tween()
	_tween.set_speed_scale(speed_scale)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(ease_for(String(action.get("ease", "in_out"))))
	_tween.tween_property(target, property, final, float(action.get("seconds", 0.5)))
	var token := _next_token()
	_tween.finished.connect(_finish_step.bind(token))
	await step_done
	_tween = null


func _dialogue(dialogue_id: String) -> void:
	if dialogue_id.is_empty() or not start_dialogue.is_valid():
		return
	_waiting_dialogue = true
	var token := _next_token()
	if not bool(start_dialogue.call(dialogue_id)):
		_waiting_dialogue = false
		return
	if not _waiting_dialogue:
		# 對話在 start 期間就同步結束（例如空對話）
		return
	await step_done


## 暫時改 Shader uniform，維持 seconds 秒後還原（seconds 為 0 則只設定不還原，事件結束／取消時仍會還原）。
func _shader_param(action: Dictionary) -> void:
	var target := _find_target(String(action.get("target", "")))
	var parameter := String(action.get("parameter", ""))
	if target == null or parameter.is_empty() or not target.has_method("set_shader_param"):
		push_warning("shader_param 找不到目標或目標沒有 set_shader_param：%s" % action.get("target", ""))
		return
	if not _shader_originals.has(target):
		_shader_originals[target] = {}
	if not _shader_originals[target].has(parameter):
		_shader_originals[target][parameter] = target.call("get_shader_param", parameter)
	target.call("set_shader_param", parameter, action.get("value", 0.0))
	var seconds := float(action.get("seconds", 0.0))
	if seconds <= 0.0:
		return
	await _wait(seconds)
	if not _cancelled and is_instance_valid(target):
		target.call("set_shader_param", parameter, _shader_originals[target][parameter])


func _remember(target: Node, property: String) -> void:
	if not _originals.has(target):
		_originals[target] = {}
	if not _originals[target].has(property):
		_originals[target][property] = target.get(property)


func _restore_all() -> void:
	for target: Variant in _originals:
		if not is_instance_valid(target):
			continue
		for property: String in _originals[target]:
			target.set(property, _originals[target][property])
	for target: Variant in _shader_originals:
		if not is_instance_valid(target):
			continue
		for parameter: String in _shader_originals[target]:
			target.call("set_shader_param", parameter, _shader_originals[target][parameter])
	_originals = {}
	_shader_originals = {}


func _next_token() -> int:
	_step_token += 1
	return _step_token


## 只有「目前步驟」的完成通知才會喚醒 run()；過期的計時器不會影響下一次事件。
func _finish_step(token: int) -> void:
	if token != _step_token:
		return
	_step_token += 1
	step_done.emit()


## 純函式：tween 的目標值。offset 相對目前值、value 絕對值；Vector2 屬性接受 [x, y]，rotation 接受 float。
static func final_value(current: Variant, action: Dictionary) -> Variant:
	if action.has("offset"):
		var offset: Variant = action["offset"]
		if typeof(offset) == TYPE_ARRAY and offset.size() == 2:
			return current + Vector2(float(offset[0]), float(offset[1]))
		return current + float(offset)
	if action.has("value"):
		var value: Variant = action["value"]
		if typeof(value) == TYPE_ARRAY and value.size() == 2:
			return Vector2(float(value[0]), float(value[1]))
		return float(value)
	return current


static func ease_for(name: String) -> Tween.EaseType:
	match name:
		"in":
			return Tween.EASE_IN
		"out":
			return Tween.EASE_OUT
		_:
			return Tween.EASE_IN_OUT
