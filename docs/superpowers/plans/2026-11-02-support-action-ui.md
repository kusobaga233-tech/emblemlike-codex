# Support action UI implementation plan

Goal: complete existing heal rule's playable selection/preview/confirmation path and action readiness.
Architecture: shared BattleSession support validation feeds read-only forecast and commit. BattleScene owns selected target, panel owns buttons/signals, HUD owns button states/feedback. Existing event timeline owns visible HP cue.

- [x] Failing rule/UI tests: forecast no mutation; HP cap; invalid/full/out-of-range/acted recheck; selection and explicit confirmation; no double actions; cancel/right-click; disabled states.
- [x] Add forecast_support command/shared validation without changing event order or support balance.
- [x] Add Support button, preview Confirm/Cancel and localized status. Busy gate disables actual HUD and panel controls until timeline drains.
- [x] Verify actual pointer confirmation, recovery cue vs immediate logical HP, cancellation, regression camera movement.
- [x] Capture 1280x800 and portrait UI, inspect; full validator; new Windows export/resource-boundary/EXE startup checks, UTF-8 report/manifest/instructions.
