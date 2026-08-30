#!/usr/bin/env python3
"""Rebuild de_mirage collision.obj only (no GLB)."""
from convert_bsp import BSP_PATH, OUT_DIR, collect_meshes, write_collision_obj
import bsp_tool

def main() -> None:
    print("loading", BSP_PATH)
    bsp = bsp_tool.load_bsp(str(BSP_PATH))
    _visual, collision = collect_meshes(bsp)
    print("collision tris", len(collision))
    write_collision_obj(collision, OUT_DIR / "collision.obj")

if __name__ == "__main__":
    main()
