# Phase 8 P8.0 視覺盤點：KEEP／FIX／REDRAW

日期：2026-09-07　分支：phase-8-art-complete（自 master 20689ba）
可量測資料由 `python3 tools/audit_props_phase8.py` 產生在 `docs/PHASE_8_ASSET_AUDIT_TABLE.md`；本文件是人工判定。
截圖：`docs/screenshots/phase8_baseline/`（基準）、`phase8_baseline/after_collision/`（室內碰撞修正後）、對照表 `phase8_baseline/contact_*.png`（灰棋盤底 2×，紅線＝貼圖底緣）。

## 1. 判定總表

| 群組 | 檔數 | 判定 | 理由 |
|---|---:|---|---|
| 四位主角 walk_v2／idle／action | 12 | KEEP | 同角色三張表造型、腳底、輪廓一致；依政策不重生 |
| NPC／寵物（阿嬤、船長、老龜、CC） | 4 | KEEP | 與主角同一像素密度 |
| 主城房屋立面 house_*、canopy_gate | 7 | KEEP | 乾淨像素風、真透明、與角色密度一致。house_tree_door 無場景使用 → UNUSED |
| town_refresh v2 大型 props | 8 | KEEP（樹屋、拱門另依版面 REDRAW v3） | 邊緣有 7～22% 半透明柔邊，但八張彼此一致、下層廣場整體成立；重出只為版面（樹屋高度、拱門拆層），不是風格 |
| 共享家庭屋家具 int_* | 12 | FIX（碰撞深度，已套用） | 像素風接近角色；四角不透明是烙了地板／地毯底，遊戲內與木地板同色，可接受 |
| 船長房間家具 cap_* | 15 | **REDRAW v3（第一批 9 張）**＋FIX 碰撞（已套用） | 見第 3 節 |
| 主城上層 tile（第 0～11 列） | — | REDRAW／NEW：upper_canopy_fill_pack | 白天卻是深藍星空虛空 tile，雲、樹冠、平台不連續（`town_upper_*.png`） |
| 主城中層 tile（第 12～22 列） | — | REDRAW：town_visual_refresh_tiles_32_v3 | 草地／石板硬切（`town_middle_street.png`） |

## 2. 室內遮擋：實測與修正

問題根因不是 Y-sort，而是碰撞盒比圖片矮太多，角色可以走進圖片裡面。修正前 `cap_chart_desk.png`／`cap_rod_rack.png` 基準截圖裡，站在航海圖桌、船具架北側的隊伍整個消失，只剩「E」提示。

已套用（只改 collision 高度，x／y／貼圖／z_bias 不動）：

| 場景 | 家具 | 碰撞高 | 站在北側被蓋 px（前→後） |
|---|---|---|---:|
| family_home | int_stove | 30→86 | 72→16 |
| family_home | int_kitchen_counter | 26→44 | 34→16 |
| family_home | int_back_door | 20→72 | 68→16 |
| family_home | int_yarn_cabinet | 26→74 | 64→16 |
| family_home | int_sewing_table | 40→66 | 42→16 |
| family_home | int_dining_table | 46→70 | 46→22（碰撞頂對齊第 5 列下緣 y=192；76 會把第 5 列整列登記為封鎖格，route test 站在流理台前 (4,5) 就找不到路徑） |
| family_home | int_kids_corner | 50→58 | 55→47（只能到 58：再高會把縫紉桌互動站位 (17,6) 封死） |
| captain_room | cap_coat_rack | 20→99 | 95→16 |
| captain_room | cap_rod_rack | 40→149 | 125→16 |
| captain_room | cap_bookshelf | 30→112 | 98→16 |
| captain_room | cap_chart_desk | 50→104 | 70→16 |
| captain_room | cap_chest_bench | 24→54 | 46→16 |
| captain_room | cap_side_table | 50→112 | 78→16 |
| captain_room | cap_chest_stack | 40→56 | 58→42（只能到 56：保留船具架互動站位 (17,7)） |
| captain_room | cap_fish_crate | 36→80 | 62→18（80 保留第 7 列走道，否則船具架不可達） |

