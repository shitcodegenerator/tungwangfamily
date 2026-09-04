# 山海樹港 RPG：Phase 1 專案規劃

## 1. Phase 1 目標

建立一個可以直接執行的 Godot 4 2D 原型，完成：

1. 建立全新 Godot 專案。
2. 建立 640×360 的邏輯畫面與 32×32 格線。
3. 建立一張可向上延伸的巨大樹洞城主城。
4. 玩家可以在多個畫面高度中自由上下探索。
5. 四位兄弟姐妹同時出現在主城。
6. 可切換目前主要操控角色。
7. 其他三位角色跟隨主要操控角色。
8. 四方向站立、行走與站立微晃動。
9. 先不進入房屋。
10. 預留平原、森林、海底根系、雲端樹冠等未來地圖出口。

Phase 1 不包含戰鬥、升級、寵物、背包、任務、劇情對話與房屋內部。這些功能要等移動、隊伍、地圖與鏡頭穩定後再加入。

## 2. 已確定的技術方向

| 項目 | 決定 |
|---|---|
| 引擎 | Godot 4.x |
| 語言 | GDScript，使用 typed annotations |
| 渲染 | Compatibility renderer |
| 邏輯解析度 | 640×360 |
| 地圖格線 | 32×32 px |
| 角色單格 | 48×64 px |
| 視角 | 2D 偽等角／Y-sort |
| 玩家節點 | CharacterBody2D |
| 互動預留 | Area2D + signals |
| 圖像過濾 | Nearest Neighbor |
| 外掛 | 不使用第三方 addon |
| 目標平台 | Windows、macOS |

本階段先採用一張連續的主城世界座標，不把每個畫面切成獨立關卡。這樣角色、隊伍、鏡頭與未來劇情狀態不需要在畫面切換時重新建立。

## 3. 主城空間設計

主城暫名為「潮根城」，是一棵巨大古樹內部形成的城鎮。Phase 1 只開放中央樹洞城，其他區域先以出口、路牌或封鎖根門表示。

### 建議世界尺寸

```text
世界寬度：約 960 px（30 格）
世界高度：約 1152 px（36 格）
鏡頭可視範圍：640×360 px
```

可分成三個垂直區段，但仍然屬於同一張世界地圖：

| 區段 | 高度 | 內容 |
|---|---:|---|
| 下層樹根廣場 | 12 格 | 出生點、中央廣場、樹根市集、船港入口 |
| 中層樹洞街 | 12 格 | 橋、商店外觀、公告欄、巨大樹心 |
| 上層樹冠平台 | 12 格 | 向上攀爬的樹枝、雲霧、未開放天塔入口 |

「像網頁 scroll 一樣往上走」的實作方式是 Camera2D 跟隨玩家，並以世界邊界限制鏡頭，而不是製作三個互相切換的場景。

### Phase 1 地圖地標

- 四位角色的出生／集合廣場
- 主城中央的巨大樹心
- 向上延伸的樹根階梯與樹枝道路
- 左側橋頭：通往平原與森林，暫時以木柵或看守者封鎖
- 右側船港：通往海底洞窟，暫時沒有船或顯示未開放
- 公告欄：只做場景物件，不啟用任務系統
- 至少三間房屋外觀：只可繞行，不可進入
- 可互動的裝飾物：樹葉、燈、旗幟、水池、木箱

## 4. 建議資料夾結構

