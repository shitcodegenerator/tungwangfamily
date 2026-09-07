# Phase 6 完成報告：船長房間的第一個異常事件

日期：2026-09-07　Godot 4.7.2　規劃：`docs/PHASE_6_PLAN.md`、`docs/LOCAL_AI_PHASE_6_PROMPT.md`、`docs/ART_STYLE_LOCK.md`、
`docs/HOW_TO_EDIT_SCENES_AND_MAP_ASSETS.md`、`assets/reference/incoming/PHASE6_EVENT_SPEC.json`
基準：master `0a0c0b2`（Phase 5）＋遠端文件 commit `835df02`（fast-forward）　分支：`phase-6-captain-room-event`

## 1. 驗收結果

| # | 驗收內容 | 狀態 | 說明 |
|---|---|---|---|
| 1 | 航海圖桌可以互動 | 完成 | 沿用 `captain_chart_table` 互動點；描述對話結束後才觸發事件（Interactable → DialogueManager → on_complete → WorldEventRunner） |
| 2 | 事件只在第一次完整完成時設定永久旗標 | 完成 | `captain_room_moving_item_seen` 由 actions 的 `set_flag` 在 `unlock_input` 之前寫入；中斷不寫。`WorldEventLibrary.find_triggered` 以 `once` + `complete_flag` + `requires.not_flags` 擋重播 |
| 3 | 物件真的發生位移，不是只改顏色 | 完成 | `tween_node` 動 TownProp 本體 `position`（+20px，1.0s，sine in-out）、`rotation` 0.06 rad → 0；route test 逐幀取樣位移 > 4px 才算 |
| 4 | 位移期間角色輸入被鎖定 | 完成 | `lock_input` → `Main._set_input_locked`；`busy` 條件加入 `events.is_running()`；事件中互動提示隱藏、方向鍵不移動、不能再次互動、F6／F7 提示「事件中無法存讀檔」 |
| 5 | 事件結束後角色、隊伍、陰影均正常 | 完成 | route test：解鎖後四人都在室內、跟隨鏈間距正常；事件不碰角色節點 |
| 6 | 離開再回來不會重播完整事件 | 完成 | 旗標存在時航海圖桌只播「已觀察」版本（對話版本陣列 `requires.flags`），物件停在原位（位置不存檔） |
| 7 | 換日不會清除神秘事件旗標 | 完成 | 單元測試 `advance_day` 後旗標與線索仍在；route test 在 Phase 5 休息換日、讀檔、v2 存檔遷移之後檢查 |
| 8 | 掉落物換日後仍正常重置 | 完成 | `daily_state` 規則不變：流理台每日旗標在同一個測試裡照常被清 |
| 9 | Shader 失效時遊戲仍可遊玩 | 完成 | `TownProp._apply_shader` 找不到或載入失敗只 `push_warning`，道具照常建立；單元測試用不存在的 shader 名稱驗證 |
| 10 | validate_map、unit test、route test 全部通過 | 完成 | 見第 5 節 |

## 2. 架構

```
Interactable(captain_chart_table) → DialogueManager → Main._on_dialogue_finished
  → QuestManager.apply_actions / notify_interact（Phase 3 流程不變）
  → WorldEventLibrary.find_triggered("interact_complete", id, scene_id, state, quests)
  → WorldEventRunner.run(event)
       lock_input → wait → tween_node ×3 → shader_param（0.8s 後還原）→ dialogue（segments ×4／5）
       → set_flag → clue → unlock_input
```

