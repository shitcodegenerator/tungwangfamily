class_name DayNightController
extends CanvasModulate
## 日夜狀態最小版本：只用 CanvasModulate 改變整個世界畫布的色調，不重建地圖、不影響碰撞。
## F5（debug_cycle_daytime）循環 白天 → 黃昏 → 夜晚 → 白天；燈籠光暈強度由 lamp_strength_for 提供。

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

var index: int = 0
var _tween: Tween


func _ready() -> void:
	color = STATE_COLORS[index]


func cycle() -> void:
	set_state(next_index(index))


func set_state(new_index: int, instant: bool = false) -> void:
	index = posmod(new_index, STATE_NAMES.size())
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		color = STATE_COLORS[index]
	else:
		_tween = create_tween()
		_tween.tween_property(self, "color", STATE_COLORS[index], TRANSITION_SECONDS)
	state_changed.emit(STATE_NAMES[index], index)


func state_name() -> StringName:
	return STATE_NAMES[index]


func state_label() -> String:
	return STATE_LABELS[index]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("debug_cycle_daytime"):
		return
	cycle()
	get_viewport().set_input_as_handled()


static func next_index(current: int) -> int:
	return (current + 1) % STATE_NAMES.size()


static func lamp_strength_for(state_index: int) -> float:
	return LAMP_STRENGTHS[posmod(state_index, LAMP_STRENGTHS.size())]
