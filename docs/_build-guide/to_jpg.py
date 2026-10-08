# -*- coding: utf-8 -*-
"""shots/*.png -> jpg/*.jpg for build_docx.py, with the last safety net applied.

Usage: .venv/bin/python to_jpg.py <employee|management>

anon.py already replaced every person before the app drew them. What is
covered here is only what could still slip past it: boxes a capture script
flagged by hand (`blur_extra`) and any e-mail address on screen that is not
one of the fake example.com ones.
"""
import json, re, sys
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).parent
D = ROOT / sys.argv[1]
EMAIL_RE = re.compile(r"[\w.+-]+@[\w-]+(\.[\w-]+)+")
out = D / "jpg"; out.mkdir(exist_ok=True)
man = json.loads((D / "manifest.json").read_text("utf-8"))
blurred = 0
for e in man:
    png = D / "shots" / e["file"]
    meta = json.loads(png.with_suffix(".json").read_text("utf-8"))
    im = Image.open(png).convert("RGB")
    k = im.width / meta["vp"]["width"]
    boxes = list(meta.get("blur_extra", []))
    for n in meta["nodes"]:
        if any(not m.group(0).endswith("@example.com") for m in EMAIL_RE.finditer(n["t"])):
            boxes.append((n["x"], n["y"], n["w"], n["h"]))
    for (x, y, w, h) in boxes:
        box = tuple(int(v * k) for v in (x, y, x + w, y + h))
        box = (max(0, box[0]), max(0, box[1]), min(im.width, box[2]), min(im.height, box[3]))
        if box[2] > box[0] and box[3] > box[1]:
            im.paste(im.crop(box).filter(ImageFilter.GaussianBlur(14)), box)
            blurred += 1
    im.thumbnail((1600, 1600))
    im.save(out / (png.stem + ".jpg"), quality=84, optimize=True)
print(f"{len(man)} images, {blurred} areas blurred -> {out}")
