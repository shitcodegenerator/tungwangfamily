extends Node
## 自動化驗證：依 BFS 路徑以模擬輸入驅動領頭角色走完驗收路線，途中切換角色 20 次、
## 測試三個封鎖出口與各類牆壁（Phase 1），再驗證互動提示、對話、輸入鎖、日夜切換（Phase 2），並擷取截圖。
##
## 執行：caffeinate -dis godot --path . --always-on-top -- --route-test --shots=<絕對路徑>
## （macOS：caffeinate 防止螢幕休眠讓畫面停止更新；並先 defaults write org.godotengine.godot NSAppSleepDisabled -bool YES 避免 App Nap）
## 結束時列印報告並以 exit code 0（通過）／1（失敗）離開。

const TILE_TIMEOUT := 4.0
const SWITCH_TARGET := 20
const SWITCH_EVERY_TILES := 5
const AXIS_ACTIONS := {
	Vector2i.LEFT: "move_left",
	Vector2i.RIGHT: "move_right",
	Vector2i.UP: "move_up",
	Vector2i.DOWN: "move_down",
}

var world: TownWorld
var party: PartyController
var interaction: InteractionController
var dialogue: DialogueManager
var day_night: DayNightController
var main_node: Node
var quests: QuestManager
var router: SceneRouter
var carry: CarrySystem
var battle: BattleDirector
var shots_dir: String = "user://screenshots"
var failures: PackedStringArray = PackedStringArray()
var passes: PackedStringArray = PackedStringArray()
var follower_violations: PackedStringArray = PackedStringArray()
var boss_bound_violations: PackedStringArray = PackedStringArray()
var switches_done: int = 0
var _running: bool = false


func _ready() -> void:
	var main: Node = get_parent()
	world = main.get("world")
	party = main.get("party")
	interaction = main.get("interaction")
	dialogue = main.get("dialogue")
	day_night = main.get("day_night")
	main_node = main
	quests = main.get("quests")
	router = main.get("router")
	carry = main.get("carry")
	battle = main.get("battle")
	# 每次執行從乾淨狀態開始：移除舊存檔，避免上次測試殘留
	SaveManager.delete_save()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots_dir))
	_run.call_deferred()


func _run() -> void:
	_running = true
	await get_tree().create_timer(0.6).timeout
	await _screenshot("01_spawn_lower_plaza")

	_check(await _walk_to(Vector2i(14, 23)), "出生點 → 下層/中層連接點")
	_check(await _walk_to(Vector2i(15, 16)), "下層 → 中層樹洞街")
	await _screenshot("02_middle_hollow_street")
	_check(await _walk_to(Vector2i(23, 11)), "中層 → 中層/上層連接點")
	_check(await _walk_to(Vector2i(14, 6)), "上層樹枝道路")
	_check(await _walk_to(Vector2i(14, 2)), "上層頂端樹冠入口前")
	await _screenshot("03_upper_branch_platform")

	_check(await _push_against(Vector2i.UP, 1.0, func(p: Vector2) -> bool: return p.y >= 72.0), "北側樹冠入口封鎖，不可離開主城")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"north_canopy"), "上方樹冠門可互動並顯示未開放提示")
	_check(await _walk_to(Vector2i(2, 16)), "走到左側橋頭")
	_check(await _push_against(Vector2i.LEFT, 1.0, func(p: Vector2) -> bool: return p.x >= 66.0), "左側橋頭封鎖，不可離開主城")
	_check(await _interact_and_close(&"west_bridge"), "左側橋頭可互動並顯示未開放提示")
	_check(await _walk_to(Vector2i(26, 27)), "走到右側船港")
	_check(await _push_against(Vector2i.RIGHT, 1.0, func(p: Vector2) -> bool: return p.x <= 894.0), "右側船港封鎖，不可離開主城")
	_check(await _interact_and_close(&"east_harbor"), "右側船港可互動並顯示未開放提示")

	_check(await _walk_to(Vector2i(6, 16)), "走到房屋門前")
	_check(await _push_against(Vector2i.UP, 1.0, func(p: Vector2) -> bool: return p.y >= 508.0), "房屋外牆阻擋，不可進入")
	_check(await _walk_to(Vector2i(22, 30)), "走到深水邊")
	_check(await _push_against(Vector2i.RIGHT, 1.0, func(p: Vector2) -> bool: return p.x <= 734.0), "深水阻擋")
	_check(await _walk_to(Vector2i(4, 25)), "走到樹皮牆邊")
	_check(await _push_against(Vector2i.LEFT, 1.0, func(p: Vector2) -> bool: return p.x >= 132.0), "樹皮牆阻擋")
	_check(await _walk_to(Vector2i(14, 34)), "走到地圖下緣")
	_check(await _push_against(Vector2i.DOWN, 1.0, func(p: Vector2) -> bool: return p.y <= 1122.0), "地圖外圍阻擋")

	# 牆角繞行：從樹皮牆邊繞過房屋轉角走到中層街道，再確認跟隨者都追上
	_check(await _walk_to(Vector2i(10, 13)), "繞過房屋與樹皮牆轉角")
	_check(await _walk_to(Vector2i(3, 17)), "沿房屋外牆走到左側橋頭旁")
	_check(await _followers_catch_up(2.5, 110.0), "牆角繞行後跟隨者 2.5 秒內追上")

	_check(await _walk_to(Vector2i(14, 29)), "上層 → 走回出生點")
	# 快速左右反覆移動，再走開，確認跟隨者不會永久卡住
	await _jitter(3.0)
	_check(await _walk_to(Vector2i(19, 26)), "快速反覆移動後仍可正常行走")
	_check(await _followers_catch_up(2.5, 110.0), "快速反覆移動後跟隨者 2.5 秒內追上")
	_check(await _walk_to(Vector2i(14, 29)), "再次回到出生點")
	await _phase2_checks()
	await _phase3_checks()
	await _phase4_checks()
	await _phase46_checks()
	await _phase5_checks()
	while switches_done < SWITCH_TARGET:
		party.cycle_leader()
		switches_done += 1
		await get_tree().create_timer(0.1).timeout
	_check(party.order.size() == 4 and party.get_leader() != null, "連續切換 %d 次後隊伍完整" % switches_done)
	await get_tree().create_timer(1.5).timeout
	_check(follower_violations.is_empty(), "跟隨者全程未穿牆、未掉出地圖（違規 %d 筆）" % follower_violations.size())
	_check(boss_bound_violations.is_empty(), "Boss 全程未越過活動上限（違規 %d 筆）" % boss_bound_violations.size())
	_running = false
	_report()


