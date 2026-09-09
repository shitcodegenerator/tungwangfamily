# Phase 9：潮根城平面化重排規格

狀態：`ready_for_local_implementation`  
規劃基準：`origin/phase-8-art-complete@6d4251176c97d990ddca414751266cb4487ec195`  
遠端交付分支：`codex/phase-9-flat-town`  
內容邊界：`docs/PHASE_3_DECISIONS.md`、D-013、D-014  

## 1. 本 Phase 的結果與邊界

本 Phase 只把 `tide_root_town` 從 30×36 的垂直三層樹城，重排為 30×24 的一般平面城鎮，不新增系統、不改正式劇情、不改任務與對話內容。

- 保留遊戲名「山海樹港」、主城名「潮根城」、樹心地標、西側橋、東側港口、共享家庭屋、船長房間、三位既有 NPC。
- 保留舊中層街道與下層廣場的主要構圖；所有既有可留素材沿用。
- 移除上層樹冠、霧、樹根路線、北側出口、根拱門與全部雲端 props。
- 唯一新增美術為「共享家庭屋一般立面」。四位主角、CC、阿嬤、船長、老龜一律不重生。
- D-010 核心循環繼續延後；本次不得自行補正式回憶、NPC 背景、Boss 或情緒落點。

## 2. 座標與轉換規則

- Tile：32×32；新世界大小 `[30, 24]`，即 960×768 px。
- Tile 座標使用 `[column, row]`，由 0 起算。
- 角色格中心仍為 `(column × 32 + 16, row × 32 + 16)`。
- 舊中層／下層資料的預設平移量為 `Δy = -384`（減去舊上層 12 列）。
- 下表提供的 pixel position 是最終權威值；不要在實作時再次套用 `Δy`。
- 每個 prop 維持現行 `render_mode`；不得加入已退役的 `z_bias`。

## 3. 最終 ASCII 地圖

直接以以下 24 列取代 `assets/maps/tide_root_town.txt`。每列恰好 30 字元，不含空白。

```text
##############################
##gggggggggggggggggggggggggg##
###gggggggggssssssssgggggggg##
##ggggggggggssssssssgggggggg##
=====sssssssssssssssssssssgg##
=====sssssssssssssssssssssgg##
##ggggggggggssssssssgggggggg##
##ggggggggggssssssssggggggg###
###gggggggggssssssssggggggg###
####gggggggggssssssgggggggg###
###ggggggggggssssssgggggggg###
###ggggggggggssssssgggggggg###
###gggggggggssssssssggggggg###
####gggggssssssssssssgg~~~~~##
####gggggsssssssssssssg~~~~~##
##,,gggggsssssssssssss========
##,,,ggggsssssmmmmssss========
##~,,gggggsssmmmmmssssg~~~~~##
##~~,,ggggssssmmmmsssgg,~~~~##
##~~~,,gggggsssssssgggg,,~~~##
##~~~~,,gggggggg,,gggg,,,~~~##
##~~~~~,,ggggggg,,gggg,,,~~~##
##~~~~~~,,,gggggg,,,,,,~~~~~##
##############################
```

### 3.1 使用到的圖例

| 字元 | 用途 | 可走 |
|---|---|---|
| `#` | 城鎮邊界／不可穿越區 | 否 |
| `g` | 草地 | 是 |
| `s` | 石板 | 是 |
| `m` | 廣場中心苔石 | 是 |
| `=` | 東西向木橋 | 是 |
| `~` | 深水 | 否 |
| `,` | 淺水／靜態深水 | 否 |

本圖不使用 `.`, `c`, `T`, `|`；不新增圖例字元。`tile_style` 維持 `town_refresh`。

### 3.2 區段表

區段名稱是功能性標籤，不新增世界觀；之後若改名，只改 `name`，不必重排。

| name | rows | 主要內容 |
|---|---:|---|
| 北側住宅街 | `[0, 9]` | 既有房屋立面、共享家庭屋、船長房入口、樹心、公告欄、西側橋 |
| 中央市集廣場 | `[10, 18]` | 早餐攤、老龜、阿嬤、CC、港口貨物、噴泉、東側港口與出生點 |
| 南側水岸 | `[19, 23]` | 水岸、荷葉池、花圃、南側景觀緩衝 |

## 4. 世界頂層資料

### 4.1 出生點與 entry

`spawn_points` 與 `entries.default` 使用同一組 tile 座標，維持四格菱形隊形且互距至少 2 格：

