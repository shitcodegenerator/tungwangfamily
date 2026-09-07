#!/usr/bin/env python3
"""Phase 8 P8.0 資產盤點：讀三個場景的 props JSON 與 PNG，算出尺寸、透明、接地、碰撞、z_bias、
「角色站在北側最多被蓋幾 px」（hidden = 圖高 − foot_inset − 碰撞高），輸出 Markdown 表到 docs/PHASE_8_ASSET_AUDIT_TABLE.md（人工判定寫在 docs/PHASE_8_ASSET_AUDIT.md）。
不改任何檔案。用法：python3 tools/audit_props_phase8.py"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MAPS = {
    "tide_root_town": "assets/maps/tide_root_town.txt",
    "family_home": "assets/maps/family_home.txt",
    "captain_room": "assets/maps/captain_room.txt",
}
WALKABLE = "gdrpbsm=|w"
THIN_WIDTH = 48   # 比角色窄的柱狀物（燈柱、旗、路標）自然遮擋，不算問題
SCENES = {
    "tide_root_town": "assets/maps/tide_root_town_props.json",
    "family_home": "assets/maps/family_home_props.json",
    "captain_room": "assets/maps/captain_room_props.json",
}
CHAR_H = 61       # 主角腳底 y=61
ANKLE_OK = 20     # 只蓋到腳踝可接受
OUT = ROOT / "docs/PHASE_8_ASSET_AUDIT_TABLE.md"


def png_stats(path: Path, frames: int) -> dict:
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    w, h = im.size
    fw = w // frames
    px = a.load()
    semi = sum(1 for y in range(h) for x in range(w) if 0 < px[x, y] < 255)
    total = w * h
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bbox = a.getbbox() or (0, 0, w, h)
    return {
        "size": f"{fw}×{h}" + (f" ×{frames}幀" if frames > 1 else ""),
        "corners_clear": all(c == 0 for c in corners),
        "semi_pct": 100.0 * semi / total,
        "bottom_gap": h - bbox[3],      # 最下方不透明列距圖底幾 px（>0 代表懸空）
        "top_gap": bbox[1],
    }


def north_walkable(rows: list[str], x: float, y: float, width: float, collision_h: float) -> bool:
    """碰撞盒頂端正上方那一列，在貼圖 x 範圍內是否有可走格。"""
    ty = int((y - collision_h - 1) // 32)
    if ty < 0 or ty >= len(rows):
        return False
    for tx in range(int((x - width / 2) // 32), int((x + width / 2 - 1) // 32) + 1):
        if 0 <= tx < len(rows[ty]) and rows[ty][tx] in WALKABLE:
            return True
    return False


def audit(scene: str, rel: str) -> list[dict]:
    data = json.loads((ROOT / rel).read_text(encoding="utf-8"))
    map_rows = [r for r in (ROOT / MAPS[scene]).read_text(encoding="utf-8").splitlines() if r]
    rows = []
    for p in data["props"]:
        tex = p["texture"]
        path = ROOT / "assets/props" / f"{tex}.png"
        frames = int(p.get("frames", 1))
        st = png_stats(path, frames)
        h = Image.open(path).height
        fi = float(p.get("foot_inset", 0))
        col = p.get("collision")
        boxes = p.get("collision_boxes")
        z = int(p.get("z_bias", 0))
        ch = float(col[1]) if isinstance(col, list) else (max(b[1] for b in boxes) if boxes else None)
        hidden = None if ch is None else max(0.0, h - fi - ch)
        w = Image.open(path).width // frames
        north = ch is not None and north_walkable(map_rows, float(p["x"]), float(p["y"]), w, ch)
        if col is None and not boxes:
            verdict = "KEEP（無碰撞裝飾）" if z < 0 or h <= 48 else "CHECK（無碰撞但會與角色 Y-sort）"
        elif hidden is not None and hidden > ANKLE_OK and not north:
            verdict = "KEEP（北側為牆，走不到後面）"
        elif hidden is not None and hidden > ANKLE_OK and w < THIN_WIDTH:
            verdict = "KEEP（柱狀薄物件，自然遮擋）"
        elif hidden is not None and hidden > ANKLE_OK:
            new_ch = int(h - fi - 16)
            verdict = f"FIX 碰撞高 {int(ch)}→{new_ch}（現況北側角色被蓋 {int(hidden)}px{'，只剩頭' if hidden >= CHAR_H - 16 else '，半身'}）"
        else:
            verdict = "KEEP"
        if not st["corners_clear"]:
            verdict += "；四角不透明"
        if st["semi_pct"] > 3.0:
            verdict += f"；半透明像素 {st['semi_pct']:.1f}%"
        if st["bottom_gap"] > 2 and fi == 0:
            verdict += f"；底緣懸空 {st['bottom_gap']}px"
        rows.append({
            "scene": scene, "texture": tex, "size": st["size"], "xy": f"({p.get('x')},{p.get('y')})",
            "collision": json.dumps(col) if col is not None else (f"boxes {boxes}" if boxes else "null"),
            "foot_inset": int(fi), "z_bias": z, "hidden": "" if hidden is None else int(hidden), "north": "是" if north else "否",
            "event": p.get("event_id", ""), "verdict": verdict,
        })
    return rows


def main() -> None:
    lines = ["# Phase 8 資產盤點（P8.0，由 tools/audit_props_phase8.py 產生）", "",
             "hidden = 圖高 − foot_inset − 碰撞高：角色貼著碰撞盒站在家具北側時，最多被圖片蓋住的像素（角色高 61）。",
             "≤ 20 只蓋腳踝可接受；FIX 建議把碰撞高提到「圖高 − foot_inset − 16」，不加 z_bias -1。",
             "風格（REDRAW）需人工看 docs/screenshots/phase8_baseline/contact_*.png 判定，本表只列可量測項目。", ""]
    for scene, rel in SCENES.items():
        rows = audit(scene, rel)
        lines += [f"## {scene}（{rel}）", "",
                  "| texture | 尺寸 | 原點 | collision | foot_inset | z_bias | hidden | 北側可走 | event | 判定 |",
                  "|---|---|---|---|---:|---:|---:|---|---|---|"]
        for r in rows:
            lines.append(f"| {r['texture']} | {r['size']} | {r['xy']} | {r['collision']} | {r['foot_inset']} | {r['z_bias']} | {r['hidden']} | {r['north']} | {r['event']} | {r['verdict']} |")
        lines.append("")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(OUT.relative_to(ROOT))
    print("\n".join(l for l in lines if "FIX" in l or "CHECK" in l))


if __name__ == "__main__":
    main()
