# Phase 1 素材說明

本資料夾包含 Phase 1 的美術參考素材。角色圖與主城圖先作為原型素材使用；若圖片不是嚴格的最終像素格，請由本地 AI 依照 `docs/PHASE_1_PROJECT_PLAN.md` 重整成正式 Sprite、TileSet 與碰撞資料。

## 檔案

- `characters/playable/phase1_playable_sprite_reference.png`：四位主角四方向參考表。
- `world/phase1_tide_root_town_reference.png`：潮根城主城遊戲畫面參考。
- `tilesets/phase1_tide_root_tileset_reference.png`：主城地形、樹根、木板、水面與裝飾的 Tileset 參考。

本次 A 級補件位於 `incoming/`：

- `A1`～`A4`：四位主角獨立行走表。
- `A5`～`A10`：主城重要道具。
- `A11-A19_tileset_supplement_reference.png`：A11～A19 的補充 Tileset 合成參考表，需依現有規格切割整理。

## 使用原則

- 不要直接以任意比例縮放角色。
- 正式角色單格為 48×64 px。
- 正式地圖格為 32×32 px。
- 圖片放大使用 Nearest Neighbor。
- 角色腳底必須統一在同一條基準線。
- 主城需要在 Godot 內重新建立可碰撞的 TileMapLayer。