```json
[
  [14, 17],
  [12, 17],
  [16, 17],
  [14, 19]
]
```

四格依序仍對應目前隊伍順序；不要改角色 ID。四格分別落在 `m / s / m / s`，均可走且不在 prop 碰撞內。

### 4.2 connectors

新地圖沒有樓層切換，最終值為：

```json
"connectors": []
```

刪除舊 `lower_to_middle` 與 `middle_to_upper`；不得以一般道路假裝 connector。

### 4.3 建議 reserved_tiles

這些是入口、互動站位與 route-test 必要動線；加入頂層 `reserved_tiles`，避免後續擺設再次封路：

```json
[
  [4, 9], [25, 9],
  [2, 4], [26, 15],
  [15, 7], [20, 4],
  [19, 15], [21, 15],
  [8, 18], [9, 18], [10, 18], [11, 18]
]
```

其中第 18 列的四格是阿嬤／CC 對話站位；沿用 D-006 的花圃例外，不得用加深花圃碰撞封掉。

## 5. 出口

只保留兩個既有出口 ID 與既有對話 key；`north_canopy` 從 props 資料移除。`assets/dialogue/tide_root_town.json` 本次不改，未被引用的 `north_canopy` 對話可暫留作回退。

| id | tile | interact_center px | interact_size | label_offset | prompt_offset | 其他 |
|---|---:|---:|---:|---:|---:|---|
| `west_bridge` | `[2,4]` | `[34,156]` | `[60,80]` | `[0,-40]` | `[8,-58]` | label、interact key 原樣保留 |
| `east_harbor` | `[26,15]` | `[926,508]` | `[60,80]` | `[-40,-40]` | `[-8,-58]` | label、interact key 原樣保留 |

西橋由第 4～5 列左緣兩格高的 `=` 形成；東港由第 15～16 列右緣兩格高的 `=` 形成。兩者 approach tile 與出生點連通。

## 6. NPC 站位

pixel position 為權威值；「所在格」只供人工檢查。

| id | position px | 所在格 | facing | interact / portrait | requires |
|---|---:|---:|---|---|---|
| `old_turtle` | `[656,480]` | 約 `[20,15]` | `down` | 均維持 `old_turtle` | 無 |
| `grandma_turtle` | `[288,554]` | 約 `[9,17]` | `down` | 均維持 `grandma_turtle` | 無 |
| `cc_penguin` | `[336,554]` | 約 `[10,17]` | `down` | 均維持 `cc_penguin` | `not_flags: ["cc_joined"]` |

阿嬤與 CC 仍在早餐攤旁；CC 仍由對話直接傳送炸物洞窟。NPC data path、對話 JSON、CC 加入條件一律不改。

## 7. 室內傳送門

兩個 portal 只做 `Δy=-384` 平移，ID、size、target、entry 與門下 28px 的回程規則不變。

| id | trigger `[x,y]` | size | target | entry | return_position |
|---|---:|---:|---|---|---:|
| `family_home_door` | `[144,290]` | `[22,6]` | `family_home` | `front_door` | `[144,318]` |
| `captain_room_door` | `[816,290]` | `[22,6]` | `captain_room` | `front_door` | `[816,318]` |

兩個 return tile 分別約為 `[4,9]`、`[25,9]`；必須可走、無碰撞，且 route test 仍用門下往北進門的方式。

## 8. 最終 props 擺位表

下表是最終完整清單。`positions` 有多組座標時，本地實作需展開成多筆 JSON prop；不得在 runtime schema 新增 positions 陣列。`—` 表示欄位省略或 `null`，其餘未列欄位沿用基準值。

