# Phase 4 完成回報（2026-09-04）

環境：macOS（Apple M1 Pro）、Godot 4.7.2 stable、Python 3.9 + Pillow 11.3。
規劃來源：`docs/PHASE_4_PLAN.md`、`docs/LOCAL_AI_PHASE_4_PROMPT.md`、`docs/PHASE_4_ASSET_README.md`、
`assets/reference/incoming/PHASE4_ASSET_MANIFEST.json`（分支 `codex/phase-4-cc-fried-food-battle`，已 fast-forward 合併進 master）。

## 1. 實際完成

### 4A 任務、交付與傳送

| 項目 | 狀態 | 實作 |
|---|---|---|
| CC 位置與互動 | 完成 | 下層廣場左側阿嬤早餐攤旁（`tide_root_town_props.json` 的 `npcs`：`grandma_turtle`、`cc_penguin`，新增道具 `breakfast_stall`）。CC 的 NPC 項目帶 `requires: {not_flags: [cc_joined]}`，加入後不再出現 |
| 香椿乾拌麵取得／交付 | 完成 | `GameState.inventory`；對話動作 `give_item`／`take_item`；對話條件新增 `items`。阿嬤只在目標為「取麵」時給麵，CC 只在背包有麵時收麵 |
| 洞窟場景與傳送 | 完成 | `scenes.json` 新增 `fried_food_cave`（24×16、tileset 第 5 列洞窟 tile、`battle` 設定）。對話動作 `teleport` 由 `Main.teleport_to()` 處理：返回點記為領頭者當下位置（CC 身旁），播傳送特效後 0.55 秒轉場；CC 不進洞窟 |
| 失敗／完成返回 CC | 完成 | `BattleDirector.battle_lost`／`battle_won` → `Main._return_to_cc()` 以 `state.return_position` 為落點 |
| 狀態可存檔 | 完成 | `schema_version` 升為 2：新增 `inventory`、`pet_id`；讀到 v1 存檔自動補空值 |

### 4B 撿取、舉物與投擲

| 項目 | 狀態 | 實作 |
|---|---|---|
| CarryableItem | 完成 | `scripts/battle/carryable_item.gd` 繼承 `Interactable`（物理層 3），地上的物品就是可互動物件，沿用既有 E 流程，沒有第二套輸入 |
| 只有操控角色可撿 | 完成 | `CarrySystem.pick_up()` 只對 `party.get_leader()` 生效；跟隨者不撿、不丟 |
| CarryAnchor | 完成 | `playable_character.tscn` 新增 `VisualRoot/CarryAnchor`（0, −60）；物品貼圖掛在此節點，不畫進角色 Sprite |
| 投擲 | 完成 | 舉著物品時 E → `CarrySystem.throw()` → `ThrownProjectile`（Area2D，只偵測物理層 5 Boss）沿面向飛 150px、視覺拋物線；起飛時以 `landing_point()` 把射程截到牆前，不會飛進牆。命中發 `hit_boss`，落地發 `landed`（物品掉在落點可再撿） |
| 四位角色共用 | 完成 | 四位都有 `carry_*`／`throw_*` 幀（行動表 96×256）；妹妹的參考檔原本損毀，後由作者從 Downloads 提供原圖補上。沒有行動表的角色會退回站立幀 + CarryAnchor |

### 4C 炸物魔王

| 項目 | 狀態 | 實作 |
|---|---|---|
| BattleDirector | 完成 | `scripts/battle/battle_director.gd`：只服務這一場；生成 Boss、接命中、掉炸雞翅、扣玩家生命、判勝負、物品重生 |
| Boss 狀態機 | 完成 | `scripts/battle/fried_food_demon.gd`：待機 0.8s → 移動 1.4s（42px/s 朝領頭者）→ 預兆 0.75s（舉翅幀、紅色脈動、抖動）→ 衝撞 0.4s（240px/s）→ 待機；受擊插入 0.35s 閃白抖動；生命 0 → 倒地 |
| HP 5、每次命中扣 1 | 完成 | `throwables.json` 三種物品皆 `plain_damage`、傷害 1（保留 `effect_type` 欄位） |
| 命中回饋 | 完成 | 依序：命中特效（物品第 4 幀 + 火花）→ Boss 閃白抖動 → 炸雞翅彈出、彈跳一次、靜止 0.25s 後縮小淡出 → 生命 −1；炸雞翅不可撿、不進背包 |
| 玩家受傷 | 完成 | 只有操控角色會被打中；`PlayableCharacter.flash_hurt()` 以 `modulate` 紅色閃爍 1 秒並無敵；生命 3 |
| 戰敗重來 | 完成 | 生命 0 → 0.9s 後返回 CC；`cc_cave_active` 清除、`cc_noodle_delivered` 保留；再談 CC 即重新傳送，Boss 與生命重置 |
| 勝利時機 | 完成 | 第 5 次命中 → 倒地幀 → 1.4s 後消散與勝利特效 → 才設定 `cc_fried_food_demon_defeated` 與任務事件 |

