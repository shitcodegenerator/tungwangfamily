"""validate_map 的規則模組（Phase 8.5-B）。

唯一入口仍是 tools/validate_map.py；這裡只放可獨立測試的純函式：
- common：讀檔、格子換算、碰撞封鎖格、BFS
- legend：ASCII 圖例（assets/maps/tile_legend.json）與 MAP-P006
- placement：MAP-P001～P005（碰撞對齊、保留格、互動站位、出入口、連通）
- render：MAP-P007（render_mode 宣告與一致性）
- allowlist：具理由與期限的例外
- content：對話、任務目標、世界事件（Phase 3～6 既有檢查）
"""
