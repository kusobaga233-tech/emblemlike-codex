"""Inspect a real Godot ZIP export, including imported and converted resources."""
from pathlib import Path
import argparse
import json
import re
import zipfile

FORBIDDEN = ("assets/test/", "assets/production/concepts/", "src/qa/", "tests/", "tools/", "docs/", "build/")
REQUIRED = ("src/scenes/boot.tscn", "src/content/chapter_one.tres", "src/scenes/battle/battle_scene.tscn")

def inspect_archive(path, project_root):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        forbidden = [n for n in names if any(prefix in n for prefix in FORBIDDEN)]
        missing = [n for n in REQUIRED if not any(v == n or v == n + ".remap" for v in names)]
        broken_remaps = []
        for name in names:
            if name.endswith((".remap", ".import")):
                text = archive.read(name).decode("utf-8")
                for target in re.findall(r'(?:path|path\.[^=\s]+)="res://([^"\n]+)"', text):
                    if target not in names:
                        broken_remaps.append({"file": name, "target": target})
        # Godot stores imported textures/meshes under opaque cache paths. Inspect
        # excluded source sidecars too, so hiding only the original names cannot pass.
        leaked_cache = set()
        for prefix in FORBIDDEN:
            for sidecar in (project_root / prefix).rglob("*.import"):
                text = sidecar.read_text(encoding="utf-8")
                for target in re.findall(r'"res://(\.godot/imported/[^"\n]+)"', text):
                    if target in names:
                        leaked_cache.add(target)
        forbidden.extend(sorted(leaked_cache))
        models = [n for n in names if n.startswith("assets/production/models/")]
        if not models:
            missing.append("assets/production/models/*")
        return {"archive": str(path), "entry_count": len(names), "forbidden_entries": forbidden, "missing_required": missing, "broken_remaps": broken_remaps, "passed": not (forbidden or missing or broken_remaps)}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    result = inspect_archive(args.archive, args.project_root)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.report:
        args.report.write_text(output + "\n", encoding="utf-8")
    print(output)
    raise SystemExit(0 if result["passed"] else 1)
