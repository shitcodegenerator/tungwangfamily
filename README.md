# 山海樹港 RPG — Phase 4：CC 與炸物魔王戰鬥切片

Godot 4.7 / GDScript / Compatibility renderer 的 2D 原型。
Phase 1：可以走、可以切換角色、其他人會跟隨、可以在一張連續的巨大樹洞城裡上下探索。
Phase 2：靠近物件按 E 互動、木框羊皮紙對話框、燈籠／水面／旗幟／雲霧動畫與粒子、F5 日夜切換。
Phase 3：集中式 GameState、JSON 存檔（F6／F7）、場景路由（主城 ⇄ 共享家庭屋 ⇄ 船長房間）、
國王企鵝船長與市集老龜 NPC、資料驅動任務與任務日誌（J）、TEMP_DEMO_CONTENT 測試任務。
Phase 4：阿嬤早餐攤與 CC、香椿乾拌麵交付、一次性炸物魔王洞窟、撿取／舉物／投擲、五次命中掉炸雞翅、
受傷變色、戰敗重來、對話選項（接受／拒絕 CC 加入）、CC 非戰鬥寵物跟隨、弟弟操控時較快。

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
| E | 與面前的物件或 NPC 互動；對話中推進（打字中先補完整句）；地上的投擲物 → 撿起；舉著物品 → 投擲 |
| W／S（選項中） | 切換對話選項 |
| J | 開關任務日誌 |
| 1／2／3／4 | 切換哥哥／冷靜哥／妹妹／弟弟（對話、轉場中無效） |
| Tab | 循環切換操控角色 |
| F5 | 日夜切換：白天 → 黃昏 → 夜晚 → 白天 |
| F6／F7 | 存檔／讀檔（`user://save_01.json`） |
| Esc | 開關測試資訊面板 |
| Q（面板開啟時） | 離開遊戲 |
| F1 | 顯示／隱藏碰撞格 |

可互動物件：公告欄（接測試任務）、樹心、三個封鎖出口、市集老龜（廣場木箱旁）、阿嬤與 CC（廣場左側早餐攤）；
走進中層左下樹門房屋＝共享家庭屋，右下陽台房屋＝船長房間（內有國王企鵝船長）。
把阿嬤的香椿乾拌麵交給 CC 會被傳送到炸物魔王洞窟：E 撿青菜／綠茶／水、再按 E 投擲，命中 5 次後回到 CC 身邊。

## 驗證

```bash
# 1. 地圖連通性（Python，僅需 Pillow 以外的標準函式庫）
python3 tools/validate_map.py

# 2. GDScript 純邏輯單元測試（headless）
godot --headless --path . -s res://tests/run_tests.gd

# 3. 自動化驗證：走完驗收路線、切換 20 次、測試封鎖出口與牆壁、互動／對話／輸入鎖／日夜切換，並截八張圖
caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots
```

驗證報告見 `docs/PHASE_1_REPORT.md`～`docs/PHASE_4_REPORT.md`；手動流程見 `docs/MANUAL_TEST_GUIDE.md`。

改過素材（重跑 `tools/build_assets.py`）後必須先 `godot --headless --path . --import`：執行期不會重新匯入 PNG。

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

## 場景、任務與存檔的資料流

```text
assets/maps/scenes.json（scene_id → 地圖／道具／對話檔、outdoor、圖例覆寫）
SceneRouter.load_scene(scene_id) ─► 同一個 TownWorld 場景以不同資料建立 ─► PartyController.place()
道具 JSON 的 portals ─► ScenePortal（領頭者走入）─► SceneRouter.enter_portal（"return" 回到記住的位置）
道具 JSON 的 npcs ─► NpcCharacter（站立、碰撞、轉向）＋ Interactable
對話 JSON 的版本陣列 ─► DialogueResolver 依 GameState／QuestManager 的 requires 挑版本 ─► on_complete 動作
QuestManager（assets/quests/*.json）：目標依序完成；interact 目標由對話結束後的 notify_interact 推進
GameState.to_dict() ─► SaveManager（user://save_01.json，schema_version）─► Main.apply_state() 還原
```

- 對話版本條件：`flags`、`not_flags`、`items`、`quest {id: 狀態}`、`quest_objective {id: 目前目標}`；
  動作：`quest_start`、`set_flag`、`clear_flag`、`unlock_scene`、`quest_objective`、`give_item`、`take_item`、`quest_event`、
  `teleport`（Main 處理，記返回點）、`show_anger`（NPC 頭上 💢）。
- 對話版本可帶 `choice {prompt, options[{text, on_select, lines, on_complete}]}`：最後一句後顯示選項，W／S 選、E 確認。
- 任務目標 `kind`：`interact`（對話結束後推進）、`enter_scene`、`event`（系統事件，例如 Boss 倒下）。
- 所有測試任務與測試對話都以 `TEMP_DEMO_CONTENT` 標記，正式內容由作者提供後直接替換 JSON。
- 家庭記憶物件（家庭屋毛線籃）與船長重要物件（船長房間小箱子）只是插槽，內容留白。

