# Chapter One Combat VFX v0.1 Audit

Date: 2026-08-03  
Scope: `CombatVfxDirector` quality metrics, pooling, and battle-scene capture helper.

## Reproducible capture

From `D:\godot-proj\star-ember-oath-godot`, run this non-headless capture harness at 1280x720:

`D:\godot-proj\Godot_v4.6.3-stable_win64.exe --path D:\godot-proj\star-ember-oath-godot --script tools/capture_combat_vfx.gd`

It writes six deterministic PNGs after dispatching fixed Chapter One events. The `BattleScene.capture_combat_vfx_frame(event, output_path)` helper is also available for one-off captures.

Expected evidence paths (create only when the capture harness is run):

- `build/evidence/combat-vfx-v01/attack.png`
- `build/evidence/combat-vfx-v01/heal.png`
- `build/evidence/combat-vfx-v01/resonance.png`
- `build/evidence/combat-vfx-v01/boss-hit.png`
- `build/evidence/combat-vfx-v01/defeat.png`
- `build/evidence/combat-vfx-v01/victory.png`

No screenshots were generated in this headless implementation pass, so no visual approval is claimed. Before acceptance, inspect each image for tactical legibility, unobscured unit silhouettes, and Boss weapon exposure; reject and record any crop, bloom spill, or missing event primitive.

## Runtime findings

Metrics are deterministic and bounded: active presentations cap at 64, pooled effect host nodes cap at 128, cumulative counters saturate at 2,147,483,647, unknown event diagnostics aggregate after 64 individual types plus `__other__` (maximum 65 keys), and low quality retains hit/heal/defeat primaries while disabling all secondary trails, extra particles, and camera request consumption.
