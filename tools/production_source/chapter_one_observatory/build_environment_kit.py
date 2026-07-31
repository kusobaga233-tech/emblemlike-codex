import bpy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = Path(__file__).resolve().parents[3]
EXPORT_DIR = PROJECT_ROOT / "assets" / "production" / "environment"
BLEND_PATH = ROOT / "chapter_one_observatory_kit.blend"
GLB_PATH = EXPORT_DIR / "chapter_one_observatory_kit.glb"
REPORT_PATH = EXPORT_DIR / "environment_kit_report.json"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def material(name, color, metallic, roughness, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.6
    return mat


def box(name, location, size, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("ProductionEdge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 11
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def join_module(name, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    module = bpy.context.object
    module.name = name
    module.data.name = f"MESH_{name}"
    return module


def create_floor(stone, brass, glass):
    parts = [box("floor_slab", (0, 0, 0.06), (0.96, 0.96, 0.12), stone)]
    parts += [box("floor_brass_x", (0, 0, 0.125), (0.78, 0.035, 0.018), brass, 0.006)]
    parts += [box("floor_brass_y", (0, 0, 0.125), (0.035, 0.78, 0.018), brass, 0.006)]
    parts += [box("floor_ember", (0, 0, 0.14), (0.12, 0.12, 0.025), glass, 0.012)]
    return join_module("Floor_1x1", parts)


def create_bridge(stone, brass, glass):
    parts = [box("bridge_slab", (2, 0, 0.10), (0.96, 0.94, 0.20), stone)]
    for x in (1.58, 2.42):
        parts.append(box("bridge_edge", (x, 0, 0.22), (0.08, 0.94, 0.14), brass, 0.015))
    for y in (-0.30, 0.0, 0.30):
        parts.append(box("bridge_glow", (2, y, 0.215), (0.62, 0.025, 0.025), glass, 0.005))
    return join_module("Bridge_1x1", parts)


def create_cover(stone, brass, glass):
    parts = [box("cover_base", (4, 0, 0.10), (0.86, 0.38, 0.20), stone)]
    parts.append(box("cover_wall", (4, 0, 0.38), (0.72, 0.24, 0.48), stone, 0.04))
    parts.append(box("cover_cap", (4, 0, 0.65), (0.78, 0.29, 0.08), brass, 0.018))
    parts.append(box("cover_ember", (4, -0.132, 0.43), (0.34, 0.025, 0.11), glass, 0.012))
    return join_module("Cover_Low_1x1", parts)


def create_ruin(stone, brass):
    parts = []
    for x, height in ((5.35, 1.18), (6.65, 0.82)):
        parts.append(box("ruin_pier", (x, 0, height * 0.5), (0.28, 0.34, height), stone, 0.045))
    parts.append(box("ruin_lintel", (5.88, 0, 1.08), (0.86, 0.32, 0.24), stone, 0.045))
    parts.append(box("ruin_trim", (5.88, -0.18, 1.08), (0.72, 0.035, 0.06), brass, 0.01))
    return join_module("Ruin_Arch_2x1", parts)


def bounds(obj):
    xs = [corner[0] for corner in obj.bound_box]
    ys = [corner[1] for corner in obj.bound_box]
    zs = [corner[2] for corner in obj.bound_box]
    return [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]


def main():
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    stone = material("MAT_ObservatoryStone", (0.12, 0.15, 0.20), 0.08, 0.72)
    brass = material("MAT_AgedBrass", (0.34, 0.22, 0.08), 0.72, 0.34)
    glass = material("MAT_EmberGlass", (0.13, 0.035, 0.015), 0.12, 0.28, (1.0, 0.16, 0.025))
    modules = [
        create_floor(stone, brass, glass),
        create_bridge(stone, brass, glass),
        create_cover(stone, brass, glass),
        create_ruin(stone, brass),
    ]
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB", export_animations=False)
    module_triangles = {obj.name: len(obj.data.loop_triangles) for obj in modules}
    report = {
        "asset": "chapter_one_observatory_kit",
        "grid_unit_metres": 1.0,
        "triangle_budget_per_module": {"minimum": 2000, "maximum": 12000},
        "triangles": sum(module_triangles.values()),
        "module_triangles": module_triangles,
        "modules": {obj.name: {"bounds_blender_xyz": bounds(obj)} for obj in modules},
        "materials": [stone.name, brass.name, glass.name],
        "collision_policy": "Godot pick shapes only; imported module geometry is render-only",
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
