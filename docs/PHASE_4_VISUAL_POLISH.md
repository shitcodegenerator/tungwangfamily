# Phase 4 視覺修正版：投擲物與洞窟參考

## 目的

依照 Phase 4 實際錄影檢視結果，先處理最影響可讀性的素材問題：

- 青菜、綠茶、水在洞窟中放大後要能在移動中辨識。
- 補上遺失的 D3 洞窟構圖參考，讓目前的單一棕色測試場有正式美術方向。
- 保留既有戰鬥資料結構、傷害規則、碰撞格與任務流程。

## 本分支內容

| 類型 | 路徑 | 規格 |
|---|---|---|
| 投擲物參考表 | `assets/reference/incoming/ITEM_throwables_vegetable_tea_water_reference_v2.png` | 448×336；4 欄 × 3 列；每個邏輯格 112×112，對應 4×3 件素材 |
| 洞窟參考圖 | `assets/reference/incoming/CAVE_fried_food_demon_arena_reference_v2.png` | 768×512；寬闊中央戰鬥區、三個道具區、岩壁、晶簇、入口 |
| 投擲物切割器 | `tools/build_assets_phase4.py` | 改用 v2 參考表；一般幀高度由 18 提高為 23 |
| 產出精靈表 | `assets/items/*.png` | 每件 112×28；4 幀：地面／舉起／飛行／命中 |

## 投擲物設計

四欄順序固定：

1. 地面拾取：大型清楚輪廓。
2. 舉起：以亮色邊緣和動作符號強化「可投擲」。
3. 飛行：保留斜向速度線，但不改傷害。
4. 命中：物件加上黃色閃光，代表命中。

三種物品仍然全部使用 `plain_damage`、傷害 1。素材放大只影響視覺，不改拾取碰撞範圍。

## 本地 AI 執行

請在拉取本分支後執行：

```bash
git checkout codex/phase-4-visual-polish
python3 tools/build_assets.py
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
```

如果本地工作樹已有未提交的場景調整，請先保留並在乾淨副本驗證素材，不要覆蓋作者的編輯器調整。

## 手動驗收

- 三種道具在洞窟中一眼可辨識，且不會互相黏連。
- 舉物時圖示不會遮住角色臉部或超出遊戲視窗。
- 飛行中的道具不會因放大而穿過牆壁。
- 第 1～4 次命中不提前結束，第 5 次命中才勝利。
- 三種物品的傷害仍相同。
- 炸雞翅仍是純視覺掉落，稍後消失，不會進背包。
- 戰敗、勝利都能回到 CC 旁邊。
- 洞窟 PNG 可由一般看圖軟體開啟，且使用 `file` 檢查時為合法 PNG。

## 尚未包含

本分支只處理素材與素材切割參數，以下項目保留給後續程式修正版：

- 四位角色在戰鬥中重疊時的隊形調整。
- Boss 與畫面上緣的安全距離。
- F5／休息進入下一天的正式每日系統。
- 對話框內使用圖像取代系統字型 `💢` 的接線。

## 檔案驗證

PNG 的標準檔頭前 8 bytes 應為：

```text
89 50 4e 47 0d 0a 1a 0a
```

這次新增的參考圖均應在上傳前通過：

```bash
file assets/reference/incoming/ITEM_throwables_vegetable_tea_water_reference_v2.png
file assets/reference/incoming/CAVE_fried_food_demon_arena_reference_v2.png
```
