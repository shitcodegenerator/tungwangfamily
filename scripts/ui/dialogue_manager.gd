class_name DialogueManager
extends CanvasLayer
## 最小對話管理：單線、依序播放 lines；按 interact 推進（打字中則先補完整句）。
## Phase 4 增加「最後一句後的選項」：choice {prompt, options: [{text, on_select, lines, on_complete}]}，
## 以上下鍵選擇、E 確認；選擇後可接續該選項的 lines，結束時把選項的 on_complete 交給 Main。
## 不做任務條件或存檔；透過 signal 讓 Main 決定要鎖定誰的移動。

signal dialogue_started(speaker: String)
signal line_changed(index: int)
signal choice_shown(options: Array)
signal choice_selected(option: Dictionary)
signal dialogue_finished

@onready var box: DialogueBox = $DialogueBox

var is_active: bool = false
var current_speaker: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1
var _choice: Dictionary = {}
var _choice_index: int = 0
var _is_choosing: bool = false
var _chosen_actions: Array = []


func _ready() -> void:
	box.visible = false


func start(speaker: String, lines: PackedStringArray, portrait: Texture2D = null, choice: Dictionary = {}) -> void:
	if lines.is_empty():
		push_warning("對話沒有任何句子：%s" % speaker)
		return
	box.set_portrait(portrait)
	box.hide_choices()
	is_active = true
	current_speaker = speaker
	_lines = lines
	_index = 0
	_choice = choice if has_valid_options(choice) else {}
	_chosen_actions = []
	_is_choosing = false
	box.show_line(speaker, _lines[0])
	dialogue_started.emit(speaker)
	line_changed.emit(0)


func start_from(interactable: Interactable) -> void:
	start(interactable.speaker_name, interactable.lines)


## 打字中 → 補完整句；選項中 → 確認；否則 → 下一句；沒有下一句 → 顯示選項或結束。
func advance() -> void:
	if not is_active:
		return
	if box.is_typing():
		box.complete_typing()
		return
	if _is_choosing:
		confirm_choice()
		return
	_index += 1
	if _index >= _lines.size():
		if not _choice.is_empty():
			_show_choice()
			return
		_finish()
		return
	box.show_line(current_speaker, _lines[_index])
	line_changed.emit(_index)


func is_choosing() -> bool:
	return _is_choosing


func choice_index() -> int:
	return _choice_index


func move_choice(delta: int) -> void:
	if not _is_choosing:
		return
	var options: Array = _choice.get("options", [])
	_choice_index = posmod(_choice_index + delta, options.size())
	box.show_choices(String(_choice.get("prompt", "")), _option_texts(), _choice_index)


func confirm_choice() -> void:
	if not _is_choosing:
		return
	var options: Array = _choice.get("options", [])
	var option: Dictionary = options[_choice_index]
	_is_choosing = false
	_choice = {}
	box.hide_choices()
	_chosen_actions = option.get("on_complete", []) if typeof(option.get("on_complete", [])) == TYPE_ARRAY else []
	choice_selected.emit(option)
	var follow_up := PackedStringArray()
	for line: Variant in option.get("lines", []):
		follow_up.append(String(line))
	if follow_up.is_empty():
		_finish()
		return
	_lines = follow_up
	_index = 0
	box.show_line(current_speaker, _lines[0])
	line_changed.emit(0)


## 對話結束後由 Main 取走選項的 on_complete 動作（取走即清空）。
func take_chosen_actions() -> Array:
	var actions := _chosen_actions
	_chosen_actions = []
	return actions


func line_index() -> int:
	return _index


func _show_choice() -> void:
	_is_choosing = true
	_choice_index = 0
	box.show_choices(String(_choice.get("prompt", "")), _option_texts(), 0)
	choice_shown.emit(_choice.get("options", []))


func _option_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for option: Variant in _choice.get("options", []):
		texts.append(String(option.get("text", "…")) if typeof(option) == TYPE_DICTIONARY else "…")
	return texts


func _unhandled_input(event: InputEvent) -> void:
	if not _is_choosing or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		move_choice(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		move_choice(1)
		get_viewport().set_input_as_handled()


func _finish() -> void:
	is_active = false
	_index = -1
	_lines = PackedStringArray()
	_is_choosing = false
	box.hide_choices()
	box.visible = false
	dialogue_finished.emit()


## 純函式：choice 是否有可用選項（至少一個字典且帶 text）。
static func has_valid_options(choice: Variant) -> bool:
	if typeof(choice) != TYPE_DICTIONARY:
		return false
	var options: Variant = choice.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.is_empty():
		return false
	for option: Variant in options:
		if typeof(option) != TYPE_DICTIONARY or not option.has("text"):
			return false
	return true
