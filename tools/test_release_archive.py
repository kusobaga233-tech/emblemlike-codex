"""Regression cases for inspecting actual exported resource graphs."""
import tempfile
import unittest
import zipfile
from pathlib import Path
from verify_release_archive import inspect_archive, REQUIRED

class ReleaseArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / "game.zip"
        self.files = {name: b"resource" for name in REQUIRED}
        self.files["assets/production/models/hero.glb.import"] = b'[remap]\npath="res://.godot/imported/hero.mesh"'
        self.files[".godot/imported/hero.mesh"] = b"mesh"

    def inspect(self):
        with zipfile.ZipFile(self.archive, "w") as pack:
            for name, content in self.files.items():
                pack.writestr(name, content)
        return inspect_archive(self.archive, self.root)

    def test_accepts_production_pack_with_complete_import_graph(self):
        self.assertTrue(self.inspect()["passed"])

    def test_rejects_each_development_resource_category(self):
        for prefix in ("assets/test/", "assets/production/concepts/", "src/qa/", "tests/", "tools/", "docs/", "build/"):
            with self.subTest(prefix=prefix):
                self.files[prefix + "unreviewed.gd"] = b"source"
                self.assertFalse(self.inspect()["passed"])
                del self.files[prefix + "unreviewed.gd"]

    def test_rejects_excluded_import_even_when_original_path_absent(self):
        sidecar = self.root / "assets/test/rejected.png.import"
        sidecar.parent.mkdir(parents=True)
        sidecar.write_text('[remap]\npath="res://.godot/imported/opaque-id.ctex"', encoding="utf-8")
        self.files[".godot/imported/opaque-id.ctex"] = b"texture"
        result = self.inspect()
        self.assertFalse(result["passed"])
        self.assertIn(".godot/imported/opaque-id.ctex", result["forbidden_entries"])

    def test_rejects_missing_chapter(self):
        del self.files["src/content/chapter_one.tres"]
        self.assertFalse(self.inspect()["passed"])

    def test_accepts_compiled_scene_only_with_present_target(self):
        del self.files["src/scenes/boot.tscn"]
        self.files["src/scenes/boot.tscn.remap"] = b'[remap]\npath="res://.godot/exported/boot.scn"'
        self.assertFalse(self.inspect()["passed"])
        self.files[".godot/exported/boot.scn"] = b"scene"
        self.assertTrue(self.inspect()["passed"])

    def test_rejects_missing_imported_model_target(self):
        del self.files[".godot/imported/hero.mesh"]
        self.assertFalse(self.inspect()["passed"])

if __name__ == "__main__":
    unittest.main()
