# Phase 8.5 專案穩定化與返工降載計畫

日期：2026-09-07  
基準素材分支：`codex/phase-8-art-assets-v3`  
狀態：供本地 AI 在 Phase 8 素材接線完成後執行；完成前不進入 Phase 9 正式內容製作。

## 0. 這一階段要得到的結果

Phase 8.5 不是新的玩法 Phase，也不是再畫一批圖。它是一個短的工程穩定化關卡，目標是讓後續每次新增場景、NPC、家具或 TileMap 時，不再重複發生「路被封住、角色被遮掉、素材規格錯、文件互相矛盾」的返工。

執行順序固定為：

1. 先把本分支的 Phase 8 v3 素材接線、匯入並完成截圖驗收。
2. 接著完成本文件的 P0：擺放硬檢查、單一顯示層級規格、文件唯一真相。
3. 再補最小的美術交付與地圖圖例防護。
4. 通過 Phase 8.5 Gate 後，Phase 9 必須回到「可重複玩的正式核心循環」，不能繼續無限擴大純美術翻修。

本階段不新增正式劇情、正式 Boss 或新 NPC；需要人物與回憶內容時，仍須先詢問作者。

## 1. 本地 AI 回饋的處置決議

| # | 問題 | 判定 | 安排 |
|---:|---|---|---|
| 1 | 物件與碰撞靠手調，route test 才抓得到封路 | 高頻且高成本 | **P0**：把可判定的規則寫進 `validate_map.py`，route test 不再是第一道防線 |
| 2 | 素材反覆不符尺寸、方向、透明與 atlas 規格 | 已造成多次重出 | **P1，但先做最小 P0 preflight**：manifest 自動驗證；完整建置整併稍後做 |
| 3 | Y-sort、z_bias、foot_inset、碰撞深度互相代償 | 架構脆弱 | **P0**：只留一套正式顯示模型，其他用法視為錯誤或明列例外 |
| 4 | 43 份文件互相重疊，沒有唯一真相 | 會直接造成遠端／本地分岔 | **P0**：建立現行規格、索引與待決策表；歷史文件歸檔 |
| 5 | 測試檔過大、完整 route test 太慢、無視覺回歸 | 中期風險 | **P2**：先加快速 smoke gate，再逐步拆測試與加入小型 golden set |
| 6 | 五代素材 builder 疊加，無法可靠從零重建 | 中期風險 | **P2**：先做單一入口包住舊流程，再逐批遷移，不一次重寫 |
| 7 | 核心遊玩循環仍未正式化 | 最大產品方向風險 | **Phase 9 Gate**：穩定化後優先完成 15～20 分鐘正式垂直切片 |
| 8 | 地圖圖例分散，未知字元錯誤 fallback | 會持續產生破圖 | **P1**：建立單一圖例來源，未知字元在驗證時直接失敗 |

若只能先做三件，採用本地 AI 建議的第 1、3、4 項。第 7 項不塞進穩定化實作，但被提升為 Phase 9 的強制方向門檻；第 2、8 項則只先做足以阻止下一次錯圖的最小防護。

## 2. 執行段落

### 8.5-A：凍結基準與 Phase 8 接線

- 合併 `codex/phase-8-art-assets-v3`，不得重生四位主角、CC、阿嬤、船長或老龜。
- 依 `docs/PHASE_8_ART_ASSET_DELIVERY.md` 接線樹屋、根拱門、中層 atlas、上層填充包與 15 件船長房家具。
- 保留舊 texture 路徑作可回退版本；先換 texture，不順手移動 x／y、出口、event_id 或碰撞。
- 產生 Phase 8 計畫指定的截圖組，將它們當作後續顯示規則整理的基準。

通過條件：v3 圖片可匯入；樹屋門可進；根拱門可通行；船長房繩圈事件仍能觸發；上層不再出現星空 fallback 或透明破口。

### 8.5-B：物件擺放規則變成硬檢查（P0）

保留 `tools/validate_map.py` 作唯一入口；內部可拆成 `tools/validators/` 模組，但不要新增第二支功能重疊的地圖驗證器。

驗證器至少要加入以下代碼化規則，錯誤訊息必須包含 scene_id、物件 id、座標與修正方向：

