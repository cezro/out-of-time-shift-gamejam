# Technical Analysis & Fix Recommendation: Coordinate Parity Remediation in `to_stickman_pose()`

**Author**: Milestone 1 Iteration 2 Explorer 2 (`teamwork_explorer_m1_it2_2`)  
**Target Recipient**: Orchestrator (`0fd925e9-f058-4fd8-8532-3aab95b2a4f6`)  
**Target File**: `new-game-project/scripts/stickman/stickmanprocedural.gd` (lines 372–400)  
**Date**: 2026-11-10  
**Status**: COMPLETE  

---

## 1. Problem Statement & Coordinate Invariant Specification

In `PROJECT.md` (lines 48–53) and `game_controller.gd` (lines 56–66), the engine defines a strict two-space coordinate model:

| Space | Coordinate System | Vertical Orientation | Horizontal Orientation | Primary Consumers |
|---|---|---|---|---|
| **Simulation Space** | Cartesian / Math 2D | $+Y$ is **UP**, $-Y$ is **DOWN** | $+X$ is **RIGHT**, $-X$ is **LEFT** | `PlayerKinematics`, `CombatMath`, `EnemyAI`, `TimelineSystem`, `ModularAssetSystem.StickmanPose`, `StickmanPoseSolver` |
| **Screen / Scene Space** | Godot 2D / CanvasItem | $+Y$ is **DOWN**, $-Y$ is **UP** | $+X$ is **RIGHT**, $-X$ is **LEFT** | Godot 2D nodes (`CharacterBody2D`, `Node2D`, `Skeleton2D`, `Bone2D`, `CanvasItem._draw`) |

### Invariant Contract (`PROJECT.md` line 50)
Simulation coordinates for any `StickmanPose` instance must strictly obey the anatomical vertical ordering:
$$\text{head\_center}.y > \text{neck}.y > \text{pelvis}.y > \text{knee}.y > \text{foot}.y$$

### Screen Projection Contract (`game_controller.gd` line 60)
The game rendering pipeline projects simulation points to screen coordinates via the canonical conversion function:
```gdscript
static func to_screen(sim_pos: Vector2) -> Vector2:
    return Vector2(sim_pos.x, -sim_pos.y)

static func to_sim(screen_pos: Vector2) -> Vector2:
    return Vector2(screen_pos.x, -screen_pos.y)
```

### The Bug in `to_stickman_pose()`
In `new-game-project/scripts/stickman/stickmanprocedural.gd` (lines 372–399), `get_bone_positions()` queries Godot bone transforms via `to_local(b_node.global_position)`. These positions reside in character-local Godot 2D space ($+Y$ DOWN).

However, `to_stickman_pose()` directly assigned these raw local coordinates into `pose.head_center`, `pose.neck`, `pose.pelvis`, etc., without converting from Godot 2D space ($+Y$ DOWN) to simulation space ($+Y$ UP).

---

## 2. Empirical Verification & Failure Analysis

We executed a live headless Godot instance with the compiled `stickmanprocedural.tscn` rig and extracted live bone positions:

### Empirical Coordinates in Character-Local Godot 2D Space
```
head_center: Vector2(-20.0, -184.0)
neck:        Vector2(-18.0, -161.0)
pelvis:      Vector2(  1.0,   -2.0)
left_hand:   Vector2( 62.8,    4.5)
right_hand:  Vector2(-31.0,   26.0)
right_foot:  Vector2(-123.8, 320.3)
left_foot:   Vector2( 23.0,  325.0)
```

### Concrete Invariant Violation
Evaluating the vertical ordering with raw coordinates:
$$\text{head\_center}.y (-184.0) < \text{neck}.y (-161.0) < \text{pelvis}.y (-2.0) < \text{foot}.y (+325.0)$$
This completely reverses the contract $\text{head\_center}.y > \text{neck}.y > \text{pelvis}.y$.

### Visual Projection Failure
When `game_controller.gd` passes this raw `StickmanPose` to `_draw_pose_skeleton()` or `_draw_modular_character()`, `to_screen()` negates the Y coordinate:
$$\text{to\_screen}(\text{head\_center}) = (-20.0, -(-184.0)) = (-20.0, +184.0) \quad \text{[rendered down near feet]}$$
$$\text{to\_screen}(\text{pelvis}) = (1.0, -(-2.0)) = (1.0, +2.0) \quad \text{[rendered at origin]}$$
$$\text{to\_screen}(\text{foot}) = (23.0, -(+325.0)) = (23.0, -325.0) \quad \text{[rendered up in the sky]}$$
The stickman renders completely inverted (upside down).

