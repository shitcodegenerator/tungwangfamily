# 製作注意事項（Phase 1～5 踩過的坑與之後產出的檢查清單）

整理日期：2026-09-05。這份文件記錄實際發生過的問題與教訓，之後要新增角色、NPC、場景、對話、任務、Boss、道具、特效或 UI 時，先對照最後一節的檢查清單。

---

## A. 素材交付與切割

| # | 發生過的事 | 教訓 |
|---|---|---|
| A1 | Phase 4 分支上三個參考檔（妹妹行動表、洞窟、阿嬤）檔案大小都約 90060 bytes、開頭同一段亂碼，根本不是 PNG。 | 收到任何圖先用 `file` 或讀前 8 bytes（`89 50 4E 47 0D 0A 1A 0A`）確認。切割器對損毀檔會略過並印提示，不會靜默產出錯圖。同一批檔案大小完全一樣就是警訊。 |
| A2 | 阿嬤參考圖檔名叫 sheet，但內容是「四列相同、每列五種視角」，不是行走表。 | 檔名不代表內容。切割前先把圖看一遍：數列數、欄數、每列是否真的是連續動作。特殊排列要寫專門的重組流程並在文件註明。 |
| A3 | 行動表參考圖的列序是 down／right／left／up，專案是 down／left／right／up。 | 每張新表都要看臉朝哪邊再對應列序，不要信任「應該一樣」。切割器用 `ACTION_ROW_ORDER` 逐角色寫死。 |
| A4 | 作者 Downloads 的原圖與分支上的縮圖雜湊對不上（同一張圖，解析度不同）。 | 比對素材用尺寸與內容，不用雜湊。原圖優先，但 448 寬的圖切到 28px 已足夠，不必為了「原圖」重切。 |
| A5 | 遠端提交的投擲物 PNG 比本機切割器產出的糊（Pillow 版本重採樣差異）。 | 遊戲內 PNG 一律以本機 `tools/build_assets.py` 產出為準；遠端只交參考圖，不要交切好的正式圖（洞窟 tile 組、v2 行走表這類「正式檔」例外，但要在 manifest 標明）。 |
| A6 | Godot 執行期不會重新匯入改過的 PNG，Phase 3 因此看到舊圖。 | 重切素材後必跑 `godot --headless --path . --import`。route test 前也要跑。 |
| A7 | 單元測試逐像素比對 tileset 與 tile 組失敗：匯入時 `fix_alpha_border` 會改寫透明與半透明邊緣像素的 RGB。 | 像素比對只比 alpha ≥ 0.5 的實心像素；或改比「切割器輸入輸出」而不是匯入後的貼圖。 |
| A8 | 洞窟地面 tile 最右一欄比其他欄暗約 15 階，平鋪後整張地圖出現直向接縫。 | 收到可平鋪 tile 先算每欄、每列平均亮度，邊緣差 > 10 就要補平（切割器 `seamless_floor`）並回報遠端要求四邊無縫。 |
| A9 | 參考圖背景有白底、棋盤格、黑底、透明四種。 | 統一用「從四邊泛洪去除近白中性灰」（`key_out_checkerboard`），封閉在輪廓內的白色（骨頭、尾巴尖）會保留；輪廓有缺口時白色會漏掉，切完一定要看預覽圖。 |
| A10 | 炸物魔王棋盤格是烙在像素裡的，不是透明。 | 同 A9；另外要抽樣角落顏色判斷是哪種背景，不要假設。 |
| A11 | 新造型行動表的投擲幀伸手很寬，若依寬度縮放整個人會縮小到 44px，與行走幀不一致。 | 角色幀一律依「站立幀高度」縮放，寬度超出 48px 的手指由 `fit_sprite` 置中裁掉；身形一致比指尖完整重要。 |
| A12 | 遠端「依既有角色重生成」的 v2 行走表把冷靜哥變成貓頭鷹鳥形、弟弟變四足猴形，與 Phase 2 造型差很多。 | 「重生成」等於換造型。收到新表先貼對照圖給作者確認，舊表保留在 repo 供切回；所有配套（行動表、頭像、NPC 版本）都必須用同一造型，否則撿起物品那一瞬間會變回舊角色。 |
| A13 | 待機表把 1px 呼吸畫在幀裡，程式原本也有 VisualRoot 微晃動，疊加後會晃 2px、陰影也跟著飄。 | 呼吸只能由一方負責：有待機表就關程式晃動。任何「視覺動畫」都不得移動碰撞盒、地面錨點與陰影。 |
| A14 | 陰影依規格放在地面錨點 (0,0)，上半段被身體蓋住，畫面上很含蓄。 | 陰影要在遊戲截圖裡放大確認看得到；規格與視覺效果衝突時先照規格做，再在報告裡附截圖請作者決定。 |
| A15 | 素材檔名帶版本（`_v2`）但 manifest 只更新一半，舊檔仍在 incoming。 | 每次交付都更新 `PHASE*_ASSET_MANIFEST.json`，切割器以 manifest 或明確常數指定來源，避免拿到舊檔。 |
| A16 | Phase 5 交付的「正式 atlas」每格帶 1px 亮框 + 1px 暗框（生成時的格框），3×3 平鋪馬上看到格線；manifest 卻寫「no intentional gutters」。 | 拿到 atlas 先量每格「外圈／次外圈／內圈」亮度（`ring_brightness`），差 > 10 就是格框；用 `deframe`（取內部 28×28、外圈鏡射補回）修正並寫進單元測試。manifest 的描述不等於實際。 |
| A17 | 同一批 edge／corner tile 裡 `_s`、`_sw`、`_se` 六格畫成與 `_n`、`_nw`、`_ne` 同向；一格 corner 還是反向的內凹角。 | 方向類 tile 逐格用像素統計（各邊、各象限的綠色比例）判定方向，不信檔名；缺的方向用翻轉補（並在 ASSET_REQUEST 要求重出）。 |
| A18 | 交付的橋面是南北向，地圖上的橋是東西向。 | 需要方向的 tile 在需求單寫明「走向」；本機可旋轉 90° 再合成上列／下列。 |
| A19 | 大型 props（144～176px）比原本 3 列高的門口空間大，屋頂會蓋到後面的街道；燈籠的燈柱不在貼圖中央。 | 大型 props 先用 `--snapshot` 工具在遊戲裡截圖看 Y-sort，再決定位置；用 `foot_x`／`foot_inset` 指定接地點，不要為了對齊去改地圖。無法解的遮擋寫進報告請作者決定。 |