```text
res://
├── project.godot
├── README.md
├── AGENTS.md
├── assets/
│   ├── characters/
│   │   ├── playable/
│   │   │   ├── big_brother_sheet.png
│   │   │   ├── calm_brother_sheet.png
│   │   │   ├── sister_sheep_sheet.png
│   │   │   └── younger_brother_sheet.png
│   │   └── npcs/
│   ├── tilesets/
│   │   └── tide_root_town_tileset.png
│   ├── maps/
│   ├── props/
│   └── ui/
├── scenes/
│   ├── main.tscn
│   ├── world/tide_root_town.tscn
│   ├── characters/playable_character.tscn
│   ├── characters/party_member.tscn
│   ├── props/town_prop.tscn
│   └── ui/debug_hud.tscn
├── scripts/
│   ├── main.gd
│   ├── world/town_world.gd
│   ├── characters/player_character.gd
│   ├── characters/party_controller.gd
│   ├── characters/follower_character.gd
│   ├── camera/camera_rig.gd
│   └── ui/debug_hud.gd
└── docs/
    ├── PHASE_1_PROJECT_PLAN.md
    └── LOCAL_AI_PHASE_1_PROMPT.md
```

不要在 Phase 1 建立過度抽象的 ECS、泛用任務框架或大型資料驅動系統。先讓節點、場景、signals 與清楚的腳本責任成立。

## 5. 場景樹設計

```text
Main (Node2D)
├── World (Node2D)
│   └── TideRootTown (Node2D)
│       ├── Ground (TileMapLayer)
│       ├── Decoration (Node2D)
│       ├── Collision (TileMapLayer)
│       ├── Exits (Node2D)
│       └── SpawnPoints (Node2D)
├── PartyController (Node)
│   ├── BigBrother (CharacterBody2D)
│   ├── CalmBrother (CharacterBody2D)
│   ├── Sister (CharacterBody2D)
│   └── YoungerBrother (CharacterBody2D)
├── CameraRig (Camera2D)
└── DebugHUD (CanvasLayer)
```

每個角色使用相同的角色場景與腳本，只透過角色資料設定外觀、速度、碰撞大小與方向。四位角色先不要各自複製一套移動程式。

## 6. 角色與隊伍行為

### 控制方式

| 操作 | 建議按鍵 |
|---|---|
| 移動 | WASD／方向鍵 |
| 切換角色 | 1、2、3、4 |
| 循環切換 | Tab |
| 退出／回到測試選單 | Esc |

切換角色時：

- 不傳送角色。
- 新角色立刻成為可操控者。
- 原本的操控者加入跟隨隊伍。
- 其他三人依目前隊伍順序重新跟隨。
- 角色的方向、動畫與位置保留。

### 跟隨邏輯

Phase 1 不使用複雜導航網格。採用簡單可靠的隊伍軌跡：

1. 主要角色每隔固定距離記錄一次位置與方向。
2. 每位跟隨者追蹤前一位角色的歷史位置。
3. 跟隨距離不足時減速，距離過遠時加速。
4. 遇到碰撞時，使用最後一個有效位置，不穿牆。
5. 跟隨者不可重疊，保留最小間距。

這套方法足以支援主城、切換角色與之後的寵物跟隨。未來地圖複雜到需要導航時，再局部加入 NavigationAgent2D。

### 動畫狀態

最低需求：

- idle_down、idle_left、idle_right、idle_up
- walk_down、walk_left、walk_right、walk_up
- 每個 walk 動畫 4 幀
- idle 使用 2 幀或同一幀做極小幅度晃動

站立微晃動不要讓整個碰撞節點上下移動，只移動視覺子節點 `VisualRoot`。碰撞腳底與角色世界位置要固定。

建議微晃動：

```text
0.00 秒：原位
0.20 秒：VisualRoot 向上 1 px
0.40 秒：原位
0.60 秒：VisualRoot 向下 1 px
```

幅度最多 1 px，週期約 0.8～1.2 秒，並讓四位角色有不同相位，避免像機器同步晃動。

## 7. 美術素材規格

Phase 1 素材已放入專案：

```text
assets/characters/playable/phase1_playable_sprite_reference.png
assets/world/phase1_tide_root_town_reference.png
assets/tilesets/phase1_tide_root_tileset_reference.png
```

