# Camera controls verification — 2026-10-22

Scope: first implementation slice of the approved static-sprite gameplay revision. Character replacement, selection/cancel UX, chapter rules and map rework remain unfinished.

## Implemented

- All framing/reset/orbit transform paths retain a 45-degree pitch.
- Wheel forward adds a clockwise 30-degree target step, viewed from +Y with -Z at screen top. Wheel backward reverses it. Wheel no longer zooms.
- Smooth orbit changes horizontal position only, preserving current focus and radius; inputs accumulate in the target, including full-circle wraps.
- A 28-pixel viewport edge zone pans on the camera's current screen axes; corners normalize speed. Pan velocity eases, focus clamps to board dimensions, and pan does not change radius.
- Runtime controls stop for GUI hover, disabled controls, tree pause, window focus loss or pointer exit. Window enter/exit signals connect and disconnect with camera lifetime. Synthetic headless pointer positions do not auto-pan.
- Existing R/Home overview and F focus commands remain; programmatic zoom API remains for compatibility, not wheel input. Middle drag no longer changes pitch.

## Fresh evidence

- tests/test_tactical_camera_controls.gd initially failed for 40-degree pitch and missing discrete orbit/pan API; passed after implementation.
- A second failure for missing pointer-exit guard was observed, then passed after adding the window guard.
- Tests cover forward/backward steps, rapid input accumulation, transition, circle wrap, invariant focus/radius/pitch, rotated pan axes, map limits, disabled input, pointer-exit input, and unchanged unit selection/marker during rotation.
- Full tools/validate_project.ps1: 18 passed, 0 failed; 21/21 test files. Historical benchmark values printed by this command are not a new performance measurement.
- Non-headless Vulkan capture via tools/capture_camera_controls.gd completed exit 0. Images: build/qa/camera-controls-20261022/view-0.png (yaw 12), view-1.png (yaw -18), view-2.png (yaw 72). All pitch 45; selected unit aurelia-1 retained. view-1 and view-2 visually inspected.

## Remaining limitations

- Captures are still old 3D models, not static sprite replacements. Old long HP bars and character scale cause occlusion at some angles. This is not final scene/composition approval.
- Automated tests validate math and selection invariants. GUI scroll consumption, physical high-resolution mouse-wheel devices, edge panning under native window resizing and full modal/pause UX still need interactive end-to-end checks.
- Future pause/result overlays must set controls_enabled or consume pointer events; existing tree pause/focus guards alone do not prove future overlays are integrated.
- The capture helper is QA-only and writes ignored build output. No battle rules, saves, or character assets were changed in this camera slice.
