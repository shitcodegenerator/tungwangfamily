# Phase 5 完成報告：每日循環與下層樹根廣場美術垂直切片

日期：2026-09-05　Godot 4.7.2　規劃：`docs/PHASE_5_PLAN.md`、`docs/LOCAL_AI_PHASE_5_PROMPT.md`、`docs/TILEMAP_AND_MAP_ASSET_TUTORIAL.md`　分支：`phase-5-daily-map`（自 master `12bc6d1` 建立）

## 1. 驗收結果

| 驗收項目 | 狀態 | 說明 |
|---|---|---|
| GameState 升 schema v3（day、day_seed、daily_state） | 完成 | `to_dict` 寫入三個欄位；`from_dict` 讀 v1／v2 存檔補 day 1、`seed_for_day(1)`、空 daily_state，旗標、任務、背包、寵物原樣保留；schema 4 以上拒絕 |
| 新遊戲從 day 1 開始 | 完成 | 單元測試 + route test 開場檢查 |
| 只有共享家庭屋休息確認後才進下一天；取消不加 | 完成 | 臥室門對話 `choice`：「休息」帶 `{"rest": true}`、「再等等」不帶；`rest` 只由 `Main.rest_until_morning` 處理，`QuestManager.apply_actions` 不會動 day |
| 同一次休息只加 1 天 | 完成 | `_resting` 旗標：轉場中重複觸發被忽略；route test 在轉場中連呼叫兩次 `rest_until_morning()`，結果 day 只 +1 |
| 休息流程：確認→淡出→day +1→存檔→早晨轉場→回到家庭屋 | 完成 | `RestTransition.play`：淡黑 0.5s → 全黑時 `advance_day()`、`load_scene("family_home", "rest")`、`SaveManager.save_state` → 日出四幀 +「第 N 天」→ 淡入 0.7s → `DayNight.play_morning()` 暖色 4 秒漸變成白天 |
| 連續切場景不重複加 day；重啟後 day、旗標、位置、任務一致 | 完成 | route test：家庭屋↔主城來回後 day 不變；F7 讀回休息時的自動存檔 day、旗標、寵物、場景一致 |
| 每日 reset hook 只執行一次、不清永久旗標與 CC | 完成 | `reset_daily_state()` 只清 `daily_state`；`day_advanced` signal 發一次；單元測試與 route test 都檢查 cc_joined、寵物、任務、背包 |
| 每日 reset 只接一個示範旗標 | 完成 | 家庭屋流理台：第一次互動 `set_daily_flag: demo_counter_checked_today`，同一天再互動走「已看過」版本（`requires.daily_flags`），休息後重置 |
| day_seed 可重現 | 完成 | `seed_for_day(day)` 確定性雜湊；`daily_rng()`；裝飾層亂數種子 = 固定種子 + day_seed（新的一天花草分布會換） |
| F5 保留為日夜測試鍵、不偷偷加 day | 完成 | 三態循環不變；route test 按三次 F5 後 day 不變 |
| 早晨→白天→傍晚簡單轉場 | 完成 | 早晨是純視覺色調（`MORNING_COLOR`）與 HUD 標籤，不是存檔狀態；`time_of_day` 仍為 0／1／2 |
| 天數與時段 HUD | 完成 | `DayHud`：畫面上方中央「圖示 + 第 N 天・時段」，圖示取自 `day_phase_icons.png`（早晨、白天、黃昏、夜晚） |
| 下層樹根廣場改用新 atlas，ASCII／碰撞／出口不變 | 完成 | `scenes.json` 主城 `tile_style: "town_refresh"`、`tile_style_rows: [23, 35]`；`TileLibrary.town_refresh_atlas_for` 依四方鄰居選 tile |
| 草地、石板路、水岸、木橋、樹根牆五種材質鄰接 | 完成 | 石板看「草地鄰居」→ edge／corner；水看「陸地鄰居」（橋不算）→ 水岸 edge／corner；`=` 兩列東西向木橋上列／下列；`#` 下方可走用草崖、其餘樹根牆；`|` 退回舊樓梯 |
| 新 atlas 每格 32×32、沒有可見白邊 | 完成（本機修正） | 交付 atlas 每格有 1px 亮框 + 1px 暗框（平鋪出格線），切割器 `deframe` 去框後鏡射補回；單元測試量整面 tile 外圈與內圈亮度差 ≤ 12、32 格全不透明 |
| 第一批 props 替換 | 完成 | 共享家庭屋外觀、早餐攤、四盞 v2 燈籠、心形噴泉、根拱門、港口木箱酒桶、空白路牌、花圃共 11 個 `town_refresh/` 道具實例 |
| 大型 props 底部接地、Y-sort、碰撞 | 完成 | 新選項 `foot_x`（燈籠柱在貼圖右側）、`foot_inset`（拱門石板地面）、`glow_x`、`collision_boxes`（拱門兩腳）；碰撞與貼圖分離、由 JSON 定義 |
| 角色可從出口與屋門正常通行 | 完成 | route test：新樹屋門進出家庭屋、穿過拱門上下樓梯、繞過噴泉、噴泉水池阻擋 |
| 舊 atlas、舊 props、舊存檔欄位不刪 | 完成 | 舊 tileset 第 0～5 列逐位元不變；舊 props PNG 全部保留；中層／上層仍用舊樣式 |
| Phase 1～4.6 不回歸 | 完成 | 單元測試 254 通過、route test 267 通過（含全部舊流程） |

