# 給遠端規劃 AI：主城改為一般平面城鎮（D-013）

日期：2026-09-09　作者決定　狀態：D-014 已答（見第 8 節），等遠端出地圖規格，本地尚未動工

## 1. 決定與理由

作者看過霧 overlay 的白天／夜晚畫面後決定：主城不再用「樹」的垂直三層結構（上層樹冠平台／中層樹洞街／下層樹根廣場），改成一般平面城鎮。

理由不是單一素材，而是結構性的：

- OPEN_DECISIONS D-001、D-002、D-004、D-006、D-007 全部是大型物件疊在街道上的顯示層級問題。平面城鎮沒有「上一層蓋住下一層街道」的情境，這一類問題會直接消失。
- 上層樹冠、霧、根牆是 Phase 8 到 8.5 返工最多的素材（藍灰霧像破洞、填充包重出、霧 overlay 疊完仍不滿意）。
- 中層街道與下層廣場現在的長相已經是一般城鎮：草地、石板路、水岸、木橋、房屋立面、早餐攤、噴泉。真正要拿掉的只有樹專屬的部分。

## 2. 目標

一張新的主城 ASCII 地圖與 props 擺位表，讓本地 AI 能在一個 Phase 內完成重排，並且**不新增任何遊戲系統**。

## 3. 保留（不要重畫、不要換位置邏輯）

| 項目 | 現況 | 要求 |
|---|---|---|
| 下層廣場 | 第 24～35 列：石板廣場、苔石中心、水岸、東西向木橋、早餐攤、噴泉、港口木箱、花圃 | 版面與 props 原樣搬進新地圖，可整體平移 |
| 中層街道 | 第 12～23 列：草地、石板大街、五張房屋立面、燈柱、路牌、圍籬、告示板 | 保留；房屋立面用現有 v2（D-008 判定 KEEP） |
| 傳送門 | 家庭屋門 (144,674)、船長房門 (816,674)，size [22,6]，return_position 在門下 28px | 兩扇門保留，位置可隨房屋移動，但門檻規則不變 |
| NPC 與對話 | old_turtle、grandma_turtle、cc_penguin；洞窟由對話 teleport 進入 | 三位 NPC 站位需在規格裡指定新格；對話 JSON 不改 |
| 出口 | west_bridge (2,16)、east_harbor (26,27)，皆「未開放」 | 保留兩個；north_canopy 移除 |
| 出生點 | entries.default 四格一組，間隔 ≥ 2 格 | 指定新出生點四格 |
| 樹心 tree_heart | 帶互動與世界事件的地標 | 保留為城鎮地標（D-014），新地圖要給它一個顯眼位置，render_mode 與 event_id 不變 |
| 世界事件 | assets/events 只靠 props event_id 找目標 | 帶 event_id 的 props（bulletin_board、tree_heart）要在表裡標明 |

## 4. 移除

- 地圖字元 `.`（樹冠）、`c`（霧）、`T`（樹根）與整個上層區段（第 0～11 列）。
- tileset 第 8～10 列（上層填充包、霧 overlay）不再被引用；檔案先留著，D-011 一起處理。
- props：`canopy_gate`、`tree_spiral`、`tree_platform`、`vine_branch` ×3、`cloud_*` ×7、`root_archway_v3_base`／`canopy`（D-014：整個移除，不留作城門）。
- 樹屋立面 `shared_family_treehouse_v3` 改為一般房屋立面：優先沿用現有 v2 房屋（76／78／56／84／93 寬），不夠再談新素材。
- 區段名稱「上層樹冠平台／中層樹洞街／下層樹根廣場」改為平面城鎮的區段名；遊戲名「山海樹港」與主城名「潮根城」保留（D-014），區段名由遠端在規格裡提案、作者確認。

## 5. 硬性限制（規格必須遵守）

- 內容邊界：`docs/PHASE_3_DECISIONS.md`。不得自創劇情、地名故事、NPC 背景；樹意象去留已由 D-014 定案（見第 8 節），規格書不得再加新的世界觀元素。
- 圖例唯一來源 `assets/maps/tile_legend.json`；新地圖只能用登錄字元，需要新字元要在規格裡說明用途與可走性。
- 擺放硬檢查 MAP-P001～P007（`docs/RENDERING_AND_PLACEMENT_SPEC.md`）：碰撞盒頂端對齊 32 倍數；每個 prop 必填 `render_mode`（ground／back／ysort／split）；大型物件北側不留無法進入的口袋，除非是對話站位（D-006 花圃例外的規則沿用）。
- 像素規範 `docs/ART_STYLE_LOCK.md`：1× 像素、alpha 只用 0／255。
- 地圖尺寸建議 30 寬 × 24 列以內（現在 30×36）；世界寬度不變可省下相機與 HUD 邊界的重調。
- 不新增 tile 樣式；`tile_style: "town_refresh"` 套整張。

## 6. 遠端要交付的東西

1. `docs/PHASE_9_FLAT_TOWN_PLAN.md`：地圖草案（ASCII 全文）、區段表、出生點、出口、NPC 站位、傳送門位置。
2. props 擺位表：每個 prop 的 texture、position、render_mode、collision_boxes、foot_inset、interact 大小；可直接轉成 `tide_root_town_props.json`。
3. 若需要新素材：只限「家庭屋一般立面」，其餘一律沿用（拱門已移除，不需要城門）。新素材照 `PHASE8_ART_ASSET_MANIFEST.json` 的格式進 manifest。
4. 交付到獨立分支 `codex/phase-9-flat-town`，基準為 `origin/phase-8-art-complete` 最新 commit；只改 docs 與 incoming，不改程式。

## 7. 本地 AI 的工作量估算（供排程）

| 工作 | 量 |
|---|---|
| 地圖與 props JSON 重排 | 半天 |
| tile_library 刪樹分支、圖例、builder 參數 | 半天 |
| 單元測試寫死座標（出生點 14,29、樓梯 13,22、出口 2,16 等）與 placement 測試 | 一天 |
| route test 317 步重走、六張版面截圖、11 張 golden 重拍 | 一天 |
| 文件（CURRENT_PROJECT_SPEC、RENDERING 規格、INDEX） | 半天 |

順序：遠端地圖規格 → 本地重排 → 才進 D-010 核心循環（NPC 站位依賴新地圖）。D-014 已定案。

## 8. 作者已回答（D-014，2026-09-09）

| 問題 | 答案 |
|---|---|
| 遊戲名「山海樹港」、主城名「潮根城」 | 保留 |
| 樹心（tree_heart，帶互動與事件） | 保留，作為城鎮地標 |
| 根拱門 | 整個移除，不留作城門 |
| 雲端樹冠路牌、雲 props | 全部移除 |
