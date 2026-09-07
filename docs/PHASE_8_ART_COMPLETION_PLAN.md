# Phase 8：美術完成與可展示垂直切片

基準分支：codex/phase-7-visual-foundation  
基準 commit：fb3c947437a45786c45168b663a45b581cffa133  
目的：把目前已能遊玩的內容整理成「可以完整展示」的 2D 像素風切片。這一階段先處理畫面完整度、建築、TileMap、家具層級與角色可見性，不新增正式劇情、Boss、NPC 或新玩法。

## 0. 本階段已決定的範圍

| 項目 | 決定 |
|---|---|
| 樹屋 | 重出三列高版本，目標 176×96、透明背景、門與踏墊比例保留；props 的底部接地點仍為 (144,672)，foot_inset 改回 0。 |
| 根拱門 | 拆成同尺寸、同錨點的「拱腳＋石板」與「樹冠」兩張 PNG；拱腳走 Y-sort，樹冠才作固定前景。 |
| 地圖拓撲 | 不因美術修正改 ASCII 可走性、出口、出生點、既有室內入口；除非驗收證明目前碰撞本身錯誤，否則不移門。 |
| 房屋 | 目前主城可見的房屋外觀全部補到完整；共享家庭屋與船長房間是本階段的完整室內；未開放的房屋不新增室內場景。 |
| 家具遮擋 | 角色、跟隨者、CC 的身體與陰影不得被家具不合理地裁掉。室內家具預設畫在角色後方；必須在角色前方的部分拆成透明 overlay。 |
| 角色素材 | 不重生四位主角、CC、阿嬤、船長或老龜。沿用目前正式角色檔，避免走路、待機、持物與頭像再次變形。 |
| 劇情邊界 | 不填寫正式劇情、父親真相、Boss 新設定、私人回憶或乾媽家庭傷痛；既有 TEMP_DEMO_CONTENT 不在本階段擅自改成正式文字。 |

## 1. 什麼叫「完成」

1. 主城上層、中層、下層在鏡頭可見範圍內沒有黑洞、透明破口、硬切接縫或明顯未完成地面。
2. 每座目前可見房屋都有完整牆面、屋頂／樹皮、門、窗或招牌，以及清楚的不可走區。
3. 共享家庭屋、船長房間的家具使用同一套像素密度、輪廓、光源方向與色盤。
4. 四位角色、跟隨者與寵物在任何室內家具旁都能看見完整身體與腳底陰影，不會只剩頭或半身。
5. 角色停止時自然待機；行走時腳底與陰影不滑動；切換角色不會換成另一個造型。
6. 未開放區域以完整的門、柵欄、雲霧或樹冠封鎖呈現，而不是讓玩家走進黑色空洞。
7. 新版素材保留舊檔與可逆替換路徑；素材、地圖資料、碰撞與互動不綁死在同一張圖。
8. import、地圖驗證、單元測試、route test 全部通過，且人工截圖看起來像一個可展示的作品切片。

## 2. Phase 8 分段

### P8.0 視覺盤點與基準

先不要修改畫面，建立以下基準：

- 主城：上層入口、中層街道、西側樹屋、根拱門、下層廣場、早餐攤、港口。
- 室內：共享家庭屋、船長房間。
- 戰鬥洞窟：入口、Boss 區、返回點。
- 每個場景輸出完整截圖與角色靠近家具／建築的局部截圖。
- 建立資產表：路徑、尺寸、透明、接地點、碰撞、z_bias、使用場景、是否需要重出。

盤點結果分成：

- KEEP：風格與尺寸通過，只修 JSON 層級或碰撞。
- FIX：素材可保留，但需要重設接地、層級、透明或匯入設定。
- REDRAW：像素密度、光源、輪廓或比例明顯不一致，另存 v3，不覆蓋舊檔。

### P8.1 建築外觀完成

#### 共享家庭樹屋

交付 assets/props/town_refresh/shared_family_treehouse_v3.png：