### 4D CC 加入與寵物

| 項目 | 狀態 | 實作 |
|---|---|---|
| 加入對話與選項 | 完成 | 對話 JSON 新增 `choice {prompt, options[{text, on_select, lines, on_complete}]}`；`DialogueManager` 在最後一句後顯示選項，上下鍵選、E 確認；`DialogueBox` 新增 `%Choices` |
| 拒絕分支 | 完成 | `on_select` 立即套用 `show_anger`（CC 頭上的 💢 貼圖 `assets/ui/anger_mark.png`）與 `cc_rejection_reaction_seen`；接續台詞「……💢」「（OS：你怎麼忍心!!!）」「……勝手についていく、です。」 |
| 兩種選擇都加入 | 完成 | 兩個選項的 `on_complete` 皆 `set_flag cc_joined` + `quest_event cc_joined`；接受另設 `cc_join_choice` |
| 寵物跟隨 | 完成 | `scripts/characters/pet_follower.gd` + `pet_follower.tscn`：掛在 `PartyController` 底下（換場景不遺失），沿用 `FollowerCharacter` 跟在 `order.back()` 後面；不在 `members`／`order` 裡，1～4／Tab 切不到；站著時每 3～6.5 秒跳一下並轉頭 |
| 存讀檔 | 完成 | `pet_id` 存檔；`Main._sync_pet()` 依 `cc_joined`／`pet_id` 生成或移除寵物、移除早餐攤旁的 CC NPC |
| 弟弟速度 | 完成 | `CharacterData.controlled_speed`（弟弟 124，其餘 0 = 沿用 96）；只在被操控時生效，跟隨時仍用 walk_speed |

### 素材整理

| 來源 | 產出 | 處理 |
|---|---|---|
| CC 5×4 參考 | `assets/characters/pets/cc_penguin_sheet.png` 240×256 | 主角切割器，高度縮到 40px（寵物尺寸） |
| Boss 3×2 參考（棋盤格烙在像素裡） | `assets/characters/boss/fried_food_demon_sheet.png` 480×80（6 幀） | 從四邊泛洪去除連到邊緣的近白中性灰，雞身內的白色骨頭保留 |
| 投擲物 4×3 | `assets/items/{vegetable_bundle,green_tea,water_flask}.png` 112×28（地面／舉起／飛行／命中） | 依格切割 |
| 特效 3×2 | `assets/effects/fx_teleport／fx_hit_sparkle／fx_poof／fx_victory／fx_chicken_wing.png` | 依格切割；炸雞翅取掉落格中最大的單一元件；投擲軌跡改由程式旋轉與拋物線呈現 |
| 行動表（四位） | `assets/characters/playable/<id>_action_sheet.png` 96×256 | 4×4 參考取第 0 欄（舉物）與第 2 欄（投擲）；列序 down/right/left/up 轉成專案的 down/left/right/up；縮放以既有站立幀寬度對齊，避免撿起時身形跳動 |
| 阿嬤參考（原圖由作者補上） | `assets/characters/npcs/grandma_turtle_sheet.png` 240×256 | 參考圖四列相同、每列是五種視角（正面、側面、側面提籃、背面、正面微笑），不是行走表；重組為 down／left（鏡射側面）／right／up 四方向站立幀後交給主角切割器 |
| **洞窟參考** | — | **分支上的檔案不是 PNG（開頭為亂碼），作者的 Downloads 也沒有這張**。依規劃用 32×32 tile 合成重建（tileset 第 5 列：地面、岩壁、油漬地面、受光牆面） |
| 早餐攤、香椿乾拌麵圖示、💢、愛心 | `assets/props/breakfast_stall.png`、`assets/ui/*.png` | 程式繪製 |

## 2. 新增與修改的檔案

