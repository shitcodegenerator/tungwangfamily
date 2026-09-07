#!/usr/bin/env python3
"""Phase 8 素材對照表：把 props／角色 PNG 放在灰色棋盤底上放大，標上檔名與尺寸，輸出到 docs/screenshots/phase8_baseline/contact_*.png。
只做檢視，不改任何素材。用法：python3 tools/contact_sheet_phase8.py"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/screenshots/phase8_baseline"
GROUPS = {
    "contact_town_refresh": sorted((ROOT / "assets/props/town_refresh").glob("*.png")),
    "contact_town_houses": sorted((ROOT / "assets/props").glob("house_*.png")) + [ROOT / "assets/props/canopy_gate.png"],
    "contact_family_home": sorted((ROOT / "assets/props").glob("int_*.png")),
    "contact_captain_room": sorted((ROOT / "assets/props").glob("cap_*.png")),
    "contact_characters": sorted((ROOT / "assets/characters/playable").glob("*_walk_v2_sheet.png"))
    + sorted((ROOT / "assets/characters/playable").glob("*_idle_sheet.png"))
    + sorted((ROOT / "assets/characters/playable").glob("*_action_sheet.png")),
    "contact_npcs_pets": sorted((ROOT / "assets/characters/npcs").glob("*.png")) + sorted((ROOT / "assets/characters/pets").glob("*.png")),
}


def checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    im = Image.new("RGBA", size, (96, 96, 96, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(120, 120, 120, 255))
    return im


def build(name: str, files: list[Path], scale: int, max_width: int = 1600) -> None:
    cells = []
    for p in files:
        im = Image.open(p).convert("RGBA")
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        label = f"{p.stem}  {im.width}x{im.height}"
        cell = checker((max(big.width, 7 * len(label) + 8) + 8, big.height + 22))
        cell.alpha_composite(big, (4, 18))
        d = ImageDraw.Draw(cell)
        d.rectangle((0, 0, cell.width, 14), fill=(0, 0, 0, 255))
        d.text((4, 2), label, fill=(255, 255, 0, 255))
        # 底緣接地線（紅）：貼圖最下一列
        d.line((4, 18 + big.height - 1, 4 + big.width, 18 + big.height - 1), fill=(255, 0, 0, 160))
        cells.append(cell)
    rows, row, w = [], [], 0
    for c in cells:
        if row and w + c.width > max_width:
            rows.append(row)
            row, w = [], 0
        row.append(c)
        w += c.width
    if row:
        rows.append(row)
    H = sum(max(c.height for c in r) for r in rows)
    W = max(sum(c.width for c in r) for r in rows)
    sheet = Image.new("RGBA", (W, H), (30, 30, 30, 255))
    y = 0
    for r in rows:
        x, rh = 0, max(c.height for c in r)
        for c in r:
            sheet.paste(c, (x, y))
            x += c.width
        y += rh
    dest = OUT / f"{name}.png"
    sheet.save(dest)
    print(dest.relative_to(ROOT), sheet.size, len(files), "張")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, files in GROUPS.items():
        build(name, files, 1 if "characters" in name or "npcs" in name else 2)