Furthermore, in `ModularAssetSystem.compute_slot_transform()`, part attachments rely on $+Y$ UP:
- `PartSlot.HEAD`: `end_pt = pose.head_center + Vector2(0.0, pose.head_radius)`
- `PartSlot.HAT_HELMET`: `end_pt = pose.head_center + Vector2(0.0, pose.head_radius * 1.65)`
- `PartSlot.EYES`: `eye_center = pose.head_center + Vector2(face_dir * 3.0, 1.0)`
With un-inverted coordinates, hats and eyes attach downwards into the neck/torso instead of upwards on the head.

---

## 3. Mathematical Transformation Strategy

To transform points from Godot 2D character-local coordinates to simulation space while preserving horizontal offsets and facing, we apply the reflection matrix across the horizontal X-axis:

$$
M_{local \to sim} = \begin{pmatrix} 1 & 0 \\ 0 & -1 \end{pmatrix}
$$

$$\vec{v}_{sim} = M_{local \to sim} \cdot \begin{pmatrix} x_{local} \\ y_{local} \end{pmatrix} = \begin{pmatrix} x_{local} \\ -y_{local} \end{pmatrix}$$

### Mathematical Properties:
1. **Preservation of Horizontal Coordinates and Offsets**:
   $$x_{sim} = x_{local}$$
   Any horizontal offset $\Delta x = x_2 - x_1$ in local space is identical in simulation space: $\Delta x_{sim} = \Delta x_{local}$.
2. **Preservation of Facing Direction**:
   In both Godot 2D and simulation space, $+X$ points RIGHT and $-X$ points LEFT.
   Since $x_{sim} = x_{local}$, forward torso lean ($x_{neck} \cdot \text{facing} > x_{pelvis} \cdot \text{facing}$) is strictly preserved for both $\text{facing} = +1.0$ and $\text{facing} = -1.0$.
3. **Restoration of Vertical Invariant**:
   $$y_{local, 1} < y_{local, 2} \iff -y_{local, 1} > -y_{local, 2} \iff y_{sim, 1} > y_{sim, 2}$$
   Since in Godot 2D: $y_{head} (-184.0) < y_{neck} (-161.0) < y_{pelvis} (-2.0) < y_{foot} (+325.0)$,
   in simulation space:
   $$y_{sim, head} (+184.0) > y_{sim, neck} (+161.0) > y_{sim, pelvis} (+2.0) > y_{sim, foot} (-325.0)$$
   The contract is strictly satisfied.
4. **Lossless Round-Trip Isometry (Involution)**:
   $$\text{to\_screen}(\vec{v}_{sim}) = \begin{pmatrix} x_{sim} \\ -y_{sim} \end{pmatrix} = \begin{pmatrix} x_{local} \\ -(-y_{local}) \end{pmatrix} = \begin{pmatrix} x_{local} \\ y_{local} \end{pmatrix} = \vec{v}_{local}$$
   When projected back to screen space for rendering, each joint lands at its exact pixel-level position in the Godot 2D scene.

---

## 4. Precise Implementation Design

We design two additions in `new-game-project/scripts/stickman/stickmanprocedural.gd`:

### 1. Robust Coordinate Converter (`_to_sim_coord`)
Includes NaN/Inf sanitization to conform to project robustness rules:
```gdscript
## Converts character-local Godot 2D coordinates (+Y DOWN) to simulation coordinates (+Y UP).
## Preserves horizontal coordinates (X) exactly, inverting only the vertical component (Y).
static func _to_sim_coord(local_pos: Vector2) -> Vector2:
	var safe_x: float = local_pos.x if is_finite(local_pos.x) else 0.0
	var safe_y: float = local_pos.y if is_finite(local_pos.y) else 0.0
	return Vector2(safe_x, -safe_y)
```

