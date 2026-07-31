# UTF-8
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "assets" / "production" / "models" / "characters_v02_report.json"
REQUIRED = {"idle", "locomotion", "attack_primary", "attack_secondary", "hit", "defeat", "select", "victory"}

def glb_json(path):
    with path.open("rb") as stream:
        magic, version, _length = struct.unpack("<4sII", stream.read(12))
        if magic != b"glTF" or version != 2:
            raise ValueError(f"{path}: not a glTF 2 GLB")
        chunk_length, chunk_type = struct.unpack("<II", stream.read(8))
        if chunk_type != 0x4E4F534A:
            raise ValueError(f"{path}: first GLB chunk is not JSON")
        return json.loads(stream.read(chunk_length).decode("utf-8"))

def main():
    data = json.loads(REPORT.read_text(encoding="utf-8"))
    errors = []
    for name, item in data["characters"].items():
        limit = 35000 if name.startswith("hero_") else 18000
        if item["triangles"] > limit: errors.append(f"{name}: {item['triangles']} > {limit} triangles")
        if item["materials"] > 4: errors.append(f"{name}: {item['materials']} materials")
        if set(item["animations"]) != REQUIRED or len(item["animations"]) != len(REQUIRED): errors.append(f"{name}: report animation contract mismatch")
        if "hand_r_weapon" not in item["weighted_bones"]: errors.append(f"{name}: weapon is not weighted to hand_r_weapon")
        if len(item["weighted_bones"]) < 8: errors.append(f"{name}: insufficient distributed weighting")
        glb_path, blend_path = ROOT / item["path"], ROOT / item["blend_source"]
        if not glb_path.is_file() or not blend_path.is_file():
            errors.append(f"{name}: output/source missing")
        elif set(animation.get("name") for animation in glb_json(glb_path).get("animations", [])) != REQUIRED or len(glb_json(glb_path).get("animations", [])) != len(REQUIRED):
            actual = [animation.get("name") for animation in glb_json(glb_path).get("animations", [])]
            errors.append(f"{name}: actual GLB animations {actual} are not exactly the required set")
    for name, item in data["weapons"].items():
        if item["triangles"] > 8000: errors.append(f"{name}: {item['triangles']} > 8000 triangles")
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
