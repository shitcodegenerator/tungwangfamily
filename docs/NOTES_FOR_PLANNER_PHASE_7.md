# 給規劃 AI：Phase 7 回饋與下一階段待處理事項

整理日期：2026-09-07。作者已看過 `docs/PHASE_7_REPORT.md`，以下是本地實作後**需要規劃端接手**的項目，請在規劃 Phase 8（或安排美術重製）時一併閱讀。
Phase 7 的程式與資料修改請以分支 `phase-7-visual-foundation` 為準；本文件只列「還沒解決、需要規劃或素材」的部分。

## 0. 作者已決定（本地已實作，不用再問）

| 項目 | 決定 |
|---|---|
| 任務／線索日誌翻頁鍵 | `<`／`>`（`,`／`.` 鍵，InputMap `quest_log_prev_page`／`quest_log_next_page`）一次翻一頁；滑鼠滾輪連續捲動；**方向鍵保留給角色移動**，日誌開著時仍可移動 |
| 捲動位置 | 每次打開回到頂端，不進存檔 |
| 樹屋 | 只改 props `foot_inset 64`（貼圖下移，頂端 y=574），碰撞、門口傳送門 (144,674)、返回點 (144,702) 不變 |
| 根拱門 | 只改 props `z_bias -1`（整張畫在角色後方），碰撞盒不變 |

## 1. 大型 props 的邊角案例（需要素材或版面決定）

只靠 props JSON 的視覺欄位，兩個大型 props 各留下一個角色會「畫在貼圖上方」的位置。截圖在 `docs/screenshots/phase7_review/`。

### 1a. 共享家庭樹屋（`assets/props/town_refresh/shared_family_treehouse_v2.png`，176×162）

- 現況：貼圖是「門＋牆」的立面，比地圖上 3 列高的門口空間高 5 列。`foot_inset 64` 後第 16～17 列街道已清楚，但**第 18 列**（門正上方那條草地，x 64～224）仍在屋頂上緣後面，站在那裡腳會被蓋住一小段（`02_treehouse_row18_before_after.png` 右）；門右側牆前 (208,688) 角色畫在牆面下緣上，看起來略「貼牆」（`05_treehouse_door_and_wall_after.png` 右）。
- 可選方案（請規劃端擇一並交付）：
  1. **重出較矮的樹屋**：約 176×96～110（3 列高），門與踏墊比例不變、底緣仍是接地線、透明背景、色盤依 `docs/ART_STYLE_LOCK.md`。本地只需把 `foot_inset` 改回 0 並重跑驗證。
  2. **把門口往南移一列**：需要同步改 `tide_root_town.txt`（第 21～22 列）、`family_home_door` 傳送門與 `return_position`、出生點距離、route test 路線；本地可做，但要規劃端在 Phase 計畫裡明確列出新座標。
  3. 維持現狀，把第 18 列那條草地在 ASCII 地圖改成不可走（`#`）：最省事，但會少一條走道，需要作者同意。

### 1b. 根拱門（`assets/props/town_refresh/root_archway_v2.png`，176×166）

- 現況：`z_bias -1` 後隊伍穿過、在走廊兩側都看得到；但站在拱門正北**第 21 列**（x 392～568）時，隊伍畫在樹冠上方，像站在拱門頂上。
- 正式解法：**把拱門拆成兩張圖**——「樹冠」（固定畫在角色上方）與「拱腳＋石板地面」（Y-sort）。需要：
  - 素材：兩張同尺寸（176×166）、同錨點的透明 PNG，各只保留自己那部分的像素；或一張原圖加上一張「樹冠遮罩」。
  - 程式：`TownProp` 增加 `overlay_texture`（或 props JSON 第二筆 `z_bias 1` 的純視覺 prop 指到樹冠圖）。本地可做，約 30 行，請在計畫中列為一項。
- 若不想拆圖，替代方案是把拱門縮到 ≤ 96px 高（樹冠不再蓋到第 21 列），同樣需要重出素材。

## 2. 中層／上層舊 atlas 的接縫（後續美術重製）

- 下層廣場（第 23～35 列，新 atlas）草地／石板／水岸／木橋接縫正常。
- **中層與上層**（第 0～22 列）仍是舊 atlas：草地 `g` 與石板街道 `s` 之間沒有過渡 tile，是硬切（例如第 14～21 列街道兩側、第 12～13 列）；第 22／23 列是「舊草地接新樹根牆」的交界。
- 需要規劃端交付：舊區域改用新 atlas 的完整過渡組（草↔石板的直邊、內角、外角，草↔樹根牆、草↔水岸），格式依 `docs/ASSET_REQUEST.md` E 節與 `tools/build_assets_phase5.py` 的切割規則（32×32、無格框、四邊無縫、方向以檔名與像素一致）。交付後本地把 `scenes.json` 的 `tile_style_rows` 擴到全圖並跑驗證。
- 順序建議：先確認 1a 的樹屋方案，因為樹屋周圍第 16～22 列正是要換 atlas 的區域。

## 3. 來源檔的放置位置（流程）

- 遠端把 `cap_rope_coil.svg` 放在 `assets/props/`，Godot 會把 `assets/` 下所有 SVG 當貼圖匯入並產生 `.svg.import`（遊戲沒有用到它）。
- 請之後把 SVG／PSD／原始來源一律放 `assets/reference/incoming/`（本地只在 manifest 標明來源），`assets/props/`、`assets/tiles/`、`assets/characters/` 只放遊戲實際載入的 PNG。本地這次已提交 `.svg.import` 讓 checkout 乾淨，等遠端移走檔案後會一併刪除。

## 4. 仍然不在範圍（提醒）

- 正式劇情、Boss、NPC、父親真相、CC 好感度／每日餵食：維持 `docs/PHASE_3_DECISIONS.md` 的邊界，Phase 6 的 TEMP_DEMO_CONTENT 文字全部未動。
- 任何新圖都要先過 `docs/ART_STYLE_LOCK.md`（透明背景、色盤、尺寸、錨點、不烙陰影），並在 manifest 寫 SHA-256、尺寸、用途。
