"""MAP-P001～P005：碰撞對齊、保留格、互動站位、出入口、連通。"""
from __future__ import annotations

from .common import (
    TILE,
    Finding,
    Scene,
    Tile,
    bfs,
    blocked_all,
    blocked_by_props,
    prop_blocked_tiles,
    prop_label,
    reachable_set,
    stand_candidates,
    standable,
    world_to_tile,
)

LARGE_COLLISION_HEIGHT = 32


def aligned_heights(y: float, h: float) -> tuple[int, int]:
    """碰撞頂端 y-h 落到 32 格線的兩個候選高度：往上對齊（封鎖格不變、實體盒稍大）與往下對齊（少封一列）。"""
    top = y - h
    row_top = (top // TILE) * TILE
    return int(y - row_top), int(y - (row_top + TILE))


def important_tiles(scene: Scene) -> set[Tile]:
    """保留格 ＋ 所有互動候選站位（給 MAP-P001 判斷該往哪個方向對齊）。"""
    tiles = set(reserved_tiles(scene))
    for _id, _tile, candidates in interact_entries(scene):
        tiles |= set(candidates)
    return tiles


def check_collision_grid(scene: Scene) -> list[Finding]:
    """MAP-P001：高度 ≥ 32 的碰撞盒（含 collision_boxes），頂端必須落在 32px 格線。
    否則多出來的幾個 px 會把整列登記為封鎖格，路徑規劃與實體碰撞不一致。"""
    findings: list[Finding] = []
    for prop in scene.data.get("props", []):
        y = float(prop.get("y", 0))
        col = prop.get("collision")
        if isinstance(col, list) and len(col) == 2 and float(col[1]) >= LARGE_COLLISION_HEIGHT:
            top = y - float(col[1])
            if top % TILE:
                up, down = aligned_heights(y, float(col[1]))
                hint = f"collision 高改 {up}（封鎖格不變）或 {down}（少封一列）"
                spill = sorted(prop_blocked_tiles(prop, scene.width, scene.height) & important_tiles(scene))
                if spill:
                    hint = f"collision 高改 {down}（少封一列）：伸進去的那一列有站位／保留格 {spill}；{up} 會繼續封住它們"
                findings.append(Finding("MAP-P001", scene.scene_id, prop_label(prop), f"碰撞頂端 y={top:g} 不在 32 格線（{top % TILE:g}px 伸進上一列）", world_to_tile(prop["x"], top), hint))
        for index, box in enumerate(prop.get("collision_boxes") or []):
            if not (isinstance(box, list) and len(box) == 4):
                continue
            w, h, dx, dy = (float(v) for v in box)
            top = y + dy - h
            if h >= LARGE_COLLISION_HEIGHT and top % TILE:
                up, down = aligned_heights(y + dy, h)
                findings.append(Finding("MAP-P001", scene.scene_id, f"{prop_label(prop)} box[{index}]", f"碰撞盒頂端 y={top:g} 不在 32 格線", world_to_tile(prop["x"] + dx, top), f"box 高改 {up} 或 {down}"))
    return findings


def reserved_tiles(scene: Scene) -> dict[Tile, list[str]]:
    """不得被 props 碰撞覆蓋的格子 → 用途說明。"""
    reserved: dict[Tile, list[str]] = {}

    def add(tile: Tile, label: str) -> None:
        reserved.setdefault(tile, []).append(label)

    for npc in scene.data.get("npcs", []):
        # NPC 原點在腳底（y 落在格線上時，腳所在的格是 y-1 那一列）
        add(world_to_tile(npc["x"], npc["y"] - 1), f"NPC {npc.get('id', '?')} 站位")
    for sp in scene.data.get("spawn_points", []):
        add((int(sp[0]), int(sp[1])), "spawn_points")
    for name, tiles in scene.data.get("entries", {}).items():
        for sp in tiles:
            add((int(sp[0]), int(sp[1])), f"entries.{name}")
    for exit_ in scene.data.get("exits", []):
        add((int(exit_["tile"][0]), int(exit_["tile"][1])), f"exit {exit_.get('name', '?')}")
    for connector in scene.data.get("connectors", []):
        add((int(connector["tile"][0]), int(connector["tile"][1])), f"connector {connector.get('name', '?')}")
    for portal in scene.data.get("portals", []):
        if portal.get("return_position"):
            rx, ry = portal["return_position"]
            add(world_to_tile(rx, ry), f"portal {portal.get('id', '?')} return_position")
    for item in scene.data.get("items", []):
        add(world_to_tile(item["x"], item["y"] - 1), f"item {item.get('item', '?')}")
    battle = scene.battle
    if battle:
        add(world_to_tile(battle["x"], battle["y"]), "Boss 生成點")
    for entry in scene.data.get("reserved_tiles", []):
        if isinstance(entry, dict):
            add((int(entry["tile"][0]), int(entry["tile"][1])), f"reserved {entry.get('reason', '')}")
        elif isinstance(entry, list) and len(entry) >= 2:
            add((int(entry[0]), int(entry[1])), "reserved")
    return reserved


def check_reserved(scene: Scene) -> list[Finding]:
    """MAP-P002：props 碰撞不得覆蓋 NPC 站位、出生點、入口、出口、傳送門返回點、投擲物、Boss 生成點與 reserved_tiles。"""
    findings: list[Finding] = []
    blocked = blocked_by_props(scene)
    for tile, labels in sorted(reserved_tiles(scene).items()):
        culprits = blocked.get(tile)
        if culprits:
            findings.append(Finding("MAP-P002", scene.scene_id, "、".join(sorted(set(culprits))), f"碰撞覆蓋保留格（{'、'.join(labels)}）", tile, "縮小碰撞高度到格線上一列，或移動物件；不要移動出生點／NPC 遷就家具"))
    return findings


FACING_OFFSET = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}


