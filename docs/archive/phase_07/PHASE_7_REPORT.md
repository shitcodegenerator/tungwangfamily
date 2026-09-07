> ARCHIVED（Phase 8.5 歸檔，2026-09-07）：歷史文件，只供追溯。現行規格：docs/CURRENT_PROJECT_SPEC.md；索引：docs/INDEX.md；待決策：docs/OPEN_DECISIONS.md。

# Phase 7 完成報告：視覺基礎修正與日誌可讀性

日期：2026-09-07　Godot 4.7.2　規劃：`docs/archive/phase_07/PHASE_7_PLAN.md`、`docs/archive/phase_07/LOCAL_AI_PHASE_7_PROMPT.md`、`docs/PHASE_7_SCENE_EDIT_TUTORIAL.md`、
`assets/reference/incoming/PHASE7_ASSET_MANIFEST.json`
基準：master `4cbaae0`（Phase 6）＋遠端 commit `356d7d1`（fast-forward）　分支：`phase-7-visual-foundation`

## 1. 驗收結果

| # | 規劃項目 | 狀態 | 說明 |
|---|---|---|---|
| P7.0 | 基準檢查 | 完成 | `--import` 後 `validate_map.py` 通過、單元測試 305／0（Phase 6 基準）；`--snapshot` 基準截圖確認樹屋、拱門、繩圈都在畫面上 |
| P7.1 | 繩圈透明修正 | 完成 | 同名 `assets/props/cap_rope_coil.png` 重新匯入（`.godot/imported` 由 Godot 重建）；props 的 `texture`、`event_id: captain_mystery_item`、位置 (176,176) 未動；事件流程由 route test 重新驗證 |
| P7.2 | 任務／線索日誌滑動 | 完成 | `LogPanel/Margin/Scroll(ScrollContainer)/Log(Label)`；滾輪捲動、`<`／`>` 切換上下頁（作者決定：方向鍵保留給角色移動）；內容不足時不顯示捲軸；每次打開回到頂端；不抓焦點、不進存檔 |
| P7.3 | 樹屋與根拱門顯示修正 | 完成（含已知邊角案例） | 只改 props JSON 視覺欄位：樹屋 `foot_inset 64`、根拱門 `z_bias -1`；`x`／`y`、`collision`、`collision_boxes`、出口、傳送門、ASCII 地圖全部不變 |
| P7.4 | 最小視覺 QA | 完成 | 檢視主城可見接縫（第 4 節）；本階段沒有新增任何角色、NPC、Boss、劇情或新圖（繩圈為遠端交付的同名替換檔） |
| 驗證 | validate_map／unit test／route test | 完成 | 見第 5 節 |

## 2. 素材檢查：`assets/props/cap_rope_coil.png`

| 檢查 | 結果 |
|---|---|
| `file` | `PNG image data, 55 x 40, 8-bit/color RGBA, non-interlaced` |
| 前 8 bytes | `89 50 4e 47 0d 0a 1a 0a` |
| SHA-256 | `0dce9b1708162dada0cf813e905a0930c61d3168e98c6a693051a68c2a7ebfe9`（與 manifest 一致） |
| 尺寸／模式 | 55×40、RGBA |
| 像素統計（Pillow） | 透明 892、半透明 0、實心 1308（共 2200）；四角皆 alpha 0；實心像素 9 色（manifest 寫 10 色是連透明色一起數） |
| 實心範圍 | x 1～49、y 4～36，沒有整張填滿的木地板底色（`docs/screenshots/phase7_review/01_cap_rope_coil_6x_on_grey.png`） |
| 匯入 | `godot --headless --path . --import` 重建 `cap_rope_coil.png-*.ctex`；單元測試 `test_phase7_props` 從匯入後貼圖再驗一次尺寸、透明、色數 ≤ 24 |
| 陰影 | 貼圖沒有烙進陰影；角色陰影仍由角色場景的 `Shadow` 節點負責 |

