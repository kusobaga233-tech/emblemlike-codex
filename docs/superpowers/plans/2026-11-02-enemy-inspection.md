# Enemy hover inspection implementation plan

Goal: add approved read-only enemy attributes without interrupting pending moves/locked confirmations.
Architecture: independent EnemyInspectionPanel renders a presentation snapshot, BattleScene owns hovered ID/lifecycle, HUD places side panel outside backdrop at responsive width.

- [x] RED: absent card, exact ranged/melee stats, no rule-state change, move mode preservation, stale exit guard, ally/dead/empty cleanup, confirm/busy priority, window/reconfigure cleanup.
- [x] Implement panel + scene hover routing; mouse-ignore UI, display HP boundary; responsive positioning beside HUD.
- [x] Actual viewport mouse motion test and right-click regression; full suite.
- [x] Capture melee/ranged/boss and portrait; inspect no overlap/truncation.
- [x] Fresh Windows EXE/ZIP boundary/startup smoke; source hashes and UTF-8 instructions/report.

No Git push unless requested, no character rework, no new combat rules.
