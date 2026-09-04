class_name SceneRouter
extends Node
## 場景轉換服務：依 assets/maps/scenes.json 的穩定 scene_id 建立世界（同一個 TownWorld 場景、不同資料檔），
## 淡出 → 換世界 → 放置隊伍 → 淡入。轉場期間由 Main 鎖定輸入。隊伍節點不屬於世界，換場景不會遺失。

signal transition_started(scene_id: String)
signal scene_changed(scene_id: String, world: TownWorld)
signal transition_finished(scene_id: String)

const REGISTRY_PATH := "res://assets/maps/scenes.json"
const WORLD_SCENE := preload("res://scenes/world/tide_root_town.tscn")
const FADE_SECONDS := 0.25
const RETURN_TARGET := "return"

var registry: Dictionary = {}
var state: GameState
var party: PartyController
var camera: CameraRig
var world_parent: Node
var current_world: TownWorld
var is_transitioning: bool = false

var _fade: ColorRect


func _ready() -> void:
	registry = parse_registry(FileAccess.get_file_as_string(REGISTRY_PATH))
	if registry.is_empty():
		push_error("場景登錄表為空或無法解析：%s" % REGISTRY_PATH)
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 40
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.02, 0.01, 0.0, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	add_child(layer)


static func parse_registry(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func bind(game_state: GameState, party_controller: PartyController, camera_rig: CameraRig, parent: Node) -> void:
	state = game_state
	party = party_controller
	camera = camera_rig
	world_parent = parent


func set_state(game_state: GameState) -> void:
	state = game_state


func has_scene(scene_id: String) -> bool:
	return registry.has(scene_id)


func scene_info(scene_id: String) -> Dictionary:
	return registry.get(scene_id, {})


func is_outdoor(scene_id: String) -> bool:
	return bool(scene_info(scene_id).get("outdoor", false))


## 戰鬥場景的設定（boss、座標、生命）；非戰鬥場景回傳空字典。
func battle_config(scene_id: String) -> Dictionary:
	var config: Variant = scene_info(scene_id).get("battle", {})
	return config if typeof(config) == TYPE_DICTIONARY else {}


func scene_name(scene_id: String) -> String:
	return String(scene_info(scene_id).get("name", scene_id))


## 同步建立世界並放置隊伍（第一次呼叫會生成隊伍）。
## 落點優先序：positions（讀檔的精確位置）→ arrival_center（返回點周圍可站格）→ 場景的 entry。
func load_scene(scene_id: String, entry_name: String = "default", positions: Array[Vector2] = [], arrival_center: Vector2 = Vector2.INF) -> TownWorld:
	if not has_scene(scene_id):
		push_error("未知場景：%s" % scene_id)
		return current_world
	if current_world != null:
		world_parent.remove_child(current_world)
		current_world.queue_free()
	var world: TownWorld = WORLD_SCENE.instantiate()
	world.configure(scene_id, scene_info(scene_id))
	world.state = state
	world_parent.add_child(world)
	current_world = world
	var spawn := positions
	if spawn.is_empty() and arrival_center != Vector2.INF:
		spawn = world.arrival_positions(arrival_center)
	if spawn.is_empty():
		spawn = world.get_entry_positions(entry_name)
	party.place(spawn)
	camera.set_world_bounds(world.world_rect)
	camera.follow(party.get_leader(), true)
	state.current_scene_id = scene_id
	state.unlock_scene(scene_id)
	scene_changed.emit(scene_id, world)
	return world


## 淡出、換場景、淡入。轉場中重複呼叫會被忽略。
func travel(scene_id: String, entry_name: String = "default", positions: Array[Vector2] = [], arrival_center: Vector2 = Vector2.INF) -> void:
	if is_transitioning or not has_scene(scene_id):
		return
	is_transitioning = true
	transition_started.emit(scene_id)
	await _fade_to(1.0)
	load_scene(scene_id, entry_name, positions, arrival_center)
	await get_tree().physics_frame
	await _fade_to(0.0)
	is_transitioning = false
	transition_finished.emit(scene_id)


## 傳送門進入：一般目標記住返回點後前往；"return" 回到記住的場景與位置。
func enter_portal(portal: ScenePortal) -> void:
	if is_transitioning:
		return
	if portal.is_return():
		if state.return_scene_id.is_empty() or not has_scene(state.return_scene_id):
			push_warning("沒有可返回的場景，改回主城")
			travel(GameState.DEFAULT_SCENE)
			return
		travel(state.return_scene_id, "default", [], state.return_position)
		return
	state.return_scene_id = state.current_scene_id
	state.return_position = portal.return_position
	travel(portal.target_scene, portal.entry_name)


## 讀檔後還原：依存檔中的場景與各角色位置放置隊伍。
func restore(loaded: GameState) -> void:
	state = loaded
	var positions: Array[Vector2] = []
	for id: String in loaded.party_order:
		if loaded.party_positions.has(id):
			positions.append(loaded.party_positions[id])
	var scene_id := loaded.current_scene_id if has_scene(loaded.current_scene_id) else GameState.DEFAULT_SCENE
	await travel(scene_id, "default", positions)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
