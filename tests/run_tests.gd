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
const TownWorldScript := preload("res://scripts/world/town_world.gd")
const RestTransitionScript := preload("res://scripts/ui/rest_transition.gd")
const DayHudScript := preload("res://scripts/ui/day_hud.gd")

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
	test_phase5_tiles()
	test_game_state_v3()
	test_daily_flags_in_dialogue()
	test_phase5_props()
	test_phase5_ui()
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
	_assert(restored.schema_version == GameStateScript.SCHEMA_VERSION and state.to_dict()["schema_version"] == GameStateScript.SCHEMA_VERSION, "schema_version 為目前版本")
	var legacy := {"schema_version": 1, "current_scene_id": "tide_root_town", "flags": {"demo": true}, "quests": {}}
	var migrated: Dictionary = GameStateScript.from_dict(legacy)
	var old: GameState = migrated["state"]
	_assert(old != null and old.inventory.is_empty() and old.pet_id == "" and old.has_flag("demo"), "v1 存檔以空背包與無寵物補齊")
	_assert(not state.remove_item("chunhsiang_noodles", 2) and state.remove_item("chunhsiang_noodles") and not state.has_item("chunhsiang_noodles"), "扣除物品：不足時拒絕，足夠時移除")
	_assert(GameStateScript.from_dict({"schema_version": GameStateScript.SCHEMA_VERSION + 1, "current_scene_id": "x", "flags": {}, "quests": {}})["state"] == null, "比目前 schema 新一版的存檔被拒絕")


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
	_assert(tileset != null and tileset.get_size() == Vector2(576, 256), "tileset 擴充為 8 列（第 6～7 列為 Phase 5 城鎮更新）")
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


