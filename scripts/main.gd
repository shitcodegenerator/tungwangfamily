extends Node2D
## 主場景：組合主城、隊伍、鏡頭、互動、對話、日夜與 HUD。帶 `-- --route-test` 參數啟動時執行自動化驗證。
## 這裡只做接線：可互動物件 → 對話管理；對話開關 → 隊伍輸入鎖；日夜狀態 → 燈籠與粒子。

const ROUTE_TEST_SCRIPT := preload("res://scripts/debug/route_test.gd")

@onready var world: TownWorld = $World/TideRootTown
@onready var day_night: DayNightController = $World/DayNight
@onready var ambient: AmbientEffects = $World/AmbientEffects
@onready var party: PartyController = $PartyController
@onready var camera: CameraRig = $CameraRig
@onready var interaction: InteractionController = $InteractionController
@onready var dialogue: DialogueManager = $DialogueManager
@onready var hud: DebugHUD = $DebugHUD


func _ready() -> void:
	party.leader_changed.connect(_on_leader_changed)
	party.spawn_party(world.get_spawn_positions())
	camera.set_world_bounds(world.world_rect)
	camera.follow(party.get_leader(), true)

	interaction.bind(party, dialogue)
	for interactable: Interactable in world.get_interactables():
		interactable.interacted.connect(dialogue.start_from)
	dialogue.dialogue_started.connect(_on_dialogue_started)
	dialogue.dialogue_finished.connect(_on_dialogue_finished)

	ambient.setup(world.get_zone_rect("中層樹洞街"), world.get_zone_rect("下層樹根廣場"))
	day_night.state_changed.connect(_on_daytime_changed)
	_on_daytime_changed(day_night.state_name(), day_night.index)

	hud.bind(party, world, day_night)
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--route-test"):
		var test: Node = ROUTE_TEST_SCRIPT.new()
		test.name = "RouteTest"
		add_child(test)


func _on_leader_changed(leader: PlayableCharacter, _roster_index: int) -> void:
	camera.follow(leader)


func _on_dialogue_started(_speaker: String) -> void:
	party.set_input_locked(true)
	hud.set_status_visible(false)


func _on_dialogue_finished() -> void:
	party.set_input_locked(false)
	hud.set_status_visible(true)


func _on_daytime_changed(_state_name: StringName, index: int) -> void:
	world.apply_daytime(index)
	ambient.set_daytime(index)