| planning id / texture | positions px | render_mode | collision / boxes | foot | 動畫、互動與備註 |
|---|---|---|---|---|---|
| `house_window_lantern` | `[208,128]` | `back` | `[68,64]` | — | 沿用 |
| `house_banner` | `[304,128]` | `back` | `[70,64]` | — | 沿用 |
| `house_narrow` | `[864,128]` | `back` | `[50,64]` | — | 沿用 |
| `town_refresh/shared_family_house_facade_v1` | `[144,288]` | `back` | `[150,64]` | `foot_inset:16` | 本 Phase 唯一新圖；門中心 x=88、接地線 y=80；對準 `family_home_door` |
| `house_tree_window` | `[720,288]` | `back` | `[76,64]` | — | 沿用；這是既有檔名，不代表重新加入樹城結構 |
| `house_balcony` | `[816,288]` | `back` | `[84,64]` | — | 沿用並對準 `captain_room_door` |
| `tree_heart` | `[480,192]` | `back` | `null` | — | `interact:tree_heart`、`interact_size:[128,40]`、`prompt_offset:[0,-64]`；改到北街中央作地標 |
| `bulletin_board` | `[656,96]` | `ysort` | `[46,12]` | — | `interact:bulletin_board`；沿用任務入口 |
| `lamp_post` ×4 | `[368,128]`, `[688,128]`, `[368,224]`, `[656,224]` | `ysort` | `[10,8]` | — | `frames:4`, `fps:5`, `glow:true`, `glow_y:14` |
| `town_refresh/lantern_post_v2` ×4 | `[176,576]`, `[688,672]`, `[400,704]`, `[592,672]` | `ysort` | `[10,8]` | `foot_x:60` | `glow:true`, `glow_x:36`, `glow_y:43` |
| `signpost` | `[80,128]` | `ysort` | `[12,8]` | — | 沿用；舊上層 `[368,96]` 那一筆刪除，不平移 |
| `town_refresh/blank_signpost_v2` | `[736,480]` | `ysort` | `[12,8]` | `foot_x:25` | 沿用 |
| `fence` ×4 | `[32,160]`, `[32,192]`, `[928,512]`, `[928,544]` | `ysort` | `[64,30]` | — | 保護橋邊與港邊；不壓出口 approach |
| `harbor_berth` | `[800,492]` | `ground` | `null` | — | 沿用，禁止加碰撞 |
| `lily_pond` ×3 | `[140,706]`, `[850,704]`, `[544,704]` | `ground` | `null` | — | 沿用，禁止加碰撞 |
| `flag_banner` ×4 | `[336,448]`, `[624,448]`, `[80,96]`, `[880,224]` | `ysort` | `[10,8]` | — | `frames:4`, `fps:4` |
| `town_refresh/breakfast_stall_v2` | `[208,516]` | `ysort` | `[132,132]` | — | 碰撞頂端 384；阿嬤／CC 在南側 |
| `town_refresh/heart_fountain_v2` | `[640,608]` | `ysort` | `[96,96]` | — | 碰撞頂端 512 |
| `town_refresh/harbor_crate_barrel_v2` | `[672,448]` | `ysort` | `[88,96]` | — | 碰撞頂端 352 |
| `town_refresh/flower_herb_bed_v2` | `[272,704]` | `ysort` | `[100,96]` | — | 碰撞頂端 608；第 18 列對話站位保留，沿用 D-006 |

### 8.1 event_id 基準差異

`NOTES_FOR_PLANNER_FLAT_TOWN.md` 提醒保留 `bulletin_board`／`tree_heart` 的 `event_id`；但精確基準 commit `6d42511` 的 `tide_root_town_props.json` 兩者都只有 `interact`，沒有 `event_id` 欄位。本 Phase 不憑空新增事件 ID：

- 以 `interact: bulletin_board`、`interact: tree_heart` 原樣保留。
- 若本地實作分支在合併時已多出合法 `event_id`，只搬位置、不改值。

### 8.2 必須移除的 props

以下不得出現在新的 `tide_root_town_props.json`：

- `canopy_gate`
- `cloud_big`／`cloud_long`／`cloud_small`／`cloud_swirl` 共 7 筆
- `tree_spiral`
- `tree_platform`
- `vine_branch` 共 3 筆
- `town_refresh/root_archway_v3_base`
- `town_refresh/root_archway_v3_canopy`
- 舊上層 `signpost` `[368,96]`
- `town_refresh/shared_family_treehouse_v3`（由一般家庭屋立面取代；舊 PNG 留在 repo 回退，不刪檔）

## 9. 場景登錄調整

本地 AI 更新 `assets/maps/scenes.json` 的 `tide_root_town`：

| 欄位 | 新值 |
|---|---|
| `tile_style` | `town_refresh` |
| `tile_style_rows` | `[0,23]` |
| `dark_wall_last_row` | `-1` |
| `legend_overrides` | `{}` |

其餘 scene ID、map／props／dialogue path、`outdoor:true` 不改。上層 fill／mist 舊 PNG 暫留回退，但新地圖不得引用。

## 10. 唯一新增素材：共享家庭屋一般立面

### 10.1 交付檔

- 遠端來源：`assets/reference/incoming/PHASE9_shared_family_house_facade_v1.png`
- 本地 runtime 目標：`assets/props/town_refresh/shared_family_house_facade_v1.png`
- Manifest：`assets/reference/incoming/PHASE9_FLAT_TOWN_ASSET_MANIFEST.json`

