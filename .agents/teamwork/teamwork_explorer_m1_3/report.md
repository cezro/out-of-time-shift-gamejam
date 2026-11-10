# Modular Asset System Integration Strategy: `PACKED_SCENE` Backend & Procedural Stickman

**Explorer**: M1 Explorer 3 (`teamwork_explorer_m1_3`)  
**Target File Under Analysis**: `new-game-project/scripts/modular_rig/modular_asset_system.gd`  
**Test Harness Under Analysis**: `new-game-project/tests/test_modular_rig.gd`  
**Target Scene to Integrate**: `res://scenes/stickman/stickmanprocedural.tscn`  
**Date**: 2026-11-10  

---

## 1. Executive Summary

`ModularAssetSystem` (`new-game-project/scripts/modular_rig/modular_asset_system.gd`) provides an extensible, high-performance modular rig and asset framework for *OUT OF TIME*. It was engineered with support for four distinct render backends:
1. `AssetRenderBackend.PROCEDURAL_VECTOR` (0)
2. `AssetRenderBackend.TEXTURE_SPRITE` (1)
3. `AssetRenderBackend.CUSTOM_POLYGON` (2)
4. `AssetRenderBackend.PACKED_SCENE` (3)

While `PROCEDURAL_VECTOR`, `TEXTURE_SPRITE`, and `CUSTOM_POLYGON` are actively utilized across the 7 existing character presets (`player_shift_staff` and the 6 enemy archetypes) and tested in `test_modular_rig.gd`, `PACKED_SCENE` is currently defined at the enum and metadata level (`PartPieceSpec.scene_path`), but lacks an instantiation helper, dedicated preset registration, and automated integration testing.

This report establishes the complete architecture and implementation specification for:
- Registering `res://scenes/stickman/stickmanprocedural.tscn` as a first-class `PACKED_SCENE` loadout and part spec in `ModularAssetSystem`.
- Adding lifecycle instantiation methods to `PartPieceSpec`, `CharacterLoadout`, and `ModularAssetRegistry`.
- Implementing `_test_packed_scene_backend_and_procedural_stickman()` in `tests/test_modular_rig.gd` to verify scene instantiation, hierarchy integrity, and interface contract execution under headless Godot without regressing existing tests.
- Coordinating with Milestone 1 Explorer 1 (Asset Import Paths) and Explorer 2 (Rig Defect Remediation & Interface Strategy).

---

## 2. Current State Analysis of `modular_asset_system.gd`

### 2.1. Architectural Layout & Class Hierarchy

`modular_asset_system.gd` (1,806 lines, `class_name ModularAssetSystem extends RefCounted`) contains six primary internal classes:

```
ModularAssetSystem (RefCounted)
├── _Ser (Static Serialization Helpers)
├── PartPieceSpec (RefCounted) — Slot specification for individual anatomical/armor pieces
├── WeaponPieceSpec (RefCounted) — Slot specification for modular weapon components
├── WeaponAssemblySpec (RefCounted) — Multi-piece composite weapon (e.g. Shift Staff)
├── CharacterLoadout (RefCounted) — Full character equipment loadout (parts + weapon)
├── StickmanPose (RefCounted) — 2D joint coordinate container (+Y is UP pure sim coords)
├── StickmanPoseSolver (RefCounted) — Analytical mathematical pose generator
└── ModularAssetRegistry (RefCounted) — Global catalog, presets, and JSON manifest bridge
```

### 2.2. Current `PACKED_SCENE` Presence & Gap Analysis

In `modular_asset_system.gd`:
- **Enum Definition** (Lines 49–54):
  ```gdscript
  enum AssetRenderBackend {
      PROCEDURAL_VECTOR = 0,
      TEXTURE_SPRITE = 1,
      CUSTOM_POLYGON = 2,
      PACKED_SCENE = 3,
  }
  ```
- **PartPieceSpec Fields** (Lines 236–253):
  ```gdscript
  class PartPieceSpec extends RefCounted:
      var part_id: String = ""
      var slot: int = PartSlot.HEAD
      var backend: int = AssetRenderBackend.PROCEDURAL_VECTOR
      var texture_path: String = ""
      var texture: Texture2D = null
      var scene_path: String = ""
      ...
  ```
- **Serialization** (Lines 275, 291, 326):
  `scene_path` is already serialized in `to_dict()`, `from_dict()`, and `duplicate_spec()`.
- **Existing Manifest** (`assets/modular_parts_manifest.json`):
  Line 45 already serializes `"scene_path": ""` alongside `"backend": 0`.
