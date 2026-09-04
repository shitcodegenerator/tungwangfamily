# 給本地 AI：Phase 4.6 執行提示

你正在 `shitcodegenerator/tungwangfamily` 執行 Phase 4.6。請先從本分支拉取全部素材，再修改程式；不要自行替換角色設計、劇情台詞或新增未確認的 NPC。

## 先做的事

1. 讀 `docs/PHASE_4_6_ANIMATION_AND_CAVE_ASSETS.md`。
2. 確認以下檔案都是合法 PNG、RGBA、尺寸正確：
   - `assets/characters/playable/*_walk_v2_sheet.png`
   - `assets/characters/playable/*_idle_sheet.png`
   - `assets/effects/character_shadow.png`
   - `assets/effects/pet_shadow.png`
   - `assets/tiles/fried_food_cave_tiles_32.png`
3. 執行 `godot --headless --path . --import`，不要只相信檔案名稱。

## 程式工作

### A. 動畫選擇

- `velocity.length() > 0` 播放 `walk`，否則播放 `idle`。
- walk：4 幀、7～8 FPS；idle：4 幀、2.5～3.5 FPS。
- 專案方向索引固定為 down/left/right/up，不要沿用參考圖可能不同的列序。
- 弟弟只有在 leader 狀態使用較快速度，這個既有規則不可被動畫重構破壞。

### B. 接地陰影

- 在 playable character scene 的地面錨點新增 Shadow Sprite2D；主角使用 `character_shadow.png`，CC 使用 `pet_shadow.png`。
- Shadow 固定在 CharacterBody2D 的 ground anchor，idle bob 只作用於 `VisualRoot`。
- Shadow 低於角色 Sprite，但不能被地板 tile 蓋住；依現有 Y-sort／z-index 規則測試主城、洞窟、橋面。
- 不要用每幀自動 bbox 計算影子位置。

### C. 跟隨隊形

- 先處理同格重疊：跟隨者至少與前一個隊員保留既有 `FOLLOW_DISTANCE`，必要時使用固定隊形點或短暫避讓。
- 切換 leader 後，動畫、速度與陰影都要跟著新 leader 正確切換。
- CC 繼續是隊伍最後一位，不加入可切換的 `members/order`。

### D. 洞窟

- 用 `assets/tiles/fried_food_cave_tiles_32.png` 的 4×2 tile atlas 替換洞窟視覺。
- 先維持目前地圖座標和碰撞，晶簇只做 overlay；不要因為換圖而重畫戰鬥地圖。
- Boss 生成 y 至少離地圖上緣 2 格，且頭部不得被 viewport 裁切。

## 不要在本階段做

- 不要新增劇情、Boss 行為、第二種攻擊或新的 NPC。
- 不要把 Phase 5 的每日系統混進本分支；本階段只保留可銜接的節點和素材。
- 不要以 emoji 字型取代 `assets/ui/anger_mark.png`。

## 驗證

除了既有自動測試，請新增或補充：

- 每位主角四方向的 walk frame hash 檢查，確認 0≠2、1≠3。
- 每格 alpha bbox 的底部都等於 62（代表 y=61 最後一列有圖、最底 2px 保留）。
- Shadow 的中心在 ground anchor，idle 四幀不改變 Shadow 世界座標。
- 洞窟 Boss 不貼上緣、三種可丟物仍可命中五次、勝負返回 CC 的舊測試全部通過。

最後請回報：修改的檔案、測試數量、手動測試截圖，以及是否需要重新匯入 Godot 資源。
