# 山海樹港 RPG — Phase 2：潮根城主城（互動與城鎮生命）

Godot 4.7 / GDScript / Compatibility renderer 的 2D 原型。
Phase 1：可以走、可以切換角色、其他人會跟隨、可以在一張連續的巨大樹洞城裡上下探索。
Phase 2：靠近物件按 E 互動、木框羊皮紙對話框、燈籠／水面／旗幟／雲霧動畫與粒子、F5 日夜切換。

## 執行

```bash
# 開啟編輯器
godot --path . --editor

# 直接執行遊戲
godot --path .
```

需要 Godot 4.7 以上（不使用任何第三方 addon）。

## 操作

| 按鍵 | 動作 |
|---|---|
| WASD／方向鍵 | 移動 |
| E | 與面前的物件互動；對話中推進（打字中先補完整句） |
| 1／2／3／4 | 切換哥哥／冷靜哥／妹妹／弟弟（對話中無效） |
| Tab | 循環切換操控角色 |
| F5 | 日夜切換：白天 → 黃昏 → 夜晚 → 白天 |
| Esc | 開關測試資訊面板 |
| Q（面板開啟時） | 離開遊戲 |
| F1 | 顯示／隱藏碰撞格 |

可互動物件：公告欄、樹心、左側橋頭、右側船港、上方樹冠門（後三者顯示「尚未開放」）。

## 驗證

```bash
# 1. 地圖連通性（Python，僅需 Pillow 以外的標準函式庫）
python3 tools/validate_map.py

# 2. GDScript 純邏輯單元測試（headless）
godot --headless --path . -s res://tests/run_tests.gd

# 3. 自動化驗證：走完驗收路線、切換 20 次、測試封鎖出口與牆壁、互動／對話／輸入鎖／日夜切換，並截八張圖
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

驗證報告見 `docs/PHASE_1_REPORT.md`、`docs/PHASE_2_REPORT.md`。

## 匯出

`export_presets.cfg` 已定義 macOS（universal）與 Windows Desktop（x86_64）兩個 preset。
安裝對應版本的 export templates 後：

```bash
godot --headless --path . --export-release "macOS" build/macos/tungworld.zip
godot --headless --path . --export-release "Windows Desktop" build/windows/tungworld.exe
```

## 互動與對話的資料流

```text
JSON（props/exits 的 interact 欄位）─► TownWorld 建立 Interactable（Area2D，物理層 3）
角色 InteractionArea（面前 20×20）──► InteractionController 每個 physics frame 挑最近目標、顯示「E」提示
按 E ─► Interactable.interact() ─► signal interacted ─► DialogueManager.start_from()
DialogueManager.dialogue_started / dialogue_finished ─► Main ─► PartyController.set_input_locked()
```

- 對話內容在 `assets/dialogue/tide_root_town.json`（id → speaker + lines），不寫在任何腳本裡。
- 對話框 `scenes/ui/dialogue_box.tscn`：NinePatch 木框、NameLabel、DialogueLabel（逐字、自動換行）、
  Portrait（預留、預設隱藏）、ContinueHint。`DialogueBox.set_portrait()` 為未來頭像接口。
- 對話中領頭者不讀移動輸入、不能切換角色；隊伍、鏡頭、位置都不變。

## 城鎮生命與日夜

- 道具 JSON 可加 `frames`/`fps`（橫向多幀循環：燈籠、旗幟）、`drift: [振幅, 週期]`（雲霧水平飄移）、
  `glow: true`（燈籠光暈，黃昏 0.7、夜晚 1.0）。這些只動 Sprite2D 子節點，不動碰撞與 Y-sort 基準。
- 水面是 TileSet 內建動畫（tileset 第 3 列，4 幀 × 0.28 秒），不需腳本。
- 粒子（`scripts/world/ambient_effects.gd`）：落葉全天、蝴蝶白天、螢火蟲黃昏與夜晚。
- 日夜 `scripts/world/day_night.gd` 是一個 CanvasModulate，只改色調與燈籠光暈，不重建地圖、不改碰撞。

## 專案結構

```text
assets/
  characters/playable/   四位角色 192×256 精靈表（48×64 × 4 方向 × 4 幀）與 CharacterData .tres
  tilesets/              32×32 主城 tileset（由參考圖切割）
  maps/                  ASCII 地圖 + 道具／出生點／出口 JSON
  props/                 房屋、燈、木箱、路牌、柵欄、雲、樹心等道具
  ui/                    Fusion Pixel 12px 字型（OFL）、Theme、對話框九宮格、互動提示圖示
  dialogue/              對話內容 JSON
  effects/               光暈與粒子貼圖
  reference/             原始 AI 生成參考圖（不直接用於遊戲）；incoming/ 為 A 級補件
scenes/                  main / world / characters / props / ui（debug_hud、dialogue_box）
scripts/
  main.gd                組合主城、隊伍、鏡頭、互動、對話、日夜、HUD
  world/town_world.gd    由 ASCII 地圖建立 TileMapLayer、碰撞、裝飾、道具、標記、可互動物件
  world/day_night.gd     CanvasModulate 日夜狀態（F5）
  world/ambient_effects.gd 落葉／蝴蝶／螢火蟲粒子
  interaction/interactable.gd           可互動 Area2D（物理層 3）＋ interacted signal
  interaction/interaction_controller.gd 最近目標選擇、提示圖示、E 鍵分派
  ui/dialogue_box.gd / ui/dialogue_manager.gd 對話框元件與單線對話流程
  world/map_parser.gd    ASCII 地圖解析與 BFS 路徑
  world/tile_library.gd  圖例 → atlas 座標、TileSet 建立
  characters/player_character.gd   單一角色：輸入、移動、方向、動畫、微晃動
  characters/follower_character.gd 跟隨前一位隊員的軌跡
  characters/party_controller.gd   角色切換、隊伍順序
  characters/party_trail.gd        軌跡資料結構
  camera/camera_rig.gd   Camera2D 跟隨與世界邊界
  ui/debug_hud.gd        除錯 HUD
  debug/route_test.gd    自動化通行驗證
tests/run_tests.gd       單元測試
tools/build_assets.py    由參考圖重建所有遊戲素材（需 Pillow）
tools/validate_map.py    地圖驗證
docs/                    規劃、提示詞、驗證報告、截圖
```

## 重建素材

Phase 1 參考圖在 `assets/reference/`，Phase 2 A 級補件在 `assets/reference/incoming/`。
`build_assets.py` 會先切 Phase 1 素材，再呼叫 `build_assets_phase2.py` 以正式素材覆蓋角色精靈表與主要道具、
產生燈籠／旗幟／水面動畫幀、補充 tile 與 UI 貼圖：

```bash
python3 tools/build_assets.py
```

角色精靈表為 240×256：第 0 欄站立、第 1～4 欄行走（48×64，列序 down/left/right/up）。

## 地圖編輯

`assets/maps/tide_root_town.txt` 是 30×36 的 ASCII 地圖，每個字元一格：

```text
可走：g 草地  d 泥土  r 樹根路  p 木板  b 樹枝木地板  s 石板  m 苔石  = 橋  | 樓梯  w 沙灘
不可走：# 樹皮牆  . 虛空  c 雲霧  ~ 深水  , 淺水  T 樹心底座
```

道具、出生點、出口與區段定義在 `assets/maps/tide_root_town_props.json`。
改完後先跑 `python3 tools/validate_map.py` 確認主要路線仍可走通。