### 2. Remediated `to_stickman_pose()`
Transforms all 14 skeletal joint positions, sets `stance`, and populates secondary pose anchors (`sword_hilt`, `sword_tip`, `scarf_nodes`):
```gdscript
## Constructs a ModularAssetSystem.StickmanPose populated from this rig's live bone positions.
## Transforms coordinates from Godot 2D character-local space (+Y DOWN) into simulation space (+Y UP).
func to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted:
	var bones := get_bone_positions()
	var mas_script = load("res://scripts/modular_rig/modular_asset_system.gd")
	if mas_script == null:
		return null
	var pose_class = mas_script.StickmanPose
	var pose = pose_class.new()
	if bones.is_empty():
		return pose

	pose.head_center = _to_sim_coord(bones.get("head_center", Vector2.ZERO))
	pose.neck = _to_sim_coord(bones.get("neck", Vector2.ZERO))
	pose.pelvis = _to_sim_coord(bones.get("pelvis", Vector2.ZERO))
	pose.left_shoulder = _to_sim_coord(bones.get("left_shoulder", Vector2.ZERO))
	pose.left_elbow = _to_sim_coord(bones.get("left_elbow", Vector2.ZERO))
	pose.left_hand = _to_sim_coord(bones.get("left_hand", Vector2.ZERO))
	pose.right_shoulder = _to_sim_coord(bones.get("right_shoulder", Vector2.ZERO))
	pose.right_elbow = _to_sim_coord(bones.get("right_elbow", Vector2.ZERO))
	pose.right_hand = _to_sim_coord(bones.get("right_hand", Vector2.ZERO))
	pose.left_hip = _to_sim_coord(bones.get("left_hip", Vector2.ZERO))
	pose.left_knee = _to_sim_coord(bones.get("left_knee", Vector2.ZERO))
	pose.left_foot = _to_sim_coord(bones.get("left_foot", Vector2.ZERO))
	pose.right_hip = _to_sim_coord(bones.get("right_hip", Vector2.ZERO))
	pose.right_knee = _to_sim_coord(bones.get("right_knee", Vector2.ZERO))
	pose.right_foot = _to_sim_coord(bones.get("right_foot", Vector2.ZERO))
	pose.stance = current_anim_state

	# Resolve effective facing direction (+1.0 right, -1.0 left)
	var eff_facing: float = facing if (is_finite(facing) and facing != 0.0) else (
		loadout_facing if (is_finite(loadout_facing) and loadout_facing != 0.0) else 1.0
	)
	var face_dir: float = 1.0 if eff_facing >= 0.0 else -1.0

	# Populate weapon anchors (sword hilt at right hand, tip projecting in facing direction)
	pose.sword_hilt = pose.right_hand
	pose.sword_tip = pose.right_hand + Vector2(face_dir * 28.0, -14.0)

	# Populate scarf trailing nodes behind the head in simulation space
	var head_back: Vector2 = pose.head_center + Vector2(-face_dir * pose.head_radius, 0.0)
	pose.scarf_nodes = [
		head_back + Vector2(-face_dir * 8.0, 1.0),
		head_back + Vector2(-face_dir * 18.0, -1.0),
		head_back + Vector2(-face_dir * 28.0, -4.0),
	]

	return pose
```

---

## 5. Machine-Applicable Patch

