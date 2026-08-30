#!/usr/bin/env python3
"""Schematic de_mirage radar using playable spawn/site bounds (not skybox)."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/workspace")
ENTS = ROOT / "assets/maps/de_mirage/entities.json"
OUT = ROOT / "assets/maps/de_mirage/radar.png"

# Playable AABB from T/CT spawns + bomb sites, padded.
MINX, MAXX = -64.0, 44.0
MINZ, MAXZ = -20.0, 70.0
W = H = 1024


def proj(x: float, z: float) -> tuple[int, int]:
    px = int((x - MINX) / (MAXX - MINX) * (W - 1))
    # z+ (A/CT) at top of image
    pz = int((1.0 - (z - MINZ) / (MAXZ - MINZ)) * (H - 1))
    return px, pz


def box(draw: ImageDraw.ImageDraw, x0, z0, x1, z1, fill, outline=None):
    a = proj(x0, z0)
    b = proj(x1, z1)
    r = [min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])]
    draw.rectangle(r, fill=fill, outline=outline)


def main() -> None:
    img = Image.new("RGBA", (W, H), (18, 24, 20, 255))
    d = ImageDraw.Draw(img)
    # Sand floor
    box(d, MINX, MINZ, MAXX, MAXZ, (168, 140, 98, 255))

    # Callout blocks (approx Godot XZ from CS:GO mirage layout)
    regions = [
        ("T SPAWN", 24, -4, 40, 14, (150, 122, 82)),
        ("T ROOF", 8, 8, 24, 22, (140, 118, 88)),
        ("PALACE", 6, 40, 22, 62, (190, 170, 140)),
        ("A", -18, 48, -4, 64, (210, 90, 70)),
        ("CT", -54, 40, -36, 58, (70, 110, 160)),
        ("JUNGLE", -28, 40, -12, 56, (90, 120, 70)),
        ("CONNECTOR", -18, 22, -4, 40, (130, 110, 90)),
        ("MID", -8, 10, 10, 28, (176, 150, 108)),
        ("CAT", 8, 22, 18, 40, (160, 130, 96)),
        ("SHOP", -30, 8, -14, 22, (150, 100, 70)),
        ("APPS", -40, 8, -22, 28, (186, 150, 120)),
        ("B APPS", -58, 6, -40, 22, (170, 130, 100)),
        ("B", -62, -14, -44, 4, (210, 90, 70)),
        ("TUNNELS", -40, -14, -18, 6, (120, 100, 80)),
        ("UNDERPASS", -16, 0, -2, 12, (110, 95, 78)),
        ("TICKET", -36, 28, -22, 42, (160, 140, 110)),
    ]
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    except Exception:
        font = ImageFont.load_default()
        small = font
    for name, x0, z0, x1, z1, col in regions:
        box(d, x0, z0, x1, z1, col + (255,), (40, 32, 24, 180))
        cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
        px, pz = proj(cx, cz)
        d.text((px - 3 * len(name), pz - 8), name, fill=(255, 245, 220, 220), font=small)

    ents = json.loads(ENTS.read_text())
    for site in ents.get("bomb_sites", []):
        c = site["center"]
        px, pz = proj(c[0], c[2])
        d.ellipse((px - 16, pz - 16, px + 16, pz + 16), outline=(240, 210, 50), width=4)
        d.text((px - 6, pz - 10), site.get("name", "?"), fill=(240, 210, 50), font=font)
    for s in ents.get("t_spawns", [])[:5]:
        px, pz = proj(s["origin"][0], s["origin"][2])
        d.rectangle((px - 3, pz - 3, px + 3, pz + 3), fill=(220, 180, 60))
    for s in ents.get("ct_spawns", [])[:5]:
        px, pz = proj(s["origin"][0], s["origin"][2])
        d.rectangle((px - 3, pz - 3, px + 3, pz + 3), fill=(80, 150, 220))

    img.save(OUT)
    ents["radar"] = {"min": [MINX, MINZ], "max": [MAXX, MAXZ], "size": [W, H]}
    ENTS.write_text(json.dumps(ents, indent=2))
    print("radar", OUT, "bounds", MINX, MAXZ, MAXX, MAXZ)


if __name__ == "__main__":
    main()
