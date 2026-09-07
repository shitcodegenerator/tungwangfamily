# Phase 8 實體教學：替換 TileMap、增加物品與完成房屋

這份文件針對第一次自己改 Godot 場景的人。專案目前採「ASCII 地圖＋程式建立 TileMap＋Props JSON＋獨立碰撞」；不要把整張畫面輸出成一張背景圖。

## 1. 先做安全準備

~~~bash
git status
git fetch origin
git switch --track origin/codex/phase-8-art-complete
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
  "foot_inset": 0
}
~~~

x、y、collision、family_home_door 傳送門與返回點不要改。完成後截樹屋門口與第 18 列上方走道。

## 5. 把一座大型建築拆成前後兩層

根拱門兩張 PNG 都是 176×166，同一個底部中央錨點：

- base：拱腳、石板、開口邊緣。
- canopy：樹冠、藤蔓前景。

Props JSON 概念：

~~~json
{
  "texture": "town_refresh/root_archway_v3_base",
  "x": 480,
  "y": 762,
  "collision": null,
  "foot_inset": 38,
  "collision_boxes": [[49,40,-57,0],[57,40,62,0]]
}
~~~

~~~json
{
  "texture": "town_refresh/root_archway_v3_canopy",
  "x": 480,
  "y": 762,
  "collision": null,
  "foot_inset": 38,
  "z_bias": 1
}
~~~

不要讓 canopy 帶 collision；不要把 base 的兩腳碰撞搬到 canopy。若兩張接縫不合，修圖的錨點，不要在 JSON 中把兩張圖設成不同縮放。

## 6. 讓家具不遮角色

角色被桌子遮住通常不是角色圖壞掉，而是整張家具圖片的 Y-sort 層級不適合。

在 family_home_props.json 和 captain_room_props.json：

~~~json
{
  "texture": "int_dining_table",
  "x": 200,
  "y": 262,
  "collision": [112,46],
  "z_bias": -1
}
~~~

這代表家具在角色後方，但 collision 仍然會擋住角色。第一批檢查：

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
- z_bias 只作小幅視覺層級，不拿來掩蓋錯誤碰撞。

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
