# 場景與 TileMap 美術修改手把手教學

這份文件針對目前 `tungwangfamily` 的資料驅動地圖架構。建議先在分支上做修改，再讓本地 AI 跑驗證；不要直接把整張 `.tscn` 或整張背景圖覆蓋掉。

## 1. 先理解目前地圖由什麼組成

目前一個場景通常由四層組成：

| 層 | 檔案 | 負責內容 |
| --- | --- | --- |
| 可走／不可走格 | `assets/maps/<scene>.txt` | 32×32 邏輯格、牆、路、水、入口與連接位置 |
| Tile 外觀規則 | `scripts/world/tile_library.gd` 與對應 tile 資料 | 把字元轉成 Tile／地面外觀 |
| 大型物件 | `assets/maps/<scene>_props.json` | 房屋、樹屋、拱門、燈籠、桌子、碰撞、互動、Shader |
| 物件貼圖 | `assets/props/*.png` | 真正顯示的 PNG；通常以底部中央為接地原點 |

角色、NPC、日誌和世界事件各自有自己的資料與腳本。改地圖物件時，先改 props JSON；只有真的新增一種地形規則才改 Tile 資料。

## 2. 動手前先建立基準截圖

在專案根目錄執行：

```bash
python3 tools/validate_map.py
caffeinate -dis godot --path . --always-on-top -- "--snapshot=tide_root_town:14,29:$PWD/before_town.png;captain_room:9,8:$PWD/before_captain.png"
```

Windows 沒有 `caffeinate` 時，直接執行：

```powershell
godot --path . -- "--snapshot=tide_root_town:14,29:$PWD/before_town.png;captain_room:9,8:$PWD/before_captain.png"
```

先確認你要改的物件真的出現在截圖裡。若截圖看不到，不要猜座標；先調整 snapshot 起點或用遊戲內座標 HUD 找到物件。

## 3. 只換一個既有物件的 PNG

例如要替換船長房間的繩圈：

1. 保留檔名 `assets/props/cap_rope_coil.png`。
2. 圖片必須是 RGBA PNG，尺寸仍為 55×40。
3. 背景必須是透明，不要把木地板、黑色方塊或陰影烘進去。
4. `assets/maps/captain_room_props.json` 不要改掉：
   - `texture: "cap_rope_coil"`
   - `event_id: "captain_mystery_item"`
   - 原本的 `[176,176]` 位置
5. 讓 Godot 重新匯入，再看事件前、移動中、完成後三張圖。

如果你真的要改尺寸，不要只把 PNG 拉大。先確認 `TownProp` 的接地點、`foot_x`、`foot_inset` 和事件位移是否仍然合理，並把新尺寸寫進 manifest。

## 4. 在主城增加一個裝飾物

以 `assets/props/` 下已有 PNG 為例，打開 `assets/maps/tide_root_town_props.json`，在 `props` 陣列最後加一筆：

```json
{
  "texture": "lily_pond",
  "x": 544,
  "y": 1088,
  "collision": null,
  "z_bias": -1
}
```

欄位意義：

- `texture`：對應 `assets/props/<texture>.png`；`town_refresh/foo` 對應子目錄。
- `x`、`y`：物件的世界座標，通常是接地原點，不是圖片左上角。
- `collision`：`[寬, 高]` 的碰撞矩形；純裝飾用 `null`。
- `z_bias`：相對 Y-sort 的視覺偏移。遠景雲、樹冠常用 `-1`；不要用它掩蓋錯誤碰撞。
- `foot_x`：圖片左邊到接地點的水平距離；大型非對稱物件才需要。
- `foot_inset`：圖片底緣與接地線的差距；先小幅調整它，不要任意改角色錨點。
- `collision_boxes`：拱門等非矩形碰撞用多個 `[寬, 高, dx, dy]`；改之前要先取得作者同意，Phase 7 不改既有值。

新增後執行：

```bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
```

然後在遊戲內從不同方向走過它。裝飾物如果看起來漂亮但角色可以穿過，可能是預期的；如果它是牆、桌子、樹根或柵欄，才需要明確的 collision。

