"""內容檢查（Phase 3～6 既有規則）：Boss 邊界、對話、任務目標、世界事件。"""
from __future__ import annotations

from pathlib import Path

from .common import ROOT, TILE, Finding, Scene, load_json, res_path

QUEST_DIR = ROOT / "assets" / "quests"
EVENT_DIR = ROOT / "assets" / "events"
CLUES_NAME = "clues.json"
EVENT_REQUIRED_KEYS = ("event_id", "scene_id", "trigger", "actions")
TARGET_ACTIONS = ("tween_node", "shader_param")
BOSS_TOP_MARGIN_TILES = 2
BOSS_HEAD_HEIGHT = 78


def first_walkable_row(scene: Scene, walkable: set[str]) -> int:
    for y, row in enumerate(scene.rows):
        if any(ch in walkable for ch in row):
            return y
    return -1


def check_boss(scene: Scene, walkable: set[str]) -> list[Finding]:
    """Boss 生成點與活動下限（min_y）都必須離最上方的可走列至少 2 格，且頭部不會超出地圖上緣。"""
    battle = scene.battle
    if not battle:
        return []
    findings: list[Finding] = []
    top = first_walkable_row(scene, walkable)
    min_y = float(battle.get("min_y", battle["y"]))
    limit = (top + BOSS_TOP_MARGIN_TILES) * TILE
    if min_y < limit:
        findings.append(Finding("MAP-C001", scene.scene_id, "boss", f"min_y={min_y:g} 離地圖上緣不足 {BOSS_TOP_MARGIN_TILES} 格（需 ≥ {limit}）"))
    if float(battle["y"]) < min_y:
        findings.append(Finding("MAP-C001", scene.scene_id, "boss", f"生成點 y={battle['y']} 高於 min_y={min_y:g}"))
    if min_y - BOSS_HEAD_HEIGHT < 0:
        findings.append(Finding("MAP-C001", scene.scene_id, "boss", f"頭部會超出地圖上緣（min_y={min_y:g}，頭高 {BOSS_HEAD_HEIGHT}）"))
    return findings


def interact_ids(scene: Scene) -> set[str]:
    return {str(e["interact"]) for e in scene.data.get("props", []) + scene.data.get("exits", []) + scene.data.get("npcs", []) if e.get("interact")}


def dialogue_has_lines(entry) -> bool:
    """一般對話（字典或版本陣列）每個版本都要有 lines；事件對話可用 segments（每段都要有 lines）。"""
    if isinstance(entry, dict) and isinstance(entry.get("segments"), list):
        return bool(entry["segments"]) and all(isinstance(seg, dict) and seg.get("lines") for seg in entry["segments"])
    variants = entry if isinstance(entry, list) else [entry]
    return bool(entry) and all(isinstance(v, dict) and v.get("lines") for v in variants)


def check_dialogue(scene: Scene) -> list[Finding]:
    findings: list[Finding] = []
    for interact_id in sorted(interact_ids(scene)):
        if not dialogue_has_lines(scene.dialogue.get(interact_id)):
            findings.append(Finding("MAP-C002", scene.scene_id, f"interact:{interact_id}", "對話 JSON 缺少此 id 或沒有句子", fix=f"在 {scene.info.get('dialogue', '對話檔')} 補上"))
    return findings


def load_quest_targets(quest_dir: Path = QUEST_DIR) -> set[str]:
    targets: set[str] = set()
    for quest_path in sorted(quest_dir.glob("*.json")):
        quests = load_json(quest_path)
        targets |= {o["target"] for q in quests["quests"] for o in q["objectives"] if o.get("kind") == "interact"}
    return targets


def check_quest_targets(quest_targets: set[str], all_interacts: set[str]) -> list[Finding]:
    return [Finding("MAP-C003", "quests", target, "任務目標不是任何場景的互動 id") for target in sorted(quest_targets - all_interacts)]


