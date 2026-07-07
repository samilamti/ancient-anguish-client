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
STONE_LIGHT = (0.68, 0.63, 0.55, 1.0)
STONE_DARK = (0.30, 0.25, 0.19, 1.0)
GOLD = (0.83, 0.55, 0.20, 1.0)  # matches the client's primary #D4A057
ROOF_RED = (0.42, 0.10, 0.07, 1.0)
GRASS = (0.22, 0.34, 0.16, 1.0)
WOOD_DARK = (0.16, 0.10, 0.06, 1.0)
WOOD = (0.33, 0.21, 0.11, 1.0)
PLASTER = (0.72, 0.64, 0.50, 1.0)
LEAF = (0.18, 0.38, 0.14, 1.0)
LEAF_DARK = (0.13, 0.29, 0.10, 1.0)
WATER = (0.10, 0.28, 0.45, 1.0)
ROCK = (0.40, 0.38, 0.34, 1.0)
SAND = (0.76, 0.66, 0.42, 1.0)
WHITE = (0.85, 0.83, 0.78, 1.0)
FIRE = (0.95, 0.45, 0.10, 1.0)


def material(name, rgba, roughness=0.62, emission=0.0):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        # Blender 4+ renamed the input "Emission" → "Emission Color".
        key = ("Emission Color" if "Emission Color" in bsdf.inputs
               else "Emission")
        bsdf.inputs[key].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emission
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


def cylinder(location, radius, depth, mat, vertices=32, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location
    )
    obj = bpy.context.object
    obj.rotation_euler = rotation
    return _apply(obj, mat)


def cone(location, radius, depth, mat, vertices=32, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=0,
        depth=depth, location=location,
    )
    obj = bpy.context.object
    obj.rotation_euler = rotation
    return _apply(obj, mat)


