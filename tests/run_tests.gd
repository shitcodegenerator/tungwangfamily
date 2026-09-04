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
const ProjectileScript := preload("res://scripts/battle/thrown_projectile.gd")
const WingScript := preload("res://scripts/battle/chicken_wing.gd")
const BossScript := preload("res://scripts/battle/fried_food_demon.gd")
const CarryableItemScript := preload("res://scripts/battle/carryable_item.gd")
const DialogueManagerScript := preload("res://scripts/ui/dialogue_manager.gd")
const BattleHudScript := preload("res://scripts/ui/battle_hud.gd")

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
	test_game_state_v2()
	test_inventory_and_events()
	test_phase4_dialogue()
	test_projectile_math()
	test_wing_and_boss_math()
	test_phase4_data()
	test_phase4_assets()
	test_phase46_sheets()
	test_phase46_logic()
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
	_assert(ids.size() == 8 and missing.is_empty(), "主城八個互動物件都有對話內容（缺少 %d 個）" % missing.size())


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


func test_game_state_v2() -> void:
	var state: GameState = GameStateScript.new()
	state.add_item("chunhsiang_noodles")
	state.pet_id = "cc_penguin"
	_assert(state.has_item("chunhsiang_noodles") and state.item_count("chunhsiang_noodles") == 1, "背包加入物品")
	var restored: GameState = GameStateScript.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))["state"]
	_assert(restored != null and restored.has_item("chunhsiang_noodles") and restored.pet_id == "cc_penguin", "v2 存檔保留物品與寵物")
	_assert(restored.schema_version == 2 and state.to_dict()["schema_version"] == 2, "schema_version 為 2")
	var legacy := {"schema_version": 1, "current_scene_id": "tide_root_town", "flags": {"demo": true}, "quests": {}}
	var migrated: Dictionary = GameStateScript.from_dict(legacy)
	var old: GameState = migrated["state"]
	_assert(old != null and old.inventory.is_empty() and old.pet_id == "" and old.has_flag("demo"), "v1 存檔以空背包與無寵物補齊")
	_assert(not state.remove_item("chunhsiang_noodles", 2) and state.remove_item("chunhsiang_noodles") and not state.has_item("chunhsiang_noodles"), "扣除物品：不足時拒絕，足夠時移除")
	_assert(GameStateScript.from_dict({"schema_version": 3, "current_scene_id": "x", "flags": {}, "quests": {}})["state"] == null, "版本 3 存檔被拒絕")


func test_inventory_and_events() -> void:
	var quests: QuestManager = QuestManagerScript.new()
	quests.load_all_definitions()
	var state: GameState = GameStateScript.new()
	quests.bind(state)
	_assert(quests.definitions.has("cc_fried_food_battle") and quests.definitions.has("demo_town_orientation"), "同時載入 Phase 3 與 Phase 4 任務")
	quests.apply_actions([{"quest_start": "cc_fried_food_battle"}, {"set_flag": "cc_found"}])
	_assert(quests.is_objective_current("cc_fried_food_battle", "get_noodles"), "CC 任務啟動後第一個目標是取麵")
	quests.notify_event("cc_noodle_delivered")
	_assert(quests.is_objective_current("cc_fried_food_battle", "get_noodles"), "還沒取麵時交付事件不推進（依序完成）")
	quests.apply_actions([{"give_item": "chunhsiang_noodles"}])
	quests.notify_interact("grandma_turtle")
	_assert(state.has_item("chunhsiang_noodles") and quests.is_objective_current("cc_fried_food_battle", "deliver_noodles"), "阿嬤互動給麵並推進到交付")
	quests.apply_actions([{"take_item": "chunhsiang_noodles"}, {"quest_event": "cc_noodle_delivered"}])
	_assert(not state.has_item("chunhsiang_noodles") and quests.is_objective_current("cc_fried_food_battle", "defeat_demon"), "交付後扣麵並推進到擊倒 Boss")
	quests.notify_event("fried_food_demon_defeated")
	quests.notify_event("cc_joined")
	_assert(quests.quest_state("cc_fried_food_battle") == "completed" and state.has_flag("cc_quest_complete"), "Boss 倒下與 CC 加入事件後任務完成")
	quests.free()


