extends SceneTree
## 純邏輯單元測試，不需要視窗：
##   godot --headless --path . -s res://tests/run_tests.gd

const MapParserScript := preload("res://scripts/world/map_parser.gd")
const TileLibraryScript := preload("res://scripts/world/tile_library.gd")
const PartyTrailScript := preload("res://scripts/characters/party_trail.gd")
const PlayerScript := preload("res://scripts/characters/player_character.gd")
const FollowerScript := preload("res://scripts/characters/follower_character.gd")
const InteractableScript := preload("res://scripts/interaction/interactable.gd")
const InteractionControllerScript := preload("res://scripts/interaction/interaction_controller.gd")
const DialogueBoxScript := preload("res://scripts/ui/dialogue_box.gd")
const DayNightScript := preload("res://scripts/world/day_night.gd")
const TownPropScript := preload("res://scripts/props/town_prop.gd")
const GameStateScript := preload("res://scripts/state/game_state.gd")
const SaveManagerScript := preload("res://scripts/save/save_manager.gd")
const QuestManagerScript := preload("res://scripts/quest/quest_manager.gd")
const DialogueResolverScript := preload("res://scripts/dialogue/dialogue_resolver.gd")
const SceneRouterScript := preload("res://scripts/world/scene_router.gd")
const QuestHudScript := preload("res://scripts/ui/quest_hud.gd")

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	test_map_parses()
	test_map_paths()
	test_ground_legend()
	test_trail()
	test_facing()
	test_follower_velocity()
	test_sprite_frames()
	test_props_json()
	test_water_animation()
	test_interaction_targeting()
	test_dialogue_logic()
	test_day_night()
	test_dialogue_json()
	test_game_state_roundtrip()
	test_save_manager()
	test_quest_flow()
	test_dialogue_resolver()
	test_scene_registry()
	test_phase3_assets()
	print("--- %d 通過，%d 失敗 ---" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _assert(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS  ", label)
	else:
		_failed += 1
		print("FAIL  ", label)


func _load_map() -> MapParser:
	return MapParserScript.load_from_file("res://assets/maps/tide_root_town.txt")


func test_map_parses() -> void:
	var parser := _load_map()
	_assert(parser.width == 30 and parser.height == 36, "地圖尺寸為 30×36")
	_assert(parser.validate().is_empty(), "地圖圖例與寬度合法")
	_assert(parser.is_walkable(14, 29), "出生點 (14,29) 可走")
	_assert(parser.is_solid(0, 0) and parser.is_solid(-1, 5) and parser.is_solid(5, 99), "邊界與外側視為實心")


func test_map_paths() -> void:
	var parser := _load_map()
	var path := parser.find_path(Vector2i(14, 29), Vector2i(14, 1))
	_assert(not path.is_empty(), "出生點可走到上層頂端")
	var adjacent := true
	for i: int in range(1, path.size()):
		if (path[i] - path[i - 1]).length_squared() != 1:
			adjacent = false
	_assert(adjacent and path[0] == Vector2i(14, 29) and path[path.size() - 1] == Vector2i(14, 1), "路徑連續且首尾正確")
	_assert(parser.find_path(Vector2i(14, 29), Vector2i(0, 0)).is_empty(), "走向實心格回傳空路徑")
	var blocked := {}
	for x: int in range(13, 17):
		blocked[Vector2i(x, 23)] = true
	_assert(parser.find_path(Vector2i(14, 29), Vector2i(14, 22), blocked).is_empty(), "封住連接走廊後下層無法到中層")
	_assert(not parser.find_path(Vector2i(14, 29), Vector2i(26, 27), blocked).is_empty(), "封住走廊不影響下層內部路徑")


func test_ground_legend() -> void:
	var parser := _load_map()
	_assert(TileLibraryScript.ground_atlas_for(parser, 0, 0) == TileLibraryScript.BARK_DARK, "上層外牆使用深色樹皮")
	_assert(TileLibraryScript.ground_atlas_for(parser, 2, 14) == TileLibraryScript.GRASS_CLIFF, "牆下方為可走格時使用草崖")
	_assert(TileLibraryScript.ground_atlas_for(parser, 0, 16) == TileLibraryScript.BRIDGE_RAIL_TOP, "橋上列使用上欄杆")
	_assert(TileLibraryScript.ground_atlas_for(parser, 0, 17) == TileLibraryScript.BRIDGE_RAIL_BOTTOM, "橋下列使用下欄杆")
	_assert(TileLibraryScript.ground_atlas_for(parser, 14, 29) == TileLibraryScript.MOSSY_STONE, "廣場中心為苔石")
	_assert(TileLibraryScript.ground_atlas_for(parser, 2, 32) == TileLibraryScript.WATER_DEEP, "深水使用動畫水面第一幀")
	_assert(TileLibraryScript.VOID_VARIANTS.has(TileLibraryScript.ground_atlas_for(parser, 5, 1)), "虛空使用補件變體之一")
	_assert(TileLibraryScript.ground_atlas_for(parser, 5, 1) == TileLibraryScript.ground_atlas_for(parser, 5, 1), "虛空變體由座標決定（可重現）")
	var tile_set := TileLibraryScript.build_collision_tileset()
	_assert(tile_set.get_physics_layers_count() == 1, "碰撞 TileSet 有一層物理層")
	var source: TileSetAtlasSource = tile_set.get_source(0)
	_assert(source.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0) == 1, "碰撞 tile 具有整格多邊形")


func test_trail() -> void:
	var trail: PartyTrail = PartyTrailScript.new(4.0, 5)
	trail.record(Vector2(0, 0))
	trail.record(Vector2(1, 0))
	_assert(trail.points.size() == 1, "距離不足 spacing 時不記錄新點")
	for x: int in [10, 20, 30, 40, 50, 60]:
		trail.record(Vector2(x, 0))
	_assert(trail.points.size() == 5 and trail.points[0] == Vector2(20, 0), "超過容量時丟棄最舊的點")
	var line := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)])
	_assert(PartyTrailScript.point_behind_static(line, Vector2(30, 0), 15.0) == Vector2(15, 0), "沿軌跡往回 15px 得到正確插值點")
	_assert(PartyTrailScript.point_behind_static(line, Vector2(30, 0), 100.0) == Vector2(0, 0), "軌跡不夠長時回傳最舊的點")
	_assert(PartyTrailScript.point_behind_static(PackedVector2Array(), Vector2(7, 7), 10.0) == Vector2(7, 7), "空軌跡回傳目前位置")


