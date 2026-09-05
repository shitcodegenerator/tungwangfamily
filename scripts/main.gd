extends Node2D
## 主場景：組合世界（由 SceneRouter 依 scene_id 建立）、隊伍、鏡頭、互動、對話、任務、存檔、日夜、
## 撿取／投擲、炸物魔王戰鬥與寵物。這裡只做接線：
##   可互動物件 → 對話（依狀態挑版本）→ 任務動作；地上的投擲物 → CarrySystem；傳送門 → 路由；
##   對話與轉場 → 輸入鎖；F6／F7 → SaveManager；戰鬥勝負 → 旗標、任務事件、回到 CC 身邊；
##   休息確認（對話 rest 動作）→ 淡出 → day +1 → 回到家庭屋 → 存檔 → 早晨轉場（Phase 5）。
## 帶 `-- --route-test` 參數啟動時執行自動化驗證。

const ROUTE_TEST_SCRIPT := preload("res://scripts/debug/route_test.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/debug/snapshot.gd")
const PET_SCENE := preload("res://scenes/characters/pet_follower.tscn")
const TELEPORT_FX := preload("res://assets/effects/fx_teleport.png")
const ANGER_MARK := preload("res://assets/ui/anger_mark.png")
const PORTRAIT_DIR := "res://assets/portraits/"
const PET_DATA_DIR := "res://assets/characters/pets/"
const TELEPORT_DELAY := 0.55
const RETURN_DELAY := 0.4
const CC_NPC_ID := "cc_penguin"
const CC_PET_ID := "cc_penguin"
const REST_SCENE_ID := "family_home"
const REST_ENTRY := "rest"

@onready var world_parent: Node2D = $World
@onready var day_night: DayNightController = $World/DayNight
@onready var ambient: AmbientEffects = $World/AmbientEffects
@onready var party: PartyController = $PartyController
@onready var camera: CameraRig = $CameraRig
@onready var interaction: InteractionController = $InteractionController
@onready var dialogue: DialogueManager = $DialogueManager
@onready var quests: QuestManager = $QuestManager
@onready var router: SceneRouter = $SceneRouter
@onready var carry: CarrySystem = $CarrySystem
@onready var battle: BattleDirector = $BattleDirector
@onready var quest_hud: QuestHud = $QuestHud
@onready var battle_hud: BattleHud = $BattleHud
@onready var hud: DebugHUD = $DebugHUD
@onready var day_hud: DayHud = $DayHud
@onready var rest_transition: RestTransition = $RestTransition

var state: GameState = GameState.new()
var world: TownWorld

var _pending_actions: Array = []
var _pending_interactable_id: String = ""
var _ambient_ready: bool = false
var _returning: bool = false
var _resting: bool = false


func _ready() -> void:
	party.leader_changed.connect(_on_leader_changed)
	quests.bind(state)
	quests.item_received.connect(func(item_id: String) -> void: quest_hud.show_toast("取得：%s" % item_label(item_id)))
	quest_hud.bind(quests)
	carry.bind(party)
	battle.bind(party, carry)
	battle.battle_won.connect(_on_battle_won)
	battle.battle_lost.connect(_on_battle_lost)
	battle_hud.bind(battle)
	interaction.bind(party, dialogue, carry)
	dialogue.dialogue_started.connect(_on_dialogue_started)
	dialogue.dialogue_finished.connect(_on_dialogue_finished)
	dialogue.choice_selected.connect(_on_choice_selected)
	day_night.state_changed.connect(_on_daytime_changed)

	router.bind(state, party, camera, world_parent)
	router.scene_changed.connect(_on_scene_changed)
	router.transition_started.connect(_on_transition_started)
	router.transition_finished.connect(func(_id: String) -> void: _set_input_locked(false))
	router.load_scene(state.current_scene_id)
	_on_daytime_changed(day_night.state_name(), day_night.index)
	day_hud.bind(state, day_night)

	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--route-test"):
		var test: Node = ROUTE_TEST_SCRIPT.new()
		test.name = "RouteTest"
		add_child(test)
	for arg: String in user_args:
		if arg.begins_with("--snapshot="):
			var snapshot: Node = SNAPSHOT_SCRIPT.new()
			snapshot.name = "Snapshot"
			add_child(snapshot)
			break


func _on_transition_started(_scene_id: String) -> void:
	_set_input_locked(true)
	carry.clear_all()


