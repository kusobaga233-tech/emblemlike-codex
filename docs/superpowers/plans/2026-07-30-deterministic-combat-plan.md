# Deterministic Combat Forecast and Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic combat forecasting and event resolution for positioned `UnitState` instances.

**Architecture:** `CombatForecast` is a focused result object populated by `CombatRules.forecast`. `CombatRules.resolve` validates through that forecast, uses a locally seeded `RandomNumberGenerator`, mutates defender HP only on a hit, and emits dictionaries through `BattleEvent` factory methods. Existing `UnitDefinition` construction remains source-compatible by appending combat accuracy, critical, and damage-type defaults.

**Tech Stack:** Godot 4.6.3, typed GDScript, the repository's `TestCase`/`run_all.gd` harness.

## Global Constraints

- All files are UTF-8.
- Resolution never uses global randomness.
- Illegal attacks return an empty event array and do not mutate either unit.
- Do not implement counterattack resolution or any Task 4 behavior.

---

### Task 1: Specify combat behavior with failing tests

**Files:**
- Create: `tests/test_combat_rules.gd`
- Create: `tests/evidence/task3-red.txt`

**Interfaces:**
- Consumes: `GridPoint.new(x, y)`, `UnitDefinition.new(...)`, `UnitState.new(definition, instance_id, grid_position)`.
- Produces: executable acceptance tests for `CombatRules.forecast` and `CombatRules.resolve`.

- [ ] **Step 1: Write the failing test**

Create a `TestCase` covering: Fenn's range-two six-damage attack; repeatable seeded resolution; illegal range returning `[]`; defeat events; physical defense versus magical resistance; clamped integer rates; counter eligibility; stable event payload types and IDs.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'D:\godot-proj\Godot_v4.6.3-stable_win64.exe' --headless --path 'D:\godot-proj\star-ember-oath-godot' --script 'res://tests/run_all.gd'
```

Expected: exit code 1 because `combat_rules.gd`, `combat_forecast.gd`, and `battle_event.gd` do not exist.

- [ ] **Step 3: Record RED evidence**

Save the exact command, output, and exit code to `tests/evidence/task3-red.txt`.

### Task 2: Implement minimal deterministic combat

**Files:**
- Create: `src/core/combat_forecast.gd`
- Create: `src/core/combat_rules.gd`
- Create: `src/events/battle_event.gd`
- Modify: `src/core/unit_definition.gd`

**Interfaces:**
- Produces: `CombatRules.forecast(attacker: UnitState, defender: UnitState) -> CombatForecast`.
- Produces: `CombatRules.resolve(attacker: UnitState, defender: UnitState, seed: int) -> Array[Dictionary]`.
- Produces: forecast fields `legal`, `damage`, `hit_rate`, `critical_rate`, `strike_count`, `can_counter`, `defender_remaining_hp`.

- [ ] **Step 1: Add backward-compatible combat stats**

Append constructor parameters and fields with defaults: `damage_type: StringName = &"physical"`, `hit: int = 100`, and `critical: int = 0`.

- [ ] **Step 2: Implement forecast**

Compute Manhattan distance from real grid positions; legal attacks require a listed range and living units. Physical damage subtracts defense, magical damage subtracts resistance, damage floors at zero, strike count is one for legal attacks, rates clamp to integer `0..100`, and counter eligibility requires a surviving defender whose range includes the same distance.

- [ ] **Step 3: Implement stable events and resolution**

Use `BattleEvent` factories so every dictionary contains `type`, `actor_id`, and `target_id`. Legal resolution emits `attack_started`, then either `attack_missed` or `hit_confirmed`; a hit continues with `damage_applied`, optional `unit_defeated`, and always `attack_finished`. Seed a new local `RandomNumberGenerator`; do not call global `rand*` functions.

- [ ] **Step 4: Run the complete test suite**

Run the same headless command and require exit code 0 with every test file passing.

- [ ] **Step 5: Record GREEN evidence**

Save the exact command, output, and exit code to `tests/evidence/task3-green.txt`.

### Task 3: Review, verify, and commit

**Files:**
- Review all Task 3 files and the `UnitDefinition` compatibility change.

- [ ] **Step 1: Check scope and UTF-8**

Review `git diff`, confirm no Task 4 features, no global randomness, and no unrelated changes.

- [ ] **Step 2: Run a fresh full verification**

Run the complete headless suite again immediately before committing.

- [ ] **Step 3: Commit**

```powershell
git add docs/superpowers/plans/2026-07-30-deterministic-combat-plan.md src/core/combat_forecast.gd src/core/combat_rules.gd src/core/unit_definition.gd src/events/battle_event.gd tests/test_combat_rules.gd tests/test_grid_rules.gd tests/evidence/task3-red.txt tests/evidence/task3-green.txt
git commit -m "feat: add deterministic combat forecast and events"
```
