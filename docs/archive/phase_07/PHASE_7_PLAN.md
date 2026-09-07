> ARCHIVED（Phase 8.5 歸檔，2026-09-07）：歷史文件，只供追溯。現行規格：docs/CURRENT_PROJECT_SPEC.md；索引：docs/INDEX.md；待決策：docs/OPEN_DECISIONS.md。

# Phase 7：視覺基礎修正與日誌可讀性

基準：`master` commit `4cbaae0f94380c02a08aca1bf1afeb878b9ed321`

分支：`codex/phase-7-visual-foundation`

## 這一階段的目標

Phase 6 已經讓船長房間具備可重複觸發規則、世界事件、線索與 Shader。Phase 7 先把玩家每天都會看到的三件事整理好：

1. 船長房間的繩圈是真正的透明 PNG，事件仍然使用原本的 `event_id`。
2. 任務／線索日誌可以在內容超出視窗時上下滑動，不再把線索截在面板底部。
3. 修正樹屋屋頂與根拱門的顯示層級與接地視覺，讓角色與跟隨者不會看起來穿進屋頂或卡在拱門邊；不改出口、ASCII 地圖、碰撞規則與事件流程。

這個 Phase 不新增正式劇情、Boss、NPC、父親真相、私人回憶或新的角色外觀。所有 Phase 6 的暫時文字仍然是暫時文字，等作者提供正式內容才替換。

## 固定規格

| 項目 | 必須維持 |
| --- | --- |
| 基礎解析度 | 640×360，Nearest，Compatibility renderer |
| 世界格 | 32×32；角色仍以腳底錨點接地 |
| 角色 | 原有四人與 CC 的貼圖、比例、陰影與命名不變 |
| 船長房間事件 | `captain_chart_table` → `captain_mystery_item` → 線索；不可硬編碼另一個節點名稱 |
| 日誌快捷鍵 | 保留 `J` 開關；對話、轉場、事件輸入鎖優先 |
| 存檔 | 不改 `schema_version`；不把 UI 滾動位置寫入存檔 |
| 日夜／每日 | 保留現有「回共享家庭屋休息才進入下一天」與每日掉落重置語意 |

## 工作順序

### P7.0 基準檢查

本地 AI 先在乾淨 checkout 上執行：

```bash
git fetch origin
git checkout -B phase-7-visual-foundation origin/codex/phase-7-visual-foundation
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
```

先用 README 的 `--snapshot` 截取下列基準畫面，確認物件確實看得到再修改：

- `captain_room`：繩圈、船長房間、J 日誌線索
- `tide_root_town`：共享家庭樹屋、根拱門、四人跟隨隊伍

### P7.1 繩圈透明修正

已提供的素材：

- `assets/props/cap_rope_coil.png`
- `assets/reference/incoming/PHASE7_ASSET_MANIFEST.json`

本素材是 55×40、RGBA、透明背景、10 色的像素圖。它只替換原本帶有木地板背景的同名檔案；不得另建一個 `cap_rope_coil_v2` 再修改 JSON，避免事件對不到。

本地 AI 實作要求：

1. 覆蓋同名 PNG 後讓 Godot 重新匯入；不可手寫或複製舊 `.godot/imported` 快取。
2. 保留 `assets/maps/captain_room_props.json` 中 `event_id: captain_mystery_item`、位置 `[176,176]` 與原本事件資料。
3. 重新驗證 `captain_chart_table` 互動、繩圈位移、四人反應、線索出現與重進房間時的暫時位置行為。
4. 用 PNG 檢查腳本確認檔案開頭是 `89504e470d0a1a0a`、尺寸 55×40、含 alpha 且不是整張不透明。

### P7.2 任務／線索日誌滑動

目前 `QuestHud` 把全部內容放在固定高度的 `Label`，Phase 6 新增線索後會超出面板。請在不改 `QuestManager` 資料格式的前提下，把現有 Log 內容放入可裁切的 `ScrollContainer` 或等效元件。

必要行為：

- `J` 開啟／關閉日誌，既有標題、任務狀態、目標與線索文字保持不變。
- 內容未超出面板時不顯示多餘的捲軸或箭頭。
- 內容超出面板時支援滑鼠滾輪，以及 `ui_up`／`ui_down`；可視範圍不應露出面板外。
- 日誌打開時焦點不應把角色移動、互動或 F5/F6/F7 吃掉；對話、事件、轉場與 Esc 面板的優先序照現有規則。
- 關閉再開啟時可回到上次瀏覽位置或頂端，但不要寫入存檔；兩者擇一並在報告記錄。
- `J` 日誌內容在 640×360 與整數倍視窗都不能與右上角目標、Toast 或面板邊框重疊。

建議節點結構（可依現有場景調整，不要整張 `.tscn` 無條件覆蓋）：

```text
LogPanel
└─ Margin
   └─ ScrollContainer
      └─ Log (Label 或 RichTextLabel)
```

### P7.3 樹屋與根拱門顯示修正

修改範圍限於 `assets/maps/tide_root_town_props.json` 內既有 props 的視覺欄位：

- `town_refresh/shared_family_treehouse_v2`
- `town_refresh/root_archway_v2`

先用 `foot_x`／`foot_inset`／`z_bias` 校正貼圖相對腳底錨點的位置，再考慮調整 prop 的 `x`／`y`。不要改：

- `tide_root_town.txt` 的牆、路、橋與出口字元
- `collision`、`collision_boxes` 的尺寸與數值
- 三個出口與兩個室內傳送門
- 角色 Sprite 的縮放、中心點、陰影或行走表

驗收重點：

- 四位角色輪流當主控，在樹屋前後走動，腳底不浮起、不穿過屋頂底緣。
- 四位角色與跟隨者通過根拱門時，隊伍不會被純視覺貼圖擋住或看起來滑進樹根。
- 所有原有道路仍然可走；碰撞偵測結果與 Phase 6 相同。
- 只用最小偏移修正，不為了遮住角色而把大型建築整張放大。

### P7.4 地圖畫面品質檢查

這次先不重做整張 tileset。請對可見畫面做四項檢查：

1. 草地、水岸、石路與木道接縫不能出現黑縫、透明縫或明顯硬切。
2. 大型 prop 的底部接地線要落在合理的 32 px 網格附近，不把碰撞盒當成貼圖底部。
3. 遠景裝飾使用較低 `z_bias`，角色與可行走路面使用既有 Y-sort 規則。
4. 不新增第二套角色比例或陰影。任何新圖片都要先通過 `docs/ART_STYLE_LOCK.md` 的尺寸、透明度、色盤與錨點規則。

發現不能靠 props 小修解決的問題，記到 Phase 7 報告的「後續美術重製」而不是偷偷改 TileMap。

## 驗收與回報

本地 AI 完成後必須交付：

```bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

另外新增至少五個截圖：

1. 船長房間：繩圈事件前。
2. 船長房間：繩圈移動中，確認透明背景。
3. 船長房間：事件完成後打開日誌，線索可見。
4. 主城：共享家庭樹屋與四人隊伍。
5. 主城：根拱門通行中，確認角色與跟隨者沒有視覺穿插。

回報分成「已完成」與「需作者決定／後續」兩段，並列出每個修改檔案、測試結果、截圖位置、PNG manifest 檢查結果與仍存在的已知限制。
