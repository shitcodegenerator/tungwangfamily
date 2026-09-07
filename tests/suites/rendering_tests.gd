extends RefCounted
## 顯示層級：render_mode 四模式、z_index 只由 render_mode 決定、碰撞頂端對齊格線（Phase 8.5 起新測試分檔；由 tests/run_tests.gd 的 SUITES 載入，t 是 runner，用 t._assert）。

const TownWorldScript := preload("res://scripts/world/town_world.gd")

## Phase 8.5-C：顯示層級只由 render_mode 決定；資料檔裡不得再有 z_bias。
func run(t: SceneTree) -> void:
	t._assert(TownWorldScript.z_index_for({"render_mode": "ground"}) == -1 and TownWorldScript.z_index_for({"render_mode": "back"}) == -1, "ground／back → z_index -1")
	t._assert(TownWorldScript.z_index_for({"render_mode": "ysort"}) == 0 and TownWorldScript.z_index_for({"render_mode": "ysort", "z_bias": -1}) == 0, "ysort → 0，且忽略殘留的 z_bias")
	t._assert(TownWorldScript.z_index_for({"render_mode": "split", "split_role": "base"}) == 0 and TownWorldScript.z_index_for({"render_mode": "split", "split_role": "canopy"}) == 1, "split base 0、canopy 1")
	var modes := {"ground": 0, "back": 0, "ysort": 0, "split": 0}
	var missing := 0
	var stray_z := 0
	for path: String in ["res://assets/maps/tide_root_town_props.json", "res://assets/maps/family_home_props.json", "res://assets/maps/captain_room_props.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for entry: Dictionary in data["props"]:
			var mode := String(entry.get("render_mode", ""))
			if modes.has(mode):
				modes[mode] += 1
			else:
				missing += 1
			if entry.has("z_bias"):
				stray_z += 1
			var raw: Variant = entry.get("collision")
			if typeof(raw) == TYPE_ARRAY and float(raw[1]) >= 32.0:
				t._assert(fmod(float(entry["y"]) - float(raw[1]), 32.0) == 0.0, "%s 碰撞頂端對齊 32 格線（MAP-P001）" % entry["texture"])
	t._assert(missing == 0 and stray_z == 0, "所有現役 props 都宣告四種 render_mode 之一且沒有 z_bias（缺 %d、殘留 %d）" % [missing, stray_z])
	t._assert(modes["ground"] >= 3 and modes["back"] >= 15 and modes["ysort"] >= 30 and modes["split"] == 2, "四種模式都有實例：ground %d、back %d、ysort %d、split %d" % [modes["ground"], modes["back"], modes["ysort"], modes["split"]])
	var captain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/captain_room_props.json"))
	var wall_back := 0
	for entry: Dictionary in captain["props"]:
		var name := String(entry["texture"])
		if name.begins_with("cap_wall_map") or name.begins_with("cap_painting") or name.begins_with("cap_porthole") or name.begins_with("cap_hanging_lantern"):
			if String(entry.get("render_mode", "")) == "back":
				wall_back += 1
		if name.begins_with("cap_rug"):
			t._assert(String(entry.get("render_mode", "")) == "ground", "地毯是 ground")
	t._assert(wall_back == 4, "船長房四件牆掛物都是 back（%d）" % wall_back)
