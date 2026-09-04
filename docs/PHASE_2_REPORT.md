# Phase 2 完成回報（2026-09-04）

環境：macOS（Apple M1 Pro）、Godot 4.7.2 stable、Python 3.9 + Pillow 11.3。
規劃來源：`docs/PHASE_2_PLAN.md`、`docs/LOCAL_AI_PHASE_2_PROMPT.md`；素材補件：`assets/reference/incoming/A1～A11-A19`。

## 1. 新增與修改的檔案

```text
新增
scripts/interaction/interactable.gd            可互動 Area2D（物理層 3）＋ interacted signal
scripts/interaction/interaction_controller.gd  最近目標選擇、「E」提示圖示、E 鍵分派
scripts/ui/dialogue_box.gd + scenes/ui/dialogue_box.tscn  木框羊皮紙對話框（名稱、逐字、換行、頭像預留、繼續提示）
scripts/ui/dialogue_manager.gd                 單線對話流程（開始／推進／結束 signal）
scripts/world/day_night.gd                     CanvasModulate 日夜狀態（F5）
scripts/world/ambient_effects.gd               落葉／蝴蝶／螢火蟲 CPUParticles2D
assets/dialogue/tide_root_town.json            五個互動物件的對話內容
assets/ui/dialogue_frame.png、interact_prompt.png   對話框九宮格、互動提示圖示
assets/effects/lamp_glow.png、leaf.png、firefly.png、butterfly.png
assets/props/harbor_berth.png、fence_post.png  A9 泊位、A10 單根木樁
tools/build_assets_phase2.py                   Phase 2 素材管線（由 build_assets.py 自動呼叫）
docs/PHASE_2_PLAN.md、LOCAL_AI_PHASE_2_PROMPT.md、PHASE_2_REPORT.md、screenshots/04～08

修改
project.godot                 新增 interact（E）、debug_cycle_daytime（F5）
scripts/main.gd / scenes/main.tscn   接線：互動 → 對話、對話 → 輸入鎖、日夜 → 燈籠與粒子
scripts/world/town_world.gd   由 JSON 建立 Interactable、載入對話 JSON、道具動畫選項、apply_daytime、get_zone_rect
scripts/world/tile_library.gd tileset 擴為 18×5；水面 TileSet 動畫；補件 tile（虛空、雲霧、深色樹皮、樓梯）
scripts/props/town_prop.gd    frames/fps 多幀、drift 飄移、glow 光暈（只動 Sprite2D 子節點）
scripts/characters/player_character.gd  input_locked；精靈表 5 欄（第 0 欄站立、第 1～4 欄行走）
scripts/characters/party_controller.gd  set_input_locked（對話中不可移動、不可切換）
scripts/ui/debug_hud.gd / debug_hud.tscn  顯示時段、Phase 2 說明、對話時隱藏狀態列
scripts/debug/route_test.gd   Phase 2 驗收流程 + 五張新截圖 + force_draw
tests/run_tests.gd            新增 23 項斷言（共 61）
tools/validate_map.py         檢查 interact id 皆有對話；北出口檢查點改為 (14,2)
assets/maps/tide_root_town_props.json  interact 欄位、燈籠／旗幟幀數、雲霧飄移、樹冠門改為 A7 尺寸並移到 y=64
assets/characters/playable/*_sheet.png  240×256 正式行走表（A1～A4）
assets/props/tree_heart / bulletin_board / canopy_gate / flag_banner / fence / lamp_post  A5～A8、A10、燈籠 4 幀
assets/tilesets/tide_root_town_tileset.png  576×160
README.md、AGENTS.md、assets/reference/ASSET_README.md
```

## 2. 素材整理結果（A1～A19）

