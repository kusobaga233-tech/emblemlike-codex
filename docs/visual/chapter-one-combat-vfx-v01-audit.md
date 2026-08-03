# Chapter One Combat VFX v0.1 Audit

Date: 2026-08-03  
Scope: `CombatVfxDirector` quality metrics, pooling, and battle-scene capture helper.

## Reproducible capture

From `D:\godot-proj\star-ember-oath-godot`, launch the project with the Godot 4.6.3 executable and use `BattleScene.capture_combat_vfx_frame(event, output_path)` from a debug harness. The helper renders two frames after dispatch and writes PNG output using the viewport image. Recommended fixed settings are 1280x720, default quality tier, chapter-one scene, and these event fixtures: `attack_started`, `unit_healed`, `resonance_changed`, `hit_confirmed` targeting `captain-1`, `unit_defeated`, and `battle_status_changed` with `status=victory`.

Expected evidence paths (create only when the capture harness is run):

- `build/evidence/combat-vfx-v01/attack.png`
- `build/evidence/combat-vfx-v01/heal.png`
- `build/evidence/combat-vfx-v01/resonance.png`
- `build/evidence/combat-vfx-v01/boss-hit.png`
- `build/evidence/combat-vfx-v01/defeat.png`
- `build/evidence/combat-vfx-v01/victory.png`

No screenshots were generated in this headless implementation pass, so no visual approval is claimed. Before acceptance, inspect each image for tactical legibility, unobscured unit silhouettes, and Boss weapon exposure; reject and record any crop, bloom spill, or missing event primitive.

## Runtime findings

Metrics are deterministic and bounded: active presentations cap at 64, pooled effect host nodes cap at 128, unknown event diagnostics aggregate after 64 types, and low quality retains hit/heal/defeat primaries while disabling secondary trails, extra particles, and camera request consumption.