補充：遠端分支同時提交了 `assets/props/cap_rope_coil.svg`（原始來源）。Godot 會把 `assets/` 下的 SVG 當貼圖匯入並產生 `cap_rope_coil.svg.import`，遊戲沒有使用它；本階段一併提交 `.import` 讓 checkout 乾淨。若不想讓它進匯入流程，可移到 `assets/reference/incoming/`。

## 3. 修改檔案

| 檔案 | 內容 |
|---|---|
| `scenes/ui/quest_hud.tscn` | `LogPanel` 高度 180→232（y 64～296：Toast 在 y 40～58 之上、底部除錯列 y 326 之下、右上目標不受影響）；`Margin` 下新增 `Scroll`（ScrollContainer，水平停用、垂直自動）與其內的 `Log`（Label：`size_flags_horizontal` 填滿、`autowrap_mode` word smart）；捲軸用面板同色系的 StyleBoxFlat Theme（軌道深棕、把手金棕） |
| `scripts/ui/quest_hud.gd` | `log_scroll`；`set_log_open`／`toggle_log`（輸入鎖定時不能打開，打開時 `scroll_vertical = 0`）；`page_log(direction)`（一頁 = 可視高度 `page_height()`）；`log_scroll_offset`／`can_scroll_log`／`is_log_at_end`；`display_log_text`；`_unhandled_input` 處理 `quest_log` 與日誌開啟時的 `quest_log_next_page`／`quest_log_prev_page`（`project.godot` 新增，對應 `.`／`,` 即 `>`／`<`）；標題列加「<／>：上下頁」。日誌不呼叫 `grab_focus`，角色移動（`Input.get_vector` 輪詢）、E、F5～F7 都不受影響；`set_input_blocked` 行為不變 |
| `assets/maps/tide_root_town_props.json` | 樹屋加 `foot_inset: 64`；根拱門加 `z_bias: -1`；各加 `note` 說明。其他欄位逐字不變 |
| `project.godot` | 新增輸入動作 `quest_log_prev_page`（`,`／`<`）、`quest_log_next_page`（`.`／`>`） |
| `tests/run_tests.gd` | `test_phase7_props`（繩圈貼圖與 props 登錄、樹屋貼圖頂端 ≥ y574 且底緣 ≤ y736、樹屋仍 z 0 且碰撞 150×60、拱門 `z_bias < 0` 且接地線／位置不變、存檔不含 scroll）、`test_phase7_ui`（場景樹內實體化 HUD：節點結構、面板矩形、短文不可捲動且無捲軸、長文可捲動且裁在面板內、`page_log` 翻頁與夾邊界、`>`／`<` 事件、方向鍵不捲動、InputMap 登錄、重開回頂端、輸入鎖定時 J 與 `toggle_log` 都打不開） |
| `scripts/debug/route_test.gd` | Phase 3 段：打開日誌時位移 0、關閉檢查；Phase 5 段：拱門 `z_index < 0` 與截圖 `29_root_archway_party`、樹屋貼圖頂端 ≥ 574 且 z 0 與截圖 `30_treehouse_party`；Phase 6 段：日誌可捲動、`>` 連按翻到最後一頁（角色不動）、截圖 `28_quest_log_clue` 改為最後一頁、`<` 翻回、關閉重開回頂端；新增 `_find_prop` helper |
| `tools/snapshot_props_trial.py`（新） | 試 props 視覺欄位：套 patch → `--snapshot` → 還原 JSON（本階段用它比較 `z_bias -1`、`foot_inset 16／64／70／102` 等候選值） |
| `docs/screenshots/phase7_review/`（新） | 繩圈 6 倍圖、樹屋／拱門修正前後對照、門口與牆前接地（README 列出每張圖驗證的事） |
| `AGENTS.md`、`README.md`、`docs/MANUAL_TEST_GUIDE.md`（新增第 16 節）、`docs/PRODUCTION_NOTES.md`（D6.5-4、B23） | 文件同步 |
| `docs/screenshots/*.png(.import)` | route test 重拍：11（日誌新面板）、20／24（拱門 z 層）、28（捲到底的線索）、新增 29／30；Phase 6 遺留未提交的 25～28 `.import` 一併加入 |

