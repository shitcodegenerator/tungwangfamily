class_name DebugHUD
extends CanvasLayer
## 除錯 HUD：顯示目前操控角色、座標、所在區段、隊伍順序、日夜狀態與測試提示。
## Esc 切換測試資訊面板；面板開啟時按 Q 離開遊戲；F1 切換碰撞格顯示。

const HELP_TEXT := """[Phase 2 測試資訊]
WASD／方向鍵：移動　　E：互動／推進對話
1／2／3／4：切換哥哥／冷靜哥／妹妹／弟弟　　Tab：循環切換
F5：切換 白天 → 黃昏 → 夜晚　　F1：顯示碰撞格
Esc：關閉此面板　　Q（面板開啟時）：離開遊戲

可互動：公告欄、樹心、左側橋頭、右側船港、上方樹冠門。
靠近時會出現「E」提示，按 E 開啟對話；對話中無法移動與切換角色。
左橋頭、右船港、上樹冠皆為封鎖出口，可走到但不可離開。"""

@onready var status_label: Label = $Margin/Status
@onready var status_panel: PanelContainer = $Margin
@onready var help_panel: PanelContainer = $HelpPanel
@onready var help_label: Label = $HelpPanel/Margin/Help

var party: PartyController
var world: TownWorld
var day_night: DayNightController
var _collision_visible: bool = false


func _ready() -> void:
	help_label.text = HELP_TEXT
	help_panel.visible = false


func bind(party_controller: PartyController, town: TownWorld, daytime: DayNightController = null) -> void:
	party = party_controller
	world = town
	day_night = daytime


## 對話框顯示時隱藏狀態列，避免與對話框重疊。
func set_status_visible(visible_now: bool) -> void:
	status_panel.visible = visible_now


func _process(_delta: float) -> void:
	if party == null or world == null or party.get_leader() == null:
		return
	var leader := party.get_leader()
	var tile := world.world_to_tile(leader.global_position)
	var daytime_text := day_night.state_label() if day_night != null else "—"
	status_label.text = "操控：%s [%d]   座標 (%d, %d)   格 (%d, %d)   %s\n隊伍：%s   切換：%d   時段：%s   Esc：測試資訊" % [
		leader.data.display_name, party.get_roster_index(leader) + 1,
		int(leader.global_position.x), int(leader.global_position.y),
		tile.x, tile.y, world.get_zone_name(leader.global_position),
		party.describe_order(), party.switch_count, daytime_text,
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		help_panel.visible = not help_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_quit") and help_panel.visible:
		get_tree().quit()
	elif event.is_action_pressed("debug_toggle_collision") and world != null:
		_collision_visible = not _collision_visible
		world.set_collision_debug_visible(_collision_visible)
		get_viewport().set_input_as_handled()
