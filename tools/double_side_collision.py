#!/usr/bin/env python3
"""Add reverse winding to every collision.obj face (Godot trimesh is one-way)."""
from pathlib import Path

SRC = Path(__file__).resolve().parent.parent / "assets" / "maps" / "de_mirage" / "collision.obj"
if not SRC.is_file():
    raise SystemExit(f"missing {SRC}")
lines = SRC.read_text().splitlines()
verts: list[str] = []
faces: list[tuple[int, int, int]] = []
for line in lines:
    if line.startswith("v "):
        verts.append(line)
    elif line.startswith("f "):
        parts = line.split()
        ids = tuple(int(p.split("/")[0]) for p in parts[1:4])
        faces.append(ids)

have: set[tuple[int, int, int]] = set(faces)
out = list(faces)
for a, b, c in faces:
    rev = (a, c, b)
    if rev not in have and (c, b, a) not in have and (b, a, c) not in have:
        out.append(rev)
        have.add(rev)

if len(out) == len(faces):
    print(f"already two-sided verts {len(verts)} faces {len(faces)}")
    raise SystemExit(0)

with SRC.open("w") as f:
    f.write("# de_mirage collision (two-sided)\n")
    for v in verts:
        f.write(v + "\n")
    for a, b, c in out:
        f.write(f"f {a} {b} {c}\n")
print(f"verts {len(verts)} faces {len(faces)} -> {len(out)}")