def check_portal_targets(scene: Scene, scene_ids: set[str]) -> list[Finding]:
    findings: list[Finding] = []
    for portal in scene.data.get("portals", []):
        target = portal.get("target")
        if target != "return" and target not in scene_ids:
            findings.append(Finding("MAP-C004", scene.scene_id, f"portal:{portal.get('id')}", f"指向未知場景 {target}"))
    return findings


def check_events(scenes: dict[str, Scene], event_dir: Path = EVENT_DIR, ok_lines: list[str] | None = None) -> list[Finding]:
    findings: list[Finding] = []
    clues_path = event_dir / CLUES_NAME
    clues = load_json(clues_path) if clues_path.exists() else {"clues": []}
    clue_ids = {clue["id"] for clue in clues.get("clues", [])}
    count = 0
    for event_path in sorted(event_dir.glob("*.json")):
        if event_path.name == CLUES_NAME:
            continue
        event = load_json(event_path)
        label = f"event:{event_path.stem}"
        missing = [key for key in EVENT_REQUIRED_KEYS if key not in event]
        if missing:
            findings.append(Finding("MAP-C005", "events", label, f"缺少欄位 {missing}"))
            continue
        scene_id = event["scene_id"]
        scene = scenes.get(scene_id)
        if scene is None:
            findings.append(Finding("MAP-C005", "events", label, f"指向未知場景 {scene_id}"))
            continue
        target_ids = {prop["event_id"] for prop in scene.data.get("props", []) if prop.get("event_id")}
        trigger = event["trigger"]
        if trigger.get("type") == "interact_complete" and trigger.get("interactable_id") not in interact_ids(scene):
            findings.append(Finding("MAP-C005", scene_id, label, f"觸發互動點 {trigger.get('interactable_id')} 不在場景"))
        types = [action.get("type") for action in event["actions"]]
        for action in event["actions"]:
            kind = action.get("type")
            if kind in TARGET_ACTIONS and action.get("target") not in target_ids:
                findings.append(Finding("MAP-C005", scene_id, label, f"動作 {kind} 的目標 {action.get('target')} 沒有在 props 以 event_id 登錄"))
            if kind == "dialogue" and not dialogue_has_lines(scene.dialogue.get(action.get("dialogue_id"))):
                findings.append(Finding("MAP-C005", scene_id, label, f"對話 {action.get('dialogue_id')} 不存在或沒有句子"))
            if kind == "clue" and action.get("clue_id") not in clue_ids:
                findings.append(Finding("MAP-C005", scene_id, label, f"線索 {action.get('clue_id')} 未在 clues.json 定義"))
        if event.get("once"):
            flag = event.get("complete_flag")
            unlock_at = types.index("unlock_input") if "unlock_input" in types else len(types)
            sets = [i for i, action in enumerate(event["actions"]) if action.get("type") == "set_flag" and action.get("flag") == flag]
            if not flag or not sets or sets[0] > unlock_at:
                findings.append(Finding("MAP-C005", scene_id, label, f"once 事件必須在 unlock_input 之前 set_flag {flag}"))
        if types and (types[0] != "lock_input" or types[-1] != "unlock_input"):
            findings.append(Finding("MAP-C005", scene_id, label, "動作應以 lock_input 開始、unlock_input 結束"))
        count += 1
        if ok_lines is not None:
            ok_lines.append(f"OK  [{label}] 場景 {scene_id}、{len(types)} 個動作、目標 {sorted(target_ids)}")
    if ok_lines is not None:
        ok_lines.append(f"OK  世界事件 {count} 個資料齊全")
    return findings


def check_scene_files(scene_id: str, info: dict, root: Path = ROOT) -> list[Finding]:
    return [Finding("MAP-S002", scene_id, key, f"找不到檔案 {info.get(key)}") for key in ("map", "props", "dialogue") if not res_path(str(info.get(key, "")), root).exists()]
