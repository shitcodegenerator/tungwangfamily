# Phase 1 完成回報（2026-09-04）

環境：macOS（Apple M1 Pro）、Godot 4.7.2 stable、Python 3.9 + Pillow 11.3。

## 1. 建立的檔案

```text
project.godot / icon.svg / README.md / AGENTS.md / .gitignore
assets/characters/playable/{big_brother,calm_brother,sister_sheep,younger_brother}_sheet.png   192×256 精靈表
assets/characters/playable/{big_brother,calm_brother,sister_sheep,younger_brother}.tres        CharacterData
assets/tilesets/tide_root_town_tileset.png          576×96（18×3 格，32×32）
assets/maps/tide_root_town.txt                      30×36 ASCII 地圖
assets/maps/tide_root_town_props.json               道具、出生點、出口、區段
assets/props/*.png                                  27 個道具（房屋 ×6、燈、木箱、路牌、柵欄、雲 ×4、樹心、公告欄、樹冠門…）
assets/ui/fusion_pixel_12px_zh_hant.ttf + theme.tres  像素 CJK 字型（OFL）
assets/reference/                                   原始參考圖（僅供切割）
scenes/main.tscn, scenes/world/tide_root_town.tscn, scenes/characters/playable_character.tscn,
scenes/props/town_prop.tscn, scenes/ui/debug_hud.tscn
scripts/main.gd, scripts/world/{town_world,map_parser,tile_library}.gd,
scripts/characters/{player_character,follower_character,party_controller,party_trail,character_data}.gd,
scripts/props/town_prop.gd, scripts/camera/camera_rig.gd, scripts/ui/debug_hud.gd, scripts/debug/route_test.gd
tests/run_tests.gd
tools/build_assets.py, tools/validate_map.py
docs/PHASE_1_PROJECT_PLAN.md, docs/LOCAL_AI_PHASE_1_PROMPT.md, docs/PHASE_1_REPORT.md, docs/screenshots/*.png
```

## 2. 執行指令與結果

| 指令 | 結果 |
|---|---|
| `godot --headless --path . --import` | 匯入完成，無 parser error |
| `godot --headless --path . --quit-after 180` | 主場景執行 180 幀，無 runtime error |
| `python3 tools/validate_map.py` | 地圖驗證通過（6 個檢查點皆可達、邊界可走格皆封鎖） |
| `godot --headless --path . -s res://tests/run_tests.gd` | 38 通過，0 失敗 |
| `godot --path . --always-on-top -- --route-test --shots=$PWD/docs/screenshots` | 結果：PASS（30 通過，0 失敗，144 秒）、切換 20 次、跟隨者違規 0 筆 |

單元測試涵蓋：地圖解析與驗證、BFS 路徑（含封路情境）、圖例→tile 對應、碰撞 TileSet、
軌跡資料結構、方向判定、跟隨速度決策、SpriteFrames 切格、道具與精靈表資源存在性。

## 3. 地圖通行驗證（自動化路線測試）

| 項目 | 結果 |
|---|---|
| 出生點 → 中層樹洞街 | 成功 |
| 中層 → 上層樹枝平台（經右側樓梯、橫向樹枝、中央樹幹） | 成功 |
| 上層 → 走回出生點 | 成功 |
| 左側橋頭：可走到、被柵欄擋住、不會離開主城 | 成功 |
| 右側船港：可走到、被柵欄擋住、不會離開主城 | 成功 |
| 上方樹冠入口：可走到、被藤蔓木門擋住、不會離開主城 | 成功 |
| 房屋外牆阻擋（不可進入） | 成功 |
| 深水阻擋 | 成功 |
| 樹皮牆阻擋 | 成功 |
| 地圖外圍阻擋 | 成功 |
| 牆角繞行（樹皮牆→房屋轉角→橋頭旁）後跟隨者 2.5 秒內追上 | 成功 |
| 快速左右反覆移動 3 秒後仍可正常行走、跟隨者 2.5 秒內追上 | 成功 |
| 途中切換角色 20 次後隊伍完整 | 成功 |
| 跟隨者全程未穿牆、未掉出地圖 | 成功（每個 physics frame 檢查） |

截圖：`docs/screenshots/01_spawn_lower_plaza.png`（出生廣場）、`02_middle_hollow_street.png`（中層）、
`03_upper_branch_platform.png`（上層頂端）。

## 4. 角色切換與跟隨

- 1～4 與 Tab 切換：新領頭者立刻接受輸入，其餘成員依新順序改追前一位，不傳送任何人。
- 跟隨採軌跡法：每 4px 記一點、最多 96 點；跟隨者追前一位隊員軌跡上 40px 之後的點，
  直線距離 < 30px 停下、> 90px 以 1.4 倍速追趕，接近目標時減速；卡住 0.4 秒改直線靠近再回到軌跡。
- 領頭者尚未移動時跟隨者保持原位（出生與切換當下不會擠成一團）。
- 四方向 idle/walk，停止時保留最後方向；站立微晃動只動 `VisualRoot.position.y`（0 / -1 / 0 / +1，週期 0.8 秒），
  四人相位分別為 0 / 0.2 / 0.45 / 0.65 秒。

## 4b. 本輪補齊的規劃項目

- 地標：廣場旗幟 ×4、廣場水池（2×2 淺水格＋荷葉）。
- 互動預留：角色場景 `InteractionOrigin/InteractionArea`（Area2D，偵測第 3 層 Interactable）＋
  `interactable_entered/exited` signals；Phase 1 沒有接收者。
- `scenes/characters/party_member.tscn`（繼承 playable_character，供未來只給跟隨者的覆寫）。
- `export_presets.cfg`：macOS universal 與 Windows x86_64。
- 物理層命名：1 World、2 Characters、3 Interactable。
- 測試：新增牆角繞行與快速反覆移動兩組跟隨者追上檢查。

**macOS 注意**：視窗被遮蔽時 App Nap 會讓 Godot 計時器極慢、停止重繪，route test 會卡住。
已執行 `defaults write org.godotengine.godot NSAppSleepDisabled -bool YES`，且測試指令加了 `--always-on-top`。

## 5. 尚未完成／後續需要替換

- **行走動畫為合成幀**：參考圖每個方向只有 1 幀，目前第 2、4 幀以「身體上移 1px + 腳部左右錯位 1px」合成。
  正式素材完成後直接覆蓋 `assets/characters/playable/*_sheet.png`（維持 192×256、列序 down/left/right/up）即可。
- **合成道具**：`tree_heart.png`（樹心）、`bulletin_board.png`（公告欄）、`canopy_gate.png`（樹冠門）、`flag_banner.png`（旗幟）為程式繪製的 placeholder。
- 完整素材需求清單見 `docs/ASSET_REQUEST.md`。
- **合成 tile**：虛空、雲霧、樓梯、橋欄杆、深色樹皮為程式合成（tileset 第 2 列）。
- 沒有自動 tiling（草地／水岸邊緣沒有過渡 tile）；Phase 2 若要更精緻可加 terrain set。
- 出口只有柵欄、路牌與文字提示，尚無互動（Phase 2 加 Area2D）。
- 未建立 git repo（依規範不主動 commit）。

## 6. 已知取捨

- `PartyController` 為 Node2D（規劃寫 Node），因為 Godot 的 Y-sort 只在 CanvasItem 鏈上生效，
  角色需與道具同一 Y-sort 群組才能正確前後遮擋。
- 地圖與碰撞在執行期由 ASCII 建立，而非存成 TileMap 資料；好處是可以 diff、可以用 Python 與 GDScript 同時驗證。
