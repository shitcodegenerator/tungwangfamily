# 給本地 AI 的 Phase 3 執行提示

你正在 `tungwangfamily` Godot 4 專案中執行 Phase 3。請先閱讀：

1. `README.md`
2. `docs/AGENTS.md`（若存在）
3. `docs/PHASE_1_REPORT.md`
4. `docs/MANUAL_TEST_GUIDE.md`
5. `docs/PHASE_3_DECISIONS.md`
6. `docs/PHASE_3_PLAN.md`
7. `docs/ASSET_REQUEST.md`

## 非常重要的內容邊界

- 不要自行創作正式章節劇情、父親離世事件、Boss、重要戰鬥、乾媽家庭傷痛或真實童年回憶。
- 本階段只能建立中性的 `TEMP_DEMO_CONTENT` 測試任務與測試對話，並在資料檔和 UI 中清楚標記。
- 如果實作過程需要新增正式故事、角色秘密或 Boss，請停止並向作者提問，不要猜測。
- 父親原型是「國王企鵝船長」，不是海獺漁夫。
- 媽媽與乾媽住在同一間共享家庭屋，程式 ID 使用 `family_home`，不要拆成兩棟房子。

## 本階段要完成

1. 建立集中式 `GameState`。
2. 建立 JSON 存檔／讀檔，使用 `user://save_01.json`，帶 `schema_version`。
3. 建立場景轉換服務，支援中央小鎮、`family_home`、`captain_room` 雙向進出。
4. 加入國王企鵝船長與市集老龜 NPC，支援站立待機、碰撞、E 互動、對話和頭像。
5. 建立資料驅動的最小任務系統，狀態至少有 `available`、`active`、`completed`。
6. 用公告欄啟動一個中性的測試任務：公告欄 → 共享家庭屋的中性互動點 → 船長房間的中性互動點 → 回報完成。
7. 加入最小任務 UI，不要重做現有 HUD 或對話框。
8. 補上自動測試、手動測試文件和 Phase 3 報告。

## 建議檔案方向

請依專案既有命名和資料夾慣例調整，不要盲目照抄：

- `assets/quests/phase3_demo_quest.json`
- `assets/dialogue/phase3_demo_dialogue.json`
- `scripts/state/game_state.gd`
- `scripts/save/save_manager.gd`
- `scripts/quest/quest_manager.gd`
- `scripts/world/scene_router.gd`
- `scenes/world/shared_family_house.tscn`
- `scenes/world/captain_room.tscn`
- `scenes/characters/npcs/king_penguin_captain.tscn`
- `scenes/characters/npcs/old_turtle.tscn`

素材參考檔在 `assets/reference/incoming/`。它們是第一版美術方向與切圖來源，不要直接假設每一格已經是可直接上線的精準 Sprite；請先檢查尺寸、透明邊界和切格方式，再依專案既有匯入規則使用。

## 修改規則

- 先檢查現有場景、腳本、輸入映射和自動測試。
- 保留既有節點、地圖布局、角色位置、碰撞和視覺調整；不要整個重建主場景。
- 一次完成一個可測試的小功能，每個小功能完成就跑測試。
- 優先擴充現有 `dialogue_manager.gd` 和互動介面，不要建立第二套互動系統。
- 對話、場景轉換、任務、存檔的輸入優先序要一致：對話／轉場鎖定移動和角色切換；Esc 面板不能在對話中搶輸入。
- 不要加入戰鬥、寵物、裝備、經驗值或 Boss。

## 完成前必測

- 原有 Phase 1／2 測試全部通過。
- 公告欄可啟動任務，任務 HUD 可顯示目前目標。
- 共享家庭屋能進出，四人隊伍和玩家位置不遺失。
- 船長房間能進出，國王企鵝船長與老龜可互動。
- 完成任務後存檔，重新啟動再讀檔，任務狀態與完成旗標仍存在。
- 讀取損壞或不存在的存檔時，遊戲能安全回到新遊戲狀態並顯示簡短提示。
- 產出 `docs/PHASE_3_REPORT.md`，列出實際完成、未完成、測試結果、暫時內容和下一步。