## Phase 5：城鎮更新 tile（去格框、翻轉補齊、鄰接判斷、只套用在下層列）。
func test_phase5_tiles() -> void:
	var delivered: Texture2D = load("res://assets/tilesets/town_visual_refresh_tiles_32.png")
	_assert(delivered != null and delivered.get_size() == Vector2(256, 128), "交付 atlas 為 256×128（8×4 格 32×32）")
	var tileset: Texture2D = load("res://assets/tilesets/tide_root_town_tileset.png")
	var image := tileset.get_image()
	var seam_ok := true
	var worst := 0.0
	for coords: Vector2i in [TileLibraryScript.TR_GRASS_A, TileLibraryScript.TR_GRASS_B, TileLibraryScript.TR_STONE_A, TileLibraryScript.TR_STONE_B, TileLibraryScript.TR_ROOT_WALL, TileLibraryScript.TR_WATER, TileLibraryScript.TR_DEEP_WATER, TileLibraryScript.TR_EARTH]:
		var cell := image.get_region(Rect2i(coords.x * 32, coords.y * 32, 32, 32))
		var inner := _ring_brightness(cell, 2)
		for ring: int in [0, 1]:
			var diff := absf(_ring_brightness(cell, ring) - inner)
			worst = maxf(worst, diff)
			if diff > 12.0:
				seam_ok = false
	_assert(seam_ok, "城鎮更新的整面 tile 外圈與內圈亮度差 ≤ 12（無格線，最大 %.1f）" % worst)
	var opaque := true
	for row: int in [6, 7]:
		for col: int in range(16):
			var cell := image.get_region(Rect2i(col * 32, row * 32, 32, 32))
			for y: int in range(32):
				for x: int in range(32):
					if cell.get_pixel(x, y).a < 1.0:
						opaque = false
	_assert(opaque, "第 6～7 列 32 格都是整格不透明（沒有白邊或透明縫）")
	var edge_n := image.get_region(Rect2i(TileLibraryScript.TR_PATH_EDGE_N.x * 32, TileLibraryScript.TR_PATH_EDGE_N.y * 32, 32, 32))
	var edge_s := image.get_region(Rect2i(TileLibraryScript.TR_PATH_EDGE_S.x * 32, TileLibraryScript.TR_PATH_EDGE_S.y * 32, 32, 32))
	_assert(_greenness(edge_n, 4) > _greenness(edge_n, 27) + 0.1 and _greenness(edge_s, 27) > _greenness(edge_s, 4) + 0.1, "path_edge_n 草在上、path_edge_s 草在下（翻轉補齊）")
	var registry: Dictionary = SceneRouterScript.parse_registry(FileAccess.get_file_as_string("res://assets/maps/scenes.json"))
	var options := {
		TileLibraryScript.TILE_STYLE_KEY: String(registry["tide_root_town"].get("tile_style", "")),
		TileLibraryScript.TILE_STYLE_ROWS_KEY: registry["tide_root_town"].get("tile_style_rows", []),
	}
	var rows: Array = options[TileLibraryScript.TILE_STYLE_ROWS_KEY]
	_assert(String(options[TileLibraryScript.TILE_STYLE_KEY]) == "town_refresh" and int(rows[0]) == 23 and int(rows[1]) == 35, "主城以 tile_style = town_refresh 只套用第 23～35 列")
	var parser := _load_map()
	var tl := TileLibraryScript
	_assert(tl.ground_atlas_for(parser, 5, 22, options) == tl.GRASS and tl.ground_atlas_for(parser, 13, 22, options) == tl.STAIRS, "第 22 列（中層）仍用舊 atlas")
	_assert(tl.ground_atlas_for(parser, 13, 23, options) == tl.STAIRS, "更新列裡的樓梯退回舊 atlas 的樓梯")
	_assert(tl.ground_atlas_for(parser, 5, 24, options) == tl.TR_GRASS_CLIFF and tl.ground_atlas_for(parser, 0, 24, options) == tl.TR_ROOT_WALL, "牆：下方可走用草崖、其餘樹根牆")
	_assert(tl.ground_atlas_for(parser, 14, 29, options) == tl.TR_STONE_B, "廣場中心 m 用石板 B")
	_assert(tl.TR_STONE_PATTERN.has(tl.ground_atlas_for(parser, 11, 24, options)), "沒有草地鄰居的石板用 A／B 變體")
	_assert(tl.ground_atlas_for(parser, 9, 26, options) == tl.TR_PATH_EDGE_W and tl.ground_atlas_for(parser, 9, 25, options) == tl.TR_PATH_EDGE_W, "石板左側是草地 → path_edge_w（牆不算草地）")
	_assert(tl.ground_atlas_for(parser, 10, 30, options) == tl.TR_PATH_CORNER_SW and tl.ground_atlas_for(parser, 18, 31, options) == tl.TR_PATH_CORNER_SE, "石板左下／右下是草地 → corner_sw／corner_se")
	_assert(tl.ground_atlas_for(parser, 3, 27, options) == tl.TR_SHORE_CORNER_NE and tl.ground_atlas_for(parser, 23, 30, options) == tl.TR_SHORE_EDGE_W, "淺水上方與右方是陸地 → shore_corner_ne；只有左方是陸地 → shore_edge_w")
	_assert(tl.ground_atlas_for(parser, 2, 27, options) == tl.TR_DEEP_WATER and tl.ground_atlas_for(parser, 2, 29, options) == tl.TR_WATER, "不靠岸的淺水用靜態深水、深水用動畫水面")
	_assert(tl.ground_atlas_for(parser, 16, 32, options) == tl.TR_SHORE_CORNER_NW, "淺水上方與左方是陸地 → shore_corner_nw")
	_assert(tl.ground_atlas_for(parser, 23, 29, options) == tl.TR_SHORE_EDGE_W, "橋旁的水只看草地那側（橋不算陸地）")
	_assert(tl.ground_atlas_for(parser, 22, 27, options) == tl.TR_BRIDGE_EW_TOP and tl.ground_atlas_for(parser, 22, 28, options) == tl.TR_BRIDGE_EW_BOTTOM, "兩列東西向木橋：上列／下列")
	var variants := {}
	for x: int in range(8, 16):
		variants[tl.ground_atlas_for(parser, x, 32, options)] = true
	_assert(variants.size() >= 2 and variants.has(tl.TR_GRASS_A), "草地在同列裡至少兩種變體（%d 種）" % variants.size())
	_assert(tl.edge_tile_for(tl.NEIGHBOR_N | tl.NEIGHBOR_S, tl.TR_STONE_A, [tl.TR_PATH_EDGE_N, tl.TR_PATH_EDGE_S, tl.TR_PATH_EDGE_W, tl.TR_PATH_EDGE_E, tl.TR_PATH_CORNER_NW, tl.TR_PATH_CORNER_NE, tl.TR_PATH_CORNER_SW, tl.TR_PATH_CORNER_SE]) == tl.TR_PATH_EDGE_N, "對邊都是草地時先取北邊 edge")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var decorated := 0
	for y: int in range(23, 36):
		for x: int in range(parser.width):
			if tl.decoration_atlas_for(parser, x, y, rng, options).x >= 0:
				decorated += 1
	_assert(decorated == 0, "更新列不疊舊 atlas 的裝飾")
	_assert(not tl.uses_town_refresh({tl.TILE_STYLE_KEY: "town_refresh"}, 0) == false, "沒有 tile_style_rows 時整張地圖都用更新樣式")
	var walkable_same := true
	for y: int in range(parser.height):
		for x: int in range(parser.width):
			if parser.is_walkable(x, y) != MapParserScript.WALKABLE_CHARS.contains(parser.char_at(x, y)):
				walkable_same = false
	_assert(walkable_same and not parser.find_path(Vector2i(14, 29), Vector2i(26, 27)).is_empty() and not parser.find_path(Vector2i(14, 29), Vector2i(2, 16)).is_empty(), "換樣式不改可走性：出生點仍可到東西兩出口")
	var big := Image.create(TileLibraryScript.ATLAS_COLUMNS * 32, TileLibraryScript.ATLAS_ROWS * 32, false, Image.FORMAT_RGBA8)
	var tile_set: TileSet = TileLibraryScript.build_ground_tileset(ImageTexture.create_from_image(big))
	var source: TileSetAtlasSource = tile_set.get_source(0)
	_assert(source.get_tile_animation_frames_count(tl.TR_WATER) == tl.WATER_FRAMES and not source.has_tile(Vector2i(13, 7)) and source.has_tile(tl.TR_BRIDGE_EW_BOTTOM), "更新水面 4 幀動畫、幀格不獨立成 tile、東西向木橋 tile 存在")


