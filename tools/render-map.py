#!/usr/bin/env python3
"""Bilder aus einem Kartenauszug (tools/mapdump, MAPDUMP=1 tools/test-headless.sh) zeichnen – ohne Grafik.

Aufruf: tools/render-map.py <ucy-map-TICK.json> <zielordner> [name:x1,y1,x2,y2,kacheln_je_pixel ...]
Ohne Ausschnitte: Übersicht über alles. Gleise grau (Bögen angenähert), Signale grün/rot/gelb nach Zustand
(Kettensignal als Raute), Halte blau mit Namen, Loks rot, Wagen gelb, Ladestellen dunkelgrün.
"""
import json, math, sys, os
from PIL import Image, ImageDraw, ImageFont

STATE = {0: (60, 200, 60), 1: (220, 50, 50), 2: (240, 200, 40), 3: (240, 120, 40)}
LEN = {"straight-rail": 2, "curved-rail-a": 5, "curved-rail-b": 5, "half-diagonal-rail": 4.5}


def font(size):
    for name in ("DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(data, box, scale, path, title):
    x1, y1, x2, y2 = box
    w, h = int((x2 - x1) * scale), int((y2 - y1) * scale)
    img = Image.new("RGB", (w, h + 30), (24, 26, 30))
    d = ImageDraw.Draw(img)

    def p(x, y):
        return ((x - x1) * scale, (y - y1) * scale + 30)

    def inside(x, y, m=8):
        return x1 - m <= x <= x2 + m and y1 - m <= y <= y2 + m

    lw = max(1, int(scale * 0.6))
    for kind, x, y, dr in data["rails"]:
        if not inside(x, y):
            continue
        a = math.radians(dr * 22.5)
        dx, dy = math.sin(a) * LEN[kind] / 2, -math.cos(a) * LEN[kind] / 2
        d.line([p(x - dx, y - dy), p(x + dx, y + dy)], fill=(150, 150, 150), width=lw)
    for kind, x, y in data["other"]:
        if inside(x, y) and scale >= 2:
            c = (30, 110, 60) if kind in ("inserter", "infinity-container") else (70, 70, 90)
            q = p(x, y)
            r = scale * 0.4
            d.rectangle([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=c)
    for kind, x, y, ori, _, _ in data["stock"]:
        if not inside(x, y):
            continue
        a = ori * 2 * math.pi
        fx, fy = math.sin(a), -math.cos(a)
        rx, ry = -fy, fx
        pts = [p(x + fx * sl + rx * sw, y + fy * sl + ry * sw) for sl, sw in
               ((3, 1), (3, -1), (-3, -1), (-3, 1))]
        d.polygon(pts, fill=(230, 60, 50) if kind == "L" else (240, 200, 60), outline=(0, 0, 0))
        if kind == "L":  # Blickrichtung
            d.line([p(x, y), p(x + fx * 3, y + fy * 3)], fill=(255, 255, 255), width=max(1, lw))
    sr = max(1.5, scale * 0.45)
    for kind, x, y, dr, st in data["signals"]:
        if not inside(x, y):
            continue
        q = p(x, y)
        c = STATE.get(st, (200, 200, 200))
        if kind == "K":
            d.polygon([(q[0], q[1] - sr * 1.3), (q[0] + sr * 1.3, q[1]), (q[0], q[1] + sr * 1.3), (q[0] - sr * 1.3, q[1])],
                      fill=c)
        else:
            d.ellipse([q[0] - sr, q[1] - sr, q[0] + sr, q[1] + sr], fill=c)
    f = font(max(10, min(16, int(scale * 3))))
    for name, x, y, dr in data["stops"]:
        if not inside(x, y):
            continue
        q = p(x, y)
        r = max(2, scale)
        d.rectangle([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=(60, 120, 230))
        if scale >= 2:
            label = name.split("] ")[-1]
            d.text((q[0] + r + 2, q[1] - r - 2), label, fill=(170, 200, 255), font=f)
    d.text((8, 6), title, fill=(230, 230, 230), font=font(16))
    img.save(path)
    print(path, img.size)


def main():
    src, out = sys.argv[1], sys.argv[2]
    data = json.load(open(src))
    os.makedirs(out, exist_ok=True)
    cuts = sys.argv[3:]
    if not cuts:
        xs = [r[1] for r in data["rails"]]
        ys = [r[2] for r in data["rails"]]
        cuts = ["uebersicht:%d,%d,%d,%d,0.7" % (min(xs) - 10, min(ys) - 10, max(xs) + 10, max(ys) + 10)]
    for cut in cuts:
        name, spec = cut.split(":")
        x1, y1, x2, y2, scale = (float(v) for v in spec.split(","))
        render(data, (x1, y1, x2, y2), scale, os.path.join(out, name + ".png"),
               "%s – Tick %d (%d:%02d min)" % (name, data["tick"], data["tick"] // 3600, data["tick"] // 60 % 60))


main()
