#!/usr/bin/env python3
"""Phase 5 素材產生器：城鎮視覺更新 atlas → tileset 第 6～7 列。

輸入：assets/tilesets/town_visual_refresh_tiles_32.png（遠端交付的正式 atlas，8 欄 × 4 列，每格 32×32）。
輸出：assets/tilesets/tide_root_town_tileset.png 擴充為 8 列，第 6～7 列放「修正後」的 32 格：

    tileset (c + 8 × (r % 2), 6 + r // 2)  ←  atlas (c, r)

    第 6 列 第 0～7 欄：草地 A、草地 B、花草草地、泥土、石板 A、石板 B、木板、深水（靜態）
    第 6 列 第 8～15 欄：石板路 edge N／S／W／E、corner NW／NE／SW／SE
    第 7 列 第 0～7 欄：水岸 edge N／S／W／E、corner NW／NE／SW／SE
    第 7 列 第 8～15 欄：草崖、樹根牆、橋面（南北向）、橋側、水面動畫 4 幀
    第 7 列 第 16～17 欄：東西向木橋 上列／下列（由南北向橋面旋轉後合成）

修正內容（見 docs/PHASE_5_REPORT.md）：
1. 交付的 atlas 每格最外圈 1px 偏亮、次外圈 1px 偏暗（生成時的格框），平鋪後會出現整齊格線；
   這裡取每格內部 28×28，外圈 2px 以鏡射補回，讓四邊可無縫平鋪（同 Phase 4.6 洞窟 tile 的 A8 處理）。
2. path_edge_s、shore_edge_s、四個 corner_sw／corner_se 交付時方向與 _n／_nw／_ne 相同，無法使用；
   改由對應的 _n／_nw／_ne 垂直翻轉產生，原格位置不變。
3. 交付的橋面是南北向（欄杆在左右）；主城的港口橋是東西向兩列，另外合成上列（欄杆在上）與下列（欄杆在下）。

由 build_assets.py 自動呼叫，也可單獨執行：python3 tools/build_assets_phase5.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from build_assets import OUT_TILES, ROOT, TILE
from build_assets_phase4 import is_valid_png

REFRESH_ATLAS = OUT_TILES / "town_visual_refresh_tiles_32.png"
TILESET = OUT_TILES / "tide_root_town_tileset.png"
ATLAS_COLUMNS = 18
ATLAS_ROWS = 8
REFRESH_FIRST_ROW = 6
FRAME_PX = 2  # 交付 atlas 每格四邊的格框厚度（亮 1px + 暗 1px）
BRIDGE_EW_TOP = (16, 7)
BRIDGE_EW_BOTTOM = (17, 7)
# 需要由對應方向翻轉補齊的格：(atlas 欄, 列) → 來源 (欄, 列)
FLIPPED_FROM = {
    (1, 1): (0, 1),  # path_edge_s   ← path_edge_n
    (6, 1): (4, 1),  # path_corner_sw ← path_corner_nw
    (7, 1): (5, 1),  # path_corner_se ← path_corner_ne
    (1, 2): (0, 2),  # shore_edge_s  ← shore_edge_n
    (6, 2): (4, 2),  # shore_corner_sw ← shore_corner_nw
    (7, 2): (5, 2),  # shore_corner_se ← shore_corner_ne
}
BRIDGE_SOURCE = (2, 3)  # bridge_planks（南北向）
BRIDGE_RAIL_PX = 10  # 旋轉後上下欄杆各佔的列數（量自交付 tile）


def tileset_slot(column: int, row: int) -> tuple[int, int]:
    """交付 atlas 的 (欄, 列) → tileset 的 (欄, 列)。"""
    return column + 8 * (row % 2), REFRESH_FIRST_ROW + row // 2


def deframe(tile: Image.Image, frame: int = FRAME_PX) -> Image.Image:
    """去掉每格四邊 frame px 的格框：保留內部，外圈以鏡射補回，四邊可無縫平鋪。"""
    size = tile.width
    inner = tile.crop((frame, frame, size - frame, size - frame))
    fixed = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fixed.paste(inner, (frame, frame))
    px = fixed.load()
    for i in range(frame):
        # 左右：欄 i 鏡射自欄 2*frame-1-i；欄 size-1-i 鏡射自欄 size-2*frame+i
        for y in range(frame, size - frame):
            px[i, y] = px[2 * frame - 1 - i, y]
            px[size - 1 - i, y] = px[size - 2 * frame + i, y]
    for i in range(frame):
        for x in range(size):
            px[x, i] = px[x, 2 * frame - 1 - i]
            px[x, size - 1 - i] = px[x, size - 2 * frame + i]
    return fixed


def ring_brightness(tile: Image.Image, ring: int) -> float:
    """距離邊緣 ring px 那一圈的平均亮度（檢查格線用）。"""
    px = tile.load()
    size = tile.width
    values = []
    for y in range(size):
        for x in range(size):
            if min(x, y, size - 1 - x, size - 1 - y) == ring:
                r, g, b, _a = px[x, y]
                values.append(0.299 * r + 0.587 * g + 0.114 * b)
    return sum(values) / len(values)


def bridge_east_west(planks: Image.Image) -> tuple[Image.Image, Image.Image]:
    """南北向橋面 → 東西向兩列：上列只留上緣欄杆、下列只留下緣欄杆，另一側以木板中段補平。
    旋轉後欄杆佔上下各 BRIDGE_RAIL_PX 列（含去格框後的鏡射列），木板中段在第 11～20 列。"""
    rotated = planks.rotate(90, expand=False)
    size = rotated.width
    rail = BRIDGE_RAIL_PX
    band = rotated.crop((0, size // 2 - rail // 2, size, size // 2 + rail // 2))
    top = rotated.copy()
    top.paste(band, (0, size - rail))
    bottom = rotated.copy()
    bottom.paste(band, (0, 0))
    return top, bottom


def build_refresh_tiles() -> None:
    if not is_valid_png(REFRESH_ATLAS):
        print(f"略過 Phase 5 tile：{REFRESH_ATLAS} 不是合法 PNG")
        return
    src = Image.open(REFRESH_ATLAS).convert("RGBA")
    if src.size != (8 * TILE, 4 * TILE):
        raise SystemExit(f"城鎮更新 atlas 尺寸應為 256×128，實際 {src.size}")
    fixed: dict[tuple[int, int], Image.Image] = {}
    for row in range(4):
        for column in range(8):
            fixed[(column, row)] = deframe(src.crop((column * TILE, row * TILE, (column + 1) * TILE, (row + 1) * TILE)))
    for target, source in FLIPPED_FROM.items():
        fixed[target] = fixed[source].transpose(Image.FLIP_TOP_BOTTOM)
    bridge_top, bridge_bottom = bridge_east_west(fixed[BRIDGE_SOURCE])

    old = Image.open(TILESET).convert("RGBA")
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * TILE, ATLAS_ROWS * TILE), (0, 0, 0, 0))
    atlas.paste(old.crop((0, 0, ATLAS_COLUMNS * TILE, min(old.height, REFRESH_FIRST_ROW * TILE))), (0, 0))
    for (column, row), tile in fixed.items():
        slot_column, slot_row = tileset_slot(column, row)
        atlas.paste(tile, (slot_column * TILE, slot_row * TILE))
    atlas.paste(bridge_top, (BRIDGE_EW_TOP[0] * TILE, BRIDGE_EW_TOP[1] * TILE))
    atlas.paste(bridge_bottom, (BRIDGE_EW_BOTTOM[0] * TILE, BRIDGE_EW_BOTTOM[1] * TILE))
    atlas.save(TILESET)

    worst = 0.0
    for tile in fixed.values():
        worst = max(worst, abs(ring_brightness(tile, 0) - ring_brightness(tile, 2)), abs(ring_brightness(tile, 1) - ring_brightness(tile, 2)))
    print(f"tileset: {atlas.size}（第 {REFRESH_FIRST_ROW}～{ATLAS_ROWS - 1} 列 = 城鎮更新 tile 32 格 + 東西向木橋 2 格；"
          f"去格框後外圈與內圈亮度差最大 {worst:.1f}）")


def main() -> None:
    build_refresh_tiles()


if __name__ == "__main__":
    main()