func _ring_brightness(cell: Image, ring: int) -> float:
	var total := 0.0
	var count := 0
	for y: int in range(32):
		for x: int in range(32):
			if mini(mini(x, y), mini(31 - x, 31 - y)) == ring:
				var c := cell.get_pixel(x, y)
				total += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				count += 1
	return total * 255.0 / float(count)


## 一列裡中央 8 個像素的「綠色優勢」平均值（g - r），用來分辨草地與石板。
func _greenness(cell: Image, y: int) -> float:
	var total := 0.0
	for x: int in range(12, 20):
		var c := cell.get_pixel(x, y)
		total += c.g - c.r
	return total / 8.0


## Phase 5：schema v3（day、day_seed、daily_state）、advance_day 只由休息呼叫、reset 不清永久資料、v2 遷移。
func test_game_state_v3() -> void:
	var state: GameState = GameStateScript.new()
	_assert(GameStateScript.SCHEMA_VERSION == 3 and state.day == 1 and state.daily_state.is_empty(), "新遊戲從 day 1 開始、daily_state 為空、schema 3")
	_assert(state.day_seed == GameStateScript.seed_for_day(1) and GameStateScript.seed_for_day(1) != GameStateScript.seed_for_day(2), "day_seed 由 day 決定且每天不同")
	var rng_a := state.daily_rng()
	var rng_b := state.daily_rng()
	_assert(rng_a.randi() == rng_b.randi(), "同一天的 daily_rng 序列可重現")
	state.set_flag("permanent_flag")
	state.add_item("chunhsiang_noodles")
	state.pet_id = "cc_penguin"
	state.quests = {"q": {"state": "active", "progress": {"a": 1}}}
	state.set_daily_flag("demo_counter_checked_today")
	_assert(state.has_daily_flag("demo_counter_checked_today") and not state.has_flag("demo_counter_checked_today"), "每日旗標存在 daily_state，不進永久 flags")
	var advanced: Array[int] = []
	state.day_advanced.connect(func(day: int) -> void: advanced.append(day))
	state.advance_day()
	_assert(state.day == 2 and advanced == [2] and state.day_seed == GameStateScript.seed_for_day(2), "advance_day：day +1、day_seed 更新、發出 day_advanced 一次")
	_assert(not state.has_daily_flag("demo_counter_checked_today") and state.daily_state.is_empty(), "進入新的一天後每日旗標重置")
	_assert(state.has_flag("permanent_flag") and state.has_item("chunhsiang_noodles") and state.pet_id == "cc_penguin" and state.quests["q"]["progress"]["a"] == 1, "每日重置不清永久旗標、背包、寵物與任務")
	state.set_daily_flag("x")
	state.reset_daily_state()
	_assert(state.day == 2 and state.daily_state.is_empty(), "reset_daily_state 只清 daily_state，不改 day")
	state.set_daily_flag("kept")
	var restored: GameState = GameStateScript.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))["state"]
	_assert(restored != null and restored.day == 2 and restored.day_seed == state.day_seed and restored.has_daily_flag("kept"), "v3 存檔保留 day、day_seed 與 daily_state")
	var legacy := {"schema_version": 2, "current_scene_id": "family_home", "flags": {"cc_joined": true}, "quests": {"q": {"state": "completed", "progress": {}}}, "inventory": {"chunhsiang_noodles": 1}, "pet_id": "cc_penguin"}
	var migrated: GameState = GameStateScript.from_dict(legacy)["state"]
	_assert(migrated != null and migrated.day == 1 and migrated.day_seed == GameStateScript.seed_for_day(1) and migrated.daily_state.is_empty(), "v2 存檔遷移：day 1、空 daily_state")
	_assert(migrated.has_flag("cc_joined") and migrated.has_item("chunhsiang_noodles") and migrated.pet_id == "cc_penguin" and migrated.quests["q"]["state"] == "completed", "v2 遷移不清旗標、背包、寵物與任務")
	var bad_day: GameState = GameStateScript.from_dict({"schema_version": 3, "current_scene_id": "x", "flags": {}, "quests": {}, "day": 0, "daily_state": "oops"})["state"]
	_assert(bad_day != null and bad_day.day == 1 and bad_day.daily_state.is_empty(), "day < 1 或 daily_state 型別錯誤時退回預設值")
	var v1 := {"schema_version": 1, "current_scene_id": "tide_root_town", "flags": {}, "quests": {}}
	_assert(GameStateScript.from_dict(v1)["state"] != null and (GameStateScript.from_dict(v1)["state"] as GameState).day == 1, "v1 存檔仍可讀取")
	var path := "user://test_save_v3.json"
	_assert(SaveManagerScript.save_state(state, path) == "" and (SaveManagerScript.load_state(path)["state"] as GameState).day == 2, "存檔再讀回 day 一致")
	SaveManagerScript.delete_save(path)
	var router_state: GameState = GameStateScript.new()
	router_state.current_scene_id = "family_home"
	router_state.unlock_scene("captain_room")
	router_state.current_scene_id = "tide_root_town"
	_assert(router_state.day == 1, "切換場景（改 current_scene_id／unlock）不增加 day")


