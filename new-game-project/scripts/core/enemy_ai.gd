class_name EnemyAI
extends RefCounted

## Enemy types, AI state machine, aerial juggle physics, and wave progression manager.
## Ported from bevy-game-test/src/enemy.rs + OUT OF TIME spec.

enum EnemyType {
	RUNNER,
	NINJA,
	HEAVY,
	GUNNER_SEMI,
	GUNNER_AUTO,
	SNIPER,
}

enum StateKind {
	SPAWNING,
	CHASE,
	WINDUP,
	ATTACK,
	HITSTUN,
	JUGGLED,
}

enum WavePhase {
	INTERMISSION,
	SPAWNING,
	ACTIVE,
	WAVE_CLEARED,
}

const JUGGLE_GRAVITY_MULT: float = 0.55


class EnemyData extends RefCounted:
	var enemy_type: int = EnemyType.RUNNER
	var state: int = StateKind.CHASE
	var state_timer: float = 0.0
	var state_duration: float = 0.0
	var attack_has_hit: bool = false
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var facing: float = 1.0
	var is_grounded: bool = true
	var health: float = 1.0
	var max_health: float = 1.0
	var attack_range: float = 52.0
	var speed: float = 210.0
	var jump_force: float = 500.0
	var hitbox_radius: float = 18.0
	var attack_damage: float = 15.0
	var bullets_to_fire: int = 0
	var fire_cooldown: float = 0.0
	## Timeline era: 0 = Past, 1 = Present, 2 = Future
	var era: int = 1
	var juggle_timer: float = 0.0
	var laser_aim_dir: Vector2 = Vector2.RIGHT
	var loadout_id: String = "enemy_runner"

	func _init(p_type: int = EnemyType.RUNNER, p_pos: Vector2 = Vector2.ZERO, p_era: int = 1) -> void:
		enemy_type = p_type
		position = p_pos
		era = p_era
		state = StateKind.CHASE
		velocity = Vector2.ZERO
		facing = 1.0
		is_grounded = true
		bullets_to_fire = 0
		fire_cooldown = 0.0

		match enemy_type:
			EnemyType.RUNNER:
				health = 1.0
				max_health = 1.0
				attack_range = 52.0
				speed = 210.0
				jump_force = 500.0
				hitbox_radius = 18.0
				attack_damage = 15.0
				loadout_id = "enemy_runner"
			EnemyType.NINJA:
				health = 1.0
				max_health = 1.0
				attack_range = 65.0
				speed = 280.0
				jump_force = 620.0
				hitbox_radius = 16.0
				attack_damage = 20.0
				loadout_id = "enemy_ninja"
			EnemyType.HEAVY:
				health = 2.0
				max_health = 2.0
				attack_range = 80.0
				speed = 130.0
				jump_force = 420.0
				hitbox_radius = 26.0
				attack_damage = 35.0
				loadout_id = "enemy_heavy"
			EnemyType.GUNNER_SEMI:
				health = 1.0
				max_health = 1.0
				attack_range = 360.0
				speed = 160.0
				jump_force = 460.0
				hitbox_radius = 18.0
				attack_damage = 20.0
				loadout_id = "enemy_gunner_semi"
			EnemyType.GUNNER_AUTO:
				health = 1.0
				max_health = 1.0
				attack_range = 280.0
				speed = 180.0
				jump_force = 480.0
				hitbox_radius = 18.0
				attack_damage = 10.0
				loadout_id = "enemy_gunner_auto"
			EnemyType.SNIPER:
				health = 1.0
				max_health = 1.0
				attack_range = 520.0
				speed = 140.0
				jump_force = 480.0
				hitbox_radius = 18.0
				attack_damage = 30.0
				loadout_id = "enemy_sniper"


## Launches an enemy into the aerial JUGGLED state with lighter gravity (0.55x).
static func launch_enemy(enemy: EnemyData, launch_vel: Vector2, stun_duration: float = 0.65) -> void:
	if enemy == null:
		return
	enemy.state = StateKind.JUGGLED
	enemy.juggle_timer = maxf(0.1, stun_duration) if is_finite(stun_duration) else 0.65
	enemy.state_timer = enemy.juggle_timer
	enemy.state_duration = enemy.juggle_timer
	var safe_vx: float = launch_vel.x if is_finite(launch_vel.x) else 0.0
	var safe_vy: float = launch_vel.y if is_finite(launch_vel.y) else 480.0
	enemy.velocity = Vector2(safe_vx, safe_vy)
	enemy.is_grounded = false
	enemy.bullets_to_fire = 0


