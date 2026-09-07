# Phase 8 實體教學：替換 TileMap、增加物品與完成房屋

這份文件只補 Phase 8 的差異（拆層、TileMap v3、家具層級）。安裝 Godot、座標怎麼讀、Aseprite 設定、逐步畫一個花盆放進場景，請先看 docs/PHASE_7_SCENE_EDIT_TUTORIAL.md（零基礎完整版）。專案目前採「ASCII 地圖＋程式建立 TileMap＋Props JSON＋獨立碰撞」；不要把整張畫面輸出成一張背景圖。

## 1. 先做安全準備

~~~bash
git status
git fetch origin
git switch phase-8-art-complete
git switch -c my-phase8-art-test
~~~

如果 git status 有別人的未提交修改，先停止，不要覆蓋。

保存基準：

~~~bash
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

美術改動前先截圖。使用 README 已提供的 --snapshot 方式，至少截主城上層／中層／下層、family_home、captain_room、fried_food_cave。

## 2. 每個檔案做什麼

| 要改的東西 | 實際檔案 |
|---|---|
| 哪些格子可走、牆、橋、樓梯 | assets/maps/*.txt |
| 建築、家具、燈籠、位置、碰撞 | assets/maps/*_props.json |
| 場景登錄與套用哪段 TileMap 樣式 | assets/maps/scenes.json |
| 圖例與鄰接如何選 atlas tile | scripts/world/tile_library.gd |
| 32×32 像素圖 | assets/tilesets/*.png |
| 大型道具圖片 | assets/props/ |
| 角色／陰影 | assets/characters/、assets/effects/ |

素材來源檔（PSD、SVG、Pixquare 原檔、參考圖）放 assets/reference/incoming/；遊戲實際讀取的才放 assets/props/、assets/tilesets/ 等目錄。

## 3. Pixquare 畫 TileMap tile

固定規格：

| 用途 | 畫布 |
|---|---:|
| 單格 tile | 32×32 |
| 8×4 城鎮 atlas | 256×128 |
| 4×4 測試表 | 128×128 |
| 3×3 無縫測試 | 96×96 |
| 多格地面參考 | 128×128 或 256×256 |

設定：

- 像素格線開啟。
- 1×像素繪製；匯出時不要抗鋸齒。
- PNG RGBA。
- Nearest。
- Mipmap 關閉。
- 不畫白框、黑框、每格獨立陰影或透明縫。
- 光源方向與現有 town_refresh 素材一致。

城鎮 atlas 的 8×4 用途：

| 區域 | 內容 |
|---|---|
| 第 0 列 | 草地 A／B、花草、泥土、石板 A／B、木板、深水 |
| 第 1 列 | 石板 N／S／W／E、石板四角 |
| 第 2 列 | 水岸 N／S／W／E、水岸四角 |
| 第 3 列 | 草崖、樹根牆、橋面、橋側、水面四幀／方向橋補件 |

交付前用 3×3 和 5×5 平鋪測試。單格漂亮不代表可以平鋪。

## 4. 替換一棟房屋

不要直接覆蓋舊檔，先使用新版本：

    assets/props/town_refresh/shared_family_treehouse_v3.png

樹屋規格：

- 176×96。
- 真透明 RGBA。
- 三列高。
- 底部是接地線，不包含地面。
- 不畫碰撞框與角色陰影。

在 assets/maps/tide_root_town_props.json 把 texture 指向新 ID，並保留：

~~~json
{
  "texture": "town_refresh/shared_family_treehouse_v3",
  "x": 144,
  "y": 672,
  "collision": [150, 60],
  "foot_inset": 16
}
~~~

foot_inset 16 是因為 v3 最下方 16px 是踏墊，畫在接地線以下；這樣貼圖頂端在 y=592，第 18 列走道的角色（原點 y=592）完全不會被屋頂蓋到。x、y、collision、family_home_door 傳送門與返回點不要改。完成後截樹屋門口與第 18 列上方走道。

## 5. 把一座大型建築拆成前後兩層

根拱門兩張 PNG 都是 176×166，同一個底部中央錨點：

- base：拱腳、石板、開口邊緣。
- canopy：樹冠、藤蔓前景。

Props JSON 概念：

~~~json
{
  "texture": "town_refresh/root_archway_v3_base",
  "render_mode": "split",
  "split_role": "base",
  "x": 480,
  "y": 762,
  "collision": null,
  "foot_inset": 38,
  "collision_boxes": [[49,58,-57,0],[57,58,62,0]]
}
~~~

~~~json
{
  "texture": "town_refresh/root_archway_v3_canopy",
  "render_mode": "split",
  "split_role": "canopy",
  "x": 480,
  "y": 762,
  "collision": null,
  "foot_inset": 38
}
~~~

`render_mode: split` 的 base 走 Y-sort、canopy 固定在角色前方（程式依 render_mode 決定 z_index，不再寫 `z_bias`）。碰撞盒高 58 是讓頂端 y=704 落在第 22 列格線上（驗證器 MAP-P001）。

不要讓 canopy 帶 collision；不要把 base 的兩腳碰撞搬到 canopy。若兩張接縫不合，修圖的錨點，不要在 JSON 中把兩張圖設成不同縮放。

## 6. 讓家具不遮角色

角色被桌子遮住通常不是角色圖壞掉，而是碰撞盒比圖片矮太多，角色走進了「圖片裡面」。先加深碰撞；自立家具的 `render_mode` 一律是 `ysort`，不要改成 `back`。

在 family_home_props.json 和 captain_room_props.json：

~~~json
{
  "texture": "int_dining_table",
  "x": 200,
  "y": 262,
  "collision": [112, 76]
}
~~~

圖高 92、碰撞從 46 提到 76：碰撞盒從接地線往上量，角色最多只能走到圖片頂端下方 16px，被蓋到的只有腳踝，Y-sort 仍然正確。`render_mode: back` 只給牆上物件、門、窗，`ground` 只給地毯；自立家具改成 back 會讓站在北側的角色整個畫在桌面上。碰撞高度取「圖高 − 16」後再往上對齊到 32 的倍數（`python3 tools/validate_map.py --audit` 會算），否則多出的幾 px 會把上一整列封掉。第一批檢查：

- int_dining_table
- int_sewing_table
- int_kids_corner
- cap_chart_desk
- cap_rod_rack
- cap_chest_stack
- cap_side_table

如果家具真的需要玩家走到後面時只顯示前緣，把圖片拆成 furniture_base.png 與 furniture_front.png。base 放後方；front 使用透明背景、只保留前緣。不要把整張桌子放到角色前方。

## 7. 替換城鎮 TileMap

1. 新 atlas 使用新檔名，例如：

       assets/tilesets/town_visual_refresh_tiles_32_v3.png

2. 確認：

~~~bash
file assets/tilesets/town_visual_refresh_tiles_32_v3.png
~~~

要看到 PNG、RGBA，尺寸必須 256×128。

3. 用 tools/build_assets_phase5.py 或本階段指定 builder 產生遊戲 tileset。
4. 執行：

~~~bash
godot --headless --path . --import
~~~

5. 先在 scenes.json 使用 tile_style_rows [12,35] 截圖確認中層，再改為 [0,35]。
6. 若出現格線或方向錯誤，先退回舊 rows，不要直接把壞 atlas 提交。

## 8. 自製物件的接地與碰撞

大型 PNG 不是「圖片中央對準座標」，而是底部接地點對準座標：

- origin 放在角色可以站立的地面線。
- 圖片不能把地面畫進去。
- 碰撞寫在 JSON，不畫在圖片內。
- foot_x 修正接地點水平位置。
- foot_inset 修正貼圖底部到接地線的距離。
- render_mode 決定層級（ground／back／ysort／split），每個物件必填；沒有 z_bias。

每次增加一件物品，先只設定 texture、x、y、collision；截圖看落地後，再增加 glow、interact、frames 或 shader。

## 9. 素材交付檢查

~~~bash
file path/to/asset.png
head -c 8 path/to/asset.png | xxd
sha256sum path/to/asset.png
godot --headless --path . --import
~~~

PNG 前 8 bytes 必須是：

    89 50 4e 47 0d 0a 1a 0a

另外人工看：

- 四角真透明。
- 沒有白底、棋盤格或黑底。
- 3 倍放大沒有白線。
- 底部接地一致。
- 沒有把陰影烙進圖。
- 沒有半透明抗鋸齒邊。
- 角色與家具的像素密度一致。

## 10. 出錯如何回退

保留舊檔，將 JSON texture 改回舊 ID；atlas 將 tile_style_rows 改回前一版，重新 import、validate、測試。不要刪掉舊素材，也不要用 git reset --hard 消除別人的修改。

## 11. 完工前人工走一遍

- 樹屋門口、上方第 18 列、西橋頭。
- 根拱門北側第 21 列、拱門內、兩側兩腳。
- 家庭屋餐桌與縫紉區。
- 船長房間航海圖桌與繩圈。
- 四位角色輪流待機、走路、舉物、投擲。
- CC 跟隨、洞窟五次命中、回傳早餐攤。
- 休息換日後每日掉落物重置，船長房間事件旗標仍保留。