func test_daily_flags_in_dialogue() -> void:
	var quests: QuestManager = QuestManagerScript.new()
	quests.load_all_definitions()
	var state: GameState = GameStateScript.new()
	quests.bind(state)
	_assert(DialogueResolverScript.requires_met({"not_daily_flags": ["today"]}, state, quests) and not DialogueResolverScript.requires_met({"daily_flags": ["today"]}, state, quests), "daily_flags／not_daily_flags 條件")
	quests.apply_actions([{"set_daily_flag": "today"}])
	_assert(state.has_daily_flag("today") and DialogueResolverScript.requires_met({"daily_flags": ["today"]}, state, quests), "對話動作 set_daily_flag 寫入每日旗標")
	quests.apply_actions([{"clear_daily_flag": "today"}])
	_assert(not state.has_daily_flag("today"), "clear_daily_flag 清除每日旗標")
	var home: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/family_home.json"))
	var counter: Array = home["kitchen_counter"]
	var first: Dictionary = DialogueResolverScript.resolve(counter, state, quests)
	_assert(_has_action(first["on_complete"], "set_daily_flag"), "流理台第一次互動設定每日示範旗標")
	quests.apply_actions(first["on_complete"])
	var again: Dictionary = DialogueResolverScript.resolve(counter, state, quests)
	_assert(again["lines"] != first["lines"] and again["on_complete"].is_empty(), "同一天再互動顯示「今天已看過」版本")
	state.advance_day()
	_assert(DialogueResolverScript.resolve(counter, state, quests)["lines"] == first["lines"], "休息後每日旗標重置，回到第一次版本")
	var rest: Dictionary = DialogueResolverScript.resolve(home["family_rest_door"], state, quests)
	_assert(DialogueManagerScript.has_valid_options(rest["choice"]) and rest["choice"]["options"].size() == 2, "臥室門對話帶「休息／再等等」兩個選項")
	var confirm: Dictionary = rest["choice"]["options"][0]
	var cancel: Dictionary = rest["choice"]["options"][1]
	_assert(_has_action(confirm.get("on_complete", []), "rest") and not _has_action(cancel.get("on_complete", []), "rest"), "只有確認選項帶 rest 動作，取消不帶")
	quests.apply_actions(cancel.get("on_complete", []))
	_assert(state.day == 2, "取消休息不增加 day（QuestManager 不處理 rest）")
	quests.apply_actions(confirm.get("on_complete", []))
	_assert(state.day == 2, "rest 動作只由 Main 的休息流程執行，apply_actions 不會增加 day")
	quests.free()


