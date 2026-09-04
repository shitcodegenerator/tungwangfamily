extends Node2D
## 主場景：組合世界（由 SceneRouter 依 scene_id 建立）、隊伍、鏡頭、互動、對話、任務、存檔、日夜與 HUD。
## 這裡只做接線：可互動物件 → 對話（依狀態挑版本）→ 任務動作；傳送門 → 路由；對話與轉場 → 輸入鎖；
## F6／F7 → SaveManager。帶 `-- --route-test` 參數啟動時執行自動化驗證。

const ROUTE_TEST_SCRIPT := preload("res://scripts/debug/route_test.gd")
const PORTRAIT_DIR := "res://assets/portraits/"

@onready var world_parent: Node2D = $World
@onready var day_night: DayNightController = $World/DayNight
@onready var ambient: AmbientEffects = $World/AmbientEffects
@onready var party: PartyController = $PartyController
@onready var camera: CameraRig = $CameraRig
@onready var interaction: InteractionController = $InteractionController
@onready var dialogue: DialogueManager = $DialogueManager
@onready var quests: QuestManager = $QuestManager
@onready var router: SceneRouter = $SceneRouter
@onready var quest_hud: QuestHud = $QuestHud
@onready var hud: DebugHUD = $DebugHUD

var state: GameState = GameState.new()
var world: TownWorld

var _pending_actions: Array = []
var _pending_interactable_id: String = ""
var _ambient_ready: bool = false


func _ready() -> void:
	party.leader_changed.connect(_on_leader_changed)
	quests.bind(state)
	quest_hud.bind(quests)
	interaction.bind(party, dialogue)
	dialogue.dialogue_started.connect(_on_dialogue_started)
	dialogue.dialogue_finished.connect(_on_dialogue_finished)
	day_night.state_changed.connect(_on_daytime_changed)

	router.bind(state, party, camera, world_parent)
	router.scene_changed.connect(_on_scene_changed)
	router.transition_started.connect(func(_id: String) -> void: _set_input_locked(true))
	router.transition_finished.connect(func(_id: String) -> void: _set_input_locked(false))
	router.load_scene(state.current_scene_id)
	_on_daytime_changed(day_night.state_name(), day_night.index)

	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--route-test"):
		var test: Node = ROUTE_TEST_SCRIPT.new()
		test.name = "RouteTest"
		add_child(test)


func _on_scene_changed(scene_id: String, new_world: TownWorld) -> void:
	world = new_world
	for interactable: Interactable in world.get_interactables():
		interactable.interacted.connect(_on_interacted)
	world.portal_entered.connect(router.enter_portal)
	world.apply_daytime(day_night.index)
	if router.is_outdoor(scene_id):
		if not _ambient_ready:
			ambient.setup(world.get_zone_rect("中層樹洞街"), world.get_zone_rect("下層樹根廣場"))
			_ambient_ready = true
		ambient.visible = true
	else:
		ambient.visible = false
	hud.bind(party, world, day_night)
	quests.notify_scene_entered(scene_id)


func _on_leader_changed(leader: PlayableCharacter, _roster_index: int) -> void:
	camera.follow(leader)


func _on_interacted(interactable: Interactable) -> void:
	if dialogue.is_active or router.is_transitioning:
		return
	var resolved: Dictionary = DialogueResolver.resolve(interactable.dialogue_entry, state, quests)
	if interactable.owner_node is NpcCharacter:
		(interactable.owner_node as NpcCharacter).face_toward(party.get_leader().global_position)
	_pending_actions = resolved["on_complete"]
	_pending_interactable_id = String(interactable.interactable_id)
	var portrait_id: String = resolved["portrait"] if not String(resolved["portrait"]).is_empty() else interactable.portrait_id
	dialogue.start(resolved["speaker"], resolved["lines"], load_portrait(portrait_id))


static func load_portrait(portrait_id: String) -> Texture2D:
	if portrait_id.is_empty():
		return null
	var path := PORTRAIT_DIR + portrait_id + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path)


func _on_dialogue_started(_speaker: String) -> void:
	_set_input_locked(true)
	hud.set_status_visible(false)


func _on_dialogue_finished() -> void:
	_set_input_locked(false)
	hud.set_status_visible(true)
	var actions := _pending_actions
	var target := _pending_interactable_id
	_pending_actions = []
	_pending_interactable_id = ""
	quests.apply_actions(actions)
	if not target.is_empty():
		quests.notify_interact(target)


func _set_input_locked(locked: bool) -> void:
	var busy := locked or dialogue.is_active or router.is_transitioning
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
	if dialogue.is_active or router.is_transitioning:
		quest_hud.show_toast("對話或轉場中無法存檔")
		return "busy"
	capture_runtime_state()
	var error := SaveManager.save_state(state)
	quest_hud.show_toast("已存檔" if error.is_empty() else "存檔失敗：" + error)
	return error


## 讀檔失敗時保留目前狀態並提示；成功則還原場景、隊伍、日夜、旗標與任務。
func load_game() -> String:
	if dialogue.is_active or router.is_transitioning:
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
	if world != null:
		state.current_scene_id = world.scene_id


func apply_state(loaded: GameState) -> void:
	state = loaded
	quests.bind(state)
	quest_hud.refresh()
	day_night.set_state(state.time_of_day, true)
	party.set_order_by_ids(state.party_order)
	router.restore(state)
