#!/usr/bin/env python3
"""Convert CS:GO de_mirage.bsp into Godot-ready GLB + entities + radar + nav."""
from __future__ import annotations

import json
import math
import os
import struct
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import bsp_tool

ROOT = Path("/workspace")
BSP_PATH = ROOT / "raw/maps/de_mirage.bsp"
NAV_PATH = ROOT / "raw/maps/de_mirage.nav"
OUT_DIR = ROOT / "assets/maps/de_mirage"
SCALE = 0.0254  # Source inch -> meter

SKIP_VISUAL = (
    "tools/toolsnodraw",
    "tools/toolsclip",
    "tools/toolsplayerclip",
    "tools/toolsskybox",
    "tools/toolsskybox2d",
    "tools/toolshint",
    "tools/toolsskip",
    "tools/toolstrigger",
    "tools/toolsareaportal",
    "tools/toolsinvisible",
    "tools/toolsblock",
    "tools/toolsblocklight",
    "tools/toolsblockbullet",
    "tools/toolsorigin",
    "tools/toolssolid",
    "tools/fogvolume",
    "lights/",
    "water/water_lod",
)
COLLISION_SKIP = (
    "tools/toolsskybox",
    "tools/toolsskybox2d",
    "tools/toolshint",
    "tools/toolsskip",
    "tools/toolstrigger",
    "tools/toolsareaportal",
    "tools/fogvolume",
    "lights/",
)
SKIP_ENT_MODELS = {
    "func_areaportal",
    "func_areaportalwindow",
    "trigger_multiple",
    "trigger_once",
    "func_bomb_target",
    "func_buyzone",
    "func_dustmotes",
    "func_clip_vphysics",
}

# Mirage material palettes (CS:GO-accurate sandstone / medina look).
CATEGORY_COLORS = {
    "brick": (186, 142, 98),
    "plaster": (214, 196, 168),
    "sand": (198, 168, 118),
    "wood": (122, 86, 52),
    "metal": (96, 98, 102),
    "tile": (176, 154, 128),
    "concrete": (154, 140, 122),
    "marble": (210, 202, 190),
    "fabric": (48, 92, 138),
    "glass": (160, 190, 200),
    "trim": (92, 72, 54),
    "green": (92, 118, 64),
    "market": (168, 92, 48),
    "default": (176, 152, 118),
}


def mat_name(mesh) -> str:
    m = mesh.material
    n = getattr(m, "name", None) or str(m)
    n = n.replace("Material('", "").replace("')", "").strip().lower()
    return n


def categorize(name: str) -> str:
    n = name.lower()
    if "glass" in n or "window" in n:
        return "glass"
    if "metal" in n or "pipe" in n or "door" in n and "metal" in n:
        return "metal"
    if "wood" in n:
        return "wood"
    if "brick" in n:
        return "brick"
    if "marble" in n:
        return "marble"
    if "tile" in n:
        return "tile"
    if "plaster" in n:
        return "plaster"
    if "sand" in n or "blend" in n or "ground" in n or "dirt" in n:
        return "sand"
    if "concrete" in n or "cement" in n:
        return "concrete"
    if "fabric" in n or "cloth" in n or "carpet" in n or "awning" in n:
        return "fabric"
    if "market" in n:
        return "market"
    if "grass" in n or "hedge" in n or "foliage" in n:
        return "green"
    if "trim" in n or "deco" in n:
        return "trim"
    if "mirage_mid" in n or "mirage_top" in n or "base/de_mirage" in n:
        return "sand"
    return "default"


def skip_visual(name: str) -> bool:
    n = name.lower()
    return any(n.startswith(s) or s in n for s in SKIP_VISUAL)


def skip_collision(name: str) -> bool:
    n = name.lower()
    return any(n.startswith(s) or s in n for s in COLLISION_SKIP)


def src_to_godot(x, y, z):
    return (x * SCALE, z * SCALE, -y * SCALE)


def src_n_to_godot(x, y, z):
    lx, ly, lz = x, z, -y
    l = math.sqrt(lx * lx + ly * ly + lz * lz) or 1.0
    return (lx / l, ly / l, lz / l)


