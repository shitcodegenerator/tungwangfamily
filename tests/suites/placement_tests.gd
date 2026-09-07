extends RefCounted
## 擺放與圖例：tile_legend.json 是唯一來源，各樣式對每個字元都有正式 mapping（Phase 8.5 起新測試分檔；由 tests/run_tests.gd 的 SUITES 載入，t 是 runner，用 t._assert）。

const MapParserScript := preload("res://scripts/world/map_parser.gd")
const TileLibraryScript := preload("res://scripts/world/tile_library.gd")

## Phase 8.5-E：圖例唯一來源 tile_legend.json；每個樣式對每個登錄字元都有正式 mapping（不落到 fallback）。
func run(t: SceneTree) -> void:
	var legend: Dictionary = MapParserScript.load_legend()
	var chars: Dictionary = legend.get("chars", {})
	t._assert(chars.size() >= 16 and MapParserScript.WALKABLE_CHARS.length() + MapParserScript.SOLID_CHARS.length() == chars.size(), "MapParser 的可走／不可走字元完全來自 tile_legend.json（%d 字元）" % chars.size())
	t._assert(MapParserScript.WALKABLE_CHARS.contains("g") and MapParserScript.WALKABLE_CHARS.contains("|") and MapParserScript.SOLID_CHARS.contains("#") and MapParserScript.SOLID_CHARS.contains("c") and not MapParserScript.WALKABLE_CHARS.contains("."), "圖例可走性：g／| 可走，#／c／. 不可走")
	t._assert(MapParserScript.legend_supports("c", "town_refresh") and MapParserScript.legend_supports("s", "cave") and not MapParserScript.legend_supports("~", "cave") and not MapParserScript.legend_supports("?", "default"), "legend_supports 依 styles 判定；cave 沒有水、未知字元一律 false")
	var tl := TileLibraryScript
	var fallback_hits: Array[String] = []
	for ch: String in chars:
		for style: String in legend.get("styles", []):
			if not MapParserScript.legend_supports(ch, style):
				continue
			var parser := MapParserScript.from_text("###\n#%s#\n###" % ch)
			var options := {tl.TILE_STYLE_KEY: "" if style == "default" else style, tl.TILE_STYLE_ROWS_KEY: []}
			var atlas := tl.ground_atlas_for(parser, 1, 1, options)
			var bad := atlas.x < 0 or atlas.y < 0 or atlas.x >= tl.ATLAS_COLUMNS or atlas.y >= tl.ATLAS_ROWS
			if style == "town_refresh" and ch != "#" and atlas == tl.TR_ROOT_WALL:
				bad = true
			if style == "default" and ch != "#" and atlas == tl.BARK:
				bad = true
			if bad:
				fallback_hits.append("%s/%s" % [ch, style])
	t._assert(fallback_hits.is_empty(), "每個登錄字元在其支援的樣式都有正式 mapping（落到 fallback：%s）" % ", ".join(fallback_hits))
	var upper_map := MapParserScript.from_text("#####\n#c.T#\n#.cb#\n#####")
	var refresh := {tl.TILE_STYLE_KEY: "town_refresh", tl.TILE_STYLE_ROWS_KEY: []}
	t._assert(tl.UP_CANOPY_FILL.has(tl.ground_atlas_for(upper_map, 1, 1, refresh)) or tl.UP_CANOPY_EDGE_S.has(tl.ground_atlas_for(upper_map, 1, 1, refresh)), "c 的地面畫樹冠")
	t._assert(tl.UP_ROOT_CAP.has(tl.ground_atlas_for(upper_map, 3, 1, refresh)), "T 上方是牆 → 根牆頂")
