class_name QuestHud
extends CanvasLayer
## 最小任務 UI：右上角一行目前目標、J 開關任務日誌、任務開始／完成時的短暫提示。
## 對話中、轉場中或 Esc 面板開啟時不搶輸入（由 Main 透過 set_input_blocked 告知）。

const TOAST_SECONDS := 2.6

@onready var objective_label: Label = $Objective
@onready var log_panel: PanelContainer = $LogPanel
@onready var log_label: Label = $LogPanel/Margin/Log
@onready var toast_label: Label = $Toast

var quests: QuestManager
var input_blocked: bool = false
var _toast_time: float = 0.0


func _ready() -> void:
	log_panel.visible = false
	toast_label.visible = false
	objective_label.visible = false


func bind(quest_manager: QuestManager) -> void:
	quests = quest_manager
	quests.quest_started.connect(_on_quest_started)
	quests.quest_updated.connect(func(_id: String) -> void: refresh())
	quests.quest_completed.connect(_on_quest_completed)
	refresh()


func set_input_blocked(blocked: bool) -> void:
	input_blocked = blocked
	if blocked:
		log_panel.visible = false


func refresh() -> void:
	if quests == null:
		return
	var summary := quests.active_summary()
	objective_label.text = "目標：" + summary
	objective_label.visible = not summary.is_empty()
	if log_panel.visible:
		log_label.text = build_log_text(quests.list_quests())


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	_toast_time = TOAST_SECONDS


func is_log_open() -> bool:
	return log_panel.visible


func _process(delta: float) -> void:
	if not toast_label.visible:
		return
	_toast_time -= delta
	if _toast_time <= 0.0:
		toast_label.visible = false
	elif _toast_time < 0.6:
		toast_label.modulate.a = _toast_time / 0.6


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked or event.is_echo() or not event.is_action_pressed("quest_log"):
		return
	log_panel.visible = not log_panel.visible
	refresh()
	get_viewport().set_input_as_handled()


func _on_quest_started(quest_id: String) -> void:
	show_toast("接受任務：%s" % _title(quest_id))


func _on_quest_completed(quest_id: String) -> void:
	show_toast("任務完成：%s" % _title(quest_id))


func _title(quest_id: String) -> String:
	return String(quests.definitions.get(quest_id, {}).get("title", quest_id))


static func build_log_text(entries: Array[Dictionary]) -> String:
	if entries.is_empty():
		return "[任務日誌]\n目前沒有任務。"
	var lines := PackedStringArray(["[任務日誌]　J：關閉"])
	for entry: Dictionary in entries:
		lines.append("")
		lines.append("%s　（%s）" % [entry["title"], QuestManager.state_label(String(entry["state"]))])
		if not String(entry.get("description", "")).is_empty():
			lines.append("　" + String(entry["description"]))
		for objective: Dictionary in entry["objectives"]:
			var mark := "✔" if objective["done"] else ("▶" if objective["current"] else "・")
			lines.append("　%s %s" % [mark, objective["text"]])
	return "\n".join(lines)