## 2. 素材檢查

| 檔案 | 檢查結果 | 處理 |
|---|---|---|
| `assets/tilesets/town_visual_refresh_tiles_32.png` | 256×128 RGBA、32 格全不透明。**每格最外圈 1px 偏亮（~132）、次外圈 1px 偏暗（~86），內部 ~109**：平鋪後出現整齊格線（同 A8） | `tools/build_assets_phase5.py`：取每格內部 28×28，外圈 2px 鏡射補回，寫入 tileset 第 6～7 列 |
| 同上，`path_edge_s`、`shore_edge_s` | 與 `_n` 同向（草都在上） | 由 `_n` 垂直翻轉產生，原格位置不變 |
| 同上，`path_corner_sw/se`、`shore_corner_sw/se` | `path_corner_sw` 是「草地佔四分之三、石板只在右下」的內凹角；其餘三格與 `_nw`／`_ne` 同向 | 由 `_nw`／`_ne` 垂直翻轉產生 |
| 同上，`bridge_planks`、`bridge_edge` | 南北向（欄杆在左右）；主城港口橋是東西向兩列 | 旋轉 90° 後合成上列（欄杆在上）與下列（欄杆在下），放第 7 列第 16～17 欄；`bridge_edge` 未使用 |
| `assets/props/town_refresh/*.png` ×8 | 尺寸與 manifest 一致、四角透明、底緣有不透明像素 | 直接使用（正式檔不經切割器） |
| `assets/ui/day_phase_icons.png` | 96×24，四格 24×24 | 順序判定為 早晨、白天、黃昏、夜晚（`DayNightController.PHASE_ICON_*`），若作者原意不同只需改四個常數 |
| `assets/ui/rest_prompt.png` | 32×32 床 + Zzz | 臥室門互動提示（`prompt_icon`） |
| `assets/effects/morning_transition_sheet.png` | 256×64，四幀日出 | 休息轉場卡 |
| `assets/reference/incoming/TOWN_visual_refresh_tiles_reference_v1.png` | **不是 PNG（`file` 判定為 data）** | 未使用；只作構圖參考，請遠端重新輸出 |

## 3. 版面決定（下層樹根廣場）

