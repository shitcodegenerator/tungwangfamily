class_name TownWorld
extends Node2D
## 潮根城主城：由 ASCII 地圖與道具 JSON 在執行期建立 TileMapLayer、碰撞、裝飾、道具、標記與可互動物件。
## 日夜只透過 apply_daytime 調整燈籠光暈，地圖與碰撞不會重建。

const TILE_SIZE := TileLibrary.TILE_SIZE
const MAP_TEXT_PATH := "res://assets/maps/tide_root_town.txt"
const PROPS_JSON_PATH := "res://assets/maps/tide_root_town_props.json"
const DIALOGUE_JSON_PATH := "res://assets/dialogue/tide_root_town.json"
const INTERACTABLE_SCRIPT := preload("res://scripts/interaction/interactable.gd")
## 沒有指定 interact_size 時，互動偵測矩形 = 碰撞盒往外擴的量。
const INTERACT_PADDING := Vector2(24.0, 28.0)
const PROP_TEXTURE_DIR := "res://assets/props/"
const TILESET_TEXTURE := preload("res://assets/tilesets/tide_root_town_tileset.png")
const PROP_SCENE := preload("res://scenes/props/town_prop.tscn")
const DECORATION_SEED := 20260904
const HINT_FONT := preload("res://assets/ui/fusion_pixel_12px_zh_hant.ttf")

@onready var ground: TileMapLayer = $Ground
@onready var decoration: TileMapLayer = $Decoration
@onready var collision: TileMapLayer = $Collision
@onready var props: Node2D = $Props
@onready var exits: Node2D = $Exits
@onready var spawn_points: Node2D = $SpawnPoints
@onready var interactables: Node2D = $Interactables

var parser: MapParser
var map_data: Dictionary = {}
var dialogue_data: Dictionary = {}
var lamp_props: Array[TownProp] = []
var world_rect: Rect2 = Rect2()
## 道具碰撞佔用的格子（key: Vector2i），供路徑規劃與測試使用。
var prop_blocked_tiles: Dictionary = {}


func _ready() -> void:
	_load_data()
	_build_ground()
	_build_collision()
	_build_decoration()
	_build_props()
	_build_spawn_points()
	_build_exits()
	collision.visible = false


func _load_data() -> void:
	parser = MapParser.load_from_file(MAP_TEXT_PATH)
	var errors := parser.validate()
	for message: String in errors:
		push_error("地圖錯誤：%s" % message)
	var json_text := FileAccess.get_file_as_string(PROPS_JSON_PATH)
	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("道具設定 JSON 解析失敗：%s" % PROPS_JSON_PATH)
		parsed = {"props": [], "spawn_points": [], "exits": [], "zones": [], "connectors": []}
	map_data = parsed
	world_rect = Rect2(Vector2.ZERO, Vector2(parser.width, parser.height) * TILE_SIZE)
	var dialogue_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_JSON_PATH))
	if typeof(dialogue_parsed) != TYPE_DICTIONARY:
		push_error("對話 JSON 解析失敗：%s" % DIALOGUE_JSON_PATH)
		dialogue_parsed = {}
	dialogue_data = dialogue_parsed


func _build_ground() -> void:
	ground.tile_set = TileLibrary.build_ground_tileset(TILESET_TEXTURE)
	for y: int in range(parser.height):
		for x: int in range(parser.width):
			ground.set_cell(Vector2i(x, y), 0, TileLibrary.ground_atlas_for(parser, x, y))


func _build_collision() -> void:
	collision.tile_set = TileLibrary.build_collision_tileset()
	for y: int in range(parser.height):
		for x: int in range(parser.width):
			if parser.is_solid(x, y):
				collision.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


