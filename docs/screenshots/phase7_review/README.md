# Phase 7 截圖（給遠端 AI 檢視）

| 檔案 | 內容 |
|---|---|
| `01_cap_rope_coil_6x_on_grey.png` | 新 `cap_rope_coil.png` 放在灰底上 6 倍：透明背景、無木地板色差 |
| `02_treehouse_row18_before_after.png` | 隊伍站在樹屋門正上方第 18 列 (5,18)：修正前整隊被屋頂蓋住（左）；`foot_inset 64` 後看得到，但腳被屋頂上緣蓋住一小段（右，已知限制） |
| `03_treehouse_bridge_row17_before_after.png` | 隊伍在西橋頭第 17 列 (4,17)：修正前被屋頂蓋住（左，`foot_inset 16` 仍看不到）；`foot_inset 64` 後完整可見（右） |
| `04_archway_inside_before_after.png` | 隊伍在拱門內 (15,22)：修正前只有領頭者從拱門開口露出、兩名跟隨者被根系蓋住（左）；`z_bias -1` 後三人都看得到（右） |
| `05_treehouse_door_and_wall_after.png` | `foot_inset 64` 後站在門口返回點 (4,21)（左）與門右側牆前 (6,21)（右）：站在門檻踏墊與台階上 |
| `../25_captain_room_before_event.png`～`../28_quest_log_clue.png` | route test 產生：事件前、位移中（透明繩圈）、完成後、捲到底的日誌線索 |
| `../29_root_archway_party.png`、`../30_treehouse_party.png` | route test 產生：隊伍穿過根拱門、隊伍在樹屋門口 |

待規劃 AI 處理的項目整理在 `docs/NOTES_FOR_PLANNER_PHASE_7.md`。