## Pure AI step function: updates enemy state and calculates intended horizontal motion and jump.
## Returns {"move_dir": float, "should_jump": bool, "gravity_scale": float}
static func step_enemy_ai(enemy: EnemyData, player_pos: Vector2, dt: float) -> Dictionary:
	if enemy == null:
		return {"move_dir": 0.0, "should_jump": false, "gravity_scale": 1.0}

	if not is_finite(enemy.position.x) or not is_finite(enemy.position.y):
		enemy.position = Vector2(
			enemy.position.x if is_finite(enemy.position.x) else 0.0,
			enemy.position.y if is_finite(enemy.position.y) else -200.0
		)
	var safe_player_pos := Vector2(
		player_pos.x if is_finite(player_pos.x) else enemy.position.x,
		player_pos.y if is_finite(player_pos.y) else enemy.position.y
	)

	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	var to_player: Vector2 = safe_player_pos - enemy.position
	var dist_x: float = absf(to_player.x)
	var dist_y: float = to_player.y
	var facing: float = 1.0 if to_player.x >= 0.0 else -1.0
	var should_jump: bool = false
	var move_dir: float = 0.0
	var is_gunner: bool = enemy.enemy_type in [EnemyType.GUNNER_SEMI, EnemyType.GUNNER_AUTO, EnemyType.SNIPER]

	match enemy.state:
		StateKind.SPAWNING:
			enemy.state_timer -= safe_dt
			if enemy.state_timer <= 0.0:
				enemy.state = StateKind.CHASE

		StateKind.CHASE:
			if is_gunner:
				var retreat_dist: float = 180.0 if enemy.enemy_type == EnemyType.SNIPER else 140.0
				if dist_x < retreat_dist:
					move_dir = -facing
					if enemy.is_grounded and dist_y > 45.0 and dist_x < 100.0:
						should_jump = true
				elif dist_x > enemy.attack_range:
					move_dir = facing
					if enemy.is_grounded and dist_y > 45.0 and dist_x < 180.0:
						should_jump = true
				else:
					var max_aim_y: float = 180.0 if enemy.enemy_type == EnemyType.SNIPER else 120.0
					if absf(dist_y) <= max_aim_y:
						var windup_time: float = 0.45
						match enemy.enemy_type:
							EnemyType.GUNNER_SEMI:
								windup_time = 0.45
							EnemyType.GUNNER_AUTO:
								windup_time = 0.35
							EnemyType.SNIPER:
								windup_time = 0.75
							_:
								windup_time = 0.40
						enemy.state = StateKind.WINDUP
						enemy.state_timer = windup_time
						enemy.state_duration = windup_time
						var aim_vec: Vector2 = (safe_player_pos + Vector2(0.0, 16.0)) - (enemy.position + Vector2(facing * 20.0, 14.0))
						enemy.laser_aim_dir = (
							aim_vec.normalized()
							if (is_finite(aim_vec.x) and is_finite(aim_vec.y) and aim_vec.length_squared() > 1.0)
							else Vector2(facing, 0.0)
						)
					else:
						if enemy.is_grounded and dist_y > 45.0:
							should_jump = true
						move_dir = facing * 0.5
			else:
				if dist_x <= enemy.attack_range and absf(dist_y) <= 50.0:
					var windup_time: float = 0.45
					match enemy.enemy_type:
						EnemyType.RUNNER:
							windup_time = 0.45
						EnemyType.NINJA:
							windup_time = 0.28
						EnemyType.HEAVY:
							windup_time = 0.70
						_:
							windup_time = 0.45
					enemy.state = StateKind.WINDUP
					enemy.state_timer = windup_time
					enemy.state_duration = windup_time
				else:
					move_dir = facing
					if enemy.is_grounded and dist_y > 45.0 and dist_x < 180.0:
						should_jump = true

		StateKind.WINDUP:
			if enemy.enemy_type == EnemyType.SNIPER:
				var aim_vec: Vector2 = (safe_player_pos + Vector2(0.0, 16.0)) - (enemy.position + Vector2(facing * 20.0, 14.0))
				enemy.laser_aim_dir = (
					aim_vec.normalized()
					if (is_finite(aim_vec.x) and is_finite(aim_vec.y) and aim_vec.length_squared() > 1.0)
					else Vector2(facing, 0.0)
				)
			enemy.state_timer -= safe_dt
			if enemy.state_timer <= 0.0:
				var attack_time: float = 0.25
				match enemy.enemy_type:
					EnemyType.RUNNER:
						attack_time = 0.25
					EnemyType.NINJA:
						attack_time = 0.20
					EnemyType.HEAVY:
						attack_time = 0.35
					EnemyType.GUNNER_SEMI:
						attack_time = 0.35
					EnemyType.GUNNER_AUTO:
						attack_time = 0.45
					EnemyType.SNIPER:
						attack_time = 0.30
				enemy.state = StateKind.ATTACK
				enemy.state_timer = attack_time
				enemy.state_duration = attack_time
				enemy.attack_has_hit = false

		StateKind.ATTACK:
			enemy.state_timer -= safe_dt
			if is_gunner:
				move_dir = -facing * 0.15
			else:
				move_dir = facing * 0.6
			if enemy.state_timer <= 0.0:
				enemy.state = StateKind.CHASE

		StateKind.HITSTUN:
			enemy.state_timer -= safe_dt
			if enemy.state_timer <= 0.0:
				enemy.state = StateKind.CHASE

		StateKind.JUGGLED:
			enemy.juggle_timer = maxf(0.0, enemy.juggle_timer - safe_dt)
			enemy.state_timer = enemy.juggle_timer
			move_dir = 0.0
			if enemy.juggle_timer <= 0.0 and enemy.is_grounded:
				enemy.state = StateKind.CHASE

	if absf(to_player.x) > 4.0:
		enemy.facing = facing

	var grav_scale: float = JUGGLE_GRAVITY_MULT if enemy.state == StateKind.JUGGLED else 1.0
	return {
		"move_dir": move_dir,
		"should_jump": should_jump,
		"gravity_scale": grav_scale,
	}