func test_phase4_dialogue() -> void:
	var quests: QuestManager = QuestManagerScript.new()
	quests.load_all_definitions()
	var state: GameState = GameStateScript.new()
	quests.bind(state)
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/tide_root_town.json"))
	var cc: Array = dialogue["cc_penguin"]
	var first: Dictionary = DialogueResolverScript.resolve(cc, state, quests)
	_assert(first["on_complete"].size() == 2 and first["on_complete"][0].has("quest_start"), "初次見 CC：啟動任務")
	quests.apply_actions(first["on_complete"])
	var no_noodles: Dictionary = DialogueResolverScript.resolve(cc, state, quests)
	_assert(no_noodles["on_complete"].is_empty() and not _has_action(no_noodles["on_complete"], "teleport"), "沒有麵時 CC 不傳送")
	state.add_item("chunhsiang_noodles")
	var deliver: Dictionary = DialogueResolverScript.resolve(cc, state, quests)
	_assert(_has_action(deliver["on_complete"], "teleport") and _has_action(deliver["on_complete"], "take_item"), "有麵時 CC 收麵並傳送")
	quests.apply_actions(deliver["on_complete"])
	var retry: Dictionary = DialogueResolverScript.resolve(cc, state, quests)
	_assert(_has_action(retry["on_complete"], "teleport") and not _has_action(retry["on_complete"], "take_item"), "失敗後再談 CC：重新傳送、不再收麵")
	state.set_flag("cc_fried_food_demon_defeated")
	var join: Dictionary = DialogueResolverScript.resolve(cc, state, quests)
	_assert(DialogueManagerScript.has_valid_options(join["choice"]) and join["choice"]["options"].size() == 2, "擊倒後 CC 對話帶接受／拒絕兩個選項")
	var reject: Dictionary = join["choice"]["options"][1]
	_assert(String(reject["lines"][0]).contains("💢") and String(reject["lines"][1]).contains("你怎麼忍心!!!"), "拒絕分支含 💢 與指定 OS")
	var both_join := true
	for option: Dictionary in join["choice"]["options"]:
		if not _has_action(option["on_complete"], "set_flag") or String(option["on_complete"][0]["set_flag"]) != "cc_joined":
			both_join = false
	_assert(both_join, "接受與拒絕最後都設定 cc_joined")
	var ends_with_desu := true
	for variant: Dictionary in cc:
		for line: Variant in variant.get("lines", []):
			var trimmed := String(line).rstrip("。！!")
			if not trimmed.ends_with("です") and not String(line).contains("💢") and not String(line).contains("OS"):
				ends_with_desu = false
	_assert(ends_with_desu, "CC 台詞句尾皆為「です」")
	_assert(not DialogueManagerScript.has_valid_options({}) and not DialogueManagerScript.has_valid_options({"options": [{"x": 1}]}), "無效的 choice 被忽略")
	_assert(DialogueBoxScript.choice_line("接受", true) == "▶ 接受" and DialogueBoxScript.choice_line("拒絕", false).ends_with("拒絕"), "選項列文字帶選取標記")
	var grandma: Array = dialogue["grandma_turtle"]
	var fresh_state: GameState = GameStateScript.new()
	var fresh: QuestManager = QuestManagerScript.new()
	fresh.load_all_definitions()
	fresh.bind(fresh_state)
	_assert(not _has_action(DialogueResolverScript.resolve(grandma, fresh_state, fresh)["on_complete"], "give_item"), "任務未啟動時阿嬤不給麵")
	fresh.apply_actions([{"quest_start": "cc_fried_food_battle"}])
	_assert(_has_action(DialogueResolverScript.resolve(grandma, fresh_state, fresh)["on_complete"], "give_item"), "目標為取麵時阿嬤給麵")
	fresh.apply_actions([{"give_item": "chunhsiang_noodles"}])
	fresh.notify_interact("grandma_turtle")
	_assert(not _has_action(DialogueResolverScript.resolve(grandma, fresh_state, fresh)["on_complete"], "give_item"), "拿到麵後阿嬤不再給麵")
	fresh.free()
	quests.free()


func _has_action(actions: Array, key: String) -> bool:
	for action: Variant in actions:
		if typeof(action) == TYPE_DICTIONARY and action.has(key):
			return true
	return false