| 檔案 | 責任 |
|---|---|
| `scripts/events/world_event_runner.gd`（新） | 只吃 actions 陣列；外部能力全靠注入的 Callable（`resolve_target`、`lock_input`、`start_dialogue`、`set_flag`、`add_clue`）；每個阻塞步驟用 token 對應完成通知，`cancel()` 殺 Tween、還原 position／rotation／scale 與 Shader 原值、解鎖、發 `event_cancelled`；資料忘了 `unlock_input` 也會在結束時解鎖；`speed_scale` 供測試加速 |
| `scripts/events/world_event_library.gd`（新） | 載入 `assets/events/*.json`、`validate()`（必填欄位、once 事件必須在 unlock 前 set_flag）、`find_triggered()`、`dialogue_segments()`（多段反應，每段可帶 `requires`） |
| `assets/events/captain_room_moving_item.json`（新） | 事件資料（依 `PHASE6_EVENT_SPEC.json` 改為 runtime 格式：多了 `complete_flag`、`clue_id`） |
| `assets/events/clues.json`（新） | 線索定義（id、title、text） |
| `scripts/quest/quest_manager.gd` | 線索：`add_clue`／`has_clue`／`list_clues`／`clue_added`；取得狀態是永久旗標 `clue_<id>`，schema 維持 v3 |
| `scripts/ui/quest_hud.gd` | 日誌加「[線索]」段落、新線索 toast、`log_text()` |
| `scripts/props/town_prop.gd` | `shader` 選項（只套 Sprite2D 的 ShaderMaterial）、`set_shader_param`／`get_shader_param`、`shader_default()` 從原始碼讀 uniform 預設值 |
| `scripts/world/town_world.gd` | props `event_id` → `event_targets`、`get_event_target(id)` |
| `scripts/main.gd` | `_setup_events` 注入 Callable；`_try_trigger_event`；事件對話 `_start_event_dialogue`／`_play_event_segment`／`_advance_event_segment`；轉場開始時 `events.cancel()`；存讀檔與 `_on_interacted` 在事件中擋掉 |
| `scripts/interaction/interaction_controller.gd` | 隊伍輸入鎖定時不顯示「E」提示 |
| `assets/maps/captain_room_props.json` | 舷窗加 `shader: captain_room_waterlight`、`event_id: captain_room_waterlight`；繩圈加 `event_id: captain_mystery_item` 並移位（見第 6 節） |
| `assets/dialogue/captain_room.json` | 航海圖桌加「已觀察」版本；新增 `captain_room_moving_item_reaction`（segments：哥哥、冷靜哥、弟弟、妹妹；CC 段 `requires.flags: cc_joined`） |
| `tools/validate_map.py` | 新增事件檢查：場景、觸發互動點、`tween_node`／`shader_param` 目標的 `event_id`、對話 id（含 segments）、線索 id、once 的 set_flag 順序、lock／unlock 首尾 |
| `tests/run_tests.gd` | `test_phase6_event_data`、`test_phase6_clues`、`test_phase6_runner`（在場景樹裡以 5× 速度實跑一次完整事件與一次中斷） |
| `scripts/debug/route_test.gd` | `_phase6_event_checks`（第一次查看航海圖桌時）與 `_phase6_checks`（Phase 5 之後：旗標保留、不重播、中斷還原、重播完成、日誌線索、離開房間） |

事件執行器不認得哥哥、CC、船長或 `cap_rope_coil`；換成羅盤、紙張只改 `captain_room_props.json` 的 `event_id` 對應（或新增一個道具帶同一個 `event_id`）。

## 3. 舷窗水光 Shader

- 檔案：`assets/shaders/captain_room_waterlight.gdshader`（遠端交付，未改）。預設 `strength 0.08`、`speed 0.35`、`wave_amount 0.008`、`event_pulse 0`。
- 只套在舷窗 TownProp 的 Sprite2D；碰撞（無）、互動 Area2D、光暈、角色與陰影都不受影響。Nearest filter 由 Sprite2D 的 `texture_filter = 1` 決定。
- 事件的 `shader_param` 把 `event_pulse` 設為 1.0 維持 0.8 秒後還原；中斷時由執行器一併還原。route test 驗證事件中 `event_pulse > 0.5`、結束與中斷後為 0。
- headless 單元測試拿不到 uniform 預設值（RenderingServer 為 dummy），因此 `TownProp.get_shader_param` 在沒有覆寫時從 Shader 原始碼解析 `uniform float <name> = <值>;`。

## 4. 暫時內容（TEMP_DEMO_CONTENT，待作者確認）

