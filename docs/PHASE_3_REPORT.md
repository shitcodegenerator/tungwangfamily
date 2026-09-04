# Phase 3 完成回報（2026-09-04）

環境：macOS（Apple M1 Pro）、Godot 4.7.2 stable、Python 3.9 + Pillow 11.3。
規劃來源：`docs/PHASE_3_PLAN.md`、`docs/PHASE_3_DECISIONS.md`、`docs/LOCAL_AI_PHASE_3_PROMPT.md`；
素材補件：`assets/reference/incoming/B3、B10 ×2、INT1、INT2`（來自分支 `codex/phase-3-quest-interiors`，已合併進 master）。

## 1. 實際完成

| 規劃項目 | 狀態 | 實作 |
|---|---|---|
| 3.1 集中式 GameState | 完成 | `scripts/state/game_state.gd`：schema_version、current/return scene、return_position、隊伍順序與位置、time_of_day、flags、quests、unlocked_scenes；`to_dict/from_dict` 含型別與版本驗證 |
| 3.2 JSON 存檔／讀檔 | 完成 | `scripts/save/save_manager.gd`：`user://save_01.json`、UTF-8 JSON、失敗回傳訊息不崩潰；F6 存檔、F7 讀檔；對話或轉場中拒絕並提示 |
| 3.3 場景轉換 | 完成 | `scripts/world/scene_router.gd` + `assets/maps/scenes.json`：穩定 `scene_id`、同一 `TownWorld` 場景以不同資料檔建立、0.25 秒淡出淡入、轉場中鎖輸入；`scripts/world/portal.gd` 傳送門（`target: "return"` 回到記住的位置） |
| 3.4 NPC 與對話 | 完成 | `scripts/characters/npc_character.gd` + `scenes/characters/npc.tscn`：站立待機、碰撞、E 互動、頭像、互動時轉向；對話 JSON 支援版本陣列 + `requires`（flags／not_flags／quest／quest_objective）+ `on_complete` 動作，由 `scripts/dialogue/dialogue_resolver.gd` 解析 |
| 3.5 任務系統 | 完成 | `scripts/quest/quest_manager.gd` + `assets/quests/phase3_demo_quest.json`：available／active／completed（failed 保留）、目標依序完成、`interact`／`enter_scene` 目標、rewards.flags；動作 `quest_start`／`set_flag`／`clear_flag`／`unlock_scene`／`quest_objective` |
| 3.6 任務 UI | 完成 | `scripts/ui/quest_hud.gd` + `scenes/ui/quest_hud.tscn`：右上角目前目標一行、J 任務日誌（✔／▶ 標記）、接受／完成提示；對話與轉場中不搶輸入 |
| 共享家庭屋 | 完成 | `family_home`：入口／出口、共用餐桌、廚房流理台、縫紉工作區、孩子角落、家庭記憶物件插槽（毛線籃，內容留白） |
| 船長房間 | 完成 | `captain_room`：航海圖桌、船具架、舷窗（潮汐觀測點）、船長重要物件插槽（上鎖小箱子，內容留白）、國王企鵝船長 NPC、吊燈與桌燈光暈 |
| 市集老龜 | 完成 | 位於主城下層廣場木箱旁（市集方向），負責測試任務回報 |
| 測試任務 | 完成 | `demo_town_orientation`（標題 `TEMP_DEMO_CONTENT：城鎮導覽測試`）：公告欄 → 家庭屋餐桌 → 船長房間航海圖桌 → 老龜回報，獎勵旗標 `demo_orientation_complete` |

### 素材整理（B3、B10、INT1、INT2）

- B10 兩張 NPC 表（384×512，5 欄 × 4 列）沿用主角切割器 → 240×256（第 0 欄站立、第 1～4 欄行走），`CharacterData` .tres 各一。
- B3 頭像 2×2 → 四張 48×48；NPC 頭像由站立幀頭部裁切成 48×48（`assets/portraits/`）。
- INT1／INT2 為不透明布局參考，未整張使用：裁出 27 件家具道具（放大 1.25 倍，船長房間的暗角以亮度鍵去透明），
  地板從參考圖取 32×32 tile 寫入 tileset 第 4 列第 15、16 格；牆面用既有樹皮 tile，透過 `scenes.json` 的 `legend_overrides` 指定。