## B. 程式與架構

| # | 發生過的事 | 教訓 |
|---|---|---|
| B1 | 跟隨者「領頭者尚未移動就回傳零向量」的早期 return 擋掉了新加的分離邏輯，返回主城時四人仍疊在同一點。 | 在既有 guard 之前加新行為時，要檢查每個 early return 是否吞掉它；用截圖或 route test 驗證，不要只信單元測試。 |
| B2 | Boss 在 MOVE 狀態會走到上牆邊，頭被地圖上緣裁掉。 | 任何會移動的大型物件都要有活動邊界（`min_y`）並寫進 `validate_map.py`；生成點與邊界都要離可走區邊緣 ≥ 2 格。 |
| B3 | Battle HUD 的 Boss 血條和任務目標 label 重疊。 | 新 UI 一律先在 640×360 截圖確認四個角落沒有和既有 HUD 打架；HUD 佔位寫進 `docs/MANUAL_TEST_GUIDE.md`。 |
| B4 | 對話框的 💢 靠 macOS 系統字型備援，其他平台會是空框。 | UI 不依賴 emoji；圖示用貼圖，內文用 RichTextLabel bbcode `[img]`。轉 bbcode 時方括號要先用暫存字元跳脫，否則 `[lb]` 補上的 `]` 會被第二次取代吃掉（實際發生過）。 |
| B5 | GDScript typed array：`party.order.has(party.pet)` 型別不符直接報錯。 | 跨型別比對用 id（`order_ids().has("cc_penguin")`），不要拿節點比。 |
| B6 | route test 寫死「弟弟 124、哥哥 96」，改速度後測試就壞。 | 測試比「關係」不比「數值」：`younger > big`、`big == data.walk_speed`。素材尺寸、幀數這類規格才寫死。 |
| B7 | 單元測試寫死主城互動物件數量 6，加了阿嬤與 CC 後變 8。 | 數量類斷言改成「≥ 舊值」或從資料檔算出來；新增 NPC／道具時記得跑單元測試。 |
| B8 | 舊的 CC 對話測試因任務狀態不對而失敗。 | 每個對話測試用全新的 `QuestManager`／`GameState`，不要共用前一個測試的狀態。 |
| B9 | 模擬按鍵：移動用 `Input.action_press` 有效，但 E／F5／J／方向鍵選項一定要 `Input.parse_input_event(InputEventAction)`，否則 `_unhandled_input` 收不到。 | 寫新的 route test 步驟時照 `_tap_action` 與 `_press_only` 兩個 helper 用，不要自己呼叫 Input。 |
| B10 | 螢幕休眠或視窗被遮時 Godot 停止繪製，route test 截圖是舊畫面、`frame_post_draw` 永遠等不到。 | route test 必須 `caffeinate -dis` + `--always-on-top` + `RenderingServer.force_draw(true)`；等待用 `process_frame`。 |
| B11 | route test 每次重跑會重寫全部 20 張截圖，git diff 很吵。 | 只有畫面真的改變時才一起 commit 截圖；純邏輯改動用 `git checkout -- docs/screenshots` 還原無關的。 |
| B12 | 洞窟出生點四格相鄰（32px），角色寬 46px，抵達時互相遮住。 | 出生點與傳送落點至少間隔 2 格（64px）；`validate_map.py` 會檢查可站與可達，但不檢查間距，要自己看。 |
| B13 | Phase 4 的 `legend_overrides` 只能做「字元 → 單一 tile」，正式洞窟需要依鄰居選 tile。 | 需要鄰居判斷的地形用 `tile_style` 走專門函式（`cave_atlas_for`），不要把規則塞進 JSON。 |
| B14 | 戰鬥暫態（Boss 血、玩家血、手上物品）一度差點進存檔。 | 暫態不進 `GameState`；轉場開始就清空。schema 變更才升 `SCHEMA_VERSION` 並寫 v(n-1) 遷移與測試。 |
| B15 | 單元測試比 JSON 讀進來的陣列 `== [23, 35]` 失敗：JSON 數字是 float。 | 比對 JSON 數值先 `int()`；像素比對用「綠色優勢 g - r」而不是單一通道（石板與草的 g 值幾乎一樣）。 |
| B16 | route test 把角色推到流理台前後，腳落在道具封鎖格裡，BFS 找不到起點。 | 推牆／推道具後先 `_push_for` 反方向 0.25 秒再 `_walk_to`。 |
| B17 | 舊測試寫死「版本 3 存檔被拒絕」「schema 為 2」，升 v3 就壞。 | 版本斷言用 `SCHEMA_VERSION + 1`／`SCHEMA_VERSION`，不寫數字。 |
| B18 | 每日系統很容易把 day 散到多處（切場景、讀檔、F5）。 | day 只在 `advance_day()` 改，而且只由休息流程呼叫一次；用 `_resting` 旗標擋重複觸發；route test 在轉場中故意重複呼叫確認只加 1。 |

