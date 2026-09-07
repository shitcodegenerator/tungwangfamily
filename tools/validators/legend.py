"""ASCII 圖例（assets/maps/tile_legend.json）與 MAP-P006。"""
from __future__ import annotations

from pathlib import Path

from .common import ROOT, Finding, Scene, load_json

LEGEND_PATH = ROOT / "assets" / "maps" / "tile_legend.json"


class Legend:
    def __init__(self, raw: dict):
        self.chars: dict[str, dict] = raw["chars"]
        self.styles: list[str] = list(raw.get("styles", ["default"]))
        self.walkable: set[str] = {ch for ch, info in self.chars.items() if info.get("walkable")}
        self.solid: set[str] = {ch for ch, info in self.chars.items() if not info.get("walkable")}

    @classmethod
    def load(cls, path: Path = LEGEND_PATH) -> "Legend":
        return cls(load_json(path))

    def supports(self, ch: str, style: str) -> bool:
        info = self.chars.get(ch)
        return bool(info) and style in info.get("styles", [])


def check_legend(scene: Scene, legend: Legend) -> list[Finding]:
    """MAP-P006：地圖每個字元都在圖例裡，而且該場景的 tile_style 對它有正式 mapping；不得退回樹根牆／樹皮牆。"""
    findings: list[Finding] = []
    style = scene.tile_style
    if style not in legend.styles:
        findings.append(Finding("MAP-P006", scene.scene_id, f"tile_style={style}", "不是圖例登錄的樣式", fix=f"tile_legend.json styles 只有 {legend.styles}"))
    seen: dict[str, tuple[int, int]] = {}
    for y, row in enumerate(scene.rows):
        for x, ch in enumerate(row):
            if ch in seen:
                continue
            if ch not in legend.chars:
                seen[ch] = (x, y)
                findings.append(Finding("MAP-P006", scene.scene_id, f"字元 '{ch}'", "未知圖例，不得退回預設 tile", (x, y), "在 assets/maps/tile_legend.json 登錄並在 tile_library.gd 加對應，或改用既有字元"))
            elif not legend.supports(ch, style):
                seen[ch] = (x, y)
                findings.append(Finding("MAP-P006", scene.scene_id, f"字元 '{ch}'", f"tile_style={style} 沒有正式 mapping", (x, y), f"在 tile_legend.json 把 {style} 加進該字元的 styles 並在 tile_library.gd 對應，或改用既有字元"))
    return findings


def check_dimensions(scene: Scene) -> list[Finding]:
    findings: list[Finding] = []
    if len(scene.rows) != scene.height:
        findings.append(Finding("MAP-S001", scene.scene_id, "world_size", f"地圖列數 {len(scene.rows)} ≠ {scene.height}"))
    for i, row in enumerate(scene.rows):
        if len(row) != scene.width:
            findings.append(Finding("MAP-S001", scene.scene_id, f"第 {i} 列", f"寬度 {len(row)} ≠ {scene.width}"))
    return findings
