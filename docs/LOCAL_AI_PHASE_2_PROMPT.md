# 給本地 AI 的 Phase 2 執行提示詞

你正在維護一個已完成 Phase 1 的 Godot 4 專案。請先閱讀：

```text
README.md
AGENTS.md
docs/PHASE_1_REPORT.md
docs/PHASE_2_PLAN.md
docs/ASSET_REQUEST.md
```

## 現況

Phase 1 已完成並通過測試：640×360、32×32 格線、連續 30×36 格潮根城、下層到上層可走通、四位角色可切換、其他角色以軌跡跟隨、四方向 idle/walk、站立微晃動，以及房屋、深水、樹皮牆和三個出口碰撞。

這一階段只做互動、對話與場景生命感，不要加入戰鬥、寵物、背包或複雜劇情。

## 素材位置

```text
assets/reference/incoming/A1_big_brother_sheet.png
assets/reference/incoming/A2_calm_brother_sheet.png
assets/reference/incoming/A3_sister_sheep_sheet.png
assets/reference/incoming/A4_younger_brother_sheet.png
assets/reference/incoming/A5_tree_heart.png
assets/reference/incoming/A6_bulletin_board.png
assets/reference/incoming/A7_canopy_gate.png
assets/reference/incoming/A8_flag_banner.png
assets/reference/incoming/A9_empty_harbor_berth.png
assets/reference/incoming/A10_fence.png
assets/reference/incoming/A11-A19_tileset_supplement_reference.png
```

圖片可能仍是參考尺寸，請沿用既有 `tools/build_assets.py` 與驗證腳本整理，不要修改 48×64 角色格、32×32 地圖格或碰撞規格。

## 實作要求

### 互動系統

1. 使用現有角色 `InteractionArea` 與物理層 3 Interactable。
2. 建立清楚的 `Interactable` 基底腳本或介面。
3. 玩家按 E 時，選擇前方或附近最近的可互動物件。
4. 顯示 B2 互動提示圖示，沒有目標時隱藏。
5. 互動物件必須發送 signal，不能把對話處理寫進 PlayerCharacter。
6. 對話中鎖定角色移動，但保持隊伍、鏡頭與位置。

### 對話框

建立可重複使用的 `scenes/ui/dialogue_box.tscn`，包含 Panel、NameLabel、DialogueLabel、Portrait 預留節點與 ContinueHint。最低功能是名稱、文字、逐字顯示、E 推進、結束隱藏與自動換行。

建立簡單 `DialogueManager`，但不要提前建立任務樹或分支劇情框架。

### 必須接上的物件

- 公告欄：一段日常公告。
- 樹心：一段含蓄神秘的文字，不揭露父親原型的結局。
- 左側橋頭：平原與森林尚未開放。
- 右側船港：海底根系尚未開放。
- 上方封鎖門：雲端樹冠尚未開放。

### 場景動畫

完成燈籠 4 幀循環、水面 4 幀循環、旗幟擺動、雲霧水平位移，以及至少一組葉片、蝴蝶或螢火蟲粒子。動畫只修改視覺節點，不可修改碰撞、角色世界座標或 Y-sort 基準。

### 日夜 Debug 切換

提供 F5：Day → Dusk → Night → Day。使用 CanvasModulate、燈光或既有色調節點處理。不要建立三份地圖，也不要讓日夜狀態改變碰撞。

## 驗收測試

1. 靠近公告欄出現提示，離開後消失。
2. 按 E 能開啟、推進並關閉對話。
3. 對話中 WASD 不會移動主要角色。
4. 公告欄、樹心、三個出口都能互動。
5. 快速移動與隊伍跟隨仍然正常。
6. 對話前後切換 1～4 角色，隊伍不傳送、不消失。
7. 燈籠、水面、旗幟與雲霧有循環動畫。
8. F5 切換三種日夜狀態，地圖碰撞不變。
9. Godot headless import 無 parser error。
10. 所有既有 Phase 1 測試仍然通過。

完成後回報建立與修改的檔案、測試指令與結果、互動截圖、對話截圖、日夜三張截圖，以及仍待補齊的素材。
