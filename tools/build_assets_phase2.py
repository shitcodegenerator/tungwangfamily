#!/usr/bin/env python3
"""Phase 2 素材產生器：整理 assets/reference/incoming/ 的 A 級補件，並產生動畫幀與 UI 貼圖。

- A1～A4：四位主角行走表 → 240×256 精靈表（48×64 單格；第 0 欄站立、第 1～4 欄行走；列序 down/left/right/up）
- A5～A10：樹心、公告欄、樹冠門、旗幟（4 幀擺動）、船港泊位、柵欄
- A11～A19：補充 tileset 合成參考表 → 擷取可驗證的格子（虛空 ×9、雲霧、深色樹皮、樓梯、草地變體）
- 動畫幀：燈籠 4 幀閃爍、淺水／深水 4 幀循環（寫入 tileset 第 3 列）
- UI：對話框九宮格、互動提示圖示、燈光光暈、粒子貼圖

只依賴 Pillow。由 build_assets.py 在 Phase 1 素材產生後自動呼叫，也可單獨執行：
    python3 tools/build_assets_phase2.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from build_assets import (
    CELL_H,
    CELL_W,
    OUT_CHARS,
    OUT_PROPS,
    OUT_TILES,
    ROOT,
    TILE,
    crisp_alpha,
    darken,
    find_components,
    scale_to,
)

INCOMING = ROOT / "assets" / "reference" / "incoming"
OUT_UI = ROOT / "assets" / "ui"
OUT_EFFECTS = ROOT / "assets" / "effects"

SHEET_COLUMNS = 5  # 第 0 欄站立，第 1～4 欄行走
REF_COLUMNS, REF_ROWS = 5, 4  # 參考圖：每列 4 個行走幀 + 1 個站立幀
ATLAS_COLUMNS = 18
ATLAS_ROWS = 5  # 第 0～2 列沿用 Phase 1；第 3 列水面動畫；第 4 列補充 tile
WATER_FRAMES = 4

CHARACTER_SOURCES = {
    "big_brother_sheet.png": "A1_big_brother_sheet.png",
    "calm_brother_sheet.png": "A2_calm_brother_sheet.png",
    "sister_sheep_sheet.png": "A3_sister_sheep_sheet.png",
    "younger_brother_sheet.png": "A4_younger_brother_sheet.png",
}


# ---------------------------------------------------------------------------
# 共用
# ---------------------------------------------------------------------------
def union_box(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def content_box(im: Image.Image, thr: int = 40) -> tuple[int, int, int, int]:
    """整張圖的不透明內容邊界。"""
    alpha = im.getchannel("A").point(lambda v: 255 if v > thr else 0)
    box = alpha.getbbox()
    if box is None:
        raise ValueError("圖片沒有任何不透明內容")
    return box


def box_containing(boxes: list[tuple[int, int, int, int]], x: int, y: int) -> tuple[int, int, int, int]:
    for box in boxes:
        if box[0] <= x < box[2] and box[1] <= y < box[3]:
            return box
    raise LookupError(f"找不到包含 ({x}, {y}) 的元件")


def brighten(im: Image.Image, factor: float, mask: Image.Image) -> Image.Image:
    """只對 mask 為白的像素乘上亮度係數。"""
    r, g, b, a = im.split()
    scaled = Image.merge(
        "RGBA",
        (
            r.point(lambda v: min(255, int(v * factor))),
            g.point(lambda v: min(255, int(v * factor))),
            b.point(lambda v: min(255, int(v * factor))),
            a,
        ),
    )
    out = im.copy()
    out.paste(scaled, (0, 0), mask)
    return out


def sheet_from_frames(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    sheet = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.paste(frame, (index * w, 0))
    return sheet


# ---------------------------------------------------------------------------
# 角色：5 欄 × 4 列參考圖 → 240×256 精靈表
# ---------------------------------------------------------------------------
def grid_cells(src: Image.Image) -> dict[tuple[int, int], tuple[int, int, int, int]]:
    """把所有 alpha 元件依中心落點歸入 5×4 格，並取每格的聯集邊界（水滴等分離小件也會併入）。"""
    width, height = src.size
    cell_w, cell_h = width / REF_COLUMNS, height / REF_ROWS
    cells: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for box in find_components(src, thr=40, min_area=24, step=2):
        cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        key = (min(REF_COLUMNS - 1, int(cx // cell_w)), min(REF_ROWS - 1, int(cy // cell_h)))
        cells[key] = union_box(cells[key], box) if key in cells else box
    missing = [(c, r) for r in range(REF_ROWS) for c in range(REF_COLUMNS) if (c, r) not in cells]
    assert not missing, f"角色參考圖缺少格子：{missing}"
    return cells


def build_character(source: Path | Image.Image, output: Path, max_height: int = CELL_H - 6) -> None:
    """max_height：精靈在 48×64 格內的最大高度（主角 58；寵物等小型角色可傳較小值）。source 可直接傳 Image。"""
    src = (source if isinstance(source, Image.Image) else Image.open(source)).convert("RGBA")
    width, height = src.size
    cell_w, cell_h = width / REF_COLUMNS, height / REF_ROWS
    cells = grid_cells(src)
    max_w = max(b[2] - b[0] for b in cells.values())
    max_h = max(b[3] - b[1] for b in cells.values())
    # 同一角色 20 個幀共用同一縮放比例；允許少量超寬（跨步幀）後裁掉邊緣
    scale = min(max_height / max_h, (CELL_W / max_w) * 1.25)
    sheet = Image.new("RGBA", (CELL_W * SHEET_COLUMNS, CELL_H * REF_ROWS), (0, 0, 0, 0))
    for row in range(REF_ROWS):
        # 精靈表欄序：第 0 欄＝參考圖第 4 欄（站立），第 1～4 欄＝參考圖第 0～3 欄（行走）
        for sheet_col, ref_col in enumerate([4, 0, 1, 2, 3]):
            box = cells[(ref_col, row)]
            sprite = src.crop(box)
            sprite = sprite.resize((max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))), Image.LANCZOS)
            sprite = crisp_alpha(sprite)
            # 以參考圖格子的水平中心為錨點，保留畫師安排的前後位移，避免逐幀重新置中造成抖動
            box_cx = (box[0] + box[2]) / 2
            cell_cx = (ref_col + 0.5) * cell_w
            x = round(CELL_W / 2 + (box_cx - cell_cx) * scale - sprite.width / 2)
            y = CELL_H - 2 - sprite.height
            cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
            cell.paste(sprite, (x, y), sprite)
            sheet.paste(cell, (sheet_col * CELL_W, row * CELL_H))
    sheet.save(output)
    print("character:", output.name, sheet.size, f"scale={scale:.3f}")


def build_characters() -> None:
    for output_name, source_name in CHARACTER_SOURCES.items():
        build_character(INCOMING / source_name, OUT_CHARS / output_name)


# ---------------------------------------------------------------------------
# 道具 A5～A10
# ---------------------------------------------------------------------------
def load_cropped(name: str) -> Image.Image:
    src = Image.open(INCOMING / name).convert("RGBA")
    return src.crop(content_box(src))


def build_flag_frames(flag: Image.Image) -> list[Image.Image]:
    """旗幟擺動：旗桿右側的旗面逐列做 ±1px 的正弦位移，4 幀循環。"""
    w, h = flag.size
    alpha = flag.getchannel("A").load()
    # 旗桿：下半部不透明像素最多的欄
    column_counts = [sum(1 for y in range(h // 2, h) if alpha[x, y] > 0) for x in range(w)]
    pole_x = max(range(w), key=column_counts.__getitem__)
    frames: list[Image.Image] = []
    for index in range(4):
        frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        pole = flag.crop((0, 0, pole_x + 2, h))
        frame.paste(pole, (0, 0), pole)
        for y in range(h):
            strip = flag.crop((pole_x + 2, y, w, y + 1))
            shift = round(math.sin(index * math.pi / 2 + y * 0.35))
            frame.paste(strip, (pole_x + 2 + shift, y), strip)
        frames.append(frame)
    return frames


def build_lamp_frames(lamp: Image.Image) -> list[Image.Image]:
    """燈籠閃爍：只調整暖色高亮像素（燈火）的亮度，4 幀。"""
    pixels = lamp.load()
    w, h = lamp.size
    mask = Image.new("L", (w, h), 0)
    mask_px = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a > 0 and r > 190 and g > 140 and b < 150:
                mask_px[x, y] = 255
    return [brighten(lamp, factor, mask) for factor in (1.0, 0.8, 1.15, 0.9)]


def build_props() -> None:
    tree_heart = crisp_alpha(scale_to(load_cropped("A5_tree_heart.png"), width=176))
    tree_heart.save(OUT_PROPS / "tree_heart.png")
    bulletin = crisp_alpha(scale_to(load_cropped("A6_bulletin_board.png"), width=52))
    bulletin.save(OUT_PROPS / "bulletin_board.png")
    gate = crisp_alpha(scale_to(load_cropped("A7_canopy_gate.png"), height=63))
    gate.save(OUT_PROPS / "canopy_gate.png")
    flag = crisp_alpha(scale_to(load_cropped("A8_flag_banner.png"), height=48))
    sheet_from_frames(build_flag_frames(flag)).save(OUT_PROPS / "flag_banner.png")
    berth = crisp_alpha(scale_to(load_cropped("A9_empty_harbor_berth.png"), width=128))
    berth.save(OUT_PROPS / "harbor_berth.png")

    fence_src = Image.open(INCOMING / "A10_fence.png").convert("RGBA")
    fence_boxes = sorted(find_components(fence_src, min_area=2000), key=lambda b: b[0])
    assert len(fence_boxes) == 2, f"A10 應切出柵欄與單根木樁 2 件，實際 {len(fence_boxes)}"
    crisp_alpha(scale_to(fence_src.crop(fence_boxes[0]), width=64)).save(OUT_PROPS / "fence.png")
    crisp_alpha(scale_to(fence_src.crop(fence_boxes[1]), height=40)).save(OUT_PROPS / "fence_post.png")

    lamp = Image.open(OUT_PROPS / "lamp_post.png").convert("RGBA")
    if lamp.width > lamp.height:  # 已經是 4 幀表：取第一幀重建
        lamp = lamp.crop((0, 0, lamp.width // 4, lamp.height))
    sheet_from_frames(build_lamp_frames(lamp)).save(OUT_PROPS / "lamp_post.png")
    for name in ("tree_heart", "bulletin_board", "canopy_gate", "flag_banner", "harbor_berth", "fence", "fence_post", "lamp_post"):
        print("prop:", name, Image.open(OUT_PROPS / f"{name}.png").size)


# ---------------------------------------------------------------------------
# Tileset：第 3 列水面動畫、第 4 列補充 tile
# ---------------------------------------------------------------------------
def water_frames(base: Image.Image) -> list[Image.Image]:
    """水面循環：一道斜向亮紋隨幀數往下流動。"""
    frames: list[Image.Image] = []
    for index in range(WATER_FRAMES):
        frame = base.copy()
        px = frame.load()
        for y in range(TILE):
            for x in range(TILE):
                phase = (x + y * 2 - index * (TILE // WATER_FRAMES)) % TILE
                if phase < 3:
                    r, g, b, a = px[x, y]
                    boost = 22 if phase == 1 else 12
                    px[x, y] = (min(255, r + boost), min(255, g + boost), min(255, b + boost), a)
        frames.append(frame)
    return frames


def supplement_tile(src: Image.Image, box: tuple[int, int, int, int], inset: int = 6) -> Image.Image:
    x0, y0, x1, y1 = box
    return src.crop((x0 + inset, y0 + inset, x1 - inset, y1 - inset)).resize((TILE, TILE), Image.LANCZOS).convert("RGBA")


def build_tileset() -> None:
    old = Image.open(OUT_TILES / "tide_root_town_tileset.png").convert("RGBA")
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE, ATLAS_ROWS * TILE), (0, 0, 0, 0))
    atlas.paste(old.crop((0, 0, ATLAS_COLUMNS * TILE, 3 * TILE)), (0, 0))

    # 第 3 列：淺水 0～3、深水 4～7、中水 8～11
    for group, source_col in enumerate((11, 13, 12)):
        base = old.crop((source_col * TILE, 0, (source_col + 1) * TILE, TILE))
        for index, frame in enumerate(water_frames(base)):
            atlas.paste(frame, ((group * WATER_FRAMES + index) * TILE, 3 * TILE))

    # 第 4 列：補充參考表
    sup = Image.open(INCOMING / "A11-A19_tileset_supplement_reference.png").convert("RGBA")
    boxes = find_components(sup, min_area=200)
    void_centers = [(x, y) for y in (440, 530, 620) for x in (520, 610, 700)]
    # 0～8 虛空：參考圖的星雲偏亮，壓暗後才不會搶走上層樹枝平台的視覺重點
    tiles: list[Image.Image] = [darken(supplement_tile(sup, box_containing(boxes, x, y)), 0.62) for x, y in void_centers]
    void_center = tiles[4]
    cloud = supplement_tile(sup, box_containing(boxes, 896, 530))
    mist = void_center.copy()
    cloud.putalpha(cloud.getchannel("A").point(lambda v: int(v * 0.82)))
    mist.alpha_composite(cloud)
    tiles.append(mist)                                                    # 9 雲霧
    tiles.append(supplement_tile(sup, box_containing(boxes, 914, 185)))  # 10 深色樹皮（霧氣樹幹中段）
    tiles.append(supplement_tile(sup, box_containing(boxes, 1258, 210), inset=2))  # 11 樓梯（正面）
    tiles.append(supplement_tile(sup, box_containing(boxes, 62, 262)))   # 12 草地變體（花草）
    tiles.append(supplement_tile(sup, box_containing(boxes, 540, 185)))  # 13 綠色樹幹中段
    tiles.append(supplement_tile(sup, box_containing(boxes, 72, 760)))   # 14 木板
    for col, tile in enumerate(tiles):
        atlas.paste(tile, (col * TILE, 4 * TILE))
    atlas.save(OUT_TILES / "tide_root_town_tileset.png")
    print("tileset:", atlas.size, f"補充 tile {len(tiles)} 格")


# ---------------------------------------------------------------------------
# UI 與特效貼圖
# ---------------------------------------------------------------------------
def build_dialogue_frame() -> Image.Image:
    """對話框九宮格 48×48：深色外框、木紋邊、亮邊、羊皮紙底。patch margin = 8。"""
    size = 48
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=4, fill=(46, 26, 12, 255))
    d.rounded_rectangle((1, 1, size - 2, size - 2), radius=3, fill=(122, 78, 38, 255))
    d.rounded_rectangle((2, 2, size - 3, size - 3), radius=3, outline=(160, 108, 56, 255))
    rng = random.Random(11)
    for _ in range(40):  # 木紋
        x = rng.randint(2, size - 3)
        y = rng.randint(2, size - 3)
        if 6 <= x <= size - 7 and 6 <= y <= size - 7:
            continue
        d.point((x, y), fill=(98, 60, 28, 255))
    d.rectangle((6, 6, size - 7, size - 7), fill=(58, 34, 16, 255))
    d.rectangle((7, 7, size - 8, size - 8), fill=(240, 226, 188, 255))
    for _ in range(60):  # 羊皮紙斑點
        x = rng.randint(8, size - 9)
        y = rng.randint(8, size - 9)
        d.point((x, y), fill=(226, 208, 164, 255))
    return im


def build_interact_prompt() -> Image.Image:
    """互動提示：18×20 的羊皮紙色對話泡泡，內有像素字「E」，底部有小尾巴。"""
    im = Image.new("RGBA", (18, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 17, 15), radius=3, fill=(46, 26, 12, 255))
    d.rounded_rectangle((1, 1, 16, 14), radius=2, fill=(244, 232, 196, 255))
    d.polygon([(6, 15), (11, 15), (8, 19)], fill=(46, 26, 12, 255))
    d.polygon([(7, 15), (10, 15), (8, 17)], fill=(244, 232, 196, 255))
    glyph = ["11111", "10000", "11110", "10000", "10000", "11111"]
    for row, bits in enumerate(glyph):
        for col, bit in enumerate(bits):
            if bit == "1":
                d.point((6 + col, 4 + row), fill=(60, 34, 14, 255))
    return im


def build_glow(size: int = 96) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = im.load()
    radius = size / 2
    for y in range(size):
        for x in range(size):
            distance = math.hypot(x + 0.5 - radius, y + 0.5 - radius) / radius
            if distance >= 1.0:
                continue
            alpha = int(255 * (1.0 - distance) ** 2 * 0.85)
            px[x, y] = (255, 196, 110, alpha)
    return im


def build_particle_textures() -> None:
    leaf = Image.new("RGBA", (6, 6), (0, 0, 0, 0))
    d = ImageDraw.Draw(leaf)
    d.polygon([(0, 3), (3, 0), (5, 2), (2, 5)], fill=(112, 176, 72, 255))
    d.line((1, 4, 4, 1), fill=(70, 128, 44, 255))
    leaf.save(OUT_EFFECTS / "leaf.png")
    firefly = Image.new("RGBA", (5, 5), (0, 0, 0, 0))
    d = ImageDraw.Draw(firefly)
    d.ellipse((0, 0, 4, 4), fill=(255, 236, 120, 110))
    d.rectangle((2, 1, 2, 3), fill=(255, 250, 200, 255))
    d.rectangle((1, 2, 3, 2), fill=(255, 250, 200, 255))
    firefly.save(OUT_EFFECTS / "firefly.png")
    butterfly = Image.new("RGBA", (14, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(butterfly)
    for frame, spread in enumerate((3, 1)):  # 兩幀：張翅、合翅
        ox = frame * 7
        d.rectangle((ox + 3, 1, ox + 3, 5), fill=(60, 40, 30, 255))
        d.polygon([(ox + 3, 3), (ox + 3 - spread, 0), (ox, 3)], fill=(240, 150, 90, 255))
        d.polygon([(ox + 3, 3), (ox + 3 + spread, 0), (ox + 6, 3)], fill=(240, 150, 90, 255))
        d.polygon([(ox + 3, 3), (ox + 3 - spread, 6), (ox + 1, 4)], fill=(220, 120, 80, 255))
        d.polygon([(ox + 3, 3), (ox + 3 + spread, 6), (ox + 5, 4)], fill=(220, 120, 80, 255))
    butterfly.save(OUT_EFFECTS / "butterfly.png")


def build_ui() -> None:
    OUT_EFFECTS.mkdir(parents=True, exist_ok=True)
    build_dialogue_frame().save(OUT_UI / "dialogue_frame.png")
    build_interact_prompt().save(OUT_UI / "interact_prompt.png")
    build_glow().save(OUT_EFFECTS / "lamp_glow.png")
    build_particle_textures()
    print("ui: dialogue_frame, interact_prompt, lamp_glow, leaf, firefly, butterfly")


def main() -> None:
    build_characters()
    build_props()
    build_tileset()
    build_ui()


if __name__ == "__main__":
    main()