| 物件 | 位置（底部中央） | 碰撞 | 說明 |
|---|---|---|---|
| 共享家庭屋外觀 `shared_family_treehouse_v2` | (144, 672) 同舊樹門房屋 | [150, 60] | 門口傳送門與返回點不變；貼圖 176×162 比舊屋大，頂端會蓋到街道第 16～17 列的西橋頭（走到左側橋頭時角色被屋頂遮住，見第 6 節） |
| 早餐攤 `breakfast_stall_v2` | (208, 900)（原 (240, 948)） | [132, 36] | 攤子往牆邊退，阿嬤與 CC 站在攤前右側不被遮；原位置的兩個木箱與苔石移除 |
| v2 燈籠 ×4 | (176, 960)、(592, 1056)、(688, 1056)、(400, 1088) | [10, 8] | `foot_x: 60`（燈柱）、`glow_x: 36`／`glow_y: 43`（光暈對準燈籠）；噴泉兩側各一盞 |
| 心形噴泉 `heart_fountain_v2` | (640, 992) | [96, 40] | 廣場東南，不擋出生點與市集老龜；封鎖 (18～21, 29～30) |
| 根拱門 `root_archway_v2` | (480, 762)，`foot_inset: 38` | 兩腳 [49, 40, -57] 與 [57, 40, 62] | 立在樓梯底端，石板地面蓋住樓梯最下一列；開口留給第 14～15 欄（中央 64px），兩腳封鎖第 13／16 欄；角色在樓梯上時透過開口可見 |
| 港口木箱酒桶 `harbor_crate_barrel_v2` | (672, 832) | [88, 28] | 取代市集老龜旁兩個木箱 |
| 空白路牌 `blank_signpost_v2` | (736, 864)，`foot_x: 25` | [12, 8] | 港口橋入口 |
| 花圃 `flower_herb_bed_v2` | (272, 1088) | [100, 30] | 西南草地水邊 |

未替換（維持舊樣式）：兩面旗幟、市集老龜旁以外的木箱、荷葉池、港口泊位、其他區域的燈籠與房屋。

## 4. 修改檔案

| 類型 | 檔案 |
|---|---|
| 狀態 | `scripts/state/game_state.gd`（v3、`advance_day`、`reset_daily_state`、每日旗標、`daily_rng`、`seed_for_day`、`day_advanced`） |
| 對話／任務 | `scripts/dialogue/dialogue_resolver.gd`（`daily_flags`／`not_daily_flags`）、`scripts/quest/quest_manager.gd`（`set_daily_flag`／`clear_daily_flag`） |
| 主流程 | `scripts/main.gd`（`rest_until_morning`、`_on_rest_dark`、`is_resting`、DayHud 綁定、`--snapshot`）、`scenes/main.tscn`（DayHud、RestTransition 節點） |
| UI | `scripts/ui/rest_transition.gd`（新）、`scripts/ui/day_hud.gd`（新）、`scripts/ui/debug_hud.gd`（說明文字）、`scripts/interaction/interactable.gd`（`prompt_texture`）、`scripts/interaction/interaction_controller.gd`（自訂提示圖示） |
| 日夜 | `scripts/world/day_night.gd`（`play_morning`、`is_morning`、`phase_icon_for`、`MORNING_COLOR`） |
| 地圖 | `scripts/world/tile_library.gd`（第 6～7 列常數、`town_refresh_atlas_for`、`neighbor_mask`、`edge_tile_for`、`uses_town_refresh`、更新水面動畫）、`scripts/world/town_world.gd`（`tile_style_rows`、`collision_boxes` 登記、`prompt_icon`、裝飾種子含 day_seed）、`scripts/props/town_prop.gd`（`foot_x`、`foot_inset`、`glow_x`、`collision_boxes`、`sprite_offset_for`、`collision_boxes_from`） |
| 資料 | `assets/maps/scenes.json`（主城 `tile_style`、`tile_style_rows`）、`assets/maps/tide_root_town_props.json`（第 3 節版面）、`assets/maps/family_home_props.json`（臥室門互動、`entries.rest`）、`assets/dialogue/family_home.json`（`family_rest_door`、流理台每日版本） |
| 素材 | `assets/tilesets/tide_root_town_tileset.png`（擴充為 8 列）、新素材的 `.import` |
| 工具 | `tools/build_assets_phase5.py`（新）、`tools/build_assets.py`（串接）、`scripts/debug/snapshot.gd`（新：`--snapshot=<scene>:<x>,<y>:<png>` 版面截圖） |
| 測試 | `tests/run_tests.gd`（`test_phase5_tiles`、`test_game_state_v3`、`test_daily_flags_in_dialogue`、`test_phase5_props`、`test_phase5_ui`；tileset 列數與 schema 斷言更新）、`scripts/debug/route_test.gd`（`_phase5_checks`、截圖 20～24） |