- 室內是 20×12 的 ASCII 地圖 + 道具 JSON，與主城走同一條 `TownWorld` 管線（碰撞、Y-sort、互動、燈光全部沿用）。

## 2. 新增與修改的檔案

```text
新增
scripts/state/game_state.gd、scripts/save/save_manager.gd、scripts/quest/quest_manager.gd
scripts/dialogue/dialogue_resolver.gd、scripts/world/scene_router.gd、scripts/world/portal.gd
scripts/characters/npc_character.gd + scenes/characters/npc.tscn
scripts/ui/quest_hud.gd + scenes/ui/quest_hud.tscn
assets/maps/scenes.json、family_home.txt、family_home_props.json、captain_room.txt、captain_room_props.json
assets/dialogue/family_home.json、captain_room.json
assets/quests/phase3_demo_quest.json
assets/characters/npcs/{king_penguin_captain,old_turtle}_sheet.png + .tres
assets/portraits/*.png（6 張）、assets/props/int_*.png（12）、cap_*.png（15）
tools/build_assets_phase3.py
docs/PHASE_3_REPORT.md、docs/screenshots/09_family_home.png、10_captain_room.png、11_quest_log.png

修改
project.godot                      新增 quest_log（J）、debug_save（F6）、debug_load（F7）；預設清除色
scripts/main.gd / scenes/main.tscn 由 SceneRouter 建立世界；互動 → DialogueResolver → 對話 → 任務動作；F6／F7；讀檔還原
scripts/world/town_world.gd        configure(scene_id, info)、entries、portals、npcs、arrival_positions、對話版本陣列
scripts/world/tile_library.gd      ground/decoration 支援 overrides 與 dark_wall_last_row
scripts/characters/party_controller.gd  place／teleport_to／order_ids／set_order_by_ids
scripts/interaction/interactable.gd     dialogue_entry、portrait_id、owner_node
scripts/ui/dialogue_manager.gd     start() 支援頭像
scripts/ui/debug_hud.gd            Phase 3 說明、顯示場景名
assets/dialogue/tide_root_town.json     公告欄與老龜的任務版本對話
assets/maps/tide_root_town_props.json   entries、兩個傳送門、老龜 NPC
tools/validate_map.py              驗證所有場景、傳送門、互動點、任務目標
tests/run_tests.gd                 新增 36 項斷言（共 96）
scripts/debug/route_test.gd        Phase 3 流程（任務、室內、NPC、存讀檔、損毀存檔）
docs/MANUAL_TEST_GUIDE.md          第 7～9 節；README.md、AGENTS.md
```

## 3. 測試指令與結果

| 指令 | 結果 |
|---|---|
| `python3 tools/build_assets.py` | 三階段素材全部重建，無錯誤 |
| `godot --headless --path . --import` | 匯入完成，無 parser error（重建素材後必須先跑，否則執行期用的是舊的匯入快取） |
| `godot --headless --path . --quit-after 180` | 主場景執行 180 幀，無 runtime error |
| `python3 tools/validate_map.py` | 三個場景通過：入口可站、傳送門與互動點可達、邊界封鎖、對話齊全、任務目標皆對應互動 id |
| `godot --headless --path . -s res://tests/run_tests.gd` | 96 通過，0 失敗（含 GameState 往返、損毀存檔、任務流程、對話條件、場景登錄表、NPC 素材） |
| `caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots` | 結果：PASS（106 通過，0 失敗）、切換 22 次、跟隨者違規 0 筆 |

### 驗收條件對照

