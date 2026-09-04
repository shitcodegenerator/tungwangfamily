class_name SaveManager
extends RefCounted
## JSON 存檔／讀檔：user://save_01.json。讀檔失敗回傳錯誤訊息而不是崩潰，由呼叫端決定是否保留目前狀態。

const SAVE_PATH := "user://save_01.json"


## 成功回傳空字串，失敗回傳可顯示的錯誤訊息。
static func save_state(state: GameState, path: String = SAVE_PATH) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "無法寫入存檔（%s）" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(state.to_dict(), "  "))
	file.close()
	return ""


## 回傳 {"state": GameState 或 null, "error": String}。
static func load_state(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": null, "error": "找不到存檔"}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"state": null, "error": "存檔內容損毀，無法解析"}
	return GameState.from_dict(parsed)


static func has_save(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
