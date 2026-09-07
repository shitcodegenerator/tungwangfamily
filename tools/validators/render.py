"""MAP-P007：每個 props 都必須宣告正式 render_mode，且與碰撞、z_bias 一致（Phase 8.5-C）。

render_mode（見 docs/RENDERING_AND_PLACEMENT_SPEC.md）：
- ground：地毯、池面等地面花紋；畫在角色後方，不得有碰撞
- back：牆掛物、門窗、雲、藤蔓、樹屋這類「角色永遠在它前方」的物件；畫在角色後方，碰撞只描述實體
- ysort：桌、櫃、箱、自立家具；底部中央原點 Y-sort，碰撞只描述不可穿越的實體
- split：拱門這類可走到後方／下方的高大物件；base（有碰撞、Y-sort）＋ canopy（無碰撞、前景）共用同一錨點
"""
from __future__ import annotations

from .common import Finding, Scene, prop_label

RENDER_MODES = ("ground", "back", "ysort", "split")
SPLIT_ROLES = ("base", "canopy")
GROUND_NAMES = ("rug", "lily_pond", "harbor_berth", "carpet", "mat")
BACK_NAMES = ("window", "side_door", "back_door", "wall_map", "painting", "porthole", "hanging_lantern", "cloud", "tree_heart", "tree_spiral", "tree_platform", "vine_branch", "treehouse", "banner_wall")


def has_collision(prop: dict) -> bool:
    col = prop.get("collision")
    return (isinstance(col, list) and len(col) == 2) or bool(prop.get("collision_boxes"))


def suggest_render_mode(prop: dict) -> tuple[str, str | None]:
    """依既有欄位與貼圖名稱猜正式模式（只給 --audit 與遷移腳本用，驗證時不採用）。"""
    name = str(prop.get("texture", "")).lower()
    if "archway" in name:
        return "split", "canopy" if "canopy" in name else "base"
    if any(key in name for key in GROUND_NAMES):
        return "ground", None
    if any(key in name for key in BACK_NAMES):
        return "back", None
    if int(prop.get("z_bias", 0)) < 0:
        return "back", None
    return "ysort", None


def check_render_modes(scene: Scene) -> list[Finding]:
    findings: list[Finding] = []
    split_partners: dict[tuple[float, float], set[str]] = {}
    for prop in scene.data.get("props", []):
        label = prop_label(prop)
        mode = prop.get("render_mode")
        z_bias = prop.get("z_bias")
        if mode not in RENDER_MODES:
            guess, role = suggest_render_mode(prop)
            hint = f'"render_mode": "{guess}"' + (f', "split_role": "{role}"' if role else "")
            findings.append(Finding("MAP-P007", scene.scene_id, label, f"沒有宣告正式 render_mode（現值 {mode!r}）", fix=f"加上 {hint}；四種模式見 docs/RENDERING_AND_PLACEMENT_SPEC.md"))
            continue
        if mode == "ground":
            if has_collision(prop):
                findings.append(Finding("MAP-P007", scene.scene_id, label, "ground 模式不得有碰撞", fix="改 back／ysort，或拿掉 collision"))
            if z_bias not in (None, -1):
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"ground 模式不接受 z_bias {z_bias}", fix="刪除 z_bias（由 render_mode 決定層級）"))
        elif mode == "back":
            if z_bias not in (None, -1):
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"back 模式不接受 z_bias {z_bias}", fix="刪除 z_bias"))
        elif mode == "ysort":
            if z_bias not in (None, 0):
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"ysort 模式不得用 z_bias {z_bias} 補救遮擋", fix="加深碰撞到貼圖高−16；真的要走到後方就拆 split"))
        elif mode == "split":
            role = prop.get("split_role")
            if role not in SPLIT_ROLES:
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"split 模式必須宣告 split_role base／canopy（現值 {role!r}）"))
                continue
            key = (float(prop.get("x", 0)), float(prop.get("y", 0)))
            split_partners.setdefault(key, set()).add(role)
            if role == "base" and not has_collision(prop):
                findings.append(Finding("MAP-P007", scene.scene_id, label, "split base 必須有碰撞（拱腳）"))
            if role == "canopy" and has_collision(prop):
                findings.append(Finding("MAP-P007", scene.scene_id, label, "split canopy 不得有碰撞", fix="碰撞只放在 base"))
            if role == "base" and z_bias not in (None, 0):
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"split base 走 Y-sort，不接受 z_bias {z_bias}"))
            if role == "canopy" and z_bias not in (None, 1):
                findings.append(Finding("MAP-P007", scene.scene_id, label, f"split canopy 固定前景層，不接受 z_bias {z_bias}"))
            if prop.get("foot_inset") is None:
                findings.append(Finding("MAP-P007", scene.scene_id, label, "split 兩層必須宣告相同 foot_inset（同一錨點）"))
    for (x, y), roles in split_partners.items():
        if roles != set(SPLIT_ROLES):
            findings.append(Finding("MAP-P007", scene.scene_id, f"split@({x:g},{y:g})", f"split 必須 base 與 canopy 成對且同錨點（現有 {sorted(roles)}）"))
    return findings