## 4. 視覺決定與 QA 筆記

### 4.1 樹屋（`shared_family_treehouse_v2`，176×162，底部中央 (144,672)）

貼圖是「門＋牆面」的立面，比地圖上 3 列高的門口空間高 5 列；原本頂端在 y 510，把第 16～17 列的西橋頭與街道整段蓋住（隊伍走過去就消失）。
只用視覺欄位能做的選擇：

| 候選 | 結果 |
|---|---|
| `z_bias -1` | 隊伍永遠看得到，但站在第 17～18 列時整隊畫在門與圓窗上，像貼紙（`docs/screenshots/phase7_review` 試拍後放棄） |
| `foot_inset 16／32` | 屋頂只下移一點，第 17 列仍被蓋住 |
| **`foot_inset 64`（採用）** | 頂端 y 574，第 16～17 列街道完整可見；底緣 y 736 剛好落在第 23 列樹根牆上緣；門口傳送門 (144,674) 與返回點 (144,702) 落在門檻與踏墊上，站在門前像踏在台階上（`05_treehouse_door_and_wall_after.png`）；Y-sort 與碰撞盒都不變 |

邊角案例：第 18 列 (x 64～224) 那條草地仍在屋頂上緣後面，站在那裡腳會被蓋住一小段（`02_treehouse_row18_before_after.png` 右）；門右側牆前 (208,688) 角色畫在牆面下緣上，看起來略「貼牆」。

### 4.2 根拱門（`root_archway_v2`，176×166，接地線 `foot_inset 38`）

拱門是南北向通道，隊伍每次進出下層廣場都要穿過。Y-sort 下它物理上正確，但樹冠蓋住北側第 20～21 列街道、兩腳蓋住走廊兩側的跟隨者（`04_archway_inside_before_after.png` 左）。

| 候選 | 結果 |
|---|---|
| `foot_inset 70／102`（下移） | 北街清楚，但走廊上端（第 22 列）改被樹冠蓋住，且拱腳視覺基座落到廣場，站在旁邊像浮在根上 |
| **`z_bias -1`（採用）** | 整張拱門畫在角色後方：北街、走廊、兩側跟隨者都看得到；碰撞盒不變，兩腳仍擋路，只有第 14～15 欄能過 |

邊角案例：站在拱門正北第 21 列 (x 392～568) 時，隊伍畫在樹冠上方，像站在拱門頂上（`r1_north` 試拍）。真正的解法是把樹冠與拱腳拆成兩張圖（樹冠固定畫在角色上方、拱腳 Y-sort），這超出「只改 props JSON」範圍，列在第 6 節。

### 4.3 主城接縫檢視（P7.4）

- 下層廣場（新 atlas，第 23～35 列）：草地／石板／水岸／木橋接縫沒有黑縫或透明縫；第 22／23 列新舊 atlas 交界仍是舊草地接新樹根牆的硬切（Phase 5 已知）。
- 中層與上層（舊 atlas）：草地與石板街道是無過渡 tile 的硬切（例如第 14～21 列 `g`↔`s`）；這需要整組過渡 tile，不在本階段小修範圍，列入後續美術。
- 大型 props 接地：樹屋底緣 y 736（第 23 列線上）、拱門接地線 y 762（第 23.8 列，石板地面中段）、其餘 v2 props 未動。
- 沒有新增第二套角色比例或陰影；沒有新圖需要過 `ART_STYLE_LOCK.md` 檢查。

## 5. 驗證

