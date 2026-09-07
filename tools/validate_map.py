#!/usr/bin/env python3
"""地圖與擺放硬檢查（唯一入口；規則在 tools/validators/）。

    python3 tools/validate_map.py            # 快速驗證：任何違規（未列在 allowlist）就非 0 結束
    python3 tools/validate_map.py --audit    # 列出所有違規（含 allowlist 蓋掉的）、每個 props 封了哪些格、建議的 allowlist 條目；一律 0 結束

規則代碼（docs/RENDERING_AND_PLACEMENT_SPEC.md 第 4 節）：
  MAP-P001 大型碰撞頂端必須在 32 格線     MAP-P002 碰撞不得覆蓋 NPC 站位／出生點／返回點／保留格
  MAP-P003 互動物件要有可站且可達的站位   MAP-P004 出生點、入口、出口、傳送門、返回點都在可站格；邊界封鎖
  MAP-P005 出生點到必要節點連通           MAP-P006 地圖字元都在 tile_legend.json 且該 tile_style 有 mapping
  MAP-P007 每個 props 宣告 render_mode 且與碰撞／z_bias 一致
  MAP-S00x 尺寸與檔案   MAP-C00x 內容（Boss 邊界、對話、任務目標、傳送門目標、世界事件）   MAP-A00x allowlist 本身
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from validators.allowlist import ALLOWLIST_PATH, Allowlist, suggest_entry  # noqa: E402
from validators.common import ROOT, Finding, Scene, load_json, load_scene  # noqa: E402
from validators.content import (  # noqa: E402
    check_boss,
    check_dialogue,
    check_events,
    check_portal_targets,
    check_quest_targets,
    check_scene_files,
    interact_ids,
    load_quest_targets,
)
from validators.legend import LEGEND_PATH, Legend, check_dimensions, check_legend  # noqa: E402
from validators.placement import (  # noqa: E402
    blocking_report,
    check_boundary,
    check_collision_grid,
    check_connectivity,
    check_exits_and_returns,
    check_interact_standing,
    check_reserved,
)
from validators.render import check_render_modes  # noqa: E402

SCENES_PATH = ROOT / "assets" / "maps" / "scenes.json"


def validate_scene(scene: Scene, legend: Legend, ok_lines: list[str] | None = None) -> list[Finding]:
    """單一場景的全部規則（純函式，測試可直接餵組裝好的 Scene）。"""
    findings = check_dimensions(scene)
    if findings:
        return findings
    findings += check_legend(scene, legend)
    if any(f.code == "MAP-P006" and "未知圖例" in f.message for f in findings):
        return findings
    walkable = legend.walkable
    findings += check_collision_grid(scene)
    findings += check_reserved(scene)
    findings += check_exits_and_returns(scene, walkable)
    findings += check_boundary(scene, walkable)
    findings += check_interact_standing(scene, walkable)
    findings += check_connectivity(scene, walkable, ok_lines)
    findings += check_render_modes(scene)
    findings += check_boss(scene, walkable)
    findings += check_dialogue(scene)
    if ok_lines is not None:
        ok_lines.append(f"OK  [{scene.scene_id}] 互動物件 {len(interact_ids(scene))} 個，對話內容齊全")
    return findings


def run(root: Path = ROOT, audit: bool = False, scenes_path: Path | None = None, allowlist_path: Path | None = None, legend_path: Path | None = None) -> tuple[list[Finding], list[Finding], list[str]]:
    """回傳 (錯誤, 被 allowlist 蓋掉的, 輸出行)。"""
    legend = Legend.load(legend_path or LEGEND_PATH)
    allowlist = Allowlist.load(allowlist_path or ALLOWLIST_PATH)
    registry = load_json(scenes_path or SCENES_PATH)
    lines: list[str] = []
    findings: list[Finding] = []
    scenes: dict[str, Scene] = {}
    for scene_id, info in registry.items():
        missing = check_scene_files(scene_id, info, root)
        if missing:
            findings += missing
            continue
        scene = load_scene(scene_id, info, root)
        scenes[scene_id] = scene
        findings += validate_scene(scene, legend, lines)
        findings += check_portal_targets(scene, set(registry))
        if audit:
            lines.append(f"    [{scene_id}] props 封鎖格：")
            lines.extend(blocking_report(scene))
    quest_targets = load_quest_targets(root / "assets" / "quests")
    all_interacts = set().union(*(interact_ids(s) for s in scenes.values())) if scenes else set()
    findings += check_quest_targets(quest_targets, all_interacts)
    lines.append(f"OK  任務目標 {len(quest_targets)} 個皆對應互動物件")
    findings += check_events(scenes, root / "assets" / "events", lines)

    errors: list[Finding] = list(allowlist.problems)
    allowed: list[Finding] = []
    for finding in findings:
        if allowlist.covers(finding):
            allowed.append(finding)
        else:
            errors.append(finding)
    errors += allowlist.unused()
    return errors, allowed, lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="地圖與擺放硬檢查")
    parser.add_argument("--audit", action="store_true", help="列出所有違規與封鎖格，並建議 allowlist 條目；不以非 0 結束")
    parser.add_argument("--quiet", action="store_true", help="只印錯誤與結論")
    args = parser.parse_args(argv)
    errors, allowed, lines = run(audit=args.audit)
    if not args.quiet:
        print("\n".join(lines))
    for finding in allowed:
        print("ALLOW " + finding.render())
    if args.audit:
        by_code: dict[str, list[Finding]] = {}
        for finding in errors:
            by_code.setdefault(finding.code, []).append(finding)
        for code in sorted(by_code):
            print(f"\n== {code}（{len(by_code[code])}）==")
            for finding in by_code[code]:
                print("  " + finding.render())
        suggestions = [suggest_entry(f) for f in errors if f.code.startswith("MAP-P")]
        if suggestions:
            print("\n建議的 allowlist 條目（每筆都要改 reason，並確認真的不能修資料）：")
            print(json.dumps(suggestions, ensure_ascii=False, indent=2))
        print(f"\n審計：{len(errors)} 項違規、{len(allowed)} 項在 allowlist 內")
        return 0
    if errors:
        print("\n".join(f.render() for f in errors))
        print(f"地圖驗證失敗：{len(errors)} 項（--audit 可看完整清單與封鎖格）")
        return 1
    print("地圖驗證通過" + (f"（allowlist 例外 {len(allowed)} 項）" if allowed else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
