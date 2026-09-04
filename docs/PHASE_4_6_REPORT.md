# Phase 4.6 完成報告：角色動畫、接地感與洞窟正式素材

日期：2026-09-05　Godot 4.7.2　規劃：`docs/PHASE_4_6_ANIMATION_AND_CAVE_ASSETS.md`、`docs/LOCAL_AI_PHASE_4_6_PROMPT.md`

## 1. 結果總覽

| 驗收項目 | 狀態 | 說明 |
|---|---|---|
| 四位角色改用 4 幀行走表（0≠2、1≠3） | 完成 | `CharacterData.sprite_sheet` 改指向 `<id>_walk_v2_sheet.png`；單元測試逐格比對 |
| 停止時使用獨立待機表、1px 呼吸 | 完成 | 新欄位 `CharacterData.idle_sheet`；`build_sprite_frames` 第三個參數；IDLE_FPS 3.3（4 幀約 1.2 秒） |
| 停止先停在 contact A，0.12 秒後切待機 | 完成 | `STOP_TO_IDLE_SECONDS`；route test 驗證停下 0.05 秒為 walk 第 0 幀且暫停、0.35 秒後為 idle |
| 待機時碰撞、地面錨點、陰影不動 | 完成 | 有待機表的角色關掉程式微晃動（VisualRoot 固定 0）；呼吸由待機幀負責 |
| 角色與 CC 腳下陰影固定在地面錨點 | 完成 | 三個角色場景新增 `Shadow` Sprite2D（第一個子節點、位置 (0,0)、centered）；主角與 NPC 用 32×12、CC 用 24×9 |
| 隊伍同格重疊 | 完成 | `FollowerCharacter.separation_velocity`：停下時與任一隊員距離 < 26px 就以半速推開；領頭者尚未移動時也會分離（出生、切換、返回不再疊成一點）；洞窟出生點改為間隔 2 格 |
| 洞窟改用正式 32×32 tile | 完成 | `assets/tiles/fried_food_cave_tiles_32.png` 4×2 由切割器複製到 tileset 第 5 列第 0～7 欄；`scenes.json` 以 `tile_style: "cave"` 走 `TileLibrary.cave_atlas_for`，碰撞資料與地圖座標不變 |
| 晶簇 overlay 不阻擋 | 完成 | 只放在「與地面相鄰的牆」的裝飾層（22% 機率、固定亂數種子），可走格不放 |
| Boss 離上緣至少 2 格、頭不被裁 | 完成 | `battle.min_y = 128`（最上方可走列 +2 格）；`FriedFoodDemon.min_y` 執行期夾住；`validate_map.py` 檢查 min_y、生成點與頭高；route test 全程監看 |
| 對話框 💢 改圖片 | 完成 | `DialogueLabel` 改為 RichTextLabel；`DialogueBox.to_bbcode` 把 💢 換成 `[img=12x12]anger_mark.png`，方括號會跳脫 |
| Phase 1～4 流程不回歸 | 完成 | route test 210 項通過（含 Phase 4 全流程） |

## 2. 素材檢查

| 檔案 | 檢查結果 |
|---|---|
| `*_walk_v2_sheet.png` ×4 | 192×256 RGBA；每格 alpha 下緣 = 62（腳底 y=61）；每方向 0≠2、1≠3 |
| `*_idle_sheet.png` ×4 | 192×256 RGBA；四幀下緣 62／61／62／63（呼吸 1px 已畫進幀裡） |
| `character_shadow.png`、`pet_shadow.png` | 32×12、24×9；深藍 (17,24,31)、最高 alpha 約 41% |
| `fried_food_cave_tiles_32.png` | 128×64 RGBA；兩款地面最右一欄比其他欄暗約 15 階，平鋪會出現直向接縫，切割器複製第 30 欄補平（其餘 6 格逐像素不動） |
| `CAVE_fried_food_demon_tiles_reference_v2.png` | 只作參考，未進遊戲 |

