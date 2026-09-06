# 手把手：在 tungwangfamily 增加物品、建築物與替換地圖美術

這份文件給第一次自己修改 Godot 地圖的人使用。
目前專案不是把一張大 PNG 當作整張地圖，而是由地圖資料、TileMap、Props、
碰撞與互動點組合而成。只要照這個順序操作，就能逐步美化畫面而不破壞角色、
出口、任務和存檔。

## 0. 先理解目前專案的資料流

    ASCII 地圖 txt
    → MapParser
    → TileLibrary
    → Ground／Wall TileMap
    → Props JSON
    → TownWorld
    → Collision／Interactable／NPC

不同檔案的責任：

| 檔案 | 負責內容 |
|---|---|
| assets/maps/*.txt | 哪些格子可走、牆、橋、樓梯與區域 |
| assets/maps/*_props.json | 建築、家具、燈籠、箱子的位置與碰撞 |
| assets/maps/scenes.json | 場景登錄、tile_style、出口與戰鬥設定 |
| scripts/world/tile_library.gd | 字元與鄰接地形如何選 tile |
| assets/tilesets/*.png | 32×32 的實際像素圖 |
| Interactable | 玩家靠近後能否按 E 互動 |
| Collision | 玩家是否可以穿過 |

不要把所有責任塞進同一張圖片或同一支腳本。

## 1. 開始前先建立安全分支

在終端機進入專案資料夾：

~~~bash
git status
git fetch origin
git switch -c phase-6-my-scene-edit
~~~

如果 git status 顯示有尚未提交的修改，先不要切換或覆蓋素材。
先把目前的修改提交，或請本地 AI 處理工作樹。

先保存目前畫面：

~~~bash
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

## 2. 自製 PNG 的基本規格

### 2.1 Tile

使用 Pixquare 時：

| 用途 | 畫布 |
|---|---|
| 單格 tile | 32×32 |
| 4×4 測試表 | 128×128 |
| 8×4 atlas | 256×128 |
| 多格地面圖案 | 128×128 或 256×256 |

Tile 必須：

- PNG RGBA。
- 透明背景。
- Nearest Filter。
- 不要抗鋸齒。
- 不要 Mipmaps。
- 不要在格子四周畫外框。
- 不要把角色陰影烘焙進地面。
- 光源方向和既有素材一致。

### 2.2 地圖物件

大型物件尺寸可以是 32 的倍數，例如：

    64×96
    96×128
    128×160
    176×162

物件最重要的不是圖片外框，而是底部接地點。
例如一棵樹的 origin 應該在樹根接觸地面的地方，而不是圖片正中央。

圖片內不要畫碰撞框；碰撞要由 JSON 或 CollisionShape2D 控制。

## 3. 在 Pixquare 畫一個新物件

以一盞新燈籠為例：

1. 建立 64×96 畫布。
2. 開啟像素格線。
3. 先畫木柱，再畫燈籠，再畫小範圍高光。
4. 預留透明區，讓物件底部可以對齊地面。
5. 將最底部接觸地面的像素放在同一條基準線。
6. 移除白底、棋盤格和背景色。
7. 使用 RGBA PNG 匯出。
8. 將檔案放入 assets/props/town_refresh/。

匯出後在終端檢查：

~~~bash
file assets/props/town_refresh/my_lantern.png
~~~

看到 PNG image data 和 RGBA 才算正確。

## 4. 把物件加入地圖

目前主城使用：

    assets/maps/tide_root_town_props.json

新增一個簡單物件：

~~~json
{
  "texture": "my_lantern",
  "x": 18,
  "y": 22,
  "collision": [10, 8],
  "z_bias": 0,
  "foot_x": 32,
  "glow": true,
  "glow_x": 32,
  "glow_y": 28
}
~~~

欄位說明：

| 欄位 | 意義 |
|---|---|
| texture | 對應 assets/props 裡的素材 ID |
| x、y | 地圖像素座標 |
| collision | 矩形碰撞大小 |
| z_bias | 微調 Y-sort 順序 |
| foot_x | 接地點在圖片中的水平位置 |
| glow | 是否產生燈光效果 |
| glow_x、glow_y | 燈光中心位置 |

第一次加入物件時，建議只設定圖片和碰撞。
確認位置正確後，再加入互動或發光效果。

## 5. 加入互動點

如果物件要按 E 互動，增加：

~~~json
{
  "texture": "my_lantern",
  "x": 18,
  "y": 22,
  "collision": [10, 8],
  "interact": "my_lantern",
  "interact_size": [48, 42],
  "prompt_offset": [0, -48]
}
~~~

然後在對應的：

    assets/dialogue/tide_root_town.json

新增暫時對話：

~~~json
{
  "my_lantern": {
    "speaker": "燈籠",
    "lines": [
      "【TEMP_DEMO_CONTENT】燈火安靜地搖了一下。"
    ]
  }
}
~~~

正式劇情文字不要自己補。先用 TEMP_DEMO_CONTENT，等作者確認後再換。

## 6. 加入建築物的正確方式

不要把一棟房子畫成單一張不能拆的大背景。

至少拆成：

    牆面 tile
    → 屋頂或樹皮 tile
    → 門
    → 窗
    → 招牌
    → 樓梯或平台
    → 碰撞
    → 入口與互動點

加入建築物的順序：

1. 先在 ASCII 地圖預留地面和通道。
2. 先放牆面和屋頂，不放裝飾。
3. 加入門與出口。
4. 設定碰撞。
5. 用 route test 確認能進出。
6. 最後才加窗戶、花、旗子、箱子與燈籠。

這樣即使之後換房屋外觀，也不需要重新設計整張地圖。

## 7. 替換 TileMap 的安全流程

### 7.1 先不要覆蓋舊 atlas

把新版放在新的檔名，例如：

    assets/tilesets/town_visual_refresh_tiles_v3.png

舊版先保留，因為其他場景可能仍然使用它。

### 7.2 製作 atlas

每格必須是 32×32：

    256×128 = 8 欄 × 4 列

每一列要先寫清楚用途，例如：

| 列 | 用途 |
|---|---|
| 0 | 草地、泥土、石板、木板 |
| 1 | 石板路邊緣與角落 |
| 2 | 水岸邊緣與角落 |
| 3 | 橋、樹根牆、水面動畫 |

邊緣 tile 必須同時有：

- 上邊。
- 下邊。
- 左邊。
- 右邊。
- 左上、右上、左下、右下角。
- 必要的內角。

一張漂亮的中心 tile 不足以做成完整地圖。

### 7.3 Godot 匯入設定

替換 PNG 後執行：

~~~bash
godot --headless --path . --import
~~~

在 Godot 檢查 Import：

- Texture Filter：Nearest。
- Mipmaps：關閉。
- Repeat：關閉。
- 不要使用非整數縮放。

### 7.4 將樣式套用到一個區域

不要一次換整張主城。

先在 assets/maps/scenes.json 為一個場景或區域指定：

~~~json
{
  "tile_style": "town_refresh",
  "tile_style_rows": [23, 35]
}
~~~

需要依照上下左右鄰居選 tile 時，應在 TileLibrary 新增專用函式。
不要在 JSON 裡寫滿每一個座標的 tile。

## 8. 做一個場景特效 Shader

Shader 適合做：

- 舷窗水光。
- 水面反光。
- 雲霧緩慢流動。
- 燈光細微脈動。

Shader 不適合做：

- 角色走路。
- 角色陰影。
- 碰撞。
- 主要物件位移。

建立檔案：

    assets/shaders/my_ambient_effect.gdshader

在 Godot 中：

1. 選取要套用的 Sprite2D 或 ColorRect。
2. Inspector 找到 Material。
3. 新增 ShaderMaterial。
4. 將 Shader 指定為 my_ambient_effect.gdshader。
5. 將強度先調到很低。
6. 在 640×360 畫面檢查是否搶過角色和對話框。

Shader 必須有可以調低的 uniform，例如 strength、speed、tint。
即使特效完全關閉，地圖和互動仍要正常。

## 9. 新增會移動的物件

物件移動請使用：

- AnimationPlayer。
- Tween。
- 通用 WorldEventRunner。

不要在物件自己的 _process 裡永遠改 position，否則：

- 事件可能無法停止。
- 存檔後位置可能錯誤。
- 進入其他場景仍可能繼續移動。
- route test 很難重現。

推薦事件順序：

    互動
    → 對話
    → lock_input
    → tween
    → effect
    → set_flag
    → unlock_input

事件完成旗標應該在全部動畫成功完成後才寫入。

## 10. 物件位置與碰撞檢查

放好物件後，使用 snapshot 截圖檢查：

- 物件是否落地。
- 角色是否能從旁邊通過。
- 物件是否遮住出口。
- 物件是否擋住出生點。
- NPC 是否被物件卡住。
- 大型物件是否蓋住不該蓋的道路。
- 角色陰影是否仍在腳底。

大型物件蓋住北側道路不一定是程式錯誤，可能是 Y-sort 正常結果。
如果不符合畫面意圖，優先縮小或移動物件，不要亂改 z_index。

## 11. 每次修改後固定驗證

修改圖片時：

~~~bash
godot --headless --path . --import
~~~

修改地圖、碰撞或 Props 後：

~~~bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
~~~

最後執行 route test，並看遊戲截圖。

必要檢查：

- 角色走路沒有滑行。
- 角色待機自然晃動。
- 陰影沒有離開腳底。
- 角色切換後比例一致。
- Tile 沒有白線。
- 物件沒有漂浮。
- 出口仍然能使用。
- 每日掉落物仍會在換日後重置。
- 船長房間事件只會按照旗標規則播放。

## 12. 如何安全撤回美術

如果新版素材不好看：

1. 不要刪除舊素材。
2. 將 Props JSON 的 texture 改回舊 ID。
3. 將 scenes.json 的 tile_style 改回舊樣式。
4. 再跑三道驗證。
5. 確認可以正常啟動後再提交。

美術優化應該是可逆的。只要地圖資料、碰撞資料和素材路徑分離，
就能逐區替換，不需要因為一張圖不好看而重做整個專案。