- 176×96，RGBA，真透明。
- 三列高；門、門框、踏墊、牆面底緣保留原本識別。
- 底緣是真正接地線，不能把草地或道路烙進圖片。
- 不畫碰撞框，不畫角色陰影。
- 光源方向與既有 town_refresh 素材一致。
- 使用後將 foot_inset 設為 0；x、y、collision、傳送門與 return_position 不改。
- 舊 shared_family_treehouse_v2.png 保留作為 fallback。

#### 根拱門

交付兩張同尺寸素材：

- root_archway_v3_base.png：只保留拱腳、根部、石板落地區與必要的開口邊緣。
- root_archway_v3_canopy.png：只保留上方樹冠、藤蔓與不會遮到角色腳部的前景枝葉。
- 兩張都是 176×166、RGBA、同一個底部中央錨點；透明區不能填背景色。
- base 使用原本 collision_boxes；canopy collision 為 null。
- base 不可含會蓋住第 20～21 列角色身體的樹冠；canopy 不能含兩腳或地面。
- 地圖保留目前的兩腳碰撞與通行開口。

建議實作為 props JSON 的兩筆資料：base 使用一般 Y-sort，canopy 使用 z_bias 1。若 z_bias 仍不穩定，再增加 TownProp 的 overlay_texture，但不得把所有大型物件改成全域前景。

#### 其他主城房屋

house_window_lantern、house_banner、house_narrow、house_tree_window、house_balcony 逐一做接觸表檢查。若重出，沿用原 ID 的碰撞與底部接地座標，新增 v3 檔案並在 props JSON 切換：

- 小型立面：96×96 或 128×96。
- 窄屋：96×96。
- 樹屋窗／陽台：128×96。
- 房屋圖只包含房屋本體，不把地面、角色、碰撞框與大段不可走區畫進去。
- 所有外觀使用同一種樹皮／木材輪廓與暖色高光。

#### 未開放的雲端樹冠

上層可見區域要變成完整的未開放景觀：

- 入口保留 canopy_gate 或等價的完整封鎖物。
- 入口後方的黑洞、缺平台、透明破口全部補成連續的雲層／樹冠／木平台 tile。
- 不開放新場景，不新增劇情；玩家只能看到完整封鎖，不會走進未完成區。
- shader 只能低強度套在雲霧或水光，不得用 shader 掩蓋缺圖。

### P8.2 TileMap 與接縫

1. 保留既有 tileset 第 0～5 列，不破壞洞窟與室內舊場景。
2. 交付乾淨版 town_visual_refresh_tiles_32_v3.png，維持 256×128、8 欄×4 列，供現有 Phase 5 builder 使用。
3. 每格 32×32，包含：
   - 草地 A／B／花草變體、石板 A／B。
   - 石板與草地的 N／S／W／E 邊緣及四角。
   - 水岸 N／S／W／E 邊緣及四角。
   - 草崖、樹根牆、橋面、橋側、水面四幀。
   - 東西向橋上列與下列。
4. 四邊可無縫平鋪；沒有亮框、暗框、白線、透明縫或每格獨立陰影。
5. 先在 3×3、5×5、完整主城三種尺度檢查，不能只看單格。
6. 先用 snapshot 比較中層第 12～22 列；確認沒有格線後，才把 scenes.json 主城 tile_style_rows 從 [23,35] 擴到 [0,35]。
7. 若全圖套用後某一區風格回歸，先縮回指定 rows，記錄失敗區域，再補 tile 或調整 TileLibrary。

### P8.3 家具、建築與角色的畫面層級

固定使用：

    Ground TileMap
    → Wall／Root TileMap
    → PropsBack（家具、牆上物件、門、桌、櫃）
    → Characters／Followers／Pet
    → PropsFront（只有拆出的透明樹冠、前景枝葉）
    → UI

實作規則：

