# Phase 8 v3 美術素材交付

日期：2026-09-07  
基準：`origin/phase-8-art-complete@31d898c958a530d145893a945844947e455ac512`  
交付分支：`codex/phase-8-art-assets-v3`

本分支只加入 Phase 8 美術素材與盤點 manifest，不改四位主角、CC、阿嬤、船長、老龜，也不改正式劇情。舊素材保留，方便回退。房屋立面五張依 P8.0 判定為 KEEP，本批沒有強行重畫。

## 執行期素材與 SHA-256

| 路徑 | 尺寸 | SHA-256 |
|---|---:|---|
| assets/props/town_refresh/shared_family_treehouse_v3.png | 176×96 | 838c7b8cdedc813aa430ba95762d3c6a77e7e8fcdaf8ec82d7f0c9446d6e3148 |
| assets/props/town_refresh/root_archway_v3_base.png | 176×166 | 36c66c1e5c49ab7d85bdd646656ddff303371cb941705072d8790be3fec45ff5 |
| assets/props/town_refresh/root_archway_v3_canopy.png | 176×166 | 7baf6209e3874c4fc001c40fbd9d2aa1c7db7c4485baae55a67cf4a54342fbcb |
| assets/tilesets/town_visual_refresh_tiles_32_v3.png | 256×128 | 9d34655b04239ad2767c58b7f8532e9f5d46eea7300ba5ef0e9c6ea6ee6c4356 |
| assets/tilesets/upper_canopy_fill_tiles_32_v1.png | 256×128 | 4d99a9f7fa3ed6b499fe3ddcf8612084790a293a5c5e61a9e2ac163dbb24ea0b |
| assets/props/cap_chart_desk_v3.png | 178×120 | 608269e4140952d69bd878a63a7908b22c82aa1392ef4d4180003bf15637b440 |
| assets/props/cap_side_table_v3.png | 140×128 | 78cda2396a08ed32319117b744e00c06cf29317d14333701e46914384db3b779 |
| assets/props/cap_rod_rack_v3.png | 108×165 | 13cbcffe6734d42eac29f0300f0d52cbcf2c86aeb28d23c9f0029ce8493cbf3f |
| assets/props/cap_bookshelf_v3.png | 80×128 | dbc7f8c629b845978889dd073a1f1963e29923e5a469837f42e39266b09ef1e4 |
| assets/props/cap_chest_stack_v3.png | 102×98 | 881efc3a28d0b1b05414dea609f0b800d0f5c1c77005964fb3c5b47bb2263764 |
| assets/props/cap_fish_crate_v3.png | 102×98 | 4b8797446efbc8942e495bf83b9e2ec58a6e113c2311b668aff74900f07705b0 |
| assets/props/cap_coat_rack_v3.png | 65×115 | 0e4a03afefeea24cc1cba9b9e4371de916cd2fc193fa65420407457d7155e37a |
| assets/props/cap_chest_bench_v3.png | 52×70 | 8867d2ce5eb332ff14e601a598cfdd8cc37435182f97e8acf1a388cf9422de88 |
| assets/props/cap_barrel_v3.png | 40×48 | a02631ba5259fd99802a4a0bce10c650c156cb0915e195e0106403f7e7b7c707 |
| assets/props/cap_wall_map_v3.png | 102×78 | df4da1b97cc3b38f187b4d72c4d8470ecfd8108e01c274042ebc5f44ade39d9c |
| assets/props/cap_painting_v3.png | 48×40 | 3d9bc0ad736b8162d2e2ccdd80f7c4016a446881357de5bc92c192fae1be73e6 |
| assets/props/cap_porthole_v3.png | 72×78 | cefb1c7170607d90fa04c7b23fe49aac8bcebc36800102e09c38b04e576ed82f |
| assets/props/cap_hanging_lantern_v3.png | 45×78 | dd9bf53b1f49b395dc5e787d587e998cff4d0e7c84706c55177593ad9718f47f |
| assets/props/cap_rug_v3.png | 215×128 | c9a688fa20c0fb014a96b0ef5b35bc52e1eae3f4e5af8074721f214f7f960ab4 |
| assets/props/cap_rope_coil_v3.png | 55×40 | b69f1dff070b3f340b9040857d1dca24cfe1d121944fb156394149abae3df820 |

## 來源參考檔

來源只放在 `assets/reference/incoming/`，不會被 Godot 場景直接載入。

| 路徑 | 尺寸 | SHA-256 |
|---|---:|---|
| assets/reference/incoming/PHASE8_captain_room_furniture_v3_source.png | 1200×570 | 5947f89f387c4cf4e435b18b37339465a07c63bc2c5ef3063db52d0808203958 |
| assets/reference/incoming/PHASE8_root_archway_v3_source.png | 352×332 | ef6801bccbcf2daa09403325b95302f1f4f6126c3640b2112f349610b6ccadc2 |
| assets/reference/incoming/PHASE8_shared_family_treehouse_v3_source.png | 352×192 | e5e56a68921ed49631f13837fc1734fd974077d8107a7641918fcf6ea798c7f9 |
| assets/reference/incoming/PHASE8_town_visual_refresh_tiles_32_v3_source.png | 256×128 | 9d34655b04239ad2767c58b7f8532e9f5d46eea7300ba5ef0e9c6ea6ee6c4356 |
| assets/reference/incoming/PHASE8_upper_canopy_fill_pack_source.png | 256×128 | 4d99a9f7fa3ed6b499fe3ddcf8612084790a293a5c5e61a9e2ac163dbb24ea0b |