## Phase 5：八個城鎮更新 props 的尺寸、接地、碰撞與 JSON 選項；家庭屋休息點與醒來點。
func test_phase5_props() -> void:
	var expected_sizes := {
		"breakfast_stall_v2": Vector2(144, 135), "shared_family_treehouse_v2": Vector2(176, 162), "lantern_post_v2": Vector2(80, 81),
		"harbor_crate_barrel_v2": Vector2(128, 102), "flower_herb_bed_v2": Vector2(144, 132), "blank_signpost_v2": Vector2(80, 76),
		"root_archway_v2": Vector2(176, 166), "heart_fountain_v2": Vector2(144, 129),
	}
	var sized := 0
	var grounded := 0
	var transparent_corners := 0
	for name: String in expected_sizes:
		var texture: Texture2D = load("res://assets/props/town_refresh/%s.png" % name)
		if texture != null and texture.get_size() == expected_sizes[name]:
			sized += 1
		var image := texture.get_image()
		var bottom := _alpha_bottom(image)
		if bottom == image.get_height():
			grounded += 1
		if image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, 0).a == 0.0:
			transparent_corners += 1
	_assert(sized == 8, "八個 v2 props 尺寸與 manifest 一致（實際 %d）" % sized)
	_assert(grounded == 8 and transparent_corners == 8, "八個 props 底緣都有不透明像素（接地）且背景透明")
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/tide_root_town_props.json"))
	var refresh_entries: Array = []
	var old_lower_lamps := 0
	for entry: Dictionary in props["props"]:
		var texture_name := String(entry["texture"])
		if texture_name.begins_with("town_refresh/"):
			refresh_entries.append(entry)
		if texture_name == "lamp_post" and float(entry["y"]) >= 24 * 32:
			old_lower_lamps += 1
	_assert(refresh_entries.size() >= 10 and old_lower_lamps == 0, "下層廣場的燈籠全部換成 v2，且至少 10 個更新 props（實際 %d）" % refresh_entries.size())
	var collision_fits := true
	var uses := {}
	for entry: Dictionary in refresh_entries:
		var texture: Texture2D = load("res://assets/props/%s.png" % entry["texture"])
		uses[String(entry["texture"])] = true
		var raw: Variant = entry.get("collision")
		if typeof(raw) == TYPE_ARRAY and (float(raw[0]) > texture.get_width() or float(raw[1]) > texture.get_height()):
			collision_fits = false
		for box: Rect2 in TownPropScript.collision_boxes_from(entry.get("collision_boxes")):
			if box.size.x > texture.get_width() or box.end.y > 0.0:
				collision_fits = false
	_assert(collision_fits, "更新 props 的碰撞盒不超出貼圖，額外碰撞盒都在接地線之上")
	for name: String in ["shared_family_treehouse_v2", "breakfast_stall_v2", "lantern_post_v2", "heart_fountain_v2", "root_archway_v2"]:
		_assert(uses.has("town_refresh/" + name), "主城使用 %s" % name)
	var treehouse := {}
	var arch := {}
	var lantern := {}
	for entry: Dictionary in refresh_entries:
		match String(entry["texture"]):
			"town_refresh/shared_family_treehouse_v2":
				treehouse = entry
			"town_refresh/root_archway_v2":
				arch = entry
			"town_refresh/lantern_post_v2":
				lantern = entry
	_assert(float(treehouse["x"]) == 144 and float(treehouse["y"]) == 672, "共享家庭屋外觀仍以 (144, 672) 為底部中央（門口傳送門不變）")
	var portal_ok := false
	for portal: Dictionary in props["portals"]:
		if portal["id"] == "family_home_door" and float(portal["x"]) == 144 and float(portal["y"]) == 674:
			portal_ok = true
	_assert(portal_ok, "家庭屋門口傳送門座標不變")
	_assert(float(arch.get("foot_inset", 0)) > 0.0 and TownPropScript.collision_boxes_from(arch.get("collision_boxes")).size() == 2, "根拱門以石板地面為接地線並有左右兩隻腳的碰撞盒")
	var boxes := TownPropScript.collision_boxes_from(arch["collision_boxes"])
	var gap := (float(arch["x"]) + boxes[1].position.x) - (float(arch["x"]) + boxes[0].end.x)
	_assert(gap >= 60.0 and gap <= 72.0 and float(arch["x"]) + boxes[0].end.x < 448.0 and float(arch["x"]) + boxes[1].position.x > 512.0, "拱門兩腳之間留出第 14～15 欄（樓梯中央）可通行（間距 %.0f）" % gap)
	_assert(float(lantern.get("foot_x", -1)) == 60 and bool(lantern.get("glow", false)) and lantern.has("glow_x"), "v2 燈籠以燈柱（foot_x 60）接地並指定光暈中心")
	_assert(TownPropScript.sprite_offset_for(80, 81, 60, 0) == Vector2(-60, -81) and TownPropScript.sprite_offset_for(176, 166, 88, 38) == Vector2(-88, -128), "sprite_offset_for：接地點在 (foot_x, height - foot_inset)")
	var parsed := TownPropScript.collision_boxes_from([[52, 40, -56, 0], [56, 40, 54, 0], "bad", [1]])
	_assert(parsed.size() == 2 and parsed[0] == Rect2(-82, -40, 52, 40) and parsed[1].get_center() == Vector2(54, -20), "collision_boxes_from 解析 [寬, 高, dx, dy] 並忽略壞資料")
	_assert(TownPropScript.collision_boxes_from(null).is_empty(), "沒有 collision_boxes 時回傳空陣列")
	var home: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/family_home_props.json"))
	var rest_door := {}
	for entry: Dictionary in home["props"]:
		if entry.get("interact", "") == "family_rest_door":
			rest_door = entry
	_assert(not rest_door.is_empty() and String(rest_door.get("prompt_icon", "")) == "rest_prompt" and ResourceLoader.exists("res://assets/ui/rest_prompt.png"), "家庭屋臥室門是休息點並使用 rest_prompt 圖示")
	var rest_tiles: Array = home["entries"]["rest"]
	var spaced := rest_tiles.size() == 4
	var parser: MapParser = MapParserScript.load_from_file("res://assets/maps/family_home.txt")
	for a: int in range(rest_tiles.size()):
		if not parser.is_walkable(int(rest_tiles[a][0]), int(rest_tiles[a][1])):
			spaced = false
		for b: int in range(a + 1, rest_tiles.size()):
			var pa := Vector2(float(rest_tiles[a][0]), float(rest_tiles[a][1])) * 32.0
			var pb := Vector2(float(rest_tiles[b][0]), float(rest_tiles[b][1])) * 32.0
			if pa.distance_to(pb) < 64.0:
				spaced = false
	_assert(spaced, "醒來點四格可走且彼此間隔 ≥ 2 格")
	_assert(TownWorldScript.decoration_seed_for(GameStateScript.seed_for_day(1)) != TownWorldScript.decoration_seed_for(GameStateScript.seed_for_day(2)), "裝飾層種子隨 day_seed 改變")