func test_projectile_math() -> void:
	_assert(is_equal_approx(ProjectileScript.arc_height(0.5, 26.0), 26.0) and ProjectileScript.arc_height(0.0, 26.0) == 0.0 and ProjectileScript.arc_height(1.0, 26.0) == 0.0, "拋物線中點最高、兩端為 0")
	var open_field := func(_p: Vector2) -> bool: return true
	var landing: Vector2 = ProjectileScript.landing_point(Vector2(100, 100), Vector2.UP, 150.0, 8.0, open_field)
	_assert(landing.distance_to(Vector2(100, 100 - 144)) < 0.01, "空曠時落點在射程盡頭（8px 步進）")
	var wall_at_40 := func(p: Vector2) -> bool: return p.y > 60.0
	var short: Vector2 = ProjectileScript.landing_point(Vector2(100, 100), Vector2.UP, 150.0, 8.0, wall_at_40)
	_assert(short.y == 68.0, "面對牆時射程截短到牆前")
	var blocked := func(_p: Vector2) -> bool: return false
	_assert(ProjectileScript.landing_point(Vector2(5, 5), Vector2.RIGHT, 100.0, 8.0, blocked) == Vector2(5, 5), "第一步就是牆時落在原地")


func test_wing_and_boss_math() -> void:
	var step: Dictionary = WingScript.simulate_step(0.0, -170.0, 1.0 / 60.0)
	_assert(step["height"] > 0.0 and not step["bounced"], "炸雞翅起跳後高度上升")
	var falling: Dictionary = WingScript.simulate_step(0.5, 120.0, 1.0 / 60.0)
	_assert(falling["height"] == 0.0 and falling["bounced"] and falling["speed"] < 0.0, "落地時反彈一次")
	var resting: Dictionary = WingScript.simulate_step(0.1, 10.0, 1.0 / 60.0)
	_assert(resting["height"] == 0.0 and resting["speed"] == 0.0 and not resting["bounced"], "速度太慢時停在地面")
	_assert(BossScript.hp_after_hit(5, 1) == 4 and BossScript.hp_after_hit(1, 1) == 0 and BossScript.hp_after_hit(0, 1) == 0, "Boss 生命扣到 0 為止")
	_assert(BattleHudScript.summary(3, 5) == "♥×3　炸物魔王 5", "戰鬥 HUD 摘要")


