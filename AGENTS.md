# AGENTS.md — 給 AI 協作者的入口

這是短入口，只放「先讀什麼」與「不可變原則」。完整現行規格在 **`docs/CURRENT_PROJECT_SPEC.md`**，
文件索引在 `docs/INDEX.md`，待作者決定的事在 `docs/OPEN_DECISIONS.md`。歷史 Phase 文件已歸檔到 `docs/archive/`，不要再更新它們。

## 先讀（依序）

1. `docs/CURRENT_PROJECT_SPEC.md` — 技術基準、內容邊界、責任分工、資料 schema、素材、驗證命令
2. `docs/PHASE_3_DECISIONS.md` — 內容邊界原文
3. `docs/RENDERING_AND_PLACEMENT_SPEC.md` — props 的 render_mode、碰撞與擺放規則（驗證器 MAP-P001～P007）
4. `docs/PRODUCTION_NOTES.md` — 踩過的坑與檢查清單
5. `docs/ART_STYLE_LOCK.md` — 素材規格
6. 目前 Phase 的主文件（見 `docs/INDEX.md`「現在必讀」）

## 不可變原則

- **內容邊界**：不得自創正式劇情、章節、Boss、父親離世演出、家庭傷痛、真實回憶；測試內容標 `TEMP_DEMO_CONTENT`。新 NPC 先問人物個性、外型、特質。CC 台詞短句＋「です」。
- **不重生角色**：四位主角、CC、阿嬤、船長、老龜的造型、ID 與貼圖路徑不改。
- **架構**：Godot 4.7、640×360、32px 格、無第三方 addon；主城是一張連續地圖；戰鬥邏輯只在 `scripts/battle/`；狀態只在 `GameState`；對話／任務／事件只在 `assets/*.json`；`PlayableCharacter` 不知道對話、任務、互動物件；`day` 只在 `advance_day()` 改。
- **擺放與層級**：每個 props 必填 `render_mode`（ground／back／ysort／split），`z_bias` 已退役；碰撞頂端對齊 32 格線；地圖字元只來自 `assets/maps/tile_legend.json`。驗證例外只能寫在 `assets/maps/validation_allowlist.json`，並有理由與到期 Phase。
- **素材**：執行期目錄只放 PNG；原檔放 `assets/reference/incoming/` 並更新 manifest（尺寸、alpha、SHA-256）；alpha 只用 0／255。改過 PNG 必 `godot --headless --path . --import`。
- **驗證**：平常 `python3 tools/verify_phase.py --fast`；合併前 `--full`。不以 route test PASS 取代人工看截圖，也不以人工看過取代硬驗證。
- **文件**：每個 Phase 一份主文件（Plan／Implementation／Verification／Remaining）；待確認事項只進 `docs/OPEN_DECISIONS.md`；規格變動改 `docs/CURRENT_PROJECT_SPEC.md`。
- **提交**：未被要求不 commit；要求時 `<type>: 中文描述` 並附 `Co-Authored-By` 與 `Claude-Session` 尾註。