- **Missing Capabilities (The Gaps)**:
  1. *No Instantiation Helper*: Neither `PartPieceSpec` nor `CharacterLoadout` has a method to instantiate the `PackedScene` referenced by `scene_path`.
  2. *No Procedural Stickman Rig Preset*: `ModularAssetRegistry._init_builtin_presets()` only populates vector and polygon presets for `player_shift_staff` and the 6 enemies. There is no built-in preset referencing `res://scenes/stickman/stickmanprocedural.tscn`.
  3. *No Loadout-Level Scene Pointer*: `CharacterLoadout` does not store a primary `rig_scene_path`, meaning callers must search through the `parts` dictionary to determine if a character has a root scene rig.
  4. *Zero Test Coverage for `PACKED_SCENE`*: `tests/test_modular_rig.gd` currently exercises tests 1 through 6 (190 assertions), none of which instantiate a scene backend.

---

## 3. Integration Strategy for `stickmanprocedural.tscn`

### 3.1. Path & Resource Specifications

Per `PROJECT.md` and Explorer 1 layout:
- **Scene File**: `res://scenes/stickman/stickmanprocedural.tscn`
- **Script File**: `res://scripts/stickman/stickmanprocedural.gd`
- **Body Part Sprites**: `res://assets/stickman/*.png`

### 3.2. Two-Tiered Registration Architecture

We formulate a clean, two-tiered registration model:

#### Tier 1: Loadout-Level Registration (`CharacterLoadout`)
A `CharacterLoadout` represents an entire entity. By adding:
- `var rig_scene_path: String = ""`
- `func instantiate_rig() -> Node`
Callers can query whether a loadout has an associated Godot Scene rig and instantiate it in a single call.

#### Tier 2: PartSlot-Level Registration (`PartPieceSpec`)
For fine-grained modularity, the procedural stickman rig can also be registered as a `PartPieceSpec`:
- `part_id`: `"procedural_stickman_rig_scene"`
- `slot`: `PartSlot.TORSO` (root torso anchor)
- `backend`: `AssetRenderBackend.PACKED_SCENE`
- `scene_path`: `"res://scenes/stickman/stickmanprocedural.tscn"`
- `func instantiate_scene() -> Node`

This dual support ensures maximum compatibility:
- Entities wanting a full scene-based character rig (e.g. player with IK bones or visual showcase) use `loadout.instantiate_rig()`.
- Entities wanting to attach modular sub-scenes to specific bones/slots use `part.instantiate_scene()`.

### 3.3. Built-In Preset in `ModularAssetRegistry`

In `ModularAssetRegistry._init_builtin_presets()`, register preset #8:
```gdscript
const PROCEDURAL_STICKMAN_SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"

# Preset 8: "player_procedural_stickman"
var stickman_rig := CharacterLoadout.new(
    "player_procedural_stickman",
    "Chronos Nomad (Procedural Rig)",
    player_white,
    electric_cyan
)
stickman_rig.rig_scene_path = PROCEDURAL_STICKMAN_SCENE_PATH

var stickman_part := PartPieceSpec.new(
    "procedural_stickman_rig_scene",
    PartSlot.TORSO,
    AssetRenderBackend.PACKED_SCENE,
    player_white,
    electric_cyan,
    2.5
)
stickman_part.scene_path = PROCEDURAL_STICKMAN_SCENE_PATH

register_part(stickman_part)
stickman_rig.equip_part(stickman_part)
register_loadout(stickman_rig)
```

### 3.4. Lifecycle Instantiation API Methods

Add the following methods to `modular_asset_system.gd`:

1. **In `PartPieceSpec`**:
   ```gdscript
   func instantiate_scene() -> Node:
       if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
           return null
       var packed: PackedScene = load(scene_path)
       if packed == null:
           return null
       return packed.instantiate()
   ```

2. **In `CharacterLoadout`**:
   ```gdscript
   var rig_scene_path: String = ""

   func instantiate_rig() -> Node:
       if not rig_scene_path.is_empty() and ResourceLoader.exists(rig_scene_path):
           var packed: PackedScene = load(rig_scene_path)
           if packed != null:
               return packed.instantiate()
       for slot_key in parts.keys():
           var part: PartPieceSpec = parts[slot_key]
           if part != null and part.backend == AssetRenderBackend.PACKED_SCENE and not part.scene_path.is_empty():
               return part.instantiate_scene()
       return null
   ```