| 項目 | 目前值 | 備註 |
|---|---|---|
| 事件目標物品 | `cap_rope_coil`（繩圈） | 技術預設；正式物品（羅盤、紙張…）只需改 props 的 `event_id` |
| 四人反應 | 哥哥「認真了認真了！剛剛它是不是動了？」／冷靜哥「超智障的……但我記得它剛剛不在那裡。」／弟弟「它是不是想出去玩？」／妹妹「先不要碰它。」 | 依提示詞建議句；每段前綴【TEMP_DEMO_CONTENT】 |
| CC 反應（在隊伍時） | 「……動いた、です。」 | 短句、句尾です |
| 航海圖桌「已觀察」版本 | 「海圖還攤在桌上。剛才那個東西，現在安安靜靜地待在新的位置。」 | 純功能性佔位 |
| 線索 | 標題「船長房間裡的東西動了」、內文「查看航海圖桌時，房間裡的東西自己移動了一小段。」 | `assets/events/clues.json` |
| 旗標／線索 id | `captain_room_moving_item_seen`／`captain_room_moving_item` | 與規格一致 |

## 5. 驗證

| 項目 | 結果 |
|---|---|
| `godot --headless --path . --import` | 通過（新 `.gdshader`、`assets/events/`、`scripts/events/` 進 class cache） |
| `python3 tools/validate_map.py` | 通過（四個場景 + 世界事件 1 個） |
| `godot --headless -s res://tests/run_tests.gd` | **305 通過、0 失敗**（Phase 5 基準 254；新增 51） |
| `--route-test` | **306 通過、0 失敗**（Phase 5 基準 267，本次開工前重跑基準確認 267／0；新增 39） |

route test 新增的檢查（Phase 3 段落內 15 項 + Phase 6 段落 22 項）：事件觸發、輸入鎖與提示隱藏、方向鍵不移動、位移 > 4px、
`event_pulse` > 0.5、四段反應（哥哥→妹妹）、旗標與線索、停在 +20px 並回正、pulse 還原、解鎖、隊伍完整；休息換日與讀檔後旗標保留、
已觀察版本、不重播、清旗標後重播 → 位移中 `cancel()` → 位置／角度／pulse 還原且旗標未寫、輸入解鎖；再觸發 → 五段反應（含 CC）→ 旗標寫入；
J 日誌有「[線索]」；離開船長房間。

新增截圖：`25_captain_room_before_event.png`、`26_captain_room_item_moving.png`、`27_captain_room_event_complete.png`、`28_quest_log_clue.png`。

碰撞與出口：沒有變更（繩圈本來就沒有碰撞；移位後仍不在出生點、出口與主要通道上；`validate_map.py` 路徑全部可達）。

## 6. 已知限制與作者待決定

1. **繩圈原本看不到**：Phase 3 起 `cap_rope_coil` 放在 (118,262) 且 `z_bias -1`，整個落在側桌貼圖（140×128，z 0）後面，畫面上從未出現；旁邊的木桶 (84,240) 也被側桌蓋住。本階段把繩圈移到書櫃與航海圖桌之間的空地 (176,176)，改由 Y-sort 繪製；木桶未動（不在事件範圍），請作者決定是否也要移位。
2. 位移方向固定往右 20px（規格值），第二次進房間繩圈會回到原位（物件位置不存檔，規格要求）。若希望「動過的東西留在新位置」，需要把「已完成時的靜態位置」寫進事件資料（例如 `settled_offset`），不建議存座標。
3. 事件的反應對話用既有單線 DialogueManager 依序播 4～5 段（每段換名字與頭像）；沒有做同時多人氣泡。資料格式（`segments`）已可支援未來插入更多段或條件段。
4. 舷窗水光在 640×360 上非常含蓄（strength 0.08）；若作者覺得看不出來，只需調 props 或 Shader 預設的 `strength`／`event_pulse` 倍率，不用改程式。
5. 事件期間 F5 日夜切換與 J 日誌被輸入鎖擋住；Esc 說明面板仍可開（與對話中行為一致）。
6. 任務日誌（J）是固定高度的 Label，兩個已完成任務加上「[線索]」段落後文字已頂到畫面底部（`28_quest_log_clue.png`）；之後線索再增加需要捲動或分頁，這是既有 UI 的限制，本階段未動 HUD 版面。
7. `cap_rope_coil.png`（55×40）不是透明背景：整張填滿烙進去的木地板底色（`docs/screenshots/phase6_review/03_cap_rope_coil_texture_6x_on_grey.png`），以前被側桌蓋住沒人看到；放到別的地板上會出現一塊方形色差。若正式物品仍用繩圈，請遠端重出 RGBA 透明背景版本。
8. 不在範圍：新 NPC、新素材、爸爸／船長真相、CC 好感度、每日餵食、任何正式劇情文字。
