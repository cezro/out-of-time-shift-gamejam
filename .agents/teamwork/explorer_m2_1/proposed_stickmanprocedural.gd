class_name StickmanProcedural
extends CharacterBody2D

## Procedural 2D Stickman Character Controller & IK Rig
## Combines 2D Skeletal Inverse Kinematics (CCDIK + LookAt) with a distance-driven mathematical gait.
## Integrates with ModularAssetSystem and game entities in new-game-project.

@export_group("Control Mode")
## If true, reads Input and executes physics movement autonomously (e.g. standalone showcase).
## If false (default for entities/PACKED_SCENE), driven externally via update_procedural_animation.
@export var autonomous_physics: bool = false

@export_group("Movement")
@export var move_speed: float = 260.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1800.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -480.0
@export var maximum_fall_speed: float = 900.0

@export_group("Running Animation")
@export var stride_length: float = 52.0
@export var foot_lift: float = 6.0
@export var arm_swing: float = 24.0
@export var hand_lift: float = 6.0
@export var head_bounce: float = 2.5
@export var head_lean: float = 9.0
@export var snappiness: float = 18.0

@export_group("Air Animation")
@export var air_foot_spread: float = 14.0
@export var air_foot_lift: float = 12.0
@export var air_hand_lift: float = 18.0

# ----------------------------------------------------------------------------
# Backward Compatibility Property Aliases
# ----------------------------------------------------------------------------

var hand_swing: float:
	get: return arm_swing
	set(v): arm_swing = v

var pose_response: float:
	get: return snappiness
	set(v): snappiness = v

# ----------------------------------------------------------------------------
# Node References
# ----------------------------------------------------------------------------

@onready var rig_node: Node2D = get_node_or_null("Rig")
@onready var ik_targets_node: Node2D = get_node_or_null("IK Targets")
@onready var skeleton: Skeleton2D = get_node_or_null("Rig/Bones/Skeleton2D")

@onready var foot_r: Node2D = get_node_or_null("IK Targets/FootR Target")
@onready var foot_l: Node2D = get_node_or_null("IK Targets/FootL Target")
@onready var arm_r: Node2D = get_node_or_null("IK Targets/ArmR Target")
@onready var arm_l: Node2D = get_node_or_null("IK Targets/ArmL Target")
@onready var head_target: Node2D = get_node_or_null("IK Targets/Head Target")

var targets: Array[Node2D] = []
var rest_positions: Dictionary = {}

var phase: float = 0.0
var facing: float = 1.0
var current_anim_state: String = "idle"

const HIP_REST_X: float = 284.51


# ----------------------------------------------------------------------------
# Lifecycle
# ----------------------------------------------------------------------------

func _ensure_references() -> void:
	if rig_node == null:
		rig_node = get_node_or_null("Rig")
	if ik_targets_node == null:
		ik_targets_node = get_node_or_null("IK Targets")
	if skeleton == null:
		skeleton = get_node_or_null("Rig/Bones/Skeleton2D")
	if foot_r == null:
		foot_r = get_node_or_null("IK Targets/FootR Target")
	if foot_l == null:
		foot_l = get_node_or_null("IK Targets/FootL Target")
	if arm_r == null:
		arm_r = get_node_or_null("IK Targets/ArmR Target")
	if arm_l == null:
		arm_l = get_node_or_null("IK Targets/ArmL Target")
	if head_target == null:
		head_target = get_node_or_null("IK Targets/Head Target")
	if targets.is_empty():
		for t in [foot_r, foot_l, arm_r, arm_l, head_target]:
			if t != null:
				targets.append(t)
				if not rest_positions.has(t):
					rest_positions[t] = t.position


func _ready() -> void:
	_ensure_references()
	floor_snap_length = 6.0

	# When externally controlled by game entities, autonomous physics is deactivated
	if not autonomous_physics:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not autonomous_physics:
		return

	var direction: float = get_move_input()

	if direction != 0.0:
		# BUG FIX: original code had 'facing - signf(direction)' which was a no-op
		facing = signf(direction)

	var target_velocity: float = direction * move_speed
	var rate: float = acceleration if direction != 0.0 else deceleration

	velocity.x = move_toward(velocity.x, target_velocity, rate * delta)

	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		if jump_pressed():
			velocity.y = jump_velocity
	else:
		velocity.y = minf(velocity.y + gravity * delta, maximum_fall_speed)

	move_and_slide()

	var is_grounded: bool = is_on_floor()
	var state: String = "run" if (is_grounded and absf(velocity.x) > 20.0) else ("air" if not is_grounded else "idle")

	update_procedural_animation(velocity, is_grounded, facing, state, delta)


func get_move_input() -> float:
	return Input.get_axis("ui_left", "ui_right")


func jump_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept")


# ----------------------------------------------------------------------------
# External Interface Methods
# ----------------------------------------------------------------------------