def interact_entries(scene: Scene) -> list[tuple[str, Tile, list[Tile]]]:
    """有座標的互動物件（props、npcs、exits）→ (id, 互動格, 候選站位)。
    互動格與 town_world 相同（y+4）；NPC 有 facing 時只接受面前那一格（玩家要面對面對話，不能從背後）。"""
    result: list[tuple[str, Tile, list[Tile]]] = []
    for entry in scene.data.get("props", []) + scene.data.get("npcs", []) + scene.data.get("exits", []):
        if not entry.get("interact"):
            continue
        if "x" in entry:
            tile = world_to_tile(entry["x"], entry["y"] + 4)
        elif entry.get("interact_center"):
            cx, cy = entry["interact_center"]
            tile = world_to_tile(cx, cy + 4)
        else:
            continue
        facing = FACING_OFFSET.get(str(entry.get("facing", "")))
        if facing and entry.get("id"):
            # NPC：面前與左右三格（不接受背後、不接受 NPC 自己的格）。面前那格可能被作者刻意封住（例如噴泉北側口袋），所以側邊也算。
            bx, by = world_to_tile(entry["x"], entry["y"] - 1)
            fx, fy = facing
            candidates = [(bx + fx, by + fy), (bx + fy, by + fx), (bx - fy, by - fx)]
        else:
            candidates = stand_candidates(tile)
        result.append((str(entry["interact"]), tile, candidates))
    return result


def check_interact_standing(scene: Scene, walkable: set[str]) -> list[Finding]:
    """MAP-P003：每個互動物件至少有一個候選站位可站，而且能從出生點 BFS 走到。"""
    findings: list[Finding] = []
    blocked = blocked_all(scene)
    by_prop = blocked_by_props(scene)
    spawn = tuple(int(v) for v in scene.data["spawn_points"][0])
    reach = reachable_set(scene, walkable, blocked, spawn)
    for interact_id, tile, candidates in interact_entries(scene):
        standing = [c for c in candidates if standable(scene, walkable, blocked, c)]
        if not standing:
            culprits = sorted({label for c in candidates for label in by_prop.get(c, [])})
            where = "面前那一格" if len(candidates) == 1 else "周圍"
            findings.append(Finding("MAP-P003", scene.scene_id, f"interact:{interact_id}", f"{where}沒有可站格", tile, f"讓 {candidates[0] if len(candidates) == 1 else candidates[1]} 空出來；封住的有：{'、'.join(culprits) or '地形'}"))
        elif not any(c in reach for c in standing):
            findings.append(Finding("MAP-P003", scene.scene_id, f"interact:{interact_id}", f"站位 {standing} 從出生點走不到", tile, "檢查中間被哪個 props 封路（用 --audit 看 MAP-P005）"))
    return findings


