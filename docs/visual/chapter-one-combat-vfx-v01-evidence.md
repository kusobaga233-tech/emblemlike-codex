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

Capture completed with Godot Vulkan startup and produced:

- [`attack.png`](evidence/chapter-one-combat-vfx-v01/attack.png) — PASS: orange attack trail is legible; silhouettes remain visible. Size 491,282 bytes; SHA-256 `2c002d386dce8b8b156bf54f85a4c3a412fd87e5e8cab96d05b279033dce4988`.
- [`heal.png`](evidence/chapter-one-combat-vfx-v01/heal.png) — PASS: cyan healing ring is legible; no material crop. Size 479,313 bytes; SHA-256 `8346e600e16a6374971c4e7819a4bd77c0b3fd4246f8acc43a628b67c962c406`.
- [`resonance.png`](evidence/chapter-one-combat-vfx-v01/resonance.png) — PASS: pale resonance ring is legible, though it overlaps the caster silhouette. Size 471,744 bytes; SHA-256 `10d7e0245081977ae6c60f432b08e0355758d869c44c14871c44820919283ce4`.
- [`boss-hit.png`](evidence/chapter-one-combat-vfx-v01/boss-hit.png) — **REJECT for visual approval**: no boss-hit primitive is visible in this captured frame. Size 481,946 bytes; SHA-256 `6ff59930430cf6b5d4161b9e7daadc71d725e5fafc500d6e29caf956354ffc53`.
- [`defeat.png`](evidence/chapter-one-combat-vfx-v01/defeat.png) — **REJECT for visual approval**: no defeat primitive is visible in this captured frame. Size 483,297 bytes; SHA-256 `f63d02dd175c1ae3bb9faa3aeea32bdaa562ba8e92dfdf85abf671468d84acba`.
- [`victory.png`](evidence/chapter-one-combat-vfx-v01/victory.png) — **REJECT for visual approval**: no victory primitive is visible in this captured frame. Size 482,984 bytes; SHA-256 `e3573d80b042d29abd096e577b7e693062d8abda6140d40e9bc8559153efbd17`.

All six PNGs were opened with the workspace image viewer at high detail. The three rejected frames are preserved as failure evidence; no blanket visual approval is claimed. The capture harness is non-headless and did initialize Vulkan successfully.

## Bounded slice disposition

**PASS (code/automated gate) with visual evidence caveat.** Runtime limits and event dispatch are covered by the passing suite: active presentations cap at 64, pooled effect hosts at 128, counters saturate at 2,147,483,647, unknown diagnostics aggregate to at most 65 keys, and low quality keeps hit/heal/defeat primaries while suppressing secondary trails/particles/camera requests. Because three deterministic captures do not show their expected event primitive, this is not visual acceptance of the complete VFX set.

This evidence closes only the bounded combat-VFX slice review. It **does not close the overall 95–100% product gate**; clean-user-machine, target-hardware certification, broader content/UX polish, and the rejected capture-frame timing/visibility issues remain unresolved product-level gaps.
