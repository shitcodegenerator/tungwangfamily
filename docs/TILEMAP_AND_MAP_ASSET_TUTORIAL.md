# Godot TileMap 與地圖素材替換教學

這篇以目前 tungwangfamily 的架構為例，說明如何逐步替換地圖 tile 和其他地圖物件。核心原則是：圖片負責長相，地圖資料負責位置，碰撞與互動另外管理。這三者分開，未來才能只換美術、不重寫劇情與地圖邏輯。

## 一、先理解目前專案的地圖結構

目前專案不是把整張地圖畫死成一張大圖，而是由幾層資料組合：

~~~text
地圖 ASCII／JSON
       ↓
MapParser 解析格子與可走性
       ↓
TileLibrary 依圖例與鄰居選 atlas 格子
       ↓
TownWorld 建立視覺 TileMap
       ↓
Props JSON 建立房屋、燈籠、木箱、NPC 與互動區
~~~

目前可參考的程式位置：

- scripts/world/tile_library.gd：圖例字元與 atlas 座標的對應、鄰接判斷、洞窟樣式。
- scripts/world/town_world.gd：解析地圖並建立視覺與裝飾層。
- assets/maps/*.txt：以字元表示哪裡可走、哪裡是牆、水或橋。
- assets/maps/*_props.json：獨立記錄物件位置、碰撞、互動 id 和排序偏移。
- assets/maps/scenes.json：場景尺寸、入口、tile_style 和特殊場景設定。

這代表你可以先換一張 atlas，再逐步調整圖例；不需要把角色、任務、出口和碰撞全部重做。

## 二、Tile、Tile sheet、TileMap 分別是什麼

### Tile

一個可重複使用的小格子。目前專案的基本單位是 32×32 像素。

### Tile sheet／atlas

很多 tile 排在同一張 PNG 裡。例如本階段的城鎮 atlas 是 8 欄×4 列：

~~~text
寬度：8 × 32 = 256 px
高度：4 × 32 = 128 px
~~~

### TileMap

把 tile 放到地圖格子上的配置。TileMap 只記得「某格使用 atlas 的哪一格」，不會把完整圖片複製進每一格。

## 三、自製 tile 的標準規格

### 1. 尺寸與格式

| 項目 | 規範 |
|---|---|
| 基本格 | 32×32 px |
| Atlas | 寬、高都必須是 32 的整數倍 |
| 格線 | 正式 atlas 不放白線、黑線或可見間隔 |
| 格式 | PNG、RGBA |
| 縮放 | Godot 使用 Nearest，不使用平滑插值 |
| 像素 | 避免半像素座標與非整數縮放 |
| 邊界 | 可平鋪 tile 的四邊不要有只在單邊出現的光暈 |

### 2. 一格只負責一種材質

- 草地 tile 只畫草地。
- 石板 tile 只畫石板。
- 草地與石板交界要另外做 edge／corner tile。
- 不要把房屋陰影、角色陰影或固定物件畫進地面 tile。
- 不要把碰撞形狀畫進正式美術；碰撞放在地圖資料或獨立碰撞層。

### 3. 顏色與光源一致

同一張地圖要假定同一個主要光源方向。例如所有屋頂、樹根和石板的亮面都朝左上，陰影都朝右下。不要讓草地是柔和高亮、石板卻是強烈黑邊，否則就會出現目前畫面中的「素材各自漂亮、放在一起卻不屬於同一個世界」的感覺。

## 四、鄰接 tile 怎麼設計

最容易破圖的不是中心 tile，而是兩種材質交界。至少要準備：

| 類型 | 用途 |
|---|---|
| 中心 tile | 大面積重複使用，例如草地、石板、水 |
| 上／下／左／右 edge | 兩種材質直線交界 |
| 四個 corner | 轉彎、道路變寬或水岸轉角 |
| 內凹 corner | 凹字形水岸、平台或道路 |
| 變體 tile | 同材質不同碎石、草紋或水紋，避免棋盤格 |

本階段提供的 town_visual_refresh_tiles_32.png 對應如下：

| 列 | 內容 |
|---:|---|
| 0 | 草地 A、草地 B、花草草地、泥土、石板 A、石板 B、木板、深水 |
| 1 | 草地／石板的上下左右 edge 與四個 corner |
| 2 | 草地／水岸的上下左右 edge 與四個 shore corner |
| 3 | 草崖、樹根牆、橋面、橋側、水面動畫 4 幀 |

使用時不要只把四種中心 tile 隨機散落。道路應由中心 tile、邊緣 tile、轉角 tile 組成；隨機變體只放在同材質內部。

## 五、在目前專案替換 tilemap 的步驟

### 步驟 1：先製作新 atlas，不覆蓋舊檔

建議先使用版本檔名：

~~~text
assets/tilesets/town_visual_refresh_tiles_32.png
~~~

不要一開始直接覆蓋 tide_root_town_tileset.png。先讓新舊 atlas 並存，方便比較與回退。

### 步驟 2：確認切割座標

如果 atlas 是 8×4：

~~~text
atlas (0,0) = x 0～31，   y 0～31
atlas (1,0) = x 32～63，  y 0～31
atlas (0,1) = x 0～31，   y 32～63
~~~

在 Godot 中確認 TileSet 的 Tile Size 是 32×32，Texture Region Size 也是 32×32。若切割結果出現白邊，通常是 atlas 內有間隔、Texture Region Size 錯誤，或匯入快取仍是舊檔。

### 步驟 3：設定 Godot 匯入

選取 PNG 後，在 Import 面板確認：

- Texture Filter：Nearest。
- Mipmaps：關閉。
- Repeat：atlas 通常關閉。
- 匯入後按 Reimport；也可以執行：

~~~bash
godot --headless --path . --import
~~~

目前專案曾遇到「PNG 已更新，但執行期仍使用 .godot/imported 舊快取」的問題，因此只複製檔案而不重新匯入是不足夠的。[Phase 4.6 報告](https://github.com/shitcodegenerator/tungwangfamily/blob/master/docs/PHASE_4_6_REPORT.md)

### 步驟 4：讓 TileLibrary 使用新 atlas

目前架構由 TileLibrary 建立 atlas。建議新增一個可切換的 style，而不是刪除舊邏輯：

~~~gdscript
const TILE_STYLE_TOWN_REFRESH := "town_refresh"

if options.get("tile_style", "") == TILE_STYLE_TOWN_REFRESH:
    return town_refresh_atlas_for(parser, x, y)
~~~

town_refresh_atlas_for() 需要依據：

1. 目前格子的材質。
2. 上、下、左、右鄰居材質。
3. 是否為道路／水岸轉角。
4. 是否應放變體 tile。

不要只用固定座標把石板貼在某個區域；這樣地圖一改大小就會破圖。

### 步驟 5：保持碰撞資料不變

第一次替換美術時，請不要同時改 ASCII 地圖和碰撞。先確認「長相變了，但可走性完全沒變」。確認成功後，才另開 commit 修改地圖形狀。

水、樹根牆、房屋和橋面通常需要不可走區；這些判定不應依賴圖片的透明像素，而應由 MapParser、碰撞層或物件 JSON 決定。

## 六、地圖上的其他素材怎麼替換

地圖物件不要塞進 tilemap。建議分成三類：

### A. 地面材質

使用 TileMap，例如草地、石板、水、木橋、樹根牆。

### B. 大型裝飾物

使用獨立 PNG，例如共享家庭屋、早餐攤、心形噴泉和根拱門。物件原點要放在「角色應站立的地面中心」，而不是圖片的左上角或圖片中心。

目前 props JSON 的概念如下：

~~~json
{
  "texture": "shared_family_treehouse_v2",
  "x": 144,
  "y": 672,
  "collision": [84, 64],
  "z_bias": 0
}
~~~

x, y 是世界座標；collision 是獨立碰撞尺寸；z_bias 只在物件需要略微提前或延後排序時使用。

### C. 小型裝飾與粒子

例如花、草、螢火蟲、燈光。可以放在 Decoration layer，不要影響走路和任務。若是燈籠，燈光範圍也應獨立於燈籠圖片。

## 七、大型物件的接地與 Y-sort

一個物件的圖片可以很高，但它的地面接觸點只有一個。推薦：

~~~text
TownWorld
├─ GroundTileMap
├─ DecorationTileMap
├─ Props
│  ├─ SharedFamilyTreehouse
│  ├─ BreakfastStall
│  └─ Lantern
└─ Characters
~~~

規則：

- 物件底部才是排序基準。
- 角色 Shadow 固定在地面錨點。
- 房屋上半部可以蓋住角色，但門口與可走區不可被錯誤碰撞封死。
- 不要把一棵完整大樹切成很多會各自排序的碎片，除非確實需要角色走到樹前與樹後。
- 如果角色穿過房屋，先檢查 origin、z_index、Y-sort，再檢查縮放。

## 八、目前這張地圖為什麼看起來「破」

根據你提供的主城、船長房間和共享家庭屋畫面，主要不是單一圖片醜，而是以下結構問題：

1. 石板路使用面積過大，重複紋理非常容易被看見。
2. 草地、樹根牆、建築外牆的細節密度不同，視線會被不同材質拉扯。
3. 一些建築像是完整插圖直接貼到地圖上，沒有足夠的地基、門口平台或邊緣過渡。
4. 道路與草地交界缺少 edge／corner tile，形成硬切線。
5. 角色尺寸相對較大，因此地面 tile 的任何重複或接縫都會特別明顯。

所以改善順序應該是：先統一 tile 規格與鄰接，再替換大型建築，最後補花草、燈光和小物；不要先大量增加裝飾來掩蓋底層接縫。

## 九、如果你要用 Pixquare 自製

### 建議畫布

- 單一 tile：32×32。
- 4×4 小組：128×128。
- 8×4 atlas：256×128。
- 角色仍使用 48×64 單格；不要把角色與 tile 畫在同一張 atlas。
- 大型 props 以 32 px 為基準倍數，例如 96×96、128×96、160×128。

### 畫圖順序

1. 先用 2～4 色畫大形。
2. 再加材質方向，例如石板縫、木板紋、草葉群。
3. 最後加 1～2 個高亮色和局部暗部。
4. 每完成一個 tile，就和上下左右同類 tile 拼接測試。
5. 用整數倍放大檢查像素，不要用模糊縮放。

### 自製檢查表

- [ ] 尺寸是 32 的整數倍。
- [ ] 沒有半透明白邊或黑邊。
- [ ] 沒有把文字、角色、陰影畫進地面 tile。
- [ ] 四邊和相鄰 tile 測試過。
- [ ] 同材質至少有 2 款變體，但變體不改變通行性。
- [ ] 亮暗方向和主城其他素材一致。
- [ ] PNG 是 RGBA，Godot Import 使用 Nearest。
- [ ] 物件的原點、碰撞和互動範圍另有記錄。
- [ ] 檔名包含用途和版本，例如 town_path_edge_n_v2.png。

## 十、逐步優化的建議順序

### 第 1 輪：底層地面

草地、道路、樹根牆、水岸、橋面。先讓大面積畫面乾淨、可平鋪、沒有白邊。

### 第 2 輪：主視覺建築

共享家庭屋、早餐攤、船長房間外觀、中央樹心。每次只換一個區域，保留舊檔做比較。

### 第 3 輪：功能性物件

公告欄、燈籠、船港、樓梯、封鎖門、傳送點。

### 第 4 輪：氛圍裝飾

花草、藤蔓、螢火蟲、水面動畫、日夜色調、雲霧和粒子。

這種順序可以讓你每次自製一小批素材就看到成果，也不會因為換一張圖而重做整個遊戲。

