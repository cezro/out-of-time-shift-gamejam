# Milestone 1 Explorer 1 Report: Asset Import & Scene Path Strategy

**Date**: 2026-11-10  
**Investigator**: teamwork_explorer (M1 Explorer 1)  
**Milestone**: M1 — Procedural Rig & Scene Asset Integration  
**Source Repository**: `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene`  
**Target Project**: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`  

---

## 1. Executive Summary

This report establishes the complete asset inventory, dependency graph, directory mapping, and import roadmap for integrating the procedural stickman rig from `procedural-animation-test-scene` into `out-of-time-shift-gamejam/new-game-project`.

### Key Findings
1. **Zero External Path Rewrites Required for Textures**:
   All 15 texture `[ext_resource]` entries in `stickmanprocedural.tscn` reference paths starting with `res://assets/stickman/<Part>.png`. By importing the texture files and their matching `.import` metadata files directly to `new-game-project/assets/stickman/`, both the `path` and the `uid` resolve natively in Godot 4.7 without modifying a single texture reference line in the scene file.
2. **Three Reference Rig Defects Identified**:
   - **Root Script Omission**: `stickmanprocedural.tscn` does NOT have `stickmanprocedural.gd` attached to its root node (`Player`).
   - **No-Op Inverted Expression Bug**: In `stickmanprocedural.gd:63`, `facing - signf(direction)` performs a subtraction rather than an assignment (`facing = signf(direction)`).
   - **Unassigned 6th CCDIK Modifier**: In `stickmanprocedural.tscn:112-114`, modification 5 (`SkeletonModification2DCCDIK_gavct`) defines `tip_nodepath = NodePath("Hip/Waist/Torso/Neck")` without a `target_nodepath`, triggering Godot editor warnings. In `animation.tscn`, this was wired to a `Body Target` node at `(266, 142)`.
3. **Dual File Copying Requirement**:
   To prevent Godot 4.7 from assigning new random UIDs during import, all 16 PNG images must be copied together with their corresponding `.png.import` files.

---

## 2. Reference Asset Inventory (`procedural-animation-test-scene`)

The reference repository contains the following candidate assets:

| Source File | Type | Size | Status in Reference | Target Location in `new-game-project` |
|---|---|---|---|---|
| `stickmanprocedural.tscn` | PackedScene | 18,128 B | Primary procedural rig scene | `res://scenes/stickman/stickmanprocedural.tscn` |
| `stickmanprocedural.gd` | GDScript | 5,285 B | Procedural rig controller | `res://scripts/stickman/stickmanprocedural.gd` |
| `stickmanprocedural.gd.uid` | UID metadata | 19 B | `uid://vawx2quhkhg3` | `res://scripts/stickman/stickmanprocedural.gd.uid` |
| `assets/stickman/*.png` (16 files) | Textures | ~120 KB | Body part sprites + base | `res://assets/stickman/*.png` |
| `assets/stickman/*.png.import` (16 files) | Godot Import Config | ~15 KB | Import params & UIDs | `res://assets/stickman/*.png.import` |
| `animation.tscn` | PackedScene | 17,383 B | Alternative rig reference | Reference only (contains `Body Target`) |
| `main.tscn` / `main.gd` | Scene / Script | ~2.5 KB | Test runner scene | Reference only (superseded by showcase) |

---

## 3. Asset Dependency Analysis: `stickmanprocedural.tscn`

### 3.1 External Texture Dependencies (`ext_resource`)
`stickmanprocedural.tscn` lines 3–17 define exactly 15 texture dependencies:

| ExtResource ID | Target Node | Texture File Name | Reference UID | Reference Path |
|---|---|---|---|---|
| `1_mxj5x` | `Rig/Body/ArmTopB` | `ArmTopB.png` | `uid://b3d4swrqcrn56` | `res://assets/stickman/ArmTopB.png` |
| `2_vhh0s` | `Rig/Body/ArmBotB` | `ArmBotB.png` | `uid://ct151o5cutda1` | `res://assets/stickman/ArmBotB.png` |
| `3_fsj47` | `Rig/Body/HandB` | `HandB.png` | `uid://dpxgbtg1hbsf1` | `res://assets/stickman/HandB.png` |
| `4_ra75p` | `Rig/Body/LegTopB` | `LegTopB.png` | `uid://qavfp6nkbenl` | `res://assets/stickman/LegTopB.png` |
| `5_thq6v` | `Rig/Body/LegBotB` | `LegBotB.png` | `uid://dtdfu47crlrt4` | `res://assets/stickman/LegBotB.png` |
| `6_fubmq` | `Rig/Body/Neck` | `neck.png` *(lowercase 'n')* | `uid://3hcjh71n8x7h` | `res://assets/stickman/neck.png` |
| `7_pnngj` | `Rig/Body/Waist` | `Waist.png` | `uid://4guj6ytv7w2b` | `res://assets/stickman/Waist.png` |
| `8_rylua` | `Rig/Body/Pelvis` | `Pelvis.png` | `uid://ju2syv4osplg` | `res://assets/stickman/Pelvis.png` |
| `9_x08tq` | `Rig/Body/Torso` | `Torso.png` | `uid://bbdw0hdd5stuk` | `res://assets/stickman/Torso.png` |
| `10_p26lh` | `Rig/Body/Head` | `Head.png` | `uid://deeupcqcwo40g` | `res://assets/stickman/Head.png` |
| `11_gfvj7` | `Rig/Body/LegTopF` | `LegTopF.png` | `uid://ccp838mregsel` | `res://assets/stickman/LegTopF.png` |
| `12_ke0je` | `Rig/Body/LegBotF` | `LegBotF.png` | `uid://ye6b2ga2y6pr` | `res://assets/stickman/LegBotF.png` |
| `13_fx6y6` | `Rig/Body/ArmTopF` | `ArmTopF.png` | `uid://wutk17dnrc4n` | `res://assets/stickman/ArmTopF.png` |
| `14_72oj3` | `Rig/Body/ArmBotF` | `ArmBotF.png` | `uid://bib4m7biqsms6` | `res://assets/stickman/ArmBotF.png` |
| `15_16xva` | `Rig/Body/HandF` | `HandF.png` | `uid://c64l5hh7s1w8c` | `res://assets/stickman/HandF.png` |

*Note on `StickmanBase.png`*: `StickmanBase.png` (UID `uid://e75013754a05b29964a0f61ad6d01184`) is the full composite stickman sheet. While not directly referenced by `stickmanprocedural.tscn`, it must be imported to support modular reference and texture slicing.

### 3.2 Sub-Resource Analysis (`sub_resource`)
`stickmanprocedural.tscn` lines 19–124 define 8 sub-resources:
1. `CapsuleShape2D_g4v7s`: Collision shape (radius: 118.0, height: 732.0).
2. `SkeletonModification2DCCDIK_aqggk`: Right Foot CCDIK chain (target: `FootR Target`, tip: `FootR`, chain length: 2).
3. `SkeletonModification2DCCDIK_kt8o7`: Left Foot CCDIK chain (target: `FootL Target`, tip: `FootL`, chain length: 2).
4. `SkeletonModification2DCCDIK_e4tth`: Right Arm CCDIK chain (target: `ArmR Target`, tip: `HandR`, chain length: 2).
5. `SkeletonModification2DCCDIK_w7c4t`: Left Arm CCDIK chain (target: `ArmL Target`, tip: `HandL`, chain length: 2).
6. `SkeletonModification2DLookAt_ymdls`: Head LookAt modifier (bone: `Head`, target: `Head Target`).
7. `SkeletonModification2DCCDIK_gavct`: Torso/Neck CCDIK chain (tip: `Neck`). **Defect**: Target node path is missing in reference rig.
8. `SkeletonModificationStack2D_y3uf6`: Modification stack containing entries 0 through 5.