func _on_scene_changed(scene_id: String, new_world: TownWorld) -> void:
	world = new_world
	for interactable: Interactable in world.get_interactables():
		interactable.interacted.connect(_on_interacted)
	world.interactable_added.connect(func(node: Interactable) -> void: node.interacted.connect(_on_interacted))
	world.portal_entered.connect(router.enter_portal)
	world.apply_daytime(day_night.index)
	carry.set_world(world)
	if router.is_outdoor(scene_id):
		if not _ambient_ready:
			ambient.setup(world.get_zone_rect("中層樹洞街"), world.get_zone_rect("下層樹根廣場"))
			_ambient_ready = true
		ambient.visible = true
	else:
		ambient.visible = false
	hud.bind(party, world, day_night)
	_sync_pet()
	var config := router.battle_config(scene_id)
	if config.is_empty():
		battle.stop()
		battle_hud.hide_battle()
	else:
		battle.start(world, config)
		battle_hud.show_battle(String(config.get("boss_name", "炸物魔王")))
	quests.notify_scene_entered(scene_id)


func _on_leader_changed(leader: PlayableCharacter, _roster_index: int) -> void:
	camera.follow(leader)


## E：地上的投擲物 → 撿起；其他 → 依狀態挑對話版本。
func _on_interacted(interactable: Interactable) -> void:
	if dialogue.is_active or router.is_transitioning:
		return
	if interactable is CarryableItem:
		carry.pick_up(interactable as CarryableItem)
		return
	var resolved: Dictionary = DialogueResolver.resolve(interactable.dialogue_entry, state, quests)
	if interactable.owner_node is NpcCharacter:
		(interactable.owner_node as NpcCharacter).face_toward(party.get_leader().global_position)
	_pending_actions = resolved["on_complete"]
	_pending_interactable_id = String(interactable.interactable_id)
	var portrait_id: String = resolved["portrait"] if not String(resolved["portrait"]).is_empty() else interactable.portrait_id
	dialogue.start(resolved["speaker"], resolved["lines"], load_portrait(portrait_id), resolved["choice"])


static func load_portrait(portrait_id: String) -> Texture2D:
	if portrait_id.is_empty():
		return null
	var path := PORTRAIT_DIR + portrait_id + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func item_label(item_id: String) -> String:
	match item_id:
		"chunhsiang_noodles":
			return "香椿乾拌麵"
		_:
			return item_id


func _on_dialogue_started(_speaker: String) -> void:
	_set_input_locked(true)
	hud.set_status_visible(false)


## 選項確認當下：先套用 on_select（例如拒絕時的 💢），再讓對話播選項的後續句子。
func _on_choice_selected(option: Dictionary) -> void:
	var actions: Variant = option.get("on_select", [])
	if typeof(actions) != TYPE_ARRAY:
		return
	quests.apply_actions(actions)
	_apply_scene_actions(actions)


func _on_dialogue_finished() -> void:
	_set_input_locked(false)
	hud.set_status_visible(true)
	var actions: Array = _pending_actions + dialogue.take_chosen_actions()
	var target := _pending_interactable_id
	_pending_actions = []
	_pending_interactable_id = ""
	quests.apply_actions(actions)
	if not target.is_empty():
		quests.notify_interact(target)
	_apply_scene_actions(actions)
	_sync_pet()


## 場景層級的動作：teleport（CC 傳送到洞窟，記住返回點）、show_anger（NPC 頭上的 💢）、rest（休息到隔天早晨）。
func _apply_scene_actions(actions: Array) -> void:
	for action: Variant in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		if action.has("show_anger"):
			_show_anger(String(action["show_anger"]))
		if action.has("teleport"):
			teleport_to(String(action["teleport"]))
		if action.get("rest", false) == true:
			rest_until_morning()


## 休息流程：淡出 → day +1（daily_state 重置）→ 回到家庭屋的醒來點 → 存檔 → 日出卡 → 淡入 → 早晨色調漸變成白天。
## 同一次休息只會增加 1 天：轉場進行中重複觸發會被忽略。
func rest_until_morning() -> void:
	if _resting or router.is_transitioning or world == null:
		return
	_resting = true
	_set_input_locked(true)
	await rest_transition.play(state.day + 1, _on_rest_dark)
	day_night.play_morning()
	_resting = false
	_set_input_locked(false)


## 畫面全黑時：進入下一天、重建家庭屋（NPC／道具依新一天的狀態）、把隊伍放到醒來點、存檔。
func _on_rest_dark() -> void:
	state.advance_day()
	day_night.set_state(0, true)
	carry.clear_all()
	router.load_scene(REST_SCENE_ID, REST_ENTRY)
	await get_tree().physics_frame
	capture_runtime_state()
	var error := SaveManager.save_state(state)
	if not error.is_empty():
		quest_hud.show_toast("存檔失敗：" + error)


func is_resting() -> bool:
	return _resting


func _show_anger(npc_id: String) -> void:
	if world == null:
		return
	var npc := world.get_npc(npc_id)
	var at := npc.global_position + Vector2(10.0, -52.0) if npc != null else party.get_leader().global_position + Vector2(10.0, -70.0)
	EffectSprite.spawn(world, ANGER_MARK, at, 1.6, true, 30)