## Phase 2：公告欄互動流程、對話中輸入鎖、樹心互動、對話前後切換不傳送、日夜切換不改碰撞。
func _phase2_checks() -> void:
	_check(await _walk_to(Vector2i(20, 16)), "走到公告欄前方")
	_check(interaction.current_target == null, "遠離公告欄時沒有互動目標")
	_check(await _walk_to(Vector2i(20, 15)), "走到公告欄正下方")
	await _face(Vector2i.UP)
	await _wait_frames(3)
	var target := interaction.current_target
	_check(target != null and target.interactable_id == &"bulletin_board" and interaction.prompt_visible(), "靠近公告欄出現互動提示")
	await _screenshot("04_interact_prompt")

	await _tap_action("interact")
	_check(dialogue.is_active and dialogue.current_speaker == "潮根城公告欄", "按 E 開啟公告欄對話")
	var before := party.get_leader().global_position
	var order_before := party.order.duplicate()
	await _push_for(Vector2i.RIGHT, 0.5)
	_check(party.get_leader().global_position.distance_to(before) < 1.0, "對話中 WASD 不會移動主要角色")
	_check(not interaction.prompt_visible(), "對話中互動提示隱藏")
	await _tap_action("interact")
	await _screenshot("05_dialogue")
	var first_index := dialogue.line_index()
	await _tap_action("interact")
	await _tap_action("interact")
	_check(dialogue.is_active and dialogue.line_index() > first_index, "按 E 推進到下一句")
	var guard := 0
	while dialogue.is_active and guard < 20:
		await _tap_action("interact")
		guard += 1
	_check(not dialogue.is_active, "對話可推進至結束並關閉（共按 %d 次）" % (guard + 3))
	_check(party.order == order_before, "對話前後隊伍順序不變")

	_check(await _walk_to(Vector2i(20, 17)), "離開公告欄")
	await _wait_frames(3)
	_check(interaction.current_target == null and not interaction.prompt_visible(), "離開公告欄後提示消失")

	_check(await _walk_to(Vector2i(15, 14)), "走到樹心前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"tree_heart"), "樹心可互動並顯示對話")

	# 對話後切換角色：沒有人被傳送
	var positions: Array[Vector2] = []
	for member: PlayableCharacter in party.members:
		positions.append(member.global_position)
	party.set_leader_by_index(2)
	switches_done += 1
	await _wait_frames(2)
	var teleported := false
	for index: int in range(party.members.size()):
		if party.members[index].global_position.distance_to(positions[index]) > 4.0:
			teleported = true
	_check(party.order.size() == 4 and not teleported, "對話後切換角色，隊伍完整且不傳送")
	party.set_leader_by_index(0)
	switches_done += 1

	# 日夜：走到燈籠旁，切換三種狀態並各截一張圖；碰撞格數量與道具封鎖格不變
	_check(await _walk_to(Vector2i(12, 16)), "走到中層燈籠旁")
	var solid_cells := world.collision.get_used_cells().size()
	var blocked := world.prop_blocked_tiles.size()
	_check(day_night.index == 0, "初始為白天")
	await _screenshot("06_day")
	await _tap_action("debug_cycle_daytime")
	await get_tree().create_timer(DayNightController.TRANSITION_SECONDS + 0.1).timeout
	_check(day_night.index == 1, "F5 切換為黃昏")
	await _screenshot("07_dusk")
	await _tap_action("debug_cycle_daytime")
	await get_tree().create_timer(DayNightController.TRANSITION_SECONDS + 0.1).timeout
	_check(day_night.index == 2, "F5 切換為夜晚")
	await _screenshot("08_night")
	_check(await _walk_to(Vector2i(6, 16)), "夜晚仍可正常行走")
	_check(await _push_against(Vector2i.UP, 0.6, func(p: Vector2) -> bool: return p.y >= 508.0), "夜晚房屋外牆仍然阻擋")
	await _tap_action("debug_cycle_daytime")
	_check(day_night.index == 0, "F5 切回白天")
	_check(world.collision.get_used_cells().size() == solid_cells and world.prop_blocked_tiles.size() == blocked, "日夜切換不改變碰撞")
	_check(await _walk_to(Vector2i(14, 29)), "回到出生點")


## Phase 3：公告欄接任務 → 家庭屋餐桌 → 船長房間航海圖桌 → 老龜回報；存檔／讀檔／損毀存檔。
func _phase3_checks() -> void:
	var quest_id := "demo_town_orientation"
	# Phase 2 已經與公告欄互動過一次：那次對話是「可接取」版本，結束時啟動任務並完成第一個目標
	_check(quests.quest_state(quest_id) == "active" and quests.is_objective_current(quest_id, "visit_family_table"), "公告欄對話啟動任務並完成第一個目標")
	_check(await _walk_to(Vector2i(20, 15)), "走回公告欄")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"bulletin_board"), "公告欄對話（進行中版本）")
	_check(quests.quest_state(quest_id) == "active" and quests.is_objective_current(quest_id, "visit_family_table"), "再次互動不會重複接任務")
	_check(quests.active_summary() == "查看共享家庭屋的餐桌", "任務 HUD 摘要更新為目前目標")
	await _tap_action("quest_log")
	_check(main_node.get("quest_hud").is_log_open(), "J 開啟任務日誌")
	await _screenshot("11_quest_log")
	await _tap_action("quest_log")

	# 共享家庭屋
	_check(await _walk_to(Vector2i(4, 21)), "走到共享家庭屋門口")
	_check(await _enter_portal(Vector2i.UP, "family_home"), "走進門口轉場到共享家庭屋")
	_check(party.order.size() == 4 and _all_members_in_world(), "進入家庭屋後四人都在室內")
	await _screenshot("09_family_home")
	_check(await _walk_to(Vector2i(6, 9)), "走到餐桌旁")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"family_table"), "餐桌互動（TEMP_DEMO_CONTENT）")
	_check(quests.is_objective_current(quest_id, "visit_chart_table"), "餐桌完成後目標更新為航海圖桌")
	_check(await _walk_to(Vector2i(9, 9)), "走到家庭屋出口上方")
	_check(await _enter_portal(Vector2i.DOWN, "tide_root_town"), "走出家庭屋回到主城")
	var leader_position := party.get_leader().global_position
	_check(leader_position.distance_to(Vector2(144, 702)) < 12.0, "返回位置在家庭屋門前（%s）" % leader_position)
	_check(_all_members_in_world(), "返回後隊伍完整")

	# 船長房間
	_check(await _walk_to(Vector2i(25, 21)), "走到船長房間門口")
	_check(await _enter_portal(Vector2i.UP, "captain_room"), "走進門口轉場到船長房間")
	await _screenshot("10_captain_room")
	_check(await _walk_to(Vector2i(12, 8)), "走到國王企鵝船長面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"king_penguin_captain"), "國王企鵝船長可互動")
	_check(await _walk_to(Vector2i(9, 7)), "走到航海圖桌下方")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"captain_chart_table"), "航海圖桌互動")
	_check(quests.is_objective_current(quest_id, "report"), "航海圖桌完成後目標更新為回報")
	_check(await _walk_to(Vector2i(9, 9)), "走到船長房間出口上方")
	_check(await _enter_portal(Vector2i.DOWN, "tide_root_town"), "走出船長房間回到主城")

	# 存檔：任務進行中、位置在船長房間門前
	_check(main_node.save_game() == "", "F6 存檔成功")
	var saved_position := party.get_leader().global_position
	var saved_day := day_night.index

	# 回報
	_check(await _walk_to(Vector2i(20, 27)), "走到市集老龜面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"old_turtle"), "市集老龜回報對話")
	_check(quests.quest_state(quest_id) == "completed" and main_node.state.has_flag("demo_orientation_complete"), "任務完成並取得旗標")

	# 讀檔：回到存檔時（任務進行中、船長房間門前）
	await _tap_action("debug_cycle_daytime")
	_check(main_node.load_game() == "", "F7 讀檔成功")
	await _wait_transition()
	quests = main_node.get("quests")
	_check(quests.quest_state(quest_id) == "active" and quests.is_objective_current(quest_id, "report"), "讀檔後任務回到進行中、目標為回報")
	_check(party.get_leader().global_position.distance_to(saved_position) < 2.0 and day_night.index == saved_day, "讀檔後位置與時段還原")
	_check(main_node.state.current_scene_id == "tide_root_town" and _all_members_in_world(), "讀檔後場景正確且隊伍完整")

	# 完成後再存檔、再讀檔：完成狀態持久
	_check(await _walk_to(Vector2i(20, 27)), "再次走到市集老龜面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"old_turtle"), "再次回報")
	_check(main_node.save_game() == "", "完成任務後存檔")
	main_node.state.set_flag("demo_orientation_complete", false)
	_check(main_node.load_game() == "", "再次讀檔")
	await _wait_transition()
	_check(main_node.state.has_flag("demo_orientation_complete") and main_node.get("quests").quest_state(quest_id) == "completed", "讀檔後完成旗標與任務狀態仍在")

	# 損毀存檔：讀檔失敗但保留目前狀態
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var before_scene: String = main_node.state.current_scene_id
	_check(main_node.load_game() != "", "損毀存檔讀檔回傳錯誤")
	_check(main_node.state.current_scene_id == before_scene and main_node.state.has_flag("demo_orientation_complete"), "損毀存檔不影響目前狀態")
	SaveManager.delete_save()
	_check(await _walk_to(Vector2i(14, 29)), "回到出生點")


## Phase 4：CC 任務 → 阿嬤取麵 → 交付傳送 → 受傷／戰敗返回 → 再傳送 → 四人各投擲一次（4 次不勝）→ 第 5 次勝利返回
## → 拒絕 CC 加入（💢 + OS）但仍加入 → 寵物跟隨 → 存讀檔保留寵物與旗標 → 弟弟速度。
func _phase4_checks() -> void:
	var quest_id := "cc_fried_food_battle"
	var state: GameState = main_node.state
	_check(await _walk_to(Vector2i(10, 30)), "走到早餐攤旁的 CC 面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"cc_penguin"), "初次與 CC 對話")
	_check(quests.quest_state(quest_id) == "active" and state.has_flag("cc_found") and quests.is_objective_current(quest_id, "get_noodles"), "CC 對話啟動任務，目標為取麵")
	await _screenshot("12_breakfast_stall")
	_check(await _interact_and_close(&"cc_penguin"), "沒有麵時再次與 CC 對話")
	await get_tree().create_timer(0.9).timeout
	_check(state.current_scene_id == "tide_root_town" and not router.is_transitioning and not state.has_item("chunhsiang_noodles"), "香椿乾拌麵未取得時 CC 不傳送")
	_check(await _walk_to(Vector2i(9, 30)), "走到阿嬤面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"grandma_turtle"), "阿嬤對話")
	_check(state.has_item("chunhsiang_noodles") and quests.is_objective_current(quest_id, "deliver_noodles"), "取得香椿乾拌麵，目標更新為交付")
	_check(await _walk_to(Vector2i(10, 30)), "拿著麵走回 CC 面前")
	await _face(Vector2i.UP)
	var cc_spot: Vector2 = party.get_leader().global_position
	_check(await _interact_and_close(&"cc_penguin"), "把麵交給 CC")
	_check(await _wait_transition_start(3.0), "交付後 CC 傳送（轉場開始）")
	await _wait_transition()
	_check(state.current_scene_id == "fried_food_cave" and _all_members_in_world(), "四人抵達炸物魔王洞窟")
	_check(state.return_scene_id == "tide_root_town" and state.return_position.distance_to(cc_spot) < 4.0, "返回點記在 CC 身旁")
	_check(not state.has_item("chunhsiang_noodles") and state.has_flag("cc_noodle_delivered") and quests.is_objective_current(quest_id, "defeat_demon"), "麵已交付、旗標與目標更新")
	_check(battle.active and battle.boss != null and battle.boss_hp() == 5, "戰鬥開始，Boss 生命 5")
	_check(main_node.save_game() == "", "洞窟內 F6 存檔（任務與傳送狀態）")
	_check(battle.boss.min_y >= 128.0 and battle.boss.global_position.y >= battle.boss.min_y, "Boss 生成點在活動上限之下（min_y %.0f）" % battle.boss.min_y)
	await _screenshot("13_cave_arrival")
	_check(_min_member_gap() >= 20.0, "抵達洞窟後四人與 CC 沒有同格重疊（最小間距 %.0f）" % _min_member_gap())

	# 受傷：Boss 衝撞 → 變色閃爍與無敵時間；生命 3 → 2
	battle.set_boss_paused(true)
	_check(await _walk_to(Vector2i(12, 7)), "走到 Boss 下方")
	await _face(Vector2i.UP)
	battle.set_boss_paused(false)
	battle.force_boss_attack()
	_check(await _wait_until(func() -> bool: return party.get_leader().is_invincible(), 2.5), "Boss 攻擊命中，領頭者變色閃爍並進入無敵時間")
	_check(battle.player_hp == 2, "受傷後生命 3 → 2")
	battle.set_boss_paused(true)
	await get_tree().create_timer(1.2).timeout

	# 戰敗：生命 1 再被打 → 回到 CC 身邊；麵的旗標不變
	_check(await _walk_to(Vector2i(12, 7)), "再次走到 Boss 下方")
	battle.set_player_hp(1)
	battle.set_boss_paused(false)
	battle.force_boss_attack()
	_check(await _wait_until(func() -> bool: return battle.player_hp == 0, 2.5), "生命歸零")
	_check(await _wait_transition_start(3.0), "戰敗後自動返回（轉場開始）")
	await _wait_transition()
	_check(state.current_scene_id == "tide_root_town" and party.get_leader().global_position.distance_to(cc_spot) < 48.0, "戰敗回到 CC 身旁")
	_check(state.has_flag("cc_noodle_delivered") and not state.has_flag("cc_fried_food_demon_defeated") and not battle.active, "戰敗不清除麵已交付旗標，Boss 未被擊倒")
	_check(await _walk_to(Vector2i(10, 30)), "走回 CC 面前")
	await _face(Vector2i.UP)
	_check(await _interact_and_close(&"cc_penguin"), "再次與 CC 對話")
	_check(await _wait_transition_start(3.0), "CC 再次傳送（重新開始）")
	await _wait_transition()
	_check(state.current_scene_id == "fried_food_cave" and battle.boss_hp() == 5 and battle.player_hp == 3, "重新進入洞窟，Boss 與生命重置")

	# 四位角色各撿一次、投一次：命中 4 次不勝利
	battle.set_boss_paused(true)
	var pickups: Array = [
		[0, &"vegetable_bundle", Vector2i(4, 8)],
		[1, &"green_tea", Vector2i(19, 8)],
		[2, &"water_flask", Vector2i(12, 12)],
		[3, &"vegetable_bundle", Vector2i(4, 8)],
	]
	for pickup: Array in pickups:
		var index: int = pickup[0]
		party.set_leader_by_index(index)
		switches_done += 1
		var leader := party.get_leader()
		_check(await _walk_to(pickup[2]), "%s 走到 %s 旁" % [leader.data.display_name, pickup[1]])
		await _face(Vector2i.UP)
		await _wait_frames(3)
		var target := interaction.current_target
		_check(target is CarryableItem and target.interactable_id == pickup[1] and interaction.prompt_visible(), "%s 靠近物品出現提示" % leader.data.display_name)
		await _tap_action("interact")
		_check(carry.is_leader_carrying() and carry.carried_item_id(leader) == String(pickup[1]), "%s 撿起並舉起 %s" % [leader.data.display_name, pickup[1]])
		if index == 0:
			await _screenshot("14_carry_item")
		_check(await _walk_to(Vector2i(12, 8)), "%s 舉著物品走到 Boss 下方" % leader.data.display_name)
		await _face(Vector2i.UP)
		var hp_before := battle.boss_hp()
		await _tap_action("interact")
		_check(not carry.is_leader_carrying(), "%s 按 E 投擲" % leader.data.display_name)
		_check(await _wait_until(func() -> bool: return battle.boss_hp() == hp_before - 1, 2.0), "%s 的投擲命中 Boss（生命 %d → %d）" % [leader.data.display_name, hp_before, hp_before - 1])
		if index == 1:
			await _screenshot_quick("15_boss_hit")
		await get_tree().create_timer(0.5).timeout
	_check(battle.boss_hp() == 1 and battle.hits_landed == 4 and battle.wings_spawned == 4, "命中 4 次：Boss 生命 1、掉落 4 隻炸雞翅")
	_check(not state.has_flag("cc_fried_food_demon_defeated") and state.current_scene_id == "fried_food_cave", "命中 4 次不會提前勝利")
	_check(await _wait_until(func() -> bool: return _item_count_in_world() == 3, 3.0), "命中消耗的物品在原位重新生成（地上共 3 件）")

	# 第 5 次命中 → 倒地 → 勝利 → 返回 CC
	party.set_leader_by_index(0)
	switches_done += 1
	_check(await _walk_to(Vector2i(12, 12)), "走到水旁")
	await _face(Vector2i.UP)
	await _wait_frames(3)
	await _tap_action("interact")
	_check(carry.is_leader_carrying(), "撿起水")
	_check(await _walk_to(Vector2i(12, 8)), "舉著水走到 Boss 下方")
	await _face(Vector2i.UP)
	await _tap_action("interact")
	_check(await _wait_until(func() -> bool: return battle.boss_hp() == 0, 2.0), "第 5 次命中，Boss 生命歸零")
	_check(battle.wings_spawned == 5 and not state.has_flag("cc_fried_food_demon_defeated"), "第 5 隻炸雞翅掉落；倒地演出結束前旗標未設定")
	_check(await _wait_transition_start(4.0), "倒地演出後返回（轉場開始）")
	_check(state.has_flag("cc_fried_food_demon_defeated") and quests.is_objective_current(quest_id, "return_to_cc"), "勝利旗標與任務事件在倒地後設定")
	await _wait_transition()
	_check(state.current_scene_id == "tide_root_town" and party.get_leader().global_position.distance_to(cc_spot) < 48.0 and _all_members_in_world(), "勝利回到 CC 身旁")
	_check(await _wait_until(func() -> bool: return _item_count_in_world() == 0, 0.5), "主城沒有投擲物")

	# CC 加入：拒絕分支
	_check(await _walk_to(Vector2i(10, 30)), "走到 CC 面前")
	await _face(Vector2i.UP)
	await _wait_frames(3)
	_check(interaction.current_target != null and interaction.current_target.interactable_id == &"cc_penguin", "CC 仍在早餐攤旁")
	await _tap_action("interact")
	var guard := 0
	while dialogue.is_active and not dialogue.is_choosing() and guard < 12:
		await _tap_action("interact")
		guard += 1
	_check(dialogue.is_active and dialogue.is_choosing(), "對話最後出現接受／拒絕選項")
	await _screenshot("16_cc_join_choice")
	await _tap_action("move_down")
	_check(dialogue.choice_index() == 1, "方向鍵下選到「拒絕」")
	await _tap_action("interact")
	_check(dialogue.is_active and not dialogue.is_choosing() and state.has_flag("cc_rejection_reaction_seen"), "確認拒絕後接續 💢 台詞")
	await _screenshot_quick("17_cc_rejected")
	guard = 0
	while dialogue.is_active and guard < 12:
		await _tap_action("interact")
		guard += 1
	_check(not dialogue.is_active and state.has_flag("cc_joined") and not state.has_flag("cc_join_choice"), "拒絕後 CC 仍然加入")
	_check(quests.quest_state(quest_id) == "completed" and state.has_flag("cc_quest_complete"), "CC 任務完成")
	world = main_node.get("world")
	_check(party.has_pet() and world.get_npc("cc_penguin") == null, "CC 從早餐攤旁消失、成為隊伍寵物")
	_check(await _walk_to(Vector2i(14, 27)), "帶著 CC 走一段路")
	_check(await _wait_until(func() -> bool: return party.pet.global_position.distance_to(party.order.back().global_position) < 90.0, 3.0), "CC 跟在隊伍最後一位後面")
	_check(not party.order_ids().has("cc_penguin") and party.members.size() == 4, "CC 不在可切換的四人名單裡")
	await _screenshot("18_pet_follow")

	# 存讀檔：寵物與旗標保留；讀到未加入的存檔則寵物消失、CC 回到攤旁
	_check(main_node.save_game() == "", "加入後存檔")
	var joined_text := FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var before: Dictionary = JSON.parse_string(joined_text)
	before["pet_id"] = ""
	before["flags"].erase("cc_joined")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(before))
	file.close()
	_check(main_node.load_game() == "", "讀取未加入 CC 的存檔")
	await _wait_transition()
	world = main_node.get("world")
	_check(not party.has_pet() and world.get_npc("cc_penguin") != null, "讀檔後寵物消失、CC 回到早餐攤旁")
	file = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(joined_text)
	file.close()
	_check(main_node.load_game() == "", "讀回加入後的存檔")
	await _wait_transition()
	world = main_node.get("world")
	state = main_node.state
	_check(party.has_pet() and world.get_npc("cc_penguin") == null and state.has_flag("cc_joined") and state.has_flag("cc_fried_food_demon_defeated"), "讀檔後寵物、CC 加入與擊倒旗標保留")
	SaveManager.delete_save()

	# 弟弟速度
	party.set_leader_by_index(3)
	switches_done += 1
	var younger := party.get_leader()
	_check(younger.controlled_speed() > party.members[0].controlled_speed() and is_equal_approx(party.members[0].controlled_speed(), party.members[0].data.walk_speed), "弟弟被操控時比哥哥快，哥哥用 walk_speed")
	await _push_for(Vector2i.RIGHT, 0.3)
	party.set_leader_by_index(0)
	switches_done += 1
	_check(await _walk_to(Vector2i(14, 29)), "回到出生點")


## Phase 4.6：行走／待機動畫切換、停下先停在 contact A、陰影固定在地面錨點、待機時 VisualRoot 不位移、切換領頭者後動畫正確。
func _phase46_checks() -> void:
	var leader := party.get_leader()
	_press_only(Vector2i.RIGHT)
	await get_tree().create_timer(0.3).timeout
	_check(String(leader.current_animation()) == "walk_right" and leader.sprite.is_playing(), "移動中播放 walk_right")
	var shadow: Sprite2D = leader.get_node("Shadow")
	var shadow_offset_moving := shadow.global_position - leader.global_position
	_release_all()
	await get_tree().create_timer(0.05).timeout
	_check(String(leader.current_animation()) == "walk_right" and not leader.sprite.is_playing() and leader.sprite.frame == 0, "剛停下時停在行走表 contact A 幀")
	await get_tree().create_timer(0.3).timeout
	_check(String(leader.current_animation()) == "idle_right" and leader.sprite.is_playing(), "停下 0.12 秒後切回 idle_right")
	var shadow_positions: Array[Vector2] = []
	var visual_offsets: Array[float] = []
	for _i: int in range(7):
		shadow_positions.append(shadow.global_position)
		visual_offsets.append(leader.visual_root.position.y)
		await get_tree().create_timer(0.2).timeout
	var shadow_fixed := true
	var visual_fixed := true
	for index: int in range(shadow_positions.size()):
		if shadow_positions[index] != leader.global_position:
			shadow_fixed = false
		if not is_zero_approx(visual_offsets[index]):
			visual_fixed = false
	_check(shadow_fixed and shadow_offset_moving == Vector2.ZERO, "陰影全程固定在地面錨點（移動與待機 1.4 秒）")
	_check(visual_fixed, "待機 1.4 秒內 VisualRoot 不位移（呼吸由待機表負責）")
	var frames_seen := {}
	for _i: int in range(8):
		frames_seen[leader.sprite.frame] = true
		await get_tree().create_timer(0.18).timeout
	_check(frames_seen.size() >= 3, "待機表確實在播放（1.4 秒內看到 %d 個不同幀）" % frames_seen.size())
	var all_have_shadow := true
	for member: PlayableCharacter in party.members:
		var member_shadow := member.get_node_or_null("Shadow") as Sprite2D
		if member_shadow == null or member_shadow.global_position != member.global_position or not member.has_idle_sheet():
			all_have_shadow = false
	if party.has_pet():
		var pet_shadow := party.pet.get_node_or_null("Shadow") as Sprite2D
		if pet_shadow == null or pet_shadow.global_position != party.pet.global_position:
			all_have_shadow = false
	_check(all_have_shadow, "四位角色與 CC 都有陰影且都在各自的地面錨點")
	party.cycle_leader()
	switches_done += 1
	var new_leader := party.get_leader()
	_press_only(Vector2i.LEFT)
	await get_tree().create_timer(0.3).timeout
	_check(new_leader != leader and String(new_leader.current_animation()) == "walk_left", "切換領頭者後新領頭者播放 walk_left")
	_release_all()
	await get_tree().create_timer(0.4).timeout
	_check(String(new_leader.current_animation()) == "idle_left", "新領頭者停下後回到 idle_left")
	await _screenshot("19_idle_shadow")
	_check(await _walk_to(Vector2i(14, 29)), "回到出生點")
	await get_tree().create_timer(1.2).timeout
	_check(_min_member_gap() >= 20.0, "停下 1.2 秒後隊伍沒有同格重疊（最小間距 %.0f）" % _min_member_gap())


## Phase 5：更新後的下層廣場（噴泉繞行、拱門穿越、新早餐攤／樹屋門）、休息流程（取消不加天、確認加一天、
## 重複觸發只加一天、自動存檔、每日旗標重置、永久資料保留、早晨→白天）、切場景不加天、v2 存檔遷移、夜晚燈籠。
func _phase5_checks() -> void:
	var state: GameState = main_node.state
	world = main_node.get("world")
	_check(state.day == 1 and state.schema_version == 3 and state.daily_state.is_empty(), "Phase 5 開始時為第 1 天（schema v3、無每日旗標）")
	_check(world.prop_blocked_tiles.has(Vector2i(19, 30)) and world.prop_blocked_tiles.has(Vector2i(20, 29)), "心形噴泉的碰撞登記為封鎖格")
	_check(await _walk_to(Vector2i(17, 31)), "走到噴泉左側")
	_check(await _walk_to(Vector2i(22, 31)), "繞過噴泉走到右側草地")
	_check(await _walk_to(Vector2i(20, 31)), "走到噴泉正下方")
	_check(await _push_against(Vector2i.UP, 0.6, func(p: Vector2) -> bool: return p.y >= 990.0), "噴泉水池阻擋，不會走進噴泉")
	_check(world.prop_blocked_tiles.has(Vector2i(13, 23)) and world.prop_blocked_tiles.has(Vector2i(16, 23)) and not world.prop_blocked_tiles.has(Vector2i(14, 23)) and not world.prop_blocked_tiles.has(Vector2i(15, 23)), "拱門兩腳封鎖第 13／16 欄，中央第 14～15 欄可通行")
	_check(await _walk_to(Vector2i(14, 25)), "走到拱門下方")
	_check(await _walk_to(Vector2i(14, 22)), "穿過拱門走上樓梯")
	_check(await _walk_to(Vector2i(14, 25)), "穿過拱門回到廣場")
	_check(await _followers_catch_up(3.0, 110.0), "穿過拱門後跟隨者 3 秒內追上")
	_check(await _walk_to(Vector2i(14, 28)), "走到廣場中央上方")
	await _screenshot("20_plaza_refresh")
	_check(await _walk_to(Vector2i(9, 30)), "走到新早餐攤前")
	await _face(Vector2i.UP)
	await _wait_frames(3)
	_check(interaction.current_target != null and interaction.current_target.interactable_id == &"grandma_turtle", "新早餐攤前仍可鎖定阿嬤互動")

	# 家庭屋：休息點提示、取消休息
	_check(await _walk_to(Vector2i(4, 21)), "走到共享家庭屋門口（新樹屋外觀）")
	_check(await _enter_portal(Vector2i.UP, "family_home"), "新樹屋門口仍可進入家庭屋")
	state = main_node.state
	_check(await _walk_to(Vector2i(2, 6)), "走到臥室門旁")
	await _push_for(Vector2i.LEFT, 0.3)
	await _wait_frames(3)
	var target := interaction.current_target
	_check(target != null and target.interactable_id == &"family_rest_door" and interaction.prompt_visible() and target.prompt_texture != null, "臥室門出現休息提示圖示")
	await _screenshot("21_rest_prompt")
	await _tap_action("interact")
	var guard := 0
	while dialogue.is_active and not dialogue.is_choosing() and guard < 12:
		await _tap_action("interact")
		guard += 1
	_check(dialogue.is_active and dialogue.is_choosing(), "臥室門對話出現休息／再等等選項")
	await _tap_action("move_down")
	_check(dialogue.choice_index() == 1, "方向鍵下選到「再等等」")
	await _tap_action("interact")
	guard = 0
	while dialogue.is_active and guard < 12:
		await _tap_action("interact")
		guard += 1
	await get_tree().create_timer(0.3).timeout
	_check(not dialogue.is_active and state.day == 1 and not main_node.is_resting(), "取消休息：day 仍為 1、沒有進入轉場")
	for _i: int in range(3):
		await _tap_action("debug_cycle_daytime")
	_check(day_night.index == 0 and state.day == 1, "F5 三次回到白天，day 不變")

	# 每日示範旗標：流理台
	_check(await _walk_to(Vector2i(4, 4)), "走到流理台前")
	_check(await _push_against(Vector2i.UP, 0.4, func(p: Vector2) -> bool: return p.y >= 100.0), "流理台阻擋")
	_check(await _interact_and_close(&"kitchen_counter"), "流理台互動（今天第一次）")
	_check(state.has_daily_flag("demo_counter_checked_today"), "流理台互動設定每日示範旗標")
	await _wait_frames(3)
	var counter_target := interaction.current_target
	var again: Dictionary = DialogueResolver.resolve(counter_target.dialogue_entry, state, quests) if counter_target != null else {"on_complete": [1]}
	_check(counter_target != null and again["on_complete"].is_empty(), "同一天再互動流理台為「已看過」版本")

	# 確認休息（先離開流理台的封鎖格，BFS 才有起點）
	await _push_for(Vector2i.DOWN, 0.25)
	var day_before := state.day
	_check(await _walk_to(Vector2i(2, 6)), "走回臥室門旁")
	await _push_for(Vector2i.LEFT, 0.3)
	await _wait_frames(3)
	await _tap_action("interact")
	guard = 0
	while dialogue.is_active and not dialogue.is_choosing() and guard < 12:
		await _tap_action("interact")
		guard += 1
	_check(dialogue.is_choosing() and dialogue.choice_index() == 0, "選項預設在「休息」")
	await _tap_action("interact")
	guard = 0
	while dialogue.is_active and guard < 12:
		await _tap_action("interact")
		guard += 1
	_check(await _wait_until(func() -> bool: return main_node.is_resting(), 1.0), "確認休息後開始轉場")
	main_node.rest_until_morning()
	main_node.rest_until_morning()
	await get_tree().create_timer(1.4).timeout
	await _screenshot_quick("22_rest_sunrise")
	_check(await _wait_until(func() -> bool: return not main_node.is_resting(), 8.0), "休息轉場結束")
	state = main_node.state
	world = main_node.get("world")
	_check(state.day == day_before + 1, "休息後 day +1，轉場中重複觸發不會再加（day %d）" % state.day)
	_check(state.current_scene_id == "family_home" and party.get_leader().global_position.distance_to(Vector2(80, 208)) < 12.0 and _all_members_in_world(), "醒來時在家庭屋的醒來點")
	_check(day_night.is_morning() and day_night.state_label() == "早晨" and day_night.index == 0, "醒來後為早晨色調（時段狀態仍是白天）")
	_check(not state.has_daily_flag("demo_counter_checked_today") and state.daily_state.is_empty(), "每日示範旗標在新的一天被重置")
	_check(state.has_flag("cc_joined") and state.has_flag("cc_fried_food_demon_defeated") and party.has_pet() and quests.quest_state("cc_fried_food_battle") == "completed", "永久旗標、CC 寵物與任務狀態不被每日重置清掉")
	await _screenshot("23_morning_wake")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	_check(typeof(saved) == TYPE_DICTIONARY and int(saved.get("day", 0)) == state.day and int(saved.get("schema_version", 0)) == 3 and (saved.get("daily_state", {"x": 1}) as Dictionary).is_empty(), "休息時自動存檔：day 與 schema v3 寫入、daily_state 為空")
	_check(await _wait_until(func() -> bool: return not day_night.is_morning(), DayNightController.MORNING_SECONDS + 1.0), "早晨在數秒內漸變成白天")

	# 切換場景不增加 day；讀檔保留 day；v2 存檔遷移
	_check(await _walk_to(Vector2i(9, 9)), "走到家庭屋出口上方")
	_check(await _enter_portal(Vector2i.DOWN, "tide_root_town"), "走出家庭屋回到主城")
	_check(await _walk_to(Vector2i(4, 21)), "再走到家庭屋門口")
	_check(await _enter_portal(Vector2i.UP, "family_home"), "再次進入家庭屋")
	state = main_node.state
	_check(state.day == day_before + 1, "連續切換場景不會增加 day")
	_check(main_node.load_game() == "", "F7 讀取休息時的自動存檔")
	await _wait_transition()
	state = main_node.state
	quests = main_node.get("quests")
	_check(state.day == day_before + 1 and state.has_flag("cc_joined") and party.has_pet() and state.current_scene_id == "family_home", "讀檔後 day、旗標、寵物與場景一致")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	raw["schema_version"] = 2
	raw.erase("day")
	raw.erase("day_seed")
	raw.erase("daily_state")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	_check(main_node.load_game() == "", "讀取 v2 格式存檔")
	await _wait_transition()
	state = main_node.state
	quests = main_node.get("quests")
	_check(state.day == 1 and state.schema_version == 3 and state.has_flag("cc_joined") and party.has_pet(), "v2 存檔遷移為 v3：day 1、旗標與寵物保留")
	SaveManager.delete_save()

	# 回主城：夜晚的 v2 燈籠
	world = main_node.get("world")
	_check(await _walk_to(Vector2i(9, 9)), "走到家庭屋出口上方")
	_check(await _enter_portal(Vector2i.DOWN, "tide_root_town"), "回到主城")
	_check(await _walk_to(Vector2i(14, 29)), "回到出生點")
	await _tap_action("debug_cycle_daytime")
	await _tap_action("debug_cycle_daytime")
	await get_tree().create_timer(DayNightController.TRANSITION_SECONDS + 0.1).timeout
	_check(day_night.index == 2, "F5 兩次切到夜晚")
	await _screenshot("24_plaza_night")
	await _tap_action("debug_cycle_daytime")
	_check(day_night.index == 0 and main_node.state.day == 1, "F5 切回白天，day 不變")


## 隊伍成員（含 CC）兩兩之間的最小距離。
func _min_member_gap() -> float:
	var bodies: Array[Node2D] = []
	for member: PlayableCharacter in party.order:
		bodies.append(member)
	if party.has_pet():
		bodies.append(party.pet)
	var smallest := INF
	for a: int in range(bodies.size()):
		for b: int in range(a + 1, bodies.size()):
			smallest = minf(smallest, bodies[a].global_position.distance_to(bodies[b].global_position))
	return smallest


func _item_count_in_world() -> int:
	world = main_node.get("world")
	var count := 0
	for interactable: Interactable in world.get_interactables():
		if interactable is CarryableItem:
			count += 1
	return count


func _wait_until(predicate: Callable, seconds: float) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		if bool(predicate.call()):
			return true
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	return bool(predicate.call())


func _wait_transition_start(seconds: float) -> bool:
	return await _wait_until(func() -> bool: return router.is_transitioning, seconds)


func _screenshot_quick(file_name: String) -> void:
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	var path := shots_dir.path_join(file_name + ".png")
	if image.save_png(path) != OK:
		failures.append("截圖失敗：%s" % path)
	else:
		passes.append("截圖：%s" % path)


func _enter_portal(direction: Vector2i, expected_scene: String) -> bool:
	var started := false
	var elapsed := 0.0
	while elapsed < 2.0 and not started:
		_press_only(direction)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		started = router.is_transitioning
	_release_all()
	if not started:
		failures.append("走向 %s 沒有觸發轉場" % direction)
		return false
	await _wait_transition()
	world = main_node.get("world")
	if main_node.state.current_scene_id != expected_scene:
		failures.append("轉場後場景為 %s，預期 %s" % [main_node.state.current_scene_id, expected_scene])
		return false
	return true


func _wait_transition() -> void:
	var elapsed := 0.0
	while elapsed < 5.0:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if not router.is_transitioning and elapsed > 0.05:
			break
	world = main_node.get("world")
	await _wait_frames(2)


func _all_members_in_world() -> bool:
	world = main_node.get("world")
	for member: PlayableCharacter in party.members:
		if not world.world_rect.has_point(member.global_position):
			return false
	return true


## 對目前目標互動：確認目標 id、對話開啟，然後一路按 E 關閉。
func _interact_and_close(expected_id: StringName) -> bool:
	await _wait_frames(3)
	var target := interaction.current_target
	if target == null or target.interactable_id != expected_id:
		failures.append("互動目標不是 %s（實際：%s）" % [expected_id, target.interactable_id if target != null else "無"])
		return false
	await _tap_action("interact")
	if not dialogue.is_active:
		failures.append("對 %s 按 E 後對話沒有開啟" % expected_id)
		return false
	var guard := 0
	while dialogue.is_active and guard < 20:
		await _tap_action("interact")
		guard += 1
	if dialogue.is_active:
		failures.append("%s 的對話無法關閉" % expected_id)
		return false
	return true


## 以 InputEventAction 模擬按一下（Input.action_press 不會派送事件，_unhandled_input 收不到）。
func _tap_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame


func _face(direction: Vector2i) -> void:
	_press_only(direction)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_release_all()


func _push_for(direction: Vector2i, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		_press_only(direction)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_release_all()


func _wait_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().physics_frame


func _physics_process(_delta: float) -> void:
	if not _running or party == null or party.order.size() < 2 or router == null or router.is_transitioning:
		return
	if main_node != null:
		world = main_node.get("world")
	if world == null or not is_instance_valid(world):
		return
	for index: int in range(1, party.order.size()):
		var member: PlayableCharacter = party.order[index]
		var tile := world.world_to_tile(member.global_position)
		if not world.world_rect.has_point(member.global_position):
			follower_violations.append("%s 掉出地圖 %s" % [member.name, member.global_position])
		elif world.parser.is_solid(tile.x, tile.y):
			follower_violations.append("%s 位於實心格 %s" % [member.name, tile])
	if battle != null and battle.active and battle.boss != null and is_instance_valid(battle.boss):
		if battle.boss.global_position.y < battle.boss.min_y - 0.5:
			boss_bound_violations.append("Boss y=%.1f 高於 min_y=%.1f" % [battle.boss.global_position.y, battle.boss.min_y])


func _walk_to(goal: Vector2i) -> bool:
	var tiles_since_switch := 0
	while true:
		if router != null and router.is_transitioning:
			_release_all()
			failures.append("走向 %s 途中發生轉場" % goal)
			return false
		if main_node != null:
			world = main_node.get("world")
		var leader := party.get_leader()
		var start := world.world_to_tile(leader.global_position)
		if start == goal and leader.global_position.distance_to(world.tile_to_world(goal)) < 6.0:
			_release_all()
			return true
		var path := world.find_tile_path(start, goal)
		if path.is_empty():
			_release_all()
			failures.append("找不到 %s → %s 的路徑" % [start, goal])
			return false
		var replan := false
		for index: int in range(1, path.size()):
			if not await _step_to_tile(path[index]):
				_release_all()
				return false
			tiles_since_switch += 1
			if switches_done < SWITCH_TARGET and tiles_since_switch >= SWITCH_EVERY_TILES:
				party.cycle_leader()
				switches_done += 1
				tiles_since_switch = 0
				replan = true
				break
		if not replan:
			_release_all()
			return true
	return false


func _step_to_tile(tile: Vector2i) -> bool:
	var target := world.tile_to_world(tile)
	var elapsed := 0.0
	while elapsed < TILE_TIMEOUT:
		var leader := party.get_leader()
		var delta := target - leader.global_position
		if delta.length() < 3.0:
			return true
		# 同時按住兩軸（像玩家斜走），這樣沿牆邊走時另一軸也會持續修正，不會被牆角卡住。
		var pressed: Array[Vector2i] = []
		if absf(delta.x) > 1.5:
			pressed.append(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
		if absf(delta.y) > 1.5:
			pressed.append(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)
		_press_axes(pressed)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	failures.append("走向 %s 逾時（領頭者位於 %s）" % [tile, party.get_leader().global_position])
	return false


func _push_against(direction: Vector2i, seconds: float, predicate: Callable) -> bool:
	var elapsed := 0.0
	var ok := true
	while elapsed < seconds:
		_press_only(direction)
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var position := party.get_leader().global_position
		var tile := world.world_to_tile(position)
		if not predicate.call(position) or world.parser.is_solid(tile.x, tile.y):
			ok = false
	_release_all()
	if not ok:
		failures.append("推向 %s 時穿越了封鎖（位置 %s）" % [direction, party.get_leader().global_position])
	return ok


## 每 0.12 秒交替按左／右，模擬玩家快速反覆移動。
func _jitter(seconds: float) -> void:
	var elapsed := 0.0
	var flip := false
	while elapsed < seconds:
		_press_only(Vector2i.LEFT if flip else Vector2i.RIGHT)
		flip = not flip
		await get_tree().create_timer(0.12).timeout
		elapsed += 0.12
	_release_all()


## 等待最多 seconds 秒，檢查每位跟隨者與其前一位隊員的距離是否都小於 max_gap。
func _followers_catch_up(seconds: float, max_gap: float) -> bool:
	_release_all()
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if _max_chain_gap() <= max_gap:
			return true
	failures.append("跟隨者未追上（最大間距 %.1f px）" % _max_chain_gap())
	return false


func _max_chain_gap() -> float:
	var worst := 0.0
	for index: int in range(1, party.order.size()):
		var gap: float = party.order[index].global_position.distance_to(party.order[index - 1].global_position)
		worst = maxf(worst, gap)
	return worst


func _press_only(axis: Vector2i) -> void:
	_press_axes([axis])


func _press_axes(axes: Array[Vector2i]) -> void:
	for key: Vector2i in AXIS_ACTIONS:
		if axes.has(key):
			Input.action_press(AXIS_ACTIONS[key])
		else:
			Input.action_release(AXIS_ACTIONS[key])


func _release_all() -> void:
	for action: String in AXIS_ACTIONS.values():
		Input.action_release(action)


func _screenshot(file_name: String) -> void:
	_release_all()
	await get_tree().create_timer(0.9).timeout
	# 用 process_frame 而非 frame_post_draw：視窗被遮蔽時 macOS 可能暫停重繪，frame_post_draw 會永遠等不到。
	await get_tree().process_frame
	await get_tree().process_frame
	# 視窗被遮蔽或螢幕休眠時 Godot 會跳過繪製，viewport 貼圖會停在舊畫面；強制同步重繪一次再讀取。
	RenderingServer.force_draw(true)
	var image := get_viewport().get_texture().get_image()
	var path := shots_dir.path_join(file_name + ".png")
	var error := image.save_png(path)
	if error != OK:
		failures.append("截圖失敗：%s（%d）" % [path, error])
	else:
		passes.append("截圖：%s" % path)


func _check(condition: bool, label: String) -> void:
	if condition:
		passes.append(label)
	else:
		failures.append(label)
	print("%s  %s  (t=%.1fs)" % ["ok  " if condition else "FAIL", label, Time.get_ticks_msec() / 1000.0])


func _report() -> void:
	print("=== ROUTE TEST REPORT ===")
	for line: String in passes:
		print("PASS  ", line)
	for line: String in failures:
		print("FAIL  ", line)
	for line: String in follower_violations.slice(0, 5):
		print("FOLLOWER  ", line)
	print("切換次數：%d" % switches_done)
	print("結果：%s（%d 通過，%d 失敗）" % ["PASS" if failures.is_empty() else "FAIL", passes.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