角色圖與 Tileset 圖目前是「可直接交給本地 AI 讀取的視覺參考素材」。由於生成圖片不一定天然符合每一格的像素邊界，本地 AI 仍需要在 Godot 或像素繪圖工具中整理切格、過濾方式與碰撞區域。

### 角色

每位角色第一版素材：

```text
Sprite Sheet：192×256 px
單格：48×64 px
4 方向 × 4 幀
透明背景
Nearest Neighbor
```

角色本身採用簡化大色塊，不追求生成圖的所有毛髮與衣服細節。每個角色至少保留一個可從剪影辨識的特徵。

### 主城

建議建立一張可重複拼接的 32×32 tileset，至少包含：

- 木質地板、樹皮牆、樹根道路
- 草地、泥土、石板路
- 水面與岸邊
- 樓梯、橋、斜坡視覺片段
- 樹葉、藤蔓、蘑菇、燈、木箱
- 房屋外牆、窗戶、門，但門先設定為不可進入
- 左側橋頭、右側船港、上方雲霧樹枝

地圖繪製時，先完成可行走底層與碰撞，再放裝飾。裝飾不能阻塞主要道路，也不能靠圖片透明區域猜碰撞。

## 8. Phase 1 驗收條件

### 專案

- [ ] Godot 專案可以正常開啟。
- [ ] `project.godot` 設定 640×360。
- [ ] Windows 與 macOS 都不依賴第三方 addon。
- [ ] 執行時沒有 parser error 或紅色 runtime error。

### 地圖

- [ ] 主城不是單一畫面。
- [ ] 玩家可由下層走到中層，再走到上層。
- [ ] Camera2D 能平滑跟隨且不超出世界邊界。
- [ ] 左、右、上方出口都有明確視覺提示。
- [ ] 房屋目前不能進入。

### 角色

- [ ] 四位角色同時出現在主城。
- [ ] 可以用 1～4 切換操控角色。
- [ ] 可以用 Tab 循環切換。
- [ ] 其他角色會跟隨。
- [ ] 跟隨者不會穿過牆壁或掉出地圖。
- [ ] 四方向行走正確。
- [ ] 站立時有微小晃動。
- [ ] 角色腳底固定，不會上下漂移。

### 測試

- [ ] 從出生點走到地圖最高處，再走回出生點。
- [ ] 連續切換角色 20 次，隊伍不崩潰。
- [ ] 讓隊伍靠近牆角、橋、房屋與地圖邊界測試。
- [ ] 快速左右移動與反方向移動時，跟隨者不會永久卡住。
- [ ] 截圖記錄初始畫面、地圖中段與地圖上層。

## 9. 後續 Phase 順序

### Phase 2：互動與城鎮生命

- Area2D 互動
- 標示牌、公告欄、樹、箱子與水池互動
- 對話框基礎
- 場景裝飾動畫
- 簡單時間或天氣狀態

### Phase 3：寵物與收集

- 寵物出現
- 送禮與親密度
- 寵物跟隨或停留
- 寵物回禮
- 小型收藏圖鑑

### Phase 4：簡單即時戰鬥

- 小怪
- 普通攻擊
- 技能
- HP、治療、受傷與死亡
- 裝備與升級的最小版本

### Phase 5：第一章劇情

- 童年日常事件
- 父親原型 NPC 的主城任務
- 海上釣魚線索
- 事件後遺留痕跡
- 第一章結尾：未知智慧留下召喚痕跡，但不直接描寫被帶走的瞬間

## 10. 開發原則

- 先完成可以走、可以切換、可以跟隨、可以探索的核心循環。
- 所有角色都共用角色場景與動畫介面。
- 所有地圖出口先以資料標記，未開放內容不寫死在角色腳本裡。
- 不要把劇情、戰鬥與移動耦合在同一支腳本。
- 每完成一個小功能，就用 headless import 與實機執行測試。
- 美術不完整時可以用同尺寸 placeholder，但不能改變節點、碰撞與動畫介面。
