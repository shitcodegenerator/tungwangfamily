class_name DayHud
extends CanvasLayer
## 畫面上方中央的一小塊：時段圖示（assets/ui/day_phase_icons.png 4 格 24×24：早晨、白天、黃昏、夜晚）+「第 N 天・白天」。
## 只讀 GameState.day 與 DayNightController 的狀態；不處理任何輸入。
## 位置避開：愛心 (10,8)、Boss 血條 (6,22)、右上任務目標、置中提示（y 40）。

const ICON_SHEET := preload("res://assets/ui/day_phase_icons.png")
const ICON_SIZE := 24
const ICON_COUNT := 4

var state: GameState
var day_night: DayNightController

var _panel: PanelContainer
var _icon: TextureRect
var _label: Label


func _ready() -> void:
	layer = 15
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.03, 0.85)
	style.border_color = Color(0.85, 0.65, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 6.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.texture = icon_texture(DayNightController.PHASE_ICON_DAY)
	row.add_child(_icon)
	_label = Label.new()
	_label.name = "Text"
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	refresh()


func bind(game_state: GameState, daytime: DayNightController) -> void:
	if state != null and state.day_advanced.is_connected(_on_day_advanced):
		state.day_advanced.disconnect(_on_day_advanced)
	state = game_state
	day_night = daytime
	state.day_advanced.connect(_on_day_advanced)
	if not day_night.state_changed.is_connected(_on_state_changed):
		day_night.state_changed.connect(_on_state_changed)
	refresh()


func refresh() -> void:
	if _label == null:
		return
	var day := state.day if state != null else 1
	var phase_label := day_night.state_label() if day_night != null else DayNightController.STATE_LABELS[0]
	var icon_index := day_night.phase_icon() if day_night != null else DayNightController.PHASE_ICON_DAY
	_label.text = text_for(day, phase_label)
	_icon.texture = icon_texture(icon_index)


func _process(_delta: float) -> void:
	# 早晨漸變結束時 DayNight 不會再發 signal，這裡以低成本方式同步標籤
	if day_night != null and _label != null and _label.text != text_for(state.day if state != null else 1, day_night.state_label()):
		refresh()


func _on_day_advanced(_day: int) -> void:
	refresh()


func _on_state_changed(_state_name: StringName, _index: int) -> void:
	refresh()


static func text_for(day: int, phase_label: String) -> String:
	return "第 %d 天・%s" % [day, phase_label]


static func icon_texture(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_SHEET
	atlas.region = Rect2(clampi(index, 0, ICON_COUNT - 1) * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	return atlas
