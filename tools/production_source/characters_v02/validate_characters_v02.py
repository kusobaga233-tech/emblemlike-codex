# UTF-8
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "assets" / "production" / "models" / "characters_v02_report.json"
REQUIRED = {"idle", "locomotion", "attack_primary", "attack_secondary", "hit", "defeat", "select", "victory"}
CHARACTERS = {"hero_ash_vanguard": "ash_lance", "hero_starbound_mender": "mender_staff", "hero_cinder_seer": "cinder_focus", "enemy_ember_husk": "oathblade", "enemy_void_lancer": "ash_lance"}
WEAPONS = {"oathblade", "ash_lance", "cinder_focus", "mender_staff", "star_eater_core"}

COMPONENTS = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
TYPE_WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

def matrix_multiply(a, b):
    return [[sum(a[row][k] * b[k][column] for k in range(4)) for column in range(4)] for row in range(4)]

def node_matrix(node):
    if "matrix" in node:
        values = node["matrix"]
        return [[values[column * 4 + row] for column in range(4)] for row in range(4)]
    x, y, z, w = node.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = node.get("scale", [1, 1, 1])
    tx, ty, tz = node.get("translation", [0, 0, 0])
    return [[(1-2*y*y-2*z*z)*sx, (2*x*y-2*z*w)*sy, (2*x*z+2*y*w)*sz, tx], [(2*x*y+2*z*w)*sx, (1-2*x*x-2*z*z)*sy, (2*y*z-2*x*w)*sz, ty], [(2*x*z-2*y*w)*sx, (2*y*z+2*x*w)*sy, (1-2*x*x-2*y*y)*sz, tz], [0, 0, 0, 1]]

def transform_point(matrix, point):
    return [sum(matrix[row][column] * ([*point, 1][column]) for column in range(4)) for row in range(3)]

def contract_errors(data):
    errors = []
    if not isinstance(data, dict) or set(data.get("characters", {})) != set(CHARACTERS): errors.append("character IDs must be exact and non-empty")
    if not isinstance(data, dict) or set(data.get("weapons", {})) != WEAPONS: errors.append("weapon IDs must be exact and non-empty")
    for name, weapon in CHARACTERS.items():
        item = data.get("characters", {}).get(name, {})
        if item.get("path") != f"assets/production/models/{name}.glb" or item.get("blend_source") != f"tools/production_source/characters_v02/{name}.blend" or item.get("weapon") != weapon: errors.append(f"{name}: canonical path/source/weapon mapping failed")
    for name in WEAPONS:
        item = data.get("weapons", {}).get(name, {})
        if item.get("path") != f"assets/production/weapons/{name}.glb" or item.get("blend_source") != f"tools/production_source/characters_v02/weapon_{name}.blend": errors.append(f"{name}: canonical weapon path/source failed")
    return errors

def read_glb(path):
    with path.open("rb") as stream:
        magic, version, _length = struct.unpack("<4sII", stream.read(12))
        if magic != b"glTF" or version != 2:
            raise ValueError(f"{path}: not a glTF 2 GLB")
        chunk_length, chunk_type = struct.unpack("<II", stream.read(8))
        if chunk_type != 0x4E4F534A:
            raise ValueError(f"{path}: first GLB chunk is not JSON")
        document = json.loads(stream.read(chunk_length).decode("utf-8"))
        binary = b""
        if stream.tell() < _length:
            binary_length, binary_type = struct.unpack("<II", stream.read(8))
            if binary_type == 0x004E4942:
                binary = stream.read(binary_length)
        return document, binary

def accessor_rows(document, binary, index):
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    fmt, component_size = COMPONENTS[accessor["componentType"]]
    width = TYPE_WIDTH[accessor["type"]]
    stride = view.get("byteStride", component_size * width)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [struct.unpack_from("<" + fmt * width, binary, offset + row * stride) for row in range(accessor["count"])]