## C. 流程與協作

| # | 發生過的事 | 教訓 |
|---|---|---|
| C1 | Phase 4.6 分支從舊一個 commit 長出來，無法 fast-forward。 | 拉遠端分支先 `git merge-base`；分歧就正常合併並確認檔案不重疊。請遠端每次開分支前先 `git pull origin master`。 |
| C2 | 遠端與本機都會改 `docs/ASSET_REQUEST.md`、manifest，容易衝突。 | 遠端只改 `assets/reference/incoming/`、manifest 與自己的規劃文件；本機負責 `docs/*_REPORT.md`、`ASSET_REQUEST.md`、程式與測試。 |
| C3 | 遠端交付訊息說「本階段包含 X」，實際分支內容有時多、有時少（例如 4.5 分支自己改了切割參數並提交了產出 PNG）。 | 拉下來先 `git diff --stat`，逐項對照訊息；產出 PNG 一律本機重切覆蓋。 |
| C4 | 使用者要求：未要求不 commit；要求時訊息格式 `<type>: 中文描述` + Co-Authored-By 與 Claude-Session 尾註。 | 做完先回報再等指示；「先提交我再跟他說」代表 commit + push 兩步都做。 |
| C5 | 每次修改後三道驗證缺一不可：`validate_map.py` → `run_tests.gd` → `--route-test`。 | 順序固定；route test 約 5 分鐘會開視窗，使用者說「可以停止測試」就不再跑，改用單元測試與預覽圖確認。 |
| C6 | 內容邊界（`docs/PHASE_3_DECISIONS.md`）：不得自創正式劇情、Boss 設定、家庭傷痛、真實回憶；CC 台詞短句 + です；測試內容標 `TEMP_DEMO_CONTENT`。 | 任何對話、任務、NPC 文字都是「功能性佔位」，等作者素材才定案。不確定就用最平淡的句子。 |