```text
新增
scripts/battle/carryable_item.gd、thrown_projectile.gd、carry_system.gd、fried_food_demon.gd、battle_director.gd、chicken_wing.gd、effect_sprite.gd
scripts/characters/pet_follower.gd + scenes/characters/pet_follower.tscn
scenes/characters/fried_food_demon.tscn、scenes/ui/battle_hud.tscn + scripts/ui/battle_hud.gd
assets/maps/fried_food_cave.txt、fried_food_cave_props.json、assets/dialogue/fried_food_cave.json
assets/items/throwables.json + 三張物品精靈表
assets/quests/phase4_cc_quest.json
assets/characters/pets/cc_penguin.tres + 精靈表、assets/characters/boss/、assets/characters/npcs/grandma_turtle.tres + 精靈表
assets/characters/playable/*_action_sheet.png（4 張）、assets/effects/fx_*.png（5 張）、assets/ui/anger_mark／heart_full／heart_empty／item_noodles.png、assets/props/breakfast_stall.png
tools/build_assets_phase4.py
docs/PHASE_4_REPORT.md、docs/screenshots/12～18

修改
project.godot                       物理層 5 = Boss；描述
scripts/state/game_state.gd         schema_version 2、inventory、pet_id、v1 遷移
scripts/characters/character_data.gd  controlled_speed、action_sheet
scripts/characters/player_character.gd carry／throw 幀、CarryAnchor、controlled_speed()、flash_hurt()／is_invincible()
scripts/characters/party_controller.gd  pet、set_pet()、跟隨鏈含寵物、teleport_to 含寵物
scripts/characters/follower_character.gd body 型別放寬為 Node2D（寵物共用）
scripts/interaction/interaction_controller.gd 舉物時 E 投擲、提示隱藏
scripts/ui/dialogue_manager.gd／dialogue_box.gd／dialogue_box.tscn 選項流程與顯示
scripts/dialogue/dialogue_resolver.gd requires.items、choice
scripts/quest/quest_manager.gd      多任務檔、kind=event、notify_event、give_item／take_item／quest_event
scripts/world/town_world.gd         state、NPC requires、items、spawn_item、remove_npc、interactable_added
scripts/world/scene_router.gd       把 state 交給世界、battle_config()
scripts/world/tile_library.gd       ATLAS_ROWS 6、洞窟常數、"#_face" 覆寫
scripts/main.gd                     撿取／投擲／戰鬥／傳送／CC 加入／寵物接線
scenes/main.tscn                    CarrySystem、BattleDirector、BattleHud
scenes/world/tide_root_town.tscn    Interactables 開 Y-sort（物品貼圖）
scenes/characters/playable_character.tscn CarryAnchor
assets/maps/scenes.json、tide_root_town_props.json、assets/dialogue/tide_root_town.json、四張角色 .tres、tileset
tools/build_assets.py／build_assets_phase2.py（build_character 加 max_height）、tools/validate_map.py
tests/run_tests.gd（+58 項，共 154）、scripts/debug/route_test.gd（+89 項，共 195）
docs/MANUAL_TEST_GUIDE.md、README.md、AGENTS.md、docs/ASSET_REQUEST.md
```

## 3. 測試指令與結果

| 指令 | 結果 |
|---|---|
| `python3 tools/build_assets.py` | 四階段素材全部重建，無錯誤 |
| `godot --headless --path . --import` | 匯入完成，無 parser error |
| `godot --headless --path . --quit-after 150` | 主場景執行無 runtime error |
| `python3 tools/validate_map.py` | 四個場景通過：洞窟三件物品與 Boss 周圍皆可達、Phase 3＋4 任務目標皆對應互動 id |
| `godot --headless --path . -s res://tests/run_tests.gd` | 154 通過，0 失敗 |
| `caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots` | 結果：PASS（195 通過，0 失敗）、切換 29 次、跟隨者違規 0 筆 |

### 必測項目對照

| 必測 | route test 檢查 | 結果 |
|---|---|---|
| Phase 3 原有自動測試全部通過 | Phase 1～3 的 106 項保留 | 通過 |
| 麵未取得時不能傳送 | 「香椿乾拌麵未取得時 CC 不傳送」 | 通過 |
| 交付後可傳送 | 「交付後 CC 傳送」「四人抵達炸物魔王洞窟」「返回點記在 CC 身旁」 | 通過 |
| 三種物品能撿、舉、投 | 青菜、綠茶、水各至少一次（提示出現 → 撿起 → 舉著走 → 投擲） | 通過 |
| 四位角色都能投擲 | 哥哥、冷靜哥、妹妹、弟弟各投擲一次並命中 | 通過 |
| 命中 5 次才勝利、4 次不能提前結束 | 「命中 4 次：Boss 生命 1」「命中 4 次不會提前勝利」「第 5 次命中，Boss 生命歸零」 | 通過 |
| 每次命中只生成一隻炸雞翅且消失 | `wings_spawned == hits`（4 → 5）；炸雞翅為純視覺節點，不是 Interactable | 通過 |
| 受傷變色、不需受傷 Sprite | 「Boss 攻擊命中，領頭者變色閃爍並進入無敵時間」「生命 3 → 2」 | 通過 |
| 戰敗回到 CC 並重新開始 | 「戰敗回到 CC 身旁」「CC 再次傳送」「Boss 與生命重置」 | 通過 |
| 勝利後返回 CC，重進不會重開洞窟 | 「勝利回到 CC 身旁」；CC 對話版本改為加入橋段，沒有 teleport 動作（單元測試） | 通過 |
| 接受／拒絕都加入；拒絕顯示 💢 與 OS | route test 走拒絕分支（截圖 17）；單元測試檢查兩選項皆 `cc_joined`、拒絕台詞含 💢 與「你怎麼忍心!!!」 | 通過 |
| F6／F7 後任務、旗標、CC 與弟弟速度正確 | 洞窟內存檔；加入後存讀檔；讀「未加入」存檔寵物消失、CC 回攤旁；弟弟 124／哥哥 96 | 通過 |

