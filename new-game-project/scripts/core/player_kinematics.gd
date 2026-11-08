class_name PlayerKinematics
extends RefCounted

## Pure player kinematics, movement configuration, chrono energy, and platform collision data.
## Coordinate convention: +Y is UP (floor_y = -260.0, jump_force = +580.0, gravity = 1400.0 subtracted from vy).


class MovementConfig extends RefCounted:
	var accel: float = 2200.0
	var decel: float = 2800.0
	var max_speed: float = 340.0
	var jump_force: float = 580.0
	var gravity: float = 1400.0
	var fall_gravity_mult: float = 1.6
	var short_hop_mult: float = 2.2
	var coyote_time_max: float = 0.12
	var jump_buffer_max: float = 0.12
	var dash_speed: float = 780.0
	var dash_duration: float = 0.14
	var dash_cooldown_max: float = 0.40
	var wall_slide_speed: float = -110.0
	var wall_jump_force: Vector2 = Vector2(420.0, 560.0)
	var slam_speed: float = -950.0


class ChronoEnergy extends RefCounted:
	var current: float = 100.0
	var max_energy: float = 100.0
	var drain_rate: float = 22.0
	var regen_rate: float = 14.0
	var teleport_cost: float = 25.0
	var kill_restore: float = 25.0

	func can_teleport() -> bool:
		return current >= teleport_cost

	func consume_teleport() -> bool:
		if can_teleport():
			current = maxf(0.0, current - teleport_cost)
			return true
		return false

	func update(is_dilating: bool, dt: float) -> void:
		var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
		if is_dilating:
			current = maxf(0.0, current - drain_rate * safe_dt)
		else:
			current = minf(max_energy, current + regen_rate * safe_dt)

	func update_with_drain(drain: float, dt: float) -> void:
		var safe_drain: float = maxf(0.0, drain) if is_finite(drain) else 0.0
		var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
		if safe_drain > 0.0:
			current = maxf(0.0, current - safe_drain * safe_dt)
		else:
			current = minf(max_energy, current + regen_rate * safe_dt)

	func reward_kill() -> void:
		current = minf(max_energy, current + kill_restore)

	func reset() -> void:
		current = max_energy


class PlatformData extends RefCounted:
	var min_x: float = -100.0
	var max_x: float = 100.0
	var y: float = 0.0
	var thickness: float = 10.0
	## Era availability: -1 = all eras, 0 = Past, 1 = Present, 2 = Future
	var era: int = -1

	func _init(center_x: float = 0.0, p_y: float = 0.0, width: float = 200.0, p_era: int = -1) -> void:
		min_x = center_x - width * 0.5
		max_x = center_x + width * 0.5
		y = p_y
		thickness = 10.0
		era = p_era

	func is_active_in_era(active_era: int) -> bool:
		return era == -1 or era == active_era


class PlayerState extends RefCounted:
	var position: Vector2 = Vector2(0.0, -200.0)
	var velocity: Vector2 = Vector2.ZERO
	var facing: float = 1.0
	var is_grounded: bool = true
	var is_wall_sliding: bool = false
	var wall_normal_x: float = 0.0
	var is_climbing_vine: bool = false
	var is_slamming: bool = false
	var coyote_timer: float = 0.0
	var jump_buffer_timer: float = 0.0
	var dash_timer: float = 0.0
	var dash_cooldown: float = 0.0
	var dash_dir: Vector2 = Vector2.RIGHT
	var slash_cooldown: float = 0.0
	var heavy_cooldown: float = 0.0
	var warp_cooldown: float = 0.0
	var parry_timer: float = 0.0
	var parry_cooldown: float = 0.0
	var invulnerability_timer: float = 0.0
	var health: float = 100.0
	var max_health: float = 100.0
	var config: MovementConfig = MovementConfig.new()
	var loadout_id: String = "player_default"

	func reset() -> void:
		position = Vector2(0.0, -200.0)
		velocity = Vector2.ZERO
		facing = 1.0
		is_grounded = true
		is_wall_sliding = false
		wall_normal_x = 0.0
		is_climbing_vine = false
		is_slamming = false
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		dash_timer = 0.0
		dash_cooldown = 0.0
		dash_dir = Vector2.RIGHT
		slash_cooldown = 0.0
		heavy_cooldown = 0.0
		warp_cooldown = 0.0
		parry_timer = 0.0
		parry_cooldown = 0.0
		invulnerability_timer = 0.0
		health = max_health


## Pure kinematic calculation for horizontal velocity with crisp acceleration and deceleration.
static func step_horizontal_velocity(current_vx: float, input_x: float, config: MovementConfig, dt: float) -> float:
	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	var safe_vx: float = current_vx if is_finite(current_vx) else 0.0
	var safe_input: float = input_x if is_finite(input_x) else 0.0

	if absf(safe_input) > 0.01:
		var target_vx: float = signf(safe_input) * config.max_speed
		var diff: float = target_vx - safe_vx
		var step: float = config.accel * safe_dt
		if absf(diff) <= step:
			return target_vx
		else:
			return safe_vx + signf(diff) * step
	else:
		var step: float = config.decel * safe_dt
		if absf(safe_vx) <= step:
			return 0.0
		else:
			return safe_vx - signf(safe_vx) * step


