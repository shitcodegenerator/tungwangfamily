# 給本地 AI：Phase 5 每日系統與地圖垂直切片

請先讀：

- docs/PHASE_5_PLAN.md
- docs/TILEMAP_AND_MAP_ASSET_TUTORIAL.md
- assets/reference/incoming/PHASE5_ASSET_MANIFEST.json

## 執行分支

請從目前 master 最新 commit 建立 Phase 5 分支，不要覆蓋作者正在進行的其他分支。所有新美術先並存，不要刪除舊 atlas 或舊 props。

## 5A 每日系統

1. GameState 的 schema_version 升為 3。
2. 新增：

~~~gdscript
var day: int = 1
var day_seed: int = 1
var daily_state: Dictionary = {}
~~~

3. from_dict() 支援 v1／v2 遷移；舊存檔缺少欄位時使用 day 1、空 daily_state，不能清除既有旗標、任務、背包或 CC。
4. 新增 advance_day()，只在共享家庭屋休息確認後呼叫一次。
5. 新增 reset_daily_state() hook；先清除 daily_state 的示範欄位，不要自行設計 CC 每日任務。
6. F5 若目前是日夜測試鍵，請保留測試用途或改成明確的 debug 行為，不可讓 F5 偷偷增加 day。
7. 休息流程：互動→詢問→取消不變→確認→淡出→day +1→存檔→早晨轉場→回到家庭屋。

## 5B 地圖美術

- 新 atlas：assets/tilesets/town_visual_refresh_tiles_32.png，256×128，8×4，每格 32×32。
- 新 props 位於 assets/props/town_refresh/。
- 先只替換下層樹根廣場的 GroundTileMap 與三個物件：共享家庭屋、早餐攤、燈籠；再加入心形噴泉和根拱門。
- 不要直接把大張 PNG 當成整張地圖背景；使用 TileMap 和 props 節點。
- 碰撞資料、出口、NPC 互動範圍先保持不變。
- 為 tile_style: "town_refresh" 增加鄰接判斷，不能只用固定座標貼中心 tile。
- 大型 props 使用底部中心作為 origin，碰撞與圖片分開。

## 匯入與驗證

~~~bash
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . --quit-after 150
~~~

請新增測試：

- v2 存檔能遷移成 v3。
- 取消休息不增加 day。
- 同一次休息只增加 1 天。
- 重新啟動後 day 與 daily_state 正確。
- 永久旗標、CC、任務和背包不會被每日重置清掉。
- 新 atlas 每格都是 32×32，沒有可見白邊；原有地圖所有可走格仍可到達出口。
- props 的底部接地、Y-sort、碰撞和互動範圍正確。

最後請回報：schema 遷移、休息流程、每日 hook、地圖替換範圍、測試數量、截圖，以及仍待作者確認的視覺問題。