| 項目 | 結果 |
|---|---|
| `godot --headless --path . --import` | 通過（繩圈與 SVG 重新匯入） |
| `python3 tools/validate_map.py` | 通過（四個場景 + 世界事件 1 個） |
| `godot --headless -s res://tests/run_tests.gd` | **335 通過、0 失敗**（Phase 6 基準 305；新增 30） |
| `--route-test` | **317 通過、0 失敗**，結果：PASS（Phase 6 基準 306；新增 11：日誌頂端／關閉、拱門 z 層、樹屋頂端、可捲動、捲到底、角色不動、翻回、重開回頂端等）。**注意**：這次跑的是「方向鍵捲動」版本；之後依作者決定改成 `<`／`>` 翻頁（route test 步驟已同步改為 `quest_log_next_page`／`quest_log_prev_page`），作者指示不再重跑，翻頁鍵由單元測試 `test_phase7_ui` 覆蓋（335／0）。下次任何人跑 route test 時會一併驗證 |

截圖與各自驗證的事（`docs/screenshots/`）：

| 檔案 | 驗證 |
|---|---|
| `25_captain_room_before_event.png` | 事件前：透明繩圈在書櫃與航海圖桌之間，周圍沒有方形色差 |
| `26_captain_room_item_moving.png` | 位移中：輸入鎖、E 提示隱藏、繩圈透明背景在木地板上移動 |
| `27_captain_room_event_complete.png` | 完成：停在 +20px、「新線索」提示 |
| `28_quest_log_clue.png` | 事件完成後打開日誌並捲到底（拍攝時仍是方向鍵版本，畫面與 > 翻到最後一頁相同）：「[線索]」段落可見、捲軸在底部、面板未超出畫面 |
| `29_root_archway_party.png` | 隊伍穿過根拱門（走廊內），跟隨者沒有被根系蓋住 |
| `30_treehouse_party.png` | 隊伍在共享家庭樹屋門口，腳底貼在門檻與台階上 |
| `11_quest_log.png` | 新面板尺寸下一個進行中任務的日誌（右側有捲軸，因為兩個可接取任務已超出） |
| `20_plaza_refresh.png`、`24_plaza_night.png` | 拱門 `z_bias -1` 後廣場白天／夜晚整體版面 |
| `phase7_review/*.png` | 修正前後對照（見該資料夾 README） |

## 6. 需作者決定／後續（已整理成 `docs/archive/phase_07/NOTES_FOR_PLANNER_PHASE_7.md` 給規劃 AI）

1. **樹屋第 18 列草地**：仍在屋頂上緣後面（腳被蓋一小段）。若要完全消除，需要把樹屋縮成約 96px 高（3 列）或把門口往南移一列（同步改傳送門、返回點、route test）；本階段沒有動這些。
2. **根拱門北側第 21 列**：`z_bias -1` 讓隊伍畫在樹冠上方。正式解法是遠端把 `root_archway_v2` 拆成「樹冠」與「拱腳＋地面」兩張圖（或程式支援 props `overlay_texture` 固定畫在角色上方），需要作者同意再做。
3. **日誌翻頁鍵**（已決定）：作者選擇 `<`／`>` 切換上下頁，方向鍵保留給角色移動；日誌開著時仍可移動（既有行為）。
4. **捲動位置**（已決定）：每次打開回到頂端，不進存檔。
5. **中層／上層舊 atlas 的草地↔石板硬切**、第 22／23 列新舊交界：需要整組過渡 tile，屬後續美術重製（`docs/archive/asset_requests/ASSET_REQUEST.md` E 節已有 atlas 需求）。
6. **`cap_rope_coil.svg`**：放在 `assets/props/` 會被 Godot 匯入成貼圖（未使用），建議遠端之後把來源檔放 `assets/reference/incoming/`。
7. 不在範圍：新角色、NPC、Boss、正式劇情文字、繩圈以外的新素材；Phase 6 的 TEMP_DEMO_CONTENT 文字全部未動。
