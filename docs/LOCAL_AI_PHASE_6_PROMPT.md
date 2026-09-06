# 給本地 AI：Phase 6 船長房間第一個異常事件

請以 master 最新 commit 0a0c0b2b19204ca73ea50051c6ca73dff0da3397 為基準。
先閱讀：

    docs/PHASE_5_REPORT.md
    docs/PRODUCTION_NOTES.md
    docs/PHASE_6_PLAN.md
    docs/ART_STYLE_LOCK.md
    docs/HOW_TO_EDIT_SCENES_AND_MAP_ASSETS.md
    assets/reference/incoming/PHASE6_EVENT_SPEC.json
    assets/reference/incoming/PHASE6_ASSET_MANIFEST.json

## 執行前規則

1. 先確認 git status；不要覆蓋作者未提交的修改。
2. 從 master 最新版本建立自己的 Phase 6 分支。
3. 先跑既有 validate_map、unit tests、route test，記錄基準數字。
4. 不重新生成四位主角、CC、阿嬤或船長的 sprite。
5. 不新增 NPC、不新增 Boss、不寫爸爸離世劇情。
6. 舊素材、舊存檔欄位與 Phase 1～5 功能不可刪除。
7. 每日掉落物重置規則維持 Phase 5：只清 daily_state，不清永久 flags。

## 一、通用事件執行器

請新增一個資料驅動的 WorldEventRunner，例如：

    scripts/events/world_event_runner.gd

它不能依賴角色、戰鬥或特定 NPC。至少支援：

    lock_input
    wait
    tween_node
    dialogue
    shader_param
    clue
    set_flag
    unlock_input

事件期間：

- 玩家不能移動。
- 不能再次觸發同一事件。
- 不能切換場景。
- 不得寫入物件正在移動中的暫態。

如果事件中斷：

- 還原物件原始 position、rotation、scale。
- 不寫入完成旗標。
- 清除輸入鎖。
- 下次互動可以安全重播。

## 二、船長房間事件

現有互動點：

    captain_chart_table

請沿用現有 Interactable → DialogueManager → on_complete 的流程，
不要把正式劇情硬寫在 TownProp 或角色腳本。

第一版事件目標使用既有 cap_rope_coil。
請以事件 target ID 尋找它，不要把 cap_rope_coil 寫死在通用事件執行器裡。
未來作者如果指定羅盤、紙張或其他物件，只修改資料。

事件效果：

1. 玩家按 E 調查航海圖桌。
2. 原本互動文字結束。
3. 鎖定輸入。
4. 物件晃動約 0.18 秒。
5. 物件平滑移動 16～24px，耗時約 1 秒。
6. 物件旋轉約 0.06 弧度後回正。
7. 舷窗水光短暫變亮。
8. 播放四位角色的短反應。
9. 寫入 captain_room_moving_item_seen。
10. 寫入 clue captain_room_moving_item。
11. 解鎖輸入。

對話文字先使用 TEMP_DEMO_CONTENT，不能當成正式劇情。
CC 若在隊伍中仍維持短句並以「です」結尾。

建議暫時反應：

    哥哥：認真了認真了！剛剛它是不是動了？
    冷靜哥：超智障的……但我記得它剛剛不在那裡。
    弟弟：它是不是想出去玩？
    妹妹：先不要碰它。

如果既有 DialogueManager 不適合事件中插入多人反應，
可先使用單一短對話完成驗收，但要保留未來可插入多段 dialogue 的資料格式。

## 三、事件旗標與存檔

使用永久 flags：

    captain_room_moving_item_seen

不要放入 daily_state。

換日後：

- 事件完成旗標保留。
- 線索保留。
- CC 加入狀態保留。
- 掉落物與每日示範旗標照 Phase 5 規則重置。

不要把 object position、Tween 狀態、event running 寫進 GameState。

## 四、舷窗水光 Shader

使用：

    assets/shaders/captain_room_waterlight.gdshader

只套用在舷窗或舷窗附近環境節點，不要套用到：

- 角色。
- 角色陰影。
- CollisionShape2D。
- 互動 Area2D。
- 事件主要目標物件。

預設強度應該低。Shader 關閉或不支援時，船長房間仍可遊玩。
事件完成後要將 event_pulse 還原為 0。

## 五、地圖與美術限制

本階段不重畫整張船長房間。
若需要新增節點，維持：

    Ground TileMap
    Wall／ceiling TileMap
    Props
    Collision
    Interactable
    Event
    Foreground／Y-sort

所有新增物件：

- 以 32px 網格定位。
- 底部中央接地。
- 圖片與碰撞分離。
- 不遮住出口、出生點和主要通道。
- 不加入新的角色陰影。

不要把新的整張背景 PNG 當作地圖。

## 六、測試

請新增測試：

1. 事件資料可以載入。
2. captain_chart_table 可以觸發事件。
3. 事件完成後旗標為 true。
4. 事件只完整播放一次。
5. 換日不會清除事件旗標。
6. daily_state 仍會重置。
7. 事件中輸入被鎖定。
8. 事件中斷會還原物件 transform。
9. 事件完成後可以離開船長房間。
10. 舊 Phase 1～5 測試不回歸。

驗證順序：

    godot --headless --path . --import
    python3 tools/validate_map.py
    godot --headless --path . -s res://tests/run_tests.gd
    route test

請產生至少以下截圖：

    25_captain_room_before_event.png
    26_captain_room_item_moving.png
    27_captain_room_event_complete.png

## 七、回報格式

回報必須包含：

- 使用的基準 commit。
- 新增與修改的檔案。
- 單元測試數量與失敗數。
- route test 數量與失敗數。
- 是否有場景碰撞或出口變更。
- 三張事件截圖。
- 已知視覺問題。
- 尚待作者決定的物品名稱與正式對話。

完成後先回報，不要自行把未經作者確認的正式劇情文字寫入主線。

