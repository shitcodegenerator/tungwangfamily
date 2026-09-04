#!/usr/bin/env python3
"""Phase 4 素材產生器：CC、炸物魔王、投擲物、角色舉物／投擲幀、戰鬥特效、洞窟 tile、早餐攤。

來源全部在 assets/reference/incoming/（參考與切割來源，不直接當正式資源）：

- CC_pet_penguin_sheet_reference.png：5 欄 × 4 列 → 240×256 精靈表（與主角同規格，但高度縮小成寵物尺寸）
- BOSS_fried_food_demon_sheet_reference.png：3 × 2 六個姿勢，棋盤格底烙在像素裡 → 由邊緣泛洪去背 → 6 幀 80×80
- ITEM_throwables_vegetable_tea_water_reference.png：3 列（青菜、綠茶、水）× 4 欄（地面、舉起、飛行、命中）→ 每件 4 幀 28×28
- FX_cc_battle_reference.png：傳送、投擲軌跡、命中、炸雞翅、消散、勝利 → 個別特效貼圖
- ACTION_<角色>_carry_throw_reference.png：4 方向 × 4 欄 → 96×256（第 0 欄舉物、第 1 欄投擲）
  參考檔若不是 PNG（分支上曾有損毀檔）會略過並印出提示：遊戲內以站立幀 + CarryAnchor 代替
- 阿嬤：正式參考圖存在時走主角切割器，否則用老龜換色當佔位；洞窟參考仍缺，以合成的 32×32 tile 重建（tileset 第 5 列）

由 build_assets.py 自動呼叫，也可單獨執行：python3 tools/build_assets_phase4.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from build_assets import CELL_H, CELL_W, OUT_CHARS, OUT_PROPS, OUT_TILES, ROOT, TILE, crisp_alpha, find_components, noise_tile, scale_to
from build_assets_phase2 import INCOMING, OUT_EFFECTS, OUT_UI, build_character, union_box

OUT_PETS = ROOT / "assets" / "characters" / "pets"
OUT_BOSS = ROOT / "assets" / "characters" / "boss"
OUT_NPCS = ROOT / "assets" / "characters" / "npcs"
OUT_ITEMS = ROOT / "assets" / "items"

ATLAS_COLUMNS = 18
ATLAS_ROWS = 6  # 第 5 列：洞窟 tile
CAVE_ROW = 5

BOSS_CELL = 80
BOSS_MAX_HEIGHT = 74
ITEM_CELL = 28
ITEM_SPRITE_HEIGHT = 23  # Phase 4 visual polish: readable pickup/carry silhouette
ITEM_HIT_HEIGHT = 26
PET_MAX_HEIGHT = 40
ACTION_COLUMNS = 2  # 0 舉物、1 投擲

ITEM_ROWS = ["vegetable_bundle", "green_tea", "water_flask"]
ITEM_FRAMES = ["ground", "carry", "fly", "hit"]
ACTION_SOURCES = {
    "big_brother": "ACTION_big_brother_carry_throw_reference.png",
    "calm_brother": "ACTION_calm_brother_carry_throw_reference.png",
    "sister_sheep": "ACTION_sister_carry_throw_reference.png",
    "younger_brother": "ACTION_younger_brother_carry_throw_reference.png",
}
## 參考圖列序（畫師產出的方向順序），輸出一律轉成 down/left/right/up。
ACTION_ROW_ORDER = {
    "big_brother": ["down", "right", "left", "up"],
    "calm_brother": ["down", "right", "left", "up"],
    "sister_sheep": ["down", "right", "left", "up"],
    "younger_brother": ["down", "right", "left", "up"],
}
OUTPUT_ROWS = ["down", "left", "right", "up"]
## Phase 4.6 新造型行動表（作者提供原圖）：4 列 × 3 欄（列序 down/left/right/up；第 0 欄舉物、第 1 欄投擲、第 2 欄舉物變化）。
## 背景可能是白底、棋盤格或透明；縮放以 v2 行走表站立幀高度為準。
ACTION_V2_SOURCES = {
    "big_brother": "ACTION_big_brother_v2_carry_throw_reference.png",
    "calm_brother": "ACTION_calm_brother_v2_carry_throw_reference.png",
    "sister_sheep": "ACTION_sister_sheep_v2_carry_throw_reference.png",
    "younger_brother": "ACTION_younger_brother_v2_carry_throw_reference.png",
}
ACTION_V2_COLUMNS = 3
FX_SPECS = {
    # 名稱: (格, 目標寬)
    "fx_teleport": ((0, 0), 64),
    "fx_hit_sparkle": ((2, 0), 32),
    "fx_poof": ((1, 1), 40),
    "fx_victory": ((2, 1), 72),
}


def is_valid_png(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return handle.read(8) == b"\x89PNG\r\n\x1a\n"
    except OSError:
        return False


def grid_cells_n(src: Image.Image, columns: int, rows: int, min_area: int = 24) -> dict[tuple[int, int], tuple[int, int, int, int]]:
    """把所有 alpha 元件依中心落點歸入 columns×rows 均分格，取每格聯集邊界。"""
    width, height = src.size
    cell_w, cell_h = width / columns, height / rows
    cells: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for box in find_components(src, thr=40, min_area=min_area, step=2):
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        key = (min(columns - 1, int(cx // cell_w)), min(rows - 1, int(cy // cell_h)))
        cells[key] = union_box(cells[key], box) if key in cells else box
    missing = [(c, r) for r in range(rows) for c in range(columns) if (c, r) not in cells]
    assert not missing, f"參考圖缺少格子：{missing}"
    return cells


def fit_sprite(sprite: Image.Image, cell_w: int, cell_h: int, height: int | None = None, scale: float | None = None, bottom_margin: int = 2) -> Image.Image:
    """把精靈縮放後置中放進格子，腳底貼齊 cell_h - bottom_margin。"""
    if scale is None:
        scale = min(height / sprite.height, cell_w / sprite.width)
    resized = sprite.resize((max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))), Image.LANCZOS)
    resized = crisp_alpha(resized)
    if resized.width > cell_w:
        cut = (resized.width - cell_w) // 2
        resized = resized.crop((cut, 0, cut + cell_w, resized.height))
    if resized.height > cell_h - bottom_margin:
        resized = resized.crop((0, resized.height - (cell_h - bottom_margin), resized.width, resized.height))
    cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    cell.paste(resized, ((cell_w - resized.width) // 2, cell_h - bottom_margin - resized.height), resized)
    return cell


# ---------------------------------------------------------------------------
# CC
# ---------------------------------------------------------------------------
def build_cc() -> None:
    OUT_PETS.mkdir(parents=True, exist_ok=True)
    build_character(INCOMING / "CC_pet_penguin_sheet_reference.png", OUT_PETS / "cc_penguin_sheet.png", max_height=PET_MAX_HEIGHT)


# ---------------------------------------------------------------------------
# 炸物魔王：去棋盤格 + 六幀
# ---------------------------------------------------------------------------
def key_out_checkerboard(im: Image.Image, min_gray: int = 224, tolerance: int = 6) -> Image.Image:
    """從四個邊緣泛洪：只把「連到邊緣的近白中性灰」變透明，雞身內部的白色（骨頭尖端）保留。"""
    w, h = im.size
    px = im.load()

    def is_checker(x: int, y: int) -> bool:
        r, g, b, _a = px[x, y]
        return r >= min_gray and abs(r - g) <= tolerance and abs(g - b) <= tolerance

    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y * w + x] or not is_checker(x, y):
            continue
        seen[y * w + x] = 1
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def build_boss() -> None:
    OUT_BOSS.mkdir(parents=True, exist_ok=True)
    src = key_out_checkerboard(Image.open(INCOMING / "BOSS_fried_food_demon_sheet_reference.png").convert("RGBA"))
    cells = grid_cells_n(src, 3, 2, min_area=200)
    order = [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)]  # 待機、走 A、走 B／預兆、攻擊、受擊、倒地
    max_h = max(cells[key][3] - cells[key][1] for key in order[:5])  # 倒地幀較矮，不參與縮放計算
    scale = BOSS_MAX_HEIGHT / max_h
    sheet = Image.new("RGBA", (BOSS_CELL * len(order), BOSS_CELL), (0, 0, 0, 0))
    for index, key in enumerate(order):
        sprite = src.crop(cells[key])
        sheet.paste(fit_sprite(sprite, BOSS_CELL, BOSS_CELL, scale=scale), (index * BOSS_CELL, 0))
    sheet.save(OUT_BOSS / "fried_food_demon_sheet.png")
    print("boss:", sheet.size, f"scale={scale:.3f}")


# ---------------------------------------------------------------------------
# 投擲物：每件 4 幀（地面、舉起、飛行、命中）
# ---------------------------------------------------------------------------
def build_items() -> None:
    OUT_ITEMS.mkdir(parents=True, exist_ok=True)
    src = Image.open(INCOMING / "ITEM_throwables_vegetable_tea_water_reference_v2.png").convert("RGBA")
    cells = grid_cells_n(src, 4, 3, min_area=60)
    for row, item_id in enumerate(ITEM_ROWS):
        sheet = Image.new("RGBA", (ITEM_CELL * len(ITEM_FRAMES), ITEM_CELL), (0, 0, 0, 0))
        for col, frame_name in enumerate(ITEM_FRAMES):
            sprite = src.crop(cells[(col, row)])
            height = ITEM_HIT_HEIGHT if frame_name == "hit" else ITEM_SPRITE_HEIGHT
            fitted = fit_sprite(sprite, ITEM_CELL, ITEM_CELL, height=height, bottom_margin=(ITEM_CELL - height) // 2)
            sheet.paste(fitted, (col * ITEM_CELL, 0))
        sheet.save(OUT_ITEMS / f"{item_id}.png")
        print("item:", item_id, sheet.size)


# ---------------------------------------------------------------------------
# 特效
# ---------------------------------------------------------------------------
def build_fx() -> None:
    OUT_EFFECTS.mkdir(parents=True, exist_ok=True)
    src = Image.open(INCOMING / "FX_cc_battle_reference.png").convert("RGBA")
    cells = grid_cells_n(src, 3, 2, min_area=60)
    for name, (key, width) in FX_SPECS.items():
        sprite = crisp_alpha(scale_to(src.crop(cells[key]), width=width), threshold=60)
        sprite.save(OUT_EFFECTS / f"{name}.png")
        print("fx:", name, sprite.size)
    # 炸雞翅：取「掉落雞翅」格中最大的單一元件
    wing_cell = src.crop(cells[(0, 1)])
    components = sorted(find_components(wing_cell, thr=40, min_area=60), key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
    wing = crisp_alpha(scale_to(wing_cell.crop(components[-1]), height=14))
    wing.save(OUT_EFFECTS / "fx_chicken_wing.png")
    print("fx: fx_chicken_wing", wing.size)


# ---------------------------------------------------------------------------
# 角色舉物／投擲幀
# ---------------------------------------------------------------------------
def idle_width(character_id: str) -> int:
    """已產出的行走表第 0 欄第 0 列（站立向下）的不透明寬度，用來讓行動幀與行走幀身形一致。"""
    sheet = Image.open(OUT_CHARS / f"{character_id}_sheet.png").convert("RGBA")
    box = sheet.crop((0, 0, CELL_W, CELL_H)).getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return box[2] - box[0]


def walk_v2_idle_height(character_id: str) -> int | None:
    """v2 行走表第 0 欄第 0 列（contact A，向下）的不透明高度；沒有 v2 表時回傳 None。"""
    path = OUT_CHARS / f"{character_id}_walk_v2_sheet.png"
    if not is_valid_png(path):
        return None
    sheet = Image.open(path).convert("RGBA")
    box = sheet.crop((0, 0, CELL_W, CELL_H)).getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return box[3] - box[1]


def build_action_sheet_v2(character_id: str, source: Path, output: Path) -> bool:
    """新造型行動表：去背（白底／棋盤格由邊緣泛洪；透明底不動）→ 4×3 分格 → 取第 0 欄舉物、第 1 欄投擲，
    依 v2 行走表站立幀高度縮放，腳底貼齊 y=61。回傳是否成功。"""
    target_height = walk_v2_idle_height(character_id)
    if target_height is None:
        return False
    src = key_out_checkerboard(Image.open(source).convert("RGBA"))
    cells = grid_cells_n(src, ACTION_V2_COLUMNS, 4, min_area=200)
    carry_ref = cells[(0, 0)]
    scale = target_height / (carry_ref[3] - carry_ref[1])
    # 只依高度縮放，讓身形與行走幀一致；投擲幀伸出去的手超過 48px 時由 fit_sprite 置中裁掉指尖，不把整個人縮小。
    scale = min(scale, (CELL_H - 2) / max(cells[(c, r)][3] - cells[(c, r)][1] for c in range(ACTION_V2_COLUMNS) for r in range(4)))
    sheet = Image.new("RGBA", (CELL_W * ACTION_COLUMNS, CELL_H * len(OUTPUT_ROWS)), (0, 0, 0, 0))
    for out_row in range(len(OUTPUT_ROWS)):
        for out_col in range(ACTION_COLUMNS):
            sprite = src.crop(cells[(out_col, out_row)])
            sheet.paste(fit_sprite(sprite, CELL_W, CELL_H, scale=scale), (out_col * CELL_W, out_row * CELL_H))
    sheet.save(output)
    print("action v2:", character_id, sheet.size, f"scale={scale:.3f}")
    return True


def build_action_sheets() -> None:
    for character_id, source_name in ACTION_SOURCES.items():
        source = INCOMING / source_name
        output = OUT_CHARS / f"{character_id}_action_sheet.png"
        v2_source = INCOMING / ACTION_V2_SOURCES.get(character_id, "")
        if is_valid_png(v2_source) and build_action_sheet_v2(character_id, v2_source, output):
            continue
        if not is_valid_png(source):
            print(f"action: {character_id} 參考檔損毀（非 PNG），略過；遊戲內以站立幀 + CarryAnchor 代替")
            if output.exists():
                output.unlink()
            continue
        src = Image.open(source).convert("RGBA")
        cells = grid_cells_n(src, 4, 4, min_area=60)
        carry_ref = cells[(0, 0)]
        scale = idle_width(character_id) / (carry_ref[2] - carry_ref[0])
        scale = min(scale, (CELL_H - 2) / max(cells[(0, r)][3] - cells[(0, r)][1] for r in range(4)))
        sheet = Image.new("RGBA", (CELL_W * ACTION_COLUMNS, CELL_H * len(OUTPUT_ROWS)), (0, 0, 0, 0))
        row_order = ACTION_ROW_ORDER[character_id]
        for out_row, direction in enumerate(OUTPUT_ROWS):
            ref_row = row_order.index(direction)
            for out_col, ref_col in enumerate((0, 2)):
                sprite = src.crop(cells[(ref_col, ref_row)])
                sheet.paste(fit_sprite(sprite, CELL_W, CELL_H, scale=scale), (out_col * CELL_W, out_row * CELL_H))
        sheet.save(output)
        print("action:", character_id, sheet.size, f"scale={scale:.3f}")


# ---------------------------------------------------------------------------
# 阿嬤（佔位）：老龜換色
# ---------------------------------------------------------------------------
def build_grandma_from_views(source: Path) -> None:
    """阿嬤參考圖不是行走表：四列內容相同，每列是「正面、側面、側面提籃、背面、正面微笑」五種視角。
    她是站立 NPC，只需要四個方向的站立幀；行走幀以兩種正面／側面交替填入（目前不會播放）。
    組成 5 欄 × 4 列（第 0～3 欄行走、第 4 欄站立；列序 down/left/right/up）再交給主角切割器。"""
    src = Image.open(source).convert("RGBA")
    cells = grid_cells_n(src, 5, 4, min_area=200)
    views = [src.crop(cells[(col, 0)]) for col in range(5)]
    front, side, side_basket, back, front_smile = views
    mirror = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    rows = [
        [front, front_smile, front, front_smile, front_smile],
        [mirror(side), mirror(side_basket), mirror(side), mirror(side_basket), mirror(side)],
        [side, side_basket, side, side_basket, side],
        [back, back, back, back, back],
    ]
    cell_w = max(im.width for im in views) + 16
    cell_h = max(im.height for im in views) + 16
    synthetic = Image.new("RGBA", (cell_w * 5, cell_h * 4), (0, 0, 0, 0))
    for row, images in enumerate(rows):
        for col, im in enumerate(images):
            synthetic.paste(im, (col * cell_w + (cell_w - im.width) // 2, row * cell_h + cell_h - 8 - im.height), im)
    build_character(synthetic, OUT_NPCS / "grandma_turtle_sheet.png")


def build_grandma_placeholder() -> None:
    source = INCOMING / "GRANDMA_turtle_breakfast_sheet_reference.png"
    if is_valid_png(source):
        build_grandma_from_views(source)
        print("grandma: 使用正式參考圖（五視角重組為四方向）")
        return
    turtle = Image.open(OUT_NPCS / "old_turtle_sheet.png").convert("RGBA")
    r, g, b, a = turtle.split()
    tinted = Image.merge("RGBA", (
        r.point(lambda v: min(255, int(v * 1.08 + 10))),
        g.point(lambda v: int(v * 0.92)),
        b.point(lambda v: int(v * 0.95 + 6)),
        a,
    ))
    # 頭巾：每格頭頂 6px 高的暖色格紋帶，讓她一眼能與市集老龜區分
    draw = ImageDraw.Draw(tinted)
    alpha = tinted.getchannel("A").load()
    for row in range(4):
        for col in range(5):
            x0, y0 = col * CELL_W, row * CELL_H
            cell_alpha = tinted.crop((x0, y0, x0 + CELL_W, y0 + CELL_H)).getchannel("A").getbbox()
            if cell_alpha is None:
                continue
            top = y0 + cell_alpha[1]
            for y in range(top, min(top + 7, y0 + CELL_H)):
                for x in range(x0, x0 + CELL_W):
                    if alpha[x, y] > 0:
                        checker = ((x // 3) + (y // 3)) % 2 == 0
                        draw.point((x, y), fill=(226, 96, 88, 255) if checker else (250, 232, 210, 255))
    tinted.save(OUT_NPCS / "grandma_turtle_sheet.png")
    print("grandma: 參考檔損毀，使用老龜換色 + 格紋頭巾佔位", tinted.size)


# ---------------------------------------------------------------------------
# 早餐攤與 UI 小圖
# ---------------------------------------------------------------------------
def build_breakfast_stall() -> Image.Image:
    """阿嬤早餐攤：木桌、兩碗麵、竹籃、冒煙。48×44，底部中央為原點。"""
    w, h = 56, 44
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((4, 18, w - 5, 26), fill=(150, 98, 46, 255), outline=(70, 40, 16, 255))
    d.rectangle((6, 26, 9, h - 1), fill=(96, 62, 30, 255))
    d.rectangle((w - 10, 26, w - 7, h - 1), fill=(96, 62, 30, 255))
    d.rectangle((4, 26, w - 5, 29), fill=(110, 70, 32, 255))
    for cx in (14, 28):
        d.ellipse((cx - 6, 10, cx + 6, 19), fill=(240, 236, 220, 255), outline=(120, 100, 80, 255))
        d.ellipse((cx - 4, 11, cx + 4, 15), fill=(214, 172, 96, 255))
        for i in range(3):
            d.line((cx - 3 + i * 3, 4 - (i % 2) * 2, cx - 3 + i * 3, 9), fill=(255, 255, 255, 140))
    d.rounded_rectangle((36, 8, 50, 19), radius=3, fill=(196, 150, 78, 255), outline=(110, 70, 32, 255))
    for x in range(38, 49, 3):
        d.line((x, 9, x, 18), fill=(150, 108, 50, 255))
    d.rectangle((38, 5, 48, 9), fill=(96, 168, 76, 255))
    d.rectangle((40, 3, 46, 5), fill=(120, 190, 90, 255))
    return im


def build_noodle_icon() -> Image.Image:
    """香椿乾拌麵：碗 + 麵 + 綠色香椿末。16×16。"""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((1, 6, 14, 15), fill=(236, 228, 208, 255), outline=(120, 96, 70, 255))
    d.ellipse((2, 5, 13, 10), fill=(222, 178, 96, 255), outline=(160, 120, 60, 255))
    for x, y in ((4, 6), (7, 5), (10, 6), (6, 8), (9, 8)):
        d.point((x, y), fill=(70, 140, 60, 255))
    return im


def build_anger_mark() -> Image.Image:
    """💢 怒氣記號 14×14：四段紅色弧線組成的十字紋。"""
    im = Image.new("RGBA", (14, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    red = (222, 40, 40, 255)
    for x0, y0 in ((1, 1), (7, 1), (1, 7), (7, 7)):
        d.arc((x0, y0, x0 + 5, y0 + 5), start=0, end=270, fill=red, width=2)
    d.rectangle((6, 6, 7, 7), fill=(0, 0, 0, 0))
    return im


def build_heart(filled: bool) -> Image.Image:
    im = Image.new("RGBA", (9, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    color = (226, 60, 70, 255) if filled else (70, 40, 40, 255)
    d.ellipse((0, 0, 4, 4), fill=color)
    d.ellipse((4, 0, 8, 4), fill=color)
    d.polygon([(0, 3), (8, 3), (4, 7)], fill=color)
    if filled:
        d.point((2, 1), fill=(255, 170, 180, 255))
    return im


def build_props_and_ui() -> None:
    build_breakfast_stall().save(OUT_PROPS / "breakfast_stall.png")
    build_noodle_icon().save(OUT_UI / "item_noodles.png")
    build_anger_mark().save(OUT_UI / "anger_mark.png")
    build_heart(True).save(OUT_UI / "heart_full.png")
    build_heart(False).save(OUT_UI / "heart_empty.png")
    print("props/ui: breakfast_stall, item_noodles, anger_mark, heart_full, heart_empty")


# ---------------------------------------------------------------------------
# 洞窟 tile（tileset 第 5 列）
# ---------------------------------------------------------------------------
def cave_floor(seed: int, spots: int) -> Image.Image:
    tile = noise_tile((92, 62, 42), 7, seed)
    d = ImageDraw.Draw(tile)
    rng = random.Random(seed + 100)
    for _ in range(spots):
        x, y = rng.randint(2, TILE - 6), rng.randint(2, TILE - 6)
        d.ellipse((x, y, x + rng.randint(2, 4), y + rng.randint(1, 3)), fill=(150, 104, 40, 255))
    for _ in range(6):
        x, y = rng.randint(0, TILE - 2), rng.randint(0, TILE - 2)
        d.point((x, y), fill=(64, 42, 28, 255))
    return tile


def cave_wall(seed: int, lit_top: bool) -> Image.Image:
    tile = noise_tile((48, 36, 34), 6, seed)
    d = ImageDraw.Draw(tile)
    rng = random.Random(seed + 7)
    for _ in range(9):
        x, y = rng.randint(0, TILE - 8), rng.randint(0, TILE - 6)
        d.rectangle((x, y, x + rng.randint(4, 8), y + rng.randint(3, 5)), outline=(30, 22, 22, 255))
    if lit_top:
        d.rectangle((0, 0, TILE - 1, 2), fill=(118, 80, 52, 255))
        d.rectangle((0, 3, TILE - 1, 4), fill=(84, 58, 40, 255))
    return tile


CAVE_TILE_PACK = ROOT / "assets" / "tiles" / "fried_food_cave_tiles_32.png"


def seamless_floor(tile: Image.Image) -> Image.Image:
    """把地面 tile 最右一欄換成第 30 欄（純複製，不重新取樣），消除平鋪時的直向暗線。"""
    fixed = tile.copy()
    fixed.paste(tile.crop((TILE - 2, 0, TILE - 1, TILE)), (TILE - 1, 0))
    return fixed


def build_cave_tiles() -> None:
    """洞窟 tile：Phase 4.6 正式 4×2 tile 組（128×64）依序複製到 atlas 第 5 列第 0～7 欄：
    地面 A、地面 B、岩壁面、岩壁頂、左上角、右上角、內凹角、晶簇 overlay。
    tile 組不存在或不合法時退回程式合成的 4 格（Phase 4 舊行為），欄位對應仍與 TileLibrary 一致。"""
    old = Image.open(OUT_TILES / "tide_root_town_tileset.png").convert("RGBA")
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE, ATLAS_ROWS * TILE), (0, 0, 0, 0))
    atlas.paste(old.crop((0, 0, ATLAS_COLUMNS * TILE, min(old.height, ATLAS_ROWS * TILE))), (0, 0))
    if is_valid_png(CAVE_TILE_PACK):
        pack = Image.open(CAVE_TILE_PACK).convert("RGBA")
        if pack.size != (4 * TILE, 2 * TILE):
            raise SystemExit(f"洞窟 tile 組尺寸應為 128×64，實際 {pack.size}")
        tiles = [pack.crop((c * TILE, r * TILE, (c + 1) * TILE, (r + 1) * TILE)) for r in range(2) for c in range(4)]
        # 兩款地面的最右一欄比其他欄暗約 15 階，平鋪時會形成整齊的直向接縫；改以第 30 欄複製過去補平。
        for index in (0, 1):
            tiles[index] = seamless_floor(tiles[index])
        source = "正式 tile 組"
    else:
        print("提示：找不到正式洞窟 tile 組，改用程式合成")
        tiles = [
            cave_floor(41, 3),          # 0 地面 A
            cave_floor(43, 8),          # 1 地面 B（油漬較多）
            cave_wall(44, True),        # 2 岩壁面（上緣受光）
            cave_wall(42, False),       # 3 岩壁頂
            cave_wall(42, False),       # 4 左上角（合成版沒有轉角，沿用岩壁）
            cave_wall(42, False),       # 5 右上角
            cave_wall(42, False),       # 6 內凹角
            Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0)),  # 7 晶簇 overlay（空）
        ]
        source = "程式合成"
    for col, tile in enumerate(tiles):
        atlas.paste(tile, (col * TILE, CAVE_ROW * TILE))
    atlas.save(OUT_TILES / "tide_root_town_tileset.png")
    print("tileset:", atlas.size, f"洞窟 tile {len(tiles)} 格（第 {CAVE_ROW} 列，{source}）")


def main() -> None:
    build_cc()
    build_boss()
    build_items()
    build_fx()
    build_action_sheets()
    build_grandma_placeholder()
    build_props_and_ui()
    build_cave_tiles()


if __name__ == "__main__":
    main()
