# 給本地 AI：Phase 8 美術完成與可展示切片

請從遠端拉取並執行本階段：

~~~bash
git fetch origin
git switch --track origin/codex/phase-8-art-complete
~~~

如果本地已有未提交修改，先停下來回報，不要覆蓋作者或其他 AI 的工作。

## 必讀順序

1. AGENTS.md
2. docs/PRODUCTION_NOTES.md
3. docs/PHASE_7_REPORT.md
4. docs/NOTES_FOR_PLANNER_PHASE_7.md
5. docs/ART_STYLE_LOCK.md
6. docs/PHASE_8_ART_COMPLETION_PLAN.md
7. assets/reference/incoming/PHASE8_ART_ASSET_MANIFEST.json
8. docs/PHASE_8_SCENE_ART_TUTORIAL.md

本階段最高目標是「畫面完整、不破圖、家具不遮角色、角色造型一致」。不要先加新劇情或新玩法。

## 0. 開始前

1. 確認目前 HEAD 與 fb3c947437a45786c45168b663a45b581cffa133 的關係。
2. 保存 Phase 7 基準截圖；不要把原截圖刪掉。
3. 執行：

~~~bash
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

4. 用 --snapshot 取得主城上層／中層／下層、共享家庭屋、船長房間、洞窟的基準圖。
5. 產生資產 contact sheet，至少包含 town_refresh 全部 prop、int_* 家庭屋家具、cap_* 船長房間家具、四位主角 walk_v2／idle／action 三組。
6. 盤點每個物件的尺寸、透明、底部接地線、z_bias、collision；先分 KEEP／FIX／REDRAW 再修改。

## 1. 不可違反的視覺規則

- 不重新生成四位主角、CC、阿嬤、船長、老龜。
- 不改四位主角的角色 ID、walk_v2、idle、action、portrait 路徑，除非測試證明匯入錯誤。
- 不把角色陰影烙進角色或家具 PNG。
- 不把整張房間或主城做成單張背景。
- 不用角色上色、透明度或 shader 遮掩美術問題。
- 不用 z_bias 掩蓋碰撞錯誤。
- 不改 tide_root_town.txt、既有門座標、出口、出生點，除非先在報告列出理由並得到作者確認。
- 正式文字、劇情、Boss、私人回憶仍遵守 PHASE_3_DECISIONS.md。

## 2. 建議實作順序

### A. 樹屋與根拱門

1. 將 shared_family_treehouse_v3.png 接到共享家庭樹屋。
2. 設定 foot_inset: 0，x/y、collision、family_home_door、return_position 不變。
3. 將 root arch 的 base 與 canopy 設為同 x/y/foot_inset：
   - base：保留 collision_boxes，一般 Y-sort。
   - canopy：collision: null、z_bias: 1，只含樹冠像素。
4. 如果 base／canopy 接合有縫，先修兩張 PNG 的共同錨點，不要靠任意縮放。
5. 站在根拱門正北第 21 列、拱門內、拱門兩側各截圖。

### B. 室內家具不遮角色

在 family_home_props.json 與 captain_room_props.json 做資料層修正：

- 家具、櫃子、桌子、架子預設加 z_bias: -1。
- 地板、地毯、牆上裝飾維持背景層。
- 事件目標繩圈維持可見、透明、event_id 與原位置規格。
- 如果某一件家具必須有前緣，不讓整張圖前景化；拆成 base／front overlay，front 只保留透明前緣。
- 重新檢查 collision，保證角色是被碰撞擋住，不是被圖片裁掉。
- 優先檢查餐桌、縫紉桌、孩子角落、航海圖桌、船具架、箱子與側桌。

### C. 中上層 TileMap

1. 不覆蓋舊 tileset 第 0～5 列。
2. 收到 town_visual_refresh_tiles_32_v3.png 後先驗證：
   - file 是 RGBA PNG。
   - 尺寸 256×128。
   - 每格 32×32。
   - 8×4 皆存在。
   - 3×3 平鋪沒有白線／暗線。
3. 跑 builder，重建遊戲 tileset。
4. 先把 tile_style_rows 擴到 [12,35] 做中層試跑，截圖確認；再擴到 [0,35]。
5. 若上層有未開放空間，優先補齊封鎖後景與平台，不要讓玩家走進黑洞。
6. 碰撞與 ASCII 可走性不因換圖而改變。

### D. 房屋與家具的風格修正

- 外部房屋只替換 props 圖，不把地面畫進房屋圖。
- 若舊素材與新 town_refresh 風格不一致，保留舊檔並新增 v3，在 props JSON 切換。
- 維持 1×像素邏輯、Nearest、固定左上光源、深靛／暖棕／琥珀色盤、深紫棕輪廓。
- 不要增加高解析柔邊、半透明抗鋸齒或照片式紋理。
- 家具的接地點要貼在木地板上；大型家具的底緣不可以懸空一格。

### E. 氣氛與展示模式

- 保留舷窗水光 Shader；只在環境 Sprite2D 上使用。
- 可加低強度雲霧、水面、燈籠脈動。
- 正常啟動畫面不顯示座標與除錯列；route test 仍可要求 debug HUD。
- 不讓 shader 改變角色、Shadow、Collision 或互動區。

## 3. 每批修改後驗證

素材批次：

~~~bash
godot --headless --path . --import
~~~

資料／腳本批次：

~~~bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

可展示驗收：

~~~bash
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
~~~

最終回報必須分成：

### 已完成

逐檔列出新增／替換素材、尺寸、RGBA、SHA-256；修改的 props JSON、scenes.json、TileLibrary、TownProp 或 UI；截圖名稱與驗證內容；import、validate_map、unit test、route test 結果。

### 仍需本地 AI 實作

如果素材尚未到位，不能假裝完成；列出等待的檔名、尺寸、透明規格與接線位置。

### 仍需作者確認

只列真正會影響內容或地圖拓撲的選項；不要再次詢問 Phase 7 已決定的翻頁鍵、回頂端、樹屋不移門、拱門拆層方向。

## 4. 回歸檢查

至少人工走過：

1. 樹屋門口與西橋頭。
2. 根拱門北側第 21 列、拱門內、兩腳旁。
3. 家庭屋餐桌、縫紉區、孩子角落。
4. 船長房間航海圖桌、繩圈、船具架與箱子。
5. 洞窟撿取、舉物、投擲與五次命中。
6. 四位角色切換、待機、走路、持物，確認腳底與陰影。
7. 換日後每日掉落物仍重置，船長房間事件旗標不被清掉。

不要在這一階段刪除舊素材或重寫正式劇情。
