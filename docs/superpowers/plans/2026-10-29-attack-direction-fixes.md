# Attack direction and VFX coordinates — continuation plan

Goal: finish the approved static-sprite combat presentation without regenerating accepted art or changing combat rules.
Architecture: one world-space anchor per effect; local ImmediateMesh vertices. Melee/thrust use camera-projected attacker-to-target axes. Resolved events control hit reactions; misses do not flash/recoil. Cancellation restores camera controls.

- [x] Reproduce arrow/ring double translation and miss reaction with failing tests.
- [x] Repair local-coordinate mesh contract and verify target ring/impact positions.
- [x] Replace straight melee strip with segmented tapered crescent; retain forward-directed thrust.
- [x] Reproduce cancellation/reconfigure camera lock, emit completion after clearing an active queue, rerun regression.
- [x] Deterministic capture: disable automatic presenter processing, adjacent melee/heal, distance-two projectiles, explicit camera pose, five profiles × four yaws × four times.
- [x] Final full validator and fresh Windows embedded-PCK export, resource-boundary verification, standalone headless/window startup.
- [x] Record checks, known limitations and runnable EXE path. Preserve unrelated accumulated work.

Capture events are presentation fixtures (not a complete legal-playthrough test). Existing battle-rule tests provide separate coverage. Fixed source art has baked-in weapons; whole-image anticipation/lunge is not a hand-authored swing or bow-draw animation.
