# UTF-8
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "assets" / "production" / "models" / "characters_v02_report.json"
REQUIRED = {"idle", "locomotion", "attack_primary", "attack_secondary", "hit", "defeat", "select", "victory"}

def main():
    data = json.loads(REPORT.read_text(encoding="utf-8"))
    errors = []
    for name, item in data["characters"].items():
        limit = 35000 if name.startswith("hero_") else 18000
        if item["triangles"] > limit: errors.append(f"{name}: {item['triangles']} > {limit} triangles")
        if item["materials"] > 4: errors.append(f"{name}: {item['materials']} materials")
        if set(item["animations"]) != REQUIRED: errors.append(f"{name}: animation contract mismatch")
        if "hand_r_weapon" not in item["weighted_bones"]: errors.append(f"{name}: weapon is not weighted to hand_r_weapon")
        if len(item["weighted_bones"]) < 8: errors.append(f"{name}: insufficient distributed weighting")
        if not (ROOT / item["path"]).is_file() or not (ROOT / item["blend_source"]).is_file(): errors.append(f"{name}: output/source missing")
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
