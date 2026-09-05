class_name DayNightController
extends CanvasModulate
## 日夜狀態最小版本：只用 CanvasModulate 改變整個世界畫布的色調，不重建地圖、不影響碰撞。
## F5（debug_cycle_daytime）循環 白天 → 黃昏 → 夜晚 → 白天；燈籠光暈強度由 lamp_strength_for 提供。
## Phase 5：休息醒來後 play_morning() 先套暖色早晨色調，再於 MORNING_SECONDS 內漸變成白天；
## 早晨不是獨立的存檔狀態（time_of_day 仍為白天 0），F5 也不會增加 day。

signal state_changed(state_name: StringName, index: int)

const STATE_NAMES: Array[StringName] = [&"day", &"dusk", &"night"]
const STATE_LABELS: Array[String] = ["白天", "黃昏", "夜晚"]
const STATE_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.78, 0.6),
	Color(0.4, 0.46, 0.78),
]
const LAMP_STRENGTHS: Array[float] = [0.0, 0.7, 1.0]
const TRANSITION_SECONDS := 0.6
const MORNING_COLOR := Color(1.0, 0.9, 0.76)
const MORNING_LABEL := "早晨"
const MORNING_SECONDS := 4.0
## assets/ui/day_phase_icons.png（4 格 24×24）的順序：早晨、白天、黃昏、夜晚。
const PHASE_ICON_MORNING := 0
const PHASE_ICON_DAY := 1
const PHASE_ICON_DUSK := 2
const PHASE_ICON_NIGHT := 3

var index: int = 0
var _tween: Tween
var _morning: bool = false


func _ready() -> void:
	color = STATE_COLORS[index]


func cycle() -> void:
	set_state(next_index(index))


func set_state(new_index: int, instant: bool = false) -> void:
	index = posmod(new_index, STATE_NAMES.size())
	_morning = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		color = STATE_COLORS[index]
	else:
		_tween = create_tween()
		_tween.tween_property(self, "color", STATE_COLORS[index], TRANSITION_SECONDS)
	state_changed.emit(STATE_NAMES[index], index)


## 休息醒來：狀態設為白天（燈籠熄滅、存檔 time_of_day = 0），畫面從早晨暖色慢慢亮成白天。
func play_morning() -> void:
	index = 0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	color = MORNING_COLOR
	_morning = true
	_tween = create_tween()
	_tween.tween_property(self, "color", STATE_COLORS[0], MORNING_SECONDS)
	_tween.finished.connect(func() -> void: _morning = false)
	state_changed.emit(STATE_NAMES[0], 0)


func is_morning() -> bool:
	return _morning


func state_name() -> StringName:
	return STATE_NAMES[index]


func state_label() -> String:
	return MORNING_LABEL if _morning else STATE_LABELS[index]


## 目前應顯示的時段圖示（day_phase_icons.png 的格索引）。
func phase_icon() -> int:
	return phase_icon_for(index, _morning)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("debug_cycle_daytime"):
		return
	cycle()
	get_viewport().set_input_as_handled()


static func next_index(current: int) -> int:
	return (current + 1) % STATE_NAMES.size()


static func lamp_strength_for(state_index: int) -> float:
	return LAMP_STRENGTHS[posmod(state_index, LAMP_STRENGTHS.size())]


## 純函式：時段索引（與是否為早晨）→ 圖示格索引。
static func phase_icon_for(state_index: int, morning: bool) -> int:
	if morning:
		return PHASE_ICON_MORNING
	match posmod(state_index, STATE_NAMES.size()):
		1:
			return PHASE_ICON_DUSK
		2:
			return PHASE_ICON_NIGHT
		_:
			return PHASE_ICON_DAY