3. **In `ModularAssetRegistry`**:
   ```gdscript
   func instantiate_rig(loadout_id: String) -> Node:
       var lo: CharacterLoadout = get_loadout(loadout_id)
       if lo != null:
           return lo.instantiate_rig()
       return null

   func get_rig_scene_path(loadout_id: String) -> String:
       var lo: CharacterLoadout = get_loadout(loadout_id)
       if lo == null:
           return ""
       if not lo.rig_scene_path.is_empty():
           return lo.rig_scene_path
       for slot_key in lo.parts.keys():
           var p: PartPieceSpec = lo.parts[slot_key]
           if p != null and p.backend == AssetRenderBackend.PACKED_SCENE:
               return p.scene_path
       return ""

   static func instantiate_scene_backend(scene_path: String) -> Node:
       if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
           return null
       var packed: PackedScene = load(scene_path)
       if packed == null:
           return null
       return packed.instantiate()
   ```

### 3.5. Coordinate System Alignment & Rig Scaling

| Parameter | Reference Rig (`procedural-animation-test-scene`) | Target Project (`new-game-project`) | Alignment Strategy |
|---|---|---|---|
| **Vertical Axis** | Godot Canvas Item (+Y is DOWN) | Pure Sim (+Y is UP, Bevy convention) | Invert Y velocity: $v_{y, \text{rig}} = -v_{y, \text{sim}}$ |
| **Character Height** | Capsule Height: 732px | Player Sim Height: ~48px (feet -260, head -212) | Scale factor: $48.0 / 732.0 \approx 0.0655$ applied to `Rig.scale` or root |
| **Facing Direction** | `facing = signf(direction)` | `player.facing = +1.0 / -1.0` | Flip `Rig.scale.x = facing` |
| **Position Anchor** | Rig offset `Vector2(-284, -303)` | Base Pelvis `pos + Vector2(0, 16)` | Map `Rig.position` relative to root CharacterBody2D |

---

## 4. Automated Test Design for `tests/test_modular_rig.gd`

### 4.1. Headless Godot SceneTree Considerations

`tests/test_modular_rig.gd` extends `SceneTree`. When running headlessly:
- `PackedScene.instantiate()` creates the node hierarchy in memory.
- In Godot, `@onready` variables and `_ready()` are **only evaluated when a node enters the active `SceneTree`** via `root.add_child(node)`.
- **Crucial Rule**: In `test_modular_rig.gd`, the test must add the instantiated rig to `root`:
  ```gdscript
  root.add_child(rig_node)
  ```
  And cleanly remove and free it upon test completion:
  ```gdscript
  root.remove_child(rig_node)
  rig_node.free()
  ```
  This guarantees that all 5 IK target `@onready` variables (`foot_r`, `foot_l`, `arm_r`, `arm_l`, `head_target`) and `rest_positions` in `stickmanprocedural.gd` are valid without throwing null-dereference errors.

### 4.2. Concrete Test Implementation Plan

Add Test 7 to `tests/test_modular_rig.gd`:

```gdscript
func _test_packed_scene_backend_and_procedural_stickman() -> void:
	print("-- Test 7: PACKED_SCENE backend registration & procedural stickman scene instantiation --")
	var registry := RigSystem.ModularAssetRegistry.new()

	# 1. Preset & Part Registration Check
	var stickman_loadout := registry.get_loadout("player_procedural_stickman")
	_assert(stickman_loadout != null, "player_procedural_stickman preset exists in ModularAssetRegistry")
	_assert(
		registry.get_rig_scene_path("player_procedural_stickman") == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH,
		"Procedural stickman scene path correctly mapped to res://scenes/stickman/stickmanprocedural.tscn"
	)

	var rig_part := stickman_loadout.get_part(RigSystem.PartSlot.TORSO)
	_assert(rig_part != null, "Torso slot has procedural stickman part equipped")
	_assert(
		rig_part.backend == RigSystem.AssetRenderBackend.PACKED_SCENE,
		"Equipped part uses AssetRenderBackend.PACKED_SCENE"
	)
	_assert(
		rig_part.scene_path == RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH,
		"Part scene_path matches PROCEDURAL_STICKMAN_SCENE_PATH"
	)

	# 2. File and ResourceLoader Check
	var scene_path: String = RigSystem.ModularAssetRegistry.PROCEDURAL_STICKMAN_SCENE_PATH
	var scene_exists: bool = ResourceLoader.exists(scene_path)
	_assert(scene_exists, "stickmanprocedural.tscn exists on disk at %s" % scene_path)
	if not scene_exists:
		printerr("    [SKIP] Cannot instantiate stickmanprocedural.tscn because file does not exist yet")
		return

	# 3. Instantiation via ModularAssetRegistry
	var rig_node: Node = registry.instantiate_rig("player_procedural_stickman")
	_assert(rig_node != null, "registry.instantiate_rig() successfully instantiated procedural stickman scene")
	if rig_node == null:
		return

	# Mount to SceneTree root to trigger @onready and _ready()
	root.add_child(rig_node)

	# 4. Hierarchy & Node Type Integrity Check
	_assert(rig_node is CharacterBody2D, "Root node is CharacterBody2D")
	_assert(rig_node.get_script() != null, "Root node has attached stickmanprocedural.gd script")
	_assert(rig_node.get_node_or_null("Rig") != null, "Rig Node2D exists in hierarchy")
	_assert(rig_node.get_node_or_null("Rig/Bones/Skeleton2D") != null, "Skeleton2D exists under Rig/Bones")
	_assert(rig_node.get_node_or_null("Rig/Body") != null, "Body visual container exists under Rig")
	_assert(rig_node.get_node_or_null("IK Targets") != null, "IK Targets container exists on root")

	# 5. Interface Contract Execution
	_assert(
		rig_node.has_method("update_procedural_animation"),
		"Rig implements update_procedural_animation() contract"
	)
	_assert(
		rig_node.has_method("get_bone_positions"),
		"Rig implements get_bone_positions() contract"
	)

	# Exercise running ground gait
	rig_node.call("update_procedural_animation", Vector2(240.0, 0.0), true, 1.0, "run", 0.016)
	_assert(is_equal_approx(float(rig_node.get("facing")), 1.0), "Rig facing is 1.0 after forward run")

	# Exercise aerial jump state with direction flip
	rig_node.call("update_procedural_animation", Vector2(-150.0, -320.0), false, -1.0, "jump", 0.016)
	_assert(is_equal_approx(float(rig_node.get("facing")), -1.0), "Rig facing turns to -1.0 on reverse jump")

	# Exercise bone position query
	var bone_dict: Dictionary = rig_node.call("get_bone_positions")
	_assert(bone_dict.has("hip") or bone_dict.has("Hip"), "Bone dictionary contains hip joint")
	_assert(bone_dict.has("head") or bone_dict.has("Head"), "Bone dictionary contains head joint")

	# 6. Teardown & Clean Cleanup
	root.remove_child(rig_node)
	rig_node.free()
	_assert(true, "Procedural stickman instance freed cleanly without orphan nodes")
```

