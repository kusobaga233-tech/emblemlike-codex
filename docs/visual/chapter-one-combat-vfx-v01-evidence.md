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
Godot_v4.6.3-stable_win64.exe --path . --headless --script tests\run_all.gd --quit-after 120  exit 0
Godot_v4.6.3-stable_win64.exe --path . --headless --check-only                    exit 0
Godot_v4.6.3-stable_win64.exe --path . --headless --quit-after 120                exit 0
```

The current export snapshot is authoritative for this evidence pass. Command: `Godot_v4.6.3-stable_win64.exe --path . --headless --export-release "Windows x64 Release" build\windows\StarEmberOath.exe`. It ran from 2026-08-03 12:14:33 +08:00 to 12:14:37 +08:00 and returned exit 1, but produced 108,618,976 bytes, SHA-256 `c3a89828511ee2eaa663f0dd3798ceca40fa8ad86e02c4195a71c069e6b66931`; this is not a clean export pass. The resulting executable smoke command `build\windows\StarEmberOath.exe --headless --quit-after 120` completed without anchored diagnostics. The standalone `tests\run_all.gd --quit-after 120` command returned exit 0. `build/` is ignored/untracked, so this binary hash is not a portable artifact unless retained externally.

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

Source commit: `eee1445cb7a535ba1e95aa34d27b230ddb3afc76` (`use tolerant mesh radius assertions`). Capture ran once on 2026-08-03 at approximately 13:14:50–13:14:53 +08:00 with Godot Vulkan startup and produced fresh 1920x1080 original-resolution PNGs:

- [`attack.png`](evidence/chapter-one-combat-vfx-v01/attack.png) — PASS: orange attack trail is clearly legible across the board. Size 491,182 bytes; SHA-256 `54e1464633c1226a1a1405a875ce7e9621a2478bcf33887d35c33a03bf1b2af3`.
- [`heal.png`](evidence/chapter-one-combat-vfx-v01/heal.png) — PASS: cyan healing ring is clearly legible around the healed unit. Size 479,244 bytes; SHA-256 `8159563d353f73f003137b82200756d7e949b40566d226c90089b10d8aa51841`.
- [`resonance.png`](evidence/chapter-one-combat-vfx-v01/resonance.png) — PASS: pale resonance ring is clearly visible, overlapping the caster silhouette but remaining identifiable. Size 471,794 bytes; SHA-256 `da6efe7a93461eb506c05742f8886c0dbdd7bd84309458f747abe4863e537e88`.
- [`boss-hit.png`](evidence/chapter-one-combat-vfx-v01/boss-hit.png) — PASS: elevated magenta weak-point ring/crown and associated crack/trail primitive are visibly distinct around the boss. Size 483,060 bytes; SHA-256 `7e643788377db84624df8e6505e2c99ccdde7d22599528d43cd99bf2b5ef3022`.
- [`defeat.png`](evidence/chapter-one-combat-vfx-v01/defeat.png) — PASS: defeat presentation is visibly distinct, with the large pale burst/orb primitive and vertical dissolve elements around the boss. Size 486,615 bytes; SHA-256 `acc63e6e146180098beceb55fdadeab0ebe8a1ce00b3a835dc6f4b1e6f8f9511`.
- [`victory.png`](evidence/chapter-one-combat-vfx-v01/victory.png) — PASS with framing caveat: the centered victory ring/status primitive is visible and distinct, but the framing leaves a foreground unit partially cropped at left and the ring reads narrow from this camera angle. Size 573,677 bytes; SHA-256 `853ebeda9c04deae4ab7bff9ce40dac5a8944cae7739eb2d48eda7a273f19f21`.

All six fresh PNGs were opened with the workspace image viewer at original detail. Each expected primitive is identifiable in current pixels; victory remains accepted with the framing caveat documented above. The capture harness is non-headless and initialized Vulkan successfully.

## Bounded slice disposition

**PASS (code/automated gate and fresh visual evidence).** Runtime limits and event dispatch are covered by the passing suite: active presentations cap at 64, pooled effect hosts at 128, counters saturate at 2,147,483,647, unknown diagnostics aggregate to at most 65 keys, and low quality keeps hit/heal/defeat primaries while suppressing secondary trails/particles/camera requests. All six fresh event captures show distinct expected primitives; victory retains the framing caveat above.

This evidence closes only the bounded combat-VFX slice review. It **does not close the overall 95–100% product gate**; clean-user-machine, target-hardware certification, and broader content/UX polish remain unresolved product-level gaps.
