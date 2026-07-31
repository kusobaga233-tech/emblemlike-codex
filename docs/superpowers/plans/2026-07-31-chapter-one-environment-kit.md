# Chapter One Environment Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or execute inline with strict RED/GREEN evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Chapter One arena floor primitives with the first Blender-authored observatory modular family while preserving deterministic grid interaction and tactical readability.

**Architecture:** One source `.blend` exports one GLB containing named floor, bridge, low-cover, and ruin modules on a one-metre grid. `GreyboxBoard` caches those imported mesh resources, keeps the existing per-cell pick-only collision contract, and places non-colliding decor under a separate root.

**Tech Stack:** Blender 4.x Python API, glTF/GLB, Godot 4.6.3, typed GDScript, repository TestCase runner.

## Global Constraints

- All authored text is UTF-8.
- Gameplay coordinates and pick collision remain one metre per grid cell.
- Decorative bridge, cover, and ruin geometry does not change pathfinding or physics blocking.
- Materials are original project-authored observatory stone, aged brass, and ember-glass surfaces.
- This slice is production advancement, not a claim of commercial-final environment art.

---

### Task 1: Specify the import and board contracts

**Files:**
- Create: `tests/test_environment_kit.gd`
- Modify: `tests/test_battle_scene.gd`
- Create: `tests/evidence/environment-kit-red.txt`

- [ ] Write assertions for the imported GLB, named modules, grid-safe bounds, material slots, board use of imported meshes, pick collision, and decor collision separation.
- [ ] Run the environment and battle tests and record the expected missing-asset/primitive failures.

### Task 2: Author and integrate the minimal modular family

**Files:**
- Create: `D:/godot-proj/star-ember-oath-blender/tools/build_environment_kit.py`
- Create: `D:/godot-proj/star-ember-oath-blender/chapter_one_observatory_kit.blend`
- Create: `assets/production/environment/chapter_one_observatory_kit.glb`
- Modify: `src/presentation/greybox_board.gd`
- Modify: `docs/asset-registry.csv`

- [ ] Generate original floor, bridge, low-cover, and ruin meshes with named production materials and metre-aligned dimensions.
- [ ] Export GLB and a triangle/bounds report from Blender.
- [ ] Load and cache imported mesh resources in `GreyboxBoard`; keep pick collisions explicit and place decor beneath `EnvironmentDecor`.
- [ ] Run import once, then run targeted tests until green.

### Task 3: Verify and commit

**Files:**
- Create: `tests/evidence/environment-kit-green.txt`

- [ ] Run Blender generation/report checks, targeted Godot tests, and the full Godot suite.
- [ ] Inspect the diff for unrelated work and confirm the source `.blend` and exported GLB are both present.
- [ ] Commit the scoped source, runtime assets, tests, evidence, plan, and registry update.
