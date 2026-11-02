# Attack confirmation implementation plan

Goal: align attack target selection with explicit heal-style confirmation; prevent hover/double-click accidental commitment.
Architecture: BattleScene tracks locked attack target separately from hover preview; panel dispatches by current action kind; existing session.confirm_attack stays authoritative.

- [x] RED new tests for hover no commit, lock/pointer persistence, double-click no attack, stale target revalidation, cancel/right-click/duplicate busy inputs.
- [x] Add attack panel signal and action-kind reset, target name/uncertainty note and button state. Keep support API compatible.
- [x] Route click to locked forecast, confirm through rule validation only. Update actual pointer E2E to explicit button.
- [x] Regression support and right-click suites. Landscape/portrait actual-confirm capture and inspection.
- [x] Full validator, fresh Windows EXE/ZIP resource check and standalone boot; UTF-8 manifest/instructions/QA.