func test_phase4_data() -> void:
	var catalog: Dictionary = CarryableItemScript.catalog()
	var same_damage := true
	for id: String in ["vegetable_bundle", "green_tea", "water_flask"]:
		if not catalog.has(id) or CarryableItemScript.damage_for(id) != 1 or String(catalog[id]["effect_type"]) != "plain_damage":
			same_damage = false
	_assert(same_damage, "三種投擲物皆為 plain_damage、傷害 1")
	var registry: Dictionary = SceneRouterScript.parse_registry(FileAccess.get_file_as_string("res://assets/maps/scenes.json"))
	_assert(registry.has("fried_food_cave") and int(registry["fried_food_cave"]["battle"]["boss_hp"]) == 5, "洞窟場景登錄且 Boss 生命 5")
	var parser: MapParser = MapParserScript.load_from_file("res://assets/maps/fried_food_cave.txt")
	var cave_options := {TileLibraryScript.TILE_STYLE_KEY: String(registry["fried_food_cave"].get("tile_style", ""))}
	_assert(String(cave_options[TileLibraryScript.TILE_STYLE_KEY]) == "cave", "洞窟場景使用 tile_style = cave")
	_assert(TileLibraryScript.ground_atlas_for(parser, 5, 1, cave_options) == TileLibraryScript.CAVE_WALL_FACE, "地面上方的牆使用岩壁面")
	_assert(TileLibraryScript.ground_atlas_for(parser, 5, 0, cave_options) == TileLibraryScript.CAVE_WALL_TOP, "第二層牆使用岩壁頂")
	_assert(TileLibraryScript.ground_atlas_for(parser, 0, 0, cave_options) == TileLibraryScript.CAVE_CORNER_TL and TileLibraryScript.ground_atlas_for(parser, parser.width - 1, 0, cave_options) == TileLibraryScript.CAVE_CORNER_TR, "地圖左上、右上角使用轉角 tile")
	var floor_a := 0
	var floor_b := 0
	for x: int in range(2, 22):
		var atlas: Vector2i = TileLibraryScript.ground_atlas_for(parser, x, 3, cave_options)
		floor_a += 1 if atlas == TileLibraryScript.CAVE_FLOOR_A else 0
		floor_b += 1 if atlas == TileLibraryScript.CAVE_FLOOR_B else 0
	_assert(floor_a > 0 and floor_b > 0 and floor_a + floor_b == 20, "洞窟地面在 A／B 兩款之間交錯（A %d、B %d）" % [floor_a, floor_b])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var crystals := 0
	for x: int in range(parser.width):
		for y: int in range(parser.height):
			var deco: Vector2i = TileLibraryScript.decoration_atlas_for(parser, x, y, rng, cave_options)
			if deco == TileLibraryScript.CAVE_CRYSTAL:
				crystals += 1
				if parser.is_walkable(x, y):
					crystals = -999
	_assert(crystals > 0, "晶簇只放在與地面相鄰的牆上，不占可走格（%d 個）" % crystals)
	var battle_cfg: Dictionary = registry["fried_food_cave"]["battle"]
	_assert(float(battle_cfg["min_y"]) >= 4 * 32 and float(battle_cfg["y"]) >= float(battle_cfg["min_y"]), "Boss 活動上限離地圖上緣至少 2 格（min_y %s）" % battle_cfg["min_y"])
	var younger: CharacterData = load("res://assets/characters/playable/younger_brother.tres")
	var big: CharacterData = load("res://assets/characters/playable/big_brother.tres")
	_assert(younger.controlled_speed > younger.walk_speed and big.controlled_speed == 0.0, "弟弟被操控時速度較快，其他角色不變")
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tide_root_town_props.json"))
	var cc_entry := {}
	for npc: Dictionary in props["npcs"]:
		if npc["id"] == "cc_penguin":
			cc_entry = npc
	_assert(cc_entry.has("requires") and cc_entry["requires"]["not_flags"] == ["cc_joined"], "CC NPC 只在未加入時出現在早餐攤旁")
	var state: GameState = GameStateScript.new()
	_assert(DialogueResolverScript.requires_met(cc_entry["requires"], state, null), "未加入時 CC 出現")
	state.set_flag("cc_joined")
	_assert(not DialogueResolverScript.requires_met(cc_entry["requires"], state, null), "加入後 CC 不再出現")


func test_phase4_assets() -> void:
	var cc: Texture2D = load("res://assets/characters/pets/cc_penguin_sheet.png")
	_assert(cc != null and cc.get_size() == Vector2(240, 256), "CC 精靈表為 240×256")
	var boss: Texture2D = load("res://assets/characters/boss/fried_food_demon_sheet.png")
	_assert(boss != null and boss.get_size() == Vector2(480, 80), "炸物魔王精靈表為 6 幀 × 80×80")
	var items := 0
	for id: String in ["vegetable_bundle", "green_tea", "water_flask"]:
		var texture: Texture2D = CarryableItemScript.texture_for(id)
		if texture != null and texture.get_size() == Vector2(112, 28):
			items += 1
	_assert(items == 3, "三種投擲物各為 4 幀 × 28×28（實際 %d）" % items)
	var actions := 0
	for id: String in ["big_brother", "calm_brother", "sister_sheep", "younger_brother"]:
		var texture: Texture2D = load("res://assets/characters/playable/%s_action_sheet.png" % id)
		var data: CharacterData = load("res://assets/characters/playable/%s.tres" % id)
		if texture != null and texture.get_size() == Vector2(96, 256) and data.action_sheet == texture:
			actions += 1
	_assert(actions == 4, "四張行動表為 96×256 且 CharacterData 已接上（實際 %d）" % actions)
	var sheet := ImageTexture.create_from_image(Image.create(240, 256, false, Image.FORMAT_RGBA8))
	var action_sheet := ImageTexture.create_from_image(Image.create(96, 256, false, Image.FORMAT_RGBA8))
	var frames: SpriteFrames = PlayerScript.build_sprite_frames(sheet, action_sheet)
	_assert(frames.has_animation(&"carry_left") and frames.has_animation(&"throw_up") and frames.get_animation_names().size() == 16, "行動表加入 carry／throw 各四方向")
	var throw_frame: AtlasTexture = frames.get_frame_texture(&"throw_right", 0)
	_assert(throw_frame.region == Rect2(48, 128, 48, 64), "throw_right 取自行動表第 1 欄第 2 列")
	_assert(PlayerScript.build_sprite_frames(sheet).get_animation_names().size() == 8, "沒有行動表時只有 8 個動畫")
	var tileset: Texture2D = load("res://assets/tilesets/tide_root_town_tileset.png")
	_assert(tileset != null and tileset.get_size() == Vector2(576, 192), "tileset 擴充為 6 列")
	for name: String in ["fx_teleport", "fx_hit_sparkle", "fx_poof", "fx_victory", "fx_chicken_wing"]:
		_assert(ResourceLoader.exists("res://assets/effects/%s.png" % name), "特效貼圖 %s 存在" % name)
	var grandma: Texture2D = load("res://assets/characters/npcs/grandma_turtle_sheet.png")
	_assert(grandma != null and grandma.get_size() == Vector2(240, 256) and ResourceLoader.exists("res://assets/props/breakfast_stall.png"), "阿嬤精靈表 240×256 與早餐攤存在")


