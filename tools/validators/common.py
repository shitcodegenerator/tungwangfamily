"""共用資料結構與幾何：與 scripts/world/town_world.gd、map_parser.gd 相同的規則。"""
from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TILE = 32
NPC_COLLISION = (20.0, 10.0)
BOSS_COLLISION = (40.0, 16.0)

Tile = tuple[int, int]


@dataclass
class Finding:
    """一筆驗證結果。code 為規則代碼（MAP-P001…），fix 為修正方向。"""

    code: str
    scene: str
    subject: str
    message: str
    tile: Tile | None = None
    fix: str = ""

    def render(self) -> str:
        where = f" @{self.tile}" if self.tile is not None else ""
        fix = f" → {self.fix}" if self.fix else ""
        return f"{self.code} [{self.scene}] {self.subject}{where}：{self.message}{fix}"

    def key(self) -> tuple[str, str, str]:
        return self.code, self.scene, self.subject


@dataclass
class Scene:
    """一個場景的資料（可由檔案載入，也可由測試直接組裝）。"""

    scene_id: str
    info: dict
    rows: list[str]
    data: dict
    dialogue: dict = field(default_factory=dict)

    @property
    def width(self) -> int:
        return int(self.data.get("world_size", [len(self.rows[0]), len(self.rows)])[0])

    @property
    def height(self) -> int:
        return int(self.data.get("world_size", [len(self.rows[0]), len(self.rows)])[1])

    @property
    def tile_style(self) -> str:
        return str(self.info.get("tile_style", "") or "default")

    @property
    def battle(self) -> dict:
        return self.info.get("battle", {}) or {}

    def char_at(self, x: int, y: int) -> str:
        if 0 <= y < len(self.rows) and 0 <= x < len(self.rows[y]):
            return self.rows[y][x]
        return "#"


def res_path(path: str, root: Path = ROOT) -> Path:
    return root / path.replace("res://", "")


def load_rows(path: Path) -> list[str]:
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def load_scene(scene_id: str, info: dict, root: Path = ROOT) -> Scene:
    rows = load_rows(res_path(info["map"], root))
    data = load_json(res_path(info["props"], root))
    dialogue = load_json(res_path(info["dialogue"], root)) if info.get("dialogue") else {}
    return Scene(scene_id, info, rows, data, dialogue)


def world_to_tile(x: float, y: float) -> Tile:
    return int(x // TILE), int(y // TILE)


def tile_center(tile: Tile) -> tuple[float, float]:
    return tile[0] * TILE + TILE / 2, tile[1] * TILE + TILE / 2


def blocked_rect(x: float, y: float, w: float, h: float, width: int, height: int, dx: float = 0.0, dy: float = 0.0) -> set[Tile]:
    """與 town_world.gd `_register_prop_blocking` 相同：碰撞盒（底部中央原點）內縮 1px 後，任何相交的格子都視為不可規劃。"""
    blocked: set[Tile] = set()
    cx, cy = x + dx, y + dy
    x0, x1 = cx - w / 2 + 1, cx + w / 2 - 1
    y0, y1 = cy - h + 1, cy - 1
    for ty in range(max(0, int(y0 // TILE)), min(height, int(y1 // TILE) + 1)):
        for tx in range(max(0, int(x0 // TILE)), min(width, int(x1 // TILE) + 1)):
            tx0, ty0 = tx * TILE, ty * TILE
            if x0 < tx0 + TILE and x1 > tx0 and y0 < ty0 + TILE and y1 > ty0:
                blocked.add((tx, ty))
    return blocked


def prop_label(prop: dict) -> str:
    return f"{prop.get('texture', '?')}({prop.get('x', '?')},{prop.get('y', '?')})"


def prop_blocked_tiles(prop: dict, width: int, height: int) -> set[Tile]:
    """單一 prop（collision ＋ collision_boxes）封鎖的格子。"""
    blocked: set[Tile] = set()
    col = prop.get("collision")
    if isinstance(col, list) and len(col) == 2:
        blocked |= blocked_rect(prop["x"], prop["y"], float(col[0]), float(col[1]), width, height)
    for box in prop.get("collision_boxes") or []:
        if isinstance(box, list) and len(box) == 4:
            w, h, dx, dy = (float(v) for v in box)
            blocked |= blocked_rect(prop["x"], prop["y"], w, h, width, height, dx, dy)
    return blocked


def blocked_by_props(scene: Scene) -> dict[Tile, list[str]]:
    """只算 props 的封鎖格 → 造成封鎖的 prop 標籤清單（供錯誤訊息點名）。"""
    result: dict[Tile, list[str]] = {}
    for prop in scene.data.get("props", []):
        for tile in prop_blocked_tiles(prop, scene.width, scene.height):
            result.setdefault(tile, []).append(prop_label(prop))
    return result


def blocked_all(scene: Scene) -> set[Tile]:
    """props ＋ NPC ＋ Boss 的封鎖格（與 town_world 的路徑規劃一致）。"""
    blocked = set(blocked_by_props(scene))
    for npc in scene.data.get("npcs", []):
        blocked |= blocked_rect(npc["x"], npc["y"], *NPC_COLLISION, scene.width, scene.height)
    battle = scene.battle
    if battle:
        blocked |= blocked_rect(battle["x"], battle["y"], *BOSS_COLLISION, scene.width, scene.height)
    return blocked


def is_walkable_char(ch: str, walkable: set[str]) -> bool:
    return ch in walkable


def standable(scene: Scene, walkable: set[str], blocked: set[Tile], tile: Tile) -> bool:
    x, y = tile
    return 0 <= y < scene.height and 0 <= x < scene.width and scene.rows[y][x] in walkable and tile not in blocked


def bfs(scene: Scene, walkable: set[str], blocked: set[Tile], start: Tile, goal: Tile) -> list[Tile] | None:
    if not standable(scene, walkable, blocked, start) or not standable(scene, walkable, blocked, goal):
        return None
    prev: dict[Tile, Tile | None] = {start: None}
    queue = deque([start])
    while queue:
        cur = queue.popleft()
        if cur == goal:
            path: list[Tile] = []
            node: Tile | None = cur
            while node is not None:
                path.append(node)
                node = prev[node]
            return path[::-1]
        x, y = cur
        for nxt in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nxt not in prev and standable(scene, walkable, blocked, nxt):
                prev[nxt] = cur
                queue.append(nxt)
    return None


def reachable_set(scene: Scene, walkable: set[str], blocked: set[Tile], start: Tile) -> set[Tile]:
    if not standable(scene, walkable, blocked, start):
        return set()
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nxt in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nxt not in seen and standable(scene, walkable, blocked, nxt):
                seen.add(nxt)
                queue.append(nxt)
    return seen


STAND_CANDIDATES = ((0, 0), (0, 1), (0, -1), (-1, 0), (1, 0), (0, 2))


def stand_candidates(tile: Tile) -> list[Tile]:
    """互動點與傳送門本身可能落在道具格上；候選站位：自身、南、北、西、東、南二格（與 Phase 3 起的規則相同）。"""
    x, y = tile
    return [(x + dx, y + dy) for dx, dy in STAND_CANDIDATES]