```diff
--- a/new-game-project/scripts/stickman/stickmanprocedural.gd
+++ b/new-game-project/scripts/stickman/stickmanprocedural.gd
@@ -370,6 +370,16 @@
 	}
 
 
+## Converts character-local Godot 2D coordinates (+Y DOWN) to simulation coordinates (+Y UP).
+## Preserves horizontal coordinates (X) exactly, inverting only the vertical component (Y).
+static func _to_sim_coord(local_pos: Vector2) -> Vector2:
+	var safe_x: float = local_pos.x if is_finite(local_pos.x) else 0.0
+	var safe_y: float = local_pos.y if is_finite(local_pos.y) else 0.0
+	return Vector2(safe_x, -safe_y)
+
+
+## Constructs a ModularAssetSystem.StickmanPose populated from this rig's live bone positions.
+## Transforms coordinates from Godot 2D character-local space (+Y DOWN) into simulation space (+Y UP).
 func to_stickman_pose(loadout_facing: float = 1.0) -> RefCounted:
 	var bones := get_bone_positions()
 	var mas_script = load("res://scripts/modular_rig/modular_asset_system.gd")
@@ -380,21 +390,36 @@
 	if bones.is_empty():
 		return pose
 
-	pose.head_center = bones.get("head_center", Vector2.ZERO)
-	pose.neck = bones.get("neck", Vector2.ZERO)
-	pose.pelvis = bones.get("pelvis", Vector2.ZERO)
-	pose.left_shoulder = bones.get("left_shoulder", Vector2.ZERO)
-	pose.left_elbow = bones.get("left_elbow", Vector2.ZERO)
-	pose.left_hand = bones.get("left_hand", Vector2.ZERO)
-	pose.right_shoulder = bones.get("right_shoulder", Vector2.ZERO)
-	pose.right_elbow = bones.get("right_elbow", Vector2.ZERO)
-	pose.right_hand = bones.get("right_hand", Vector2.ZERO)
-	pose.left_hip = bones.get("left_hip", Vector2.ZERO)
-	pose.left_knee = bones.get("left_knee", Vector2.ZERO)
-	pose.left_foot = bones.get("left_foot", Vector2.ZERO)
-	pose.right_hip = bones.get("right_hip", Vector2.ZERO)
-	pose.right_knee = bones.get("right_knee", Vector2.ZERO)
-	pose.right_foot = bones.get("right_foot", Vector2.ZERO)
+	pose.head_center = _to_sim_coord(bones.get("head_center", Vector2.ZERO))
+	pose.neck = _to_sim_coord(bones.get("neck", Vector2.ZERO))
+	pose.pelvis = _to_sim_coord(bones.get("pelvis", Vector2.ZERO))
+	pose.left_shoulder = _to_sim_coord(bones.get("left_shoulder", Vector2.ZERO))
+	pose.left_elbow = _to_sim_coord(bones.get("left_elbow", Vector2.ZERO))
+	pose.left_hand = _to_sim_coord(bones.get("left_hand", Vector2.ZERO))
+	pose.right_shoulder = _to_sim_coord(bones.get("right_shoulder", Vector2.ZERO))
+	pose.right_elbow = _to_sim_coord(bones.get("right_elbow", Vector2.ZERO))
+	pose.right_hand = _to_sim_coord(bones.get("right_hand", Vector2.ZERO))
+	pose.left_hip = _to_sim_coord(bones.get("left_hip", Vector2.ZERO))
+	pose.left_knee = _to_sim_coord(bones.get("left_knee", Vector2.ZERO))
+	pose.left_foot = _to_sim_coord(bones.get("left_foot", Vector2.ZERO))
+	pose.right_hip = _to_sim_coord(bones.get("right_hip", Vector2.ZERO))
+	pose.right_knee = _to_sim_coord(bones.get("right_knee", Vector2.ZERO))
+	pose.right_foot = _to_sim_coord(bones.get("right_foot", Vector2.ZERO))
 	pose.stance = current_anim_state
+
+	var eff_facing: float = facing if (is_finite(facing) and facing != 0.0) else (
+		loadout_facing if (is_finite(loadout_facing) and loadout_facing != 0.0) else 1.0
+	)
+	var face_dir: float = 1.0 if eff_facing >= 0.0 else -1.0
+
+	pose.sword_hilt = pose.right_hand
+	pose.sword_tip = pose.right_hand + Vector2(face_dir * 28.0, -14.0)
+
+	var head_back: Vector2 = pose.head_center + Vector2(-face_dir * pose.head_radius, 0.0)
+	pose.scarf_nodes = [
+		head_back + Vector2(-face_dir * 8.0, 1.0),
+		head_back + Vector2(-face_dir * 18.0, -1.0),
+		head_back + Vector2(-face_dir * 28.0, -4.0),
+	]
+
 	return pose
```

---

## 6. Active Verification Recommendation for Test Suite

In `new-game-project/tests/test_challenger_m1_2_adversarial.gd` (around line 610), augment `test_14_live_rig_to_stickman_pose_simulation()` with active vertical invariant assertions:
```gdscript
	# Verify simulation coordinate invariants (+Y UP)
	ok = _check(pose.head_center.y > pose.neck.y, "head_center.y (%f) > neck.y (%f) in sim coordinates" % [pose.head_center.y, pose.neck.y]) and ok
	ok = _check(pose.neck.y > pose.pelvis.y, "neck.y (%f) > pelvis.y (%f) in sim coordinates" % [pose.neck.y, pose.pelvis.y]) and ok
	ok = _check(pose.pelvis.y > pose.left_foot.y, "pelvis.y (%f) > left_foot.y (%f) in sim coordinates" % [pose.pelvis.y, pose.left_foot.y]) and ok
	ok = _check(pose.pelvis.y > pose.right_foot.y, "pelvis.y (%f) > right_foot.y (%f) in sim coordinates" % [pose.pelvis.y, pose.right_foot.y]) and ok
```
This guarantees automated regression prevention in all future builds.
