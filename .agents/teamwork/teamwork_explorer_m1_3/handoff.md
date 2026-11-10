# Handoff Report: Modular Asset System Integration Strategy (M1 Explorer 3)

**Agent**: M1 Explorer 3 (`teamwork_explorer_m1_3`)  
**Mission**: Analyze how `stickmanprocedural.tscn` should be integrated with `ModularAssetSystem`'s `PACKED_SCENE` render backend and tested in `test_modular_rig.gd`.  
**Target Project**: `new-game-project`  
**Date**: 2026-11-10  

---

## 1. Observation

1. **`ModularAssetSystem.AssetRenderBackend` Enum**:
   In `new-game-project/scripts/modular_rig/modular_asset_system.gd:49-54`:
   ```gdscript
   enum AssetRenderBackend {
       PROCEDURAL_VECTOR = 0,
       TEXTURE_SPRITE = 1,
       CUSTOM_POLYGON = 2,
       PACKED_SCENE = 3,
   }
   ```
   `PACKED_SCENE` is defined as enum value `3`.

2. **`PartPieceSpec` Scene Path & Serialization**:
   In `new-game-project/scripts/modular_rig/modular_asset_system.gd:242, 275, 291, 326`:
   - `var scene_path: String = ""` exists as a member of `PartPieceSpec`.
   - `duplicate_spec()` copies `copy.scene_path = scene_path`.
   - `to_dict()` outputs `"scene_path": scene_path`.
   - `from_dict()` reads `spec.scene_path = _Ser.safe_str(d.get("scene_path"), "")`.
   - However, neither `PartPieceSpec` nor `CharacterLoadout` has an `instantiate_scene()` or `instantiate_rig()` helper method.

3. **Current Built-In Presets in `ModularAssetRegistry`**:
   In `new-game-project/scripts/modular_rig/modular_asset_system.gd:1403-1806`:
   `_init_builtin_presets()` initializes exactly 7 character presets:
   `player_shift_staff`, `enemy_runner`, `enemy_ninja`, `enemy_heavy`, `enemy_gunner_semi`, `enemy_gunner_auto`, and `enemy_sniper`.
   None of these 7 presets use `AssetRenderBackend.PACKED_SCENE`. There is no built-in preset referencing `res://scenes/stickman/stickmanprocedural.tscn`.

4. **Existing Test Suite in `test_modular_rig.gd`**:
   In `new-game-project/tests/test_modular_rig.gd:14-29`:
   `test_modular_rig.gd` extends `SceneTree` and runs 6 tests:
   `_test_stickman_pose_solver_stances()`, `_test_all_20_part_slot_transforms()`, `_test_shift_staff_7_piece_assembly_and_key_alignment()`, `_test_runtime_piece_by_piece_injection()`, `_test_ragdoll_loadout_splitting()`, and `_test_json_manifest_roundtrip_and_mcp_bridge()`.
   Execution via headless Godot (`python -c "import subprocess; ..."`) yielded:
   ```
   === Test Summary: 190 passed, 0 failed ===
   ```
   There is zero coverage for `PACKED_SCENE` backend instantiation.

5. **Headless Instantiation Invariant**:
   In `new-game-project/tests/test_game_integration.gd:51-57`:
   Scenes instantiated from `PackedScene` require being added to `root` (`root.add_child(inst)`) for `@onready` variables and `_ready()` lifecycle hooks to execute. Once added, `root.remove_child(inst)` followed by `inst.free()` cleans up without orphan node warnings.

---

## 2. Logic Chain

1. **Backend Integration Viability**:
   From Observation 1 and 2, `ModularAssetSystem` was deliberately architected to support `PACKED_SCENE`, but only metadata fields (`backend = 3`, `scene_path = "..."`) were implemented. Adding instantiation methods `instantiate_scene()` on `PartPieceSpec` and `instantiate_rig()` on `CharacterLoadout` completes the backend lifecycle without altering existing vector/sprite/polygon paths.

