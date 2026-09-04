# AGENTS.md — 給 AI 協作者的專案守則

## 專案是什麼

「山海樹港 RPG」：Godot 4.7 2D 原型。Phase 1 完成主城「潮根城」、四位可切換角色與跟隨隊伍；
Phase 2 完成互動（E）、對話框、城鎮生命動畫與 F5 日夜切換；Phase 3 完成 GameState、存檔、場景路由、
兩個室內場景、兩位 NPC、資料驅動任務與 TEMP_DEMO_CONTENT 測試任務。
規劃文件：`docs/PHASE_1_PROJECT_PLAN.md`、`docs/PHASE_2_PLAN.md`、`docs/PHASE_3_PLAN.md`、`docs/PHASE_3_DECISIONS.md`、
`docs/LOCAL_AI_PHASE_*_PROMPT.md`。**內容邊界以 `docs/PHASE_3_DECISIONS.md` 為準**：不得自行創作正式劇情、Boss、
父親離世演出、乾媽家庭傷痛或真實回憶；測試內容一律標記 `TEMP_DEMO_CONTENT` 或 `demo_` 前綴；
父親原型是「國王企鵝船長」；媽媽與乾媽共用 `family_home`。

## 不可更動的規格

- 邏輯解析度 640×360，地圖格 32×32，角色單格 48×64（列序 down/left/right/up；精靈表第 0 欄站立、第 1～4 欄行走）。
- Compatibility renderer、Nearest Neighbor、不使用第三方 addon。
- 主城是一張連續世界地圖（960×1152），不拆成多個場景；室內是獨立小場景，經 `scenes.json` 的穩定 `scene_id` 切換。
- 四位角色共用 `scenes/characters/playable_character.tscn` 與同一套腳本，差異只放在 `CharacterData` .tres。
- 站立微晃動只移動 `VisualRoot`，不移動 CharacterBody2D 與碰撞盒。

## 目前明確不做

戰鬥、小怪、經驗值、等級、裝備、技能、任務、分支對話、存檔條件、背包、寵物、送禮、房屋內部、場景轉場。

## 責任分工

| 檔案 | 只負責 |
|---|---|
| `scripts/characters/player_character.gd` | 單一角色的輸入、移動、方向、動畫、微晃動 |
| `scripts/characters/follower_character.gd` | 由前一位隊員的軌跡算出想要的速度 |
| `scripts/characters/party_controller.gd` | 切換、隊伍順序、跟隨鏈 |
| `scripts/world/town_world.gd` | 由 ASCII 地圖與 JSON 建立世界 |
| `scripts/camera/camera_rig.gd` | 鏡頭跟隨與邊界 |
| `scripts/ui/debug_hud.gd` | 除錯資訊 |
| `scripts/interaction/interactable.gd` | 被互動時發 signal、攜帶對話資料 |
| `scripts/interaction/interaction_controller.gd` | 最近目標、提示圖示、E 鍵分派 |
| `scripts/ui/dialogue_box.gd` | 顯示一句話（逐字、換行、頭像預留） |
| `scripts/ui/dialogue_manager.gd` | 單線對話順序與開關 |
| `scripts/world/day_night.gd` | CanvasModulate 日夜狀態 |
| `scripts/world/ambient_effects.gd` | 粒子 |
| `scripts/props/town_prop.gd` | 道具貼圖、碰撞、多幀／飄移／光暈 |
| `scripts/state/game_state.gd` | 唯一的遊戲狀態與序列化 |
| `scripts/save/save_manager.gd` | JSON 存讀檔，回傳錯誤不崩潰 |
| `scripts/quest/quest_manager.gd` | 任務定義、進度、對話動作 |
| `scripts/dialogue/dialogue_resolver.gd` | 依狀態挑對話版本 |
| `scripts/world/scene_router.gd` | 場景建立、轉場、傳送門、讀檔還原 |
| `scripts/characters/npc_character.gd` | 站立 NPC 外觀與轉向 |
| `scripts/ui/quest_hud.gd` | 任務摘要、日誌、提示 |

不要把劇情、戰鬥與移動耦合進同一支腳本；不要為了「泛用」建立難以除錯的框架。
對話內容一律放 `assets/dialogue/*.json`、任務放 `assets/quests/*.json`；旗標與任務進度只存在 `GameState`，
不要在公告欄、NPC 或場景腳本裡各自保存變數。`PlayableCharacter` 不得知道對話、任務或互動物件的存在。
存檔 ID 用 `scene_id` 與角色 `id`，不要用節點路徑。
生命感動畫與日夜只能改視覺節點（Sprite2D、CanvasModulate、粒子），不得改碰撞、角色座標或 Y-sort 基準。

## 每次修改後必跑

```bash
godot --headless --path . --import   # 改過素材或新增檔案後先跑
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

三者都必須通過（route test 以 exit code 0 結束並印出「結果：PASS」）。

## 地圖與道具

- 地圖改 `assets/maps/tide_root_town.txt`；道具、出生點、出口改 `assets/maps/tide_root_town_props.json`。
- 道具碰撞盒以「底部中央」為原點，`collision: [寬, 高]`；`null` 代表純裝飾。
- 道具碰撞盒相交的格子會被視為不可路徑規劃；路線驗證依賴這個規則。
- 道具或出口加 `interact: <id>` 即成為可互動物件；`<id>` 必須存在於 `assets/dialogue/tide_root_town.json`
  （`validate_map.py` 與單元測試都會檢查）。

## 物理層

| 層 | 用途 |
|---|---|
| 1 World | TileMap 碰撞、道具 StaticBody2D |
| 2 Characters | 角色本體（彼此不碰撞） |
| 3 Interactable | 可互動物件（Interactable Area2D）；角色的 InteractionArea 只偵測此層 |

## 素材

- 遊戲素材由 `tools/build_assets.py`（含 `build_assets_phase2.py`）從 `assets/reference/` 與 `assets/reference/incoming/` 切割產生，改參考圖後重跑即可；不要手改 `assets/characters`、`assets/props`、`assets/tilesets` 裡的 PNG。
- 字型：Fusion Pixel 12px（OFL，`assets/ui/FUSION_PIXEL_OFL.txt`），UI 字級請用 12 的倍數。
