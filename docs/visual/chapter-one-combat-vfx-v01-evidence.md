# Chapter One Combat VFX v0.1 Evidence

Date: 2026-08-03  
Scope: bounded Task 5 combat-VFX slice only (`CombatVfxDirector`, pooling/quality limits, and deterministic capture helper).

## Authoritative validation

`D:\CODEX-PROJ\chanlleng\tools\validate_project.ps1` was checked and is unavailable in that workspace. The authoritative validator used here is the project-local [`tools/validate_project.ps1`](../../tools/validate_project.ps1). Command (from `D:\godot-proj\star-ember-oath-godot`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_project.ps1
```

Exit code: **0**. Summary: 17/17 full tests passed; parser/resource smoke passed; 120-frame boot passed; UTF-8/JSON/asset/phase-gate checks passed; `git diff --check` passed. The validator also ran fresh-worker playthrough, save-service, and E2E scene-flow checks.

Additional exact checks:

```text
Godot_v4.6.3-stable_win64.exe --path . --headless --script tests\run_all.gd       exit 0
Godot_v4.6.3-stable_win64.exe --path . --headless --check-only                    exit 0
Godot_v4.6.3-stable_win64.exe --path . --headless --quit-after 120                exit 0
Godot_v4.6.3-stable_win64.exe --path . --headless --export-release "Windows x64 Release" build\windows\StarEmberOath.exe  exit 0
```

The exported executable smoke command `build\windows\StarEmberOath.exe --headless --quit-after 120` completed without anchored diagnostics (the PowerShell wrapper did not expose a populated `$LASTEXITCODE`; the Godot export itself and validator smoke are both exit 0). Export artifact measured 108,618,992 bytes, SHA-256 `bb5cd5ee11702ac40498123c5c369a50353f1e2766348b56e612319f922e6575`.

The committed [`tests/evidence/windows-build-manifest.json`](../../tests/evidence/windows-build-manifest.json) records an older export (`source_commit` `8bfff3c`, 106,801,416 bytes, SHA-256 `059c5970aeaf29a9e0614ca422c3b31ced88717c208053cffe39e7a0ff2e09dc`). It is retained as historical evidence; the freshly generated hash above is not written to unrelated manifest files in this docs-only pass.

## Existing Task 2 evidence

- [`task2-final-focused.log`](../../tests/evidence/task2-final-focused.log)
- [`task2-final-full.log`](../../tests/evidence/task2-final-full.log)
- [`task2-final-parser.log`](../../tests/evidence/task2-final-parser.log)
- [`task5-green.txt`](../../tests/evidence/task5-green.txt)
- [`task5-quality-green.txt`](../../tests/evidence/task5-quality-green.txt)
- [`task5-quality-red.txt`](../../tests/evidence/task5-quality-red.txt)

## Non-headless capture and six-frame review

Command:

```text
D:\godot-proj\Godot_v4.6.3-stable_win64.exe --path D:\godot-proj\star-ember-oath-godot --script tools/capture_combat_vfx.gd
```

Capture completed with Godot Vulkan startup and produced:

- [`attack.png`](../../build/evidence/combat-vfx-v01/attack.png) — PASS: orange attack trail is legible; silhouettes remain visible.
- [`heal.png`](../../build/evidence/combat-vfx-v01/heal.png) — PASS: cyan healing ring is legible; no material crop.
- [`resonance.png`](../../build/evidence/combat-vfx-v01/resonance.png) — PASS: pale resonance ring is legible, though it overlaps the caster silhouette.
- [`boss-hit.png`](../../build/evidence/combat-vfx-v01/boss-hit.png) — **REJECT for visual approval**: no boss-hit primitive is visible in this captured frame.
- [`defeat.png`](../../build/evidence/combat-vfx-v01/defeat.png) — **REJECT for visual approval**: no defeat primitive is visible in this captured frame.
- [`victory.png`](../../build/evidence/combat-vfx-v01/victory.png) — **REJECT for visual approval**: no victory primitive is visible in this captured frame.

All six PNGs were opened with the workspace image viewer at high detail. The three rejected frames are preserved as failure evidence; no blanket visual approval is claimed. The capture harness is non-headless and did initialize Vulkan successfully.

## Bounded slice disposition

**PASS (code/automated gate) with visual evidence caveat.** Runtime limits and event dispatch are covered by the passing suite: active presentations cap at 64, pooled effect hosts at 128, counters saturate at 2,147,483,647, unknown diagnostics aggregate to at most 65 keys, and low quality keeps hit/heal/defeat primaries while suppressing secondary trails/particles/camera requests. Because three deterministic captures do not show their expected event primitive, this is not visual acceptance of the complete VFX set.

This evidence closes only the bounded combat-VFX slice review. It **does not close the overall 95–100% product gate**; clean-user-machine, target-hardware certification, broader content/UX polish, and the rejected capture-frame timing/visibility issues remain unresolved product-level gaps.
