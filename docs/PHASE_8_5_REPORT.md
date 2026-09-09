# Phase 8.5 專案穩定化 — 本地執行報告

日期：2026-09-07　分支：phase-8-art-complete（基於 codex/phase-8-art-assets-v3 3847042 之後）
計畫：`docs/PHASE_8_5_PROJECT_STABILIZATION_PLAN.md`。依計畫第 6 節格式回報。

## 1. 已完成

### 8.5-A 凍結基準與 Phase 8 接線（commit 97f504d、a54dd93）

見 `docs/PHASE_8_REPORT.md` 第二批：20 張 v3 PNG 接線、tileset 576×320、tile_style_rows [0,35]、樹屋 foot_inset 16、拱門拆層、船長房 15 件 v3；上層 `c` 一律畫樹冠（作者決定）。route test 317、單元測試 355。

### 8.5-B 擺放硬檢查（`tools/validate_map.py` ＋ `tools/validators/`）

| 檔案 | 內容 |
|---|---|
| `tools/validators/common.py` | Scene／Finding 資料結構、與 town_world 相同的封鎖格計算（含 collision_boxes）、BFS、站位候選 |
| `tools/validators/legend.py` | 讀 `assets/maps/tile_legend.json`；MAP-P006 未知字元／該樣式無 mapping |
| `tools/validators/placement.py` | MAP-P001 碰撞頂端對齊（提示兩個候選高度，伸進去那列有站位就建議少封一列）、P002 保留格（NPC 腳底格、出生點、入口、出口、連接點、返回點、投擲物、Boss、`reserved_tiles`）、P003 互動站位（NPC 面前與左右；物件自身／四方／南二格）、P004 出入口與邊界、P005 連通、`--audit` 用的封鎖格報告 |
| `tools/validators/render.py` | MAP-P007 render_mode 必填與一致性、split 成對同錨點；`suggest_render_mode` 只給 audit 與遷移用 |
| `tools/validators/content.py` | Boss 邊界、對話、任務目標、傳送門目標、世界事件（Phase 3～6 既有檢查搬入，代碼 MAP-C00x） |
| `tools/validators/allowlist.py` | `assets/maps/validation_allowlist.json`：id／rule／scene／subject／reason／owner／expires_phase，到期失效（MAP-A001）、未用提醒（MAP-A002） |
| `tools/validate_map.py` | 唯一入口；預設任何違規非 0；`--audit` 列全部違規、每個 props 封了哪些格、建議 allowlist 條目 |
| `tools/tests/test_validators.py` | 14 個夾具：餐桌搬到走道、互動點被圍住、未知字元、樣式無 mapping、NPC 站位被碰撞覆蓋、花圃 116 回歸、碰撞不對齊、返回點在碰撞內、缺 render_mode、ysort 帶 z_bias、split 不成對、建議、allowlist 到期／缺欄位、真實資料零違規 |

錯誤訊息固定含規則代碼、場景、物件（貼圖＋座標）、格子與修正方向，例如：
`MAP-P001 [tide_root_town] town_refresh/flower_herb_bed_v2(272,1088) @(8, 30)：碰撞頂端 y=972 不在 32 格線（12px 伸進上一列） → collision 高改 96（少封一列）：伸進去的那一列有站位／保留格 [(9, 30), (10, 30)…]；128 會繼續封住它們`

### 8.5-C 單一顯示層級（`render_mode`）

- 78 個現役 props 全部宣告 `render_mode`：ground 3（地毯、池面 ×2）、back 26（牆掛物、門窗、雲、藤蔓、樹台、樹心、五棟房屋立面、樹屋、上層閘門）、ysort 47、split 2（拱門 base／canopy）。
- `z_bias` 欄位自資料檔移除；`TownWorld.z_index_for(entry)` 只看 render_mode（ground／back −1、ysort 0、split base 0／canopy 1），舊資料退回 z_bias 並 push_error。
- 17 個碰撞頂端不在格線的 props 改為「往上對齊、封鎖格不變」的高度（樹屋 64、早餐攤 132、港口木箱 96、上層閘門 64、拱門兩腳 58、家庭屋 5 件、船長房 6 件），路徑規劃與實體碰撞一致；route test 317 通過。allowlist 目前 0 筆。
- `docs/RENDERING_AND_PLACEMENT_SPEC.md`：四模式、參數唯一職責、幾何事實、規則代碼、現役實例、固定流程。

### 8.5-D 文件唯一真相

- 新增 `docs/CURRENT_PROJECT_SPEC.md`、`docs/INDEX.md`、`docs/OPEN_DECISIONS.md`（12 筆，含 D-001～D-003 三項已定案）。
- `AGENTS.md` 改為短入口＋不可變原則；`README.md` 更新 Phase 摘要與驗證命令。
- 32 份歷史文件 `git mv` 到 `docs/archive/phase_01～07`、`tutorials`、`asset_requests`（含 `asset_brief/`），檔頭加 ARCHIVED；全 repo 27 個檔案的連結改寫到新路徑，不刪內容、不改 git history。
- 現行教學（Phase 7 零基礎版、Phase 8 差異版）與 `PRODUCTION_NOTES.md` 改為 render_mode 說明並加入 Phase 8／8.5 教訓；`LOCAL_AI_PHASE_8_PROMPT.md` 加附註。

### 8.5-E 素材與圖例最小防護

