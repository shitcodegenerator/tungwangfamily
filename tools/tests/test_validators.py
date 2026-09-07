"""validate_map 硬檢查的回歸夾具（Phase 8.5-B）。

    python3 -m unittest discover -s tools/tests -v

每個夾具都拿真實場景資料複製一份、動一個地方，確認驗證器會以正確的規則代碼點名物件。
"""
from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from validate_map import run, validate_scene  # noqa: E402
from validators.allowlist import Allowlist  # noqa: E402
from validators.common import Finding, load_json, load_scene  # noqa: E402
from validators.legend import Legend  # noqa: E402
from validators.placement import aligned_heights  # noqa: E402
from validators.render import suggest_render_mode  # noqa: E402

SCENES = load_json(ROOT / "assets" / "maps" / "scenes.json")
LEGEND = Legend.load()


def scene_copy(scene_id: str):
    scene = load_scene(scene_id, SCENES[scene_id])
    scene.data = copy.deepcopy(scene.data)
    scene.rows = list(scene.rows)
    return scene


def find_prop(scene, needle: str) -> dict:
    for prop in scene.data["props"]:
        if needle in prop["texture"]:
            return prop
    raise AssertionError(f"找不到 {needle}")


def codes(findings: list[Finding]) -> list[str]:
    return [f.code for f in findings]


class RealDataPasses(unittest.TestCase):
    def test_repo_data_has_no_errors(self) -> None:
        errors, allowed, _lines = run()
        self.assertEqual([], [f.render() for f in errors])
        self.assertEqual([], [f.render() for f in allowed], "目前不應有 allowlist 例外")


