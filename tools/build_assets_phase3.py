#!/usr/bin/env python3
"""Phase 3 素材產生器：NPC 行走表、角色頭像、室內家具道具、室內地板 tile。

- B10：國王企鵝船長、市集老龜 5 欄 × 4 列參考 → 240×256 精靈表（與主角同規格）
- B3：四位主角頭像 2×2 → 各 48×48；NPC 頭像由站立幀頭部裁切
- INT1／INT2：室內布局參考圖（不透明）→ 依手工框裁出家具（放大 1.25 倍）、地板 32×32 tile 寫入 tileset 第 4 列第 15、16 格

由 build_assets.py 自動呼叫，也可單獨執行：python3 tools/build_assets_phase3.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from build_assets import OUT_CHARS, OUT_PROPS, OUT_TILES, ROOT, TILE
from build_assets_phase2 import INCOMING, build_character, grid_cells

OUT_NPCS = ROOT / "assets" / "characters" / "npcs"
OUT_PORTRAITS = ROOT / "assets" / "portraits"
PORTRAIT_SIZE = 48
INTERIOR_SCALE = 1.25  # 512 寬參考圖 → 640 邏輯寬

NPC_SOURCES = {
    "king_penguin_captain": "B10_king_penguin_captain_sheet.png",
    "old_turtle": "B10_old_turtle_sheet.png",
}
PLAYER_PORTRAIT_ORDER = ["big_brother", "calm_brother", "sister_sheep", "younger_brother"]

# 室內家具：名稱 → (參考圖, 裁切框 x0,y0,x1,y1 以 512×341 原圖座標)
INTERIOR_PROPS = {
    "int_stove": ("INT1_shared_family_house_reference.png", (50, 40, 92, 122)),
    "int_kitchen_counter": ("INT1_shared_family_house_reference.png", (92, 75, 182, 123)),
    "int_kitchen_window": ("INT1_shared_family_house_reference.png", (100, 38, 138, 76)),
    "int_yarn_cabinet": ("INT1_shared_family_house_reference.png", (266, 50, 310, 122)),
    "int_yarn_basket": ("INT1_shared_family_house_reference.png", (306, 72, 344, 102)),
    "int_sewing_table": ("INT1_shared_family_house_reference.png", (338, 66, 402, 132)),
    "int_fabric_shelf": ("INT1_shared_family_house_reference.png", (420, 66, 456, 122)),
    "int_plant": ("INT1_shared_family_house_reference.png", (440, 120, 462, 152)),
    "int_dining_table": ("INT1_shared_family_house_reference.png", (86, 166, 220, 240)),
    "int_kids_corner": ("INT1_shared_family_house_reference.png", (340, 172, 452, 256)),
    "int_back_door": ("INT1_shared_family_house_reference.png", (224, 30, 266, 100)),
    "int_side_door": ("INT1_shared_family_house_reference.png", (16, 146, 46, 202)),
    "cap_wall_map": ("INT2_captain_room_reference.png", (120, 40, 202, 102)),
    "cap_hanging_lantern": ("INT2_captain_room_reference.png", (220, 10, 256, 72)),
    "cap_painting": ("INT2_captain_room_reference.png", (224, 70, 262, 102)),
    "cap_porthole": ("INT2_captain_room_reference.png", (268, 30, 326, 92)),
    "cap_coat_rack": ("INT2_captain_room_reference.png", (324, 60, 376, 152)),
    "cap_rod_rack": ("INT2_captain_room_reference.png", (370, 70, 456, 202)),
    "cap_bookshelf": ("INT2_captain_room_reference.png", (58, 80, 122, 182)),
    "cap_chart_desk": ("INT2_captain_room_reference.png", (124, 100, 266, 196)),
    "cap_chest_bench": ("INT2_captain_room_reference.png", (270, 110, 312, 166)),
    "cap_barrel": ("INT2_captain_room_reference.png", (40, 164, 72, 202)),
    "cap_rope_coil": ("INT2_captain_room_reference.png", (58, 190, 102, 222)),
    "cap_side_table": ("INT2_captain_room_reference.png", (70, 220, 182, 322)),
    "cap_rug": ("INT2_captain_room_reference.png", (180, 190, 352, 292)),
    "cap_chest_stack": ("INT2_captain_room_reference.png", (370, 204, 452, 282)),
    "cap_fish_crate": ("INT2_captain_room_reference.png", (320, 254, 402, 332)),
}
# 地板 tile：(參考圖, 26×26 的純地板區域) → 放大後約 32×32
INTERIOR_FLOORS = {
    15: ("INT1_shared_family_house_reference.png", (240, 240, 266, 266)),
    16: ("INT2_captain_room_reference.png", (240, 296, 266, 322)),
}


def build_npcs() -> None:
    OUT_NPCS.mkdir(parents=True, exist_ok=True)
    for npc_id, source in NPC_SOURCES.items():
        build_character(INCOMING / source, OUT_NPCS / f"{npc_id}_sheet.png")


def square_head(sprite: Image.Image) -> Image.Image:
    """取精靈上方的正方形區域（頭部）縮成 48×48。"""
    side = min(sprite.width, sprite.height)
    head = sprite.crop(((sprite.width - side) // 2, 0, (sprite.width - side) // 2 + side, side))
    return head.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.LANCZOS)


def build_portraits() -> None:
    OUT_PORTRAITS.mkdir(parents=True, exist_ok=True)
    src = Image.open(INCOMING / "B3_character_portraits_reference.png").convert("RGBA")
    half_w, half_h = src.width // 2, src.height // 2
    for index, character_id in enumerate(PLAYER_PORTRAIT_ORDER):
        col, row = index % 2, index // 2
        cell = src.crop((col * half_w, row * half_h, (col + 1) * half_w, (row + 1) * half_h))
        cell.resize((PORTRAIT_SIZE, PORTRAIT_SIZE), Image.LANCZOS).save(OUT_PORTRAITS / f"{character_id}.png")
    for npc_id, source in NPC_SOURCES.items():
        ref = Image.open(INCOMING / source).convert("RGBA")
        cells = grid_cells(ref)
        idle_down = ref.crop(cells[(4, 0)])
        square_head(idle_down).save(OUT_PORTRAITS / f"{npc_id}.png")
    print("portraits:", len(PLAYER_PORTRAIT_ORDER) + len(NPC_SOURCES))


def key_out_darkness(im: Image.Image, low: int = 16, high: int = 34) -> Image.Image:
    """船長房間參考圖四周是近黑的暗角，裁下的家具會帶著黑色方塊；把最暗的像素轉為透明（漸層過渡）。"""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            brightness = max(r, g, b)
            if brightness < high:
                factor = max(0.0, min(1.0, (brightness - low) / float(high - low)))
                px[x, y] = (r, g, b, int(a * factor))
    return out


def scaled_crop(source: str, box: tuple[int, int, int, int]) -> Image.Image:
    src = Image.open(INCOMING / source).convert("RGBA")
    crop = src.crop(box)
    if source.startswith("INT2"):
        crop = key_out_darkness(crop)
    return crop.resize((max(1, round(crop.width * INTERIOR_SCALE)), max(1, round(crop.height * INTERIOR_SCALE))), Image.LANCZOS)


def build_interior_props() -> None:
    for name, (source, box) in INTERIOR_PROPS.items():
        sprite = scaled_crop(source, box)
        sprite.save(OUT_PROPS / f"{name}.png")
    print("interior props:", len(INTERIOR_PROPS))


def build_interior_floors() -> None:
    atlas = Image.open(OUT_TILES / "tide_root_town_tileset.png").convert("RGBA")
    for column, (source, box) in INTERIOR_FLOORS.items():
        tile = Image.open(INCOMING / source).convert("RGBA").crop(box).resize((TILE, TILE), Image.LANCZOS)
        atlas.paste(tile, (column * TILE, 4 * TILE))
    atlas.save(OUT_TILES / "tide_root_town_tileset.png")
    print("interior floors written to tileset row 4, columns", list(INTERIOR_FLOORS))


def main() -> None:
    build_npcs()
    build_portraits()
    build_interior_props()
    build_interior_floors()


if __name__ == "__main__":
    main()
