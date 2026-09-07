# Phase 8 本地執行報告（第一批：盤點、室內層級、builder、展示模式）

日期：2026-09-07　分支：phase-8-art-complete（自 master 20689ba 建立，已合入遠端 codex/phase-8-art-complete 的規劃文件）
依 docs/LOCAL_AI_PHASE_8_PROMPT.md 執行；規劃審閱修正見 docs/PHASE_8_ART_COMPLETION_PLAN.md 第 5-1 節。

## 已完成

### 規劃審閱（先於實作）

對照程式與素材後修正的規格（已寫回計畫、提示、教學與 manifest）：

1. 樹屋 v3：foot_inset 0 → 16，圖片底部 16px 為踏墊。角色原點在格子中央，第 18 列原點 y=592；96 高＋inset 0 的頂端在 576 仍蓋腳，與 Phase 7 現況只差 2px。
2. 房屋立面 v3：寬度不得超過原檔（相鄰房屋原點只相距 96px，128 寬會重疊 32px）。
3. 室內家具：先加深碰撞，不預設 z_bias -1（自立家具 -1 會讓北側角色畫在桌面上）。
4. tile_style_rows：v3 atlas 先到 [12,35]；[0,35] 需 upper_canopy_fill_pack 與 tile_library 補 `.`／`T`／`c`（目前 `.` 會被畫成樹根牆）。
5. builder：Phase 5 版寫死來源檔並去 2px 格框，乾淨版 v3 需要新參數。
6. 基準改 master 20689ba；必讀加入 docs/PHASE_7_SCENE_EDIT_TUTORIAL.md（零基礎完整版）。

### 素材

本批**沒有新增或替換任何 PNG**；四位主角、CC、阿嬤、船長、老龜素材未動（`git diff --stat` 無 assets/characters、assets/props、assets/tilesets 變更；tileset 以預設參數重建後 SHA 前 16 碼 dd7f9330fc1cee98 與原檔相同）。

### 資料與程式

| 檔案 | 變更 |
|---|---|
| assets/maps/family_home_props.json | 7 件家具 collision 高度加深（int_stove 86、int_kitchen_counter 44、int_back_door 72、int_yarn_cabinet 74、int_sewing_table 66、int_dining_table 70、int_kids_corner 58） |
| assets/maps/captain_room_props.json | 8 件家具 collision 高度加深（cap_coat_rack 99、cap_rod_rack 149、cap_bookshelf 112、cap_chart_desk 104、cap_chest_bench 54、cap_side_table 112、cap_chest_stack 56、cap_fish_crate 80） |
| scripts/ui/debug_hud.gd、scripts/main.gd、project.godot | 除錯狀態列預設隱藏；`--route-test`／`--snapshot=`／`--debug-hud` 或 F2（debug_toggle_status）才顯示；對話隱藏／恢復不會把停用的狀態列打開 |
| tools/build_assets_phase5.py | 新增 `--atlas <path>`、`--frame N`（乾淨版用 0）；預設行為與輸出不變 |
| tools/audit_props_phase8.py | 盤點：尺寸、透明、四角、底緣懸空、碰撞、北側被蓋 px、北側是否可走 → docs/PHASE_8_ASSET_AUDIT_TABLE.md |
| tools/contact_sheet_phase8.py、tools/montage_phase8.py | 素材對照表、截圖拼圖 |
| tests/run_tests.gd | 新增 test_phase8_ui（8 個斷言） |

x、y、貼圖、z_bias、傳送門、出生點、ASCII 地圖、tile_style_rows 全部未改。

### 截圖

- `docs/screenshots/phase8_baseline/`：主城上層×3、中層街道、樹屋×3、拱門×2、下層廣場、家庭屋×4、船長房間×4、洞窟；`contact_*.png` 六張對照表；`montage/` 拼圖。
- `docs/screenshots/phase8_baseline/after_collision/`：室內 13 張修正後截圖。關鍵：`cap_chart_north.png`（站航海圖桌北側只蓋腳踝）、`cap_rod_rack.png`、`home_dining_north.png`。
- `docs/screenshots/phase8_route/`：本批 route test 截圖（Phase 7 的 docs/screenshots/*.png 未覆蓋）。

### 驗證

| 項目 | 結果 |
|---|---|
| godot --headless --import | 通過 |
| python3 tools/validate_map.py | 地圖驗證通過（互動點 sewing_table、captain_rod_rack 站位保留） |
| 單元測試 | 343 通過，0 失敗 |
| route test | 317 通過，0 失敗（第二次；截圖 docs/screenshots/phase8_route/） |

## 仍需本地 AI 實作（等素材到位）

| 等待檔案 | 規格 | 接線 |
|---|---|---|
| assets/props/town_refresh/shared_family_treehouse_v3.png | 176×96 RGBA 真透明，底 16px 踏墊，門檻線在 y=80 | props JSON texture 切換、foot_inset 16 |
| assets/props/town_refresh/root_archway_v3_base.png／_canopy.png | 各 176×166，同底部中央錨點；base 含拱腳＋石板，canopy 只含樹冠 | 兩筆 props：base 保留 collision_boxes、一般 Y-sort；canopy collision null、z_bias 1 |
| assets/tilesets/town_visual_refresh_tiles_32_v3.png | 256×128、8×4、無格框 | `python3 tools/build_assets_phase5.py --atlas <path> --frame 0` → import → tile_style_rows [12,35] → 中層截圖 |
| upper_canopy_fill_pack | 雲層／霧／樹根 refresh tile | tile_library 補 `.`／`T`／`c` 分支後才擴到 [0,35] |
| cap_*_v3.png 整批 15 張（作者已決定） | 尺寸沿用、真透明、不烙地板；繩圈維持事件規格 | props JSON 切換，碰撞沿用本批數值 |

## 過程中修正的回歸

第一次 route test 314 通過 4 失敗：餐桌碰撞 76 讓第 5 列整列被登記為封鎖格，route test 站在流理台前 (4,5) 找不到回臥室門的路徑（後三項是連鎖）。餐桌改 70（碰撞頂對齊 y=192）後重跑。

## 仍需作者確認

1. 戶外大型 props 北側口袋（breakfast_stall 第 25～26 列 5 格、heart_fountain、harbor_crate_barrel、flower_herb_bed）：加深碰撞會封掉那些格子。要封（角色不會走進去消失）還是保留可走（接受被蓋）？本批未動。
2. 船長房間家具：作者已決定整批重出 v3（15 張），manifest 已列。
3. int_kids_corner 與 cap_chest_stack 因保留互動站位只能加深到 58／56，站在它們北側口袋仍會被蓋 47／42px；若要完全解決需微調家具位置（版面決定）。

## 視覺例外（誠實列出）

- 主城上層仍是星空虛空 tile（白天）：等 fill pack。
- 中層草地／石板硬切：等 v3 atlas。
- 樹屋第 18 列蓋腳 16～18px、拱門正北第 21 列站在樹冠上：等 v3 素材。
- 船長房間家具矩形貼片邊緣在深色地板上可見：等 v3。