func _build_decoration() -> void:
	decoration.tile_set = ground.tile_set
	var rng := RandomNumberGenerator.new()
	rng.seed = DECORATION_SEED
	for y: int in range(parser.height):
		for x: int in range(parser.width):
			var atlas := TileLibrary.decoration_atlas_for(parser, x, y, rng)
			if atlas.x >= 0:
				decoration.set_cell(Vector2i(x, y), 0, atlas)


func _build_props() -> void:
	for entry: Dictionary in map_data.get("props", []):
		var texture_name: String = entry.get("texture", "")
		var texture: Texture2D = load(PROP_TEXTURE_DIR + texture_name + ".png")
		if texture == null:
			push_error("找不到道具貼圖：%s" % texture_name)
			continue
		var prop: TownProp = PROP_SCENE.instantiate()
		prop.name = texture_name.to_pascal_case() + str(props.get_child_count())
		prop.position = Vector2(entry.get("x", 0.0), entry.get("y", 0.0))
		var collision_size := Vector2.ZERO
		var raw_collision: Variant = entry.get("collision")
		if typeof(raw_collision) == TYPE_ARRAY and raw_collision.size() == 2:
			collision_size = Vector2(raw_collision[0], raw_collision[1])
		props.add_child(prop)
		prop.setup(texture, collision_size, float(entry.get("alpha", 1.0)), int(entry.get("z_bias", 0)), entry)
		_register_prop_blocking(prop.position, collision_size)
		if prop.has_glow():
			lamp_props.append(prop)
		if entry.has("interact"):
			var size := _vector_from(entry.get("interact_size"), collision_size + INTERACT_PADDING)
			var center := prop.position + Vector2(0.0, -size.y / 2.0 + 4.0)
			_add_interactable(StringName(String(entry["interact"])), center, size, entry)


## 建立可互動 Area2D（物理層 3）；對話內容從 dialogue JSON 依 id 取得。
func _add_interactable(id: StringName, center: Vector2, size: Vector2, entry: Dictionary) -> Interactable:
	var node: Interactable = INTERACTABLE_SCRIPT.new()
	var speaker := ""
	var lines := PackedStringArray()
	var dialogue: Variant = dialogue_data.get(String(id))
	if typeof(dialogue) == TYPE_DICTIONARY:
		speaker = String(dialogue.get("speaker", ""))
		for line: Variant in dialogue.get("lines", []):
			lines.append(String(line))
	else:
		push_error("對話 JSON 缺少 id：%s" % id)
		lines.append("……")
	node.position = center
	var prompt := Vector2.INF
	if entry.has("prompt_offset"):
		prompt = _vector_from(entry.get("prompt_offset"), Vector2.INF)
	node.setup(id, speaker, lines, size, prompt)
	interactables.add_child(node)
	return node


static func _vector_from(raw: Variant, fallback: Vector2) -> Vector2:
	if typeof(raw) == TYPE_ARRAY and raw.size() == 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


## 任何與碰撞盒相交（內縮 1px，避免剛好貼齊格線的誤判）的格子都視為不可路徑規劃。
func _register_prop_blocking(bottom_center: Vector2, size: Vector2) -> void:
	if size == Vector2.ZERO:
		return
	var rect := Rect2(bottom_center - Vector2(size.x / 2.0, size.y), size).grow(-1.0)
	var min_tile := world_to_tile(rect.position)
	var max_tile := world_to_tile(rect.end)
	for y: int in range(min_tile.y, max_tile.y + 1):
		for x: int in range(min_tile.x, max_tile.x + 1):
			var tile_rect := Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE))
			if rect.intersects(tile_rect):
				prop_blocked_tiles[Vector2i(x, y)] = true


func _build_spawn_points() -> void:
	var index := 0
	for raw: Array in map_data.get("spawn_points", []):
		var marker := Marker2D.new()
		marker.name = "Spawn%d" % index
		marker.position = tile_to_world(Vector2i(int(raw[0]), int(raw[1])))
		spawn_points.add_child(marker)
		index += 1


