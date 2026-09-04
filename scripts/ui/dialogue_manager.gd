class_name DialogueManager
extends CanvasLayer
## 最小對話管理：單線、依序播放 lines；按 interact 推進（打字中則先補完整句）。
## 不做分支、任務條件或存檔；透過 signal 讓 Main 決定要鎖定誰的移動。

signal dialogue_started(speaker: String)
signal line_changed(index: int)
signal dialogue_finished

@onready var box: DialogueBox = $DialogueBox

var is_active: bool = false
var current_speaker: String = ""
var _lines: PackedStringArray = PackedStringArray()
var _index: int = -1


func _ready() -> void:
	box.visible = false


func start(speaker: String, lines: PackedStringArray, portrait: Texture2D = null) -> void:
	if lines.is_empty():
		push_warning("對話沒有任何句子：%s" % speaker)
		return
	box.set_portrait(portrait)
	is_active = true
	current_speaker = speaker
	_lines = lines
	_index = 0
	box.show_line(speaker, _lines[0])
	dialogue_started.emit(speaker)
	line_changed.emit(0)


func start_from(interactable: Interactable) -> void:
	start(interactable.speaker_name, interactable.lines)


## 打字中 → 補完整句；否則 → 下一句；沒有下一句 → 結束。
func advance() -> void:
	if not is_active:
		return
	if box.is_typing():
		box.complete_typing()
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	box.show_line(current_speaker, _lines[_index])
	line_changed.emit(_index)


func line_index() -> int:
	return _index


func _finish() -> void:
	is_active = false
	_index = -1
	_lines = PackedStringArray()
	box.visible = false
	dialogue_finished.emit()
