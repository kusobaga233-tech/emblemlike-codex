# Battle Camera and Atmosphere Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the default Chapter One battle view readable at character scale while retaining a safe full-board overview and adding collision-free observatory atmosphere.

**Architecture:** TacticalCamera keeps full-board reset semantics and gains a bounded local group-framing mode derived from world-space points. BattleScene invokes that mode only after unit construction. GreyboxBoard builds render-only perimeter and distant atmosphere from the existing imported kit plus inexpensive procedural meshes; capture tooling records the genuine default after warmup.

**Tech Stack:** Godot 4.6, typed GDScript, imported GLB environment kit, headless integration tests.

## Global Constraints

- Preserve deterministic gameplay state and all legal camera orbit/zoom clamps.
- Keep atmosphere render-only and collision-free.
- Verify 16:9 projected unit placement against the 388 px left HUD.
- Capture the genuine default view, not a QA-only camera override.
- Do not claim commercial-final quality.

---

### Task 1: Local group framing

**Files:**
- Modify: `tests/test_battle_scene.gd`
- Modify: `src/presentation/tactical_camera.gd`
- Modify: `src/scenes/battle/battle_scene.gd`

**Interfaces:**
- Produces: `frame_group(points: Array[Vector3]) -> void`, `reset_view() -> void`, and local framing state/metrics.

- [ ] Write tests proving the API is absent or default battle projection remains too small/under the HUD.
- [ ] Run the battle-scene worker and record the expected RED output.
- [ ] Implement local bounds, safe distance limits, default formation framing, and overview reset.
- [ ] Run the targeted worker and preserve projected-screen metrics at 1280x720.

### Task 2: Observatory atmosphere

**Files:**
- Modify: `tests/test_environment_kit.gd`
- Modify: `src/presentation/greybox_board.gd`

**Interfaces:**
- Produces: named `PlatformRim`, `DistantStructures`, and `CrystalBeacons` render-only groups under `EnvironmentDecor`.

- [ ] Write tests for minimum decor counts, out-of-grid placement, and zero collision objects.
- [ ] Run the environment worker and record the expected RED output.
- [ ] Build a perimeter rim and distant kit/procedural silhouettes without collision or session mutation.
- [ ] Run targeted environment and battle tests.

### Task 3: Truthful evidence and validation

**Files:**
- Modify: `tools/capture_production_battle.gd`
- Create: `tests/evidence/production-battle-v02.png`

**Interfaces:**
- Consumes: BattleScene's true default camera setup.
- Produces: warmed-up 1280x720 evidence.

- [ ] Increase shader/animation warmup without manipulating the camera.
- [ ] Run targeted tests, full suite, project validator, and fresh capture.
- [ ] Inspect the screenshot and measure unit screen-space placement/size and decor counts.
- [ ] Commit only after visual inspection and report honest residual gaps.