| 規則代碼 | 硬檢查 |
|---|---|
| MAP-P001 | 需要貼格的大型建築、門與地圖結構，其碰撞頂端必須落在 32px 格線；既有不規則家具先由 audit 列出，再以具理由、具期限的 allowlist 過渡，不能靜默略過 |
| MAP-P002 | props collision 不得覆蓋 NPC 出生格、玩家返回點、傳送門落點或明列的 reserved tile |
| MAP-P003 | 每個可互動物件至少有一個相鄰可站格，而且該格必須能從場景出生點以 BFS 走到 |
| MAP-P004 | 每個出口與 return_position 都必須落在可走格；進出後不能出現在碰撞內 |
| MAP-P005 | 場景的必要節點（出生點、出口、主要互動點）之間保持連通；封路時在快速驗證即失敗 |
| MAP-P006 | 地圖使用的每個 ASCII 字元在該 tile_style 都有正式 mapping；未知字元不得回退成樹根牆 |
| MAP-P007 | 高度跨越多列且會與角色交錯的大型物件必須宣告正式 render_mode；未宣告就失敗 |

執行策略：先用 `--audit` 對現況列出例外，再修正或建立最小 allowlist；allowlist 每筆必須有 `id`、`reason`、`owner`、`expires_phase`。新物件不得新增永久例外。

必加回歸 fixture：

- 把家庭屋餐桌測試副本移到走道時，快速驗證必須非 0 結束並指出餐桌。
- 把互動物四周封住時，必須報 MAP-P003。
- 填入未知地圖字元時，必須報 MAP-P006，而不是顯示另一種 tile。
- NPC 出生點壓到碰撞時，必須報 MAP-P002。

### 8.5-C：單一顯示層級模型（P0）

顯示與碰撞各自只負責一件事。正式 render_mode 固定如下：

| render_mode | 適用物件 | 正式做法 | 禁止用法 |
|---|---|---|---|
| `ground` | 地板、道路、地毯、地面花紋 | TileMap 或固定背景層，不參與 Y-sort | 不用碰撞或 z_bias 修遮擋 |
| `back` | 牆、掛畫、窗、不可走到後方的立面 | 背景 props 層；必要碰撞只描述實體範圍 | 不把自立家具全部塞到角色後方 |
| `ysort` | 桌、櫃、箱、一般自立家具 | 底部中央原點＋Y-sort；碰撞只描述不可穿越的實體 footprint | 不用 `z_bias=-1` 補救角色被家具吞掉 |
| `split` | 根拱門、可走到下方／後方的高大樹冠 | base 與 canopy 共用同一底部中央錨點；base 有碰撞，canopy 無碰撞且在前景層 | 不用一張跨多列完整圖再反覆調 z_bias |

參數的唯一職責：

- `foot_inset`：只校準圖片的接地線，不負責修正遮擋。
- `z_bias`：只表達已核准的背景／前景層角色，不負責掩蓋碰撞錯誤。
- collision：只描述玩家不能進入的實體 footprint，不為了看起來正確而任意放大到整張圖片。
- Y-sort：只根據接地點決定一般自立物件與角色的前後。

Phase 8 物件的正式分類：

- 共享家庭樹屋：`back`，176×96，`foot_inset=16`，不改門與返回點。
- 根拱門：`split`，base／canopy 同錨點，只有 base 保留兩腳碰撞。
- 船長房自立家具：`ysort`；牆上物件與地毯：`back` 或 `ground`；不統一加 `z_bias=-1`。
- 角色陰影仍是角色場景第一個子節點，固定地面錨點，不進入任何 props 顯示補救。

需要新增一份 `docs/RENDERING_AND_PLACEMENT_SPEC.md`，內容只描述現行規則與實例；之後所有場景教學只連到它，不再各自複製一套層級說明。

### 8.5-D：文件唯一真相（P0）

建立下列三個入口：

1. `docs/CURRENT_PROJECT_SPEC.md`：唯一現行規格，整合 AGENTS、內容邊界、資料 schema、render_mode、地圖圖例、素材與測試命令。
2. `docs/INDEX.md`：分成「現在必讀」「作者教學」「歷史歸檔」，每個主題只能指定一份現行文件。
3. `docs/OPEN_DECISIONS.md`：每筆只有 id、問題、負責人、狀態、決定日期與最終結論，不再把待確認事項複製到每份 Phase 報告。

`AGENTS.md` 改成短入口與不可變原則，不再累積每個 Phase 的完整歷史。舊 Phase 文件先移到 `docs/archive/phase_xx/` 或在檔頭標記 ARCHIVED；移動前先更新連結，不刪除歷史內容。

以下三項不再列為未決：

- 樹屋第 18 列：採 v3 176×96、門檻 y=80、`foot_inset=16`。
- 根拱門第 21 列：採 v3 base／canopy 拆層。
- 日誌輸入：方向鍵保留角色移動；捲動用滾輪，`<`／`>` 翻頁，每次打開回頂端。

從 Phase 9 起，不再固定產生「計畫＋提示詞＋報告」三份重疊文件；每個 Phase 只保留一份主文件，內含 Plan、Implementation、Verification、Remaining 四節。

### 8.5-E：美術與圖例的最小防護（P1，緊接 P0）

