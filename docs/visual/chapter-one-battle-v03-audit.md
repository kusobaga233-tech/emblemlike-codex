# Chapter One battle visual audit v03

- Evidence: `res://tests/evidence/production-battle-v02.png`
- Capture date: 2026-07-31
- Resolution: 1280×720
- Status: accepted camera/atmosphere progress evidence; not commercial-final approval

## Confirmed improvements

- Default 16:9 entry now frames the four-unit allied formation and nearby tactical cells at a materially larger screen-space scale.
- Allied unit centres remain to the right of the 388 px desktop HUD safe boundary in the measured 1280×720 test.
- `R` and `Home` expose full-board overview/reset during play; `F` returns to selected-unit local focus.
- Portrait view automatically uses overview framing and a compact HUD capped at 42% of viewport width, preserving pointer-accessible battlefield space.
- Collision-free platform rim, layered foundation, distant pylons/arches, and crystal beacons reduce the empty navy surround without occupying tactical cells.
- The capture script records the true default view after 48 warmup frames and does not apply a QA-only camera transform.

## Remaining visual gaps

- The Bridge Captain's pale weapon/focus geometry remains over-bright and visually merges at this exposure.
- Brann remains the largest allied silhouette and can dominate the formation, though the revised azimuth prevents allied clipping and substantially improves separation.
- Character geometry, authored textures, combat VFX, secondary motion, and impact camera work are still below commercial-final quality.
- Portrait mode is functionally usable and tested, but this landscape evidence does not constitute a dedicated portrait composition approval.

## Gate decision

This pass is accepted for default framing, accessible overview controls, responsive HUD behavior, and render-only observatory atmosphere. It remains production-progress evidence rather than a 95–100% commercial-quality visual approval.