## 5. 驗證

| 項目 | 結果 |
|---|---|
| `godot --headless --path . --import` | 新 PNG 與重切 tileset 已匯入 |
| `python3 tools/validate_map.py` | 4 場景通過 |
| `godot --headless -s res://tests/run_tests.gd` | 254 通過，0 失敗（Phase 4.6 為 177） |
| `--route-test` | 267 通過，0 失敗；跟隨者違規 0、Boss 越界 0（Phase 4.6 為 210） |
| 截圖 | `20_plaza_refresh.png`（新廣場）、`21_rest_prompt.png`（臥室門休息提示）、`22_rest_sunrise.png`（日出卡「第 2 天」）、`23_morning_wake.png`（早晨色調、醒來點、HUD「第 2 天・早晨」）、`24_plaza_night.png`（夜晚 v2 燈籠光暈） |

需要重新匯入：是（拉取後請跑 `godot --headless --path . --import`）。

## 6. 待作者確認的視覺問題與已知限制

1. **共享家庭屋外觀蓋到街道**：176×162 的樹屋以舊門口為底部，頂端 64px 伸進第 16～17 列（西橋頭與街道）。角色走到左側橋頭時會被屋頂遮住（Y-sort 正確，但視覺上像走到房子後面）。可選：作者把樹屋縮成 3 列高（約 176×96），或把家庭屋門口往南移一列（需同步改傳送門、返回點與 route test）。
2. **根拱門的頂端**：拱門立在樓梯底端，樹冠約蓋到第 20～21 列的東西向街道；在街道橫越第 12～17 欄時角色下半身會被拱門遮住。這是 Y-sort 的正確結果，但若不想要，拱門可以改放別處（廣場內沒有第二個南北向走廊）或縮小。
3. **拱門開口只有 53px**：兩腳碰撞盒之間留 64px 給第 14～15 欄，角色寬 46px 可通過，但跟隨者連走時會貼腳滑一下；route test 通過。
4. **交付 atlas 的四個角落格與兩個南邊格方向錯誤**（第 2 節），目前以翻轉補齊；翻轉後光影方向與其他格相反，遠看不明顯。若要正式版請遠端重出（見 `docs/ASSET_REQUEST.md` E 節）。
5. **去格框的鏡射補邊**：每格外圈 2px 是內部像素的鏡像，草地在 3×3 平鋪時可看出對稱的小圖案；重出無格框的 atlas 後把 `FRAME_PX` 設 0 即可。
6. **早晨只是色調**：沒有獨立的早晨時段（存檔 `time_of_day` 仍是白天），符合規劃「先不建立複雜時鐘」。
7. **CC 每日餵食、好感度、每日獎勵**：未實作，等作者定案。每日系統目前只有 `daily_state` 與一個示範旗標。
8. **時段圖示順序**是依圖案判讀（暖黃日出＝早晨、淡黃＝白天、橘＝黃昏、雲月＝夜晚），如與原意不同改 `DayNightController.PHASE_ICON_*` 四個常數。
9. 中層與上層仍是舊 atlas，與下層的交界在第 22／23 列（舊草地接新樹根牆）。是否全面套用新 atlas 等作者看過下層再決定。