## Steps enemy movement, juggle gravity (0.55x when JUGGLED), platform landing, and out-of-bounds recovery.
static func step_enemy_physics(
	enemy: EnemyData,
	move_dir: float,
	should_jump: bool,
	platforms: Array,
	dt: float,
	floor_y: float = -260.0,
	gravity: float = 1200.0
) -> void:
	if enemy == null:
		return
	if not is_finite(enemy.position.x) or not is_finite(enemy.position.y):
		enemy.position = Vector2(
			enemy.position.x if is_finite(enemy.position.x) else 0.0,
			enemy.position.y if is_finite(enemy.position.y) else floor_y
		)
	if not is_finite(enemy.velocity.x) or not is_finite(enemy.velocity.y):
		enemy.velocity = Vector2(
			enemy.velocity.x if is_finite(enemy.velocity.x) else 0.0,
			enemy.velocity.y if is_finite(enemy.velocity.y) else 0.0
		)
	var safe_move_dir: float = clampf(move_dir, -1.0, 1.0) if is_finite(move_dir) else 0.0
	var safe_dt: float = clampf(dt, 0.0, 10.0) if (is_finite(dt) and dt > 0.0) else 0.0
	if safe_dt <= 0.0:
		return

	if should_jump and enemy.is_grounded and enemy.state != StateKind.JUGGLED:
		enemy.velocity.y = enemy.jump_force
		enemy.is_grounded = false

	var grav_mult: float = JUGGLE_GRAVITY_MULT if enemy.state == StateKind.JUGGLED else 1.0
	if enemy.state != StateKind.JUGGLED:
		enemy.velocity.x = safe_move_dir * enemy.speed
	else:
		enemy.velocity.x = move_toward(enemy.velocity.x, 0.0, 200.0 * safe_dt)
	enemy.velocity.y -= (gravity * grav_mult) * safe_dt

	var prev_y: float = enemy.position.y
	enemy.position.x += enemy.velocity.x * safe_dt
	enemy.position.y += enemy.velocity.y * safe_dt

	# Clamp to screen bounds and recover out-of-bounds enemies to floor_y
	enemy.position.x = clampf(enemy.position.x, -580.0, 580.0)
	if enemy.position.y < -350.0:
		enemy.position.y = floor_y
		enemy.velocity.y = 0.0
		enemy.is_grounded = true

	enemy.is_grounded = false
	if enemy.position.y <= floor_y:
		enemy.position.y = floor_y
		enemy.velocity.y = 0.0
		enemy.is_grounded = true
		if enemy.state == StateKind.JUGGLED and enemy.juggle_timer <= 0.0:
			enemy.state = StateKind.CHASE
	elif enemy.velocity.y <= 0.0:
		for plat in platforms:
			if plat == null:
				continue
			if enemy.position.x >= plat.min_x and enemy.position.x <= plat.max_x:
				if prev_y >= plat.y and enemy.position.y <= plat.y:
					enemy.position.y = plat.y
					enemy.velocity.y = 0.0
					enemy.is_grounded = true
					if enemy.state == StateKind.JUGGLED and enemy.juggle_timer <= 0.0:
						enemy.state = StateKind.CHASE
					break



