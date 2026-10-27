#!/usr/bin/env python3
"""Vorschaubild des Mods (thumbnail.png, 144 × 144) zeichnen – im Stil des UTL-Bildes: dunkles Quadrat mit runden
Ecken, Gleise, in der Mitte Lok und Wagen, die Kupplung grün hervorgehoben; oben und unten eine Gleisharfe mit den
UTL-Farben an den Stumpfenden. Gezeichnet in vierfacher Größe und verkleinert (glatte Kanten).

Aufruf: tools/make_thumbnail.py [ziel.png]   Standard: thumbnail.png im Mod-Ordner
"""
import os
import sys
from PIL import Image, ImageDraw

S = 4                      # Zeichenmaßstab
W = 144 * S
BG = (38, 41, 47, 255)
GRID = (48, 52, 59, 255)
RAIL = (150, 156, 166, 255)
SLEEPER = (96, 84, 70, 255)
WHITE = (240, 240, 240, 255)
ORANGE = (240, 140, 40, 255)
GREEN = (80, 200, 90, 255)
COLORS = [(240, 140, 40, 255), (60, 140, 230, 255), (240, 200, 40, 255), (80, 200, 90, 255)]


def track(d, x1, y1, x2, y2, width):
    """Gleis von (x1, y1) nach (x2, y2): Schwellen und zwei Schienen."""
    import math
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    gauge = 7 * S
    step = 11 * S
    n = int(length / step)
    for i in range(n + 1):
        cx, cy = x1 + ux * i * step, y1 + uy * i * step
        d.line([(cx - nx * gauge * 1.5, cy - ny * gauge * 1.5), (cx + nx * gauge * 1.5, cy + ny * gauge * 1.5)],
               fill=SLEEPER, width=3 * S)
    for side in (-1, 1):
        d.line([(x1 + nx * gauge * side, y1 + ny * gauge * side), (x2 + nx * gauge * side, y2 + ny * gauge * side)],
               fill=RAIL, width=width)


def main(out):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, W - 1, W - 1], radius=22 * S, fill=BG)
    for g in range(12 * S, W, 18 * S):  # feines Raster wie beim UTL-Bild
        d.line([(g, 6 * S), (g, W - 6 * S)], fill=GRID, width=S)
        d.line([(6 * S, g), (W - 6 * S, g)], fill=GRID, width=S)
    mid = W // 2
    # Gleisharfe: zwei Gleise oben, zwei unten laufen in das Hauptgleis ein
    for k, (dy, color) in enumerate(zip((-48, -26, 26, 48), COLORS)):
        y = mid + dy * S
        track(d, 22 * S, y, 40 * S, y, 2 * S)
        track(d, 40 * S, y, 50 * S + abs(dy) * S // 2, mid, 2 * S)
        d.rounded_rectangle([10 * S, y - 7 * S, 24 * S, y + 7 * S], radius=3 * S, fill=color, outline=BG, width=2 * S)
    track(d, 30 * S, mid, W - 8 * S, mid, 3 * S)
    # Wagen (rechts) und Lok (links), dazwischen die Kupplung
    wy1, wy2 = mid - 15 * S, mid + 15 * S
    d.rounded_rectangle([102 * S, wy1, 136 * S, wy2], radius=4 * S, fill=ORANGE, outline=BG, width=2 * S)
    for x in (108, 116, 124):
        d.line([(x * S + 3 * S, wy1 + 6 * S), (x * S + 3 * S, wy2 - 6 * S)], fill=(200, 110, 25, 255), width=2 * S)
    # Lok wie im UTL-Bild: Kessel, Führerhaus, Schornstein
    lx1, lx2 = 54 * S, 90 * S
    d.rounded_rectangle([lx1, mid - 12 * S, lx2, mid + 15 * S], radius=5 * S, fill=WHITE, outline=BG, width=2 * S)
    d.rounded_rectangle([lx1 + 2 * S, mid - 24 * S, lx1 + 18 * S, mid - 6 * S], radius=3 * S, fill=WHITE,
                        outline=BG, width=2 * S)
    d.rectangle([lx2 - 14 * S, mid - 21 * S, lx2 - 8 * S, mid - 10 * S], fill=WHITE)
    d.rounded_rectangle([lx1 + 5 * S, mid - 20 * S, lx1 + 14 * S, mid - 12 * S], radius=2 * S, fill=BG)
    for x in (lx1 + 8 * S, lx1 + 18 * S, lx1 + 28 * S):
        d.ellipse([x - 5 * S, mid + 10 * S, x + 5 * S, mid + 20 * S], fill=BG)
        d.ellipse([x - 3 * S, mid + 12 * S, x + 3 * S, mid + 18 * S], fill=WHITE)
    # Kupplung: zwei verschlungene Glieder in Grün
    for cx in (94, 99):
        d.rounded_rectangle([cx * S - 5 * S, mid - 4 * S, cx * S + 5 * S, mid + 4 * S], radius=4 * S, outline=GREEN,
                            width=3 * S)
    img = img.resize((144, 144), Image.LANCZOS)
    img.save(out)
    print(out, img.size)


main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "thumbnail.png"))