## CC 傳送：返回點記在 CC 身旁（領頭者現在的位置），CC 本人不進洞窟。
func teleport_to(scene_id: String) -> void:
	if router.is_transitioning or not router.has_scene(scene_id) or world == null:
		return
	state.return_scene_id = world.scene_id
	state.return_position = party.get_leader().global_position
	for member: PlayableCharacter in party.members:
		EffectSprite.spawn(world, TELEPORT_FX, member.global_position + Vector2(0.0, -30.0), TELEPORT_DELAY + 0.2, false, 12)
	_set_input_locked(true)
	await get_tree().create_timer(TELEPORT_DELAY).timeout
	await router.travel(scene_id, "default")


## 勝利：旗標與任務事件只在 Boss 倒地演出結束後才設定，然後回到 CC 身邊。
func _on_battle_won() -> void:
	state.set_flag("cc_fried_food_demon_defeated", true)
	state.set_flag("cc_cave_active", false)
	quests.notify_event("fried_food_demon_defeated")
	quest_hud.show_toast("炸物魔王倒下了！")
	_return_to_cc()


## 失敗：清掉本次戰鬥暫態，回到 CC 身邊；香椿乾拌麵已交付的旗標不動。
func _on_battle_lost() -> void:
	state.set_flag("cc_cave_active", false)
	quest_hud.show_toast("被炸雞翅打倒了……回到 CC 身邊")
	_return_to_cc()


func _return_to_cc() -> void:
	if _returning or router.is_transitioning:
		return
	_returning = true
	_set_input_locked(true)
	await get_tree().create_timer(RETURN_DELAY).timeout
	var scene_id := state.return_scene_id if router.has_scene(state.return_scene_id) else GameState.DEFAULT_SCENE
	await router.travel(scene_id, "default", [], state.return_position)
	_returning = false


## 寵物與旗標同步：cc_joined 後 CC 從早餐攤旁消失、變成跟在隊伍最後的寵物；讀到未加入的存檔則移除寵物。
func _sync_pet() -> void:
	if world == null:
		return
	if state.has_flag("cc_joined") and state.pet_id.is_empty():
		state.pet_id = CC_PET_ID
	if state.pet_id.is_empty():
		if party.has_pet():
			party.set_pet(null)
		return
	var npc_position := world.remove_npc(CC_NPC_ID) if state.pet_id == CC_PET_ID else Vector2.INF
	if not party.has_pet():
		var pet: PetFollower = PET_SCENE.instantiate()
		pet.data = load(PET_DATA_DIR + state.pet_id + ".tres")
		party.set_pet(pet, npc_position)


func _set_input_locked(locked: bool) -> void:
	var busy := locked or dialogue.is_active or router.is_transitioning or _resting
	party.set_input_locked(busy)
	quest_hud.set_input_blocked(busy)


func _on_daytime_changed(_state_name: StringName, index: int) -> void:
	if world != null:
		world.apply_daytime(index)
	ambient.set_daytime(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("debug_save"):
		save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_load"):
		load_game()
		get_viewport().set_input_as_handled()


## 把隊伍與時段寫回狀態後存檔；失敗只提示，不影響遊戲。
func save_game() -> String:
	if dialogue.is_active or router.is_transitioning or _resting:
		quest_hud.show_toast("對話或轉場中無法存檔")
		return "busy"
	capture_runtime_state()
	var error := SaveManager.save_state(state)
	quest_hud.show_toast("已存檔" if error.is_empty() else "存檔失敗：" + error)
	return error


## 讀檔失敗時保留目前狀態並提示；成功則還原場景、隊伍、日夜、旗標、任務、物品與寵物。
func load_game() -> String:
	if dialogue.is_active or router.is_transitioning or _resting:
		quest_hud.show_toast("對話或轉場中無法讀檔")
		return "busy"
	var result := SaveManager.load_state()
	if result["state"] == null:
		quest_hud.show_toast("讀檔失敗：%s（保留目前進度）" % result["error"])
		return String(result["error"])
	apply_state(result["state"])
	quest_hud.show_toast("已讀檔")
	return ""


func capture_runtime_state() -> void:
	state.party_order = party.order_ids()
	state.party_positions = {}
	for member: PlayableCharacter in party.members:
		state.party_positions[String(member.data.id)] = member.global_position
	state.time_of_day = day_night.index
	state.pet_id = String(party.pet.data.id) if party.has_pet() else ""
	if world != null:
		state.current_scene_id = world.scene_id


func apply_state(loaded: GameState) -> void:
	state = loaded
	quests.bind(state)
	day_hud.bind(state, day_night)
	quest_hud.refresh()
	day_night.set_state(state.time_of_day, true)
	party.set_order_by_ids(state.party_order)
	carry.clear_all()
	if state.pet_id.is_empty() and party.has_pet():
		party.set_pet(null)
	router.restore(state)