## Primary interface method: updates gait phase, target offsets, and IK lerping.
func update_procedural_animation(
	p_velocity: Vector2,
	is_on_ground: bool,
	facing_direction: float,
	current_state: String,
	delta: float
) -> void:
	_ensure_references()
	current_anim_state = current_state

	# Update facing direction if non-zero
	if facing_direction != 0.0:
		facing = 1.0 if facing_direction >= 0.0 else -1.0

	var speed: float = absf(p_velocity.x)
	var speed_ratio: float = clampf(speed / maxf(move_speed, 1.0), 0.0, 1.0)

	# Accumulate gait phase based on horizontal ground displacement
	if is_on_ground and stride_length > 0.01:
		var distance_moved: float = speed * delta
		phase = fposmod(phase + distance_moved / (stride_length * 2.0), 1.0)

	update_target_animation(delta, speed_ratio, is_on_ground, p_velocity, current_state)


## Updates IK target positions by interpolating toward rest_position + computed offsets.
func update_target_animation(
	delta: float,
	speed_ratio: float,
	is_on_ground: bool = true,
	p_velocity: Vector2 = Vector2.ZERO,
	current_state: String = "idle"
) -> void:
	var offsets: Dictionary = {}

	# Default standing / resting pose
	for target in targets:
		offsets[target] = Vector2.ZERO

	if not is_on_ground or current_state in ["jump", "fall", "air"]:
		apply_air_offsets(offsets, p_velocity)
	elif current_state == "wall_slide":
		apply_wall_slide_offsets(offsets)
	elif current_state in ["slash", "heavy_slash"]:
		apply_attack_offsets(offsets, current_state)
	elif current_state == "parry_guard":
		apply_parry_offsets(offsets)
	elif speed_ratio > 0.02 or current_state in ["run", "walk"]:
		apply_run_offsets(offsets, speed_ratio)

	var weight: float = 1.0 - exp(-snappiness * delta) if delta > 0.0 else 1.0

	for target in targets:
		var base_rest: Vector2 = get_mirrored_rest_position(target, facing)
		var offset: Vector2 = offsets.get(target, Vector2.ZERO)
		target.position = target.position.lerp(base_rest + offset, weight)


## Calculates mirrored rest position relative to the hip center (HIP_REST_X) to support facing flip.
func get_mirrored_rest_position(target: Node2D, cur_facing: float) -> Vector2:
	var base_rest: Vector2 = rest_positions.get(target, target.position)
	if cur_facing >= 0.0:
		return base_rest
	var dx: float = base_rest.x - HIP_REST_X
	return Vector2(HIP_REST_X - dx, base_rest.y)


# ----------------------------------------------------------------------------
# Offset Solvers
# ----------------------------------------------------------------------------

func apply_run_offsets(offsets: Dictionary, speed_ratio: float) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return

	var right_phase: float = phase
	var left_phase: float = fposmod(phase + 0.5, 1.0)

	offsets[foot_r] = get_foot_offset(right_phase)
	offsets[foot_l] = get_foot_offset(left_phase)

	var angle: float = phase * TAU
	var arm_amount: float = lerpf(0.35, 1.0, speed_ratio)

	# Hands counter-swing against their corresponding feet
	offsets[arm_r] = Vector2(
		-cos(angle) * arm_swing * facing,
		-absf(sin(angle)) * hand_lift
	) * arm_amount

	offsets[arm_l] = Vector2(
		cos(angle) * arm_swing * facing,
		-absf(sin(angle + PI)) * hand_lift
	) * arm_amount

	# Two head bounces per complete stride
	var bounce: float = (0.5 - 0.5 * cos(angle * 2.0)) * head_bounce * speed_ratio

	offsets[head_target] = Vector2(
		head_lean * facing * speed_ratio,
		-bounce
	)


func get_foot_offset(cycle: float) -> Vector2:
	var half_stride: float = stride_length * 0.5
	var x: float = 0.0
	var y: float = 0.0

	if cycle < 0.5:
		# Stance: move backward relative to the character
		var t: float = cycle / 0.5
		x = lerpf(half_stride, -half_stride, t)
	else:
		# Swing: lift the foot and return it to the front
		var t: float = (cycle - 0.5) / 0.5
		var eased: float = t * t * (3.0 - 2.0 * t)
		x = lerpf(-half_stride, half_stride, eased)
		y = -sin(t * PI) * foot_lift

	return Vector2(x * facing, y)


func apply_air_offsets(offsets: Dictionary, p_velocity: Vector2 = Vector2.ZERO) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return

	var rising: bool = (p_velocity.y < 0.0) if p_velocity != Vector2.ZERO else (velocity.y < 0.0)
	var tuck: float = 1.0 if rising else 0.45

	offsets[foot_r] = Vector2(air_foot_spread * facing, -air_foot_lift * tuck)
	offsets[foot_l] = Vector2(-air_foot_spread * facing, -air_foot_lift * tuck * 0.5)
	offsets[arm_r] = Vector2(-arm_swing * facing * 0.3, -air_hand_lift)
	offsets[arm_l] = Vector2(arm_swing * facing * 0.3, -air_hand_lift * 0.8)
	offsets[head_target] = Vector2(head_lean * facing * 0.4, -2.0)