## Phase 4.6：四位角色的 4 幀行走表與待機表、陰影、洞窟 tile 組。
func test_phase46_sheets() -> void:
	var ids: Array[String] = ["big_brother", "calm_brother", "sister_sheep", "younger_brother"]
	var wired := 0
	var distinct_ok := true
	var walk_bottom_ok := true
	var idle_bottom_ok := true
	for id: String in ids:
		var data: CharacterData = load("res://assets/characters/playable/%s.tres" % id)
		var walk: Texture2D = data.sprite_sheet
		var idle: Texture2D = data.idle_sheet
		if walk != null and idle != null and walk.get_size() == Vector2(192, 256) and idle.get_size() == Vector2(192, 256) and walk.resource_path.ends_with("%s_walk_v2_sheet.png" % id):
			wired += 1
		var walk_image := walk.get_image()
		var idle_image := idle.get_image()
		for row: int in range(4):
			var frames: Array[PackedByteArray] = []
			for column: int in range(4):
				var cell := walk_image.get_region(Rect2i(column * 48, row * 64, 48, 64))
				frames.append(cell.get_data())
				if _alpha_bottom(cell) != 62:
					walk_bottom_ok = false
				var idle_bottom := _alpha_bottom(idle_image.get_region(Rect2i(column * 48, row * 64, 48, 64)))
				if idle_bottom < 61 or idle_bottom > 63:
					idle_bottom_ok = false
			if frames[0] == frames[2] or frames[1] == frames[3]:
				distinct_ok = false
	_assert(wired == 4, "四位角色接上 192×256 的 v2 行走表與待機表（實際 %d）" % wired)
	_assert(distinct_ok, "每個方向的行走幀 0≠2、1≠3（左右腳交替）")
	_assert(walk_bottom_ok, "行走表每格 alpha 下緣都是 62（腳底 y=61，底部保留 2px）")
	_assert(idle_bottom_ok, "待機表每格 alpha 下緣在 61～63（1px 呼吸幅度）")
	var shadow: Texture2D = load("res://assets/effects/character_shadow.png")
	var pet_shadow: Texture2D = load("res://assets/effects/pet_shadow.png")
	_assert(shadow != null and shadow.get_size() == Vector2(32, 12) and pet_shadow != null and pet_shadow.get_size() == Vector2(24, 9), "角色陰影 32×12、寵物陰影 24×9")
	for scene_path: String in ["res://scenes/characters/playable_character.tscn", "res://scenes/characters/npc.tscn", "res://scenes/characters/pet_follower.tscn"]:
		var node: Node = (load(scene_path) as PackedScene).instantiate()
		var shadow_node := node.get_node_or_null("Shadow") as Sprite2D
		var first_child := node.get_child(0)
		_assert(shadow_node != null and shadow_node.position == Vector2.ZERO and first_child == shadow_node and shadow_node.centered, "%s 的 Shadow 在地面錨點且排在 VisualRoot 之前" % scene_path.get_file())
		node.free()
	var pack: Texture2D = load("res://assets/tiles/fried_food_cave_tiles_32.png")
	_assert(pack != null and pack.get_size() == Vector2(128, 64), "洞窟正式 tile 組 128×64")
	var tileset: Texture2D = load("res://assets/tilesets/tide_root_town_tileset.png")
	var atlas_image := tileset.get_image()
	var pack_image := pack.get_image()
	var copied := true
	for index: int in range(8):
		var from := pack_image.get_region(Rect2i((index % 4) * 32, (index / 4) * 32, 32, 32))
		var to := atlas_image.get_region(Rect2i(index * 32, 5 * 32, 32, 32))
		# 匯入時 fix_alpha_border 會改寫透明與半透明邊緣像素的 RGB，只比對實心像素。
		for y: int in range(32):
			for x: int in range(32):
				var a := from.get_pixel(x, y)
				var b := to.get_pixel(x, y)
				# 地面 A／B（index 0、1）的最右一欄由切割器補平，不比對。
				if index < 2 and x == 31:
					continue
				if a.a >= 0.5 and (a != b):
					copied = false
	_assert(copied, "tileset 第 5 列第 0～7 欄與正式 tile 組的實心像素相同")
	var sheet := ImageTexture.create_from_image(Image.create(192, 256, false, Image.FORMAT_RGBA8))
	var idle_sheet := ImageTexture.create_from_image(Image.create(192, 256, false, Image.FORMAT_RGBA8))
	var frames_with_idle: SpriteFrames = PlayerScript.build_sprite_frames(sheet, null, idle_sheet)
	_assert(frames_with_idle.get_frame_count(&"idle_up") == 4 and is_equal_approx(frames_with_idle.get_animation_speed(&"idle_up"), PlayerScript.IDLE_FPS), "有待機表時 idle 4 幀、以 IDLE_FPS 播放")
	var idle_frame: AtlasTexture = frames_with_idle.get_frame_texture(&"idle_left", 3)
	_assert(idle_frame.atlas == idle_sheet and idle_frame.region == Rect2(144, 64, 48, 64), "idle_left 第 4 幀取自待機表第 1 列第 3 欄")


