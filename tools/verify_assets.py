#!/usr/bin/env python3
"""素材 preflight（Phase 8.5-E）：交付與執行期 PNG 的自動檢查。

    python3 tools/verify_assets.py            # 錯誤 → 非 0；警告只列出
    python3 tools/verify_assets.py --strict   # 警告也算錯誤

檢查項目：
- 執行期目錄（assets/props、tilesets、characters、ui、effects、items、portraits）只能有 PNG（.import／.tres／.ttf／.txt 授權除外）；
  SVG／PSD／Aseprite／Pixquare 原檔一律放 assets/reference/incoming/。
- 每張 PNG：signature、IHDR 尺寸可讀、RGBA。
- props／town_refresh／tilesets：alpha 只用 0 與 255（無柔邊）；props 四角透明（不然是帶背景的參考大圖）。
- 32px atlas（*_tiles_32*.png）：尺寸為 32 的倍數、每格外圈與內圈亮度差 ≤ 12（有格框就會超過）。
- 角色表：walk_v2／idle 192×256、舊表與 NPC／寵物 240×256、行動表 96×256、Boss 480×80。
- manifest（assets/reference/incoming/*MANIFEST*.json）：status 為 delivered 的條目，檔案要存在、尺寸與 SHA-256 要一致。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNTIME_DIRS = ["assets/props", "assets/tilesets", "assets/characters", "assets/ui", "assets/effects", "assets/items", "assets/portraits"]
ALLOWED_RUNTIME_SUFFIXES = {".png", ".import", ".tres", ".ttf", ".txt", ".json", ".gitkeep"}
PREFLIGHT_ALLOWLIST = ROOT / "assets" / "reference" / "incoming" / "ASSET_PREFLIGHT_ALLOWLIST.json"
BINARY_ALPHA_DIRS = ["assets/props", "assets/tilesets"]
CORNER_DIRS = ["assets/props"]
ATLAS_RING_MAX_DIFF = 12.0
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
SHEET_RULES = [
    ("_walk_v2_sheet.png", (192, 256)),
    ("_idle_sheet.png", (192, 256)),
    ("_action_sheet.png", (96, 256)),
    ("fried_food_demon_sheet.png", (480, 80)),
    ("_sheet.png", (240, 256)),
]


def png_header(path: Path) -> tuple[int, int, int, int] | None:
    """回傳 (寬, 高, 位深, 色彩型別)；不是 PNG 時回傳 None。"""
    data = path.read_bytes()[:33]
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        return None
    width, height, depth, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, depth, color_type


def sha256_of(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_image(path: Path):
    from PIL import Image

    return Image.open(path).convert("RGBA")


def alpha_stats(image) -> tuple[int, int, int]:
    """(透明, 半透明, 不透明) 像素數。"""
    histogram = image.getchannel("A").histogram()
    return histogram[0], sum(histogram[1:255]), histogram[255]


def corners_transparent(image) -> bool:
    w, h = image.size
    return all(image.getpixel(p)[3] == 0 for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)))


def ring_brightness(tile, ring: int) -> float:
    px = tile.load()
    size = tile.width
    values = []
    for y in range(size):
        for x in range(size):
            if min(x, y, size - 1 - x, size - 1 - y) == ring:
                r, g, b, _a = px[x, y]
                values.append(0.299 * r + 0.587 * g + 0.114 * b)
    return sum(values) / len(values)


def atlas_gutter_diff(image, tile: int = 32) -> float:
    worst = 0.0
    for row in range(image.height // tile):
        for column in range(image.width // tile):
            cell = image.crop((column * tile, row * tile, (column + 1) * tile, (row + 1) * tile))
            worst = max(worst, abs(ring_brightness(cell, 0) - ring_brightness(cell, 2)), abs(ring_brightness(cell, 1) - ring_brightness(cell, 2)))
    return worst


def check_runtime_dirs(root: Path, errors: list[str], warnings: list[str]) -> list[Path]:
    pngs: list[Path] = []
    for rel in RUNTIME_DIRS:
        base = root / rel
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if path.is_dir():
                continue
            if path.suffix.lower() not in ALLOWED_RUNTIME_SUFFIXES:
                errors.append(f"ASSET-R001 {path.relative_to(root)}：執行期目錄不得放 {path.suffix} 原檔，請移到 assets/reference/incoming/")
            elif path.suffix.lower() == ".png":
                pngs.append(path)
    return pngs


def check_png(path: Path, root: Path, errors: list[str], warnings: list[str]) -> None:
    rel = path.relative_to(root)
    header = png_header(path)
    if header is None:
        errors.append(f"ASSET-P001 {rel}：不是合法 PNG（signature／IHDR）")
        return
    width, height, _depth, color_type = header
    image = load_image(path)
    if color_type != 6:
        warnings.append(f"ASSET-P002 {rel}：色彩型別 {color_type} 不是 RGBA（6），Godot 匯入仍可用但透明資訊可能來自調色盤")
    rel_str = str(rel)
    is_atlas = "_tiles_32" in path.name
    if any(rel_str.startswith(d) for d in BINARY_ALPHA_DIRS) and not is_atlas and "glow" not in path.name and "shadow" not in path.name:
        transparent, semi, opaque = alpha_stats(image)
        if semi:
            errors.append(f"ASSET-P003 {rel}：有 {semi} 個半透明像素（{semi * 100 / (width * height):.1f}%），像素素材 alpha 只能是 0 或 255")
        if any(rel_str.startswith(d) for d in CORNER_DIRS) and opaque and not corners_transparent(image):
            warnings.append(f"ASSET-P004 {rel}：四角不透明（可能是矩形貼片或帶背景）")
    if is_atlas:
        if width % 32 or height % 32:
            errors.append(f"ASSET-T001 {rel}：atlas 尺寸 {width}×{height} 不是 32 的倍數")
        else:
            diff = atlas_gutter_diff(image)
            if diff > ATLAS_RING_MAX_DIFF:
                cell_note = "（橋面格欄杆在兩側屬正常，其餘格請確認沒有格框）" if diff < 40 else ""
                warnings.append(f"ASSET-T002 {rel}：某格外圈與內圈亮度差 {diff:.1f} > {ATLAS_RING_MAX_DIFF:g}{cell_note}")
    if rel_str.startswith("assets/characters"):
        for suffix, expected in SHEET_RULES:
            if path.name.endswith(suffix):
                if (width, height) != expected:
                    errors.append(f"ASSET-C001 {rel}：角色表尺寸 {width}×{height}，規格 {expected[0]}×{expected[1]}")
                break


def check_manifests(root: Path, errors: list[str], warnings: list[str]) -> int:
    checked = 0
    for manifest_path in sorted((root / "assets" / "reference" / "incoming").glob("*MANIFEST*.json")):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        entries = [e for key in ("required_assets", "conditional_assets", "assets", "source_files") for e in (manifest.get(key) or []) if isinstance(e, dict)]
        for entry in entries:
            status = str(entry.get("status", "delivered"))
            if not str(entry.get("path", "")) or "delivered" not in status:
                continue
            path = root / entry["path"]
            label = f"{manifest_path.name}:{entry.get('id', entry['path'])}"
            if not path.exists():
                errors.append(f"ASSET-M001 {label}：manifest 說已交付但檔案不存在 {entry['path']}")
                continue
            header = png_header(path)
            size = entry.get("size") or entry.get("verified_dimensions")
            if header and size and [header[0], header[1]] != [int(size[0]), int(size[1])]:
                errors.append(f"ASSET-M002 {label}：manifest 尺寸 {size} ≠ 實際 {header[0]}×{header[1]}")
            if entry.get("sha256") and entry["sha256"] != sha256_of(path):
                errors.append(f"ASSET-M003 {label}：manifest SHA-256 與實際檔不符")
            checked += 1
    return checked


def load_preflight_allowlist(path: Path = PREFLIGHT_ALLOWLIST) -> tuple[list[dict], float]:
    if not path.exists():
        return [], 0.0
    raw = json.loads(path.read_text(encoding="utf-8"))
    return list(raw.get("entries", [])), float(raw.get("current_phase", 0))


def apply_allowlist(errors: list[str], entries: list[dict], current_phase: float) -> tuple[list[str], list[str], list[str]]:
    """錯誤訊息格式固定為「CODE path：…」；allowlist 以 (rule, path) 對應，到期的例外不再生效。"""
    remaining: list[str] = []
    allowed: list[str] = []
    problems: list[str] = []
    active: dict[tuple[str, str], dict] = {}
    for entry in entries:
        missing = [key for key in ("id", "rule", "path", "reason", "owner", "expires_phase") if not entry.get(key)]
        if missing:
            problems.append(f"ASSET-A001 {entry.get('id', '?')}：allowlist 缺少欄位 {missing}")
            continue
        if current_phase >= float(entry["expires_phase"]):
            problems.append(f"ASSET-A001 {entry['id']}：allowlist 例外已到期（expires_phase {entry['expires_phase']}）")
            continue
        active[(entry["rule"], entry["path"])] = entry
    for line in errors:
        code, _space, rest = line.partition(" ")
        path = rest.split("：", 1)[0]
        if (code, path) in active:
            allowed.append(line)
        else:
            remaining.append(line)
    return remaining + problems, allowed, problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="素材 preflight")
    parser.add_argument("--strict", action="store_true", help="警告也視為錯誤")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args(argv)
    errors: list[str] = []
    warnings: list[str] = []
    pngs = check_runtime_dirs(ROOT, errors, warnings)
    for path in pngs:
        check_png(path, ROOT, errors, warnings)
    manifest_count = check_manifests(ROOT, errors, warnings)
    entries, current_phase = load_preflight_allowlist()
    errors, allowed, _problems = apply_allowlist(errors, entries, current_phase)
    if not args.quiet:
        for line in warnings:
            print("WARN  " + line)
        for line in allowed:
            print("ALLOW " + line)
    for line in errors:
        print("ERROR " + line)
    failed = errors or (args.strict and warnings)
    print(f"素材 preflight：{len(pngs)} 張執行期 PNG、{manifest_count} 筆 manifest 條目、{len(errors)} 錯誤、{len(allowed)} 例外、{len(warnings)} 警告 → {'失敗' if failed else '通過'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
