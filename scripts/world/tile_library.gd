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
##   第 5 列：Phase 4.6 洞窟正式 tile（由 assets/tiles/fried_food_cave_tiles_32.png 4×2 複製：
##            濕苔地面 A、濕苔地面 B、岩壁面、岩壁頂、左上角、右上角、內凹角、晶簇 overlay）
##   第 6～7 列：Phase 5 城鎮視覺更新（tools/build_assets_phase5.py 由 town_visual_refresh_tiles_32.png 去格框後複製，
##            atlas (c, r) → tileset (c + 8×(r%2), 6 + r/2)）：
##            第 6 列 0～7 草地 A／B／花草、泥土、石板 A／B、木板、深水（靜態）；8～15 石板路 edge N/S/W/E、corner NW/NE/SW/SE
##            第 7 列 0～7 水岸 edge N/S/W/E、corner NW/NE/SW/SE；8～15 草崖、樹根牆、南北橋面、橋側、水面動畫 4 幀；
##            16～17 東西向木橋上列／下列。tile_style = "town_refresh" 時由 town_refresh_atlas_for 依鄰居選 tile。

const TILE_SIZE := 32
const TILE_VECTOR := Vector2i(TILE_SIZE, TILE_SIZE)
const ATLAS_COLUMNS := 18
const ATLAS_ROWS := 8
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
## 第 5 列：洞窟（scenes.json 的 tile_style = "cave" 走 cave_atlas_for，不用 legend_overrides）
const CAVE_FLOOR_A := Vector2i(0, 5)
const CAVE_FLOOR_B := Vector2i(1, 5)
const CAVE_WALL_FACE := Vector2i(2, 5)
const CAVE_WALL_TOP := Vector2i(3, 5)
const CAVE_CORNER_TL := Vector2i(4, 5)
const CAVE_CORNER_TR := Vector2i(5, 5)
const CAVE_CORNER_BL := Vector2i(6, 5)
const CAVE_CRYSTAL := Vector2i(7, 5)
## 地面 A／B 交錯的雜湊週期：5 格裡 3 格 A、2 格 B，避免棋盤格。
const CAVE_FLOOR_PATTERN: Array[bool] = [true, false, true, true, false]
## 晶簇 overlay 出現在「與地面相鄰的牆」上的機率。
const CAVE_CRYSTAL_CHANCE := 0.22
## legend_overrides 的特殊鍵：牆（#）下方為可走格時改用此 tile（牆面受光）。
const WALL_FACE_KEY := "#_face"
const TILE_STYLE_KEY := "tile_style"
const TILE_STYLE_CAVE := "cave"
const TILE_STYLE_TOWN_REFRESH := "town_refresh"
## scenes.json 可用 tile_style_rows: [first, last] 只把樣式套在部分列（Phase 5 先做下層樹根廣場的垂直切片）。
const TILE_STYLE_ROWS_KEY := "tile_style_rows"

## 第 6～7 列：Phase 5 城鎮視覺更新（TR_ = town refresh）
const TR_GRASS_A := Vector2i(0, 6)
const TR_GRASS_B := Vector2i(1, 6)
const TR_GRASS_FLOWERS := Vector2i(2, 6)
const TR_EARTH := Vector2i(3, 6)
const TR_STONE_A := Vector2i(4, 6)
const TR_STONE_B := Vector2i(5, 6)
const TR_PLANKS := Vector2i(6, 6)
const TR_DEEP_WATER := Vector2i(7, 6)
const TR_PATH_EDGE_N := Vector2i(8, 6)
const TR_PATH_EDGE_S := Vector2i(9, 6)
const TR_PATH_EDGE_W := Vector2i(10, 6)
const TR_PATH_EDGE_E := Vector2i(11, 6)
const TR_PATH_CORNER_NW := Vector2i(12, 6)
const TR_PATH_CORNER_NE := Vector2i(13, 6)
const TR_PATH_CORNER_SW := Vector2i(14, 6)
const TR_PATH_CORNER_SE := Vector2i(15, 6)
const TR_SHORE_EDGE_N := Vector2i(0, 7)
const TR_SHORE_EDGE_S := Vector2i(1, 7)
const TR_SHORE_EDGE_W := Vector2i(2, 7)
const TR_SHORE_EDGE_E := Vector2i(3, 7)
const TR_SHORE_CORNER_NW := Vector2i(4, 7)
const TR_SHORE_CORNER_NE := Vector2i(5, 7)
const TR_SHORE_CORNER_SW := Vector2i(6, 7)
const TR_SHORE_CORNER_SE := Vector2i(7, 7)
const TR_GRASS_CLIFF := Vector2i(8, 7)
const TR_ROOT_WALL := Vector2i(9, 7)
const TR_BRIDGE_NS := Vector2i(10, 7)
const TR_BRIDGE_SIDE := Vector2i(11, 7)
## 水面動畫第一幀（第 12～15 欄 4 幀，由 TileSet 動畫播放）
const TR_WATER := Vector2i(12, 7)
const TR_BRIDGE_EW_TOP := Vector2i(16, 7)
const TR_BRIDGE_EW_BOTTOM := Vector2i(17, 7)
## 草地變體週期：7 格裡 4 格 A、2 格 B、1 格花草，依座標雜湊選取（可重現）。
const TR_GRASS_PATTERN: Array[Vector2i] = [TR_GRASS_A, TR_GRASS_A, TR_GRASS_B, TR_GRASS_A, TR_GRASS_FLOWERS, TR_GRASS_A, TR_GRASS_B]
const TR_STONE_PATTERN: Array[Vector2i] = [TR_STONE_A, TR_STONE_B, TR_STONE_A, TR_STONE_A, TR_STONE_B]
## 鄰居位元：石板路的邊緣看「草地」鄰居，水岸看「陸地」鄰居（橋與樓梯不算陸地，橋旁的水維持水面）。
const NEIGHBOR_N := 1
const NEIGHBOR_S := 2
const NEIGHBOR_W := 4
const NEIGHBOR_E := 8
const GRASS_CHARS := "g"
const LAND_CHARS := "gsmdrbw"

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
	if String(options.get(TILE_STYLE_KEY, "")) == TILE_STYLE_CAVE:
		return cave_atlas_for(parser, x, y)
	if uses_town_refresh(options, y):
		return town_refresh_atlas_for(parser, x, y)
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


