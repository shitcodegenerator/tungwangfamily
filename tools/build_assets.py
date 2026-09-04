#!/usr/bin/env python3
"""Phase 1 素材產生器。

把 AI 生成的參考圖（assets/reference/*.png）切成規格化的遊戲素材：

- 角色 Sprite Sheet：192×256，48×64 單格，4 方向 × 4 幀（列＝方向 down/left/right/up）
- 主城 Tileset：32×32 atlas（第 0 列地形、第 1 列裝飾、第 2 列合成 tile）
- 道具：房屋、燈、木箱、路牌、柵欄、雲、樹心、公告欄等

只依賴 Pillow。執行：python3 tools/build_assets.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT / "assets" / "reference"
OUT_CHARS = ROOT / "assets" / "characters" / "playable"
OUT_TILES = ROOT / "assets" / "tilesets"
OUT_PROPS = ROOT / "assets" / "props"

TILE = 32
CELL_W, CELL_H = 48, 64
FRAMES = 4
DIRECTIONS = ["down", "left", "right", "up"]


# ---------------------------------------------------------------------------
# 共用：透明區域切割
# ---------------------------------------------------------------------------
def find_components(im: Image.Image, thr: int = 40, min_area: int = 400, step: int = 2) -> list[tuple[int, int, int, int]]:
    """以 alpha 連通區域找出每個獨立圖塊的邊界框（回傳 (x0, y0, x1, y1)）。"""
    w, h = im.size
    alpha = im.getchannel("A").load()
    gw, gh = w // step, h // step
    mask = [[alpha[x * step, y * step] > thr for x in range(gw)] for y in range(gh)]
    seen = [[False] * gw for _ in range(gh)]
    boxes: list[tuple[int, int, int, int]] = []
    for y in range(gh):
        for x in range(gw):
            if not mask[y][x] or seen[y][x]:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            minx = maxx = x
            miny = maxy = y
            count = 0
            while stack:
                cx, cy = stack.pop()
                count += 1
                minx, maxx = min(minx, cx), max(maxx, cx)
                miny, maxy = min(miny, cy), max(maxy, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < gw and 0 <= ny < gh and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if count * step * step >= min_area:
                boxes.append((minx * step, miny * step, (maxx + 1) * step, (maxy + 1) * step))
    # 依「列」再依 x 排序，列高以 120px 分群
    boxes.sort(key=lambda b: (b[1] // 120, b[0]))
    return boxes


def crisp_alpha(im: Image.Image, threshold: int = 110) -> Image.Image:
    """把縮放後的半透明邊緣二值化，維持像素風的乾淨外框。"""
    out = im.copy()
    out.putalpha(out.getchannel("A").point(lambda v: 255 if v > threshold else 0))
    return out


def scale_to(im: Image.Image, width: int | None = None, height: int | None = None) -> Image.Image:
    w, h = im.size
    if width is not None and height is None:
        s = width / w
    elif height is not None and width is None:
        s = height / h
    else:
        s = min(width / w, height / h)
    return im.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)


# ---------------------------------------------------------------------------
# 角色
# ---------------------------------------------------------------------------
CHARACTER_FILES = [
    "big_brother_sheet.png",      # 哥哥：紅鬃山犬
    "calm_brother_sheet.png",     # 冷靜哥：灰藍貓頭鷹
    "sister_sheep_sheet.png",     # 妹妹：綿羊
    "younger_brother_sheet.png",  # 弟弟：溪水猴
]


def make_walk_frames(base: Image.Image) -> list[Image.Image]:
    """由單一站立幀合成 4 幀行走動畫。

    幀 0/2：原圖；幀 1/3：整體上移 1px，並將腳部區域左右錯位 1px，
    形成簡單但可辨識的步伐。角色腳底基準線不變（維持在 y=62）。
    """
    w, h = base.size
    frames: list[Image.Image] = []
    leg_h = max(6, h // 5)
    for i in range(FRAMES):
        if i % 2 == 0:
            frames.append(base.copy())
            continue
        shift = 1 if i == 1 else -1
        frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        body = base.crop((0, 0, w, h - leg_h))
        legs = base.crop((0, h - leg_h, w, h))
        frame.paste(body, (0, -1), body)
        frame.paste(legs, (shift, h - leg_h - 1), legs)
        frames.append(frame)
    return frames


def build_characters() -> None:
    src = Image.open(REF / "phase1_playable_sprite_reference.png").convert("RGBA")
    boxes = find_components(src)
    assert len(boxes) == 16, f"角色參考圖應切出 16 個精靈，實際 {len(boxes)}"
    for row, filename in enumerate(CHARACTER_FILES):
        row_boxes = boxes[row * 4:(row + 1) * 4]
        max_w = max(b[2] - b[0] for b in row_boxes)
        max_h = max(b[3] - b[1] for b in row_boxes)
        # 同一角色四個方向使用同一縮放比例，允許少量超寬後裁掉指尖
        scale = min((CELL_H - 6) / max_h, (CELL_W / max_w) * 1.25)
        sheet = Image.new("RGBA", (CELL_W * FRAMES, CELL_H * len(DIRECTIONS)), (0, 0, 0, 0))
        for d, box in enumerate(row_boxes):
            sprite = src.crop(box)
            sprite = sprite.resize((max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))), Image.LANCZOS)
            sprite = crisp_alpha(sprite)
            if sprite.width > CELL_W:
                cut = (sprite.width - CELL_W) // 2
                sprite = sprite.crop((cut, 0, cut + CELL_W, sprite.height))
            cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
            cell.paste(sprite, ((CELL_W - sprite.width) // 2, CELL_H - 2 - sprite.height), sprite)
            for f, frame in enumerate(make_walk_frames(cell)):
                sheet.paste(frame, (f * CELL_W, d * CELL_H))
        sheet.save(OUT_CHARS / filename)
        print("character:", filename, sheet.size)


# ---------------------------------------------------------------------------
# Tileset
# ---------------------------------------------------------------------------
# 參考圖元件索引（由 find_components 的排序決定）
TERRAIN_INDEX = list(range(0, 18))       # 第 0 列：地形 18 格
DECOR_INDEX = [26, 27, 28, 29, 30, 31, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 58]
ATLAS_COLS = 18
ATLAS_ROWS = 3


def texture_tile(src: Image.Image, box: tuple[int, int, int, int], inset: int = 6) -> Image.Image:
    x0, y0, x1, y1 = box
    return src.crop((x0 + inset, y0 + inset, x1 - inset, y1 - inset)).resize((TILE, TILE), Image.LANCZOS).convert("RGBA")


def decor_tile(src: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    sprite = crisp_alpha(scale_to(src.crop(box), width=30, height=30))
    cell = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    cell.paste(sprite, ((TILE - sprite.width) // 2, TILE - 1 - sprite.height), sprite)
    return cell


def noise_tile(base: tuple[int, int, int], amount: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    im = Image.new("RGBA", (TILE, TILE))
    px = im.load()
    for y in range(TILE):
        for x in range(TILE):
            n = rng.randint(-amount, amount)
            px[x, y] = (max(0, min(255, base[0] + n)), max(0, min(255, base[1] + n)), max(0, min(255, base[2] + n)), 255)
    return im


def stairs_tile(planks: Image.Image) -> Image.Image:
    im = planks.copy()
    d = ImageDraw.Draw(im)
    for i in range(4):
        y = i * 8
        d.rectangle((0, y, TILE - 1, y + 1), fill=(120, 78, 40, 255))
        d.rectangle((0, y + 6, TILE - 1, y + 7), fill=(58, 34, 16, 255))
    return im


def rail_tile(planks: Image.Image, rail: Image.Image, top: bool) -> Image.Image:
    im = planks.copy()
    strip = crisp_alpha(scale_to(rail, width=TILE))
    strip = strip.crop((0, 0, TILE, min(strip.height, 14)))
    y = 0 if top else TILE - strip.height
    im.paste(strip, (0, y), strip)
    return im


def darken(im: Image.Image, factor: float) -> Image.Image:
    r, g, b, a = im.split()
    r = r.point(lambda v: int(v * factor))
    g = g.point(lambda v: int(v * factor))
    b = b.point(lambda v: int(v * factor))
    return Image.merge("RGBA", (r, g, b, a))


def build_tileset(src: Image.Image, boxes: list[tuple[int, int, int, int]]) -> dict[str, Image.Image]:
    atlas = Image.new("RGBA", (ATLAS_COLS * TILE, ATLAS_ROWS * TILE), (0, 0, 0, 0))
    named: dict[str, Image.Image] = {}
    for col, idx in enumerate(TERRAIN_INDEX):
        tile = texture_tile(src, boxes[idx])
        atlas.paste(tile, (col * TILE, 0))
        named[f"terrain_{col}"] = tile
    for col, idx in enumerate(DECOR_INDEX):
        atlas.paste(decor_tile(src, boxes[idx]), (col * TILE, TILE))

    planks = named["terrain_7"]
    bark = named["terrain_4"]
    rail = src.crop(boxes[25])
    cloud = src.crop(boxes[42])
    void = noise_tile((26, 34, 46), 5, 1)
    mist = void.copy()
    cloud_cut = cloud.crop((60, 20, 200, 90)).resize((TILE, TILE), Image.LANCZOS)
    mist.alpha_composite(cloud_cut)
    synthesized = [
        void,                              # (0,2) 虛空
        mist,                              # (1,2) 雲霧
        stairs_tile(planks),               # (2,2) 樓梯
        rail_tile(planks, rail, True),     # (3,2) 橋：上緣欄杆
        rail_tile(planks, rail, False),    # (4,2) 橋：下緣欄杆
        darken(bark, 0.55),                # (5,2) 深色樹皮（上層外牆）
        darken(planks, 0.8),               # (6,2) 深色木板（樹枝道路邊）
    ]
    for col, tile in enumerate(synthesized):
        atlas.paste(tile, (col * TILE, 2 * TILE))
    atlas.save(OUT_TILES / "tide_root_town_tileset.png")
    print("tileset:", atlas.size)
    return named


# ---------------------------------------------------------------------------
# 道具
# ---------------------------------------------------------------------------
PROP_SPECS = {
    # 名稱: (元件索引, 目標寬, 目標高)
    "house_tree_door": (36, None, 96),
    "house_window_lantern": (37, None, 96),
    "house_banner": (38, None, 96),
    "house_balcony": (39, None, 96),
    "house_tree_window": (40, None, 96),
    "house_narrow": (41, None, 96),
    "lamp_post": (33, None, 48),
    "crate": (34, None, 32),
    "signpost": (35, None, 32),
    "fence": (25, 64, None),
    "cloud_big": (42, 124, None),
    "cloud_small": (43, 88, None),
    "cloud_long": (44, 128, None),
    "cloud_swirl": (45, 68, None),
    "ladder_rope": (20, None, 40),
    "ladder_wood": (21, None, 42),
    "tree_platform": (24, 104, None),
    "tree_spiral": (23, 96, None),
    "grass_stairs": (22, 104, None),
    "dock": (18, None, 66),
    "dock_small": (19, None, 66),
    "lily_pond": (57, 52, None),
    "vine_branch": (32, None, 40),
    "rock_moss": (46, 40, None),
}


def build_props(src: Image.Image, boxes: list[tuple[int, int, int, int]], named: dict[str, Image.Image]) -> None:
    for name, (idx, w, h) in PROP_SPECS.items():
        sprite = crisp_alpha(scale_to(src.crop(boxes[idx]), width=w, height=h))
        sprite.save(OUT_PROPS / f"{name}.png")
        print("prop:", name, sprite.size)
    build_tree_heart(named["terrain_4"]).save(OUT_PROPS / "tree_heart.png")
    build_bulletin_board().save(OUT_PROPS / "bulletin_board.png")
    build_gate().save(OUT_PROPS / "canopy_gate.png")
    build_flag().save(OUT_PROPS / "flag_banner.png")
    print("prop: tree_heart, bulletin_board, canopy_gate, flag_banner")


def build_flag() -> Image.Image:
    """廣場旗幟：木桿加藍綠色三角旗，桿頂一顆金色小球。"""
    w, h = 20, 48
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((4, 4, 6, h - 1), fill=(96, 62, 30, 255))
    d.rectangle((3, 2, 7, 4), fill=(230, 190, 80, 255))
    d.polygon([(7, 5), (19, 10), (7, 20)], fill=(40, 140, 140, 255))
    d.polygon([(7, 8), (14, 10), (7, 16)], fill=(70, 180, 170, 255))
    d.line((7, 5, 7, 20), fill=(20, 90, 90, 255))
    return im


def build_tree_heart(bark: Image.Image) -> Image.Image:
    """巨大樹心：以樹皮貼圖鋪成的粗大樹幹，中央嵌著發光的琥珀色樹心。"""
    w, h = 160, 128
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    trunk = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(0, h, TILE):
        for x in range(0, w, TILE):
            trunk.paste(bark, (x, y))
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 12, w - 1, h - 1), radius=40, fill=255)
    md.polygon([(20, 14), (w - 20, 14), (w - 4, 40), (4, 40)], fill=255)
    im.paste(trunk, (0, 0), mask)
    d = ImageDraw.Draw(im)
    cx, cy = w // 2, 70
    for r, color in ((40, (255, 190, 90, 60)), (32, (255, 200, 110, 120)), (24, (255, 220, 140, 220)), (14, (255, 245, 200, 255))):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)
    for r in (34, 26, 18):
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(140, 80, 30, 200))
    rng = random.Random(7)
    for _ in range(18):
        x = rng.randint(6, w - 6)
        y = rng.randint(16, 30)
        d.rectangle((x, y, x + 3, y + 3), fill=(96, 160, 60, 255))
    return im


def build_bulletin_board() -> Image.Image:
    w, h = 48, 44
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((6, 8, 9, h - 1), fill=(84, 52, 24, 255))
    d.rectangle((w - 10, 8, w - 7, h - 1), fill=(84, 52, 24, 255))
    d.rectangle((2, 4, w - 3, 30), fill=(122, 80, 40, 255), outline=(60, 36, 16, 255))
    d.rectangle((6, 8, 18, 22), fill=(240, 228, 190, 255))
    d.rectangle((22, 10, 34, 24), fill=(236, 220, 180, 255))
    d.rectangle((36, 8, 44, 18), fill=(244, 232, 200, 255))
    for x0, y0 in ((8, 12), (24, 14), (38, 11)):
        d.line((x0, y0, x0 + 6, y0), fill=(120, 100, 80, 255))
        d.line((x0, y0 + 3, x0 + 8, y0 + 3), fill=(120, 100, 80, 255))
    d.rectangle((0, 2, w - 1, 5), fill=(60, 36, 16, 255))
    return im


def build_gate() -> Image.Image:
    """雲端樹冠入口的封鎖門：藤蔓纏繞的木柵。"""
    w, h = 128, 48
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for x in range(4, w, 20):
        d.rectangle((x, 6, x + 5, h - 1), fill=(96, 62, 30, 255), outline=(50, 30, 12, 255))
    d.rectangle((0, 14, w - 1, 19), fill=(120, 78, 40, 255), outline=(50, 30, 12, 255))
    d.rectangle((0, 32, w - 1, 37), fill=(120, 78, 40, 255), outline=(50, 30, 12, 255))
    rng = random.Random(3)
    for _ in range(40):
        x = rng.randint(0, w - 4)
        y = rng.randint(4, h - 6)
        d.rectangle((x, y, x + 2, y + 2), fill=(70, 140, 60, 255))
    return im


def main() -> None:
    OUT_CHARS.mkdir(parents=True, exist_ok=True)
    OUT_TILES.mkdir(parents=True, exist_ok=True)
    OUT_PROPS.mkdir(parents=True, exist_ok=True)
    build_characters()
    src = Image.open(REF / "phase1_tide_root_tileset_reference.png").convert("RGBA")
    boxes = find_components(src)
    assert len(boxes) == 59, f"tileset 參考圖應切出 59 個元件，實際 {len(boxes)}"
    named = build_tileset(src, boxes)
    build_props(src, boxes, named)
    # Phase 2：以 incoming/ 的正式素材覆蓋角色精靈表與主要道具，並產生動畫幀、補充 tile 與 UI 貼圖
    import build_assets_phase2

    build_assets_phase2.main()


if __name__ == "__main__":
    main()