### 4.3. Non-Regression Safeguards

1. **Zero Impact on Existing Tests**: Tests 1 through 6 in `test_modular_rig.gd` (the 190 passing assertions) do not make assumptions about total loadout count. `expected_presets` in Test 4 explicitly lists the 7 preset IDs and verifies each individually without checking `loadouts.size() == 7`.
2. **Adversarial Resilience**: `test_adversarial_disprover.gd` passes null and invalid fields to `PartPieceSpec.from_dict()`. The new fields (`rig_scene_path`) in `CharacterLoadout` will use `_Ser.safe_str()` with fallback `""`, guaranteeing 100% fuzz/null resilience.
3. **Headless Cleanliness**: Adding and removing from `root` guarantees no orphan node warnings in Godot headless console output.

---

## 5. Concrete Implementation Instructions for the Worker

### Step 1: Update `scripts/modular_rig/modular_asset_system.gd`
1. In `class PartPieceSpec`:
   - Add `func instantiate_scene() -> Node`
2. In `class CharacterLoadout`:
   - Add `var rig_scene_path: String = ""`
   - Update `duplicate_loadout()`, `to_dict()`, and `from_dict()` to serialize `rig_scene_path`.
   - Add `func instantiate_rig() -> Node`
3. In `class ModularAssetRegistry`:
   - Define `const PROCEDURAL_STICKMAN_SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"`
   - Add preset `"player_procedural_stickman"` to `_init_builtin_presets()`.
   - Add `func instantiate_rig(loadout_id: String) -> Node`
   - Add `func get_rig_scene_path(loadout_id: String) -> String`
   - Add `static func instantiate_scene_backend(scene_path: String) -> Node`

### Step 2: Update `assets/modular_parts_manifest.json`
Add the registered `procedural_stickman_rig_scene` part and `player_procedural_stickman` loadout to `assets/modular_parts_manifest.json` so tools (such as `godot-mcp` or `asset_mcp_bridge.gd`) can serialize and deserialize the procedural scene backend.

### Step 3: Update `tests/test_modular_rig.gd`
1. In `_init()`:
   Add call to `_test_packed_scene_backend_and_procedural_stickman()`.
2. Append `func _test_packed_scene_backend_and_procedural_stickman() -> void` as detailed in Section 4.2.

### Step 4: Verification Command
Run the test suite headlessly to verify 100% pass:
```powershell
python -c "import subprocess; res = subprocess.run([r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', '--headless', '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project', '--script', 'res://tests/test_modular_rig.gd'], capture_output=True, text=True); print(res.stdout); print('CODE:', res.returncode)"
```
And verify full project test suite passes:
```cmd
run_tests.bat
```