| 補件 | 處理 | 產出 |
|---|---|---|
| A1～A4 角色行走表 | 5 欄 × 4 列參考圖依格子聯集切割（水滴等分離小件併入），同角色 20 幀共用縮放，以格子水平中心為錨點避免抖動 | 4 張 240×256（第 0 欄站立、第 1～4 欄行走） |
| A5 樹心 | 縮至寬 176 | `tree_heart.png` 176×192，可互動 |
| A6 公告欄 | 縮至寬 52 | `bulletin_board.png` 52×47，可互動 |
| A7 樹冠門 | 縮至高 63；改放 y=64、碰撞 106×60（封住第 0～1 列），北出口檢查點改為 (14,2) | `canopy_gate.png` 106×63，可互動 |
| A8 旗幟 | 縮至高 48，旗面逐列 ±1px 正弦位移合成 4 幀 | `flag_banner.png` 4 幀 |
| A9 空泊位 | 縮至寬 128，取代原 `dock` 放在右側船港 | `harbor_berth.png` |
| A10 柵欄 | 切出柵欄（寬 64）與單根木樁（高 40） | `fence.png`、`fence_post.png`（後者尚未使用） |
| A11～A19 合成參考表 | 只擷取可驗證為完整 32×32 的格子：虛空 ×9（壓暗 0.62）、雲霧、深色樹皮、正面樓梯、花草草地、綠樹幹、木板 | tileset 第 4 列 |

未套用的 A11 部分：草地／泥土／水岸過渡 tile（參考表為 72×80 的斜視角格，邊緣規則無法對應 32×32 四方向 autotile），
以及樹幹頂／底、九種樓梯變體、樹輪平台 4×4、圓木與繩索柵欄。詳見第 6 節。

## 3. 執行指令與結果

| 指令 | 結果 |
|---|---|
| `python3 tools/build_assets.py` | 產生 4 張角色表、8 個新道具、576×160 tileset、UI／特效貼圖 |
| `godot --headless --path . --import` | 匯入完成，無 parser error |
| `godot --headless --path . --quit-after 120` | 主場景執行 120 幀，無 runtime error |
| `python3 tools/validate_map.py` | 地圖驗證通過（6 個檢查點皆可達、邊界封鎖、5 個互動物件對話齊全） |
| `godot --headless --path . -s res://tests/run_tests.gd` | 61 通過，0 失敗 |
| `caffeinate -dis godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots` | 結果：PASS（62 通過，0 失敗）、切換 22 次、跟隨者違規 0 筆 |

## 4. 驗收項目對照（LOCAL_AI_PHASE_2_PROMPT 第 1～10 項）

| # | 項目 | 自動化檢查 | 結果 |
|---|---|---|---|
| 1 | 靠近公告欄出現提示，離開後消失 | 「靠近公告欄出現互動提示」「離開公告欄後提示消失」 | 通過 |
| 2 | 按 E 開啟、推進並關閉對話 | 「按 E 開啟公告欄對話」「按 E 推進到下一句」「對話可推進至結束並關閉」 | 通過 |
| 3 | 對話中 WASD 不移動主要角色 | 對話中按住右鍵 0.5 秒，位移 < 1px | 通過 |
| 4 | 公告欄、樹心、三個出口都能互動 | 五個 `_interact_and_close` 檢查（確認目標 id、對話開啟、可關閉） | 通過 |
| 5 | 快速移動與隊伍跟隨正常 | Phase 1 牆角繞行、快速反覆移動、跟隨者追上檢查 | 通過 |
| 6 | 對話前後切換角色，隊伍不傳送、不消失 | 對話後切換，四人位移皆 < 4px；隊伍順序與對話前相同 | 通過 |
| 7 | 燈籠、水面、旗幟、雲霧循環動畫 | 燈籠 4 幀 5fps、旗幟 4 幀 4fps（TownProp）；水面 TileSet 動畫 4 幀（單元測試）；雲霧 drift | 通過（動畫本身以截圖與試玩確認） |
| 8 | F5 切換三種日夜狀態，碰撞不變 | index 0→1→2→0；碰撞格數與道具封鎖格數相同；夜晚房屋外牆仍阻擋 | 通過 |
| 9 | headless import 無 parser error | 見第 3 節 | 通過 |
| 10 | 既有 Phase 1 測試仍通過 | 38 項舊斷言全數保留（精靈表尺寸斷言改為 240×256） | 通過 |