## Handles gunner/sniper burst initialization and bullet firing during StateKind.ATTACK.
## Returns a CombatMath.BulletData instance when a shot is fired, or null otherwise.
static func step_gunner_attack(enemy: EnemyData, player_pos: Vector2, dt: float) -> CombatMath.BulletData:
	if enemy == null or enemy.state != StateKind.ATTACK:
		return null
	if not (enemy.enemy_type in [EnemyType.GUNNER_SEMI, EnemyType.GUNNER_AUTO, EnemyType.SNIPER]):
		return null

	if not is_finite(enemy.position.x) or not is_finite(enemy.position.y):
		enemy.position = Vector2(
			enemy.position.x if is_finite(enemy.position.x) else 0.0,
			enemy.position.y if is_finite(enemy.position.y) else -200.0
		)
	var safe_facing: float = 1.0 if (not is_finite(enemy.facing) or enemy.facing >= 0.0) else -1.0
	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	if not enemy.attack_has_hit:
		enemy.attack_has_hit = true
		match enemy.enemy_type:
			EnemyType.GUNNER_SEMI:
				enemy.bullets_to_fire = 1
			EnemyType.GUNNER_AUTO:
				enemy.bullets_to_fire = 4
			EnemyType.SNIPER:
				enemy.bullets_to_fire = 1
			_:
				enemy.bullets_to_fire = 1
		enemy.fire_cooldown = 0.0

	if enemy.fire_cooldown > 0.0:
		enemy.fire_cooldown -= safe_dt

	if enemy.bullets_to_fire > 0 and enemy.fire_cooldown <= 0.0:
		enemy.bullets_to_fire -= 1
		enemy.fire_cooldown = 0.09 if enemy.enemy_type == EnemyType.GUNNER_AUTO else 0.40

		var muzzle: Vector2 = enemy.position + Vector2(safe_facing * 20.0, 14.0)
		var safe_player: Vector2 = (
			player_pos
			if (is_finite(player_pos.x) and is_finite(player_pos.y))
			else (enemy.position + Vector2(safe_facing * 200.0, 0.0))
		)
		var player_target: Vector2 = safe_player + Vector2(0.0, 16.0)
		var to_target: Vector2 = player_target - muzzle
		var aim_dir: Vector2
		if is_finite(to_target.x) and is_finite(to_target.y) and to_target.length_squared() > 1.0:
			aim_dir = to_target.normalized()
		else:
			aim_dir = Vector2(safe_facing, 0.0)

		var bullet_speed: float = 540.0
		var bullet_damage: float = 20.0
		var bullet_radius: float = 6.0
		var is_auto: bool = false
		var bounces: int = 0

		match enemy.enemy_type:
			EnemyType.GUNNER_SEMI:
				bullet_speed = 540.0
				bullet_damage = 20.0
				bullet_radius = 6.0
				is_auto = false
				bounces = 0
			EnemyType.GUNNER_AUTO:
				bullet_speed = 420.0
				bullet_damage = 10.0
				bullet_radius = 5.0
				is_auto = true
				bounces = 0
			EnemyType.SNIPER:
				bullet_speed = 780.0
				bullet_damage = 30.0
				bullet_radius = 6.0
				is_auto = false
				bounces = 2

		return CombatMath.BulletData.new(
			muzzle,
			aim_dir * bullet_speed,
			bullet_radius,
			bullet_damage,
			3.5,
			is_auto,
			bounces,
			enemy.era
		)

	return null


## Pure wave scaling calculation: returns total enemy count for given wave number (3 + wave * 3).
static func calculate_wave_enemy_count(wave: int) -> int:
	return 3 + maxi(0, wave) * 3


