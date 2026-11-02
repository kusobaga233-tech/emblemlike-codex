# Cutout 2.5D prototype QA

## Scope

This isolated QA asset composites the approved Aurelia formal cutout art into a transparent `SubViewport`, maps it to a camera-facing 3D `QuadMesh`, anchors the feet to the viewport baseline, and forwards presentation events to the existing VFX/event boundary.

## Evidence

- `build/qa/cutout-2p5d-prototype/idle-default-3d.png`
- `build/qa/cutout-2p5d-prototype/attack_primary-default-3d.png`
- `build/qa/cutout-2p5d-prototype/idle-close-3d.png`
- `build/qa/cutout-2p5d-prototype/attack_primary-close-3d.png`

## Result

`TECHNICAL_SAMPLE_PASS / ART_REVIEW_REJECT`

The technical sample passes scene loading, alpha compositing, camera-facing behavior, foot anchoring, real 3D ground geometry, visible soft translucent shadow presence, animation playback and ordered event forwarding. Transparent ordering is explicit: opaque ground priority `0`, shadow priority `1`, and character priority `2`. Default and close captures keep the character large enough for presentation review. It is not a final art approval: the current formal source art is a limited-layer composite, so green-edge/alpha fringe and visible layer boundaries remain. Head, body and the updated clean weapon-and-hand image are intentionally whole-image layers in this first integration sample.

## Known visual limitations

- Green-edge/limited-layer notes: source PNGs retain a small chroma fringe at transparent borders and do not yet expose production-grade limb, hair and cloth layers.
- The sample validates the engine presentation path only; it does not replace the production Aurelia model or Chapter 1 assets.


## Test scope correction (2026-10-29)

All three isolated QA tests (`test_cutout_character_2d.gd`, `test_cutout_character_billboard_3d.gd`, and `test_bb_diagnostic_character.gd`) are included in the default suite again. The earlier exclusion and blanket attribution to QA resource leaks were not justified. An overly short E2E worker frame cap truncated playback/teardown. The runner now requires an explicit PASS marker and allows 1800 inner-worker frames; E2E advances presentation time deterministically. Legacy Bone2D warnings are not art approval and remain nonblocking. These samples are still excluded from the exported game resources.