func test_facing() -> void:
	_assert(PlayerScript.direction_to_facing(Vector2(1, 0.5), Vector2i.DOWN) == Vector2i.RIGHT, "水平分量較大取右")
	_assert(PlayerScript.direction_to_facing(Vector2(-0.2, -1), Vector2i.DOWN) == Vector2i.UP, "垂直分量較大取上")
	_assert(PlayerScript.direction_to_facing(Vector2.ZERO, Vector2i.LEFT) == Vector2i.LEFT, "零向量保留原方向")


func test_follower_velocity() -> void:
	var delta := 1.0 / 60.0
	var near := FollowerScript.decide_velocity(Vector2(0, 0), Vector2(10, 0), Vector2(5, 0), 96.0, delta)
	_assert(near == Vector2.ZERO, "與前一位太近時停下")
	var far := FollowerScript.decide_velocity(Vector2(0, 0), Vector2(200, 0), Vector2(160, 0), 96.0, delta)
	_assert(is_equal_approx(far.length(), 96.0 * FollowerScript.MAX_SPEED_SCALE) and far.x > 0.0, "距離過遠時加速追趕")
	var normal := FollowerScript.decide_velocity(Vector2(0, 0), Vector2(60, 0), Vector2(30, 0), 96.0, delta)
	_assert(is_equal_approx(normal.length(), 96.0), "一般距離以基本速度前進")
	var arriving := FollowerScript.decide_velocity(Vector2(0, 0), Vector2(60, 0), Vector2(0.5, 0), 96.0, delta)
	_assert(arriving.length() <= 0.5 / delta + 0.001, "接近目標時速度不超過剩餘距離")