class WaveManager extends RefCounted:
	var current_wave: int = 1
	var phase: int = WavePhase.INTERMISSION
	var phase_timer: float = 2.0
	var remaining_to_spawn: int = 0
	var spawn_timer: float = 0.0
	var total_wave_enemies: int = 6
	var alive_count: int = 0
	var spawn_interval: float = 1.2
	var intermission_duration: float = 2.5
	var multi_era_spawning: bool = true

	## Pure update step for wave progression.
	## Returns a Dictionary with "action": "announce_wave" | "spawn_enemy" | "announce_clear", or {} if no action.
	func update(dt: float, arena_width: float, spawn_y: float) -> Dictionary:
		var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0

		match phase:
			WavePhase.INTERMISSION:
				phase_timer -= safe_dt
				if phase_timer <= 0.0:
					var total: int = EnemyAI.calculate_wave_enemy_count(current_wave)
					total_wave_enemies = total
					phase = WavePhase.SPAWNING
					remaining_to_spawn = total
					spawn_timer = 0.1
					return {
						"action": "announce_wave",
						"wave": current_wave,
					}

			WavePhase.SPAWNING:
				if remaining_to_spawn <= 0:
					phase = WavePhase.ACTIVE
					return {}

				spawn_timer -= safe_dt
				if spawn_timer <= 0.0 and remaining_to_spawn > 0:
					remaining_to_spawn -= 1
					spawn_timer = maxf(0.4, spawn_interval - float(current_wave) * 0.05)

					var spawn_side: float = -1.0 if (remaining_to_spawn % 2 == 0) else 1.0
					var spawn_x: float = spawn_side * (arena_width * 0.5 - 40.0)
					var pos: Vector2 = Vector2(spawn_x, spawn_y)

					var e_type: int = EnemyType.RUNNER
					if current_wave <= 1:
						e_type = EnemyType.RUNNER
					elif current_wave == 2:
						match remaining_to_spawn % 3:
							0:
								e_type = EnemyType.GUNNER_SEMI
							1:
								e_type = EnemyType.NINJA
							_:
								e_type = EnemyType.RUNNER
					elif current_wave == 3:
						match remaining_to_spawn % 5:
							0:
								e_type = EnemyType.HEAVY
							1:
								e_type = EnemyType.GUNNER_AUTO
							2:
								e_type = EnemyType.GUNNER_SEMI
							3:
								e_type = EnemyType.NINJA
							_:
								e_type = EnemyType.RUNNER
					else:
						match remaining_to_spawn % 6:
							0:
								e_type = EnemyType.HEAVY
							1:
								e_type = EnemyType.GUNNER_AUTO
							2:
								e_type = EnemyType.GUNNER_SEMI
							3:
								e_type = EnemyType.NINJA
							4:
								e_type = EnemyType.SNIPER
							_:
								e_type = EnemyType.RUNNER

					var spawn_era: int = (remaining_to_spawn % 3) if multi_era_spawning else 1

					alive_count += 1
					if remaining_to_spawn == 0:
						phase = WavePhase.ACTIVE

					return {
						"action": "spawn_enemy",
						"enemy_type": e_type,
						"position": pos,
						"era": spawn_era,
					}

			WavePhase.ACTIVE:
				if total_wave_enemies > 0 and alive_count == 0:
					phase = WavePhase.WAVE_CLEARED
					phase_timer = 2.0
					return {
						"action": "announce_clear",
						"wave": current_wave,
					}

			WavePhase.WAVE_CLEARED:
				phase_timer -= safe_dt
				if phase_timer <= 0.0:
					current_wave += 1
					phase = WavePhase.INTERMISSION
					phase_timer = intermission_duration

		return {}

	func on_enemy_killed() -> void:
		if alive_count > 0:
			alive_count -= 1

	func is_real_time_phase() -> bool:
		return phase == WavePhase.WAVE_CLEARED or phase == WavePhase.INTERMISSION

	func reset() -> void:
		current_wave = 1
		phase = WavePhase.INTERMISSION
		phase_timer = 2.0
		remaining_to_spawn = 0
		spawn_timer = 0.0
		total_wave_enemies = 6
		alive_count = 0
		spawn_interval = 1.2
		intermission_duration = 2.5
		multi_era_spawning = true
