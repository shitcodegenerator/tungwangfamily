# Phase 8 本地執行報告（第一批：盤點、室內層級、builder、展示模式；第二批：v3 素材接線）

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
| assets/maps/tide_root_town_props.json | 作者選 A：封住 4 個大型物件北側口袋——breakfast_stall_v2 119、heart_fountain_v2 96（113 會封掉老龜站位）、harbor_crate_barrel_v2 86、flower_herb_bed_v2 116；validate_map 通過、單元測試 343；依作者指示未重跑 route test。**第二批更正：花圃 116 封掉阿嬤／CC 對話站位，改 96（見第二批回歸）** |
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

## 第二批：Phase 8 v3 素材接線（2026-09-07，合入 codex/phase-8-art-assets-v3 = 3847042）

依 docs/PHASE_8_ART_ASSET_DELIVERY.md 接線。遠端交付的 20 張執行期 PNG 尺寸與 SHA-256 全部與 manifest 相符；
本地另以 PIL 逐張確認：alpha 全為二值（沒有半透明像素）、四角透明、船長房家具底列透明（沒有烙地板）。

### 使用的 PNG（file：PNG image data、RGBA；SHA-256 前 16 碼）

| 路徑 | 尺寸 | 模式 | SHA-256 |
|---|---:|---|---|
| assets/props/town_refresh/shared_family_treehouse_v3.png | 176×96 | RGBA | 838c7b8cdedc813a… |
| assets/props/town_refresh/root_archway_v3_base.png | 176×166 | RGBA | 36c66c1e5c49ab7d… |
| assets/props/town_refresh/root_archway_v3_canopy.png | 176×166 | RGBA | 7baf6209e3874c4f… |
| assets/tilesets/town_visual_refresh_tiles_32_v3.png | 256×128 | RGBA | 9d34655b04239ad2… |
| assets/tilesets/upper_canopy_fill_tiles_32_v1.png | 256×128 | RGBA | 4d99a9f7fa3ed6b4… |
| assets/props/cap_barrel_v3.png | 40×48 | RGBA | a02631ba5259fd99… |
| assets/props/cap_bookshelf_v3.png | 80×128 | RGBA | dbc7f8c629b84597… |
| assets/props/cap_chart_desk_v3.png | 178×120 | RGBA | 608269e4140952d6… |
| assets/props/cap_chest_bench_v3.png | 52×70 | RGBA | 8867d2ce5eb332ff… |
| assets/props/cap_chest_stack_v3.png | 102×98 | RGBA | 881efc3a28d0b1b0… |
| assets/props/cap_coat_rack_v3.png | 65×115 | RGBA | 0e4a03afefeea24c… |
| assets/props/cap_fish_crate_v3.png | 102×98 | RGBA | 4b8797446efbc894… |
| assets/props/cap_hanging_lantern_v3.png | 45×78 | RGBA | dd9bf53b1f49b395… |
| assets/props/cap_painting_v3.png | 48×40 | RGBA | 3d9bc0ad736b8162… |
| assets/props/cap_porthole_v3.png | 72×78 | RGBA | cefb1c7170607d90… |
| assets/props/cap_rod_rack_v3.png | 108×165 | RGBA | 13cbcffe6734d42e… |
| assets/props/cap_rope_coil_v3.png | 55×40 | RGBA | b69f1dff070b3f34… |
| assets/props/cap_rug_v3.png | 215×128 | RGBA | c9a688fa20c0fb01… |
| assets/props/cap_side_table_v3.png | 140×128 | RGBA | 78cda2396a08ed32… |
| assets/props/cap_wall_map_v3.png | 102×78 | RGBA | df4da1b97cc3b38f… |

產生檔：assets/tilesets/tide_root_town_tileset.png 由 `python3 tools/build_assets_phase5.py`（預設即 v3 atlas、frame 0、fill pack）重建為 576×320（10 列）；SHA-256 前 16 碼 5ebc6d67975ef812。

### 哪些 props 換新檔、哪些保留