def inspect_glb(path):
    document, binary = read_glb(path)
    triangles = 0
    material_indices = set()
    weighted_joint_indices = set()
    mesh_bounds = {}
    mesh_primitives = 0
    for mesh_index, mesh in enumerate(document.get("meshes", [])):
        mesh_min, mesh_max = [float("inf")]*3, [float("-inf")]*3
        for primitive in mesh.get("primitives", []):
            mesh_primitives += 1
            if primitive.get("mode", 4) != 4:
                raise ValueError(f"{path}: non-triangle primitive")
            count = document["accessors"][primitive["indices"]]["count"] if "indices" in primitive else document["accessors"][primitive["attributes"]["POSITION"]]["count"]
            triangles += count // 3
            if "material" in primitive: material_indices.add(primitive["material"])
            position = document["accessors"][primitive["attributes"]["POSITION"]]
            if "min" not in position or "max" not in position: raise ValueError(f"{path}: POSITION bounds missing")
            for axis in range(3):
                mesh_min[axis] = min(mesh_min[axis], position["min"][axis])
                mesh_max[axis] = max(mesh_max[axis], position["max"][axis])
            attrs = primitive["attributes"]
            if "JOINTS_0" in attrs and "WEIGHTS_0" in attrs:
                joints = accessor_rows(document, binary, attrs["JOINTS_0"])
                weights = accessor_rows(document, binary, attrs["WEIGHTS_0"])
                for joint_row, weight_row in zip(joints, weights):
                    for joint, weight in zip(joint_row, weight_row):
                        if weight > 0: weighted_joint_indices.add(joint)
        mesh_bounds[mesh_index] = (mesh_min, mesh_max)
    minimum, maximum = [float("inf")]*3, [float("-inf")]*3
    identity = [[1 if row == column else 0 for column in range(4)] for row in range(4)]
    def visit(index, parent):
        nonlocal minimum, maximum
        node = document["nodes"][index]
        world = matrix_multiply(parent, node_matrix(node))
        if "mesh" in node:
            low, high = mesh_bounds[node["mesh"]]
            for x in (low[0], high[0]):
                for y in (low[1], high[1]):
                    for z in (low[2], high[2]):
                        point = transform_point(world, (x, y, z))
                        for axis in range(3): minimum[axis], maximum[axis] = min(minimum[axis], point[axis]), max(maximum[axis], point[axis])
        for child in node.get("children", []): visit(child, world)
    scene = document.get("scenes", [{}])[document.get("scene", 0)]
    for root in scene.get("nodes", []): visit(root, identity)
    skins = document.get("skins", [])
    joint_nodes = skins[0].get("joints", []) if skins else []
    joint_names = [document["nodes"][node].get("name", "") for node in joint_nodes]
    weighted_names = sorted(joint_names[index] for index in weighted_joint_indices if index < len(joint_names))
    return {"triangles": triangles, "materials": len(material_indices), "mesh_primitives": mesh_primitives, "animations": [item.get("name") for item in document.get("animations", [])], "bones": len(joint_nodes), "bone_names": joint_names, "weighted_bones": weighted_names, "bounds": {"min": [round(value, 5) for value in minimum], "max": [round(value, 5) for value in maximum]}}

def main():
    data = json.loads(REPORT.read_text(encoding="utf-8"))
    errors = contract_errors(data)
    if errors:
        print("FAIL characters_v02\n" + "\n".join(errors))
        return 1
    for name, item in data["characters"].items():
        limit = 35000 if name.startswith("hero_") else 18000
        actual = inspect_glb(ROOT / item["path"])
        for field in ("triangles", "materials", "bones", "weighted_bones", "bounds"):
            if item.get(field) != actual[field]: errors.append(f"{name}: report {field}={item.get(field)} != GLB {actual[field]}")
        if actual["triangles"] > limit: errors.append(f"{name}: {actual['triangles']} > {limit} triangles")
        if actual["materials"] > 4: errors.append(f"{name}: {actual['materials']} materials")
        if set(item["animations"]) != REQUIRED or len(item["animations"]) != len(REQUIRED): errors.append(f"{name}: report animation contract mismatch")
        if "hand_r_weapon" not in item["weighted_bones"]: errors.append(f"{name}: weapon is not weighted to hand_r_weapon")
        if len(item["weighted_bones"]) < 8: errors.append(f"{name}: insufficient distributed weighting")
        glb_path, blend_path = ROOT / item["path"], ROOT / item["blend_source"]
        if not glb_path.is_file() or not blend_path.is_file():
            errors.append(f"{name}: output/source missing")
        elif actual["mesh_primitives"] < 1 or set(actual["animations"]) != REQUIRED or len(actual["animations"]) != len(REQUIRED) or "hand_r_weapon" not in actual["bone_names"]:
            errors.append(f"{name}: actual GLB mesh/animation/skeleton contract failed")
    for name, item in data["weapons"].items():
        actual = inspect_glb(ROOT / item["path"])
        for field in ("triangles", "materials", "bounds"):
            if item.get(field) != actual[field]: errors.append(f"{name}: report {field}={item.get(field)} != GLB {actual[field]}")
        if actual["triangles"] > 8000 or actual["mesh_primitives"] < 1 or actual["animations"] or actual["bones"]: errors.append(f"{name}: actual weapon GLB structure/budget failed")
        if not (ROOT / item["path"]).is_file() or not (ROOT / item["blend_source"]).is_file(): errors.append(f"{name}: output/source missing")
    if errors:
        print("FAIL characters_v02")
        print("\n".join(errors))
        return 1
    print("PASS characters_v02")
    for name, item in data["characters"].items(): print(f"{name}: {item['triangles']} tris, {item['materials']} mats, {len(item['animations'])} clips, {len(item['weighted_bones'])} weighted bones")
    for name, item in data["weapons"].items(): print(f"{name}: {item['triangles']} tris")
    return 0

if __name__ == "__main__":
    sys.exit(main())
