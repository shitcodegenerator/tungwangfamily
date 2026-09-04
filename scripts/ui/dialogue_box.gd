class_name DialogueBox
extends Control
## 可重複使用的對話框：木框羊皮紙底、名稱、逐字顯示的內文、繼續提示、頭像；Phase 4 增加選項列表。
## 只負責「顯示一句話／一組選項」，句子順序與開關由 DialogueManager 控制。

signal typing_finished

const CHARS_PER_SECOND := 28.0
const HINT_BLINK_PERIOD := 0.8
const CHOICE_COLOR := Color(0.2, 0.12, 0.05)
const CHOICE_SELECTED_COLOR := Color(0.62, 0.28, 0.08)

@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %DialogueLabel
@onready var portrait: TextureRect = %Portrait
@onready var continue_hint: Label = %ContinueHint
@onready var choices: VBoxContainer = %Choices

var _elapsed: float = 0.0
var _typing: bool = false
var _blink_time: float = 0.0


func _ready() -> void:
	continue_hint.visible = false
	portrait.visible = portrait.texture != null
	choices.visible = false


func show_line(speaker: String, text: String) -> void:
	name_label.text = speaker
	name_label.visible = not speaker.is_empty()
	text_label.text = text
	text_label.visible_characters = 0
	text_label.visible = true
	_elapsed = 0.0
	_typing = true
	continue_hint.visible = false
	visible = true


func is_typing() -> bool:
	return _typing


## 立刻顯示整句。
func complete_typing() -> void:
	text_label.visible_characters = -1
	if _typing:
		_typing = false
		typing_finished.emit()
	continue_hint.visible = not choices.visible


## 未來頭像接口：傳 null 隱藏。
func set_portrait(texture: Texture2D) -> void:
	portrait.texture = texture
	portrait.visible = texture != null


## 顯示選項：prompt 取代內文，選項逐列列出，selected 那列加上「▶」與強調色。
func show_choices(prompt: String, options: PackedStringArray, selected: int) -> void:
	for child: Node in choices.get_children():
		child.queue_free()
	text_label.text = prompt
	text_label.visible_characters = -1
	text_label.visible = not prompt.is_empty()
	_typing = false
	continue_hint.visible = false
	for index: int in range(options.size()):
		var label := Label.new()
		label.text = choice_line(options[index], index == selected)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", CHOICE_SELECTED_COLOR if index == selected else CHOICE_COLOR)
		choices.add_child(label)
	choices.visible = true
	visible = true


func hide_choices() -> void:
	choices.visible = false
	for child: Node in choices.get_children():
		child.queue_free()


func is_showing_choices() -> bool:
	return choices.visible


func _process(delta: float) -> void:
	if _typing:
		_elapsed += delta
		var total := text_label.text.length()
		var count := visible_count(_elapsed, CHARS_PER_SECOND, total)
		text_label.visible_characters = count
		if count >= total:
			complete_typing()
		return
	_blink_time += delta
	continue_hint.modulate.a = 1.0 if fmod(_blink_time, HINT_BLINK_PERIOD) < HINT_BLINK_PERIOD * 0.6 else 0.35


## 純函式：經過 elapsed 秒後應顯示的字數。
static func visible_count(elapsed: float, chars_per_second: float, total: int) -> int:
	return clampi(int(floor(elapsed * chars_per_second)), 0, total)


## 純函式：選項那一列的文字。
static func choice_line(text: String, selected: bool) -> String:
	return ("▶ " if selected else "　 ") + text