2. **Preset & Registry Registration**:
   From Observation 3, callers need a standard preset to obtain the procedural stickman rig without manually building the dictionary. Introducing preset #8 (`player_procedural_stickman`) with `rig_scene_path = "res://scenes/stickman/stickmanprocedural.tscn"` and equipping a `PartPieceSpec` on `PartSlot.TORSO` with `backend = AssetRenderBackend.PACKED_SCENE` gives both loadout-level and slot-level access.

3. **Non-Regressive Automated Testing**:
   From Observation 4, Test 4 in `test_modular_rig.gd` validates an explicit list of 7 presets (`expected_presets`) and does not check `loadouts.size() == 7`. Therefore, adding an 8th preset causes 0 regressions to existing assertions.

4. **Headless Execution Safety**:
   From Observation 5, `test_modular_rig.gd` extends `SceneTree` and has direct access to `root`. Instantiating `stickmanprocedural.tscn`, adding it to `root`, exercising `update_procedural_animation()` and `get_bone_positions()`, and removing/freeing it guarantees that `@onready` targets are initialized and prevents orphan node memory leaks during headless test runs.

---

## 3. Caveats

1. **Scene File Availability**: The test in `test_modular_rig.gd` relies on `res://scenes/stickman/stickmanprocedural.tscn` being present. If run before Explorer 1's Worker imports the files, the test must guard execution via `ResourceLoader.exists()` so it skips gracefully rather than throwing a file-not-found error.
2. **Interface Contract Sync**: The test invokes `update_procedural_animation` and `get_bone_positions` per `PROJECT.md` contracts. These methods must be added by Explorer 2's Worker to `stickmanprocedural.gd`.
3. **Coordinate System**: Simulation coordinates in `ModularAssetSystem` (+Y UP) must be inverted for Godot Canvas Items (+Y DOWN) when passing velocities into the rig scene.

---

## 4. Conclusion

1. **ModularAssetSystem Registration**:
   - Add `func instantiate_scene() -> Node` to `PartPieceSpec`.
   - Add `var rig_scene_path: String = ""` and `func instantiate_rig() -> Node` to `CharacterLoadout`.
   - Add constant `PROCEDURAL_STICKMAN_SCENE_PATH = "res://scenes/stickman/stickmanprocedural.tscn"`.
   - Register preset `"player_procedural_stickman"` in `ModularAssetRegistry._init_builtin_presets()`.
   - Add `instantiate_rig(loadout_id)` and `get_rig_scene_path(loadout_id)` to `ModularAssetRegistry`.

2. **Automated Test in `tests/test_modular_rig.gd`**:
   - Add Test 7 (`_test_packed_scene_backend_and_procedural_stickman()`).
   - Validate preset existence, scene loading, node hierarchy (`Skeleton2D`, `Rig`, `IK Targets`), interface contract execution (`update_procedural_animation`, `get_bone_positions`), and teardown via `root.remove_child` + `free()`.

3. **Manifest Update**:
   - Update `assets/modular_parts_manifest.json` with the new part and loadout.

---

## 5. Verification Method

1. **Headless Modular Rig Test**:
   ```powershell
   python -c "import subprocess; res = subprocess.run([r'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe', '--headless', '--path', r'c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project', '--script', 'res://tests/test_modular_rig.gd'], capture_output=True, text=True); print(res.stdout); assert res.returncode == 0"
   ```
   **Expected Outcome**: All 7 tests pass (over 200 assertions passed, 0 failed).

2. **Full Regression Suite**:
   ```cmd
   run_tests.bat
   ```
   **Expected Outcome**: All 5 test suites pass with zero regressions (`ALL 5 TEST SUITES PASSED!`).

3. **Invalidation Conditions**:
   - Any failure in existing tests 1–6.
   - Null-dereference errors on `@onready` variables in `stickmanprocedural.gd`.
   - Orphan node memory leak warnings on test exit.