## 撿取、投擲與炸物魔王（Phase 4）

```text
props JSON 的 items ─► TownWorld.spawn_item() ─► CarryableItem（Interactable 子類，物理層 3）
E ─► Main._on_interacted：CarryableItem → CarrySystem.pick_up()（貼圖掛到角色 VisualRoot/CarryAnchor）
舉著物品時 E ─► CarrySystem.throw() ─► ThrownProjectile（只偵測物理層 5 Boss；落點在起飛時截到牆前）
hit_boss ─► BattleDirector：命中特效 → FriedFoodDemon.take_hit() → 炸雞翅 → 物品 2 秒後原位重生
FriedFoodDemon.attack_landed ─► BattleDirector：只有操控角色扣血，PlayableCharacter.flash_hurt() 變色閃爍 + 無敵
battle_won／battle_lost ─► Main：旗標、任務事件、回到 state.return_position（CC 身旁）
```

- 戰鬥設定在 `scenes.json` 該場景的 `battle`（boss、x、y、boss_hp、player_hp）；三種投擲物在 `assets/items/throwables.json`。
- 戰鬥暫態（Boss 生命、玩家生命、手上物品）不進存檔；轉場開始時清空。
- 寵物 `PetFollower` 掛在 `PartyController` 底下、跟在 `order.back()` 後面，不在可切換名單；`GameState.pet_id` 存檔。

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
  dialogue/              對話內容 JSON（主城、共享家庭屋、船長房間）
  quests/                任務定義 JSON
  portraits/             48×48 頭像（四位主角、兩位 NPC）
  characters/npcs/       NPC 精靈表與 CharacterData
  characters/pets/       CC 精靈表與 CharacterData
  characters/boss/       炸物魔王 6 幀精靈表
  items/                 投擲物精靈表（地面／舉起／飛行／命中）與 throwables.json
  effects/               光暈、粒子、傳送／命中／消散／勝利／炸雞翅特效貼圖
  reference/             原始 AI 生成參考圖（不直接用於遊戲）；incoming/ 為 A 級補件
scenes/                  main / world / characters / props / ui（debug_hud、dialogue_box）
scripts/
  main.gd                組合主城、隊伍、鏡頭、互動、對話、日夜、HUD
  world/town_world.gd    由 ASCII 地圖建立 TileMapLayer、碰撞、裝飾、道具、標記、可互動物件
  world/scene_router.gd  場景登錄表、轉場淡入淡出、傳送門處理、讀檔還原
  world/portal.gd        傳送門 Area2D
  world/day_night.gd     CanvasModulate 日夜狀態（F5）
  state/game_state.gd    集中式狀態與序列化
  save/save_manager.gd   JSON 存檔／讀檔
  quest/quest_manager.gd 任務定義、進度、動作
  dialogue/dialogue_resolver.gd 依狀態挑對話版本
  characters/npc_character.gd   站立 NPC
  characters/pet_follower.gd    非戰鬥寵物跟隨與小動作
  battle/carryable_item.gd      地上的投擲物（Interactable 子類）
  battle/carry_system.gd        撿起／舉著／投擲
  battle/thrown_projectile.gd   飛行中的物品、落點計算
  battle/fried_food_demon.gd    炸物魔王狀態機
  battle/battle_director.gd     這一場戰鬥的接線：命中、炸雞翅、生命、勝負
  battle/chicken_wing.gd / effect_sprite.gd 命中回饋與一次性特效
  ui/battle_hud.gd       愛心與 Boss 生命
  ui/quest_hud.gd        目標摘要、任務日誌、提示
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
`build_assets.py` 會先切 Phase 1 素材，再呼叫 `build_assets_phase2.py`（正式角色表、主要道具、動畫幀、補充 tile、UI）
與 `build_assets_phase3.py`（NPC 行走表、頭像、室內家具、室內地板 tile）：

```bash
python3 tools/build_assets.py
godot --headless --path . --import   # 重建後必跑：執行期不會自動重新匯入改過的 PNG
```

角色精靈表為 240×256：第 0 欄站立、第 1～4 欄行走（48×64，列序 down/left/right/up）。

## 地圖編輯

`assets/maps/tide_root_town.txt` 是 30×36 的 ASCII 地圖，每個字元一格：

```text
可走：g 草地  d 泥土  r 樹根路  p 木板  b 樹枝木地板  s 石板  m 苔石  = 橋  | 樓梯  w 沙灘
不可走：# 樹皮牆  . 虛空  c 雲霧  ~ 深水  , 淺水  T 樹心底座
```

道具、出生點、出口與區段定義在 `assets/maps/tide_root_town_props.json`。
室內場景同樣是 ASCII 地圖＋道具 JSON（`family_home.*`、`captain_room.*`），在 `scenes.json` 登錄。
改完後先跑 `python3 tools/validate_map.py` 確認每個場景的入口、傳送門與互動點都可走到。