**注意：新表的角色造型與 Phase 2 正式表不同**（Q 版比例、頭身較大；冷靜哥是貓頭鷹鳥形、弟弟是四足猴形）。舊表仍在 `assets/characters/playable/<id>_sheet.png`，把 `.tres` 的 `sprite_sheet` 指回去並清空 `idle_sheet` 即可還原。舉物／投擲行動表已由作者提供新造型原圖（`ACTION_<id>_v2_carry_throw_reference.png`，4 列 × 3 欄），切割器 `build_action_sheet_v2` 泛洪去背後依 v2 站立幀高度縮放；舊造型的 Phase 4 行動表參考仍保留作備援。

## 3. 修改檔案

| 類型 | 檔案 |
|---|---|
| 角色 | `scripts/characters/character_data.gd`（`idle_sheet`）、`player_character.gd`（待機表、contact A 停頓、關程式微晃動、`has_idle_sheet`／`current_animation`）、`follower_character.gd`（`separation_velocity`、`others`、`tie_break`）、`party_controller.gd`（分離接線、`TIE_BREAKS`） |
| 場景 | `scenes/characters/playable_character.tscn`、`npc.tscn`、`pet_follower.tscn`（Shadow）、`scenes/ui/dialogue_box.tscn`（RichTextLabel） |
| 資料 | `assets/characters/playable/*.tres`（v2 行走表 + 待機表）、`assets/maps/scenes.json`（`tile_style`、`battle.min_y`）、`assets/maps/fried_food_cave_props.json`（出生點間距） |
| 世界 | `scripts/world/tile_library.gd`（`cave_atlas_for`、`cave_decoration_for`、CAVE_* 常數）、`town_world.gd`（`tile_style` 選項） |
| 戰鬥 | `scripts/battle/fried_food_demon.gd`（`min_y`）、`battle_director.gd`（設定 min_y） |
| UI | `scripts/ui/dialogue_box.gd`（`to_bbcode`） |
| 工具 | `tools/build_assets_phase4.py`（`build_cave_tiles` 改複製正式 tile 組、`seamless_floor`、`build_action_sheet_v2`）、`tools/validate_map.py`（Boss 上緣檢查） |
| 測試 | `tests/run_tests.gd`（`test_phase46_sheets`、`test_phase46_logic`、洞窟 tile 對應改寫）、`scripts/debug/route_test.gd`（`_phase46_checks`、Boss 邊界監看、`_min_member_gap`、截圖 19） |

## 4. 驗證

| 項目 | 結果 |
|---|---|
| `python3 tools/validate_map.py` | 4 場景通過（含 Boss 上緣檢查） |
| `godot --headless -s res://tests/run_tests.gd` | 177 通過，0 失敗 |
| `--route-test` | 210 通過，0 失敗；跟隨者違規 0、Boss 越界 0 |
| 截圖 | `docs/screenshots/13_cave_arrival.png`（正式洞窟 tile、間隔出生）、`15_boss_hit.png`、`17_cc_rejected.png`（💢 圖片）、`19_idle_shadow.png`（待機） |

需要重新匯入：是。新增 PNG 與重切的 tileset 都已 `godot --headless --path . --import`；拉取後請再跑一次。

## 5. 已知限制與建議

- 陰影中心依規格放在地面錨點 (0,0)，上半段被角色身體蓋住，畫面上只露出腳下 6px、41% 透明度的深色弧線，偏含蓄；若要更明顯可請遠端把陰影畫成較寬或往下 2px 的版本。
- 分離只解決「同格」重疊：停下時隊員彼此至少 26px，但新造型寬 46px，並排時仍會互相遮到一半；要完全不遮需要拉開停止間距或縮小造型，屬美術決策。
- 洞窟只有左上、右上兩個轉角 tile 可用；底部兩角與側牆以岩壁頂平鋪，內凹角 (6,5) 目前地圖形狀用不到。
- Phase 5 每日系統未動；`GameState` 仍是 schema_version 2。
