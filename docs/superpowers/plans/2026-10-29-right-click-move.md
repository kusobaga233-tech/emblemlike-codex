# Right-click pending move implementation plan

Goal: implement the user-confirmed uniform right-click undo on terrain and all characters, removing the dedicated button.
Architecture: BattleScene resolves screen-space pointer hits, routes both unit/cell to existing rule command; BattleHud displays pending/committed status; BattleSession remains authoritative.

- [x] RED: update previous incompatible scene tests, add real mouse-button/physics tests for friend/enemy/neutral, terrain, outside, preview and wait-commit.
- [x] GREEN: input hit-test and right-click routing with busy/phase gates; remove UndoMove node/binding and obsolete UI command entry; add pending-move status.
- [x] Verify return Tween completion (not instantaneous root teleport), original selection and move budget, occupied-origin rejection, no undo after wait/attack.
- [x] Capture moved/cancelled/waited UI using new input path, inspect images.
- [x] Full validator, fresh embedded Windows EXE/ZIP resource check/startup smoke, UTF-8 instructions/manifest/QA evidence.

No art generation, role changes or unrelated cleanup. Keep accumulated uncommitted work.