截圖：`docs/screenshots/04_interact_prompt.png`（公告欄提示）、`05_dialogue.png`（對話框）、
`06_day.png`、`07_dusk.png`、`08_night.png`（中層燈籠旁三種時段）。01～03 亦以新素材重新擷取。

## 5. 設計說明

- **互動資料流**：JSON `interact` 欄位 → `TownWorld` 建立 `Interactable`（Area2D，物理層 3，矩形 = 碰撞盒外擴或 `interact_size`）
  → `InteractionController` 每個 physics frame 讀取領頭者 `InteractionArea` 內的候選並挑最近者 → 按 E 呼叫 `interact()`
  → `interacted` signal → `DialogueManager.start_from()`。`PlayableCharacter` 完全不知道對話與互動物件。
- **輸入鎖**：`DialogueManager.dialogue_started/finished` → `Main` → `PartyController.set_input_locked()`。
  鎖定時領頭者不讀移動輸入、`_unhandled_input` 不處理切換；跟隨者、鏡頭、位置全部維持原狀。
- **對話框**：NinePatch 木框（程式繪製九宮格）＋ `Label.visible_characters` 逐字（28 字／秒）＋ `AUTOWRAP_ARBITRARY`（CJK 換行）。
  `Portrait` 節點與 `set_portrait()` 為頭像接口；分支選項預留在 `DialogueManager`（目前只有單線）。
- **城鎮生命**：全部走 `TownProp` 的視覺選項或 TileSet 動畫，不新增任何碰撞或腳本節點；粒子為 `CPUParticles2D`。
- **日夜**：一個 `CanvasModulate`（白天 1,1,1／黃昏 1,0.78,0.6／夜晚 0.4,0.46,0.78，0.6 秒補間）＋ 燈籠 additive 光暈（黃昏 0.7、夜晚 1.0）。
  HUD 位於 CanvasLayer，不受色調影響。
- **測試如何按 E**：`Input.action_press` 不會派送事件，`_unhandled_input` 收不到；route test 改用
  `Input.parse_input_event(InputEventAction)`。

## 6. 尚未完成／仍待補齊的素材

- **A11 過渡 tile 未套用**：草地→泥土、草地→水岸的 8+8 格為斜視角 72×80 參考，無法直接對應 32×32 autotile 規則；
  需要重新產出「正上方視角、每格 32×32、含 4 邊 + 4 內角 + 4 外角」的過渡組（見 `docs/ASSET_REQUEST.md` A11 更新）。
- 樹輪平台 4×4、九種樓梯變體、樹幹頂／底、圓木與繩索柵欄已在參考表中但尚未切割使用。
- B 級素材（對話框九宮格、互動圖示、頭像、燈籠／水面動畫、粒子、NPC）目前全部為程式合成的 placeholder，
  正式素材到位後只需覆蓋 `assets/ui/`、`assets/effects/` 對應檔案。
- 日夜沒有時間系統，只有 F5；沒有音效。
- 未建立 git repo（依規範不主動 commit）。

## 7. 已知取捨

- 精靈表由 192×256 改為 240×256 以容納獨立站立幀；`build_sprite_frames` 同時支援 4 欄與 5 欄，舊素材仍可用。
- 樹冠門從 y=32 移到 y=64 並加高碰撞：新素材 63px 高，放在原位會被鏡頭上界裁掉；代價是上層可走區少了第 1 列的 4 格。
- 虛空 tile 採用補件星雲但壓暗 38%，且 16 格才出現一次亮環；原圖直接鋪滿時網格感過重。
- 東側船港互動點需站在 (27,27)（柵欄前一格）面向右；(26,27) 距離不足。
