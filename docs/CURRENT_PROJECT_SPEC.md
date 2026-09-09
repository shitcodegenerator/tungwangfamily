# 山海樹港 RPG — 現行專案規格（唯一版本）

更新：2026-09-07（Phase 8.5）。這份文件整合 AGENTS 守則、內容邊界、資料 schema、顯示層級、地圖圖例、素材與測試命令。
歷史 Phase 文件在 `docs/archive/`，只供追溯；與本文件衝突時以本文件為準。索引見 `docs/INDEX.md`，待決策見 `docs/OPEN_DECISIONS.md`。

## 1. 專案與技術基準

| 項目 | 規格 |
|---|---|
| 引擎 | Godot 4.7.2（`/opt/homebrew/bin/godot`），GDScript，Compatibility renderer，Nearest，不用第三方 addon |
| 畫面 | 邏輯 640×360、整數倍率；地圖格 32×32 |
| 主城 | 一張連續世界地圖（30×36 格，960×1152），`tide_root_town`；室內為獨立小場景，經 `assets/maps/scenes.json` 的穩定 `scene_id` 切換 |
| 角色 | 單格 48×64、腳底 y=61、列序 down／left／right／up；主角行走表 `*_walk_v2_sheet.png` 192×256（4 幀）＋待機表 192×256＋行動表 96×256；NPC／CC 240×256；Boss 480×80 |
| 四位主角 | 共用 `scenes/characters/playable_character.tscn` 與同一支腳本，差異只在 `CharacterData` .tres；碰撞 18×10 |
| 陰影 | 角色場景第一個子節點 `Shadow`，固定地面錨點 (0,0)；待機表自帶呼吸，程式不再晃動 VisualRoot |
| 分支 | 遠端規劃／素材推 `codex/phase-N-*`；本地自 master 開 Phase 分支實作，作者決定何時合併 master |

## 2. 內容邊界（不可越線）

以 `docs/PHASE_3_DECISIONS.md` 為準：

- 不得自創正式劇情、章節、Boss、父親離世演出、乾媽家庭傷痛、真實回憶；測試內容一律 `TEMP_DEMO_CONTENT` 或 `demo_` 前綴。
- 父親原型 NPC 是「國王企鵝船長」；媽媽與乾媽共用 `family_home`。
- 炸物魔王只能是純幻想、搞笑的一次性教學 Boss。
- CC 台詞只用短句、句尾「です」；CC 每日餵食／好感度規則未定案，不要自行設計。
- 新 NPC：先問人物個性、外型、特質，再設計功能。
- 目前明確不做：小怪、經驗值、等級、裝備、技能樹、複雜屬性、完整戰鬥框架、好感度、送禮。

## 3. 程式責任分工（不可耦合）