---

## D. 之後要產出內容時的檢查清單

### D1 新角色／NPC／寵物精靈表
1. `file` 確認 PNG；看圖數列數與欄數；確認每列的臉朝向並對應 down／left／right／up。
2. 決定規格：主角 = 行走表 192×256（4 幀，contact A／passing A／contact B／passing B）+ 待機表 192×256；NPC／寵物 = 240×256（第 0 欄站立、第 1～4 欄行走）。腳底一律 y=61、底部留 2px。
3. 切割後跑 `tests/run_tests.gd`：每方向 0≠2、1≠3；alpha 下緣 = 62；待機幀 61～63。
4. 拼一張「新表 vs 舊表」對照圖給作者確認造型，再決定要不要換；舊表不要刪。
5. 配套一起換：行動表、頭像、任何用到同一角色的貼圖。
6. `.tres` 只改 `sprite_sheet`／`idle_sheet`／`action_sheet`；碰撞盒 18×10 不因造型變。
7. 陰影：主角與 NPC 用 `character_shadow.png`，寵物用 `pet_shadow.png`，節點是第一個子節點、位置 (0,0)。

### D2 新場景／地圖
1. ASCII 地圖 + props JSON + dialogue JSON + `scenes.json` 登錄，一次到位；`validate_map.py` 會檢查出生點、互動點、道具、投擲物、Boss 的可站與可達。
2. 出生點與落點彼此間隔 ≥ 2 格；有 Boss 的場景加 `battle.min_y`，離最上方可走列 ≥ 2 格。
3. 需要依鄰居選 tile 的地形加 `tile_style`，在 `TileLibrary` 寫專門函式；只換單一 tile 用 `legend_overrides`。
4. 新 tile 組先量邊緣亮度，再放進 tileset 空列（目前第 5 列用到第 7 欄、第 6～7 列用到第 17 欄；第 5 列第 8～17 欄與第 8 列起可用；`ATLAS_ROWS` 要同步改切割器與 `TileLibrary`）。
5. 室內場景 `dark_wall_last_row = -1`、`outdoor = false`。
6. route test 至少走到一次並截圖；截圖檔名接續編號（目前到 24）。

