# 給本地 AI：Phase 4.6 持物／投擲動畫修正

請在獨立工作分支執行，避免覆蓋你正在進行的 `codex/phase-4-6-animation-cave-assets` 修改。先讀 `docs/PHASE_4_6_CARRY_THROW_ANIMATION.md`，再開始改程式。

## 素材接線

四位角色各有：

- `assets/characters/playable/<id>_walk_v2_sheet.png`：普通行走，192×256。
- `assets/characters/playable/<id>_idle_sheet.png`：待機，192×256。
- `assets/characters/playable/<id>_carry_walk_v2_sheet.png`：持物行走，192×256。
- `assets/characters/playable/<id>_throw_v2_sheet.png`：投擲，144×256。

方向列序一律是 down、left、right、up。持物表每列 4 幀；投擲表每列 3 幀。

## 必做修改

1. `CharacterData` 新增 `carry_walk_sheet` 與 `throw_sheet`，並在四個 `.tres` 接上正確角色的素材。
2. `PlayableCharacter` 的動畫選擇改成：投擲 > 持物行走 > 普通行走 > idle。
3. `is_carrying && velocity.length() > 0` 時，必須使用 `carry_walk_v2_sheet`；不可再用舊的單張 carry 姿勢。
4. 投擲用 3 幀表，總長約 0.25～0.30 秒；release 幀才觸發 `ThrownProjectile`。
5. CarryAnchor、角色 Shadow 和 CharacterBody2D 的 ground anchor 固定；不要隨著 Sprite 的 idle bob 或投擲前傾一起移動。
6. 播放切換不能讓普通 walk 動畫的 `_play_animation()` 每幀蓋掉 carry／throw 動畫。
7. 舊 `action_sheet` 僅作 fallback，不要刪除，避免讀取舊存檔或舊素材時崩潰。

## 一致性檢查

請逐格比較四組表：

- 頭部位置和尺寸不可突然變大或縮小。
- 角色腳底都在每格 y=61，陰影世界座標不變。
- 角色主要色盤和配件不可改變。
- 持物表不應畫入青菜、綠茶、水；這些仍由 `CarryAnchor` 顯示。
- 投擲表不能使用上一版角色外觀。

## 測試

請新增或補充自動測試：

- 四位角色各四方向持物移動，確認播放的是 carry sheet 而不是 fallback action sheet。
- 四位角色各完成 windup → release → follow-through，確認只生成一個投射物。
- 切換 leader、弟弟較快速度、跟隨隊形、CC 最後跟隨者均不回歸。
- 命中炸物魔王 5 次、戰敗重來、勝利返回 CC 全部通過。

手動測試請錄製至少三段：

1. 四人排成隊伍，輪流切換 leader 並持物走路。
2. 四個方向各投擲一次，確認出手方向、release 時機和腳底位置。
3. 洞窟 Boss 戰中撿取、移動、投擲，確認物品沒有重複或卡在手上。

最後回報實際修改的檔案、測試數量，以及任何仍需作者確認的角色外觀差異。