class PlacementRules(unittest.TestCase):
    def test_dining_table_in_walkway_blocks_path(self) -> None:
        """家庭屋餐桌搬到出口前的走道：MAP-P004／P005 必須點名餐桌。"""
        scene = scene_copy("family_home")
        table = find_prop(scene, "int_dining_table")
        exit_portal = scene.data["portals"][0]
        table["x"], table["y"] = exit_portal["x"], exit_portal["y"] - 8
        findings = validate_scene(scene, LEGEND)
        blocking = [f for f in findings if f.code in ("MAP-P004", "MAP-P005", "MAP-P002") and "int_dining_table" in (f.subject + f.message)]
        self.assertTrue(blocking, [f.render() for f in findings])

    def test_interact_surrounded_reports_p003(self) -> None:
        scene = scene_copy("captain_room")
        desk = find_prop(scene, "cap_chart_desk")
        scene.data["props"].append({"texture": "cap_barrel_v3", "render_mode": "ysort", "x": desk["x"], "y": desk["y"] + 64, "collision": [200, 96]})
        scene.data["props"].append({"texture": "cap_barrel_v3", "render_mode": "ysort", "x": desk["x"] - 100, "y": desk["y"] + 32, "collision": [64, 96]})
        scene.data["props"].append({"texture": "cap_barrel_v3", "render_mode": "ysort", "x": desk["x"] + 100, "y": desk["y"] + 32, "collision": [64, 96]})
        findings = validate_scene(scene, LEGEND)
        p003 = [f for f in findings if f.code == "MAP-P003" and "captain_chart_table" in f.subject]
        self.assertTrue(p003, [f.render() for f in findings])

    def test_unknown_char_reports_p006_not_fallback(self) -> None:
        scene = scene_copy("tide_root_town")
        row = list(scene.rows[5])
        row[3] = "?"
        scene.rows[5] = "".join(row)
        findings = validate_scene(scene, LEGEND)
        self.assertEqual(["MAP-P006"], codes(findings))
        self.assertIn("'?'", findings[0].subject)
        self.assertEqual((3, 5), findings[0].tile)

    def test_char_without_style_mapping_reports_p006(self) -> None:
        scene = scene_copy("fried_food_cave")
        row = list(scene.rows[5])
        row[5] = "~"
        scene.rows[5] = "".join(row)
        findings = validate_scene(scene, LEGEND)
        self.assertTrue(any(f.code == "MAP-P006" and "cave" in f.message for f in findings), [f.render() for f in findings])

    def test_npc_spawn_under_collision_reports_p002(self) -> None:
        scene = scene_copy("tide_root_town")
        turtle = next(n for n in scene.data["npcs"] if n["id"] == "old_turtle")
        fountain = find_prop(scene, "heart_fountain")
        fountain["collision"] = [fountain["collision"][0], 160]
        findings = validate_scene(scene, LEGEND)
        p002 = [f for f in findings if f.code == "MAP-P002" and "old_turtle" in f.message and "heart_fountain" in f.subject]
        self.assertTrue(p002, [f.render() for f in findings])
        self.assertEqual((turtle["x"] // 32, (turtle["y"] - 1) // 32), p002[0].tile)
        fountain["collision"] = [fountain["collision"][0], 128]
        findings = validate_scene(scene, LEGEND)
        self.assertFalse([f for f in findings if f.code == "MAP-P002"], "128 只封到老龜面前那格，側邊仍可站，不算覆蓋站位")

    def test_flower_bed_116_regression_is_caught(self) -> None:
        """Phase 8 第二批抓到的回歸：花圃 116 封掉阿嬤／CC 的對話站位。"""
        scene = scene_copy("tide_root_town")
        bed = find_prop(scene, "flower_herb_bed")
        bed["collision"] = [100, 116]
        findings = validate_scene(scene, LEGEND)
        p001 = [f for f in findings if f.code == "MAP-P001" and "flower_herb_bed" in f.subject]
        self.assertEqual(1, len(p001), [f.render() for f in findings])
        self.assertIn("改 96", p001[0].fix, "伸進第 30 列的那 12px 蓋到阿嬤／CC 的站位，必須建議少封一列")
        self.assertIn("(9, 30)", p001[0].fix)

    def test_collision_top_off_grid_reports_p001_with_fix(self) -> None:
        scene = scene_copy("family_home")
        table = find_prop(scene, "int_dining_table")
        table["collision"] = [table["collision"][0], 76]
        findings = validate_scene(scene, LEGEND)
        p001 = [f for f in findings if f.code == "MAP-P001" and "int_dining_table" in f.subject]
        self.assertEqual(1, len(p001), [f.render() for f in findings])
        self.assertIn("改 ", p001[0].fix)
        self.assertEqual((int(table["y"]) - (int(table["y"]) - 76) // 32 * 32, int(table["y"]) - ((int(table["y"]) - 76) // 32 + 1) * 32), aligned_heights(table["y"], 76))

    def test_return_position_in_collision_reports_p004(self) -> None:
        scene = scene_copy("tide_root_town")
        portal = next(p for p in scene.data["portals"] if p["id"] == "family_home_door")
        treehouse = find_prop(scene, "treehouse")
        portal["return_position"] = [treehouse["x"], treehouse["y"] - 16]
        findings = validate_scene(scene, LEGEND)
        self.assertTrue(any(f.code == "MAP-P004" and "return:family_home_door" in f.subject for f in findings), [f.render() for f in findings])


class RenderModeRules(unittest.TestCase):
    def test_missing_render_mode_reports_p007_with_suggestion(self) -> None:
        scene = scene_copy("captain_room")
        rug = find_prop(scene, "cap_rug")
        del rug["render_mode"]
        findings = validate_scene(scene, LEGEND)
        p007 = [f for f in findings if f.code == "MAP-P007" and "cap_rug" in f.subject]
        self.assertEqual(1, len(p007))
        self.assertIn('"render_mode": "ground"', p007[0].fix)

    def test_ysort_with_z_bias_is_rejected(self) -> None:
        scene = scene_copy("captain_room")
        desk = find_prop(scene, "cap_chart_desk")
        desk["z_bias"] = -1
        findings = validate_scene(scene, LEGEND)
        self.assertTrue(any(f.code == "MAP-P007" and "z_bias" in f.message for f in findings))

    def test_split_needs_pair(self) -> None:
        scene = scene_copy("tide_root_town")
        canopy = find_prop(scene, "root_archway_v3_canopy")
        scene.data["props"].remove(canopy)
        findings = validate_scene(scene, LEGEND)
        self.assertTrue(any(f.code == "MAP-P007" and "成對" in f.message for f in findings))

    def test_suggestions(self) -> None:
        self.assertEqual(("split", "canopy"), suggest_render_mode({"texture": "town_refresh/root_archway_v3_canopy"}))
        self.assertEqual(("ground", None), suggest_render_mode({"texture": "cap_rug_v3"}))
        self.assertEqual(("ysort", None), suggest_render_mode({"texture": "cap_chart_desk_v3", "collision": [1, 1]}))


class AllowlistRules(unittest.TestCase):
    def test_expired_entry_fails_and_active_entry_covers(self) -> None:
        finding = Finding("MAP-P001", "family_home", "int_stove(66,114)", "x")
        active = Allowlist({"current_phase": "8.5", "entries": [{"id": "a", "rule": "MAP-P001", "scene": "family_home", "subject": "int_stove(66,114)", "reason": "r", "owner": "o", "expires_phase": "9"}]})
        self.assertIsNotNone(active.covers(finding))
        self.assertEqual([], active.unused())
        expired = Allowlist({"current_phase": "9", "entries": [{"id": "a", "rule": "MAP-P001", "scene": "family_home", "subject": "int_stove(66,114)", "reason": "r", "owner": "o", "expires_phase": "9"}]})
        self.assertIsNone(expired.covers(finding))
        self.assertEqual(["MAP-A001"], codes(expired.problems))
        incomplete = Allowlist({"current_phase": "8.5", "entries": [{"id": "b", "rule": "MAP-P001"}]})
        self.assertEqual(["MAP-A001"], codes(incomplete.problems))


if __name__ == "__main__":
    unittest.main()