| 檔案 | 只負責 |
|---|---|
| `scripts/characters/player_character.gd` | 單一角色輸入、移動、方向、動畫；不得知道對話、任務、互動物件 |
| `scripts/characters/follower_character.gd`、`party_controller.gd`、`party_trail.gd` | 跟隨、分離、切換、隊伍順序 |
| `scripts/characters/pet_follower.gd` | CC 寵物跟隨，不在 party order |
| `scripts/world/map_parser.gd` | ASCII 地圖；可走／不可走字元只來自 `assets/maps/tile_legend.json` |
| `scripts/world/tile_library.gd` | 圖例字元 → atlas 座標；`tile_style` `cave`／`town_refresh` 依四方鄰居選 tile；上層 `.`／`c`／`T` 用填充包（第 8～9 列）；`c` 的霧絲由 `decoration_atlas_for` 以第 10 列透明 overlay 疊在裝飾層（`upper_mist_overlay_for` 依四方 `c` 鄰居選填充／端／緣／孤立格） |
| `scripts/world/town_world.gd` | 由 ASCII 地圖與 props JSON 建立世界；`z_index_for(render_mode)`；碰撞盒 → 封鎖格 |
| `scripts/props/town_prop.gd` | props 貼圖、碰撞、多幀／飄移／光暈／shader；`foot_x`／`foot_inset`／`collision_boxes` |
| `scripts/world/scene_router.gd`、`portal.gd` | 場景建立、轉場、傳送門（只看領頭者）、讀檔還原 |
| `scripts/state/game_state.gd` | 唯一狀態與序列化（schema v3：day／day_seed／daily_state）；`advance_day` 只由休息流程呼叫 |
| `scripts/save/save_manager.gd` | JSON 存讀檔（F6／F7），錯誤回傳不崩潰 |
| `scripts/quest/quest_manager.gd`、`dialogue/dialogue_resolver.gd`、`ui/dialogue_*.gd`、`ui/quest_hud.gd` | 任務、對話版本、對話框、日誌（滾輪、`<`／`>` 翻頁） |
| `scripts/events/world_event_library.gd`、`world_event_runner.gd` | 資料驅動世界事件；外部能力用注入的 Callable；`cancel()` 還原；暫態不進 GameState |
| `scripts/battle/*` | 唯一的戰鬥（炸物魔王）；主城、CC、物品、角色腳本不得知道戰鬥存在；戰鬥暫態不進 GameState |
| `scripts/ui/debug_hud.gd`、`day_hud.gd`、`battle_hud.gd`、`rest_transition.gd` | 除錯面板（狀態列只在 `--route-test`／`--snapshot`／`--debug-hud`／F2 顯示）、天數、戰鬥、休息轉場 |
| `scripts/debug/route_test.gd`、`snapshot.gd` | 自動驗收路線與截圖工具，不放遊戲邏輯 |

存檔 ID 用 `scene_id` 與角色 `id`，不用節點路徑。對話在 `assets/dialogue/<scene>.json`、任務 `assets/quests/*.json`、事件 `assets/events/*.json`（線索＝永久旗標 `clue_<id>`）。

## 4. 資料 schema

### 4.1 場景登錄 `assets/maps/scenes.json`

每個 `scene_id`：`name`、`map`（ASCII txt）、`props`（JSON）、`dialogue`、`tile_style`（無／`cave`／`town_refresh`）、`tile_style_rows`（主城目前 `[0, 35]`）、`legend_overrides`、`dark_wall_last_row`、`battle`（洞窟 Boss：x、y、`min_y`）。

### 4.2 ASCII 地圖與圖例 `assets/maps/tile_legend.json`

可走：`g d r p b s m = | w`；不可走：`# . c ~ , T`。每個字元登錄名稱、`walkable`、支援的 `styles`。新增地形：先登錄字元 → `tile_library.gd` 加對應 → `validate_map`（MAP-P006）與 `tests/suites/placement_tests.gd` 會確認每個樣式都有 mapping，不得退回樹根牆。

### 4.3 props JSON（每個場景）

頂層：`world_size`、`spawn_points`、`entries`、`zones`、`exits`、`connectors`、`portals`（`return_position`）、`npcs`（`facing`、`requires`）、`items`（洞窟）、可選 `reserved_tiles`。
每個 prop：`texture`、**`render_mode`**（`ground`／`back`／`ysort`／`split`＋`split_role`）、`x`、`y`（接地點）、`collision` `[寬, 高]` 或 `null`、可選 `collision_boxes`、`foot_x`、`foot_inset`、`frames`／`fps`、`drift`、`alpha`、`glow`／`glow_x`／`glow_y`、`shader`、`interact`／`interact_size`／`prompt_offset`／`prompt_icon`、`event_id`、`note`。
`z_bias` 已退役。碰撞高度 ≥ 32 時頂端必須在 32 格線。完整規則與實例：`docs/RENDERING_AND_PLACEMENT_SPEC.md`。

### 4.4 存檔 schema v3

`GameState.to_dict()`：`schema_version`、`current_scene_id`、`return_position`、`party`／`leader`、`flags`、`daily_state`、`day`、`day_seed`、`quests`、`inventory`、`pet`。改 schema 才升版並寫遷移與測試；UI 捲動位置不存檔。

## 5. 素材

