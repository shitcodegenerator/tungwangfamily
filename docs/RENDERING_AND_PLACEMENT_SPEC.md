# 顯示層級與擺放規格（現行，Phase 8.5 起唯一版本）

這份文件只描述**現在的規則與實例**。場景教學、提示詞、報告一律連到這裡，不再各自複製一套層級說明。
規則被工具強制：`python3 tools/validate_map.py`（MAP-P001～P007）與 `tests/suites/rendering_tests.gd`。

## 1. 四種 render_mode（每個 props 必填）

| render_mode | 用在 | 畫法 | 碰撞 | 禁止 |
|---|---|---|---|---|
| `ground` | 地毯、池面、港口泊位、地面花紋 | z_index -1，角色永遠在它前面 | 不得有 | 不用碰撞或層級修遮擋 |
| `back` | 牆掛物（畫、地圖、舷窗、掛燈）、門、窗、雲、藤蔓、樹屋與房屋立面（角色走不到後方） | z_index -1 | 只描述實體（房屋立面 64、樹屋 150×64） | 不把自立家具塞到這裡 |
| `ysort` | 桌、櫃、箱、架、燈柱、柵欄、攤位、噴泉等自立物件 | 底部中央原點 Y-sort（z_index 0） | 只描述不可穿越的實體 footprint；高度 = 圖高 − 約 16，讓角色最多只被蓋到腳踝 | 不得用 `z_bias -1` 補救角色被吞掉 |
| `split` | 根拱門這類角色會走到後方／下方的高大物件 | `split_role: base`（Y-sort、有碰撞）＋ `split_role: canopy`（z_index 1、無碰撞），兩筆 props 同 x／y／foot_inset | 只在 base | 不用一張完整圖反覆調層級 |

`z_bias` 欄位已退役：資料檔裡不得再出現，顯示層級只由 `render_mode` 決定（`TownWorld.z_index_for`）。

## 2. 每個參數只做一件事

| 參數 | 唯一職責 | 不負責 |
|---|---|---|
| `x`、`y` | 接地點（底部中央）的世界座標 | 不為了躲圖片移動 |
| `foot_x` | 接地點距圖片左緣幾 px（圖片不對稱時） | 層級 |
| `foot_inset` | 接地線距圖片底緣幾 px（圖片底部畫了地面、踏墊、石板） | 修遮擋 |
| `collision` `[寬, 高]`／`collision_boxes` `[[寬, 高, dx, dy]…]` | 玩家不能進入的實體 footprint | 不為了看起來正確放大到整張圖 |
| `render_mode`（＋`split_role`） | 顯示層級 | 碰撞 |
| Y-sort | 只依接地點決定一般自立物件與角色的前後 | — |
| 角色 `Shadow` | 角色場景第一個子節點、固定地面錨點 | 不進任何 props 補救 |

## 3. 幾何事實（決定數值前先算）

- 格子 32px；角色原點在格子中央：`tile_to_world(x, y) = (x·32+16, y·32+16)`。角色碰撞盒 18×10、盒頂 = 原點 − 10。
- 角色貼圖 48×64，腳底在貼圖 y=61；站在第 N 列時頭頂約在 `N·32 + 16 − 61`。
- props 碰撞盒登記封鎖格的規則（`TownWorld._register_prop_blocking`）：碰撞矩形內縮 1px 後**任何相交的格子整格封鎖**。
  所以碰撞頂端 `y − 高` 必須落在 32 的倍數（MAP-P001），否則多出的幾 px 會把整列封掉、路徑規劃與實體碰撞不一致。
- 互動區 = `collision` ＋ padding (24, 28)，底邊固定在原點 +4；`interact_size` 可覆寫。
- 傳送門觸發只看領頭者；門口格中心與傳送門底緣只差 1px（route test 用 `_walk_to_door` 往南偏 6px 再按上）。

## 4. 驗證器規則代碼

| 代碼 | 規則 | 修正方向 |
|---|---|---|
| MAP-P001 | 高度 ≥ 32 的碰撞頂端在 32 格線 | 驗證器會給兩個候選高度；伸進去那列若有站位就選「少封一列」 |
| MAP-P002 | 碰撞不覆蓋 NPC 站位、出生點、入口、出口、傳送門返回點、投擲物、Boss 生成點、`reserved_tiles` | 縮碰撞或移物件，不移出生點 |
| MAP-P003 | 互動物件有可站且可達的站位（NPC：面前與左右；物件：自身／四方／南二格） | 空出站位 |
| MAP-P004 | 出生點、入口、出口、連接點、傳送門站位與返回點、投擲物都在可站格；地圖邊界封鎖 | 改座標或縮碰撞 |
| MAP-P005 | 出生點到每個必要節點連通 | `--audit` 列出封路的 props |
| MAP-P006 | 地圖字元都在 `assets/maps/tile_legend.json`，且該 tile_style 有正式 mapping | 先登錄再對應，不得退回樹根牆 |
| MAP-P007 | 每個 props 宣告 render_mode 且與碰撞一致；split 成對同錨點 | 依第 1 節分類 |
| MAP-A001／A002 | allowlist 條目缺欄位、到期、或已無對應違規 | 修資料後刪除 |

例外只能寫在 `assets/maps/validation_allowlist.json`（id、rule、scene、subject、reason、owner、expires_phase），到期自動失效。目前 0 筆。

## 5. 現役實例

| 物件 | render_mode | 關鍵數值 | 為什麼 |
|---|---|---|---|
| 共享家庭樹屋 v3（176×96） | back | (144,672)、foot_inset 16、collision 150×64 | 最下 16px 是踏墊畫在接地線以下；頂端 y=592 剛好是第 18 列角色原點，不蓋第 16～17 列街道 |
| 根拱門 v3（176×166 ×2） | split | (480,762)、foot_inset 38、base 兩腳 [49,58,-57,0] [57,58,62,0]、canopy 無碰撞 | 隊伍要從拱門下穿過；base 石板在腳下、樹冠在頭上。站在正北第 21 列時身體會被樹冠遮（作者接受） |
| 五棟房屋立面 | back | collision 高 64 | 角色走不到後方 |
| 船長房自立家具 ×9（v3） | ysort | 碰撞高 = 對齊格線的「圖高 − 約 16」 | 站北側只被蓋到腳踝 |
| 船長房牆掛物 ×4 | back | 無碰撞 | 牆上 |
| 地毯、池面、泊位 | ground | 無碰撞 | 地面 |
| 繩圈（事件目標） | ysort | 55×40、(176,176)、無碰撞 | 事件會移動它；位置在書櫃與航海圖桌之間的空地 |
| 雲、樹心、藤蔓、上層樹台 | back | 無碰撞 | 遠景 |

## 6. 新增或調整物件的固定流程

1. 決定 render_mode（第 1 節）。自立物件先量圖高，碰撞高取「圖高 − 16」後**再往上對齊到 32 格線**（`validate_map --audit` 會算給你）。
2. 寫進 props JSON：`texture`、`render_mode`、`x`、`y`、`collision`（或 `null`）、必要時 `foot_x`／`foot_inset`／`split_role`。
3. `python3 tools/verify_phase.py --fast`：素材 preflight ＋ 地圖硬檢查 ＋ 夾具 ＋ 單元測試。
4. `--snapshot` 截圖看接地與遮擋；大型物件另外從北側、南側、穿越三個角度看。
5. 合併前 `python3 tools/verify_phase.py --full`（含 route test）。