### 10.2 接線規格

| 項目 | 值 |
|---|---|
| Canvas | 176×96 RGBA |
| Alpha | 只含 0、255 |
| opaque bbox | `[2,0,174,96]` |
| door center | `x=88` |
| ground / threshold line | `y=80` |
| bottom area | y=81～95 只有中央門階，無牆體、地板或陰影 |
| render_mode | `back` |
| prop anchor | `[144,288]`，底部中央；預設 `foot_x=88` 可省略 |
| foot_inset | `16` |
| collision | `[150,64]`；頂端 224，對齊 32 格線 |
| portal | 保留 `family_home_door` `[144,290]` |

本地接線時複製 PNG，不縮放、不再量化、不烙陰影；舊 `shared_family_treehouse_v3` 留作回退。

## 11. 本地實作順序

1. 從本交付分支建立本地實作分支，先跑一次 `python3 tools/verify_phase.py --fast` 留基準。
2. 將家庭屋來源 PNG 複製到 runtime 目標，更新 builder／資產驗證規則，但不刪舊圖。
3. 取代 ASCII 地圖，更新 `world_size`、zones、spawn／entry、exits、connectors、portals、NPC 與 props。
4. 更新 `scenes.json` 的列範圍與 `dark_wall_last_row`。
5. 更新所有寫死舊列數、舊出生點、舊 connector、`north_canopy` 的單元與 route 測試；對話 JSON 不改。
6. 跑 fast 驗證與 `validate_map --audit`；不得加入 placement allowlist 來掩蓋新違規。
7. 重拍平面城鎮 golden 圖並跑 full route test；最後才更新現行規格與 D-013／D-014 的 implementation 註記。

## 12. 驗收條件

### 12.1 資料與幾何

- ASCII 為 30×24；每列 30 字元，只有 `# g s m = ~ ,`。
- `.`, `c`, `T` 使用量均為 0；`north_canopy`、舊 connectors 與移除 props 使用量均為 0。
- 所有 6 棟房屋、早餐攤、噴泉、港口箱與花圃的大碰撞頂端都在 32px 格線。
- 四個出生點、兩個 portal return、兩個出口、三位 NPC 與 tree heart／bulletin 的建議站位全部可走且連通。
- `validate_map --audit` 無 MAP-P001～P007 錯誤、無新 allowlist、無不可達小口袋。

### 12.2 視覺

- 地圖從北到南是一張平面城鎮，不再像三張地圖上下堆疊。
- 頂端沒有樹冠破洞、霧 overlay、巨大黑帶或北側雲門。
- 共享家庭屋正門清楚，角色回城落點不被門階、牆面或碰撞吞掉。
- 樹心是可辨識地標，但不遮家庭屋／船長房門與主要道路。
- 西橋、東港、早餐攤、噴泉與南水岸均能在實際鏡頭中完整閱讀，不出現被裁半的建築。

建議 snapshot 中心：`[480,192]` 樹心、`[144,304]` 家庭屋、`[816,304]` 船長房、`[208,544]` 早餐攤、`[640,608]` 廣場、`[864,512]` 東港、`[64,144]` 西橋。

### 12.3 必跑命令

```bash
godot --headless --path . --import
python3 tools/verify_phase.py --fast
python3 tools/validate_map.py --audit
python3 tools/build_assets.py --clean --verify
python3 tools/verify_phase.py --full
```

## 13. 遠端規劃階段自檢結果

以下是用本文件 ASCII 與 props footprint 做的獨立靜態檢查；這不是本地專案驗證器的替代品。

| 檢查 | 結果 |
|---|---|
| 地圖尺寸 | PASS，30×24 |
| 未登錄／禁用字元 | PASS；實際字元 `# , = g m s ~`，無 `. c T` |
| 大碰撞頂端對齊 | PASS，10 個高度 ≥32 的碰撞 |
| 必要節點 | PASS，13 組測試站位全為可走且未被碰撞覆蓋 |
| 連通性 | PASS，355 個扣除碰撞後的可走格同一連通區 |
| 新封閉口袋 | PASS，0 |
| 新 PNG | PASS，176×96 RGBA；alpha 僅 0／255；SHA-256 見 manifest |

## 14. 本 Phase 之後

平面重排與完整 route test 通過後，再回到 D-010 討論第一段正式核心循環。這份規格不預先指定回憶、NPC 原型或正式情緒落點。