| 場景 | 換成 v3 | 保留舊檔 |
|---|---|---|
| 主城 | shared_family_treehouse_v3（foot_inset 64 → 16）、root_archway_v3_base ＋ root_archway_v3_canopy（拆兩筆 props） | 房屋立面 ×5、breakfast_stall_v2、heart_fountain_v2、lantern_post_v2、harbor_crate_barrel_v2、flower_herb_bed_v2、blank_signpost_v2 等全部 v2 |
| 船長房間 | 15 件全部 cap_*_v3；x、y、collision、interact、event_id、shader、glow 全部沿用第一批數值 | 舊 cap_*.png 留在 assets/props/ 可回退（Phase 7 繩圈測試仍驗舊檔） |
| 家庭屋、洞窟 | 無 | 全部 |

角色：assets/characters/ 沒有任何變更（`git diff --stat 31d898c..HEAD -- assets/characters` 為空）；四位主角、CC、阿嬤、船長、老龜未重生。

### 主城 tile_style_rows 實際範圍

[23,35] → 先 [12,35]（截圖確認中層草地／石板過渡沒有格線、白線）→ **[0,35]**。
上層第 0～11 列由 tile_library 新分支處理：`.` → 填充包樹冠（下方不是天空用樹冠下緣）、`T` → 根牆（上方不是 T 用根牆頂）、`c` → 霧層。
主城地圖裡的 `c` 幾乎全是孤立單格（只有第 1 列兩對相鄰），畫成霧層會像一格藍色破洞，因此規則定為「至少一個四方鄰居也是 c 才畫霧，孤立的 c 畫樹冠」；見下方待作者確認。
樹冠四格變體改用以亮格為主的週期表（UP_CANOPY_PATTERN），避免 mod 4 雜湊出現棋盤格。

### z_bias／overlay 變更

| 物件 | 之前 | 現在 | render_mode（Phase 8.5 用語） |
|---|---|---|---|
| 樹屋 | z_bias 0、foot_inset 64 | z_bias 0、foot_inset 16 | back（Y-sort、頂端 y=592） |
| 根拱門 | 一張圖 z_bias -1 | base：z_bias 0、兩隻腳碰撞盒；canopy：z_bias 1、無碰撞、同錨點 | split |
| 船長房自立家具 ×9 | z_bias 0 | 不變 | ysort |
| 船長房牆掛／地毯／舷窗 ×5 | z_bias -1 | 不變 | back／ground |
| 繩圈 | Y-sort、event 目標 | 不變（cap_rope_coil_v3，55×40，(176,176)） | ysort |

### 程式與工具

| 檔案 | 變更 |
|---|---|
| tools/build_assets_phase5.py | 預設來源改 v3 atlas（frame 0），`--fill`／`--no-fill` 把上層填充包放進第 8～9 列；`main(argv)` 供 build_assets.py 傳 `[]`；舊 Phase 5 atlas 用 `--atlas ... --frame 2` |
| scripts/world/tile_library.gd | ATLAS_ROWS 8 → 10；UP_* 常數、SKY_CHARS、UP_CANOPY_PATTERN；`pick_variant`、`upper_canopy_atlas_for`；town_refresh_atlas_for 加 `.`／`c`／`T` |
| assets/maps/scenes.json | tile_style_rows [23,35] → [0,35] |
| tests/run_tests.gd | v3 貼圖名、tileset 576×320、上層填充分支、拱門拆層、樹屋頂端 y=592（354 項） |
| scripts/debug/route_test.gd | 拱門改驗 base（z 0）＋ canopy（z > 0）同錨點；樹屋頂端 == 592 |

### 截圖（docs/screenshots/phase8_v3/）

| 檔名 | 驗收 | 結果 |
|---|---|---|
| phase8_town_upper_clean.png | 上層沒有黑洞、星空 | 通過：樹冠填充＋平台，白天沒有星空虛空 |
| phase8_town_middle_transitions.png | 草地／石板過渡沒有硬切 | 通過：v3 atlas 無格線 |
| phase8_treehouse_door.png | 樹屋接地、隊伍不被屋頂遮 | 通過：隊伍站在踏墊上，頂端 y=592 |
| phase8_archway_north.png | 站第 21 列 | 樹冠在角色前方：頭露出、身體被葉子遮（依規劃 split 的定義，見待確認） |
| phase8_archway_inside.png | 穿過拱門 | 通過：base 石板在腳下、canopy 在頭上 |
| phase8_family_home_party.png | 室內家具 | 通過（未改） |
| phase8_captain_room_party.png、phase8_captain_room_south.png | 船長房 v3 家具 | 通過：風格統一、無貼片邊緣、站桌北側只蓋腳踝 |
| phase8_cave_party.png | 洞窟 | 通過（未改） |
| phase8_idle_shadow.png、phase8_day_night.png | 待機陰影、夜晚層級 | 通過（route test 截圖 19／08 複製） |
| phase8_breakfast_stall_pocket.png | 阿嬤攤前第 30 列站位 | 通過：四人完整，花圃碰撞回到 96 後可站 |
| phase8_archway_party_route.png | 隊伍穿過拱門 | 通過（route test 截圖 29） |

