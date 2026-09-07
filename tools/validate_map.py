#!/usr/bin/env python3
"""驗證所有場景（assets/maps/scenes.json）的 ASCII 地圖：尺寸、圖例、道具落點、入口可站、
主要路線可走通（BFS）、傳送門與互動點可達、互動 id 都有對話、任務目標都指向存在的互動 id、
世界事件（assets/events/*.json）的場景、觸發互動點、目標節點、對話 id 與線索 id 都存在（Phase 6）。

執行：python3 tools/validate_map.py
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENES_PATH = ROOT / "assets" / "maps" / "scenes.json"
QUEST_DIR = ROOT / "assets" / "quests"
EVENT_DIR = ROOT / "assets" / "events"
CLUES_PATH = EVENT_DIR / "clues.json"
EVENT_REQUIRED_KEYS = ("event_id", "scene_id", "trigger", "actions")
TARGET_ACTIONS = ("tween_node", "shader_param")
TILE = 32

WALKABLE = set("gdrpbsm=|w")
SOLID = set("#.c~,T")


def res_path(path: str) -> Path:
    return ROOT / path.replace("res://", "")


def load_rows(path: Path) -> list[str]:
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def blocked_rect(x: float, y: float, w: float, h: float, width: int, height: int) -> set[tuple[int, int]]:
    """與 town_world.gd 相同規則：碰撞盒（底部中央原點）內縮 1px 後，任何相交的格子都視為不可規劃。"""
    blocked: set[tuple[int, int]] = set()
    x0, x1 = x - w / 2 + 1, x + w / 2 - 1
    y0, y1 = y - h + 1, y - 1
    for ty in range(height):
        for tx in range(width):
            tx0, ty0 = tx * TILE, ty * TILE
            if x0 < tx0 + TILE and x1 > tx0 and y0 < ty0 + TILE and y1 > ty0:
                blocked.add((tx, ty))
    return blocked


def blocked_by_props(data: dict, width: int, height: int) -> set[tuple[int, int]]:
    blocked: set[tuple[int, int]] = set()
    for prop in data.get("props", []):
        col = prop.get("collision")
        if col:
            blocked |= blocked_rect(prop["x"], prop["y"], col[0], col[1], width, height)
    for npc in data.get("npcs", []):
        blocked |= blocked_rect(npc["x"], npc["y"], 20, 10, width, height)
    battle = info_battle(data)
    if battle:
        blocked |= blocked_rect(battle["x"], battle["y"], 40, 16, width, height)
    return blocked


def info_battle(data: dict) -> dict:
    return data.get("_battle") or {}


BOSS_TOP_MARGIN_TILES = 2
BOSS_HEAD_HEIGHT = 78


def first_walkable_row(rows: list[str]) -> int:
    for y, row in enumerate(rows):
        if any(ch in WALKABLE for ch in row):
            return y
    return -1


def boss_top_margin_errors(scene_id: str, rows: list[str], battle: dict) -> list[str]:
    """Boss 生成點與活動下限（min_y）都必須離最上方的可走列至少 2 格，且頭部不會超出地圖上緣。"""
    errors = []
    top = first_walkable_row(rows)
    min_y = float(battle.get("min_y", battle["y"]))
    limit = (top + BOSS_TOP_MARGIN_TILES) * TILE
    if min_y < limit:
        errors.append(f"[{scene_id}] Boss min_y={min_y:g} 離地圖上緣不足 {BOSS_TOP_MARGIN_TILES} 格（需 ≥ {limit}）")
    if float(battle["y"]) < min_y:
        errors.append(f"[{scene_id}] Boss 生成點 y={battle['y']} 高於 min_y={min_y:g}")
    if min_y - BOSS_HEAD_HEIGHT < 0:
        errors.append(f"[{scene_id}] Boss 頭部會超出地圖上緣（min_y={min_y:g}，頭高 {BOSS_HEAD_HEIGHT}）")
    return errors


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


def world_to_tile(x: float, y: float) -> tuple[int, int]:
    return int(x // TILE), int(y // TILE)


def nearest_walkable(rows: list[str], blocked: set[tuple[int, int]], tile: tuple[int, int]) -> tuple[int, int] | None:
    """互動點與傳送門本身可能落在道具格上；找相鄰（含自身）的可站格。"""
    x, y = tile
    for cand in ((x, y), (x, y + 1), (x, y - 1), (x - 1, y), (x + 1, y), (x, y + 2)):
        cx, cy = cand
        if 0 <= cy < len(rows) and 0 <= cx < len(rows[0]) and rows[cy][cx] in WALKABLE and cand not in blocked:
            return cand
    return None


def validate_scene(scene_id: str, info: dict, quest_targets: set[str]) -> tuple[list[str], set[str]]:
    errors: list[str] = []
    rows = load_rows(res_path(info["map"]))
    data = json.loads(res_path(info["props"]).read_text(encoding="utf-8"))
    data["_battle"] = info.get("battle", {})
    dialogue = json.loads(res_path(info["dialogue"]).read_text(encoding="utf-8"))
    width, height = data["world_size"]
    if len(rows) != height:
        errors.append(f"[{scene_id}] 地圖列數 {len(rows)} ≠ {height}")
    for i, row in enumerate(rows):
        if len(row) != width:
            errors.append(f"[{scene_id}] 第 {i} 列寬度 {len(row)} ≠ {width}")
        for ch in row:
            if ch not in WALKABLE | SOLID:
                errors.append(f"[{scene_id}] 第 {i} 列有未知圖例 '{ch}'")
    if errors:
        return errors, set()

    blocked = blocked_by_props(data, width, height)
    for prop in data.get("props", []):
        tx, ty = int(prop["x"] // TILE), int((prop["y"] - 1) // TILE)
        if prop.get("collision") and rows[ty][tx] not in WALKABLE:
            print(f"注意：[{scene_id}] {prop['texture']} 的底部落在非行走格 ({tx},{ty}) '{rows[ty][tx]}'")

    spawn = tuple(data["spawn_points"][0])
    for name, tiles in {"spawn_points": data["spawn_points"], **data.get("entries", {})}.items():
        for sp in tiles:
            p = tuple(sp)
            if rows[p[1]][p[0]] not in WALKABLE or p in blocked:
                errors.append(f"[{scene_id}] 入口 {name} 的格 {p} 不可站立")

    checkpoints: dict[str, tuple[int, int]] = {}
    for c in data.get("connectors", []):
        checkpoints[c["name"]] = tuple(c["tile"])
    for e in data.get("exits", []):
        checkpoints[e["name"]] = tuple(e["tile"])
    if scene_id == "tide_root_town":
        checkpoints["top_center"] = (14, 2)
    for portal in data.get("portals", []):
        tile = nearest_walkable(rows, blocked, world_to_tile(portal["x"], portal["y"]))
        if tile is None:
            errors.append(f"[{scene_id}] 傳送門 {portal['id']} 周圍沒有可站格")
        else:
            checkpoints[f"portal:{portal['id']}"] = tile

    for item in data.get("items", []):
        tile = world_to_tile(item["x"], item["y"] - 1)
        if rows[tile[1]][tile[0]] not in WALKABLE or tile in blocked:
            errors.append(f"[{scene_id}] 投擲物 {item['item']} 落在不可站格 {tile}")
        else:
            checkpoints[f"item:{item['item']}"] = tile
    battle = info_battle(data)
    if battle:
        tile = nearest_walkable(rows, blocked, world_to_tile(battle["x"], battle["y"] + 4))
        if tile is None:
            errors.append(f"[{scene_id}] Boss 周圍沒有可站格")
        else:
            checkpoints["boss"] = tile
        errors.extend(boss_top_margin_errors(scene_id, rows, battle))

    interact_ids: set[str] = set()
    for entry in data.get("props", []) + data.get("exits", []) + data.get("npcs", []):
        if not entry.get("interact"):
            continue
        interact_ids.add(entry["interact"])
        if "x" in entry:
            tile = nearest_walkable(rows, blocked, world_to_tile(entry["x"], entry["y"] + 4))
            if tile is None:
                errors.append(f"[{scene_id}] 互動點 {entry['interact']} 周圍沒有可站格")
            else:
                checkpoints[f"interact:{entry['interact']}"] = tile

    for name, goal in checkpoints.items():
        path = bfs(rows, blocked, spawn, goal)
        if path is None:
            errors.append(f"[{scene_id}] 從出生點無法走到 {name} {goal}")
        else:
            print(f"OK  [{scene_id}] {name:32s} {goal}  路徑長度 {len(path) - 1}")

    for ty in range(height):
        for tx in (0, width - 1):
            if rows[ty][tx] in WALKABLE and (tx, ty) not in blocked:
                errors.append(f"[{scene_id}] 邊界格 ({tx},{ty}) 可走且未封鎖")
    for tx in range(width):
        for ty in (0, height - 1):
            if rows[ty][tx] in WALKABLE and (tx, ty) not in blocked:
                errors.append(f"[{scene_id}] 邊界格 ({tx},{ty}) 可走且未封鎖")

    for interact_id in sorted(interact_ids):
        entry = dialogue.get(interact_id)
        variants = entry if isinstance(entry, list) else [entry]
        if not entry or any(not v or not v.get("lines") for v in variants):
            errors.append(f"[{scene_id}] 對話 JSON 缺少 {interact_id} 或沒有句子")
    print(f"OK  [{scene_id}] 互動物件 {len(interact_ids)} 個，對話內容齊全")
    return errors, interact_ids


def dialogue_has_lines(entry) -> bool:
    """一般對話（字典或版本陣列）每個版本都要有 lines；事件對話可用 segments（每段都要有 lines）。"""
    if isinstance(entry, dict) and isinstance(entry.get("segments"), list):
        return bool(entry["segments"]) and all(isinstance(seg, dict) and seg.get("lines") for seg in entry["segments"])
    variants = entry if isinstance(entry, list) else [entry]
    return bool(entry) and all(isinstance(v, dict) and v.get("lines") for v in variants)


def validate_events(scenes: dict, interacts_by_scene: dict[str, set[str]]) -> list[str]:
    errors: list[str] = []
    clues = json.loads(CLUES_PATH.read_text(encoding="utf-8")) if CLUES_PATH.exists() else {"clues": []}
    clue_ids = {clue["id"] for clue in clues.get("clues", [])}
    count = 0
    for event_path in sorted(EVENT_DIR.glob("*.json")):
        if event_path == CLUES_PATH:
            continue
        event = json.loads(event_path.read_text(encoding="utf-8"))
        label = f"[event:{event_path.stem}]"
        missing = [key for key in EVENT_REQUIRED_KEYS if key not in event]
        if missing:
            errors.append(f"{label} 缺少欄位 {missing}")
            continue
        scene_id = event["scene_id"]
        if scene_id not in scenes:
            errors.append(f"{label} 指向未知場景 {scene_id}")
            continue
        info = scenes[scene_id]
        props = json.loads(res_path(info["props"]).read_text(encoding="utf-8"))
        dialogue = json.loads(res_path(info["dialogue"]).read_text(encoding="utf-8"))
        target_ids = {prop["event_id"] for prop in props.get("props", []) if prop.get("event_id")}
        trigger = event["trigger"]
        if trigger.get("type") == "interact_complete" and trigger.get("interactable_id") not in interacts_by_scene.get(scene_id, set()):
            errors.append(f"{label} 觸發互動點 {trigger.get('interactable_id')} 不在場景 {scene_id}")
        types = [action.get("type") for action in event["actions"]]
        for action in event["actions"]:
            kind = action.get("type")
            if kind in TARGET_ACTIONS and action.get("target") not in target_ids:
                errors.append(f"{label} 動作 {kind} 的目標 {action.get('target')} 沒有在 {scene_id} 的 props 以 event_id 登錄")
            if kind == "dialogue" and not dialogue_has_lines(dialogue.get(action.get("dialogue_id"))):
                errors.append(f"{label} 對話 {action.get('dialogue_id')} 不存在或沒有句子")
            if kind == "clue" and action.get("clue_id") not in clue_ids:
                errors.append(f"{label} 線索 {action.get('clue_id')} 未在 clues.json 定義")
        if event.get("once"):
            flag = event.get("complete_flag")
            unlock_at = types.index("unlock_input") if "unlock_input" in types else len(types)
            sets = [i for i, action in enumerate(event["actions"]) if action.get("type") == "set_flag" and action.get("flag") == flag]
            if not flag or not sets or sets[0] > unlock_at:
                errors.append(f"{label} once 事件必須在 unlock_input 之前 set_flag {flag}")
        if types and (types[0] != "lock_input" or types[-1] != "unlock_input"):
            errors.append(f"{label} 動作應以 lock_input 開始、unlock_input 結束")
        count += 1
        print(f"OK  {label} 場景 {scene_id}、{len(types)} 個動作、目標 {sorted(target_ids)}")
    print(f"OK  世界事件 {count} 個資料齊全")
    return errors


def main() -> int:
    scenes = json.loads(SCENES_PATH.read_text(encoding="utf-8"))
    quest_targets: set[str] = set()
    for quest_path in sorted(QUEST_DIR.glob("*.json")):
        quests = json.loads(quest_path.read_text(encoding="utf-8"))
        quest_targets |= {o["target"] for q in quests["quests"] for o in q["objectives"] if o.get("kind") == "interact"}
    errors: list[str] = []
    all_interacts: set[str] = set()
    interacts_by_scene: dict[str, set[str]] = {}
    for scene_id, info in scenes.items():
        missing_files = [key for key in ("map", "props", "dialogue") if not res_path(info[key]).exists()]
        if missing_files:
            errors += [f"[{scene_id}] 找不到 {key}：{info[key]}" for key in missing_files]
            continue
        scene_errors, interacts = validate_scene(scene_id, info, quest_targets)
        errors += scene_errors
        all_interacts |= interacts
        interacts_by_scene[scene_id] = interacts
        for portal in json.loads(res_path(info["props"]).read_text(encoding="utf-8")).get("portals", []):
            target = portal.get("target")
            if target != "return" and target not in scenes:
                errors.append(f"[{scene_id}] 傳送門 {portal['id']} 指向未知場景 {target}")
    for target in sorted(quest_targets):
        if target not in all_interacts:
            errors.append(f"任務目標 {target} 不是任何場景的互動 id")
    print(f"OK  任務目標 {len(quest_targets)} 個皆對應互動物件")
    errors += validate_events(scenes, interacts_by_scene)

    if errors:
        print("\n".join(errors))
        return 1
    print("地圖驗證通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
