extends Node
## 版面截圖工具：把隊伍放到指定場景的指定格，等畫面穩定後存 PNG，全部拍完就離開。
##
## 執行：caffeinate -dis godot --path . --always-on-top -- --snapshot=<scene_id>:<格x>,<格y>:<絕對路徑.png>[;<下一組>...]
## 例：--snapshot="tide_root_town:14,29:/tmp/plaza.png;family_home:3,6:/tmp/rest.png"
## 只用於美術版面檢查（Phase 5 大型 props 的接地、Y-sort 與碰撞），不做任何斷言。

const SETTLE_SECONDS := 0.8

var specs: Array[Dictionary] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--snapshot="):
			continue
		for group: String in arg.trim_prefix("--snapshot=").split(";", false):
			var parts := group.split(":")
			if parts.size() != 3:
				push_error("snapshot 參數格式錯誤：%s" % group)
				continue
			var tile := parts[1].split(",")
			specs.append({
				"scene": parts[0],
				"tile": Vector2i(int(tile[0]), int(tile[1])),
				"path": parts[2],
			})
	_run.call_deferred()


func _run() -> void:
	var main: Node = get_parent()
	var router: SceneRouter = main.get("router")
	for spec: Dictionary in specs:
		var world: TownWorld = main.get("world")
		var scene_id := String(spec["scene"])
		var center: Vector2 = Vector2(spec["tile"]) * TileLibrary.TILE_SIZE + Vector2(16.0, 16.0)
		if world == null or world.scene_id != scene_id:
			router.load_scene(scene_id, "default", [], center)
			await get_tree().physics_frame
			world = main.get("world")
		var party: PartyController = main.get("party")
		party.place(world.arrival_positions(center))
		var camera: CameraRig = main.get("camera")
		camera.follow(party.get_leader(), true)
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png(String(spec["path"]))
		print("snapshot %s %s → %s (%s)" % [scene_id, spec["tile"], spec["path"], error_string(error)])
	get_tree().quit(0)
