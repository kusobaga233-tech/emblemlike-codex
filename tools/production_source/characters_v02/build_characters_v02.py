# UTF-8
"""Deterministically build Chapter One character/weapon production candidates.

These are original, project-authored stylized game meshes derived from the approved
silhouette references. They are production candidates, not commercial-final art.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = Path(__file__).resolve().parents[3]
MODEL_DIR = PROJECT_ROOT / "assets" / "production" / "models"
WEAPON_DIR = PROJECT_ROOT / "assets" / "production" / "weapons"
REPORT_PATH = MODEL_DIR / "characters_v02_report.json"
ANIMATIONS = ("idle", "locomotion", "attack_primary", "attack_secondary", "hit", "defeat", "select", "victory")

CHARACTERS = {
    "hero_ash_vanguard": {"kind": "hero", "weapon": "ash_lance", "scale": (1.12, 1.02, 1.0), "colors": ((0.10, 0.18, 0.27), (0.45, 0.24, 0.08), (0.80, 0.47, 0.12), (0.05, 0.07, 0.09))},
    "hero_starbound_mender": {"kind": "hero", "weapon": "mender_staff", "scale": (0.92, 0.92, 1.02), "colors": ((0.10, 0.25, 0.30), (0.18, 0.48, 0.46), (0.75, 0.65, 0.34), (0.04, 0.07, 0.10))},
    "hero_cinder_seer": {"kind": "hero", "weapon": "cinder_focus", "scale": (0.82, 0.88, 1.06), "colors": ((0.30, 0.08, 0.08), (0.54, 0.16, 0.06), (1.0, 0.30, 0.05), (0.07, 0.03, 0.04))},
    "enemy_ember_husk": {"kind": "enemy", "weapon": "oathblade", "scale": (0.88, 0.86, 0.92), "colors": ((0.16, 0.12, 0.11), (0.28, 0.16, 0.10), (0.72, 0.16, 0.035), (0.035, 0.025, 0.025))},
    "enemy_void_lancer": {"kind": "enemy", "weapon": "ash_lance", "scale": (0.88, 0.92, 1.08), "colors": ((0.08, 0.07, 0.14), (0.18, 0.10, 0.28), (0.42, 0.12, 0.75), (0.025, 0.02, 0.04))},
}


def clear_scene():
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)


def mat(name, color, metallic=0.15, roughness=0.55, emission=False):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.2
    return material


def apply_bevel(obj, width=0.025, segments=2):
    bevel = obj.modifiers.new("AuthoredEdge", "BEVEL")
    bevel.width = width
    bevel.segments = segments
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)


def cube(name, location, size, material, rotation=(0, 0, 0), bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = tuple(value * 0.5 for value in size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        apply_bevel(obj, bevel)
    return obj


def sphere(name, location, scale, material, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return obj


def cylinder(name, location, radius, depth, material, vertices=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    apply_bevel(obj, min(radius * 0.18, 0.018), 2)
    return obj


def cone(name, location, r1, r2, depth, material, vertices=12, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def weapon_geometry(name, materials, attached=False):
    steel, accent, glow, dark = materials
    parts = []
    if name == "oathblade":
        parts += [cube("Oathblade_Blade", (0, 0, 0.58), (0.09, 0.035, 1.02), steel, rotation=(0, 0, -0.08), bevel=0.012)]
        parts += [cone("Oathblade_Tip", (-0.04, 0, 1.17), 0.07, 0, 0.25, steel, vertices=4, rotation=(0, 0.08, 0))]
        parts += [cube("Oathblade_Guard", (0.04, 0, 0.08), (0.42, 0.07, 0.08), accent, bevel=0.015), cylinder("Oathblade_Grip", (0.04, 0, -0.15), 0.045, 0.38, dark)]
    elif name == "ash_lance":
        parts += [cylinder("AshLance_Shaft", (0, 0, 0.58), 0.038, 2.35, dark, rotation=(0, 0, 0))]
        parts += [cone("AshLance_Head", (0, 0, 1.95), 0.16, 0, 0.62, steel, vertices=6), cube("AshLance_Fin", (0, 0, 1.62), (0.34, 0.06, 0.22), accent, rotation=(0, 0, 0.45), bevel=0.01)]
    elif name == "mender_staff":
        parts += [cylinder("MenderStaff_Shaft", (0, 0, 0.78), 0.035, 2.05, dark)]
        parts += [sphere("MenderStaff_Core", (0, 0, 1.92), (0.16, 0.16, 0.16), glow, 12, 8)]
        for angle in (0, math.pi * 0.5):
            parts.append(cube("MenderStaff_Halo", (0, 0, 1.92), (0.42, 0.025, 0.055), accent, rotation=(0, angle, angle), bevel=0.01))
    elif name == "cinder_focus":
        parts += [sphere("CinderFocus_Core", (0, 0, 0.48), (0.17, 0.12, 0.22), glow, 12, 8)]
        for angle in (0, 2.094, 4.188):
            parts.append(cone("CinderFocus_Shard", (math.cos(angle)*0.26, math.sin(angle)*0.26, 0.48), 0.08, 0, 0.34, accent, vertices=5, rotation=(0.4, angle, 0)))
        parts += [cylinder("CinderFocus_Grip", (0, 0, -0.02), 0.04, 0.55, dark)]
    elif name == "star_eater_core":
        parts += [sphere("StarEater_Core", (0, 0, 0), (0.30, 0.30, 0.30), glow, 16, 10)]
        for angle in (0, 1.57, 3.14, 4.71):
            parts.append(cone("StarEater_Spike", (math.cos(angle)*0.38, math.sin(angle)*0.38, 0), 0.12, 0, 0.52, dark, vertices=5, rotation=(0, math.pi*0.5, angle)))
    if attached:
        for obj in parts:
            obj.location += Vector((0.55, -0.03, 1.10))
    return parts


def create_rig():
    armature_data = bpy.data.armatures.new("SharedHumanoidRig")
    rig = bpy.data.objects.new("Rig", armature_data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = {
        "root": ((0, 0, 0), (0, 0, 0.18), None),
        "pelvis": ((0, 0, 0.65), (0, 0, 0.90), "root"),
        "spine": ((0, 0, 0.90), (0, 0, 1.38), "pelvis"),
        "head": ((0, 0, 1.38), (0, 0, 1.82), "spine"),
        "upper_arm_l": ((0, 0, 1.33), (-0.43, 0, 1.27), "spine"),
        "forearm_l": ((-0.43, 0, 1.27), (-0.72, 0, 1.08), "upper_arm_l"),
        "upper_arm_r": ((0, 0, 1.33), (0.43, 0, 1.27), "spine"),
        "forearm_r": ((0.43, 0, 1.27), (0.72, 0, 1.08), "upper_arm_r"),
        "hand_r_weapon": ((0.72, 0, 1.08), (0.90, 0, 1.04), "forearm_r"),
        "thigh_l": ((-0.16, 0, 0.70), (-0.18, 0, 0.35), "pelvis"),
        "shin_l": ((-0.18, 0, 0.35), (-0.18, 0, 0.03), "thigh_l"),
        "thigh_r": ((0.16, 0, 0.70), (0.18, 0, 0.35), "pelvis"),
        "shin_r": ((0.18, 0, 0.35), (0.18, 0, 0.03), "thigh_r"),
    }
    made = {}
    for name, (head, tail, parent) in bones.items():
        bone = armature_data.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        if parent:
            bone.parent = made[parent]
        made[name] = bone
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin_to_bone(obj, rig, bone_name):
    obj.parent = rig
    modifier = obj.modifiers.new("ArmatureDeform", "ARMATURE")
    modifier.object = rig
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def armor_character(asset_id, spec, materials, rig):
    primary, secondary, glow, dark = materials
    sx, sy, sz = spec["scale"]
    parts = []
    def add(obj, bone):
        skin_to_bone(obj, rig, bone)
        parts.append(obj)
    add(cube("Torso_Underlayer", (0, 0, 1.15), (0.52*sx, 0.30*sy, 0.62*sz), dark, bevel=0.055), "spine")
    add(cube("Chest_Armor", (0, -0.035, 1.26), (0.63*sx, 0.26*sy, 0.36*sz), primary, bevel=0.07), "spine")
    add(cube("Waist_Belt", (0, 0, 0.88), (0.55*sx, 0.31*sy, 0.13), secondary, bevel=0.035), "pelvis")
    add(sphere("Helmet", (0, 0, 1.62*sz), (0.22*sx, 0.20*sy, 0.25), primary), "head")
    add(cube("Visor", (0, -0.19*sy, 1.64*sz), (0.30*sx, 0.035, 0.085), glow, bevel=0.015), "head")
    for side, sign in (("L", -1), ("R", 1)):
        add(sphere("Pauldron_"+side, (0.38*sign*sx, 0, 1.34), (0.18*sx, 0.20*sy, 0.14), secondary), "upper_arm_"+side.lower())
        add(cylinder("Bracer_"+side, (0.57*sign*sx, 0, 1.15), 0.09*sx, 0.34, primary, rotation=(0, math.pi*0.5, 0)), "forearm_"+side.lower())
        add(cube("ThighPlate_"+side, (0.17*sign*sx, 0, 0.61), (0.22*sx, 0.27*sy, 0.40), primary, bevel=0.055), "thigh_"+side.lower())
        add(cube("Greave_"+side, (0.18*sign*sx, -0.02, 0.22), (0.19*sx, 0.24*sy, 0.35), secondary, bevel=0.045), "shin_"+side.lower())
    if asset_id == "hero_ash_vanguard":
        add(cube("Tower_Shield", (-0.69, 0.02, 1.02), (0.55, 0.12, 1.12), primary, rotation=(0, 0, -0.12), bevel=0.09), "forearm_l")
        add(cube("Shield_Ridge", (-0.70, -0.08, 1.02), (0.13, 0.06, 0.94), glow, bevel=0.025), "forearm_l")
        add(cube("Vanguard_Backplate", (0, 0.18, 1.25), (0.58, 0.12, 0.54), secondary, bevel=0.07), "spine")
    elif asset_id == "hero_starbound_mender":
        add(cone("Mender_Mantle", (0, 0.08, 1.17), 0.46, 0.29, 0.68, primary, vertices=12), "spine")
        for sign in (-1, 1):
            add(cube("Mender_Ribbon", (0.28*sign, 0.12, 0.76), (0.10, 0.06, 0.62), secondary, rotation=(0, 0, 0.12*sign), bevel=0.02), "pelvis")
    elif asset_id == "hero_cinder_seer":
        add(cone("Seer_Robe", (0, 0.06, 0.77), 0.46, 0.25, 0.94, primary, vertices=12), "pelvis")
        add(cone("Seer_Hood", (0, 0.04, 1.69), 0.31, 0.08, 0.48, secondary, vertices=12), "head")
        for sign in (-1, 1):
            add(cone("Cinder_Shard", (0.32*sign, 0.11, 1.52), 0.09, 0, 0.35, glow, vertices=5, rotation=(0.25, 0.2*sign, 0)), "spine")
    elif asset_id == "enemy_ember_husk":
        rig.pose.bones["spine"].rotation_euler.x = 0.15
        add(cube("Broken_Plate", (0.18, -0.15, 1.23), (0.27, 0.08, 0.44), secondary, rotation=(0.12, 0.1, -0.18), bevel=0.04), "spine")
        add(cone("Charred_Spike", (-0.24, 0.10, 1.48), 0.09, 0, 0.35, dark, vertices=5, rotation=(0.5, -0.4, 0)), "spine")
    elif asset_id == "enemy_void_lancer":
        add(cone("Void_Crest", (0, 0.04, 1.93), 0.16, 0, 0.50, glow, vertices=5), "head")
        for sign in (-1, 1):
            add(cone("Void_Shoulder_Fin", (0.42*sign, 0.05, 1.48), 0.12, 0, 0.46, secondary, vertices=5, rotation=(0.3, 0.5*sign, 0)), "upper_arm_"+("l" if sign < 0 else "r"))
    weapon_parts = weapon_geometry(spec["weapon"], materials, attached=True)
    for obj in weapon_parts:
        skin_to_bone(obj, rig, "hand_r_weapon")
        parts.append(obj)
    return parts


def make_actions(rig):
    poses = {
        "idle": {"spine": (0.02, 0, 0)},
        "locomotion": {"thigh_l": (0.48, 0, 0), "thigh_r": (-0.48, 0, 0), "upper_arm_l": (-0.25, 0, 0), "upper_arm_r": (0.25, 0, 0)},
        "attack_primary": {"spine": (0, 0, -0.28), "upper_arm_r": (-0.95, 0.15, -0.42), "forearm_r": (-0.60, 0, 0)},
        "attack_secondary": {"spine": (-0.15, 0.18, 0.34), "upper_arm_l": (-0.72, 0, 0.55), "upper_arm_r": (-0.45, 0, -0.62)},
        "hit": {"spine": (-0.30, 0, 0.25), "head": (0.18, 0, -0.12)},
        "defeat": {"root": (0, 1.25, 0), "spine": (-0.55, 0, 0)},
        "select": {"spine": (-0.08, 0, 0), "head": (-0.12, 0, 0), "upper_arm_r": (-0.18, 0, -0.15)},
        "victory": {"upper_arm_r": (-1.65, 0, -0.20), "forearm_r": (-0.45, 0, 0), "head": (-0.18, 0, 0)},
    }
    rig.animation_data_create()
    for action_name, end_pose in poses.items():
        action = bpy.data.actions.new(action_name)
        rig.animation_data.action = action
        for bone in rig.pose.bones:
            bone.rotation_euler = (0, 0, 0)
            bone.keyframe_insert("rotation_euler", frame=1, group=bone.name)
        for bone_name, rotation in end_pose.items():
            rig.pose.bones[bone_name].rotation_euler = rotation
        for bone in rig.pose.bones:
            bone.keyframe_insert("rotation_euler", frame=16, group=bone.name)
        action.frame_start, action.frame_end = 1, 16
        action.use_fake_user = True
    rig.animation_data.action = bpy.data.actions.get("idle")


def triangle_count(objects):
    total = 0
    for obj in objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            total += len(obj.data.loop_triangles)
    return total


def export_character(asset_id, spec):
    clear_scene()
    colors = spec["colors"]
    materials = [mat("MAT_Primary", colors[0], 0.42, 0.42), mat("MAT_Secondary", colors[1], 0.58, 0.35), mat("MAT_Glow", colors[2], 0.12, 0.25, True), mat("MAT_Underlayer", colors[3], 0.05, 0.78)]
    rig = create_rig()
    parts = armor_character(asset_id, spec, materials, rig)
    make_actions(rig)
    blend_path = ROOT / f"{asset_id}.blend"
    glb_path = MODEL_DIR / f"{asset_id}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", export_animations=True, export_animation_mode="ACTIONS", export_skins=True)
    return {"path": str(glb_path.relative_to(PROJECT_ROOT)).replace("\\", "/"), "triangles": triangle_count(parts), "materials": len(materials), "animations": list(ANIMATIONS), "bones": len(rig.data.bones), "weighted_bones": sorted({group.name for obj in parts for group in obj.vertex_groups}), "weapon": spec["weapon"], "blend_source": str(blend_path.relative_to(PROJECT_ROOT)).replace("\\", "/")}


def export_weapon(name):
    clear_scene()
    materials = [mat("MAT_WeaponMetal", (0.33, 0.37, 0.42), 0.75, 0.25), mat("MAT_WeaponAccent", (0.56, 0.30, 0.08), 0.55, 0.34), mat("MAT_WeaponGlow", (1.0, 0.20, 0.04), 0.1, 0.22, True), mat("MAT_WeaponGrip", (0.035, 0.03, 0.04), 0.0, 0.78)]
    parts = weapon_geometry(name, materials)
    blend_path = ROOT / f"weapon_{name}.blend"
    glb_path = WEAPON_DIR / f"{name}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB", export_animations=False)
    return {"path": str(glb_path.relative_to(PROJECT_ROOT)).replace("\\", "/"), "triangles": triangle_count(parts), "materials": len(materials), "blend_source": str(blend_path.relative_to(PROJECT_ROOT)).replace("\\", "/")}


def main():
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    WEAPON_DIR.mkdir(parents=True, exist_ok=True)
    report = {"generator": str(Path(__file__).relative_to(PROJECT_ROOT)).replace("\\", "/"), "status": "production_candidate_not_commercial_final", "characters": {}, "weapons": {}}
    for asset_id, spec in CHARACTERS.items():
        report["characters"][asset_id] = export_character(asset_id, spec)
    for weapon in ("oathblade", "ash_lance", "cinder_focus", "mender_staff", "star_eater_core"):
        report["weapons"][weapon] = export_weapon(weapon)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