## 一格裡最後一列有不透明像素的 y（exclusive，與 PIL getbbox 的 bottom 相同）；全透明回傳 0。
func _alpha_bottom(cell: Image) -> int:
	for y: int in range(cell.get_height() - 1, -1, -1):
		for x: int in range(cell.get_width()):
			if cell.get_pixel(x, y).a > 0.0:
				return y + 1
	return 0


## Phase 4.6：停下後的分離、對話框 💢 圖片。
func test_phase46_logic() -> void:
	var none: Array[Vector2] = [Vector2(100, 0)]
	_assert(FollowerScript.separation_velocity(Vector2.ZERO, none, 60.0).is_zero_approx(), "沒有人靠近時不分離")
	var close: Array[Vector2] = [Vector2(10, 0)]
	var pushed: Vector2 = FollowerScript.separation_velocity(Vector2.ZERO, close, 60.0)
	_assert(pushed.x < 0.0 and is_equal_approx(pushed.length(), 60.0), "被右邊的隊員擠到時往左推開")
	var stacked: Array[Vector2] = [Vector2.ZERO]
	var tie_a: Vector2 = FollowerScript.separation_velocity(Vector2.ZERO, stacked, 60.0, Vector2.RIGHT)
	var tie_b: Vector2 = FollowerScript.separation_velocity(Vector2.ZERO, stacked, 60.0, Vector2.LEFT)
	_assert(tie_a.x > 0.0 and tie_b.x < 0.0, "完全重疊時依 tie_break 往不同方向推開")
	var far: Array[Vector2] = [Vector2(FollowerScript.SEPARATION_GAP, 0)]
	_assert(FollowerScript.separation_velocity(Vector2.ZERO, far, 60.0).is_zero_approx(), "距離達 SEPARATION_GAP 就不再推")
	var bb := DialogueBoxScript.to_bbcode("……💢 [OS] 你怎麼忍心!!!")
	_assert(bb.contains("[img=12x12]res://assets/ui/anger_mark.png[/img]") and not bb.contains("💢"), "💢 換成 anger_mark 圖片")
	_assert(bb.contains("[lb]OS[rb]"), "方括號會被跳脫，不會被當成 bbcode")
	_assert(DialogueBoxScript.to_bbcode("普通句子です") == "普通句子です", "沒有特殊字元時原樣輸出")