func apply_wall_slide_offsets(offsets: Dictionary) -> void:
	if foot_r == null or foot_l == null or arm_r == null or arm_l == null or head_target == null:
		return
	offsets[foot_r] = Vector2(-15.0 * facing, -air_foot_lift * 1.4)
	offsets[foot_l] = Vector2(10.0 * facing, 8.0)
	offsets[arm_r] = Vector2(20.0 * facing, -10.0)
	offsets[arm_l] = Vector2(25.0 * facing, -5.0)
	offsets[head_target] = Vector2(-head_lean * facing * 0.5, 0.0)


func apply_attack_offsets(offsets: Dictionary, stance: String) -> void:
	if arm_r == null or arm_l == null or head_target == null:
		return
	var reach_mult: float = 1.6 if stance == "heavy_slash" else 1.2
	offsets[arm_r] = Vector2(arm_swing * facing * reach_mult, -hand_lift * 1.5)
	offsets[arm_l] = Vector2(-arm_swing * facing * 0.5, -hand_lift * 0.5)
	offsets[head_target] = Vector2(head_lean * facing * 1.2, 2.0)


func apply_parry_offsets(offsets: Dictionary) -> void:
	if arm_r == null or arm_l == null or head_target == null:
		return
	offsets[arm_r] = Vector2(15.0 * facing, -hand_lift * 2.5)
	offsets[arm_l] = Vector2(10.0 * facing, -hand_lift * 2.2)
	offsets[head_target] = Vector2(-head_lean * facing * 0.3, 0.0)


# ----------------------------------------------------------------------------
# Bone / Joint & Target Retrieval Interface
# ----------------------------------------------------------------------------

## Returns dictionary mapping joint/bone names to 2D coordinates in character-local space.
func get_bone_positions() -> Dictionary:
	_ensure_references()
	var result: Dictionary = {}
	if skeleton == null:
		return result

	var bone_map: Dictionary = {
		"pelvis": "Hip",
		"hip": "Hip",
		"neck": "Hip/Waist/Torso/Neck",
		"head": "Hip/Waist/Torso/Neck/Head",
		"head_center": "Hip/Waist/Torso/Neck/Head",
		"torso": "Hip/Waist/Torso",
		"waist": "Hip/Waist",
		"left_shoulder": "Hip/ArmL",
		"left_elbow": "Hip/ArmL/ForearmL",
		"left_hand": "Hip/ArmL/ForearmL/HandL",
		"right_shoulder": "Hip/ArmR",
		"right_elbow": "Hip/ArmR/ForearmR",
		"right_hand": "Hip/ArmR/ForearmR/HandR",
		"left_hip": "Hip/LegL",
		"left_knee": "Hip/LegL/ShinL",
		"left_foot": "Hip/LegL/ShinL/FootL",
		"right_hip": "Hip/LegR",
		"right_knee": "Hip/LegR/ShinR",
		"right_foot": "Hip/LegR/ShinR/FootR",
	}

	for key in bone_map.keys():
		var b_path: String = bone_map[key]
		var b_node: Node2D = skeleton.get_node_or_null(b_path)
		if b_node != null:
			result[key] = to_local(b_node.global_position)

	return result


## Returns dictionary mapping target names to target Node2D references.
func get_ik_targets() -> Dictionary:
	_ensure_references()
	return {
		"foot_r": foot_r,
		"foot_l": foot_l,
		"arm_r": arm_r,
		"arm_l": arm_l,
		"head": head_target,
	}


## Constructs a ModularAssetSystem.StickmanPose populated from this rig's live bone positions.
func to_stickman_pose(_loadout_facing: float = 1.0) -> RefCounted:
	var bones := get_bone_positions()
	var mas_script = load("res://scripts/modular_rig/modular_asset_system.gd")
	if mas_script == null:
		return null
	var pose_class = mas_script.StickmanPose
	var pose = pose_class.new()
	if bones.is_empty():
		return pose

	pose.head_center = bones.get("head_center", Vector2.ZERO)
	pose.neck = bones.get("neck", Vector2.ZERO)
	pose.pelvis = bones.get("pelvis", Vector2.ZERO)
	pose.left_shoulder = bones.get("left_shoulder", Vector2.ZERO)
	pose.left_elbow = bones.get("left_elbow", Vector2.ZERO)
	pose.left_hand = bones.get("left_hand", Vector2.ZERO)
	pose.right_shoulder = bones.get("right_shoulder", Vector2.ZERO)
	pose.right_elbow = bones.get("right_elbow", Vector2.ZERO)
	pose.right_hand = bones.get("right_hand", Vector2.ZERO)
	pose.left_hip = bones.get("left_hip", Vector2.ZERO)
	pose.left_knee = bones.get("left_knee", Vector2.ZERO)
	pose.left_foot = bones.get("left_foot", Vector2.ZERO)
	pose.right_hip = bones.get("right_hip", Vector2.ZERO)
	pose.right_knee = bones.get("right_knee", Vector2.ZERO)
	pose.right_foot = bones.get("right_foot", Vector2.ZERO)
	pose.stance = current_anim_state
	return pose