func test_sprite_frames() -> void:
	var image := Image.create(192, 256, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var frames := PlayerScript.build_sprite_frames(texture)
	_assert(frames.get_animation_names().size() == 8, "四方向 × idle/walk 共 8 個動畫")
	_assert(frames.get_frame_count(&"walk_up") == 4 and frames.get_frame_count(&"idle_left") == 1, "walk 4 幀、idle 1 幀")
	var atlas: AtlasTexture = frames.get_frame_texture(&"walk_right", 3)
	_assert(atlas.region == Rect2(144, 128, 48, 64), "4 欄精靈表：walk_right 第 4 幀取自第 3 列第 4 欄")
	var wide := ImageTexture.create_from_image(Image.create(240, 256, false, Image.FORMAT_RGBA8))
	var wide_frames := PlayerScript.build_sprite_frames(wide)
	var idle: AtlasTexture = wide_frames.get_frame_texture(&"idle_left", 0)
	var walk: AtlasTexture = wide_frames.get_frame_texture(&"walk_right", 3)
	_assert(idle.region == Rect2(0, 64, 48, 64), "5 欄精靈表：站立取第 0 欄")
	_assert(walk.region == Rect2(192, 128, 48, 64), "5 欄精靈表：行走取第 1～4 欄")


func test_props_json() -> void:
	var text := FileAccess.get_file_as_string("res://assets/maps/tide_root_town_props.json")
	var data: Variant = JSON.parse_string(text)
	_assert(typeof(data) == TYPE_DICTIONARY, "道具 JSON 可解析")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var missing := PackedStringArray()
	for entry: Dictionary in data["props"]:
		var path := "res://assets/props/%s.png" % entry["texture"]
		if not FileAccess.file_exists(path):
			missing.append(path)
	_assert(missing.is_empty(), "所有道具貼圖都存在（缺少 %d 個）" % missing.size())
	_assert(data["spawn_points"].size() == 4 and data["exits"].size() == 3, "四個出生點、三個出口")
	for sheet: String in ["big_brother", "calm_brother", "sister_sheep", "younger_brother"]:
		var texture: Texture2D = load("res://assets/characters/playable/%s_sheet.png" % sheet)
		_assert(texture != null and texture.get_size() == Vector2(240, 256), "%s 精靈表為 240×256（站立 + 4 幀行走）" % sheet)


func test_water_animation() -> void:
	var image := Image.create(TileLibraryScript.ATLAS_COLUMNS * 32, TileLibraryScript.ATLAS_ROWS * 32, false, Image.FORMAT_RGBA8)
	var tile_set: TileSet = TileLibraryScript.build_ground_tileset(ImageTexture.create_from_image(image))
	var source: TileSetAtlasSource = tile_set.get_source(0)
	_assert(source.get_tile_animation_frames_count(TileLibraryScript.WATER_SHALLOW) == TileLibraryScript.WATER_FRAMES, "淺水 tile 有 4 幀動畫")
	_assert(source.get_tile_animation_frames_count(TileLibraryScript.WATER_DEEP) == TileLibraryScript.WATER_FRAMES, "深水 tile 有 4 幀動畫")
	_assert(source.has_tile(TileLibraryScript.MIST) and source.has_tile(TileLibraryScript.STAIRS), "補件列的雲霧與樓梯 tile 存在")
	_assert(not source.has_tile(Vector2i(1, 3)), "動畫幀格不會被建立成獨立 tile")
	_assert(TownPropScript.frame_at(0.45, 5.0, 4) == 2 and TownPropScript.frame_at(0.9, 5.0, 4) == 0, "道具幀索引依 fps 循環")


func test_interaction_targeting() -> void:
	var near: Interactable = InteractableScript.new()
	near.setup(&"near", "近", PackedStringArray(["a"]), Vector2(20, 20))
	near.position = Vector2(10, 0)
	var far: Interactable = InteractableScript.new()
	far.setup(&"far", "遠", PackedStringArray(["b"]), Vector2(20, 20))
	far.position = Vector2(50, 0)
	var decoy := Area2D.new()
	decoy.position = Vector2(1, 0)
	var picked: Interactable = InteractionControllerScript.pick_nearest([decoy, far, near], Vector2.ZERO)
	_assert(picked == near, "多個候選時挑選最近的 Interactable，忽略非 Interactable 的 Area2D")
	_assert(InteractionControllerScript.pick_nearest([decoy], Vector2.ZERO) == null, "沒有 Interactable 時回傳 null")
	_assert(near.collision_layer == 4 and near.collision_mask == 0 and near.monitorable, "Interactable 位於物理層 3 且可被偵測")
	var fired: Array[StringName] = []
	near.interacted.connect(func(node: Interactable) -> void: fired.append(node.interactable_id))
	near.interact()
	_assert(fired == [&"near"], "interact() 發出 interacted signal")
	_assert(near.prompt_position() == Vector2(10, -22), "提示位置預設在偵測矩形上方")
	for node: Node in [near, far, decoy]:
		node.free()


func test_dialogue_logic() -> void:
	_assert(DialogueBoxScript.visible_count(0.0, 28.0, 10) == 0, "逐字顯示：0 秒顯示 0 字")
	_assert(DialogueBoxScript.visible_count(0.5, 28.0, 10) == 10, "逐字顯示：不超過總字數")
	_assert(DialogueBoxScript.visible_count(0.1, 28.0, 10) == 2, "逐字顯示：0.1 秒顯示 2 字")


func test_day_night() -> void:
	_assert(DayNightScript.next_index(0) == 1 and DayNightScript.next_index(1) == 2 and DayNightScript.next_index(2) == 0, "日夜循環 白天→黃昏→夜晚→白天")
	_assert(DayNightScript.lamp_strength_for(0) == 0.0 and DayNightScript.lamp_strength_for(2) == 1.0, "白天燈籠熄滅、夜晚全亮")
	_assert(DayNightScript.STATE_COLORS.size() == 3 and DayNightScript.STATE_LABELS.size() == 3, "三種狀態各有顏色與標籤")


func test_dialogue_json() -> void:
	var dialogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/tide_root_town.json"))
	_assert(typeof(dialogue) == TYPE_DICTIONARY, "對話 JSON 可解析")
	var props: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tide_root_town_props.json"))
	if typeof(dialogue) != TYPE_DICTIONARY or typeof(props) != TYPE_DICTIONARY:
		return
	var ids: Array[String] = []
	for entry: Dictionary in props["props"]:
		if entry.has("interact"):
			ids.append(String(entry["interact"]))
	for entry: Dictionary in props["exits"]:
		if entry.has("interact"):
			ids.append(String(entry["interact"]))
	for entry: Dictionary in props.get("npcs", []):
		if entry.has("interact"):
			ids.append(String(entry["interact"]))
	var missing := PackedStringArray()
	for id: String in ids:
		var entry: Variant = dialogue.get(id)
		var variants: Array = entry if typeof(entry) == TYPE_ARRAY else [entry]
		for variant: Variant in variants:
			if typeof(variant) != TYPE_DICTIONARY or (variant as Dictionary).get("lines", []).is_empty():
				missing.append(id)
	_assert(ids.size() == 6 and missing.is_empty(), "主城六個互動物件都有對話內容（缺少 %d 個）" % missing.size())


func test_game_state_roundtrip() -> void:
	var state: GameState = GameStateScript.new()
	state.current_scene_id = "captain_room"
	state.return_scene_id = "tide_root_town"
	state.return_position = Vector2(816, 702)
	state.party_order = PackedStringArray(["sister_sheep", "big_brother"])
	state.party_positions = {"sister_sheep": Vector2(1, 2), "big_brother": Vector2(3, 4)}
	state.time_of_day = 2
	state.set_flag("demo_flag")
	state.quests = {"q": {"state": "active", "progress": {"a": 1}}}
	var restored: Dictionary = GameStateScript.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	var copy: GameState = restored["state"]
	_assert(copy != null and restored["error"] == "", "GameState 可序列化再還原")
	_assert(copy.current_scene_id == "captain_room" and copy.return_position == Vector2(816, 702), "場景與返回位置保留")
	_assert(copy.party_order == PackedStringArray(["sister_sheep", "big_brother"]) and copy.party_positions["big_brother"] == Vector2(3, 4), "隊伍順序與位置保留")
	_assert(copy.time_of_day == 2 and copy.has_flag("demo_flag") and copy.quests["q"]["progress"]["a"] == 1, "日夜、旗標與任務進度保留")
	_assert(GameStateScript.from_dict({"schema_version": 99, "current_scene_id": "x", "flags": {}, "quests": {}})["state"] == null, "版本過新的存檔被拒絕")
	_assert(GameStateScript.from_dict({"schema_version": 1})["state"] == null, "缺欄位的存檔被拒絕")


func test_save_manager() -> void:
	var path := "user://test_save.json"
	var state: GameState = GameStateScript.new()
	state.set_flag("saved_flag")
	_assert(SaveManagerScript.save_state(state, path) == "", "存檔寫入成功")
	var loaded: Dictionary = SaveManagerScript.load_state(path)
	_assert(loaded["state"] != null and (loaded["state"] as GameState).has_flag("saved_flag"), "存檔讀回並保留旗標")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var broken: Dictionary = SaveManagerScript.load_state(path)
	_assert(broken["state"] == null and not String(broken["error"]).is_empty(), "損毀存檔回傳錯誤而非崩潰")
	SaveManagerScript.delete_save(path)
	_assert(SaveManagerScript.load_state(path)["state"] == null, "不存在的存檔回傳錯誤")


func test_quest_flow() -> void:
	var quests: QuestManager = QuestManagerScript.new()
	quests.load_definitions("res://assets/quests/phase3_demo_quest.json")
	var state: GameState = GameStateScript.new()
	quests.bind(state)
	_assert(quests.quest_state("demo_town_orientation") == "available", "任務初始為可接取")
	_assert(quests.active_summary().is_empty(), "未接取時 HUD 摘要為空")
	quests.notify_interact("bulletin_board")
	_assert(quests.objective_progress("demo_town_orientation", "read_notice") == 0, "未接取時互動不會推進")
	quests.apply_actions([{"quest_start": "demo_town_orientation"}])
	_assert(quests.quest_state("demo_town_orientation") == "active", "對話動作可啟動任務")
	quests.notify_interact("family_table")
	_assert(quests.objective_progress("demo_town_orientation", "visit_family_table") == 0, "目標依序完成，跳過的目標不推進")
	quests.notify_interact("bulletin_board")
	quests.notify_interact("family_table")
	quests.notify_interact("captain_chart_table")
	_assert(quests.is_objective_current("demo_town_orientation", "report"), "三個地點完成後目前目標為回報")
	_assert(quests.active_summary() == "向市集老龜回報", "HUD 摘要顯示目前目標")
	quests.notify_interact("old_turtle")
	_assert(quests.quest_state("demo_town_orientation") == "completed" and state.has_flag("demo_orientation_complete"), "回報後任務完成並發放旗標")
	_assert(QuestHudScript.build_log_text(quests.list_quests()).contains("✔ 閱讀公告欄"), "任務日誌文字標記已完成目標")
	quests.free()


func test_dialogue_resolver() -> void:
	var quests: QuestManager = QuestManagerScript.new()
	quests.load_definitions("res://assets/quests/phase3_demo_quest.json")
	var state: GameState = GameStateScript.new()
	quests.bind(state)
	var entry: Array = [
		{"requires": {"quest": {"demo_town_orientation": "completed"}}, "speaker": "A", "lines": ["done"]},
		{"requires": {"flags": ["seen"]}, "speaker": "B", "lines": ["seen"]},
		{"speaker": "C", "lines": ["default"], "on_complete": [{"set_flag": "seen"}]},
	]
	var first: Dictionary = DialogueResolverScript.resolve(entry, state, quests)
	_assert(first["speaker"] == "C" and first["lines"][0] == "default", "沒有條件成立時使用最後一個預設版本")
	quests.apply_actions(first["on_complete"])
	_assert(DialogueResolverScript.resolve(entry, state, quests)["speaker"] == "B", "旗標條件成立時選到對應版本")
	_assert(DialogueResolverScript.resolve(entry, null, null)["speaker"] == "C", "沒有狀態時退回預設版本")
	_assert(DialogueResolverScript.resolve({"lines": ["x"]}, state, quests)["lines"][0] == "x", "單一字典直接使用")
	_assert(DialogueResolverScript.resolve(null, state, quests)["lines"][0] == "……", "空資料退回省略號")
	_assert(not DialogueResolverScript.requires_met({"not_flags": ["seen"]}, state, quests), "not_flags 條件")
	quests.free()


func test_scene_registry() -> void:
	var registry: Dictionary = SceneRouterScript.parse_registry(FileAccess.get_file_as_string("res://assets/maps/scenes.json"))
	_assert(registry.has("tide_root_town") and registry.has("family_home") and registry.has("captain_room"), "場景登錄表含主城與兩個室內")
	var missing := PackedStringArray()
	for scene_id: String in registry:
		for key: String in ["map", "props", "dialogue"]:
			if not FileAccess.file_exists(String(registry[scene_id][key])):
				missing.append(String(registry[scene_id][key]))
		var parser: MapParser = MapParserScript.load_from_file(String(registry[scene_id]["map"]))
		_assert(parser.validate().is_empty(), "%s 地圖圖例合法" % scene_id)
		var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(registry[scene_id]["props"])))
		for entry_name: String in props.get("entries", {}):
			for tile: Array in props["entries"][entry_name]:
				if not parser.is_walkable(int(tile[0]), int(tile[1])):
					missing.append("%s entry %s" % [scene_id, entry_name])
	_assert(missing.is_empty(), "所有場景資料檔存在且入口可站（缺 %d）" % missing.size())


func test_phase3_assets() -> void:
	for npc: String in ["king_penguin_captain", "old_turtle"]:
		var sheet: Texture2D = load("res://assets/characters/npcs/%s_sheet.png" % npc)
		_assert(sheet != null and sheet.get_size() == Vector2(240, 256), "%s 精靈表為 240×256" % npc)
		var data: CharacterData = load("res://assets/characters/npcs/%s.tres" % npc)
		_assert(data != null and data.sprite_sheet == sheet, "%s CharacterData 指向精靈表" % npc)
	var portraits := 0
	for id: String in ["big_brother", "calm_brother", "sister_sheep", "younger_brother", "king_penguin_captain", "old_turtle"]:
		var portrait: Texture2D = load("res://assets/portraits/%s.png" % id)
		if portrait != null and portrait.get_size() == Vector2(48, 48):
			portraits += 1
	_assert(portraits == 6, "六張 48×48 頭像（實際 %d）" % portraits)