- 共享家庭屋與船長房間內，家具預設加 z_bias: -1，讓角色完整可見。
- 家具仍以 JSON collision 阻擋角色，不准用圖層遮擋代替碰撞。
- 優先檢查餐桌、縫紉桌、孩子角落、航海圖桌、船具架、箱子與側桌。
- 若家具確實需要前緣，拆成 base 與透明 front overlay；front 只能包含玩家真的會走到後面的前緣像素。
- cap_rope_coil 維持自己的 event_id、位置與透明背景，不因家具重排而改成硬編碼。
- shader 只能套 Sprite2D，不能套角色、Shadow、CollisionShape2D 或互動區。

### P8.4 角色一致性與接地 QA

本階段不產生新的角色造型。QA 必須同時看：

- 四位角色的正式 walk_v2、idle、action/carry_throw、portrait。
- down／left／right／up 的頭部高度、腳底 y=61、身體寬度。
- Shadow 第一個子節點固定在 (0,0)，不跟著 VisualRoot 微晃。
- 弟弟可以比較矮、姿勢比較低，但不能像沒有接觸地面。
- 待機只由待機表或 VisualRoot 其中一方負責，不能疊加成 2px 漂浮。
- 持物／投擲仍使用同一份角色造型，不得在舉物瞬間變回舊版。

### P8.5 氣氛與可展示畫面

只做不影響玩法的環境 polish：

- 雲霧緩慢漂移。
- 水面低強度反光。
- 燈籠低強度脈動。
- 上層樹冠或港口可有少量粒子。
- shader 有 strength／speed 等可調 uniform，預設低強度；關閉後仍可遊玩。
- Debug HUD、座標、格子、測試文字只在 debug／route test 開啟，正常啟動的展示畫面不應被底部除錯列壓住。
- 不用 shader 解決缺圖、遮擋或碰撞。

## 3. 必須產出的截圖 QA

至少保存：

| 截圖 | 驗收 |
|---|---|
| phase8_town_upper_clean.png | 上層沒有黑洞、入口封鎖完整 |
| phase8_town_middle_transitions.png | 草地／石板過渡沒有硬切 |
| phase8_treehouse_door.png | 樹屋三列高、門檻接地、隊伍不被屋頂遮 |
| phase8_archway_north.png | 站在第 21 列時樹冠在頭部上方、拱腳不遮角色 |
| phase8_family_home_party.png | 四人經過餐桌、縫紉區、孩子角落時完整可見 |
| phase8_captain_room_party.png | 四人經過航海圖桌、船具架、箱子時完整可見 |
| phase8_cave_battle.png | 洞窟與角色／投擲物不出現風格斷裂 |
| phase8_idle_shadow.png | 四位角色停止時陰影貼腳、待機自然 |
| phase8_day_night.png | 白天、黃昏、夜晚仍保留同一套美術層級 |

## 4. 驗收命令

每次替換 PNG 或 atlas：

~~~bash
godot --headless --path . --import
~~~

每次修改地圖、props、scene 或腳本：

~~~bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

最後：

~~~bash
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
~~~

交付報告列出：

- 每張新增／替換 PNG 的 file 結果、尺寸、RGBA、SHA-256。
- 哪些 props 使用新檔、哪些保留舊檔。
- 主城 tile_style_rows 的實際範圍。
- 家具 z_bias／overlay 的變更。
- 角色素材沒有被重生的證據。
- validate_map、unit test、route test 結果。
- 仍存在的視覺例外；不能用「測試通過」取代人工截圖。

## 5. 不要在 Phase 8 做的事

- 不新增正式劇情、正式 Boss、NPC 或父親離世演出。
- 不把主城畫成一張不可拆的全背景。
- 不用全域 z_index 把所有角色永遠畫在所有物件上方。
- 不為了修一張房屋圖移動所有門與出口。
- 不把 SVG、PSD、Pixquare 原檔放進實際載入目錄；來源檔放 assets/reference/incoming/，遊戲使用的只有經檢查的 PNG。
- 不刪除舊素材；所有新版美術都可回退。
