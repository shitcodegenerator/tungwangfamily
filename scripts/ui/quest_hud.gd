class_name QuestHud
extends CanvasLayer
## 最小任務 UI：右上角一行目前目標、J 開關任務日誌、任務開始／完成時的短暫提示。
## 對話中、轉場中或 Esc 面板開啟時不搶輸入（由 Main 透過 set_input_blocked 告知）。
## Phase 7：日誌文字放在 ScrollContainer 內，內容超出面板時可用滑鼠滾輪捲動，或用 <／>（quest_log_prev_page／
## quest_log_next_page）切換上下頁；不用方向鍵，因為方向鍵同時是角色移動。捲動位置只是 UI 暫態（每次打開回到頂端），
## 不進 GameState 或存檔。日誌不抓取 Control 焦點，因此角色移動、互動與 F5～F7 照舊由各自的節點處理。

const TOAST_SECONDS := 2.6

@onready var objective_label: Label = $Objective
@onready var log_panel: PanelContainer = $LogPanel
@onready var log_scroll: ScrollContainer = $LogPanel/Margin/Scroll
@onready var log_label: Label = $LogPanel/Margin/Scroll/Log
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
	quests.clue_added.connect(_on_clue_added)
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
		display_log_text(build_log_text(quests.list_quests(), quests.list_clues()))


## 直接指定日誌內文（refresh 與測試用）；捲動範圍由 ScrollContainer 依內容高度自動更新。
func display_log_text(text: String) -> void:
	log_label.text = text


func log_text() -> String:
	return log_label.text


## 打開／關閉日誌。輸入鎖定時不能打開（回傳 false）；每次打開都回到頂端。
func set_log_open(open: bool) -> bool:
	if open and input_blocked:
		return false
	log_panel.visible = open
	if open:
		refresh()
		log_scroll.scroll_vertical = 0
	return true


func toggle_log() -> bool:
	return set_log_open(not log_panel.visible)


## 切換上下頁：一頁 = 目前可視高度；超出範圍由 ScrollContainer 夾住。direction 1 下一頁、-1 上一頁。
func page_log(direction: int) -> void:
	log_scroll.scroll_vertical = log_scroll.scroll_vertical + direction * page_height()


## 一頁的像素高度（ScrollContainer 目前的可視高度）。
func page_height() -> int:
	return maxi(1, int(log_scroll.get_v_scroll_bar().page))


func log_scroll_offset() -> int:
	return log_scroll.scroll_vertical


## 內容高度超過可視範圍時才可捲動（此時 ScrollContainer 也才會顯示捲軸）。
func can_scroll_log() -> bool:
	return _max_scroll() > 0


func is_log_at_end() -> bool:
	return log_scroll.scroll_vertical >= _max_scroll()


func _max_scroll() -> int:
	var bar := log_scroll.get_v_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


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
	if input_blocked:
		return
	if event.is_action_pressed("quest_log") and not event.is_echo():
		toggle_log()
		_mark_handled()
	elif log_panel.visible and event.is_action_pressed("quest_log_next_page") and not event.is_echo():
		page_log(1)
		_mark_handled()
	elif log_panel.visible and event.is_action_pressed("quest_log_prev_page") and not event.is_echo():
		page_log(-1)
		_mark_handled()


func _mark_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_quest_started(quest_id: String) -> void:
	show_toast("接受任務：%s" % _title(quest_id))


func _on_quest_completed(quest_id: String) -> void:
	show_toast("任務完成：%s" % _title(quest_id))


func _on_clue_added(clue_id: String) -> void:
	show_toast("新線索：%s" % quests.clue_title(clue_id))
	refresh()


func _title(quest_id: String) -> String:
	return String(quests.definitions.get(quest_id, {}).get("title", quest_id))


## clues：已取得的線索（Phase 6），有才顯示「[線索]」段落。
static func build_log_text(entries: Array[Dictionary], clues: Array[Dictionary] = []) -> String:
	if entries.is_empty() and clues.is_empty():
		return "[任務日誌]\n目前沒有任務。"
	var lines := PackedStringArray(["[任務日誌]　J：關閉　<／>：上下頁"])
	for entry: Dictionary in entries:
		lines.append("")
		lines.append("%s　（%s）" % [entry["title"], QuestManager.state_label(String(entry["state"]))])
		if not String(entry.get("description", "")).is_empty():
			lines.append("　" + String(entry["description"]))
		for objective: Dictionary in entry["objectives"]:
			var mark := "✔" if objective["done"] else ("▶" if objective["current"] else "・")
			lines.append("　%s %s" % [mark, objective["text"]])
	if not clues.is_empty():
		lines.append("")
		lines.append("[線索]")
		for clue: Dictionary in clues:
			lines.append("　・%s" % clue["title"])
			if not String(clue.get("text", "")).is_empty():
				lines.append("　　%s" % clue["text"])
	return "\n".join(lines)