新增 manifest 驗證入口（可併入現有工具），對每張交付 PNG 自動檢查：

- PNG signature、IHDR 尺寸、RGBA／透明背景、SHA-256。
- atlas 實際欄列、格尺寸、無 gutter／格框、邊緣接縫亮度。
- sprite sheet 的方向列序、幀數與每格尺寸；方向語意仍需輸出 contact sheet 供人工確認。
- source 檔只能在 `assets/reference/incoming/`；runtime 目錄不得出現 SVG／PSD／Pixquare 或帶背景的參考大圖。
- manifest 宣稱與實際檔不一致時直接失敗。

地圖圖例改為一個宣告式來源，例如 `assets/maps/tile_legend.json`，由 TileLibrary 與驗證器共同讀取。若目前不宜立即資料化，至少先在一個程式模組定義並讓驗證器引用，不得維持兩套手寫 mapping。Phase 8 的 `.`、`c`、`T` 必須在上層套用前有明確 refresh mapping。

### 8.5-F：測試與素材建置降載（P2，不阻塞 P0 合併）

先建立單一跨平台入口：

- `python3 tools/verify_phase.py --fast`：PNG／manifest、map placement、圖例、拆分後的 unit smoke，目標在一般開發回合可頻繁執行。
- `python3 tools/verify_phase.py --full`：先 import，再跑完整 unit、route test 與指定截圖；每次合併 Phase 前必跑。
- `python3 tools/build_assets.py --clean --verify`：用暫存輸出包住現有五代 builder，從零重建後驗證；第一版可呼叫舊腳本，不要求立刻重寫 1,700 行。

測試拆分採漸進式：舊 runner 保留，只把新測試依 placement、rendering、events、save、battle 分檔註冊。不得在同一 Phase 全面改寫測試框架。

視覺回歸只保留 8～12 張具代表性的 golden screenshots 在 git；每次 route test 的大量輸出改放未追蹤的 artifacts 目錄或 CI artifact。現有 51MB 歷史截圖暫不改寫 git history，也不在這一階段做 Git LFS 歷史遷移。

## 3. Phase 8.5 Gate

只有以下項目全部成立才可開始 Phase 9：

- Phase 8 v3 素材全部接線，指定截圖人工看過，沒有破圖、白線、黑洞、烙底色或角色遮罩。
- `validate_map.py` 能在快速模式抓到封路、不可達互動點、出生點碰撞、未知圖例與未宣告高大物件。
- 所有現役 props 能對應到 `ground`／`back`／`ysort`／`split` 之一；不存在用四個旋鈕互相補救但無文件的物件。
- `CURRENT_PROJECT_SPEC.md`、`INDEX.md`、`OPEN_DECISIONS.md` 存在，AGENTS 能指向唯一現行規格。
- `--fast` 驗證可在平常修改後執行；`--full` 在合併前通過並印出 PASS。
- 報告列出所有 allowlist 例外；不能只寫「測試通過」。

## 4. Phase 9 的產品方向門檻

Phase 9 不再先做另一輪廣泛美術翻修。第一個目標是完成一段約 15～20 分鐘、可以從早晨玩到回家休息並進入隔天的正式垂直切片：

`共享家庭屋醒來 → 主城互動／接任務 → 外出或特殊遭遇 → 獎勵與 CC 隊伍價值 → 回家休息 → 每日重置`。

這裡只定結構，不自行決定正式劇情。開始前必須向作者確認：本段要採用哪一段成長回憶、使用哪位真實人物作 NPC 原型、情緒落點，以及既有 CC／炸物魔王內容哪些要升格為正式內容。所有新 NPC 仍遵守「先問人物個性、外型、特質，再設計功能」。

## 5. 本階段禁止事項

- 不重生或改造四位主角與既有 NPC／CC。
- 不自行新增正式家庭劇情、父親離世演出、新 Boss 或新 NPC。
- 不用 shader 掩蓋缺圖、碰撞或遮擋。
- 不為了整理文件刪除歷史內容或重寫 git history。
- 不一次重寫所有 builder、測試或 TownProp；先建立防護與單一入口，再漸進遷移。
- 不以 route test PASS 取代人工截圖；也不以人工看起來正常取代硬驗證。

## 6. 本地 AI 回報格式

完成後請逐項回報：

1. **已完成**：依 8.5-A～F 分段列檔案與 commit。
2. **驗證**：列 `--fast`、unit、完整 route、截圖 QA 的命令、耗時與結果。
3. **例外**：每一筆 allowlist 的 id、原因、到期 Phase。
4. **未完成**：明確標出阻塞原因，不把規劃項目寫成已完成。
5. **Phase 9 前需作者回答**：只列內容設計問題，不自行補正式回憶或人物。
