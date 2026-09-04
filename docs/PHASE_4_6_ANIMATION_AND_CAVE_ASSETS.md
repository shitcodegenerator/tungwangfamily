# Phase 4.6：角色動畫、接地感與洞窟正式素材

## 這一階段完成什麼

這是 Phase 4 戰鬥內容之後、每日系統之前的視覺基礎修正。目標不是增加新劇情，而是讓目前的主城與炸物魔王洞窟「走起來像遊戲」：

1. 四位主角改用真正有左右腳交替的 4 幀行走表。
2. 站立時使用獨立 idle 表，角色有很輕微的呼吸／重心擺動。
3. 角色和 CC 寵物腳下加入固定在地面的像素陰影。
4. 洞窟補上可切成 32×32 的正式 tile sheet，取代目前的程式合成外觀。
5. 保留原本角色辨識度、方向列序、碰撞與存檔格式，不改動劇情旗標。

## 為什麼要先做這一階段

目前影片中最明顯的問題是「腳沒有和地面建立關係」以及「走路像整張圖水平滑動」。檢查現有角色表也發現每個方向的第 1、3 幀完全相同；因此這不是單純調播放速度就能修好的問題。動畫表和接地陰影應先穩定，後面的每日循環、更多 NPC、寵物小動作和戰鬥第二種攻擊才不會建立在錯誤的角色基準上。

## 素材規格

### 主角行走表

路徑：`assets/characters/playable/<id>_walk_v2_sheet.png`

| 項目 | 規格 |
|---|---|
| 整張 | 192×256、RGBA、透明背景 |
| 單格 | 48×64 |
| 列序 | 第 0 列 down、 第 1 列 left、 第 2 列 right、 第 3 列 up |
| 欄序 | contact A、passing A、contact B、passing B |
| 腳底 | 每格不透明像素下緣固定在 y=61，底部保留 2px |
| 播放 | 7～8 FPS，依序 0→1→2→3 循環；停止時不要停在 contact A 以外的半步姿勢 |

本批包含：

- `big_brother_walk_v2_sheet.png`
- `calm_brother_walk_v2_sheet.png`
- `sister_sheep_walk_v2_sheet.png`
- `younger_brother_walk_v2_sheet.png`

`younger_brother` 的移動速度規則仍維持現有設計：只要目前操控弟弟，就比其他角色快；跟隨時仍使用隊伍跟隨速度。

### 主角待機表

路徑：`assets/characters/playable/<id>_idle_sheet.png`

同樣是 192×256、4×4 格，列序也相同。四幀是 neutral、微上移、neutral、微下沉，幅度只有 1px。重要的是「角色的碰撞節點、地面錨點和陰影不能跟著上下跳」，只有 `VisualRoot` 內的 Sprite 做微小動畫；否則陰影會跟著飄。

待機建議 2.5～3.5 FPS，整個週期約 1.2 秒。走路時停用 idle，停止輸入約 0.12 秒後再切回 idle，避免一放開方向鍵就突然跳姿勢。

### 腳下陰影

| 檔案 | 尺寸 | 用途 |
|---|---:|---|
| `assets/effects/character_shadow.png` | 32×12 | 四位主角、一般 NPC |
| `assets/effects/pet_shadow.png` | 24×9 | CC |

兩張都是 RGBA 硬邊像素陰影，透明背景。陰影的中心應放在角色的地面錨點 `(0, 0)`，Sprite 的中心點放在陰影中心，不要綁到角色頭部或整張精靈表的幾何中心。陰影應比角色低一層：`z_index = -1` 或放在 `VisualRoot` 前、角色 Sprite 後；同時要被地圖的 Y-sort 規則正確排序。

建議節點結構：

```text
PlayableCharacter
├─ Shadow                 # 固定在地面錨點，不跟著 idle bob
└─ VisualRoot             # 只讓這層換幀／做 1px idle 位移
   ├─ Sprite2D
   └─ CarryAnchor
```

### 洞窟 tile

路徑：`assets/tiles/fried_food_cave_tiles_32.png`

整張 128×64，4 欄×2 列，每格正好 32×32，沒有格線和間隔。列序如下：

| 格位 | 內容 | 建議用法 |
|---|---|---|
| (0,0) | 濕苔地面 A | 可重複鋪設 |
| (1,0) | 濕苔地面 B | 隨機交錯，避免棋盤格 |
| (2,0) | 岩壁面 | 不可走區 |
| (3,0) | 岩壁頂／平台邊 | 可走地面與岩壁交界 |
| (0,1) | 左上角 | 岩壁轉角 |
| (1,1) | 右上角 | 岩壁轉角 |
| (2,1) | 左下／內凹角 | 洞窟邊界 |
| (3,1) | 發光晶簇 overlay | 放在地面上，不要改變碰撞 |

洞窟原始參考也保留在 `assets/reference/incoming/CAVE_fried_food_demon_tiles_reference_v2.png`；它只作色彩與構圖參考，不要直接當成遊戲 tile。

## 本地 AI 接線要求

1. 不要直接把 `*_walk_v2_sheet.png` 當 idle。角色停止時載入對應 `*_idle_sheet.png`，移動時載入 `*_walk_v2_sheet.png`。
2. 先固定地面錨點，再調整 Sprite 的 offset；不可用移動整個 CharacterBody2D 的方式做 idle bob。
3. 角色每一幀都要以同一個 y=61 腳底基準對齊。啟用影子後，影子不能每幀重新依精靈 bbox 置中，否則走路時影子會左右抖動。
4. 隊伍跟隨者使用相同 AnimationPlayer／動畫選擇器，但每個角色共用自己的 walk、idle 表。先修正隊形最小距離，再做播放；不可用加大角色縮放來掩蓋重疊。
5. 洞窟地圖先保留原碰撞資料，只替換 atlas 的視覺來源；Boss 的生成點仍需離地圖上緣至少 2 格，避免頭部被裁切。
6. `💢` 的對話框圖示仍應使用 `assets/ui/anger_mark.png`，不要依賴系統 emoji 字型。
7. 素材變更後必須執行 `godot --headless --path . --import`，避免沿用舊的 `.godot/imported` 快取。

## 驗收條件

- 四位角色四方向行走時，0 與 2、1 與 3 都不是完全相同幀，腳步交替可辨識。
- 往上、往下、左右走時，腳底不跳離地面；影子位置固定，且不會漂到角色身後或頭頂。
- 停止後能看到約 1.2 秒的自然微動；切換方向不會顯示錯列。
- 四名跟隨者與 CC 不會因影子節點而改變碰撞或隊伍間距。
- 洞窟地面不再是單一棕色 debug tile；晶簇可見但不阻擋角色。
- 原有 Phase 1～4 任務、F6/F7、CC 傳送、五次命中與勝負返回流程不回歸。

## 下一階段銜接

這一階段完成並手動確認後，再進入 Phase 5：`day` 欄位與 schema v3、回共享家庭屋休息進入下一天、每日重置，以及以「一天」為單位的 CC 食物互動。Phase 5 的正式劇情事件和 Boss 不會在沒有先得到作者回憶素材的情況下自行定案。