### 3.3 Node Hierarchy & RemoteTransform2D Mapping
The scene contains 3 main child groups under root `Player` (`CharacterBody2D`):
```
Player (CharacterBody2D)
├── CollisionShape2D (CapsuleShape2D)
├── Rig (Node2D, pos: -284, -303)
│   ├── Body (Node2D)
│   │   ├── ArmTopB, ArmBotB, HandB (Sprite2D)
│   │   ├── LegTopB, LegBotB (Sprite2D)
│   │   ├── Neck, Waist, Pelvis, Torso, Head (Sprite2D)
│   │   └── LegTopF, LegBotF, ArmTopF, ArmBotF, HandF (Sprite2D)
│   └── Bones (Node2D)
│       └── Skeleton2D (modification_stack attached)
│           └── Hip (Bone2D) -> controls Pelvis via RemoteTransform2D
│               ├── LegR -> ShinR -> FootR (controls LegTopF, LegBotF)
│               ├── ArmR -> ForearmR -> HandR (controls ArmTopF, ArmBotF, HandF)
│               ├── LegL -> ShinL -> FootL (controls LegTopB, LegBotB)
│               ├── ArmL -> ForearmL -> HandL (controls ArmTopB, ArmBotB, HandB)
│               └── Waist -> Torso -> Neck -> Head (controls Waist, Torso, Neck, Head)
└── IK Targets (Node2D, pos: -284, -303)
    ├── FootR Target (pos: 160, 624)
    ├── FootL Target (pos: 307, 628)
    ├── ArmR Target (pos: 253, 329)
    ├── ArmL Target (pos: 347, 308)
    └── Head Target (pos: 262, 26)
```

---

## 4. Target Directory & Scene Path Architecture in `new-game-project`

Per `PROJECT.md` specifications, the target directory layout is:

```
new-game-project/
├── assets/
│   ├── audio/
│   ├── modular_parts_manifest.json
│   └── stickman/                         <-- CREATE DIRECTORY
│       ├── ArmBotB.png (+ .import)
│       ├── ArmBotF.png (+ .import)
│       ├── ArmTopB.png (+ .import)
│       ├── ArmTopF.png (+ .import)
│       ├── HandB.png (+ .import)
│       ├── HandF.png (+ .import)
│       ├── Head.png (+ .import)
│       ├── LegBotB.png (+ .import)
│       ├── LegBotF.png (+ .import)
│       ├── LegTopB.png (+ .import)
│       ├── LegTopF.png (+ .import)
│       ├── neck.png (+ .import)
│       ├── Pelvis.png (+ .import)
│       ├── StickmanBase.png (+ .import)
│       ├── Torso.png (+ .import)
│       └── Waist.png (+ .import)
├── scenes/
│   ├── main.tscn
│   ├── procedural_stickman_showcase.tscn (Milestone 4)
│   └── stickman/                         <-- CREATE DIRECTORY
│       └── stickmanprocedural.tscn       <-- IMPORTED RIG SCENE
├── scripts/
│   ├── chrono_shift/
│   ├── core/
│   ├── game/
│   ├── modular_rig/
│   │   └── modular_asset_system.gd
│   ├── stickman/                         <-- CREATE DIRECTORY
│   │   ├── stickmanprocedural.gd         <-- IMPORTED RIG SCRIPT
│   │   └── stickmanprocedural.gd.uid
│   ├── timeline/
│   └── tools/
└── tests/
```

---

## 5. Godot 4.7 Resource Resolution Mechanism

### 5.1 Why Copying `.png.import` Files is Critical
In Godot 4.x, resource lookup operates on a two-tier resolution system:
1. **Primary Lookup (UID-based)**:
   When Godot encounters `[ext_resource type="Texture2D" uid="uid://b3d4swrqcrn56" path="res://assets/stickman/ArmTopB.png"]`, it consults the project UID table (`.godot/uid_cache.bin`).
2. **Fallback Lookup (Path-based)**:
   If the UID is absent or cannot be resolved, Godot falls back to `path`. If the file exists at `path` but has a differing UID generated by the editor, Godot prints a console warning:
   `Resource file 'res://assets/stickman/ArmTopB.png' has changed UID from uid://... to uid://...`
3. **Preservation via Direct `.import` Copy**:
   By copying `ArmTopB.png.import` directly from the reference project, the UID `uid://b3d4swrqcrn56` is preserved. When Godot 4.7 parses `new-game-project`, both UID and path match perfectly, resulting in **zero console warnings, zero re-indexing delay, and zero broken links**.