route test 其餘 27 張截圖放在未追蹤的 scratch 目錄，不再整批進 git（依 Phase 8.5-F 的截圖保存策略）。

### 第二批驗證

| 項目 | 結果 |
|---|---|
| godot --headless --import | 通過（22 個新 .import） |
| python3 tools/validate_map.py | 地圖驗證通過 |
| 單元測試 | 354 通過，0 失敗 |
| route test | 第三次 317 通過，0 失敗（第一次 221／32、第二次 158／120，原因見下） |

### 第二批過程中修正的回歸

1. **花圃碰撞 116 封掉阿嬤／CC 對話站位**：第一批「封口袋」把 flower_herb_bed_v2 加深到 116（頂端 y=972），第 30 列第 6～10 格被登記為封鎖格，而玩家就是站在 (9,30)／(10,30) 面對阿嬤與 CC，整串 CC 任務 route test 失敗。當時依作者指示沒重跑 route test，所以到這批才發現。改回 96（頂端 y=992）。第 30 列的北側口袋因互動站位必須保持開放。
2. **早餐攤碰撞 119 封掉 (4,25)**：這是 route test「走到樹皮牆邊」的目標格；封口袋是作者決定，所以改測試目標到樓梯西側的樹根牆 (11,24)。
3. **門口格提早觸發傳送門**：角色碰撞盒 18×10，站在門口格中心時盒頂 y=678，傳送門底緣 677，只差 1px；route test 走到格子只要求 3px 內停下，最後一步偏北 1px 以上就會在按上之前轉場，領頭者被送進家庭屋後繼續往主城座標走、卡在西牆。第 2 點改了目標後換人時序不同，剛好踩到。route test 新增 `_walk_to_door`：門口格最後一步目標往南偏 6px，餘裕變 7px；五個門口呼叫點改用。遊戲本身的資料沒改。

## 過程中修正的回歸

第一次 route test 314 通過 4 失敗：餐桌碰撞 76 讓第 5 列整列被登記為封鎖格，route test 站在流理台前 (4,5) 找不到回臥室門的路徑（後三項是連鎖）。餐桌改 70（碰撞頂對齊 y=192）後重跑。

## 仍需作者確認

1. 戶外大型 props 北側口袋：作者已選封住（已套用，見上表）。
2. 船長房間家具：作者已決定整批重出 v3（15 張），manifest 已列。
3. int_kids_corner 與 cap_chest_stack 因保留互動站位只能加深到 58／56，站在它們北側口袋仍會被蓋 47／42px；若要完全解決需微調家具位置（版面決定）。
4. ~~上層 `c`~~：作者 2026-09-07 決定——地面一律畫樹冠，霧改用透明 overlay 疊在裝飾層。需要遠端出圖 `upper_mist_overlay_pack`（256×64、8×2、真透明霧絲，規格在 manifest conditional_assets）；填充包裡的藍灰霧 tile 保留不用。
5. ~~拱門正北第 21 列~~：作者接受 split 的定義結果（canopy 在前）。
6. ~~船長房 v3 色數~~：作者接受。

## 視覺例外（誠實列出）

- ~~主城上層星空虛空~~：已由填充包解決；`c` 一律畫樹冠，霧絲等 overlay 圖（見待確認 4）。
- ~~中層草地／石板硬切~~：v3 atlas 已解決。
- ~~樹屋第 18 列蓋腳~~：v3 頂端 y=592，已解決。
- 拱門正北第 21 列：canopy 在角色前方（見待確認 5）。
- ~~船長房間家具貼片邊緣~~：v3 真透明，已解決。
- 上層 `T` 根牆與 `b` 平台為填充包／木板 tile 平鋪，遠看有重複感；屬素材風格，不是破圖。
