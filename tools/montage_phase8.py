#!/usr/bin/env python3
"""把 docs/screenshots/phase8_baseline/*.png 拼成幾張總覽圖（每張 6 格，縮到 640 寬），方便一次檢視。"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

src = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots/phase8_baseline")
out = src / "montage"
out.mkdir(exist_ok=True)
files = sorted(p for p in src.glob("*.png"))
W = 640
cols, per = 2, 6
for i in range(0, len(files), per):
    batch = files[i:i + per]
    tiles = []
    for p in batch:
        im = Image.open(p).convert("RGB")
        h = round(im.height * W / im.width)
        im = im.resize((W, h), Image.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, 8 + 7 * len(p.stem), 14), fill=(0, 0, 0))
        d.text((4, 2), p.stem, fill=(255, 255, 0))
        tiles.append(im)
    th = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (W * cols, th * rows), (40, 40, 40))
    for k, t in enumerate(tiles):
        sheet.paste(t, ((k % cols) * W, (k // cols) * th))
    dest = out / f"montage_{i // per + 1}.png"
    sheet.save(dest)
    print(dest, sheet.size, [p.stem for p in batch])
