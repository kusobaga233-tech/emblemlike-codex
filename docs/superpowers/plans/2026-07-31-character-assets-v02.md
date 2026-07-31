# Chapter One Character Assets V02 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the five remaining Chapter One unit greyboxes with reproducible, rigged Blender-authored character GLBs and provide all five weapon-family GLBs.

**Architecture:** A deterministic UTF-8 Blender Python generator creates one shared humanoid rig contract, silhouette-specific modular armor and equipment, eight named actions, versioned `.blend` sources, GLBs, and a machine-readable budget report. Godot keeps its existing runtime pick collision and maps unit definition IDs to imported character scenes.

**Tech Stack:** Blender 4.x Python API, glTF 2.0/GLB, Godot 4.6 GDScript tests.

## Global Constraints

- Heroes stay at or below 35,000 triangles, enemies at or below 18,000, and separate weapons at or below 8,000.
- Characters use no more than four materials and include `hand_r_weapon` plus eight required animation names.
- Geometry is original project-authored interpretation of the approved generated references and is not described as commercial-final.
- Existing Aurelia and boss mappings/assets remain unchanged; runtime pick collision remains separate.

---

### Task 1: Asset Contract

- [x] Add a failing Godot import/mapping/skeleton/animation test.
- [x] Run it before asset implementation and preserve RED output.
- [x] Add a Blender-side report validator for budgets, materials, bones, weights, and animations.

### Task 2: Deterministic Blender Production Source

- [x] Create the UTF-8 generator and `.gdignore` under `tools/production_source/characters_v02`.
- [x] Author distinct proportions, layered armor, silhouette equipment, shared bone names, distributed vertex weights, and distinct action poses.
- [x] Save character and weapon `.blend` sources and export GLBs plus report JSON.

### Task 3: Godot Integration and Evidence

- [x] Map the five Chapter One unit definition IDs without changing gameplay logic.
- [x] Import with Godot, run the focused tests and full suite, then run the Blender report validator.
- [x] Mark registry rows reviewed only after all evidence passes, self-review the diff, and commit.