## 洞窟樣式：牆下方是地面 → 岩壁面；地圖左上、右上角 → 轉角；其餘牆 → 岩壁頂。
## 可走格：'s'（原油漬格）固定用地面 B，其他依座標雜湊在 A／B 之間交錯。
static func cave_atlas_for(parser: MapParser, x: int, y: int) -> Vector2i:
	var ch := parser.char_at(x, y)
	if ch == "#":
		if parser.is_walkable(x, y + 1):
			return CAVE_WALL_FACE
		if x == 0 and y == 0:
			return CAVE_CORNER_TL
		if x == parser.width - 1 and y == 0:
			return CAVE_CORNER_TR
		return CAVE_WALL_TOP
	if ch == "s":
		return CAVE_FLOOR_B
	return CAVE_FLOOR_A if CAVE_FLOOR_PATTERN[posmod(x * 3 + y * 7, CAVE_FLOOR_PATTERN.size())] else CAVE_FLOOR_B


## 洞窟裝飾：只在「與可走格相鄰的牆」上放晶簇 overlay（裝飾層，不改碰撞）。
static func cave_decoration_for(parser: MapParser, x: int, y: int, rng: RandomNumberGenerator) -> Vector2i:
	if parser.char_at(x, y) != "#":
		return Vector2i(-1, -1)
	var beside_floor := parser.is_walkable(x, y + 1) or parser.is_walkable(x, y - 1) or parser.is_walkable(x - 1, y) or parser.is_walkable(x + 1, y)
	if beside_floor and rng.randf() < CAVE_CRYSTAL_CHANCE:
		return CAVE_CRYSTAL
	return Vector2i(-1, -1)


## tile_style = "town_refresh" 且（沒有 tile_style_rows，或 y 落在 [first, last] 內）時使用城鎮更新 tile。
static func uses_town_refresh(options: Dictionary, y: int) -> bool:
	if String(options.get(TILE_STYLE_KEY, "")) != TILE_STYLE_TOWN_REFRESH:
		return false
	var rows: Variant = options.get(TILE_STYLE_ROWS_KEY, [])
	if typeof(rows) != TYPE_ARRAY or rows.size() != 2:
		return true
	return y >= int(rows[0]) and y <= int(rows[1])


