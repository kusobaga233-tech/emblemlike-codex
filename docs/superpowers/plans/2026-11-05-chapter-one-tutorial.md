# Chapter one tutorial loop implementation plan

Goal: close the chapter-one teaching loop (move → attack → heal → resonance), add objective/turn HUD detail and an enemy threat-range overlay without changing combat rules or character art.

Architecture: `TutorialFlow` is a pure observer of flushed events; `TutorialPanel` renders its step; `BattleScene` wires steps, highlight rings and HUD. `ThreatRules` computes move/attack envelopes for living enemies; `GreyboxBoard` draws them in a dedicated overlay. Resonance gets a UI mode on top of the existing `use_resonance_selected` command.

- [x] RED: threat rules (move BFS, terrain/unit blocking, attack envelope), tutorial advancement (order, out-of-order, skip), HUD text, resonance mode.
- [x] Implement `ThreatRules` + board overlay + HUD toggle and refresh triggers.
- [x] Implement `TutorialFlow` + panel + unit tutorial ring/marker + event wiring.
- [x] Implement objective progress, turn limit and failure-condition HUD lines.
- [x] Implement resonance button/modes/forecast/confirm using a shared rule damage helper.
- [x] Scene tests for tutorial, threat, HUD and resonance; keep existing hover/right-click/support priority.
- [x] Full suite + `tools/validate_project.ps1`; capture 1280x800 and 720x1280 evidence.
- [x] QA record with automated vs manual boundaries; no character rework, no AI/balance change.

Out of scope: new chapters, art replacement, 2.5D cutout acceptance, target-hardware performance claims.
