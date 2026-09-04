class_name TileLibrary
extends RefCounted
## 地圖圖例 → Tileset atlas 座標，以及 TileSet 的程式化建立。
##
## Atlas 配置（assets/tilesets/tide_root_town_tileset.png，18 欄 × 3 列，每格 32×32）：
##   第 0 列：地形（草、草崖、泥土、根泥、樹皮、亮樹皮、樹根、木板、拼木、石板、苔石、
##            淺水、中水、深水、沙灘、草水岸 ×2、草水角）
##   第 1 列：裝飾（花草、苜蓿、灌木、藤蔓 ×2、苔蘚、岩石 ×2、樹樁、蘑菇 ×2、花 ×5、荷葉、蘆葦）
##   第 2 列：Phase 1 合成（虛空、雲霧、樓梯、橋上欄、橋下欄、深色樹皮、深色木板）
##   第 3 列：水面動畫（淺水 0～3、深水 4～7、中水 8～11，各 4 幀，由 TileSet 動畫播放）
##   第 4 列：A11～A19 補件（虛空 ×9、雲霧、深色樹皮、樓梯、花草草地、綠色樹幹、木板、家庭屋地板、船長房地板）
##   第 5 列：Phase 4 洞窟（地面、岩壁、油漬地面、受光岩壁）

const TILE_SIZE := 32
const TILE_VECTOR := Vector2i(TILE_SIZE, TILE_SIZE)
const ATLAS_COLUMNS := 18
const ATLAS_ROWS := 6
const UPPER_ZONE_LAST_ROW := 11
const WATER_FRAMES := 4
const WATER_FRAME_SECONDS := 0.28

const GRASS := Vector2i(0, 0)
const GRASS_CLIFF := Vector2i(1, 0)
const DIRT := Vector2i(2, 0)
const ROOT_DIRT := Vector2i(3, 0)
const BARK := Vector2i(4, 0)
const ROOTS := Vector2i(6, 0)
const PLANKS := Vector2i(7, 0)
const PARQUET := Vector2i(8, 0)
const STONE := Vector2i(9, 0)
const MOSSY_STONE := Vector2i(10, 0)
const SAND := Vector2i(14, 0)
const BRIDGE_RAIL_TOP := Vector2i(3, 2)
const BRIDGE_RAIL_BOTTOM := Vector2i(4, 2)
## 第 3 列：動畫水面（座標為第一幀）
const WATER_SHALLOW := Vector2i(0, 3)
const WATER_DEEP := Vector2i(4, 3)
const WATER_MID := Vector2i(8, 3)
const WATER_TILES: Array[Vector2i] = [WATER_SHALLOW, WATER_DEEP, WATER_MID]
## 第 4 列：補件
const VOID_VARIANTS: Array[Vector2i] = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4),
]
## 虛空以帶星點的暗色 tile（0、1、2、7）為主，中央亮環（4）16 格只出現一次，避免整片天空太花。
const VOID_PATTERN: Array[int] = [1, 0, 7, 2, 1, 7, 0, 1, 2, 7, 1, 4, 0, 7, 2, 1]
const VOID := Vector2i(1, 4)
const MIST := Vector2i(9, 4)
const BARK_DARK := Vector2i(10, 4)
const STAIRS := Vector2i(11, 4)
const GRASS_FLOWERS := Vector2i(12, 4)
## 第 5 列：洞窟
const CAVE_FLOOR := Vector2i(0, 5)
const CAVE_WALL := Vector2i(1, 5)
const CAVE_FLOOR_GREASY := Vector2i(2, 5)
const CAVE_WALL_FACE := Vector2i(3, 5)
## legend_overrides 的特殊鍵：牆（#）下方為可走格時改用此 tile（牆面受光）。
const WALL_FACE_KEY := "#_face"

const DECO_FLOWERS := Vector2i(0, 1)
const DECO_CLOVER := Vector2i(1, 1)
const DECO_VINES := Vector2i(3, 1)
const DECO_VINES_FLOWERS := Vector2i(4, 1)
const DECO_MOSS := Vector2i(5, 1)
const DECO_MUSHROOM_RED := Vector2i(9, 1)
const DECO_MUSHROOM_ORANGE := Vector2i(10, 1)
const DECO_FLOWER_BLUE := Vector2i(11, 1)
const DECO_FLOWER_PINK := Vector2i(12, 1)
const DECO_FLOWER_ORANGE := Vector2i(13, 1)
const DECO_FLOWER_WHITE := Vector2i(14, 1)
const DECO_FLOWER_VIOLET := Vector2i(15, 1)
const DECO_LILY := Vector2i(16, 1)
const DECO_REEDS := Vector2i(17, 1)

const GRASS_DECORATIONS: Array[Vector2i] = [
	DECO_FLOWERS, DECO_CLOVER, DECO_MUSHROOM_RED, DECO_MUSHROOM_ORANGE,
	DECO_FLOWER_BLUE, DECO_FLOWER_PINK, DECO_FLOWER_ORANGE, DECO_FLOWER_WHITE, DECO_FLOWER_VIOLET,
]