def required_nodes(scene: Scene, walkable: set[str], blocked: set[Tile]) -> list[tuple[str, Tile, str]]:
    """場景必要節點 → (名稱, 應站的格, 類別)。傳送門與 Boss 用候選站位裡第一個可站的格。"""
    nodes: list[tuple[str, Tile, str]] = []
    for sp in scene.data.get("spawn_points", []):
        nodes.append(("spawn_point", (int(sp[0]), int(sp[1])), "spawn"))
    for name, tiles in scene.data.get("entries", {}).items():
        for sp in tiles:
            nodes.append((f"entry:{name}", (int(sp[0]), int(sp[1])), "entry"))
    for connector in scene.data.get("connectors", []):
        nodes.append((connector["name"], (int(connector["tile"][0]), int(connector["tile"][1])), "connector"))
    for exit_ in scene.data.get("exits", []):
        nodes.append((exit_["name"], (int(exit_["tile"][0]), int(exit_["tile"][1])), "exit"))
    if scene.scene_id == "tide_root_town":
        nodes.append(("top_center", (14, 2), "checkpoint"))
    for portal in scene.data.get("portals", []):
        first = next((c for c in stand_candidates(world_to_tile(portal["x"], portal["y"])) if standable(scene, walkable, blocked, c)), None)
        nodes.append((f"portal:{portal['id']}", first if first is not None else world_to_tile(portal["x"], portal["y"]), "portal"))
        if portal.get("return_position"):
            rx, ry = portal["return_position"]
            nodes.append((f"return:{portal['id']}", world_to_tile(rx, ry), "return"))
    for item in scene.data.get("items", []):
        nodes.append((f"item:{item['item']}", world_to_tile(item["x"], item["y"] - 1), "item"))
    battle = scene.battle
    if battle:
        first = next((c for c in stand_candidates(world_to_tile(battle["x"], battle["y"] + 4)) if standable(scene, walkable, blocked, c)), None)
        nodes.append(("boss", first if first is not None else world_to_tile(battle["x"], battle["y"]), "boss"))
    return nodes


def check_exits_and_returns(scene: Scene, walkable: set[str]) -> list[Finding]:
    """MAP-P004：出生點、入口、出口、連接點、傳送門站位與返回點、投擲物都必須落在可站格（可走且未被碰撞封鎖）。"""
    findings: list[Finding] = []
    blocked = blocked_all(scene)
    by_prop = blocked_by_props(scene)
    for name, tile, kind in required_nodes(scene, walkable, blocked):
        if standable(scene, walkable, blocked, tile):
            continue
        x, y = tile
        ch = scene.char_at(x, y)
        reason = f"落在不可走格 '{ch}'" if ch not in walkable else f"被碰撞封鎖：{'、'.join(by_prop.get(tile, ['NPC／Boss']))}"
        findings.append(Finding("MAP-P004", scene.scene_id, f"{kind}:{name}", reason, tile, "改座標到可站格，或縮小封住它的碰撞"))
    return findings


def check_connectivity(scene: Scene, walkable: set[str], ok_lines: list[str] | None = None) -> list[Finding]:
    """MAP-P005：從出生點到每個必要節點都有路徑（互動站位由 MAP-P003 另外檢查）。"""
    findings: list[Finding] = []
    blocked = blocked_all(scene)
    spawn = tuple(int(v) for v in scene.data["spawn_points"][0])
    for name, tile, kind in required_nodes(scene, walkable, blocked):
        if kind == "spawn":
            continue
        path = bfs(scene, walkable, blocked, spawn, tile)
        if path is None:
            findings.append(Finding("MAP-P005", scene.scene_id, f"{kind}:{name}", "從出生點走不到", tile, "用 --audit 列出封路的 props；碰撞頂端對齊格線通常就能解"))
        elif ok_lines is not None:
            ok_lines.append(f"OK  [{scene.scene_id}] {name:32s} {tile}  路徑長度 {len(path) - 1}")
    return findings


def check_boundary(scene: Scene, walkable: set[str]) -> list[Finding]:
    """地圖四邊的可走格必須被碰撞封住（角色不得走出地圖）。"""
    findings: list[Finding] = []
    blocked = blocked_all(scene)
    edge: list[Tile] = [(tx, ty) for ty in range(scene.height) for tx in (0, scene.width - 1)]
    edge += [(tx, ty) for tx in range(scene.width) for ty in (0, scene.height - 1)]
    for tile in sorted(set(edge)):
        if scene.char_at(*tile) in walkable and tile not in blocked:
            findings.append(Finding("MAP-P004", scene.scene_id, "邊界", "邊界格可走且未封鎖", tile, "改成牆或加封鎖用的 props"))
    return findings


def blocking_report(scene: Scene) -> list[str]:
    """--audit 用：每個 props 封住哪些格。"""
    lines: list[str] = []
    for prop in scene.data.get("props", []):
        tiles = sorted(prop_blocked_tiles(prop, scene.width, scene.height))
        if tiles:
            lines.append(f"    {prop_label(prop)} 封鎖 {len(tiles)} 格：{tiles[0]}…{tiles[-1]}")
    return lines