- 執行期目錄（`assets/props`、`tilesets`、`characters`、`ui`、`effects`、`items`、`portraits`）只放 PNG（與 .import／.tres／.ttf／.json 資料）；SVG／PSD／Aseprite 原檔與參考大圖放 `assets/reference/incoming/`，每次交付更新 `PHASE*_ASSET_MANIFEST.json`（路徑、尺寸、alpha、SHA-256）。
- 像素規則（`docs/ART_STYLE_LOCK.md`）：1× 像素、alpha 只用 0／255、不烙地板／牆／陰影、色盤與光源一致。既有帶柔邊的舊檔列在 `assets/reference/incoming/ASSET_PREFLIGHT_ALLOWLIST.json`（到期自動失效）。
- 主城 tileset `assets/tilesets/tide_root_town_tileset.png` 576×352：第 0～5 列 Phase 1 舊 atlas、第 6～7 列 Phase 8 v3 城鎮更新 tile、第 8～9 列上層填充包（第 8 列藍灰霧格保留不用）、第 10 列 Phase 8.5 透明霧 overlay（`upper_mist_overlay_tiles_32_v1.png` 8×2 摺成 16 欄，12～15 欄為保留透明格）。由 `python3 tools/build_assets_phase5.py` 產生（預設即 v3／frame 0／fill／mist）。
- 五代 builder 單一入口：`python3 tools/build_assets.py`（依序 phase1～5）；`--clean --verify` 在暫存目錄重建並比對 repo。遠端直接交付的正式檔（v2 行走表、洞窟 tile、v2／v3 props、atlas）不經切割；Phase 7 繩圈由 builder 逐 byte 複製 `incoming/PHASE7_cap_rope_coil.png`。
- 改過任何 PNG 後必跑 `godot --headless --path . --import`。
- 不重生四位主角、CC、阿嬤、船長、老龜；不改角色 ID 與貼圖路徑。

## 6. 驗證命令

| 何時 | 命令 | 內容 |
|---|---|---|
| 平常修改後 | `python3 tools/verify_phase.py --fast` | 素材 preflight（`tools/verify_assets.py`）→ 地圖硬檢查（`tools/validate_map.py`）→ 驗證器夾具（`python3 -m unittest discover -s tools/tests`）→ Godot 單元測試（`tests/run_tests.gd`，含 `tests/suites/*.gd`） |
| 只跑 Python | `python3 tools/verify_phase.py --fast --no-godot` | 幾秒 |
| 合併前 | `python3 tools/verify_phase.py --full` | 以上全部 ＋ import ＋ route test（`--route-test`，約 5 分鐘、需 caffeinate 與視窗）＋ 六張版面截圖 → `build/route_shots/` |
| 找出封路原因 | `python3 tools/validate_map.py --audit` | 所有違規、每個 props 封鎖的格、建議 allowlist |
| 版面檢查 | `caffeinate -dis godot --path . --always-on-top -- "--snapshot=<scene>:<x>,<y>:/abs/a.png;..."` | 不做斷言 |
| 素材重建驗證 | `python3 tools/build_assets.py --clean --verify` | builder 產出必須與 repo 一致 |

截圖保存：只有 `docs/screenshots/golden/`（11 張代表性畫面）進 git；route test 與 verify 的大量截圖放 `build/`（gitignore）。

## 7. 提交與協作

- 未被要求不 commit；要求時訊息 `<type>: 中文描述`，附 `Co-Authored-By` 與 `Claude-Session` 尾註。
- 從 Phase 9 起每個 Phase 只保留一份主文件 `docs/PHASE_N.md`（Plan／Implementation／Verification／Remaining 四節）；待確認事項只寫進 `docs/OPEN_DECISIONS.md`。
- 遠端只改 `assets/reference/incoming/`、manifest 與規劃文件；本地負責程式、資料、測試與報告。
- Phase 9 前置門檻：Phase 8.5 Gate 全部成立（見 `docs/PHASE_8_5_REPORT.md`），且 `OPEN_DECISIONS` D-010 由作者回答。
