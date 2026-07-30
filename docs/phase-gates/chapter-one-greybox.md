# Chapter One greybox phase gate

## Decision

PASS — the Phase 1 greybox gate is satisfied for the tested chapter-one build. This gate confirms deterministic mechanics, basic flow, persistence, camera framing, and clean headless execution. Phase 1 greybox gate PASS does not mean final commercial quality is complete, and it does not authorize production character or environment asset generation by itself.

## Run metadata

- Time: `2026-07-30T22:07:52+08:00`
- Commit SHA: `67b762514d950d8d6dd54c50da52937d6596bddf` was the source baseline; the fresh run also included the uncommitted Task 10 documentation and validator files that are committed by this task.
- Godot version: `4.6.3.stable.official.7d41c59c4`
- Project: `D:\godot-proj\star-ember-oath-godot`

## Gate evidence

| Gate | Status | Command | Evidence file | Live coverage |
| --- | --- | --- | --- | --- |
| full playthrough | PASS | `Godot_v4.6.3-stable_win64.exe --headless --path <project> --script res://tests/run_all.gd --quit-after 120 -- --test-runner-worker res://tests/test_chapter_one_playthrough.gd` | `tests/evidence/task10-key-workers.txt` | Frozen chapter script reaches victory with required support/resonance behavior. |
| invalid command handling | PASS | `Godot_v4.6.3-stable_win64.exe --headless --path <project> --script res://tests/run_all.gd --quit-after 120` | `tests/evidence/task10-full-tests.txt` | Battle-session and scene tests verify rejected commands are controlled no-ops. |
| deterministic digest | PASS | same live playthrough worker command | `tests/evidence/task10-key-workers.txt` | Two fresh frozen playthroughs produce the same canonical event digest. |
| save restore | PASS | worker command for `res://tests/test_save_service.gd` | `tests/evidence/task10-key-workers.txt` | Structured save, rotation, recovery, and continuation restoration pass. |
| keyboard flow | PASS | worker command for `res://tests/test_e2e_scene_flow.gd` | `tests/evidence/task10-key-workers.txt` | Title, deployment, battle HUD, and result keyboard focus/flow pass. |
| viewport framing | PASS | full suite plus E2E worker | `tests/evidence/task10-full-tests.txt` | Landscape, portrait, orbit, zoom, and board-corner framing assertions pass. |
| clean engine logs | PASS | `Godot_v4.6.3-stable_win64.exe --headless --path <project> --quit-after 120` | `tests/evidence/task10-120-frames.txt` | 120-frame boot exits 0 without anchored `ERROR:`, `SCRIPT ERROR:`, or orphan diagnostics. |

The complete validation Command is `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate_project.ps1`. Its GREEN summary is recorded in `tests/evidence/task10-green.txt`; the validator reruns the real 12/12 suite, parser/resource smoke, and 120-frame boot rather than accepting this Markdown PASS at face value.

## Limitations and next-stage blockers

- All visuals remain greybox primitives and native Control UI. No production hero, boss, enemy, weapon, environment, UI raster, VFX, or audio asset is claimed as generated or approved.
- Production image/reference work remains blocked until the asset and prompt registries are reviewed. Every generated reference image or raster asset must use the user-specified `$imagegen` skill.
- Four hero concepts, a boss with a mesh budget equal to a hero, two enemy types, weapons, environment, UI, VFX, and audio remain planned production slots.
- The next phase must preserve deterministic tests, keyboard accessibility, viewport framing, save compatibility, clean engine logs, provenance, and license review while replacing greybox presentation.
