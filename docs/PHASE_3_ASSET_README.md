# Phase 3 素材包說明

## 參考素材

以下 PNG 放在 `assets/reference/incoming/`，供本地 AI 和後續像素美術整理使用：

| 檔案 | 用途 |
|---|---|
| `B3_character_portraits_reference.png` | 四位可操作角色的 2×2 頭像方向參考，最終 UI 顯示需整理成四張 48×48 |
| `B10_king_penguin_captain_sheet.png` | 國王企鵝船長方向／行走參考，4 方向 × 5 格（含待機） |
| `B10_old_turtle_sheet.png` | 市集老龜方向／行走參考，4 方向 × 5 格（含待機） |
| `INT1_shared_family_house_reference.png` | 媽媽、乾媽和四個孩子共用的家庭屋室內構圖參考 |
| `INT2_captain_room_reference.png` | 國王企鵝船長房間室內構圖參考 |

## 使用限制與整理方式

- 這批素材是可愛、簡化、偏像素遊戲的第一版方向圖，不是最終逐像素修稿。
- 不要把參考圖整張當成單一 Sprite 使用。
- NPC 行走表請按照目前專案規格切成 48×64 格；若現有動畫資源採 4 幀行走加 1 幀待機，請保持一致。
- 四位頭像請從參考圖重繪或縮放整理成獨立 48×48 PNG，保留透明背景和清楚的臉部辨識度。
- 室內圖是布局參考，請使用現有 tileset／props 組成可碰撞、可走動、可由入口返回的 Godot 場景。
- 任何正式家庭記憶物件、船長重要物件或劇情插圖都先留成可替換插槽，等待作者提供內容。
