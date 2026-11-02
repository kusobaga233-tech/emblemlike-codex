# Tactical camera interaction implementation

Goal: Implement the user-approved fixed 45-degree tactical view, focus-centered wheel orbit and screen-edge panning without changing combat rules.
Architecture: TacticalCamera owns a cumulative yaw target and smooth stepping, a pure screen-edge direction query, and bounded board-plane panning. GUI hover, disabled controls, paused tree, pointer outside and window focus gate runtime input. Existing focus/reset/overview paths retain 45 degrees. Selection state is not consumed or modified by camera input.
Tech: Godot 4.6.3, GDScript, existing isolated test runner.

- [x] Add tests/test_tactical_camera_controls.gd for +/-30-degree wheel input, accumulated rotation, focus/radius invariant, fixed pitch, screen-relative panning, corners, boundaries and disabled input. Observe failures before changing camera.
- [x] Implement camera controls in src/presentation/tactical_camera.gd. Preserve programmatic framing/zoom compatibility, but remove wheel zoom and middle-drag pitch changes.
- [x] Update historical pitch assertions in tests/test_battle_scene.gd from 40 to the approved 45 degrees.
- [x] Run isolated camera tests and full project validation. Record any regressions rather than treating headless checks as visual approval.

Static character replacement, layered selection/cancel UX, chapter rules and scene redesign follow separately; this change does not claim those complete. Never overwrite existing QA assets or alter battle RNG/save rules.

Evidence: docs/qa/camera-controls-2026-10-22.md. Physical mouse/GUI checks and broader sprite/selection/gameplay tasks remain outside this bounded slice.