## 城鎮更新樣式：依圖例與四方鄰居選 tile（不用固定座標）。
##   g → 草地變體；s／m → 石板，與草地相鄰的邊用 edge／corner（草地那側）；
##   ,／~ → 水，與陸地相鄰的邊用水岸 edge／corner（陸地那側），其餘 ~ 為動畫水面、, 為靜態深水；
##   = → 東西向木橋：上方不是橋的列用上列、下方不是橋的列用下列；
##   # → 下方可走用草崖，其餘樹根牆；| 與其他圖例退回舊 atlas。
static func town_refresh_atlas_for(parser: MapParser, x: int, y: int) -> Vector2i:
	var ch := parser.char_at(x, y)
	match ch:
		"g":
			return TR_GRASS_PATTERN[posmod(x * 5 + y * 11, TR_GRASS_PATTERN.size())]
		"s", "m":
			var mask := neighbor_mask(parser, x, y, GRASS_CHARS)
			var base: Vector2i = TR_STONE_B if ch == "m" else TR_STONE_PATTERN[posmod(x * 3 + y * 7, TR_STONE_PATTERN.size())]
			return edge_tile_for(mask, base, [
				TR_PATH_EDGE_N, TR_PATH_EDGE_S, TR_PATH_EDGE_W, TR_PATH_EDGE_E,
				TR_PATH_CORNER_NW, TR_PATH_CORNER_NE, TR_PATH_CORNER_SW, TR_PATH_CORNER_SE,
			])
		",", "~":
			var mask := neighbor_mask(parser, x, y, LAND_CHARS)
			var base: Vector2i = TR_WATER if ch == "~" else TR_DEEP_WATER
			return edge_tile_for(mask, base, [
				TR_SHORE_EDGE_N, TR_SHORE_EDGE_S, TR_SHORE_EDGE_W, TR_SHORE_EDGE_E,
				TR_SHORE_CORNER_NW, TR_SHORE_CORNER_NE, TR_SHORE_CORNER_SW, TR_SHORE_CORNER_SE,
			])
		"=":
			if parser.char_at(x, y - 1) != "=":
				return TR_BRIDGE_EW_TOP
			if parser.char_at(x, y + 1) != "=":
				return TR_BRIDGE_EW_BOTTOM
			return TR_PLANKS
		"#":
			return TR_GRASS_CLIFF if parser.is_walkable(x, y + 1) else TR_ROOT_WALL
		"d":
			return TR_EARTH
		"p", "b":
			return TR_PLANKS
	if SIMPLE_LEGEND.has(ch):
		return SIMPLE_LEGEND[ch]
	return TR_ROOT_WALL


## 四方鄰居中屬於 chars 的位元組合（N=1、S=2、W=4、E=8）。
static func neighbor_mask(parser: MapParser, x: int, y: int, chars: String) -> int:
	var mask := 0
	if chars.contains(parser.char_at(x, y - 1)):
		mask |= NEIGHBOR_N
	if chars.contains(parser.char_at(x, y + 1)):
		mask |= NEIGHBOR_S
	if chars.contains(parser.char_at(x - 1, y)):
		mask |= NEIGHBOR_W
	if chars.contains(parser.char_at(x + 1, y)):
		mask |= NEIGHBOR_E
	return mask


## 依鄰居位元選 edge／corner：tiles = [N, S, W, E, NW, NE, SW, SE]。
## 兩個相鄰方向 → corner；單一方向 → edge；沒有鄰居或只有對邊（走廊）→ base。
static func edge_tile_for(mask: int, base: Vector2i, tiles: Array[Vector2i]) -> Vector2i:
	var n := (mask & NEIGHBOR_N) != 0
	var s := (mask & NEIGHBOR_S) != 0
	var w := (mask & NEIGHBOR_W) != 0
	var e := (mask & NEIGHBOR_E) != 0
	if n and w:
		return tiles[4]
	if n and e:
		return tiles[5]
	if s and w:
		return tiles[6]
	if s and e:
		return tiles[7]
	if n:
		return tiles[0]
	if s:
		return tiles[1]
	if w:
		return tiles[2]
	if e:
		return tiles[3]
	return base


## 虛空依座標雜湊選取變體（確定性，不用亂數，讓截圖可重現）。
static func void_atlas_for(x: int, y: int) -> Vector2i:
	var index := VOID_PATTERN[posmod(x * 7 + y * 13, VOID_PATTERN.size())]
	return VOID_VARIANTS[index]


## 依圖例與亂數決定裝飾層 atlas 座標；回傳 Vector2i(-1, -1) 代表不放裝飾。
static func decoration_atlas_for(parser: MapParser, x: int, y: int, rng: RandomNumberGenerator, options: Dictionary = {}) -> Vector2i:
	if String(options.get(TILE_STYLE_KEY, "")) == TILE_STYLE_CAVE:
		return cave_decoration_for(parser, x, y, rng)
	if uses_town_refresh(options, y):
		# 城鎮更新 tile 自帶花草變體，不疊舊 atlas 的裝飾（風格不同）
		return Vector2i(-1, -1)
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
			var coords := Vector2i(col, row)
			# 第 7 列第 13～15 欄是城鎮更新水面的第 2～4 幀，由 TR_WATER 的動畫涵蓋
			if row == TR_WATER.y and col > TR_WATER.x and col < TR_WATER.x + WATER_FRAMES:
				continue
			source.create_tile(coords)
	if available_rows > WATER_SHALLOW.y:
		for coords: Vector2i in WATER_TILES:
			source.create_tile(coords)
			_animate_water(source, coords)
	if available_rows > TR_WATER.y:
		_animate_water(source, TR_WATER)
	tile_set.add_source(source, 0)
	return tile_set


static func _animate_water(source: TileSetAtlasSource, coords: Vector2i) -> void:
	source.set_tile_animation_columns(coords, 0)
	source.set_tile_animation_frames_count(coords, WATER_FRAMES)
	for frame: int in range(WATER_FRAMES):
		source.set_tile_animation_frame_duration(coords, frame, WATER_FRAME_SECONDS)


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
