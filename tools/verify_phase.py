#!/usr/bin/env python3
"""單一驗證入口（Phase 8.5-F）。

    python3 tools/verify_phase.py --fast   # 平常修改後跑：素材 preflight、地圖硬檢查、驗證器夾具、Godot 單元測試（約 1～2 分鐘）
    python3 tools/verify_phase.py --full   # 合併前跑：--fast 全部 ＋ import ＋ route test ＋ 指定截圖（約 8 分鐘，會開視窗）
    python3 tools/verify_phase.py --fast --no-godot   # 只跑 Python 部分（幾秒）

每一步都印出命令、耗時與結果；任何一步失敗就以非 0 結束並印 FAIL，全部通過印 PASS。
route test 截圖放到 --shots（預設 build/route_shots/，不進 git）；golden 截圖在 docs/screenshots/golden/。
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = shutil.which("godot") or "/opt/homebrew/bin/godot"
SNAPSHOTS = [
    ("tide_root_town", "14,6", "phase_town_upper.png"),
    ("tide_root_town", "14,17", "phase_town_middle.png"),
    ("tide_root_town", "4,21", "phase_treehouse_door.png"),
    ("tide_root_town", "14,23", "phase_archway.png"),
    ("family_home", "5,6", "phase_family_home.png"),
    ("captain_room", "9,7", "phase_captain_room.png"),
]


def run_step(name: str, command: list[str], cwd: Path = ROOT, env: dict | None = None) -> tuple[bool, float]:
    print(f"\n=== {name}\n$ {' '.join(command)}")
    started = time.time()
    result = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
    elapsed = time.time() - started
    output = (result.stdout + result.stderr).strip().splitlines()
    tail = output[-12:] if len(output) > 12 else output
    for line in tail:
        print("  " + line)
    ok = result.returncode == 0
    print(f"--- {name}：{'OK' if ok else 'FAIL'}（{elapsed:.1f}s，exit {result.returncode}）")
    return ok, elapsed


def godot_unit_tests() -> list[str]:
    return [GODOT, "--headless", "--path", ".", "-s", "res://tests/run_tests.gd"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="單一驗證入口")
    parser.add_argument("--fast", action="store_true")
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--no-godot", action="store_true", help="--fast 時略過 Godot 單元測試")
    parser.add_argument("--shots", default=str(ROOT / "build" / "route_shots"), help="route test 與截圖輸出目錄（不進 git）")
    args = parser.parse_args(argv)
    if not (args.fast or args.full):
        parser.error("請指定 --fast 或 --full")
    steps: list[tuple[str, list[str]]] = [
        ("素材 preflight", [sys.executable, "tools/verify_assets.py"]),
        ("地圖與擺放硬檢查", [sys.executable, "tools/validate_map.py", "--quiet"]),
        ("驗證器夾具（Python unittest）", [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests"]),
    ]
    if args.full:
        steps.append(("Godot import", [GODOT, "--headless", "--path", ".", "--import"]))
    if not args.no_godot or args.full:
        steps.append(("Godot 單元測試", godot_unit_tests()))
    if args.full:
        shots = Path(args.shots)
        shots.mkdir(parents=True, exist_ok=True)
        snapshot_arg = ";".join(f"{scene}:{tile}:{shots / name}" for scene, tile, name in SNAPSHOTS)
        steps.append(("route test", ["caffeinate", "-dis", GODOT, "--path", ".", "--always-on-top", "--", "--route-test", f"--shots={shots}"]))
        steps.append(("版面截圖", ["caffeinate", "-dis", GODOT, "--path", ".", "--always-on-top", "--", f"--snapshot={snapshot_arg}"]))
    results = []
    for name, command in steps:
        ok, elapsed = run_step(name, command)
        results.append((name, ok, elapsed))
        if not ok and name != "版面截圖":
            break
    print("\n==== 結果")
    for name, ok, elapsed in results:
        print(f"  {'OK  ' if ok else 'FAIL'} {name}（{elapsed:.1f}s）")
    subprocess.run(["git", "checkout", "--", "tools/__pycache__"], cwd=ROOT, capture_output=True)
    for cache in (ROOT / "tools" / "validators" / "__pycache__", ROOT / "tools" / "tests" / "__pycache__"):
        shutil.rmtree(cache, ignore_errors=True)
    passed = all(ok for _name, ok, _elapsed in results) and len(results) == len(steps)
    print("PASS" if passed else "FAIL")
    return 0 if passed else 1


if __name__ == "__main__":
    os.chdir(ROOT)
    sys.exit(main())