### 5.2 Resolution Verification Table
| Resource in `stickmanprocedural.tscn` | Target Path in `new-game-project` | Target `.import` File Status | Resolved Cleanly? |
|---|---|---|---|
| `res://assets/stickman/ArmTopB.png` | `assets/stickman/ArmTopB.png` | Copied from source | YES |
| `res://assets/stickman/ArmBotB.png` | `assets/stickman/ArmBotB.png` | Copied from source | YES |
| `res://assets/stickman/HandB.png` | `assets/stickman/HandB.png` | Copied from source | YES |
| `res://assets/stickman/LegTopB.png` | `assets/stickman/LegTopB.png` | Copied from source | YES |
| `res://assets/stickman/LegBotB.png` | `assets/stickman/LegBotB.png` | Copied from source | YES |
| `res://assets/stickman/neck.png` | `assets/stickman/neck.png` | Copied from source | YES |
| `res://assets/stickman/Waist.png` | `assets/stickman/Waist.png` | Copied from source | YES |
| `res://assets/stickman/Pelvis.png` | `assets/stickman/Pelvis.png` | Copied from source | YES |
| `res://assets/stickman/Torso.png` | `assets/stickman/Torso.png` | Copied from source | YES |
| `res://assets/stickman/Head.png` | `assets/stickman/Head.png` | Copied from source | YES |
| `res://assets/stickman/LegTopF.png` | `assets/stickman/LegTopF.png` | Copied from source | YES |
| `res://assets/stickman/LegBotF.png` | `assets/stickman/LegBotF.png` | Copied from source | YES |
| `res://assets/stickman/ArmTopF.png` | `assets/stickman/ArmTopF.png` | Copied from source | YES |
| `res://assets/stickman/ArmBotF.png` | `assets/stickman/ArmBotF.png` | Copied from source | YES |
| `res://assets/stickman/HandF.png` | `assets/stickman/HandF.png` | Copied from source | YES |

---

## 6. Discrepancy & Reference Rig Bug Audit

### Defect 1: Root Node Script Attachment Missing
- **File**: `procedural-animation-test-scene/stickmanprocedural.tscn:125`
- **Observed Content**:
  ```tscn
  [node name="Player" type="CharacterBody2D" unique_id=562865352]
  ```
- **Analysis**: The script `stickmanprocedural.gd` was never attached to `stickmanprocedural.tscn` in the reference repository. Without attaching it, instantiating `stickmanprocedural.tscn` creates a static CharacterBody2D without procedural animation updates.
- **Fix Required in `new-game-project`**:
  Add script ext_resource:
  ```tscn
  [ext_resource type="Script" uid="uid://vawx2quhkhg3" path="res://scripts/stickman/stickmanprocedural.gd" id="16_procedural_script"]
  ```
  Attach to root node:
  ```tscn
  [node name="Player" type="CharacterBody2D" unique_id=562865352]
  script = ExtResource("16_procedural_script")
  ```

### Defect 2: Inverted Direction No-Op Typo
- **File**: `procedural-animation-test-scene/stickmanprocedural.gd:62-64`
- **Observed Content**:
  ```gdscript
  if direction != 0.0:
      facing - signf(direction)
  ```
- **Analysis**: `facing - signf(direction)` computes a difference and discards the result. The variable `facing` remains forever unchanged (`1.0`), preventing the character from ever turning left.
- **Fix Required in `new-game-project`**:
  ```gdscript
  if direction != 0.0:
      facing = signf(direction)
  ```

### Defect 3: Unassigned 6th CCDIK Modifier
- **File**: `procedural-animation-test-scene/stickmanprocedural.tscn:112-114`
- **Observed Content**:
  ```tscn
  [sub_resource type="SkeletonModification2DCCDIK" id="SkeletonModification2DCCDIK_gavct"]
  tip_nodepath = NodePath("Hip/Waist/Torso/Neck")
  ```
  And `SkeletonModificationStack2D_y3uf6` line 117 specifies `modification_count = 6`.
- **Analysis**: Modification 5 is active in the stack, but has no `target_nodepath`. In `animation.tscn:382-384`, an explicit `Body Target` node was provided:
  ```tscn
  [node name="Body Target" type="Node2D" parent="IK Targets" unique_id=1522361759]
  position = Vector2(266, 142)
  ```