## 接線規格

### 樹屋

- 使用 `shared_family_treehouse_v3.png`，畫布 176×96。
- `y=80` 是門檻線；`y=80..95` 是 16px 踏墊。
- 保留原位置、碰撞與 `family_home_door` 傳送門；props 的 `foot_inset` 必須是 16。

### 根拱門

- `root_archway_v3_base.png` 與 `root_archway_v3_canopy.png` 都是 176×166，使用完全相同的底部中央錨點。
- base 才保留原本兩個 collision box；canopy 不設碰撞，`z_bias=1`。
- canopy 沒有地面／石板像素；不要把 base 與 canopy 疊成兩份完整拱門。

### 中層 atlas

- `town_visual_refresh_tiles_32_v3.png` 是乾淨 8×4 atlas，每格 32×32，保留 Phase 5 的既有欄列語意，只移除原本每格 2px 格框。
- builder 使用：
  
  `python3 tools/build_assets_phase5.py --atlas assets/tilesets/town_visual_refresh_tiles_32_v3.png --frame 0`

- 第一輪只套主城第 12～35 列；確認截圖沒有硬切與白線後，再考慮擴到第 0～35 列。

### 上層填充包

`upper_canopy_fill_tiles_32_v1.png` 是額外的 8×4、32px atlas，供 TileLibrary 補上層的 `.`、`c`、`T`：

| 區域 | atlas 格位 | 用途 |
|---|---|---|
| row 0, col 0–3 | 綠色樹冠填充 | `.` 的日間樹冠變體 |
| row 0, col 4–7 | 藍灰霧層填充 | `c` 的霧／雲變體 |
| row 1 | 下緣／過渡變體 | 有鄰居時選用 |
| row 2, col 0–3 | 根牆 | `T` 的根系牆變體 |
| row 2, col 4–7 | 根牆頂部變體 | 上緣或轉接 |
| row 3, col 0–3 | 雲層下緣 | 雲霧下緣 |
| row 3, col 4–7 | 根牆帽／苔痕變體 | 根牆上緣 |

不要在還沒有這三個分支前把 `tile_style_rows` 直接改成 [0,35]；先保留 [12,35] 做回歸。

### 船長房間家具

- 15 張全部使用 `cap_*_v3.png`，尺寸沿用 manifest；不要加 `z_bias=-1` 到自立家具，遮擋依現有加深碰撞處理。
- 牆上物件、地毯、舷窗仍依既有規則使用 `z_bias=-1`。
- `cap_porthole_v3.png` 保留 `captain_room_waterlight` shader。
- `cap_rope_coil_v3.png` 必須維持 55×40、原位置與 event target，不可因換圖移動事件。
- captain_room props 只替換 texture 欄位為 `cap_*_v3`，x、y、collision、event_id 維持 Phase 8 已修正值。

## 本地 AI 驗收順序

先在本地專案執行：

```bash
git fetch origin codex/phase-8-art-assets-v3
git merge --no-ff origin/codex/phase-8-art-assets-v3
godot --headless --path . --import
python3 tools/validate_map.py
godot --headless --path . -s res://tests/run_tests.gd
```

接線後至少做三組人工截圖：

1. 主城第 12～35 列：樹屋門檻、根拱門兩層與石板／草地邊界。
2. 主城第 0～11 列：白天不應再出現深藍星空虛空或缺口。
3. 船長房間：航海圖桌、船具架北側站位仍只遮到腳踝，繩圈事件仍找得到目標。

若接線後任何一組畫面變差，先只回退對應 v3 texture，不要刪除舊檔或重設分支。完成接線後再跑 route test；manifest 已包含本分支所有新增 PNG 的尺寸、alpha 與 SHA-256 盤點結果。

## 接線後的 Phase 8.5

本批素材本身已完成遠端 PNG signature、尺寸、RGBA 與 manifest SHA-256 驗證；本地仍需做 Godot import、實際接線與場景截圖，兩者不能互相取代。

接線與 Phase 8 截圖 QA 完成後，請不要直接開始新增內容。先讀並執行 [`PHASE_8_5_PROJECT_STABILIZATION_PLAN.md`](./PHASE_8_5_PROJECT_STABILIZATION_PLAN.md)。優先順序是：

1. 擺放與可達性硬驗證。
2. 單一 render_mode／遮擋規格。
3. 文件唯一真相。
4. 最小素材 preflight 與地圖圖例防護。

Phase 8.5 不會要求重畫本批角色或家具，也不會自行增加劇情；它的目的，是把本地 AI 回報的反覆返工原因變成工具與規則。