func _build_exits() -> void:
	for entry: Dictionary in map_data.get("exits", []):
		var tile_raw: Array = entry.get("tile", [0, 0])
		var marker := Marker2D.new()
		marker.name = String(entry.get("name", "exit"))
		marker.position = tile_to_world(Vector2i(int(tile_raw[0]), int(tile_raw[1])))
		marker.set_meta("label", entry.get("label", ""))
		marker.set_meta("open", false)
		var offset_raw: Array = entry.get("label_offset", [0, 0])
		marker.add_child(_make_hint_label(String(entry.get("label", "")), Vector2(offset_raw[0], offset_raw[1])))
		exits.add_child(marker)
		if entry.has("interact"):
			var center := _vector_from(entry.get("interact_center"), marker.position)
			var size := _vector_from(entry.get("interact_size"), Vector2(64.0, 64.0))
			_add_interactable(StringName(String(entry["interact"])), center, size, entry)
	for entry: Dictionary in map_data.get("connectors", []):
		var tile_raw: Array = entry.get("tile", [0, 0])
		var marker := Marker2D.new()
		marker.name = String(entry.get("name", "connector"))
		marker.position = tile_to_world(Vector2i(int(tile_raw[0]), int(tile_raw[1])))
		marker.set_meta("connector", true)
		exits.add_child(marker)


func _make_hint_label(text: String, offset: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 20
	var settings := LabelSettings.new()
	settings.font = HINT_FONT
	settings.font_size = 12
	settings.font_color = Color(1.0, 0.95, 0.8)
	settings.outline_size = 3
	settings.outline_color = Color(0.1, 0.05, 0.0, 0.9)
	label.label_settings = settings
	label.size = Vector2(160, 16)
	label.position = offset + Vector2(-80, -8)
	return label


# --- 對外查詢 ---------------------------------------------------------------

func get_spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child: Node in spawn_points.get_children():
		if child is Marker2D:
			result.append((child as Marker2D).global_position)
	return result


func get_interactables() -> Array[Interactable]:
	var result: Array[Interactable] = []
	for child: Node in interactables.get_children():
		if child is Interactable:
			result.append(child as Interactable)
	return result


## 日夜切換：只調整燈籠光暈，地圖、碰撞與道具位置都不變。
func apply_daytime(state_index: int) -> void:
	var strength := DayNightController.lamp_strength_for(state_index)
	for lamp: TownProp in lamp_props:
		lamp.set_glow_strength(strength)


## 指定區段（zones 名稱）的世界座標矩形；找不到時回傳整張地圖。
func get_zone_rect(zone_name: String) -> Rect2:
	for zone: Dictionary in map_data.get("zones", []):
		if String(zone.get("name", "")) == zone_name:
			var rows: Array = zone.get("rows", [0, 0])
			var top := int(rows[0]) * TILE_SIZE
			var bottom := (int(rows[1]) + 1) * TILE_SIZE
			return Rect2(0.0, top, world_rect.size.x, bottom - top)
	return world_rect


func get_exit_markers() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	for child: Node in exits.get_children():
		if child is Marker2D:
			result.append(child as Marker2D)
	return result


func get_zone_name(world_position: Vector2) -> String:
	var row := world_to_tile(world_position).y
	for zone: Dictionary in map_data.get("zones", []):
		var rows: Array = zone.get("rows", [0, 0])
		if row >= int(rows[0]) and row <= int(rows[1]):
			return String(zone.get("name", "?"))
	return "主城外"


func tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)


func world_to_tile(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE_SIZE), floori(world_position.y / TILE_SIZE))


func is_tile_walkable(tile: Vector2i) -> bool:
	return parser.is_walkable(tile.x, tile.y) and not prop_blocked_tiles.has(tile)


func find_tile_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return parser.find_path(start, goal, prop_blocked_tiles)


func set_collision_debug_visible(visible_now: bool) -> void:
	collision.visible = visible_now
