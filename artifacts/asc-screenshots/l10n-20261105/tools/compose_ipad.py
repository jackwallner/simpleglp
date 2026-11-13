#!/usr/bin/env python3
"""Compose 13-inch iPad App Store frames (2064x2752): one header over a framed real iPad capture.

Usage: compose_ipad.py [locale ...]
Reads raw/<locale>/ipad/<scene>.png and copy/ipad-headers.json, writes ipad/<locale>/<scene>.png.
All headers in a locale share the size of the longest one so the set reads uniform.
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

KIT = Path(__file__).resolve().parent.parent
CANVAS = (2064, 2752)
SCREEN = (1860, 2480)
BEZEL = 32
DEVICE_TOP = 450
HEADER_BOX = (1800, 330)
HEADER_Y = 70
FONT = "HelveticaNeue-Light"
COLOR = [25, 53, 57]
TOP, BOTTOM = (237, 247, 245), (201, 232, 226)
SS = 4


def headline(jobs):
    r = subprocess.run([str(KIT / "tools" / "headline")], input=json.dumps(jobs, ensure_ascii=False),
                       text=True, capture_output=True)
    if r.returncode:
        raise SystemExit(r.stderr)
    return json.loads(r.stdout)


def background():
    w, h = CANVAS
    strip = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        strip.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return strip.resize((w, h))


def rounded_mask(size, radius):
    w, h = size
    m = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius * SS, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def compose(locale, scenes, texts, size, tmp):
    for scene in scenes:
        raw = KIT / "raw" / locale / "ipad" / f"{scene}.png"
        canvas = background()
        header = tmp / f"{locale}-{scene}.png"
        headline([{"text": texts[scene], "locale": locale, "font": FONT, "color": COLOR,
                   "box": list(HEADER_BOX), "size": size, "out": str(header)}])
        h = Image.open(header).convert("RGBA")
        canvas.paste(h, ((CANVAS[0] - h.width) // 2, HEADER_Y + (HEADER_BOX[1] - h.height) // 2), h)
        dev = (SCREEN[0] + 2 * BEZEL, SCREEN[1] + 2 * BEZEL)
        x, y = (CANVAS[0] - dev[0]) // 2, DEVICE_TOP
        body = Image.new("RGB", dev, (14, 16, 16))
        canvas.paste(body, (x, y), rounded_mask(dev, 112))
        screen = Image.open(raw).convert("RGB").resize(SCREEN, Image.LANCZOS)
        canvas.paste(screen, (x + BEZEL, y + BEZEL), rounded_mask(SCREEN, 80))
        out = KIT / "ipad" / locale
        out.mkdir(parents=True, exist_ok=True)
        canvas.save(out / f"{scene}.png", optimize=True)


def main():
    headers = json.loads((KIT / "copy" / "ipad-headers.json").read_text(encoding="utf-8"))
    locales = sys.argv[1:] or list(headers)
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        for locale in locales:
            texts = headers[locale]
            scenes = [s for s in texts if (KIT / "raw" / locale / "ipad" / f"{s}.png").exists()]
            if not scenes:
                print(f"{locale}: no raws"); continue
            fits = headline([{"text": texts[s], "locale": locale, "font": FONT, "color": COLOR,
                              "box": list(HEADER_BOX), "maxSize": 170, "minSize": 1} for s in scenes])
            size = min(f["size"] for f in fits)
            compose(locale, scenes, texts, size, tmp)
            print(f"{locale}: {len(scenes)} frames, header {size:.0f}px")


if __name__ == "__main__":
    main()
