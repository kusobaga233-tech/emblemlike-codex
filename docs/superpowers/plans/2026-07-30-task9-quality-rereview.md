# Task 9 Quality Re-review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use test-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make save-slot recovery restart-safe, derive scripted-event validity generically from chapter definitions, and prevent malformed live sessions from reaching serializer property access or filesystem mutation.

**Architecture:** Keep persistence behavior inside `SaveService`. Add slot reconciliation before temporary-file creation, replace event-name special cases with trigger parsing over `chapter.events`, and route compatibility serialization plus saving through a structured `serialize_result` validator.

**Tech Stack:** Godot 4.6.3, typed GDScript, the existing process-isolated test runner, JSON save slots.

## Global Constraints

- Strict RED → observed failure → minimal implementation → GREEN for each task.
- All text and evidence files are UTF-8.
- Preserve the 1 MiB and schema resource limits already implemented.
- No Task 10 artwork changes.
- SaveService is main-thread, single-writer; overlapping saves return `save_in_progress`.

---

### Task 1: Restart-safe slot reconciliation

**Files:**
- Modify: `tests/test_save_service.gd`
- Modify: `src/core/save_service.gd`
- Create: `tests/evidence/task9-reconcile-red.txt`
- Create: `tests/evidence/task9-reconcile-green.txt`

**Interfaces:**
- Produces: `_reconcile_slots(path, chapter) -> Dictionary` called before `.tmp` creation.

- [ ] Add a test that injects `rotation` failure with three distinct valid payloads, then performs a normal save and asserts target=third, backup=second, and no previous slot.
- [ ] Add restart-style load/save cases for valid/invalid target, previous, and backup combinations.
- [ ] Run focused SaveService test and observe failures caused by missing reconciliation.
- [ ] Implement schema-validated reconciliation and a single-writer busy guard.
- [ ] Run focused and full tests, record UTF-8 evidence, and commit independently.

### Task 2: Generic chapter event validation

**Files:**
- Modify: `tests/test_save_service.gd`
- Modify: `src/core/save_service.gd`
- Create: `tests/evidence/task9-generic-events-red.txt`
- Create: `tests/evidence/task9-generic-events-green.txt`

**Interfaces:**
- Consumes: `chapter.events` dictionaries with `id` and `trigger`.
- Produces: generic `round-start:N`, `round:N`, and `resonance:N` validation without fixed IDs or global ordering.

- [ ] Add custom chapter fixtures covering no events, renamed opening/round/resonance events, a second chapter, and both legal resonance/round event orders.
- [ ] Run focused tests and observe hard-coded event-name failures.
- [ ] Replace fixed-name checks with known/unique IDs and trigger-derived state rules.
- [ ] Run focused and full tests, record UTF-8 evidence, and commit independently.

### Task 3: Structured serializer preflight

**Files:**
- Modify: `tests/test_save_service.gd`
- Modify: `src/core/save_service.gd`
- Create: `tests/evidence/task9-serialize-result-red.txt`
- Create: `tests/evidence/task9-serialize-result-green.txt`

**Interfaces:**
- Produces: `serialize_result(session) -> {ok, payload, reason}`; `serialize` remains a compatibility wrapper.

- [ ] Add mutation tests for null units, definitions, grid positions, turn state, and resonance state; assert stable `invalid_session`, no diagnostics, and unchanged slots.
- [ ] Run focused test and observe serializer property-access failures.
- [ ] Validate the complete object graph and required field types before dereferencing; make `save_file` consume only `serialize_result`.
- [ ] Run focused and full tests, record UTF-8 evidence, and commit independently.

### Task 4: Final quality gate

**Files:**
- Modify evidence files only when trailing whitespace or EOF cleanup is required.

- [ ] Run SaveService, chapter playthrough, and Task 8 E2E focused tests.
- [ ] Run all 12 test files.
- [ ] Run 120-frame verbose startup and require zero `ERROR:` or `SCRIPT ERROR:` diagnostics.
- [ ] Parse every QA JSON file, strict-decode project text as UTF-8, run `git diff --check`, and confirm no `.tmp`, `.bak`, `.previous.new`, or stray `.uid` files.
- [ ] Confirm a clean worktree and report all commit SHAs for re-review.