## Pure kinematic calculation for vertical velocity with coyote time, jump buffer, and gravity scaling.
## Returns {"vy": float, "coyote_timer": float, "jump_buffer_timer": float, "did_jump": bool}
static func step_vertical_velocity(
	current_vy: float,
	is_grounded: bool,
	jump_held: bool,
	jump_pressed: bool,
	coyote_timer: float,
	jump_buffer_timer: float,
	config: MovementConfig,
	dt: float
) -> Dictionary:
	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	var safe_coyote: float = maxf(0.0, coyote_timer) if is_finite(coyote_timer) else 0.0
	var safe_buffer: float = maxf(0.0, jump_buffer_timer) if is_finite(jump_buffer_timer) else 0.0
	var new_coyote: float = config.coyote_time_max if is_grounded else maxf(0.0, safe_coyote - safe_dt)
	var new_buffer: float = config.jump_buffer_max if jump_pressed else maxf(0.0, safe_buffer - safe_dt)
	var new_vy: float = current_vy if is_finite(current_vy) else 0.0
	var did_jump: bool = false

	if new_buffer > 0.0 and new_coyote > 0.0:
		new_vy = config.jump_force
		new_coyote = 0.0
		new_buffer = 0.0
		did_jump = true
	else:
		var effective_gravity: float = config.gravity
		if new_vy < 0.0:
			effective_gravity = config.gravity * config.fall_gravity_mult
		elif not jump_held and new_vy > 0.0:
			effective_gravity = config.gravity * config.short_hop_mult
		new_vy -= effective_gravity * safe_dt

	return {
		"vy": new_vy,
		"coyote_timer": new_coyote,
		"jump_buffer_timer": new_buffer,
		"did_jump": did_jump,
	}


## Starts Kinetic Dash, sets invulnerability, and cancels recovery frames of light slashes by zeroing slash_cooldown.
static func start_dash(player: PlayerState, input_x: float) -> bool:
	if player == null:
		return false
	if not is_finite(player.dash_cooldown):
		player.dash_cooldown = 0.0
	if not is_finite(player.position.x) or not is_finite(player.position.y):
		player.position = Vector2(
			player.position.x if is_finite(player.position.x) else 0.0,
			player.position.y if is_finite(player.position.y) else -200.0
		)
	if not is_finite(player.velocity.x) or not is_finite(player.velocity.y):
		player.velocity = Vector2(
			player.velocity.x if is_finite(player.velocity.x) else 0.0,
			player.velocity.y if is_finite(player.velocity.y) else 0.0
		)
	if not is_finite(player.facing) or absf(player.facing) < 1e-4:
		player.facing = 1.0
	if player.dash_cooldown > 0.0:
		return false

	player.dash_timer = player.config.dash_duration
	player.dash_cooldown = player.config.dash_cooldown_max
	var safe_invuln: float = maxf(0.0, player.invulnerability_timer) if is_finite(player.invulnerability_timer) else 0.0
	player.invulnerability_timer = maxf(safe_invuln, player.config.dash_duration)
	# Cancel recovery frames of light slashes on Kinetic Dash!
	player.slash_cooldown = 0.0
	player.is_slamming = false
	player.is_wall_sliding = false

	var dir_x: float = signf(input_x) if (is_finite(input_x) and absf(input_x) > 0.01) else (1.0 if player.facing >= 0.0 else -1.0)
	player.facing = dir_x
	player.dash_dir = Vector2(dir_x, 0.0)
	player.velocity = player.dash_dir * player.config.dash_speed
	return true


## Implements PDF spec Wall Rebound & Slide: stick to vertical surfaces/vines, slide down capped at wall_slide_speed,
## and launch diagonally upward on jump! Returns true if a wall rebound jump was triggered.
static func step_wall_slide_and_rebound(
	player: PlayerState,
	touching_wall_normal_x: float,
	jump_pressed: bool,
	_dt: float
) -> bool:
	if player == null:
		return false
	if not is_finite(player.position.x) or not is_finite(player.position.y):
		player.position = Vector2(
			player.position.x if is_finite(player.position.x) else 0.0,
			player.position.y if is_finite(player.position.y) else -200.0
		)
	if not is_finite(player.velocity.x) or not is_finite(player.velocity.y):
		player.velocity = Vector2(
			player.velocity.x if is_finite(player.velocity.x) else 0.0,
			player.velocity.y if is_finite(player.velocity.y) else 0.0
		)
	if not is_finite(player.facing) or absf(player.facing) < 1e-4:
		player.facing = 1.0

	if not player.is_grounded and is_finite(touching_wall_normal_x) and absf(touching_wall_normal_x) > 0.01:
		var normal_x: float = signf(touching_wall_normal_x)
		player.is_wall_sliding = true
		player.wall_normal_x = normal_x

		if jump_pressed:
			# Launch diagonally upward away from the wall surface
			player.velocity = Vector2(normal_x * player.config.wall_jump_force.x, player.config.wall_jump_force.y)
			player.facing = normal_x
			player.is_wall_sliding = false
			player.is_climbing_vine = false
			player.is_slamming = false
			player.coyote_timer = 0.0
			player.jump_buffer_timer = 0.0
			return true
		else:
			# Cap downward vertical slide velocity (+Y is up, so wall_slide_speed is -110.0)
			if player.velocity.y < player.config.wall_slide_speed:
				player.velocity.y = player.config.wall_slide_speed
			return false
	else:
		player.is_wall_sliding = false
		player.wall_normal_x = 0.0
		return false


## Initiates an airborne Downward Slam attack (fast vertical drop towards floor/platforms).
static func start_downward_slam(player: PlayerState) -> bool:
	if player == null:
		return false
	if not is_finite(player.position.x) or not is_finite(player.position.y):
		player.position = Vector2(
			player.position.x if is_finite(player.position.x) else 0.0,
			player.position.y if is_finite(player.position.y) else -200.0
		)
	if player.is_grounded or player.is_slamming:
		return false
	player.is_slamming = true
	player.is_wall_sliding = false
	player.dash_timer = 0.0
	player.velocity = Vector2(0.0, player.config.slam_speed)
	return true
