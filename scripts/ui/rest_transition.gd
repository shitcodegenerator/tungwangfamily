class_name RestTransition
extends CanvasLayer
## 休息→隔天早晨的全螢幕轉場：淡出到黑 → （畫面全黑時執行回呼：day +1、重建場景、存檔）→
## 顯示日出四幀（assets/effects/morning_transition_sheet.png，4 × 64×64）與「第 N 天」→ 淡入。
## 只負責畫面與節奏；不改 GameState、不知道場景怎麼重建。

signal finished

const SUNRISE_SHEET := preload("res://assets/effects/morning_transition_sheet.png")
const FRAME_SIZE := 64
const FRAME_COUNT := 4
const FRAME_SECONDS := 0.42
const FADE_OUT_SECONDS := 0.5
const FADE_IN_SECONDS := 0.7
const HOLD_SECONDS := 0.5
const CARD_SCALE := 2.0

var is_playing: bool = false

var _cover: ColorRect
var _card: Control
var _frame: TextureRect
var _label: Label


func _ready() -> void:
	layer = 45
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.color = Color(0.02, 0.01, 0.0, 1.0)
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	_cover.visible = false
	add_child(_cover)
	_card = Control.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	_frame = TextureRect.new()
	_frame.name = "Sunrise"
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	var card_px := FRAME_SIZE * CARD_SCALE
	_frame.offset_left = -card_px / 2.0
	_frame.offset_right = card_px / 2.0
	_frame.offset_top = -card_px / 2.0 - 12.0
	_frame.offset_bottom = card_px / 2.0 - 12.0
	_frame.texture = frame_texture(0)
	_card.add_child(_frame)
	_label = Label.new()
	_label.name = "DayLabel"
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.offset_left = -160.0
	_label.offset_right = 160.0
	_label.offset_top = card_px / 2.0 - 4.0
	_label.offset_bottom = card_px / 2.0 + 28.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_card.add_child(_label)


## 播放整段轉場；on_dark 在畫面全黑時呼叫（可為 async）。重複呼叫會被忽略。
func play(day: int, on_dark: Callable) -> void:
	if is_playing:
		return
	is_playing = true
	_cover.visible = true
	_card.visible = false
	_label.text = day_label(day)
	await _fade_cover(1.0, FADE_OUT_SECONDS)
	if on_dark.is_valid():
		await on_dark.call()
	_card.visible = true
	for index: int in range(FRAME_COUNT):
		_frame.texture = frame_texture(index)
		await get_tree().create_timer(FRAME_SECONDS).timeout
	await get_tree().create_timer(HOLD_SECONDS).timeout
	_card.visible = false
	await _fade_cover(0.0, FADE_IN_SECONDS)
	_cover.visible = false
	is_playing = false
	finished.emit()


func _fade_cover(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", alpha, seconds)
	await tween.finished


## 純函式：日出表的第 index 幀。
static func frame_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SUNRISE_SHEET
	atlas.region = Rect2(clampi(index, 0, FRAME_COUNT - 1) * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
	return atlas


static func day_label(day: int) -> String:
	return "第 %d 天" % day