const SIMPLE_LEGEND := {
	"g": GRASS,
	"d": DIRT,
	"r": ROOT_DIRT,
	"T": ROOTS,
	"p": PLANKS,
	"b": PARQUET,
	"s": STONE,
	"m": MOSSY_STONE,
	",": WATER_SHALLOW,
	"~": WATER_DEEP,
	"w": SAND,
	"c": MIST,
	"|": STAIRS,
}


## 依圖例字元與鄰居決定地形 atlas 座標。
## options：overrides（圖例字元 → Vector2i，室內場景用來換地板／牆面）、dark_wall_last_row（此列以上的牆用深色樹皮）。
static func ground_atlas_for(parser: MapParser, x: int, y: int, options: Dictionary = {}) -> Vector2i:
	var ch := parser.char_at(x, y)
	var overrides: Dictionary = options.get("overrides", {})
	if ch == "#" and overrides.has(WALL_FACE_KEY) and parser.is_walkable(x, y + 1):
		return overrides[WALL_FACE_KEY]
	if overrides.has(ch):
		return overrides[ch]
	if SIMPLE_LEGEND.has(ch):
		return SIMPLE_LEGEND[ch]
	match ch:
		".":
			return void_atlas_for(x, y)
		"=":
			return BRIDGE_RAIL_TOP if parser.char_at(x, y + 1) == "=" else BRIDGE_RAIL_BOTTOM
		"#":
			if y <= int(options.get("dark_wall_last_row", UPPER_ZONE_LAST_ROW)):
				return BARK_DARK
			if parser.is_walkable(x, y + 1):
				return GRASS_CLIFF
			return BARK
	push_warning("未知圖例 '%s'，以樹皮牆代替" % ch)
	return BARK


## 虛空依座標雜湊選取變體（確定性，不用亂數，讓截圖可重現）。
static func void_atlas_for(x: int, y: int) -> Vector2i:
	var index := VOID_PATTERN[posmod(x * 7 + y * 13, VOID_PATTERN.size())]
	return VOID_VARIANTS[index]


## 依圖例與亂數決定裝飾層 atlas 座標；回傳 Vector2i(-1, -1) 代表不放裝飾。
static func decoration_atlas_for(parser: MapParser, x: int, y: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Vector2i:
	var ch := parser.char_at(x, y)
	var roll := rng.randf()
	var dark_wall_last_row := int(options.get("dark_wall_last_row", UPPER_ZONE_LAST_ROW))
	match ch:
		"g":
			if roll < 0.14:
				return GRASS_DECORATIONS[rng.randi_range(0, GRASS_DECORATIONS.size() - 1)]
		"~":
			if roll < 0.08:
				return DECO_LILY
		",":
			var beside_land := parser.is_walkable(x - 1, y) or parser.is_walkable(x + 1, y)
			if beside_land and roll < 0.18:
				return DECO_REEDS
		"#":
			if y > dark_wall_last_row and parser.is_walkable(x, y + 1) and roll < 0.35:
				return DECO_VINES if roll < 0.25 else DECO_VINES_FLOWERS
			if roll > 0.92:
				return DECO_MOSS
	return Vector2i(-1, -1)


## 建立主城 TileSet：單一 atlas 來源，沒有物理層（碰撞交給獨立的 Collision 層）。
## 第 3 列的水面以 TileSet 內建動畫播放（同列橫向 4 幀），不需要任何腳本逐格更新。
static func build_ground_tileset(texture: Texture2D) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_VECTOR
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_VECTOR
	var available_rows := mini(ATLAS_ROWS, int(texture.get_height()) / TILE_SIZE)
	for row: int in range(available_rows):
		if row == WATER_SHALLOW.y:
			continue
		for col: int in range(ATLAS_COLUMNS):
			source.create_tile(Vector2i(col, row))
	if available_rows > WATER_SHALLOW.y:
		for coords: Vector2i in WATER_TILES:
			source.create_tile(coords)
			source.set_tile_animation_columns(coords, 0)
			source.set_tile_animation_frames_count(coords, WATER_FRAMES)
			for frame: int in range(WATER_FRAMES):
				source.set_tile_animation_frame_duration(coords, frame, WATER_FRAME_SECONDS)
	tile_set.add_source(source, 0)
	return tile_set


## 建立碰撞 TileSet：一個半透明紅色方塊，帶有整格碰撞多邊形。
static func build_collision_tileset() -> TileSet:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.2, 0.2, 0.35))
	for i: int in range(TILE_SIZE):
		image.set_pixel(i, 0, Color(1.0, 0.9, 0.2, 0.8))
		image.set_pixel(0, i, Color(1.0, 0.9, 0.2, 0.8))
	var texture := ImageTexture.create_from_image(image)
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_VECTOR
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_VECTOR
	source.create_tile(Vector2i.ZERO)
	# TileData 的物理層數量取決於所屬 TileSet，因此必須先 add_source 再加碰撞多邊形。
	tile_set.add_source(source, 0)
	var data: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	var half := float(TILE_SIZE) / 2.0
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))
	return tile_set


## 場景登錄表的 legend_overrides（字元 → [col, row]）轉成 Vector2i 對照表。
static func overrides_from_json(raw: Variant) -> Dictionary:
	var result := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	for ch: String in raw:
		var coords: Variant = raw[ch]
		if typeof(coords) == TYPE_ARRAY and coords.size() == 2:
			result[ch] = Vector2i(int(coords[0]), int(coords[1]))
	return result