def vcomp(v, i):
    if hasattr(v, "x"):
        return (v.x, v.y, v.z)[i]
    return float(v[i])


def make_category_textures(path: Path) -> dict[str, Path]:
    path.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(2018)
    out = {}
    for cat, rgb in CATEGORY_COLORS.items():
        s = 512
        img = np.zeros((s, s, 3), dtype=np.float32)
        base = np.array(rgb, dtype=np.float32) / 255.0
        yy, xx = np.mgrid[0:s, 0:s]
        if cat in ("brick",):
            bw, bh = 42, 18
            mortar = ((xx % bw) < 3) | ((yy % bh) < 3)
            stagger = ((yy // bh) % 2) * (bw // 2)
            mortar = ((xx + stagger) % bw < 3) | (yy % bh < 3)
            brick_n = rng.random((s, s, 1)) * 0.18
            img[:] = base * (0.88 + brick_n)
            img[mortar] = np.array([0.45, 0.38, 0.30])
        elif cat in ("tile", "marble"):
            tw = 64
            grout = ((xx % tw) < 2) | ((yy % tw) < 2)
            img[:] = base * (0.9 + rng.random((s, s, 1)) * 0.12)
            img[grout] = np.array([0.35, 0.32, 0.28])
            if cat == "marble":
                veining = (np.sin(xx * 0.04 + yy * 0.02) * np.sin(yy * 0.07)).clip(0, 1)
                img += veining[..., None] * 0.12
        elif cat == "wood":
            grain = 0.5 + 0.5 * np.sin(yy * 0.35 + np.sin(xx * 0.05) * 4)
            img[:] = base * (0.75 + 0.35 * grain[..., None])
            img *= 0.85 + rng.random((s, s, 1)) * 0.15
        elif cat == "metal":
            img[:] = base * (0.7 + rng.random((s, s, 1)) * 0.3)
            rivet = ((xx % 32) < 3) & ((yy % 32) < 3)
            img[rivet] = img[rivet] * 1.3
        elif cat == "fabric" or cat == "market":
            stripe = (np.sin(xx * 0.2) > 0).astype(np.float32)
            img[:] = base * (0.7 + 0.4 * stripe[..., None])
            img *= 0.85 + rng.random((s, s, 1)) * 0.2
        elif cat == "glass":
            img[:] = base * (0.6 + 0.2 * np.sin(xx * 0.08)[..., None])
        else:
            # plaster / sand / concrete / default: mottled stucco
            noise = rng.random((s, s, 1))
            blot = np.sin(xx * 0.03)[..., None] * np.sin(yy * 0.025)[..., None]
            img[:] = base * (0.82 + 0.22 * noise + 0.08 * blot)
            if cat == "sand":
                img *= 0.95 + 0.1 * rng.random((s, s, 1))
        img = np.clip(img, 0, 1)
        p = path / f"{cat}.png"
        Image.fromarray((img * 255).astype(np.uint8), "RGB").save(p)
        out[cat] = p
    return out


def triangulate(poly_verts):
    if len(poly_verts) < 3:
        return []
    tris = []
    for i in range(1, len(poly_verts) - 1):
        tris.append((poly_verts[0], poly_verts[i], poly_verts[i + 1]))
    return tris


def sun_lit(nx, ny, nz):
    # Source Z-up sun, roughly mirage afternoon
    sx, sy, sz = 0.35, 0.25, 0.90
    ndot = max(0.0, nx * sx + ny * sy + nz * sz)
    amb = 0.32
    if nz < -0.2:
        amb *= 0.55
    return amb + 0.68 * ndot


class PrimBuilder:
    def __init__(self):
        self.positions = []
        self.normals = []
        self.uvs = []
        self.colors = []
        self.indices = []

    def add_tri(self, verts, albedo):
        base = len(self.positions)
        for v in verts:
            px, py, pz = vcomp(v.position, 0), vcomp(v.position, 1), vcomp(v.position, 2)
            nx, ny, nz = vcomp(v.normal, 0), vcomp(v.normal, 1), vcomp(v.normal, 2)
            gx, gy, gz = src_to_godot(px, py, pz)
            gnx, gny, gnz = src_n_to_godot(nx, ny, nz)
            uv = v.uv[0] if isinstance(v.uv, (list, tuple)) else v.uv
            u, vv = float(uv.x) if hasattr(uv, "x") else float(uv[0]), float(uv.y) if hasattr(uv, "y") else float(uv[1])
            cr, cg, cb, _ca = v.colour if v.colour is not None else (1, 1, 1, 1)
            lit = sun_lit(nx, ny, nz)
            r = min(1.0, albedo[0] * (0.35 + 0.65 * cr) * lit)
            g = min(1.0, albedo[1] * (0.35 + 0.65 * cg) * lit)
            b = min(1.0, albedo[2] * (0.35 + 0.65 * cb) * lit)
            self.positions.extend((gx, gy, gz))
            self.normals.extend((gnx, gny, gnz))
            self.uvs.extend((u, vv))
            self.colors.extend((r, g, b, 1.0))
        self.indices.extend((base, base + 1, base + 2))


def write_glb(path: Path, prims: dict[str, PrimBuilder], tex_files: dict[str, Path]):
    """Minimal glTF 2.0 GLB with COLOR_0, UV, normals, per-category PNG."""
    bin_chunks = []
    accessors = []
    buffer_views = []
    images = []
    textures = []
    materials = []
    primitives = []
    offset = 0

    def align4(n):
        return (n + 3) & ~3

    def add_blob(data: bytes, target: int):
        nonlocal offset
        pad = align4(len(data)) - len(data)
        buffer_views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
        bin_chunks.append(data + (b"\x00" * pad))
        offset += len(data) + pad
        return len(buffer_views) - 1

    # embed textures
    img_index = {}
    for cat, p in tex_files.items():
        raw = p.read_bytes()
        images.append({"mimeType": "image/png", "bufferView": None})
        bv = add_blob(raw, None)  # no target for image
        images[-1]["bufferView"] = bv
        # fix target None - glTF images shouldn't have target on bufferView
        buffer_views[bv].pop("target", None)
        textures.append({"source": len(images) - 1})
        img_index[cat] = len(textures) - 1

    for cat, pb in prims.items():
        if not pb.indices:
            continue
        pos = np.asarray(pb.positions, dtype=np.float32)
        nrm = np.asarray(pb.normals, dtype=np.float32)
        uvs = np.asarray(pb.uvs, dtype=np.float32)
        col = np.asarray(pb.colors, dtype=np.float32)
        idx = np.asarray(pb.indices, dtype=np.uint32)
        nvert = pos.size // 3
        # accessors
        def acc_vec(arr, ncomp, bview, mins=None, maxs=None, ctype=5126):
            a = {"bufferView": bview, "componentType": ctype, "count": nvert if ncomp != 1 else len(idx), "type": {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[ncomp]}
            if mins is not None:
                a["min"] = mins
                a["max"] = maxs
            accessors.append(a)
            return len(accessors) - 1

        pmin = pos.reshape(-1, 3).min(0).tolist()
        pmax = pos.reshape(-1, 3).max(0).tolist()
        ai_pos = acc_vec(pos, 3, add_blob(pos.tobytes(), 34962), pmin, pmax)
        ai_nrm = acc_vec(nrm, 3, add_blob(nrm.tobytes(), 34962))
        ai_uv = acc_vec(uvs, 2, add_blob(uvs.tobytes(), 34962))
        ai_col = acc_vec(col, 4, add_blob(col.tobytes(), 34962))
        accessors.append(
            {
                "bufferView": add_blob(idx.tobytes(), 34963),
                "componentType": 5125,
                "count": int(idx.size),
                "type": "SCALAR",
            }
        )
        ai_idx = len(accessors) - 1
        rgb = [c / 255.0 for c in CATEGORY_COLORS.get(cat, CATEGORY_COLORS["default"])]
        mat = {
            "name": cat,
            "pbrMetallicRoughness": {
                "baseColorFactor": [rgb[0], rgb[1], rgb[2], 0.55 if cat == "glass" else 1.0],
                "metallicFactor": 0.55 if cat == "metal" else 0.0,
                "roughnessFactor": 0.25 if cat == "metal" else 0.92,
            },
            "doubleSided": True,
        }
        if cat in img_index:
            mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": img_index[cat]}
            mat["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, 0.45 if cat == "glass" else 1]
        if cat == "glass":
            mat["alphaMode"] = "BLEND"
        materials.append(mat)
        primitives.append(
            {
                "attributes": {"POSITION": ai_pos, "NORMAL": ai_nrm, "TEXCOORD_0": ai_uv, "COLOR_0": ai_col},
                "indices": ai_idx,
                "material": len(materials) - 1,
            }
        )

    binary = b"".join(bin_chunks)
    gltf = {
        "asset": {"version": "2.0", "generator": "hvh2018-bsp"},
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": buffer_views,
        "accessors": accessors,
        "images": images,
        "textures": textures,
        "materials": materials,
        "meshes": [{"name": "de_mirage", "primitives": primitives}],
        "nodes": [{"name": "de_mirage", "mesh": 0}],
        "scenes": [{"nodes": [0]}],
        "scene": 0,
    }
    js = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    js += b" " * ((4 - (len(js) % 4)) % 4)
    binary += b"\x00" * ((4 - (len(binary) % 4)) % 4)
    length = 12 + 8 + len(js) + 8 + len(binary)
    header = struct.pack("<4sII", b"glTF", 2, length)
    jschunk = struct.pack("<I4s", len(js), b"JSON") + js
    bchunk = struct.pack("<I4s", len(binary), b"BIN\x00") + binary
    path.write_bytes(header + jschunk + bchunk)
    print(f"wrote {path} ({path.stat().st_size/1e6:.1f} MB) prims={len(primitives)} verts={sum(len(p.positions)//3 for p in prims.values())}")


def collect_meshes(bsp):
    visual = defaultdict(list)
    collision = []
    world = bsp.MODELS[0]
    # World faces
    nworld = world.num_faces
    print(f"world faces {nworld} total faces {len(bsp.FACES)} models {len(bsp.MODELS)}")

    # Skip trigger-like brush models
    skip_models = set()
    for e in bsp.ENTITIES:
        cn = e.get("classname", "")
        mdl = e.get("model", "")
        if cn in SKIP_ENT_MODELS and mdl.startswith("*"):
            try:
                skip_models.add(int(mdl[1:]))
            except ValueError:
                pass

    def consume_mesh(mesh, force_collision=False):
        name = mat_name(mesh)
        cat = categorize(name)
        vis = not skip_visual(name)
        col = not skip_collision(name) or force_collision
        for poly in mesh.polygons:
            tris = triangulate(poly.vertices)
            if vis:
                visual[cat].extend(tris)
            if col:
                for t in tris:
                    collision.append(t)

    # Regular + displacement faces for every brush model except skipped
    for mi, model in enumerate(bsp.MODELS):
        if mi in skip_models:
            continue
        first = model.first_face
        last = first + model.num_faces
        for fi in range(first, last):
            face = bsp.FACES[fi]
            try:
                if face.displacement_info is not None and int(face.displacement_info) >= 0:
                    mesh = bsp.displacement_mesh(fi)
                    consume_mesh(mesh)
                else:
                    for mesh in bsp.face_mesh(fi):
                        consume_mesh(mesh)
            except Exception:
                continue
        if mi % 20 == 0:
            print(f"  model {mi}/{len(bsp.MODELS)}")
    return visual, collision


def parse_entities(bsp):
    def origin(e):
        o = e.get("origin", "0 0 0").split()
        x, y, z = (float(o[0]), float(o[1]), float(o[2])) if len(o) >= 3 else (0, 0, 0)
        return list(src_to_godot(x, y, z))

    def angles(e):
        a = e.get("angles", "0 0 0").split()
        p, yaw, r = (float(a[0]), float(a[1]), float(a[2])) if len(a) >= 3 else (0, 0, 0)
        # Source pitch/yaw/roll -> Godot (Y-up): yaw around Y becomes -yaw after Y-flip
        return [p, yaw, r]

    def model_aabb(e):
        mdl = e.get("model", "")
        if not mdl.startswith("*"):
            return None
        idx = int(mdl[1:])
        m = bsp.MODELS[idx]
        mins = m.bounds.mins
        maxs = m.bounds.maxs
        c0 = src_to_godot(vcomp(mins, 0), vcomp(mins, 1), vcomp(mins, 2))
        c1 = src_to_godot(vcomp(maxs, 0), vcomp(maxs, 1), vcomp(maxs, 2))
        mn = [min(c0[0], c1[0]), min(c0[1], c1[1]), min(c0[2], c1[2])]
        mx = [max(c0[0], c1[0]), max(c0[1], c1[1]), max(c0[2], c1[2])]
        center = [(mn[i] + mx[i]) * 0.5 for i in range(3)]
        return {"mins": mn, "maxs": mx, "center": center}

    t_spawns, ct_spawns = [], []
    bombs, buys = [], []
    for e in bsp.ENTITIES:
        cn = e.get("classname", "")
        if cn == "info_player_terrorist":
            t_spawns.append({"origin": origin(e), "angles": angles(e)})
        elif cn == "info_player_counterterrorist":
            ct_spawns.append({"origin": origin(e), "angles": angles(e)})
        elif cn == "func_bomb_target":
            aabb = model_aabb(e)
            if aabb:
                bombs.append(aabb)
        elif cn == "func_buyzone":
            aabb = model_aabb(e)
            if aabb:
                team = int(e.get("TeamNum", e.get("teamnum", "0")) or 0)
                aabb["team"] = team
                buys.append(aabb)
    # A is east (+X godot is +X source). On mirage A is +X, B is -X
    bombs.sort(key=lambda b: b["center"][0], reverse=True)
    if len(bombs) >= 2:
        bombs[0]["name"] = "A"
        bombs[1]["name"] = "B"
    elif bombs:
        bombs[0]["name"] = "A"

    props = []
    sprp = bsp.GAME_LUMP.sprp
    names = list(sprp.model_names)
    cover_keys = (
        "van", "truck", "car", "crate", "box", "barrel", "dumpster", "pallet",
        "barrier", "sandbag", "kiosk", "cart", "fridge", "table", "bench",
        "container", "oil", "booth", "market", "wood_crate", "cardboard",
        "trash", "bin", "sofa", "couch", "shelf", "cabinet", "door",
        "concrete", "block", "wall_brick", "aircon", "acunit", "pipe_cluster",
        "brush_shape", "wood_fence", "fence", "sign_board", "food_cart",
    )
    size_map = {
        "van": (2.2, 2.0, 5.2),
        "truck": (2.4, 2.4, 6.0),
        "crate": (0.7, 0.7, 0.7),
        "wood_crate": (0.8, 0.8, 0.8),
        "barrel": (0.45, 0.9, 0.45),
        "dumpster": (1.1, 1.2, 1.8),
        "barrier": (0.5, 1.1, 2.0),
        "bench": (0.5, 0.5, 1.6),
        "table": (0.9, 0.8, 1.4),
        "box": (0.55, 0.55, 0.55),
        "brush_shape": (0.8, 1.2, 0.8),
        "fence": (0.12, 1.6, 2.4),
        "door": (0.12, 2.2, 1.1),
        "cart": (0.8, 1.0, 1.4),
        "container": (2.4, 2.6, 6.0),
    }
    for i, p in enumerate(sprp.props):
        ni = int(getattr(p, "name_index", 0))
        name = names[ni] if 0 <= ni < len(names) else ""
        low = name.lower()
        if not any(k in low for k in cover_keys):
            continue
        ox, oy, oz = vcomp(p.origin, 0), vcomp(p.origin, 1), vcomp(p.origin, 2)
        origin_g = list(src_to_godot(ox, oy, oz))
        ang = p.angles
        # yzx mapping: y=pitch, z=yaw, x=roll
        pitch = float(getattr(ang, "y", 0.0))
        yaw = float(getattr(ang, "z", 0.0))
        roll = float(getattr(ang, "x", 0.0))
        size = (0.6, 0.8, 0.6)
        for k, sz in size_map.items():
            if k in low:
                size = sz
                break
        props.append(
            {
                "name": name,
                "origin": origin_g,
                "pitch": pitch,
                "yaw": yaw,
                "roll": roll,
                "size": list(size),
            }
        )
    return {
        "t_spawns": t_spawns,
        "ct_spawns": ct_spawns,
        "bomb_sites": bombs,
        "buyzones": buys,
        "props": props,
        "scale": SCALE,
        "map": "de_mirage",
    }


def parse_nav(path: Path):
    data = path.read_bytes()
    magic, ver = struct.unpack_from("<II", data, 0)
    off = 8
    if ver >= 10:
        _sub = struct.unpack_from("<I", data, off)[0]
        off += 4
    if ver >= 4:
        off += 4  # bsp size
    if ver >= 14:
        off += 1  # analyzed
    places = []
    if ver >= 5:
        count = struct.unpack_from("<H", data, off)[0]
        off += 2
        for _ in range(count):
            ln = struct.unpack_from("<H", data, off)[0]
            off += 2
            name = data[off : off + ln].split(b"\x00")[0].decode("utf-8", "replace")
            off += ln
            places.append(name)
    has_unnamed = False
    if ver >= 5:
        has_unnamed = data[off] != 0
        off += 1
    areas = []
    try:
        area_count = struct.unpack_from("<I", data, off)[0]
        off += 4
        for _ in range(area_count):
            aid = struct.unpack_from("<I", data, off)[0]
            off += 4
            flags = struct.unpack_from("<I", data, off)[0]
            off += 4
            nw_x, nw_y, nw_z = struct.unpack_from("<fff", data, off)
            off += 12
            se_x, se_y, se_z = struct.unpack_from("<fff", data, off)
            off += 12
            ne_z, sw_z = struct.unpack_from("<ff", data, off)
            off += 8
            for _d in range(4):
                nconn = struct.unpack_from("<I", data, off)[0]
                off += 4
                off += 4 * nconn
            # hiding spots
            nhide = struct.unpack_from("<B", data, off)[0]
            off += 1
            off += nhide * (4 + 12 + 1)  # id + pos + attrs  (approx)
            # approach spots skipped in v15+? version 16 may differ.
            # This parser is best-effort; if it desyncs we keep places only.
            place_id = 0
            gx0, gy0, gz0 = src_to_godot(nw_x, nw_y, nw_z)
            gx1, gy1, gz1 = src_to_godot(se_x, se_y, se_z)
            areas.append(
                {
                    "id": aid,
                    "flags": flags,
                    "nw": [gx0, gy0, gz0],
                    "se": [gx1, gy1, gz1],
                    "place": place_id,
                }
            )
            # Too version-sensitive after this; stop if remaining looks implausible
            if off >= len(data) - 8:
                break
    except Exception as ex:
        print("nav area parse truncated:", ex)
        areas = []
    # Re-parse areas with a more conservative approach: only store places
    # and use spawn-derived waypoints if area parse is untrustworthy.
    return {"places": places, "areas": areas, "version": ver}


def parse_nav_areas_v16(path: Path, places: list[str]):
    """Parse CS:GO nav areas (version 16) for bot routing."""
    data = path.read_bytes()
    # We already consumed header in parse_nav; redo with known layout from Source SDK
    magic, ver = struct.unpack_from("<II", data, 0)
    off = 8
    off += 4  # subversion
    off += 4  # bsp size
    off += 1  # analyzed
    nplaces = struct.unpack_from("<H", data, off)[0]
    off += 2
    for _ in range(nplaces):
        ln = struct.unpack_from("<H", data, off)[0]
        off += 2 + ln
    off += 1  # unnamed areas
    area_count = struct.unpack_from("<I", data, off)[0]
    off += 4
    areas = []
    ok = True
    for i in range(area_count):
        try:
            aid = struct.unpack_from("<I", data, off)[0]
            off += 4
            flags = struct.unpack_from("<I", data, off)[0]
            off += 4
            nw = struct.unpack_from("<fff", data, off)
            off += 12
            se = struct.unpack_from("<fff", data, off)
            off += 12
            ne_z, sw_z = struct.unpack_from("<ff", data, off)
            off += 8
            conns = []
            for _d in range(4):
                nconn = struct.unpack_from("<I", data, off)[0]
                off += 4
                ids = list(struct.unpack_from(f"<{nconn}I", data, off)) if nconn else []
                off += 4 * nconn
                conns.append(ids)
            nhide = data[off]
            off += 1
            hides = []
            for _ in range(nhide):
                hid = struct.unpack_from("<I", data, off)[0]
                off += 4
                hp = struct.unpack_from("<fff", data, off)
                off += 12
                hat = data[off]
                off += 1
                hides.append(hp)
            # encounter paths
            nenc = struct.unpack_from("<I", data, off)[0]
            off += 4
            for _ in range(nenc):
                off += 4 + 1 + 4 + 1  # from id, from dir, to id, to dir
                nspots = data[off]
                off += 1
                off += nspots * 6  # packed spots (uint32 id + byte order? actually 5 bytes + pad)
            # place
            place = struct.unpack_from("<H", data, off)[0]
            off += 2
            # ladders 2 dirs
            for _ in range(2):
                nl = struct.unpack_from("<I", data, off)[0]
                off += 4 + 4 * nl
            off += 4  # earliest occupy times * 2 floats? actually 2 floats = 8
            off += 4
            # light intensity 4 floats
            off += 16
            # vis area ids
            nvis = struct.unpack_from("<I", data, off)[0]
            off += 4 + 4 * nvis
            # inheritance
            off += 4
            cx = (nw[0] + se[0]) * 0.5
            cy = (nw[1] + se[1]) * 0.5
            cz = (nw[2] + se[2]) * 0.5
            g = src_to_godot(cx, cy, cz)
            pname = places[place - 1] if 1 <= place <= len(places) else ""
            areas.append(
                {
                    "id": aid,
                    "center": list(g),
                    "place": pname,
                    "conns": [x for d in conns for x in d],
                }
            )
        except Exception as ex:
            print("nav desync at area", i, "off", off, ex)
            ok = False
            break
    print(f"nav areas parsed {len(areas)}/{area_count} ok={ok}")
    return areas if ok else []


def write_radar(visual_tris, ents, path: Path):
    # bounds in godot XZ
    xs, zs = [], []
    for cat, tris in visual_tris.items():
        if cat == "glass":
            continue
        for t in tris:
            for v in t:
                x, y, z = src_to_godot(vcomp(v.position, 0), vcomp(v.position, 1), vcomp(v.position, 2))
                xs.append(x)
                zs.append(z)
    minx, maxx = min(xs), max(xs)
    minz, maxz = min(zs), max(zs)
    pad = 4.0
    minx -= pad
    maxx += pad
    minz -= pad
    maxz += pad
    w = 1024
    h = 1024
    img = Image.new("RGBA", (w, h), (12, 18, 14, 255))
    draw = ImageDraw.Draw(img)

    def proj(x, z):
        px = int((x - minx) / (maxx - minx) * (w - 1))
        pz = int((z - minz) / (maxz - minz) * (h - 1))
        return px, pz

    # draw filled tris colored by category
    cat_col = {
        "sand": (196, 168, 118, 255),
        "plaster": (210, 190, 160, 255),
        "brick": (170, 120, 80, 255),
        "wood": (110, 80, 50, 255),
        "metal": (80, 80, 85, 255),
        "tile": (160, 140, 120, 255),
        "concrete": (140, 130, 115, 255),
        "market": (160, 90, 50, 255),
        "default": (160, 140, 110, 255),
        "trim": (90, 70, 50, 255),
        "marble": (200, 190, 180, 255),
        "green": (70, 110, 60, 255),
    }
    for cat, tris in visual_tris.items():
        col = cat_col.get(cat, (150, 140, 120, 255))
        for t in tris:
            pts = []
            ys = []
            for v in t:
                x, y, z = src_to_godot(vcomp(v.position, 0), vcomp(v.position, 1), vcomp(v.position, 2))
                pts.append(proj(x, z))
                ys.append(y)
            if max(ys) - min(ys) > 3.5:
                continue  # skip tall walls to keep floorplan readable
            if max(ys) > 4.5:
                continue
            draw.polygon(pts, fill=col)
    # sites
    for site in ents.get("bomb_sites", []):
        c = site["center"]
        px, pz = proj(c[0], c[2])
        draw.ellipse((px - 10, pz - 10, px + 10, pz + 10), outline=(230, 200, 40), width=3)
        draw.text((px + 12, pz - 8), site.get("name", "?"), fill=(230, 200, 40))
    for s in ents.get("t_spawns", []):
        px, pz = proj(s["origin"][0], s["origin"][2])
        draw.rectangle((px - 2, pz - 2, px + 2, pz + 2), fill=(210, 170, 50))
    for s in ents.get("ct_spawns", []):
        px, pz = proj(s["origin"][0], s["origin"][2])
        draw.rectangle((px - 2, pz - 2, px + 2, pz + 2), fill=(80, 140, 210))
    img = img.transpose(Image.FLIP_TOP_BOTTOM)
    img.save(path)
    meta = {"min": [minx, minz], "max": [maxx, maxz], "size": [w, h]}
    return meta


def write_collision_obj(collision, path: Path):
    """Godot can use a simplified collision mesh. Write OBJ for trimesh import."""
    # downsample: keep every triangle but weld vertices
    vmap = {}
    verts = []
    faces = []

    def vid(x, y, z):
        k = (round(x, 3), round(y, 3), round(z, 3))
        if k not in vmap:
            vmap[k] = len(verts)
            verts.append(k)
        return vmap[k] + 1

    for t in collision:
        ids = []
        ok = True
        for v in t:
            x, y, z = src_to_godot(vcomp(v.position, 0), vcomp(v.position, 1), vcomp(v.position, 2))
            ids.append(vid(x, y, z))
        if len(set(ids)) == 3:
            faces.append(ids)
    with path.open("w") as f:
        f.write("# de_mirage collision\n")
        for v in verts:
            f.write(f"v {v[0]} {v[1]} {v[2]}\n")
        for a, b, c in faces:
            f.write(f"f {a} {b} {c}\n")
    print(f"collision verts {len(verts)} faces {len(faces)}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("loading BSP", BSP_PATH)
    bsp = bsp_tool.load_bsp(str(BSP_PATH))
    tex_files = make_category_textures(OUT_DIR / "textures")
    visual, collision = collect_meshes(bsp)
    print("visual cats", {k: len(v) for k, v in visual.items()})
    print("collision tris", len(collision))
    prims = {}
    for cat, tris in visual.items():
        pb = PrimBuilder()
        albedo = tuple(c / 255.0 for c in CATEGORY_COLORS.get(cat, CATEGORY_COLORS["default"]))
        for t in tris:
            pb.add_tri(t, albedo)
        prims[cat] = pb
    write_glb(OUT_DIR / "de_mirage.glb", prims, tex_files)
    ents = parse_entities(bsp)
    nav = parse_nav(NAV_PATH)
    areas = parse_nav_areas_v16(NAV_PATH, nav["places"])
    nav["areas"] = areas
    radar_meta = write_radar(visual, ents, OUT_DIR / "radar.png")
    ents["radar"] = radar_meta
    ents["places"] = nav["places"]
    (OUT_DIR / "entities.json").write_text(json.dumps(ents, indent=2))
    (OUT_DIR / "nav.json").write_text(json.dumps(nav))
    write_collision_obj(collision, OUT_DIR / "collision.obj")
    print("done", OUT_DIR)
    print("T spawns", len(ents["t_spawns"]), "CT", len(ents["ct_spawns"]), "sites", ents["bomb_sites"], "props", len(ents["props"]))


if __name__ == "__main__":
    main()
