#!/usr/bin/env python3
"""Render compass location-kind icons with Blender.

Usage:
    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python scripts/blender/render_location_icons.py -- \
        --kinds city --out design/compass_icons --suffix -pass1

Each icon is a chibi miniature built from primitives, rendered at 512x512
with a transparent background through an orthographic 3/4 camera. Approved
renders are copied into assets/images/compass/<kind>.png (and the kind added
to _kRenderedIconKinds in compass_overlay.dart).
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# ---------------------------------------------------------------- palette

STONE = (0.55, 0.47, 0.36, 1.0)
STONE_DARK = (0.30, 0.25, 0.19, 1.0)
GOLD = (0.83, 0.55, 0.20, 1.0)  # matches the client's primary #D4A057
ROOF_RED = (0.42, 0.10, 0.07, 1.0)
GRASS = (0.22, 0.34, 0.16, 1.0)
WOOD_DARK = (0.16, 0.10, 0.06, 1.0)


def material(name, rgba, roughness=0.62):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


# ---------------------------------------------------------------- helpers

def _apply(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def sphere(location, scale, mat, segments=32):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=segments // 2, location=location
    )
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.shade_smooth()
    return _apply(obj, mat)


def cylinder(location, radius, depth, mat, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location
    )
    return _apply(bpy.context.object, mat)


def cone(location, radius, depth, mat, vertices=32):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=0,
        depth=depth, location=location,
    )
    return _apply(bpy.context.object, mat)


def box(location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return _apply(obj, mat)


# ------------------------------------------------------------ connectivity

def check_connectivity(max_gap=0.05):
    """Fail loudly when any mesh part floats free of the largest part.

    World-space, distance-only BVH check (per the hard-won rules: local-space
    nearest and matrix_world normal tricks both invent false connections).
    """
    # Scale/rotation set after primitive_add isn't in matrix_world until the
    # depsgraph re-evaluates — without this, checks run on stale transforms.
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    trees, verts = [], []
    for obj in meshes:
        world = [obj.matrix_world @ v.co for v in obj.data.vertices]
        polys = [p.vertices[:] for p in obj.data.polygons]
        trees.append(BVHTree.FromPolygons([v[:] for v in world], polys))
        verts.append(world)

    def touches(i, j):
        for v in verts[i]:
            hit = trees[j].find_nearest(v)
            if hit[0] is not None and hit[3] <= max_gap:
                return True
        return False

    sizes = [len(v) for v in verts]
    start = sizes.index(max(sizes))
    reached = {start}
    frontier = [start]
    while frontier:
        current = frontier.pop()
        for other in range(len(meshes)):
            if other in reached:
                continue
            if touches(current, other) or touches(other, current):
                reached.add(other)
                frontier.append(other)

    floating = [meshes[i] for i in range(len(meshes)) if i not in reached]
    for obj in floating:
        print(f"FLOATING PART: {obj.name} at {obj.location[:]}")
    if floating:
        sys.exit("Connectivity check failed — floating parts above.")
    print(f"Connectivity OK ({len(meshes)} parts)")


# ---------------------------------------------------------------- builders

def build_city():
    """Walled medieval city: gate wall, twin towers, central keep, banner."""
    stone = material("stone", STONE)
    stone_dark = material("stone_dark", STONE_DARK)
    gold = material("gold", GOLD, roughness=0.45)
    roof = material("roof", ROOF_RED)
    grass = material("grass", GRASS, roughness=0.8)
    wood = material("wood", WOOD_DARK, roughness=0.7)

    # Grounding base.
    cylinder((0, 0, 0.06), 1.12, 0.12, grass, vertices=48)

    # Outer wall ring + darker parapet rim.
    cylinder((0, 0, 0.40), 0.85, 0.60, stone, vertices=48)
    cylinder((0, 0, 0.72), 0.90, 0.10, stone_dark, vertices=48)

    # Gate facing the camera (camera sits toward +X, -Y).
    gate_dir = Vector((1, -1, 0)).normalized()
    gate_pos = gate_dir * 0.80
    frame = box((gate_pos.x, gate_pos.y, 0.38), (0.34, 0.34, 0.5), stone_dark)
    frame.rotation_euler = (0, 0, math.atan2(gate_dir.y, gate_dir.x))
    door_pos = gate_dir * 0.94
    door = box((door_pos.x, door_pos.y, 0.32), (0.16, 0.18, 0.34), wood)
    door.rotation_euler = (0, 0, math.atan2(gate_dir.y, gate_dir.x))

    # Central keep with a gold roof. Runs all the way down to the base so
    # the connectivity check sees the whole spire chain grounded.
    cylinder((0, 0, 0.66), 0.42, 1.12, stone)
    cylinder((0, 0, 1.24), 0.47, 0.09, stone_dark)
    cone((0, 0, 1.52), 0.50, 0.52, roof)

    # Two wall towers, offset so both read from the 3/4 view.
    for tx, ty in ((-0.62, -0.56), (0.50, 0.68)):
        cylinder((tx, ty, 0.62), 0.20, 0.85, stone)
        cylinder((tx, ty, 1.06), 0.24, 0.07, stone_dark)
        cone((tx, ty, 1.28), 0.27, 0.36, gold)

    # Banner on the keep's spire.
    cylinder((0, 0, 1.92), 0.026, 0.46, wood, vertices=12)
    box((0.16, 0, 2.03), (0.32, 0.02, 0.18), gold)


BUILDERS = {
    "city": build_city,
}


# ------------------------------------------------------------------ scene

def setup_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.lights,
                  bpy.data.cameras):
        for item in list(block):
            if item.users == 0:
                block.remove(item)

    scene = bpy.context.scene
    # Blender 4.x calls Eevee "BLENDER_EEVEE_NEXT"; 5.x is back to
    # "BLENDER_EEVEE".
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    # AgX (the default) washes the palette out; icons want punchy color.
    scene.view_settings.view_transform = "Standard"

    # Orthographic 3/4 camera.
    bpy.ops.object.camera_add(location=(4.2, -4.2, 3.4))
    cam = bpy.context.object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.3
    direction = Vector((0, 0, 0.95)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    # Three-point lighting: warm key, cool fill, rim.
    bpy.ops.object.light_add(type="SUN", location=(3, -2, 6))
    key = bpy.context.object
    key.data.energy = 4.0
    key.data.color = (1.0, 0.93, 0.82)
    key.rotation_euler = (math.radians(35), math.radians(20), 0)

    bpy.ops.object.light_add(type="SUN", location=(-4, -3, 4))
    fill = bpy.context.object
    fill.data.energy = 1.4
    fill.data.color = (0.75, 0.82, 1.0)
    fill.rotation_euler = (math.radians(55), math.radians(-35), 0)

    bpy.ops.object.light_add(type="SUN", location=(0, 5, 5))
    rim = bpy.context.object
    rim.data.energy = 2.2
    rim.rotation_euler = (math.radians(-50), 0, 0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--kinds", default=",".join(BUILDERS))
    parser.add_argument("--out", default="design/compass_icons")
    parser.add_argument("--suffix", default="")
    args = parser.parse_args(argv)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    for kind in args.kinds.split(","):
        kind = kind.strip()
        if kind not in BUILDERS:
            sys.exit(f"No builder for kind '{kind}'. Have: {list(BUILDERS)}")
        setup_scene()
        BUILDERS[kind]()
        check_connectivity()
        target = out_dir / f"{kind}{args.suffix}.png"
        bpy.context.scene.render.filepath = str(target.resolve())
        bpy.ops.render.render(write_still=True)
        print(f"Rendered {target}")


if __name__ == "__main__":
    main()