碰撞盒與格線的關係：town_world 只要碰撞盒與格子相交就把整格登記為不可路徑規劃，所以碰撞頂端最好落在 32 的倍數，否則會多封一整列。
沒有對任何自立家具加 z_bias -1；牆上物件（窗、門、地毯、壁畫、掛燈、舷窗）維持原本的 -1。
修正後截圖：`after_collision/cap_chart_north.png`（站桌北側只蓋腳踝）、`after_collision/cap_chart_desk.png`、`after_collision/cap_rod_rack.png`、`after_collision/home_dining_north.png`。
validate_map、343 個單元測試通過；互動點 sewing_table、captain_rod_rack 站位保留。

## 3. 船長房間家具 REDRAW v3 理由

對照表 `contact_captain_room.png` 與 ART_STYLE_LOCK 比對：

- 半透明像素 25～67%（cap_barrel 67%、cap_coat_rack 53%、cap_bookshelf 49%、cap_fish_crate 45%、cap_chest_stack 43%、cap_rod_rack 42%）：整張是柔邊／抗鋸齒，不是 1× 像素邏輯。
- 四角不透明：烙了木地板與牆面底色，家具是「矩形貼片」而不是物件；地板換色或角色走到旁邊就露出矩形邊。
- 像素密度接近照片式細節，與四位主角（48×64 乾淨輪廓）差距最大；家庭屋 int_* 反而接近角色。

作者決定（2026-09-07）：整批 15 張一起重出，避免新舊混雜。順序建議——
第一批（玩家會靠近、會互動）：cap_chart_desk、cap_side_table、cap_rod_rack、cap_bookshelf、cap_chest_stack、cap_fish_crate、cap_coat_rack、cap_chest_bench、cap_barrel。
第二批（牆上／地面）：cap_wall_map、cap_painting、cap_porthole、cap_hanging_lantern、cap_rug。
cap_rope_coil 也一起重出以統一風格，但必須維持 55×40、透明、事件目標位置不變。
規格：尺寸沿用原檔、底緣＝接地線、真透明、不烙地板、不烙陰影、深靛／暖棕／琥珀色盤、左上光源；碰撞沿用本次修正後的值。
來源檔放 assets/reference/incoming/PHASE8_interior_furniture_v3_source.png，遊戲讀取的 PNG 用新檔名 `cap_*_v3.png`，props JSON 切換，舊檔保留。

## 4. 戶外 props：作者 2026-09-07 決定封住大型物件北側口袋（已套用）

盤點腳本對戶外也算出「北側被蓋」，但這些多屬自然遮擋，且加深碰撞會改變廣場可走區，違反「不因美術修正改可走性」：

| 物件 | 北側被蓋 px | 判定 |
|---|---:|---|
| house_*（5 棟，各 32px） | 32 | KEEP：站在房子後面被屋簷蓋腳是正常 RPG 遮擋 |
| lamp_post×4、lantern_post_v2×4、signpost×2、blank_signpost_v2、flag_banner×4、bulletin_board | 24～73 | KEEP：柱狀薄物件或告示，走到後面自然被擋 |
| breakfast_stall_v2 | 99 | 已套用：碰撞 36→119，第 25～26 列攤位後方 5 格封住 |
| heart_fountain_v2 | 89→33 | 已套用：碰撞 40→96（碰撞頂對齊 y=896；113 會封掉市集老龜的站位 (20,27)），第 28 列封住 |
| harbor_crate_barrel_v2 | 74 | 已套用：碰撞 28→86 |
| flower_herb_bed_v2 | 102 | 已套用：碰撞 30→116 |
| shared_family_treehouse_v2 | 38 | 隨 v3 素材處理（見計畫 5-1） |
| root_archway_v2 | 88 | 隨 v3 拆層處理 |

## 5. 角色接地與待機（P8.4 抽查）

`treehouse_row18.png`、`archway_north_row21.png`、`town_lower_plaza.png`、`cave_entry.png`：四位角色與 CC 的腳底陰影貼腳、無 2px 漂浮；洞窟裡投擲物與角色風格一致。未發現需要處理的項目。