- `assets/maps/tile_legend.json`：16 個字元的名稱、可走性、支援樣式。`MapParser.WALKABLE_CHARS／SOLID_CHARS` 改為 static var 從檔案載入；`TileLibrary` 的 fallback 改 push_error；`tests/suites/placement_tests.gd` 逐字元逐樣式確認不落到 fallback。
- `tools/verify_assets.py`：執行期目錄只准 PNG（SVG 原檔已移到 `assets/reference/incoming/PHASE7_cap_rope_coil_source.svg`）、PNG signature／IHDR／RGBA、props 與 tileset alpha 二值、四角透明（警告）、32px atlas 格框亮度、角色表尺寸、manifest 已交付條目的存在／尺寸／SHA-256。既有 24 個帶柔邊的舊檔列在 `assets/reference/incoming/ASSET_PREFLIGHT_ALLOWLIST.json`（expires_phase 10）。

### 8.5-F 測試與 builder 降載

- `tools/verify_phase.py --fast`（preflight → validate_map → Python 夾具 → Godot 單元測試）／`--full`（＋import、route test、六張截圖到 `build/route_shots/`）；每步印命令、耗時、結果，最後 PASS／FAIL。
- `tools/build_assets.py --clean --verify`：複製整棵 assets 到暫存目錄、五代 builder 在那裡重建、依 mtime 分辨產出（96 張）與直接交付（43 張）、逐檔 SHA-256 比對 repo。修正兩個不可重現點：phase5 在暫存目錄找不到 v3 atlas、phase3 會用參考圖覆蓋 Phase 7 交付的透明繩圈（現改為逐 byte 複製 `incoming/PHASE7_cap_rope_coil.png`）。結果：產出與 repo 一致。
- 測試分檔：`tests/suites/placement_tests.gd`、`rendering_tests.gd` 由 `run_tests.gd` 的 `SUITES` 載入；舊 runner 保留。
- 截圖：`docs/screenshots/golden/` 11 張代表畫面；route test 與 verify 截圖改放 `build/`（gitignore）；不改寫 git history。

## 2. 驗證

| 命令 | 耗時 | 結果 |
|---|---|---|
| `python3 tools/verify_assets.py` | 約 10 秒 | 138 張 PNG、26 筆 manifest；0 錯誤、24 例外（allowlist）、29 警告（四角不透明的舊房屋／家具貼片、atlas 橋面格） |
| `python3 tools/validate_map.py` | < 1 秒 | 通過，0 例外 |
| `python3 tools/validate_map.py --audit` | < 1 秒 | 0 項違規 |
| `python3 -m unittest discover -s tools/tests` | < 1 秒 | 14 通過 |
| `godot --headless -s res://tests/run_tests.gd` | 約 2 秒 | 395 通過，0 失敗（失敗時 quit(1)） |
| `python3 tools/build_assets.py --clean --verify` | 約 90 秒 | 產出與 repo 一致 |
| route test（`--route-test`） | 約 5 分鐘 | 317 通過，0 失敗（碰撞對齊與 render_mode 改動後重跑；樹屋斷言改為 back／z_index -1） |
| `python3 tools/verify_phase.py --fast` | 約 5 秒 | PASS（四步全部 OK） |

截圖 QA：`docs/screenshots/golden/` 11 張（Phase 8 第二批人工看過）；本階段沒有改任何貼圖與位置，只改碰撞高度（封鎖格不變）與層級欄位，樹屋／房屋改為 back 後畫面與 ysort 時相同（角色永遠在它們南側）。

## 3. 例外（allowlist）

- 地圖驗證 `assets/maps/validation_allowlist.json`：**0 筆**。17 個不對齊的碰撞全部改資料解決。
- 素材 preflight `assets/reference/incoming/ASSET_PREFLIGHT_ALLOWLIST.json`：**24 筆**，全部是 ASSET-P003（半透明像素）：舊 cap_*.png ×14、breakfast_stall.png、town_refresh v2 ×8、tide_root_town_tileset.png（第 0～5 列 Phase 1 舊 tile）。到期 Phase 10；處置見 OPEN_DECISIONS D-009／D-011。

## 4. 未完成

- `docs/screenshots/` 歷史截圖 51MB 未清理（計畫明定本階段不改寫 history；D-012）。
- MAP-P007 只驗資料一致性，不讀 PNG 高度判斷「跨多列且會與角色交錯」；跨列判斷交給人工截圖與 `--snapshot`。
- 快速 golden 視覺回歸（像素比對）未做；目前 golden 只是人工比對用。
- 上層 `c` 的霧 overlay 已於 2026-09-08 接線（`codex/phase-8-5-upper-mist-overlay` → tileset 第 10 列、只疊裝飾層；地面仍是樹冠），D-004 等作者看過白天／夜晚畫面後定案。

## 5. Phase 8.5 Gate 對照

| Gate 條件 | 狀態 |
|---|---|
| Phase 8 v3 素材全部接線、截圖人工看過 | 成立（Phase 8 第二批） |
| validate_map 快速模式抓封路、不可達互動點、出生點碰撞、未知圖例、未宣告高大物件 | 成立（MAP-P001～P007 ＋ 14 個夾具） |
| 所有現役 props 對應四種 render_mode，沒有四個旋鈕互相補救 | 成立（78／78，z_bias 移除） |
| CURRENT_PROJECT_SPEC、INDEX、OPEN_DECISIONS 存在，AGENTS 指向唯一規格 | 成立 |
| `--fast` 可平常執行、`--full` 合併前通過印 PASS | `--fast` PASS；`--full` 的組成（import、單元、route test 317、截圖）各自單獨跑過，整合入口下次合併前再整段跑一次 |
| 報告列出所有 allowlist 例外 | 成立（第 3 節） |

## 6. Phase 9 前需作者回答（只列內容設計）

見 `docs/OPEN_DECISIONS.md` D-010：本段核心循環要採用哪一段成長回憶、使用哪位真實人物作 NPC 原型、情緒落點、既有 CC／炸物魔王內容哪些升格為正式內容。所有新 NPC 先問人物個性、外型、特質。