## Phase 5：早晨色調、時段圖示、日出轉場幀與天數 HUD 文字。
func test_phase5_ui() -> void:
	_assert(DayNightScript.MORNING_COLOR != DayNightScript.STATE_COLORS[0] and DayNightScript.MORNING_SECONDS > 0.0, "早晨色調與白天不同且會漸變")
	_assert(DayNightScript.phase_icon_for(0, true) == DayNightScript.PHASE_ICON_MORNING and DayNightScript.phase_icon_for(0, false) == DayNightScript.PHASE_ICON_DAY, "早晨／白天圖示")
	_assert(DayNightScript.phase_icon_for(1, false) == DayNightScript.PHASE_ICON_DUSK and DayNightScript.phase_icon_for(2, false) == DayNightScript.PHASE_ICON_NIGHT, "黃昏／夜晚圖示")
	_assert(DayNightScript.next_index(0) == 1 and DayNightScript.STATE_NAMES.size() == 3, "F5 循環仍是三態（早晨不是存檔狀態）")
	var icons: Texture2D = load("res://assets/ui/day_phase_icons.png")
	_assert(icons != null and icons.get_size() == Vector2(96, 24), "時段圖示表 96×24（4 格）")
	var sheet: Texture2D = load("res://assets/effects/morning_transition_sheet.png")
	_assert(sheet != null and sheet.get_size() == Vector2(256, 64), "日出轉場表 256×64（4 幀 64×64）")
	var frame: AtlasTexture = RestTransitionScript.frame_texture(3)
	_assert(frame.region == Rect2(192, 0, 64, 64) and RestTransitionScript.frame_texture(9).region.position.x == 192, "日出第 4 幀取自 x=192，超出範圍夾到最後一幀")
	_assert(RestTransitionScript.day_label(7) == "第 7 天" and DayHudScript.text_for(3, "早晨") == "第 3 天・早晨", "轉場與 HUD 的天數文字")
	_assert(DayHudScript.icon_texture(2).region == Rect2(48, 0, 24, 24), "HUD 圖示取自圖示表第 3 格")
