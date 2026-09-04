# Phase 4.6 分支補充：持物行走與投擲動畫

## 問題根因

目前舊版 `action_sheet` 是 2 欄格式：每個方向只有一張舉物姿勢與一張投擲姿勢。角色移動時仍顯示固定舉物姿勢，所以速度變快時只會看到整張角色平移，腳沒有真正交替。

這個分支不覆蓋舊版 `action_sheet`，而是提供新的兩組素材，讓本地 AI 可以明確區分「持物行走」和「一次性投擲」。

## 一致性規則

四位角色的正式外觀母版是：

```text
assets/characters/playable/<id>_walk_v2_sheet.png
```

所有持物、投擲、受擊和未來技能圖，都必須以這四張母版為唯一角色基準：

- 臉型、眼睛、髮型／羊毛／羽毛、服裝、配件、輪廓和主色不可重新詮釋。
- 不可以把舊版 action sheet 的角色外觀直接拼到新版 walk sheet 上。
- 不可以替角色增加提示詞沒有指定的新帽子、武器、背包或衣服。
- 手上物品由 `CarryAnchor` 或投射物節點疊加，角色動作表本身不畫青菜、綠茶或水。
- 每格腳底最後一列固定在 y=61，底下保留 2px；動作只能改變上半身、手臂、腿部和尾巴／圍巾的姿勢。

## A. 持物行走表

路徑：`assets/characters/playable/<id>_carry_walk_v2_sheet.png`

整張 192×256，單格 48×64，4 欄×4 列。

| 列 | 方向 |
|---:|---|
| 0 | down |
| 1 | left |
| 2 | right |
| 3 | up |

欄 0～3 是真正的四幀走路循環：contact A、passing A、contact B、passing B。雙手保持在胸前的持物姿勢，但左右腳要交替；因此 `CarryAnchor` 的物品會看起來被角色抱著一起移動，而不是角色滑過地面。

建議播放速度與一般行走一致，7～8 FPS。停止時顯示第 0 幀或切入對應 idle 表，不要停在單腳抬起的 passing 幀。

## B. 投擲表

路徑：`assets/characters/playable/<id>_throw_v2_sheet.png`

整張 144×256，單格 48×64，3 欄×4 列。

| 列 | 方向 |
|---:|---|
| 0 | down |
| 1 | left |
| 2 | right |
| 3 | up |

欄位是一次性投擲動作：

1. `windup`：雙手收在胸前，物品仍掛在 CarryAnchor。
2. `release`：手臂向面向方向伸出，這一幀把物品交給 ThrownProjectile。
3. `follow_through`：身體略微前傾，手臂收勢。

建議總長 0.25～0.30 秒，release 事件落在中間幀；投擲動畫期間暫停一般 walk／idle，不要讓 walk 動畫搶回 SpriteFrame。

## 建議程式資料接口

在 `CharacterData` 保留舊欄位作為相容 fallback，新增：

```gdscript
@export var carry_walk_sheet: Texture2D
@export var throw_sheet: Texture2D
```

動畫選擇優先序：

```text
throwing                  → throw_sheet
is_carrying && moving     → carry_walk_sheet
is_carrying && stationary → carry_walk_sheet 第 0 幀
moving                    → walk_v2_sheet
stationary                → idle_sheet
```

如果新欄位為空，才退回舊 `action_sheet` 或站立幀；不能因為舊欄位存在就優先使用舊動作表。

## 與 CarrySystem 的同步

- 撿起：切到 `carry_walk` 的第 0 幀，物品掛到 `CarryAnchor`。
- 持物移動：按照 facing 選列，按照 walk phase 選欄 0～3。
- 按 E 投擲：鎖定角色輸入與動畫，播放 `throw`。
- `release` 幀：移除 CarryAnchor 的物品，建立 ThrownProjectile。
- 投擲結束：回到同方向的 idle 或 walk；若投擲前仍有移動輸入，不要回到普通 walk 的第 0 幀造成跳幀。

## 驗收條件

- 四位角色持物走四方向時，都看得到腳步交替，不再是固定舉物姿勢滑行。
- 持物表和普通 walk 表的臉、髮型／羊毛／羽毛、衣服和色盤一致。
- 投擲三幀的角色比例與普通 walk 表一致；腳底、陰影和碰撞地面不跳動。
- 物品只在 release 幀由 CarryAnchor 交給投射物，不會複製成兩個。
- 切換操控角色後，新的 leader 能正確使用自己的 carry／throw 表；CC 仍不進入可切換角色。
- 四位角色各命中炸物魔王至少一次，原本五次命中才勝利、戰敗返回 CC、重新傳送流程全部通過。
- 不得以縮小角色、提高移動速度或關閉碰撞來掩蓋動畫不一致。
