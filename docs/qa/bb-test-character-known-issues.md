# BB test character diagnostic notes

This asset is isolated under `assets/test` and is not a production character. It is not registered in `unit_catalog.gd`, `PRODUCTION_VISUALS`, deployment content, or Chapter 1, and it does not replace Aurelia.

## Known visual issues

- Hair, cape, and skirt layers can occlude one another during motion and need dedicated deformation and clipping cleanup.
- The `defeat` clip can expose an unstable mesh/pose artifact and is unsuitable for production use.
- Several action silhouettes are weak at tactical-camera distance, especially the two attacks and victory pose.
- Compatibility-renderer evidence can still show clipped highlights from the source materials; the preview lighting is intentionally neutral and low-energy so this remains visible as an asset/material issue.
- No neutral standing idle pose is present in the imported animation evidence. Even the first `idle` frame retains the source seated/hovering posture; the Godot diagnostic scene does not fabricate a replacement pose.
- The two attack clips remain extremely close to the idle silhouette at their selected semantic frames, confirming that the limitation is in the authored clips rather than capture timing.
- The current animation set is intended for import and playback diagnosis only; it is not commercial-quality animation evidence.

## Evidence protocol

The capture harness emits one front-view full-body image per required clip under `build/qa/bb-test-character`. Each image seeks to a clip-specific semantic time instead of capturing only the first/default frame. The `defeat` evidence is intentionally preserved even when it exposes deformation artifacts.

Expected evidence files:

- `idle-front.png`
- `locomotion-front.png`
- `attack_primary-front.png`
- `attack_secondary-front.png`
- `hit-front.png`
- `defeat-front.png`
- `select-front.png`
- `victory-front.png`

## Acceptance boundary

Passing the diagnostic resource test proves only that Godot can load the GLB, find a skeleton, skin, material, and the exact eight expected animation names. It does not approve topology, weighting, animation quality, or visual design.