## 5. 移動大型建築的「畫面」而不破壞地圖

樹屋和根拱門是最容易出現「看起來擋路，但實際碰撞不在那裡」的物件。請依序嘗試：

1. `foot_x`：修正圖片底部接地點的左右偏移。
2. `foot_inset`：修正圖片底緣相對接地線的上下偏移。
3. `z_bias`：修正前景／背景顯示順序。
4. 最後才調 `x`／`y`；調整後要重新看碰撞是否仍與畫面吻合。

不要直接修改 `.txt` 來「躲開」貼圖，也不要改角色縮放來配合一張過大的建築圖。地圖邏輯和美術顯示要分開，這樣未來替換高清一點的 prop 時不會整張地圖壞掉。

## 6. 替換或自製 TileMap 素材的規範

目前世界格是 32×32，因此新 tile 應遵守：

- 每一格恰好 32×32 px；tileset 可以是 32 的整數倍排列。
- 四邊需要無縫的 tile 必須在上下左右都能平鋪；不要只在右下角畫暗邊。
- 草地、水岸、石路、木道等過渡要分開做直邊、內角、外角與必要的中心填充。
- 使用 Nearest；不要抗鋸齒、半透明模糊或非整數縮放。
- 透明 PNG 要有真正 alpha；參考圖可以有背景，遊戲素材不可把背景烘進去。
- 色彩維持 `docs/ART_STYLE_LOCK.md`：深藍紫輪廓 `#111525`，限制色數，避免每張圖使用完全不同的黑色與高光。
- tileset 只負責地面／牆面規則；門、樹屋、船、招牌、燈籠等大型物件放在 props，不要把一棟建築塞進一格 tile。

若是 4×4 tile sheet，格子之間是否留間隔必須以現有切割器規則為準；不要自行混用 8 px 間隔與無間隔版本。交付前先看 `docs/ASSET_REQUEST.md` 或 `tools/build_assets*.py` 的實際規格。

## 7. 加入 Shader 特效的安全方式

Shader 只套在視覺 Sprite，不套在碰撞、互動區或角色陰影。適合的例子：

- 舷窗水光：低強度、只改顏色或亮度。
- 水面微光：不改碰撞，也不移動玩家。
- 雲霧飄動：只改 Sprite 顯示位置或透明度，不能把邏輯節點搬走。

在 props JSON 中使用：

```json
{
  "texture": "cap_porthole",
  "shader": "captain_room_waterlight",
  "event_id": "captain_room_waterlight"
}
```

Shader 找不到時，道具應該仍能正常顯示。不要把 Shader 當成事件邏輯；事件仍應透過 `assets/events/*.json` 與 `WorldEventRunner`。

## 8. 角色一致性檢查

自製角色或改動既有角色時，先確認：

- 四方向行走表順序仍是 down／left／right／up。
- 每格仍是 48×64；整張四幀行走表是 192×256。
- 腳底落在同一條底部接地線，角色寬度不要因方向大幅變化。
- 閒置幀只做很小的自然晃動，不改身高、武器比例或陰影位置。
- 舉物／投擲圖也要沿用同一角色頭身比例、輪廓色盤與腳底陰影；不要用另一種角色模板重新生成。
- 角色陰影是獨立的第一個子節點，貼地且不隨 Sprite frame 變形。

## 9. 完成後的檢查清單

```bash
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

至少檢查：

- 從四個方向走過新物件。
- 四位角色輪流主控，確認腳底與陰影一致。
- 路線沒有被意外封死，入口／出口仍可用。
- 重新進出場景後物件仍在正確位置。
- 重新啟動後讀檔沒有崩潰。
- 日誌內容超出高度時可以滑動，且不會把遊戲角色移動一起觸發。

如果只想試做一張圖，先只改一個檔案、截圖、驗證，再繼續下一張。這樣出現問題時可以精確回滾，不會讓整個主城變成難以追查的素材拼貼。