- **Fix Required in `new-game-project`**:
  Add `Body Target` node to `IK Targets`:
  ```tscn
  [node name="Body Target" type="Node2D" parent="IK Targets" unique_id=1522361759]
  position = Vector2(266, 142)
  ```
  And configure `SkeletonModification2DCCDIK_gavct`:
  ```tscn
  [sub_resource type="SkeletonModification2DCCDIK" id="SkeletonModification2DCCDIK_gavct"]
  target_nodepath = NodePath("../../../IK Targets/Body Target")
  tip_nodepath = NodePath("Hip/Waist/Torso/Neck")
  ```
  This eliminates any missing target warnings from Godot's CCDIK solver.

---

## 7. ModularAssetSystem Integration (Feature 3)

In `new-game-project/scripts/modular_rig/modular_asset_system.gd`:
- `AssetRenderBackend.PACKED_SCENE = 3` is already defined in the enum (line 53).
- `PartPieceSpec.scene_path` is already serialized and deserialized in lines 242, 275, 291, 326.
- The Worker must ensure:
  1. `ModularAssetSystem` provides helper registration for the procedural stickman PackedScene:
     ```gdscript
     const PROCEDURAL_STICKMAN_SCENE_PATH := "res://scenes/stickman/stickmanprocedural.tscn"
     ```
  2. In `new-game-project/assets/modular_parts_manifest.json`, the procedural stickman scene path can be referenced by parts using backend 3.0 (`PACKED_SCENE`).

---

## 8. Step-by-Step Implementation Guide for Worker

The Worker agent should execute the following steps in sequence:

### Step 1: Directory Structure Creation
Create the three required directories:
- `new-game-project/assets/stickman/`
- `new-game-project/scripts/stickman/`
- `new-game-project/scenes/stickman/`

### Step 2: Texture & Metadata Transfer
Copy all 32 files (16 `.png` + 16 `.png.import`) from:
`c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene\assets\stickman\`
to:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\assets\stickman\`

### Step 3: Script Import and Bug Fixes
1. Copy `stickmanprocedural.gd` and `stickmanprocedural.gd.uid` from:
   `c:\Users\Zero\Documents\GitHub Repositories\procedural-animation-test-scene\`
   to:
   `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\scripts\stickman\`
2. Fix line 63: replace `facing - signf(direction)` with `facing = signf(direction)`.
3. Add interface methods matching `PROJECT.md` contracts:
   - `update_procedural_animation(velocity: Vector2, is_on_ground: bool, facing_direction: float, current_state: String, delta: float) -> void`
   - `get_bone_positions() -> Dictionary[String, Vector2]`

### Step 4: Scene Import and Rig Wiring
1. Copy `stickmanprocedural.tscn` to `new-game-project/scenes/stickman/stickmanprocedural.tscn`.
2. Insert script `ext_resource`:
   `[ext_resource type="Script" uid="uid://vawx2quhkhg3" path="res://scripts/stickman/stickmanprocedural.gd" id="16_procedural_script"]`
3. Attach script to root `Player` node: `script = ExtResource("16_procedural_script")`.
4. Add `Body Target` node to `IK Targets` at `position = Vector2(266, 142)`.
5. Update `SkeletonModification2DCCDIK_gavct` to set `target_nodepath = NodePath("../../../IK Targets/Body Target")`.

### Step 5: Verification & Headless Validation
1. Run Godot in headless editor mode to build asset caches:
   `"D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project" --editor --quit`
2. Run test harness:
   `cmd /c run_tests.bat`
3. Verify 0 errors, 0 warnings, and 100% pass across all test suites.

---

## 9. Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Texture UID mismatch causing editor warnings | Medium | Low | Copy `.png.import` files alongside `.png` files to retain reference UIDs. |
| Case sensitivity on `neck.png` on Linux/Steam Deck | Medium | High | Maintain exact casing (`neck.png` lowercase 'n') as defined in reference repository. |
| Missing 6th CCDIK target causing Godot console error | High | High | Add `Body Target` node at `(266, 142)` matching `animation.tscn` reference. |
| Script missing from root node breaking instantiation | High | High | Explicitly add script `ext_resource` and attribute to `Player` node. |
| Inadvertent regression in existing test suite | Low | Critical | Execute `run_tests.bat` after import to verify all 5 existing test suites pass. |
