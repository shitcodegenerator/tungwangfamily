class_name MapParser
extends RefCounted
## 解析 ASCII 主城地圖。每個字元對應一個 32×32 格。
##
## 圖例：
##   可走：g 草地  d 泥土  r 樹根路  p 木板  b 樹枝木地板  s 石板  m 苔石  = 橋  | 樓梯  w 沙灘
##   不可走：# 樹皮牆  . 虛空  c 雲霧  ~ 深水  , 淺水  T 樹心底座

const WALKABLE_CHARS := "gdrpbsm=|w"
const SOLID_CHARS := "#.c~,T"

var rows: PackedStringArray = PackedStringArray()
var width: int = 0
var height: int = 0


static func from_text(text: String) -> MapParser:
	var parser := MapParser.new()
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges(false, true)
		if trimmed.is_empty():
			continue
		parser.rows.append(trimmed)
	parser.height = parser.rows.size()
	parser.width = parser.rows[0].length() if parser.height > 0 else 0
	return parser


static func load_from_file(path: String) -> MapParser:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("無法讀取地圖檔：%s" % path)
	return from_text(text)


## 回傳錯誤訊息清單；空陣列代表地圖格式正確。
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if height == 0:
		errors.append("地圖沒有任何列")
		return errors
	for y: int in range(height):
		if rows[y].length() != width:
			errors.append("第 %d 列寬度 %d，應為 %d" % [y, rows[y].length(), width])
		for x: int in range(rows[y].length()):
			var ch := rows[y][x]
			if not WALKABLE_CHARS.contains(ch) and not SOLID_CHARS.contains(ch):
				errors.append("第 %d 列第 %d 格有未知圖例 '%s'" % [y, x, ch])
	return errors


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func char_at(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "#"
	return rows[y][x]


func is_walkable(x: int, y: int) -> bool:
	return WALKABLE_CHARS.contains(char_at(x, y))


func is_solid(x: int, y: int) -> bool:
	return not is_walkable(x, y)


## 以 BFS 找出四方向最短路徑（含起點與終點）。找不到時回傳空陣列。
## extra_blocked 的 key 為 Vector2i，可用來加入道具碰撞佔用的格子。
func find_path(start: Vector2i, goal: Vector2i, extra_blocked: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not _passable(start, extra_blocked) or not _passable(goal, extra_blocked):
		return result
	var previous: Dictionary = {start: null}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == goal:
			var node: Variant = current
			while node != null:
				result.push_front(node)
				node = previous[node]
			return result
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next := current + offset
			if _passable(next, extra_blocked) and not previous.has(next):
				previous[next] = current
				queue.append(next)
	return result


func _passable(tile: Vector2i, extra_blocked: Dictionary) -> bool:
	return is_walkable(tile.x, tile.y) and not extra_blocked.has(tile)
