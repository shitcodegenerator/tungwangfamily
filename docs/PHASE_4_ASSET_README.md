# Phase 4 素材包說明

## 素材位置

本階段素材放在 `assets/reference/incoming/`，全部都是參考／切割來源，不覆蓋 Phase 1～3 正式資源。

## 素材清單

| 檔案 | 用途 | 預期處理 |
|---|---|---|
| `BOSS_fried_food_demon_sheet_reference.png` | 戴王冠炸全雞 Boss | 切出待機、移動、攻擊、受擊、倒地等姿勢；先作方向與動畫參考 |
| `CC_pet_penguin_sheet_reference.png` | CC 非戰鬥寵物 | 5 欄 × 4 列方向／待機／行走參考；依專案規格整理 |
| `GRANDMA_turtle_breakfast_sheet_reference.png` | 阿嬤早餐攤 NPC | 圍裙、花格子頭巾、念珠和早餐籃；如現有素材已符合，可只補配件 |
| `ITEM_throwables_vegetable_tea_water_reference.png` | 青菜、綠茶、水 | 三列物品參考；切成地面、舉起、飛行和命中特效 |
| `ACTION_big_brother_carry_throw_reference.png` | 哥哥行動參考 | 4 方向 × 4 動作欄；整理成 48×64 格 |
| `ACTION_calm_brother_carry_throw_reference.png` | 冷靜哥行動參考 | 4 方向 × 4 動作欄；整理成 48×64 格 |
| `ACTION_sister_carry_throw_reference.png` | 妹妹行動參考 | 4 方向 × 4 動作欄；整理成 48×64 格 |
| `ACTION_younger_brother_carry_throw_reference.png` | 弟弟行動參考 | 4 方向 × 4 動作欄；整理成 48×64 格 |
| `CAVE_fried_food_demon_arena_reference.png` | Boss 洞窟布局 | 不直接當地圖，使用 32×32 tiles 重建可走與可碰撞場景 |
| `FX_cc_battle_reference.png` | 傳送、投擲、命中、炸雞翅、勝利效果 | 依需求切成獨立特效或重新用程式粒子整理 |

## 重要提醒

- 生成圖可能包含非一致的單格間距、邊緣像素或背景殘留，不能直接假設是正式 Sprite sheet。
- 角色正式資源目標單格為 48×64，腳底需對齊同一條接地線。
- 物品不應畫進角色 Sprite；請使用 `CarryAnchor` 以節點方式掛載。
- Boss 素材是參考圖，若背景或光暈無法乾淨移除，請重新切割或重繪，不要把黑底／棋盤格當成遊戲背景。
- 洞窟圖只作構圖參考：中央要保持連續可走空間，物品放置點要能被玩家到達，傳送落點不能與障礙重疊。
- 正式匯入 PNG 後先執行 Godot import，再做 headless 與手動測試，避免使用舊 `.godot/imported` 快取。
