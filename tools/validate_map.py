#!/usr/bin/env python3
"""驗證主城 ASCII 地圖：尺寸、圖例、道具落點，以及主要路線是否可走通（BFS）。

執行：python3 tools/validate_map.py
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAP_PATH = ROOT / "assets" / "maps" / "tide_root_town.txt"
PROPS_PATH = ROOT / "assets" / "maps" / "tide_root_town_props.json"
DIALOGUE_PATH = ROOT / "assets" / "dialogue" / "tide_root_town.json"
TILE = 32

WALKABLE = set("gdrpbsm=|w")
SOLID = set("#.c~,T")


def load_map() -> list[str]:
    rows = [line.rstrip("\n") for line in MAP_PATH.read_text(encoding="utf-8").splitlines() if line.strip()]
    return rows


def blocked_by_props(props: list[dict], width: int, height: int) -> set[tuple[int, int]]:
    blocked: set[tuple[int, int]] = set()
    for prop in props:
        col = prop.get("collision")
        if not col:
            continue
        w, h = col
        # 與 town_world.gd 相同規則：碰撞盒內縮 1px 後，任何相交的格子都視為不可規劃
        x0, x1 = prop["x"] - w / 2 + 1, prop["x"] + w / 2 - 1
        y0, y1 = prop["y"] - h + 1, prop["y"] - 1
        for ty in range(height):
            for tx in range(width):
                tx0, ty0 = tx * TILE, ty * TILE
                if x0 < tx0 + TILE and x1 > tx0 and y0 < ty0 + TILE and y1 > ty0:
                    blocked.add((tx, ty))
    return blocked


def bfs(rows: list[str], blocked: set[tuple[int, int]], start: tuple[int, int], goal: tuple[int, int]) -> list[tuple[int, int]] | None:
    width, height = len(rows[0]), len(rows)

    def ok(p: tuple[int, int]) -> bool:
        x, y = p
        return 0 <= x < width and 0 <= y < height and rows[y][x] in WALKABLE and p not in blocked

    if not ok(start) or not ok(goal):
        return None
    prev: dict[tuple[int, int], tuple[int, int] | None] = {start: None}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        if cur == goal:
            path = []
            node: tuple[int, int] | None = cur
            while node is not None:
                path.append(node)
                node = prev[node]
            return path[::-1]
        x, y = cur
        for nxt in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if ok(nxt) and nxt not in prev:
                prev[nxt] = cur
                queue.append(nxt)
    return None


def main() -> int:
    rows = load_map()
    data = json.loads(PROPS_PATH.read_text(encoding="utf-8"))
    width, height = data["world_size"]
    errors: list[str] = []
    if len(rows) != height:
        errors.append(f"地圖列數 {len(rows)} ≠ {height}")
    for i, row in enumerate(rows):
        if len(row) != width:
            errors.append(f"第 {i} 列寬度 {len(row)} ≠ {width}")
        for ch in row:
            if ch not in WALKABLE | SOLID:
                errors.append(f"第 {i} 列有未知圖例 '{ch}'")
    if errors:
        print("\n".join(errors))
        return 1

    blocked = blocked_by_props(data["props"], width, height)
    for prop in data["props"]:
        tx, ty = int(prop["x"] // TILE), int((prop["y"] - 1) // TILE)
        if prop.get("collision") and rows[ty][tx] not in WALKABLE:
            print(f"注意：{prop['texture']} 的底部落在非行走格 ({tx},{ty}) '{rows[ty][tx]}'")

    spawn = tuple(data["spawn_points"][0])
    for sp in data["spawn_points"]:
        p = tuple(sp)
        if rows[p[1]][p[0]] not in WALKABLE or p in blocked:
            errors.append(f"出生點 {p} 不可站立")

    checkpoints = {c["name"]: tuple(c["tile"]) for c in data["connectors"]}
    checkpoints.update({e["name"]: tuple(e["tile"]) for e in data["exits"]})
    checkpoints["top_center"] = (14, 2)
    for name, goal in checkpoints.items():
        path = bfs(rows, blocked, spawn, goal)
        if path is None:
            errors.append(f"從出生點無法走到 {name} {goal}")
        else:
            print(f"OK  {name:16s} {goal}  路徑長度 {len(path) - 1}")

    # 出口外側必須被封鎖：地圖最外圈的可走格都要被道具擋住
    for ty in range(height):
        for tx in (0, width - 1):
            if rows[ty][tx] in WALKABLE and (tx, ty) not in blocked:
                errors.append(f"邊界格 ({tx},{ty}) 可走且未封鎖")
    for tx in range(width):
        for ty in (0, height - 1):
            if rows[ty][tx] in WALKABLE and (tx, ty) not in blocked:
                errors.append(f"邊界格 ({tx},{ty}) 可走且未封鎖")

    # 互動物件：每個 interact id 都要有對話內容
    dialogue = json.loads(DIALOGUE_PATH.read_text(encoding="utf-8"))
    interact_ids = [e["interact"] for e in data["props"] + data["exits"] if e.get("interact")]
    for interact_id in interact_ids:
        entry = dialogue.get(interact_id)
        if not entry or not entry.get("lines"):
            errors.append(f"對話 JSON 缺少 {interact_id} 或沒有句子")
    print(f"OK  互動物件 {len(interact_ids)} 個，對話內容齊全" if not errors else "")

    if errors:
        print("\n".join(errors))
        return 1
    print("地圖驗證通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
