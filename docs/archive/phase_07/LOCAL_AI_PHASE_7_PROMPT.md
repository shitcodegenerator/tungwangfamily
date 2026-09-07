> ARCHIVED（Phase 8.5 歸檔，2026-09-07）：歷史文件，只供追溯。現行規格：docs/CURRENT_PROJECT_SPEC.md；索引：docs/INDEX.md；待決策：docs/OPEN_DECISIONS.md。

# 給本地 AI 的 Phase 7 執行提示

請先不要直接改 `master`。先執行：

```bash
git fetch origin
git checkout -B phase-7-visual-foundation origin/codex/phase-7-visual-foundation
```

接著完整閱讀：

1. `AGENTS.md`
2. `docs/PRODUCTION_NOTES.md`
3. `docs/archive/phase_06/PHASE_6_REPORT.md`
4. `docs/screenshots/phase6_review/README.md`
5. `docs/PHASE_3_DECISIONS.md`
6. `docs/archive/phase_07/PHASE_7_PLAN.md`
7. `assets/reference/incoming/PHASE7_ASSET_MANIFEST.json`

## 你的實作任務

### A. 套用透明繩圈

- 將分支上的 `assets/props/cap_rope_coil.png` 視為同名正式替換檔。
- 不要改成新檔名，也不要刪除 `event_id: captain_mystery_item`。
- 重新匯入 Godot 資源，不要依賴舊 `.godot/imported` 快取。
- 用檔案檢查確認：PNG signature、55×40、RGBA、含透明像素、不是整張不透明、沒有木地板背景。
- 不要把角色陰影畫進繩圈；角色陰影仍由既有角色場景處理。

### B. 任務／線索日誌加入滑動

- 保留 `J` 開關、既有任務與線索文字，以及 `QuestManager` 目前 schema。
- 修改 `scenes/ui/quest_hud.tscn` 與 `scripts/ui/quest_hud.gd` 時，以現有節點為基礎增量修改。
- 將 Log 放入可裁切的 `ScrollContainer`（或功能完全相同的元件）。
- 日誌內容不足時，不顯示無意義的捲軸；內容超出時，滑鼠滾輪和 `ui_up`／`ui_down` 都能移動。
- 對話、事件、轉場、Esc 面板的輸入優先序不能被 J 日誌破壞；輸入鎖時不能意外打開日誌。
- 不把 scroll offset 寫入 `GameState` 或存檔。
- 測試 640×360 與整數倍視窗，確認不超出面板、不蓋住目標 HUD、Toast 或邊框。

### C. 修正主城兩個大型 prop 的視覺遮擋

只調整 `assets/maps/tide_root_town_props.json` 的既有：

- `town_refresh/shared_family_treehouse_v2`
- `town_refresh/root_archway_v2`

優先使用 `foot_x`、`foot_inset`、`z_bias`，必要時才微調 `x`／`y`。保留所有出口、ASCII 地圖、`collision`、`collision_boxes`、互動區與傳送門。不要改角色貼圖或比例。

完成後用 `--snapshot` 和實際遊玩檢查：四位角色輪流主控、跟隨者通過樹屋前與根拱門，腳底接地且不被大型貼圖錯誤遮住。若發現需要改碰撞才能修正，先停在報告中提出，不要自行擴大範圍。

### D. 做一次最小視覺 QA

- 不重做整張 TileMap。
- 檢查主城目前可見的草地／石路／水岸／木道接縫；能用既有 props 或 tile legend 小修就修，必須重畫整組的問題寫入後續清單。
- 不新增角色、NPC、Boss、正式劇情或新的道具系統。
- 不產生第二套人物外觀。任何新圖先依 `docs/ART_STYLE_LOCK.md` 檢查透明背景、色盤、尺寸、錨點和陰影。

## 驗證

```bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

PNG manifest 至少用以下方式驗證（可用等效工具，但要把結果寫進報告）：

```bash
file assets/props/cap_rope_coil.png
identify -format 'size=%wx%h channels=%[channels] opaque=%[opaque] colors=%k\n' assets/props/cap_rope_coil.png
```

## Commit 與回報格式

完成後只推到 `phase-7-visual-foundation`，不要直接推 `master`。回報必須分成：

### 已完成

- 每個修改／新增檔案及其用途。
- `validate_map.py`、Godot tests、route test 的結果。
- PNG manifest 的實際檢查結果。
- 截圖檔名與每張圖驗證的事情。

### 需本地 AI 實作／需作者決定

- 仍未完成的項目與原因。
- 需要作者提供正式文字或素材的地方。
- 不能靠本 Phase 安全修正的地圖問題。
- 不要把推測性的劇情、Boss 或私人回憶寫進資產。