def box(location, scale, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    obj.rotation_euler = rotation
    return _apply(obj, mat)


def ground(mat=None):
    """The 1.12-radius base disc every miniature stands on (z 0..0.12)."""
    return cylinder(
        (0, 0, 0.06), 1.12, 0.12,
        mat or material("grass", GRASS, roughness=0.8),
        vertices=48,
    )


def prism_roof(location, length, half_diag, mat):
    """Gabled roof: a cube rotated 45° around x. The side ridge vertices sit
    at ±half_diag in y — keep that within ~0.05 of the wall's half-depth and
    the roof center a hair above the wall top so connectivity holds."""
    side = half_diag * 2 / math.sqrt(2)
    return box(location, (length, side, side), mat,
               rotation=(math.radians(45), 0, 0))


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
    wood = material("wood_dark", WOOD_DARK, roughness=0.7)

    ground()

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


def build_village():
    """Three thatched cottages of falling size."""
    plaster = material("plaster", PLASTER)
    thatch = material("gold", GOLD, roughness=0.45)
    wood = material("wood_dark", WOOD_DARK, roughness=0.7)
    ground()

    cottages = [((-0.5, -0.25), 0.62), ((0.45, 0.2), 0.5), ((-0.1, 0.6), 0.42)]
    for (cx, cy), s in cottages:
        wall_h = 0.75 * s
        box((cx, cy, 0.10 + wall_h / 2), (s, s, wall_h), plaster)
        cone((cx, cy, 0.10 + wall_h + 0.22 * s), s * 0.85, 0.62 * s, thatch,
             vertices=8)
    # Door on the biggest cottage, facing the camera.
    box((-0.5 + 0.30, -0.25 - 0.30, 0.24), (0.14, 0.14, 0.26), wood,
        rotation=(0, 0, math.radians(45)))


def build_bridge():
    """Stone bridge over a stream."""
    stone = material("stone", STONE)
    stone_dark = material("stone_dark", STONE_DARK)
    water = material("water", WATER, roughness=0.25)
    ground()

    # The stream, crossing the base.
    box((0, 0, 0.10), (0.55, 2.0, 0.10), water)
    # Abutments on both banks.
    box((-0.55, 0, 0.22), (0.5, 0.42, 0.28), stone)
    box((0.55, 0, 0.22), (0.5, 0.42, 0.28), stone)
    # Arched deck: two slopes meeting a flat crown.
    box((0, 0, 0.42), (0.72, 0.36, 0.10), stone)
    box((-0.44, 0, 0.35), (0.52, 0.36, 0.09), stone,
        rotation=(0, math.radians(-18), 0))
    box((0.44, 0, 0.35), (0.52, 0.36, 0.09), stone,
        rotation=(0, math.radians(18), 0))
    # Parapets.
    box((0, -0.16, 0.51), (0.6, 0.05, 0.09), stone_dark)
    box((0, 0.16, 0.51), (0.6, 0.05, 0.09), stone_dark)
    # Dark arch under the crown.
    cylinder((0, 0, 0.16), 0.17, 0.5, stone_dark,
             rotation=(math.radians(90), 0, 0))


def build_cave():
    """Rocky hill with a dark mouth facing the camera."""
    rock = material("rock", ROCK, roughness=0.85)
    stone_dark = material("stone_dark", STONE_DARK)
    dark = material("cave_mouth", (0.03, 0.02, 0.02, 1.0), roughness=0.9)
    ground()

    sphere((0, 0.1, 0.55), (0.95, 0.85, 0.62), rock)
    sphere((-0.35, 0.45, 0.75), (0.5, 0.45, 0.4), rock)  # second knoll
    sphere((0.52, -0.42, 0.32), (0.30, 0.30, 0.32), dark)
    sphere((-0.78, -0.5, 0.2), (0.17, 0.15, 0.16), stone_dark)
    sphere((0.88, 0.28, 0.18), (0.13, 0.12, 0.13), stone_dark)


def build_temple():
    """Round colonnade with a gold roof."""
    stone_light = material("stone_light", STONE_LIGHT)
    gold = material("gold", GOLD, roughness=0.45)
    ground()

    cylinder((0, 0, 0.16), 0.80, 0.10, stone_light, vertices=48)
    cylinder((0, 0, 0.24), 0.70, 0.10, stone_light, vertices=48)
    for i in range(5):
        angle = math.radians(36 + i * 72)
        cylinder((0.48 * math.cos(angle), 0.48 * math.sin(angle), 0.60),
                 0.09, 0.62, stone_light)
    cylinder((0, 0, 0.95), 0.62, 0.10, stone_light, vertices=48)
    cone((0, 0, 1.14), 0.66, 0.32, gold, vertices=48)


def build_camp():
    """Two tents and a campfire."""
    roof = material("roof", ROOF_RED)
    gold = material("gold", GOLD, roughness=0.45)
    wood = material("wood", WOOD, roughness=0.75)
    dark = material("cave_mouth", (0.03, 0.02, 0.02, 1.0), roughness=0.9)
    fire = material("fire", FIRE, roughness=0.4, emission=4.0)
    ground()

    cone((-0.25, 0.15, 0.42), 0.55, 0.70, roof, vertices=10)
    cone((0.08, -0.18, 0.28), 0.16, 0.30, dark, vertices=10)  # tent opening
    cone((0.55, 0.52, 0.33), 0.38, 0.52, gold, vertices=10)
    # Campfire: crossed logs + flame.
    cylinder((0.45, -0.5, 0.16), 0.045, 0.44, wood,
             rotation=(math.radians(90), 0, math.radians(30)))
    cylinder((0.45, -0.5, 0.16), 0.045, 0.44, wood,
             rotation=(math.radians(90), 0, math.radians(-40)))
    sphere((0.45, -0.5, 0.26), (0.12, 0.12, 0.17), fire)


def build_fortress():
    """Square keep with corner turrets — sterner than the round city."""
    stone = material("stone", STONE)
    stone_dark = material("stone_dark", STONE_DARK)
    gold = material("gold", GOLD, roughness=0.45)
    wood = material("wood_dark", WOOD_DARK, roughness=0.7)
    ground()

    box((0, 0, 0.62), (1.1, 1.1, 1.05), stone)
    box((0, 0, 1.17), (0.95, 0.95, 0.10), stone_dark)  # parapet
    for mx, my in ((-0.42, -0.42), (0.42, -0.42), (-0.42, 0.42), (0.42, 0.42)):
        box((mx, my, 1.30), (0.16, 0.16, 0.16), stone_dark)
    box((0.56, -0.15, 0.32), (0.08, 0.30, 0.45), wood)  # gate
    for tx, ty in ((-0.55, -0.55), (0.55, 0.55)):
        cylinder((tx, ty, 0.72), 0.17, 1.35, stone)
        cone((tx, ty, 1.52), 0.23, 0.30, gold)
    cylinder((0, 0, 1.50), 0.026, 0.60, wood, vertices=12)
    box((0.15, 0, 1.70), (0.30, 0.02, 0.17), gold)


def build_hall():
    """Long gabled guild hall with a gold sign."""
    plaster = material("plaster", PLASTER)
    roof = material("roof_wood", (0.24, 0.13, 0.07, 1.0), roughness=0.7)
    gold = material("gold", GOLD, roughness=0.45)
    wood = material("wood_dark", WOOD_DARK, roughness=0.7)
    ground()

    box((0, 0, 0.35), (1.3, 0.58, 0.5), plaster)
    prism_roof((0, 0, 0.625), 1.45, 0.297, roof)
    box((0, -0.30, 0.30), (0.22, 0.03, 0.35), wood)   # double door
    box((0, -0.31, 0.55), (0.30, 0.02, 0.12), gold)   # sign board


def build_farm():
    """Red barn, silo, and golden field strips."""
    barn_red = material("roof", ROOF_RED)
    roof = material("roof_wood", (0.24, 0.13, 0.07, 1.0), roughness=0.7)
    stone_light = material("stone_light", STONE_LIGHT)
    gold = material("gold", GOLD, roughness=0.45)
    ground()

    for fx, fy_scale in ((0.34, 0.95), (0.6, 0.9), (0.86, 0.65)):
        box((fx, 0, 0.135), (0.18, fy_scale, 0.05), gold)
    box((-0.45, 0.1, 0.35), (0.7, 0.55, 0.5), barn_red)
    prism_roof((-0.45, 0.1, 0.62), 0.8, 0.26, roof)
    cylinder((-0.05, 0.62, 0.42), 0.18, 0.68, stone_light)
    cone((-0.05, 0.62, 0.80), 0.21, 0.24, gold)


def build_ruin():
    """Broken colonnade and crumbled wall."""
    rock = material("rock", ROCK, roughness=0.85)
    stone_dark = material("stone_dark", STONE_DARK)
    moss = material("grass", GRASS, roughness=0.8)
    ground()

    cylinder((-0.5, 0.3, 0.395), 0.14, 0.55, rock,
             rotation=(math.radians(6), math.radians(-4), 0))
    cylinder((0.1, 0.55, 0.545), 0.14, 0.85, rock,
             rotation=(math.radians(-7), math.radians(5), 0))
    cylinder((0.45, -0.1, 0.285), 0.14, 0.35, rock)
    # Fallen column across the ground.
    cylinder((-0.05, -0.5, 0.24), 0.13, 0.8, rock,
             rotation=(0, math.radians(90), math.radians(15)))
    # Crumbled wall, stepping down.
    box((0.6, 0.5, 0.28), (0.55, 0.15, 0.36), stone_dark,
        rotation=(0, 0, math.radians(-12)))
    box((0.72, 0.42, 0.48), (0.28, 0.15, 0.30), stone_dark,
        rotation=(0, math.radians(4), math.radians(-12)))
    sphere((-0.35, 0.32, 0.16), (0.14, 0.13, 0.12), moss)
    sphere((0.28, -0.42, 0.14), (0.12, 0.11, 0.10), moss)


def build_dwelling():
    """Single cozy cottage with a lit window."""
    plaster = material("plaster", PLASTER)
    roof = material("roof", ROOF_RED)
    stone_dark = material("stone_dark", STONE_DARK)
    wood = material("wood_dark", WOOD_DARK, roughness=0.7)
    glow = material("window", GOLD, roughness=0.3, emission=2.0)
    ground()

    box((0, 0, 0.38), (0.85, 0.7, 0.55), plaster)
    prism_roof((0, 0, 0.68), 1.0, 0.354, roof)
    box((-0.28, 0.12, 1.09), (0.14, 0.14, 0.35), stone_dark)  # chimney
    box((0, -0.36, 0.28), (0.20, 0.03, 0.32), wood)           # door
    box((0.26, -0.36, 0.45), (0.14, 0.02, 0.14), glow)        # window
    box((0.435, 0, 0.45), (0.02, 0.14, 0.14), glow)           # gable window


def build_coast():
    """Striped lighthouse on a sandy islet."""
    water = material("water", WATER, roughness=0.25)
    sand = material("sand", SAND, roughness=0.8)
    white = material("white", WHITE)
    red = material("roof", ROOF_RED)
    stone = material("stone", STONE)
    lamp = material("lamp", GOLD, roughness=0.3, emission=3.0)
    ground(water)

    cylinder((0, 0, 0.13), 0.62, 0.10, sand, vertices=48)
    cylinder((0, 0, 0.34), 0.22, 0.32, white)
    cylinder((0, 0, 0.64), 0.22, 0.28, red)
    cylinder((0, 0, 0.90), 0.22, 0.24, white)
    cylinder((0, 0, 1.10), 0.15, 0.16, lamp)
    cone((0, 0, 1.28), 0.19, 0.22, red)
    sphere((0.75, -0.55, 0.14), (0.14, 0.13, 0.12), stone)


def build_nature():
    """A great tree with a sapling and bush."""
    wood = material("wood", WOOD, roughness=0.75)
    leaf = material("leaf", LEAF, roughness=0.7)
    leaf_dark = material("leaf_dark", LEAF_DARK, roughness=0.7)
    ground()

    cylinder((0, 0, 0.45), 0.16, 0.75, wood)
    sphere((0, 0, 1.15), (0.55, 0.55, 0.50), leaf)
    sphere((-0.38, 0.15, 0.95), (0.38, 0.38, 0.34), leaf_dark)
    sphere((0.32, -0.25, 0.98), (0.36, 0.36, 0.32), leaf_dark)
    # Sapling.
    cylinder((-0.65, -0.38, 0.30), 0.08, 0.42, wood)
    sphere((-0.65, -0.38, 0.62), (0.26, 0.26, 0.24), leaf)
    # Bush.
    sphere((0.68, -0.45, 0.22), (0.20, 0.20, 0.17), leaf_dark)


def build_landmark():
    """Weathered monolith with a gold band, flanked by standing stones."""
    stone_light = material("stone_light", STONE_LIGHT)
    stone_dark = material("stone_dark", STONE_DARK)
    gold = material("gold", GOLD, roughness=0.45)
    ground()

    rot = (0, 0, math.radians(30))
    cone((0, 0, 0.85), 0.34, 1.5, stone_light, vertices=4, rotation=rot)
    # Gold plinth at the foot (grounded through the base disc — the tapered
    # shaft's slant faces are too far for a mid-shaft band), gem at the tip.
    box((0, 0, 0.16), (0.50, 0.50, 0.12), gold, rotation=rot)
    sphere((0, 0, 1.60), (0.11, 0.11, 0.15), gold)
    sphere((0.6, 0.35, 0.20), (0.16, 0.13, 0.22), stone_dark)
    sphere((-0.55, -0.45, 0.18), (0.13, 0.11, 0.18), stone_dark)


BUILDERS = {
    "city": build_city,
    "village": build_village,
    "bridge": build_bridge,
    "cave": build_cave,
    "temple": build_temple,
    "camp": build_camp,
    "fortress": build_fortress,
    "hall": build_hall,
    "farm": build_farm,
    "ruin": build_ruin,
    "dwelling": build_dwelling,
    "coast": build_coast,
    "nature": build_nature,
    "landmark": build_landmark,
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