### D3 對話／任務
1. 對話只放 `assets/dialogue/<scene>.json`，用版本陣列 + `requires`（flags／not_flags／items／quest／quest_objective）+ `on_complete`；分支只用 `choice`。
2. 任務放 `assets/quests/*.json`（全部自動載入）；目標種類只有 `interact`、`enter_scene`、`event`。
3. CC 台詞短句、句尾「です」，其他角色不套用；測試內容前綴 `demo_` 或標 `TEMP_DEMO_CONTENT`。
4. 不寫正式劇情、回憶、Boss 對白、家庭事件；炸物魔王只能搞笑。
5. 表情符號改用貼圖：對話框內文會把 💢 換成 `anger_mark.png`，其他符號要先加對應圖與 `to_bbcode` 規則。
6. 每個新對話寫單元測試：用新的 `GameState`／`QuestManager`，驗證版本選擇與 `on_complete`。

### D4 道具／投擲物／特效
1. 投擲物 4 幀（地面／舉起／飛行／命中）112×28，一般幀主體 23px；登錄在 `assets/items/throwables.json`，傷害維持 1、`plain_damage`。
2. 道具 JSON `items` 的位置必須可站可達；落地重生位置由程式截到牆前。
3. 特效由切割器切成單張貼圖，播放用 `EffectSprite.spawn`；不做粒子以外的持續動畫。
4. 舉物時道具掛在 `VisualRoot/CarryAnchor` (0,-60)，換造型後要看截圖確認不擋臉。

### D5 Boss／戰鬥
1. 邏輯只能在 `scripts/battle/`；主城、CC、道具、角色腳本不得知道戰鬥存在。
2. 狀態機只發 signal，接線在 `BattleDirector`；暫態不進存檔。
3. 生成點、`min_y`、hurtbox 大小都寫進 `scenes.json` 的 `battle`，並在 `validate_map.py` 加檢查。
4. 不加小怪、等級、裝備、技能樹。

### D6 UI／HUD
1. 字型 Fusion Pixel 12px，字級用 12 的倍數；不用 emoji。
2. 新 HUD 先畫在 640×360 截圖上確認不與愛心 (10,8)、Boss 血條 (6,22)、天數面板（上方中央 y 6～30）、任務目標（右上）、置中提示（y 40）、除錯列（下方）重疊。
3. Label 換 RichTextLabel 時記得 `bbcode_enabled`、`scroll_active = false`、字色用 `default_color`、字級用 `normal_font_size`。

### D6.5 大型 props 與新 atlas（Phase 5 起）
1. atlas：`file` 確認 PNG → 量每格外圈／內圈亮度 → 逐格用像素統計判方向 → 進 `tools/build_assets_phase5.py`（或新 phase 的切割器）→ tileset 空列 → `TileLibrary` 常數 + 鄰接函式 + 單元測試（無格線、方向、鄰接例子）。
2. 新樣式一律用 `tile_style` + `tile_style_rows` 先套一個區域，ASCII 與碰撞不動，跑 `validate_map.py` 確認可走性沒變。
3. props：先在 `assets/maps/*_props.json` 放進去，用 `--snapshot` 截圖看接地、Y-sort、與 NPC／出生點／路線的關係；碰撞盒不超出貼圖、留出通道；燈籠用 `foot_x`＋`glow_x`；有地面的物件用 `foot_inset`；多腳物件用 `collision_boxes`。
4. 大型物件會遮到北邊的走道是 Y-sort 的正常結果，不要切碎片、不要改 z_index；寫進報告請作者決定要縮圖還是移位置。

### D7 每次收工
1. `godot --headless --path . --import`（改過素材時）。
2. `python3 tools/validate_map.py` → `godot --headless --path . -s res://tests/run_tests.gd` → route test。
3. 看截圖：放大到 3 倍檢查陰影、接縫、重疊、裁切。
4. 寫 `docs/PHASE_*_REPORT.md`：驗收表、素材檢查、修改檔案、驗證數字、已知限制；更新 `AGENTS.md`、`README.md`、`MANUAL_TEST_GUIDE.md`、`ASSET_REQUEST.md`。
5. 不主動 commit；被要求時用 `<type>: 中文描述` 格式並附尾註。
