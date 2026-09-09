# 文件索引（每個主題只有一份現行文件）

更新：2026-09-07（Phase 8.5）。找不到的東西先查這裡；「歷史歸檔」只供追溯，內容可能已被現行文件推翻。

## 現在必讀

| 主題 | 現行文件 |
|---|---|
| 專案入口與不可變原則 | `AGENTS.md` |
| 現行規格（技術、內容邊界、責任分工、schema、素材、驗證） | `docs/CURRENT_PROJECT_SPEC.md` |
| 內容邊界原文 | `docs/PHASE_3_DECISIONS.md` |
| props 顯示層級與擺放規則、驗證器代碼 | `docs/RENDERING_AND_PLACEMENT_SPEC.md` |
| 待決策／已決策 | `docs/OPEN_DECISIONS.md` |
| 給遠端規劃 AI：主城改平面城鎮的地圖需求（D-013） | `docs/NOTES_FOR_PLANNER_FLAT_TOWN.md` |
| 踩過的坑與產出檢查清單 | `docs/PRODUCTION_NOTES.md` |
| 素材風格鎖定 | `docs/ART_STYLE_LOCK.md` |
| 目前 Phase：8.5 穩定化 | 計畫 `docs/PHASE_8_5_PROJECT_STABILIZATION_PLAN.md`、報告 `docs/PHASE_8_5_REPORT.md` |
| 上一個 Phase：8 美術完成 | 計畫 `docs/PHASE_8_ART_COMPLETION_PLAN.md`、交付 `docs/PHASE_8_ART_ASSET_DELIVERY.md`、報告 `docs/PHASE_8_REPORT.md`、盤點 `docs/PHASE_8_ASSET_AUDIT.md`／`_TABLE.md`、提示詞 `docs/LOCAL_AI_PHASE_8_PROMPT.md` |
| 素材 manifest 與例外 | `assets/reference/incoming/PHASE8_ART_ASSET_MANIFEST.json`、`ASSET_PREFLIGHT_ALLOWLIST.json`；地圖驗證例外 `assets/maps/validation_allowlist.json` |
| 地圖圖例 | `assets/maps/tile_legend.json` |

## 作者教學

| 主題 | 現行文件 |
|---|---|
| 零基礎：安裝、座標、Aseprite、畫一個物件放進場景、改建築、錯誤對照 | `docs/PHASE_7_SCENE_EDIT_TUTORIAL.md` |
| 只補 Phase 8 差異：拆層、TileMap v3、家具層級 | `docs/PHASE_8_SCENE_ART_TUTORIAL.md` |
| 手動測試流程（自動化測不到的手感與視覺） | `docs/MANUAL_TEST_GUIDE.md` |
| 代表性畫面（golden，11 張） | `docs/screenshots/golden/` |

## 工具

| 命令 | 用途 |
|---|---|
| `python3 tools/verify_phase.py --fast` / `--full` | 單一驗證入口 |
| `python3 tools/validate_map.py [--audit]` | 地圖與擺放硬檢查 |
| `python3 tools/verify_assets.py` | 素材 preflight |
| `python3 -m unittest discover -s tools/tests` | 驗證器夾具 |
| `python3 tools/build_assets.py [--clean --verify]` | 五代素材 builder 單一入口 |
| `tools/audit_props_phase8.py`、`contact_sheet_phase8.py`、`montage_phase8.py`、`snapshot_props_trial.py` | 盤點表、對照表、拼圖、試值 |

## 歷史歸檔（不再更新）

| 目錄 | 內容 |
|---|---|
| `docs/archive/phase_01`～`phase_07` | 各 Phase 的計畫、報告、本地 AI 提示詞、素材 README、Phase 4.6 動畫與洞窟、Phase 7 給規劃 AI 的待辦 |
| `docs/archive/tutorials` | `HOW_TO_EDIT_SCENES_AND_MAP_ASSETS.md`、`TILEMAP_AND_MAP_ASSET_TUTORIAL.md`（已被 Phase 7 教學取代） |
| `docs/archive/asset_requests` | Phase 1～5 的素材需求單、視覺簡報與 `asset_brief/` 圖 |
| `docs/screenshots/phase8_baseline`、`phase8_v3`、`phase7_review`、根目錄 `*.png` | 歷史截圖（不再新增；route test 截圖改放 `build/`） |