截圖：`12_breakfast_stall`、`13_cave_arrival`、`14_carry_item`、`15_boss_hit`、`16_cc_join_choice`、`17_cc_rejected`、`18_pet_follow`。

## 4. 設計說明

- **一套互動輸入**：地上的物品是 `Interactable` 子類，E 的優先序在 `InteractionController`：對話推進 > 舉物時投擲 > 一般互動（含撿取）。
- **戰鬥邏輯只在兩支腳本**：`FriedFoodDemon`（狀態機、只發 signal）與 `BattleDirector`（接線、掉翅、生命、勝負）。
  主城、CC、物品、`PlayableCharacter` 都不知道戰鬥存在；`Main` 只把勝負轉成旗標、任務事件與返回。
- **戰鬥暫態不進存檔**：Boss 生命、玩家生命、手上的物品都在 `BattleDirector`／`CarrySystem`；轉場開始時清空。
  在洞窟內讀檔會重新開始這一場（Boss 與生命重置）。
- **CC 的兩種身分**：早餐攤旁的 CC 是資料驅動的 NPC（`requires` 控制出現）；加入後變成 `PetFollower`，兩者共用同一份 `CharacterData`。
- **選項只擴充資料格式**：`choice` 是對話版本的可選欄位，沒有選項的對話流程完全不變。

## 5. 暫時內容（正式內容到位後替換）

- `assets/quests/phase4_cc_quest.json` 整個任務；`assets/dialogue/tide_root_town.json` 的 `grandma_turtle`、`cc_penguin` 所有版本（CC 台詞為短句 + です，其餘標 TEMP_DEMO_CONTENT；拒絕分支的 💢 與 OS 為規劃指定內容）。
- 洞窟 tile 為程式合成；阿嬤的行走幀只是正面／側面交替（她不會走動，目前不播放）。
- 早餐攤、愛心、💢、香椿乾拌麵圖示為程式繪製。
- Boss 攻擊只有「衝撞」一種；沒有音效。

## 6. 未完成／取捨

- **損毀素材**：分支上妹妹行動表、阿嬤、洞窟三個檔案都不是 PNG；妹妹與阿嬤已由作者提供原圖補上，`CAVE_fried_food_demon_arena_reference.png` 仍需重新交付（見 `docs/ASSET_REQUEST.md` D 節）。
- 「回到共享家庭屋休息才進入下一個遊戲日」：目前沒有每日系統，本階段未建立，也沒有把 F5 接到任何每日邏輯。
- 洞窟只有一個房間、沒有小怪；物品命中後在原位重生（2 秒），沒打中則掉在落點——這樣 5 次命中一定可達成。
- 拒絕分支的旗標命名：接受 → `cc_join_choice`；拒絕 → `cc_rejection_reaction_seen`（規劃的 `cc_join_choice` 解讀為「是否接受」）。
- 被切換成跟隨者的角色會繼續舉著物品，切回來才丟；沒有自動放下。
- 對話框內的 💢 依賴系統字型備援（macOS 有 Apple Color Emoji），其他平台可能顯示空框；CC 頭上的 💢 是貼圖，不受影響。

## 7. 建議下一步

1. 請遠端重新交付洞窟參考圖（若能附 32×32 tile 組更好）；到位後只要重跑 `tools/build_assets.py` 並 `--import`。
2. 若要做「休息進入下一天」，建議在 `GameState` 加 `day` 欄位（schema_version 3）並由家庭屋的床互動觸發。
3. 好感度、CC 小動作種類、Boss 第二種攻擊都可以只改 `PetFollower`／`FriedFoodDemon`，不動其他系統。
