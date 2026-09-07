#!/usr/bin/env python3
"""試驗主城 props 的視覺欄位（foot_x／foot_inset／z_bias）：套用 patch → --snapshot 截圖 → 還原 JSON。

用法（專案根目錄）：
  python3 tools/snapshot_props_trial.py <tag> '<patch json>' '<specs>' [輸出目錄]

  patch json：{"town_refresh/shared_family_treehouse_v2": {"foot_inset": 64}, "town_refresh/root_archway_v2": {"z_bias": -1}}
              值為 null 代表移除該欄位。
  specs：     "tide_root_town:4,17:bridge;tide_root_town:15,22:inside"（scene:格x,格y:名稱），輸出 <目錄>/<tag>_<名稱>.png

只用於美術版面比較，不做斷言；JSON 一定會還原（例外時也還原）。需要視窗，macOS 請用 caffeinate。
"""
import json
import os
import shutil
import subprocess
import sys

PROPS_PATH = "assets/maps/tide_root_town_props.json"


def apply_patch(data: dict, patch: dict) -> dict:
    props = []
    for prop in data["props"]:
        if prop.get("texture") in patch:
            updated = dict(prop)
            for key, value in patch[prop["texture"]].items():
                if value is None:
                    updated.pop(key, None)
                else:
                    updated[key] = value
            props.append(updated)
        else:
            props.append(prop)
    return {**data, "props": props}


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    tag, patch, specs = sys.argv[1], json.loads(sys.argv[2]), sys.argv[3]
    out_dir = os.path.abspath(sys.argv[4] if len(sys.argv) > 4 else "docs/screenshots/trials")
    os.makedirs(out_dir, exist_ok=True)
    backup = PROPS_PATH + ".trial_backup"
    shutil.copy(PROPS_PATH, backup)
    with open(PROPS_PATH, encoding="utf-8") as handle:
        original = json.load(handle)
    with open(PROPS_PATH, "w", encoding="utf-8") as handle:
        json.dump(apply_patch(original, patch), handle, ensure_ascii=False, indent=2)
    groups = []
    for spec in specs.split(";"):
        scene, tile, name = spec.split(":")
        groups.append(f"{scene}:{tile}:{out_dir}/{tag}_{name}.png")
    command = ["godot", "--path", ".", "--always-on-top", "--", "--snapshot=" + ";".join(groups)]
    if shutil.which("caffeinate"):
        command = ["caffeinate", "-dis", *command]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=300, check=False)
        for line in result.stdout.splitlines():
            if line.startswith("snapshot"):
                print(line)
        return result.returncode
    finally:
        shutil.move(backup, PROPS_PATH)


if __name__ == "__main__":
    sys.exit(main())