| 條件 | 自動化檢查 | 結果 |
|---|---|---|
| 乾淨啟動進入中央小鎮，不破壞既有手動測試 | Phase 1／2 全部 62 項檢查保留並通過 | 通過 |
| 公告欄啟動測試任務、任務摘要更新 | 「公告欄對話啟動任務並完成第一個目標」「任務 HUD 摘要更新」「再次互動不會重複接任務」「J 開啟任務日誌」 | 通過 |
| 進出共享家庭屋，返回位置合理、隊伍仍在 | 走入門口轉場、四人皆在室內、餐桌互動、走出後領頭者在門前 (144,702)、隊伍完整 | 通過 |
| 進出船長房間，船長與老龜可互動 | 船長房間轉場、國王企鵝船長對話、航海圖桌互動；老龜於主城廣場回報 | 通過 |
| F6 存檔、F7 讀檔後場景／位置／日夜／旗標／任務一致 | 存檔於任務進行中 → 完成任務並改時段 → 讀檔後任務回到進行中、位置與時段還原；完成後再存讀，旗標與完成狀態仍在 | 通過（同一次執行內；跨重啟由手動測試 9.4 覆蓋） |
| 損毀或不存在的存檔 | 寫入亂碼後讀檔回傳錯誤、目前狀態不變；單元測試涵蓋不存在的檔案 | 通過 |
| 對話中不能移動、切換角色、隊伍不失控 | Phase 2 檢查保留；轉場中同樣鎖定 | 通過 |
| 沒有新增正式劇情、Boss、私人回憶 | 所有測試文字含 `TEMP_DEMO_CONTENT`；兩個插槽只有介面 | 符合 |

截圖：`09_family_home.png`、`10_captain_room.png`、`11_quest_log.png`（01～08 亦重新擷取）。

## 4. 設計說明

- **一份狀態**：旗標、任務進度、場景、隊伍全部在 `GameState`；公告欄、NPC、場景腳本沒有任何自己的進度變數。
  對話版本由 `DialogueResolver` 讀 `GameState`／`QuestManager` 決定，`PlayableCharacter` 仍不知道對話與任務的存在。
- **場景切換不重建隊伍**：`PartyController` 不屬於世界節點，`SceneRouter` 只換 `World` 底下的 `TownWorld`，
  再以入口（entries）、返回點周圍可站格（`arrival_positions`）或存檔座標放置四人。
- **室內即資料**：新增室內只要 ASCII 地圖 + 道具 JSON + 對話 JSON，並在 `scenes.json` 登錄；不需要新場景檔或腳本。
- **存檔還原路徑**：`Main.apply_state()` → 重新綁定 QuestManager → 日夜立即套用 → 依 id 重排隊伍 → `SceneRouter.restore()` 依存檔座標放置。
- **輸入優先序**：對話 > 轉場 > 任務日誌／切換角色；F6／F7 在對話或轉場中被拒絕並提示。

## 5. 暫時內容（正式內容到位後替換）

- `assets/quests/phase3_demo_quest.json`：整個任務。
- `assets/dialogue/tide_root_town.json`：公告欄前兩個版本、老龜四個版本。
- `assets/dialogue/family_home.json`、`captain_room.json`：全部句子。
- 家庭記憶物件（家庭屋毛線籃 `family_memory_slot`）與船長重要物件（船長房間小箱子 `captain_keepsake_slot`）：只有介面與空白文字。
- 家具道具為參考圖裁切（含地板背景），不是逐像素修稿；船長房間暗角以亮度鍵去除。

## 6. 未完成／取捨

- 「重新啟動後讀檔」只在手動測試流程（9.4）驗證；自動化在同一次執行內完成存→改→讀。存檔格式與路徑固定，跨重啟沒有額外邏輯。
- 讀檔失敗時採規劃書的「保留目前狀態並提示」，而非提示詞中的「回到新遊戲狀態」；兩者在剛啟動時等價。
- 家庭屋的左右側門、船長房間的後門僅為裝飾，沒有第二個房間（規劃明定第一版不做）。
- 沒有巡邏 NPC、沒有時間系統、沒有音效。
- A11／A12 過渡 tile 仍待重產（見 `docs/ASSET_REQUEST.md`）。

## 7. 建議下一步

1. 作者提供正式任務與對話文字後，替換第 5 節列出的 JSON；程式不需改動。
2. 若要「重新啟動自動讀檔」或多存檔槽，只需在 `SaveManager` 加路徑參數與標題畫面。
3. 寵物與戰鬥（Phase 4）建議先定義 `GameState` 的新欄位與 schema_version 2 的遷移規則，再動系統。
