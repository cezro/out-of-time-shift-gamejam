class_name CombatMath
extends RefCounted

## Pure combat geometry, hit detection, arcade style rank / combo scoring, and projectile physics.
## Ported from bevy-game-test/src/combat.rs + OUT OF TIME spec.


static func _safe_vec2(v: Vector2, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if is_finite(v.x) and is_finite(v.y):
		return v
	return Vector2(
		v.x if is_finite(v.x) else fallback.x,
		v.y if is_finite(v.y) else fallback.y
	)


static func _safe_dir(v: Vector2, fallback: Vector2 = Vector2.RIGHT) -> Vector2:
	if is_finite(v.x) and is_finite(v.y) and v.length_squared() > 1e-6:
		return v.normalized()
	if is_finite(fallback.x) and is_finite(fallback.y) and fallback.length_squared() > 1e-6:
		return fallback.normalized()
	return Vector2.RIGHT


## Pure mathematical calculation: minimum squared distance from point `p` to line segment `[a, b]`.
static func point_to_segment_distance_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var sp: Vector2 = _safe_vec2(p, Vector2.ZERO)
	var sa: Vector2 = _safe_vec2(a, Vector2.ZERO)
	var sb: Vector2 = _safe_vec2(b, sa)
	var ab: Vector2 = sb - sa
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-6 or not is_finite(len_sq):
		var d0: float = (sp - sa).length_squared()
		return d0 if is_finite(d0) else 0.0
	var dot_val: float = (sp - sa).dot(ab)
	var t: float = clampf(dot_val / len_sq, 0.0, 1.0) if is_finite(dot_val) else 0.0
	var projection: Vector2 = sa + ab * t
	var d_sq: float = (sp - projection).length_squared()
	return d_sq if is_finite(d_sq) else 0.0


## Pure test: checks if line segment `[a, b]` intersects a circle of given `center` and `radius`.
static func segment_intersects_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var r: float = maxf(0.0, radius) if is_finite(radius) else 0.0
	return point_to_segment_distance_sq(center, a, b) <= r * r


## Pure test: checks if target circle intersects a katana slash arc.
static func katana_arc_intersects(
	origin: Vector2,
	facing: float,
	aim_dir: Vector2,
	target: Vector2,
	slash_range: float,
	arc_radians: float,
	target_radius: float
) -> bool:
	var s_origin: Vector2 = _safe_vec2(origin, Vector2.ZERO)
	var s_target: Vector2 = _safe_vec2(target, Vector2.ZERO)
	var s_range: float = maxf(0.0, slash_range) if is_finite(slash_range) else 80.0
	var s_arc: float = maxf(0.0, arc_radians) if is_finite(arc_radians) else PI * 0.75
	var s_rad: float = maxf(0.0, target_radius) if is_finite(target_radius) else 0.0

	var to_target: Vector2 = s_target - s_origin
	var dist: float = to_target.length()
	if not is_finite(dist) or dist > s_range + s_rad:
		return false
	# If very close to player, hit unconditionally
	if dist <= maxf(s_rad * 1.5, 1e-4):
		return true

	var dir: Vector2 = to_target / dist
	var f: float = 1.0 if (not is_finite(facing) or facing >= 0.0) else -1.0
	var primary_dir: Vector2 = _safe_dir(aim_dir, Vector2(f, 0.0))

	var angle_diff: float = acos(clampf(dir.dot(primary_dir), -1.0, 1.0))
	return angle_diff <= (s_arc * 0.5) + (s_rad / maxf(dist, 1.0))


class ComboState extends RefCounted:
	var count: int = 0
	var multiplier: int = 1
	var timer: float = 0.0
	var window: float = 2.8
	var score: int = 0
	var highest_combo: int = 0
	var total_kills: int = 0
	var warp_kills: int = 0
	var parry_kills: int = 0
	var slam_kills: int = 0
	var style_points: float = 0.0

	## Registers a kill, resets combo window, updates multiplier, style points, and awards score.
	func register_kill(is_warp: bool, is_parry: bool = false, is_slam: bool = false) -> int:
		count += 1
		total_kills += 1
		if is_warp:
			warp_kills += 1
		if is_parry:
			parry_kills += 1
		if is_slam:
			slam_kills += 1

		highest_combo = maxi(highest_combo, count)

		# Multiplier progression matching Bevy: 1x (0..1), 2x (2..4), 3x (5..8), 4x (9..13), 5x (>=14)
		if count <= 1:
			multiplier = 1
		elif count <= 4:
			multiplier = 2
		elif count <= 8:
			multiplier = 3
		elif count <= 13:
			multiplier = 4
		else:
			multiplier = 5

		timer = window

		var style_gain: float = 5.5
		if is_parry:
			style_gain = 10.0
		elif is_warp:
			style_gain = 8.0
		elif is_slam:
			style_gain = 7.5
		style_points = minf(100.0, style_points + style_gain)

		var base_score: int = 100
		if is_warp:
			base_score = 250
		elif is_parry:
			base_score = 300
		elif is_slam:
			base_score = 200

		var awarded: int = base_score * multiplier
		score += awarded
		return awarded

	## Returns Arcade Style Rank ("D", "C", "B", "A", "S", "SS", "SSS") based on combo count / style_points.
	func get_style_rank() -> String:
		if count >= 18 or style_points >= 95.0:
			return "SSS"
		elif count >= 14 or style_points >= 76.0:
			return "SS"
		elif count >= 9 or style_points >= 49.0:
			return "S"
		elif count >= 5 or style_points >= 27.0:
			return "A"
		elif count >= 3 or style_points >= 16.0:
			return "B"
		elif count >= 2 or style_points >= 10.5:
			return "C"
		return "D"

	## Penalizes combo and style when the player takes damage.
	func on_damage_taken() -> void:
		count = 0
		multiplier = 1
		timer = 0.0
		style_points = 0.0

	## Ticks the combo decay timer.
	func update(dt: float) -> void:
		var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
		if timer > 0.0:
			timer = maxf(0.0, timer - safe_dt)
			if timer == 0.0:
				count = 0
				multiplier = 1
				style_points = 0.0

	func reset() -> void:
		count = 0
		multiplier = 1
		timer = 0.0
		score = 0
		highest_combo = 0
		total_kills = 0
		warp_kills = 0
		parry_kills = 0
		slam_kills = 0
		style_points = 0.0


class BulletData extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var radius: float = 6.0
	var damage: float = 20.0
	var lifetime: float = 3.5
	var is_automatic: bool = false
	var bounces_remaining: int = 0
	var is_reflected: bool = false
	var era: int = 1

	func _init(
		p_pos: Vector2 = Vector2.ZERO,
		p_vel: Vector2 = Vector2.ZERO,
		p_radius: float = 6.0,
		p_damage: float = 20.0,
		p_lifetime: float = 3.5,
		p_is_auto: bool = false,
		p_bounces: int = 0,
		p_era: int = 1
	) -> void:
		position = CombatMath._safe_vec2(p_pos, Vector2.ZERO)
		velocity = CombatMath._safe_vec2(p_vel, Vector2.ZERO)
		radius = maxf(0.5, p_radius) if is_finite(p_radius) else 6.0
		damage = maxf(0.0, p_damage) if is_finite(p_damage) else 20.0
		lifetime = maxf(0.0, p_lifetime) if is_finite(p_lifetime) else 3.5
		is_automatic = p_is_auto
		bounces_remaining = p_bounces
		era = p_era

	## Steps bullet position, lifetime, and arena wall/floor/ceiling ricochet bounces.
	## Returns true if the bullet remains active, false if expired or out of bounds.
	func step_bullet(
		dt: float,
		arena_half_width: float = 580.0,
		floor_y: float = -260.0,
		ceiling_y: float = 360.0
	) -> bool:
		position = CombatMath._safe_vec2(position, Vector2.ZERO)
		velocity = CombatMath._safe_vec2(velocity, Vector2.ZERO)
		var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
		if not is_finite(lifetime) or not is_finite(damage) or lifetime <= 0.0 or damage <= 0.0:
			return false

		lifetime -= safe_dt
		if lifetime <= 0.0:
			return false

		position += velocity * safe_dt

		if bounces_remaining > 0:
			var bounced: bool = false
			if position.x < -arena_half_width:
				position.x = -arena_half_width + (-arena_half_width - position.x)
				velocity.x = absf(velocity.x)
				bounced = true
			elif position.x > arena_half_width:
				position.x = arena_half_width - (position.x - arena_half_width)
				velocity.x = -absf(velocity.x)
				bounced = true

			if position.y < floor_y:
				position.y = floor_y + (floor_y - position.y)
				velocity.y = absf(velocity.y)
				bounced = true
			elif position.y > ceiling_y:
				position.y = ceiling_y - (position.y - ceiling_y)
				velocity.y = -absf(velocity.y)
				bounced = true

			if bounced:
				bounces_remaining -= 1
			return true
		else:
			var max_x: float = maxf(650.0, arena_half_width + 70.0)
			var min_y: float = minf(-350.0, floor_y - 90.0)
			var max_y: float = maxf(450.0, ceiling_y + 90.0)
			if absf(position.x) > max_x or position.y < min_y or position.y > max_y:
				return false
			return true

	## Deflects/parries the bullet towards `new_dir`, boosting speed & damage and preserving bounces.
	func deflect(new_dir: Vector2, speed_mult: float = 1.5) -> void:
		is_reflected = true
		velocity = CombatMath._safe_vec2(velocity, Vector2.ZERO)
		var current_speed: float = velocity.length()
		if current_speed < 1.0 or not is_finite(current_speed):
			current_speed = 540.0
		var dir: Vector2
		if is_finite(new_dir.x) and is_finite(new_dir.y) and new_dir.length_squared() > 1e-4:
			dir = new_dir.normalized()
		elif is_finite(velocity.x) and is_finite(velocity.y) and velocity.length_squared() > 1e-4:
			dir = -velocity.normalized()
		else:
			dir = Vector2.RIGHT
		var mult: float = maxf(0.1, speed_mult) if is_finite(speed_mult) else 1.5
		velocity = dir * (current_speed * mult)
		damage = (damage if is_finite(damage) else 20.0) * 1.5
		lifetime = maxf(lifetime if is_finite(lifetime) else 2.5, 2.5)
		if bounces_remaining > 0:
			bounces_remaining = maxi(bounces_remaining, 2)


class SliceEventData extends RefCounted:
	var enemy_id: int = -1
	var slice_position: Vector2 = Vector2.ZERO
	var slice_direction: Vector2 = Vector2.RIGHT
	var impulse: Vector2 = Vector2.ZERO
	var is_warp_kill: bool = false
	var is_parry_kill: bool = false
	var is_slam_kill: bool = false

	func _init(
		p_enemy_id: int = -1,
		p_pos: Vector2 = Vector2.ZERO,
		p_dir: Vector2 = Vector2.RIGHT,
		p_impulse: Vector2 = Vector2.ZERO,
		p_is_warp: bool = false,
		p_is_parry: bool = false,
		p_is_slam: bool = false
	) -> void:
		enemy_id = p_enemy_id
		slice_position = p_pos
		slice_direction = p_dir
		impulse = p_impulse
		is_warp_kill = p_is_warp
		is_parry_kill = p_is_parry
		is_slam_kill = p_is_slam


class SlashArcVisualData extends RefCounted:
	var origin: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var arc_span: float = PI * 0.75
	var radius: float = 80.0
	var timer: float = 0.14
	var duration: float = 0.14
	var color: Color = Color(0.2, 0.95, 1.0, 1.0)


class WarpBeamVisualData extends RefCounted:
	var start: Vector2 = Vector2.ZERO
	var end: Vector2 = Vector2.ZERO
	var timer: float = 0.25
	var duration: float = 0.25
	var color: Color = Color(0.0, 1.0, 0.9, 1.0)


class ShockwaveVisualData extends RefCounted:
	var origin: Vector2 = Vector2.ZERO
	var current_radius: float = 10.0
	var max_radius: float = 160.0
	var timer: float = 0.28
	var duration: float = 0.28
	var color: Color = Color(1.0, 0.55, 0.1, 0.95)


## Resolves a batch of SliceEventData with strict per-enemy deduplication so duplicate slice events
## in the same frame never double-decrement alive_count or double-award combo kills.
## Returns {"ragdolls": Array[RagdollPhysics.RagdollPieceData], "particles": Array[RagdollPhysics.SliceParticleData], "killed_ids": Array[int]}
static func resolve_slice_events(
	events: Array,
	chrono: ChronoState,
	combo: ComboState,
	wave_mgr: RefCounted,
	energy: RefCounted,
	enemies_by_id: Dictionary
) -> Dictionary:
	var processed: Dictionary = {}
	var spawned_ragdolls: Array = []
	var spawned_particles: Array = []
	var killed_ids: Array[int] = []

	for ev in events:
		if ev == null:
			continue
		var eid: int = ev.enemy_id
		if processed.has(eid):
			continue
		processed[eid] = true

		if not enemies_by_id.has(eid):
			continue
		var enemy = enemies_by_id[eid]
		enemies_by_id.erase(eid)
		killed_ids.append(eid)

		# 1. Trigger Hitstop & Screen Shake
		if chrono != null:
			var hitstop: float = ChronoState.HITSTOP_NORMAL
			var shake: float = 7.0
			if ev.is_parry_kill:
				hitstop = ChronoState.HITSTOP_PARRY
				shake = 10.0
			elif ev.is_warp_kill:
				hitstop = ChronoState.HITSTOP_WARP
				shake = 12.0
			elif ev.is_slam_kill:
				hitstop = ChronoState.HITSTOP_SLAM
				shake = 10.0
			chrono.trigger_hitstop(hitstop)
			chrono.trigger_shake(shake)

		# 2. Score & Combo
		if combo != null:
			combo.register_kill(ev.is_warp_kill, ev.is_parry_kill, ev.is_slam_kill)

		# 3. Chrono Energy reward
		if energy != null and energy.has_method("reward_kill"):
			energy.reward_kill()

		# 4. Wave manager update
		if wave_mgr != null and wave_mgr.has_method("on_enemy_killed"):
			wave_mgr.on_enemy_killed()

		# 5. Ragdoll Halves Split
		var base_vel: Vector2 = enemy.velocity if enemy != null else Vector2.ZERO
		var enemy_facing: float = enemy.facing if enemy != null else 1.0
		var enemy_loadout: String = enemy.loadout_id if enemy != null else "enemy_runner"
		var split: Dictionary = RagdollPhysics.calculate_slice_split_velocities(
			base_vel, ev.slice_direction, ev.impulse
		)

		var upper_piece := RagdollPhysics.RagdollPieceData.new(
			RagdollPhysics.RagdollPart.UPPER_TORSO,
			ev.slice_position + Vector2(0.0, 10.0),
			split["upper_vel"],
			split["upper_ang_vel"],
			enemy_facing,
			Color.WHITE,
			enemy_loadout
		)
		var lower_piece := RagdollPhysics.RagdollPieceData.new(
			RagdollPhysics.RagdollPart.LOWER_LEGS,
			ev.slice_position,
			split["lower_vel"],
			split["lower_ang_vel"],
			enemy_facing,
			Color.WHITE,
			enemy_loadout
		)
		spawned_ragdolls.append(upper_piece)
		spawned_ragdolls.append(lower_piece)

		# 6. Blood & Cyber Sparks
		var spark_count: int = 24 if ev.is_warp_kill else 14
		for i in range(spark_count):
			var angle: float = (float(i) / float(spark_count)) * TAU
			var speed: float = 120.0 + fmod(float(i) * 27.0, 240.0)
			var spark_dir: Vector2 = Vector2(cos(angle), sin(angle))
			var spark_color: Color = Color(0.1, 0.95, 1.0, 1.0) if ev.is_warp_kill else Color(0.95, 0.15, 0.2, 1.0)
			var part := RagdollPhysics.SliceParticleData.new(
				ev.slice_position,
				spark_dir * speed + ev.slice_direction * 150.0,
				0.6 + float(i) * 0.04,
				3.5,
				spark_color,
				0.8
			)
			spawned_particles.append(part)

	return {
		"ragdolls": spawned_ragdolls,
		"particles": spawned_particles,
		"killed_ids": killed_ids,
	}


## Executes a katana slash from `player`, checking enemies (Dictionary of id -> EnemyData) and bullets (Array of BulletData).
## Immediately zeroes slashed bullet damage and lifetime (or deflects on parry) to prevent race conditions.
## Reduces player.slash_cooldown to 0.04 on hitting any enemy or bullet (from base 0.22).
## Returns {"slice_events": Array[SliceEventData], "hit_enemies": int, "hit_bullets": int}
static func perform_katana_slash(
	player: PlayerKinematics.PlayerState,
	cursor_world_pos: Variant,
	enemies_by_id: Dictionary,
	bullets: Array,
	chrono: ChronoState = null,
	deflect_bullets: bool = false
) -> Dictionary:
	var result: Dictionary = {
		"slice_events": [],
		"hit_enemies": 0,
		"hit_bullets": 0,
	}
	if player == null:
		return result
	if not is_finite(player.slash_cooldown):
		player.slash_cooldown = 0.0
	if player.slash_cooldown > 0.0:
		return result
	if chrono != null and chrono.is_hitstop_active():
		return result

	player.position = _safe_vec2(player.position, Vector2(0.0, -200.0))
	player.facing = 1.0 if (not is_finite(player.facing) or player.facing >= 0.0) else -1.0
	player.slash_cooldown = 0.22
	var origin: Vector2 = player.position + Vector2(0.0, 16.0)
	var aim_dir: Vector2
	if cursor_world_pos is Vector2:
		var cw: Vector2 = cursor_world_pos
		if is_finite(cw.x) and is_finite(cw.y) and (cw - origin).length_squared() > 1e-4:
			aim_dir = (cw - origin).normalized()
		else:
			aim_dir = Vector2(player.facing, 0.0)
	else:
		aim_dir = Vector2(player.facing, 0.0)

	var slash_range: float = 80.0
	var arc_span: float = PI * 0.75

	var hit_enemy_count: int = 0
	for eid in enemies_by_id.keys():
		var enemy = enemies_by_id[eid]
		if enemy == null:
			continue
		var enemy_center: Vector2 = _safe_vec2(enemy.position, Vector2.ZERO) + Vector2(0.0, 16.0)
		if katana_arc_intersects(origin, player.facing, aim_dir, enemy_center, slash_range, arc_span, enemy.hitbox_radius):
			hit_enemy_count += 1
			var impulse: Vector2 = aim_dir * 320.0 + Vector2(0.0, 180.0)
			result["slice_events"].append(SliceEventData.new(eid, enemy_center, aim_dir, impulse, false, false, false))

	var hit_bullet_count: int = 0
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: BulletData = bullets[i]
		if bullet == null:
			continue
		if katana_arc_intersects(origin, player.facing, aim_dir, bullet.position, slash_range, arc_span, bullet.radius):
			hit_bullet_count += 1
			if deflect_bullets:
				bullet.deflect(aim_dir, 1.5)
			else:
				# Zero out damage and lifetime immediately to prevent race conditions with bullet step!
				bullet.damage = 0.0
				bullet.lifetime = 0.0
				bullets.remove_at(i)

	var total_hits: int = hit_enemy_count + hit_bullet_count
	if total_hits > 0:
		player.slash_cooldown = 0.04
		if hit_bullet_count > 0 and hit_enemy_count == 0 and chrono != null:
			chrono.trigger_hitstop(ChronoState.HITSTOP_PARRY if deflect_bullets else 0.04)
			chrono.trigger_shake(4.0)

	result["hit_enemies"] = hit_enemy_count
	result["hit_bullets"] = hit_bullet_count
	return result


## Executes a Chrono Warp teleport-slice from `player.position` towards `cursor_world_pos` (max range 380.0).
## Consumes teleport energy, sets warp_cooldown = 0.20 (reduced to 0.05 ONLY when hitting >= 1 enemy, NOT bullets!).
## Returns {"slice_events": Array[SliceEventData], "hit_enemies": int, "did_warp": bool}
static func perform_chrono_warp(
	player: PlayerKinematics.PlayerState,
	energy: PlayerKinematics.ChronoEnergy,
	cursor_world_pos: Vector2,
	enemies_by_id: Dictionary,
	chrono: ChronoState = null
) -> Dictionary:
	var result: Dictionary = {
		"slice_events": [],
		"hit_enemies": 0,
		"did_warp": false,
	}
	if player == null or energy == null:
		return result
	if not is_finite(player.warp_cooldown):
		player.warp_cooldown = 0.0
	if chrono != null and chrono.is_hitstop_active():
		return result
	if player.warp_cooldown > 0.0 or not energy.can_teleport():
		return result

	energy.consume_teleport()
	player.warp_cooldown = 0.20
	player.invulnerability_timer = 0.25

	player.position = _safe_vec2(player.position, Vector2(0.0, -200.0))
	player.facing = 1.0 if (not is_finite(player.facing) or player.facing >= 0.0) else -1.0
	var start_pos: Vector2 = player.position
	var safe_cursor: Vector2 = (
		cursor_world_pos
		if (is_finite(cursor_world_pos.x) and is_finite(cursor_world_pos.y))
		else (start_pos + Vector2(player.facing * 200.0, 0.0))
	)
	var warp_vector: Vector2 = safe_cursor - start_pos
	var max_range: float = 380.0
	var dist: float = warp_vector.length()
	var target_pos: Vector2 = (
		(start_pos + (warp_vector / dist) * max_range)
		if (is_finite(dist) and dist > max_range and dist > 1e-4)
		else safe_cursor
	)
	target_pos = _safe_vec2(target_pos, start_pos)

	var clamped_target := Vector2(
		clampf(target_pos.x, -570.0, 570.0),
		clampf(target_pos.y, -260.0, 320.0)
	)
	var delta_vec: Vector2 = clamped_target - start_pos
	var slice_dir: Vector2 = _safe_dir(delta_vec, Vector2(player.facing, 0.0))

	player.position = clamped_target
	player.velocity = Vector2.ZERO

	var seg_start: Vector2 = start_pos + Vector2(0.0, 16.0)
	var seg_end: Vector2 = clamped_target + Vector2(0.0, 16.0)
	var slice_radius: float = 28.0

	var hit_count: int = 0
	for eid in enemies_by_id.keys():
		var enemy = enemies_by_id[eid]
		if enemy == null:
			continue
		var enemy_center: Vector2 = _safe_vec2(enemy.position, Vector2.ZERO) + Vector2(0.0, 16.0)
		if segment_intersects_circle(seg_start, seg_end, enemy_center, enemy.hitbox_radius + slice_radius):
			hit_count += 1
			var impulse: Vector2 = slice_dir * 450.0 + Vector2(0.0, 240.0)
			result["slice_events"].append(SliceEventData.new(eid, enemy_center, slice_dir, impulse, true, false, false))

	if hit_count > 0:
		# Rapid chaining of warp kills: reduce warp cooldown when hitting enemies (NOT bullets)!
		player.warp_cooldown = 0.05

	result["hit_enemies"] = hit_count
	result["did_warp"] = true
	return result


## Executes a Downward Slam landing shockwave, launching nearby enemies into the JUGGLED state.
## Returns the number of enemies launched.
static func apply_slam_shockwave(
	origin: Vector2,
	shockwave_radius: float,
	enemies: Array,
	launch_speed_y: float = 540.0
) -> int:
	var s_origin: Vector2 = _safe_vec2(origin, Vector2.ZERO)
	var s_rad: float = maxf(0.0, shockwave_radius) if is_finite(shockwave_radius) else 160.0
	var s_launch_y: float = launch_speed_y if is_finite(launch_speed_y) else 540.0
	var hit_count: int = 0
	for enemy in enemies:
		if enemy == null:
			continue
		var e_pos: Vector2 = _safe_vec2(enemy.position, Vector2.ZERO)
		var dist: float = (e_pos - s_origin).length()
		if is_finite(dist) and dist <= s_rad + enemy.hitbox_radius:
			var push_x: float = signf(e_pos.x - s_origin.x) * 140.0
			EnemyAI.launch_enemy(enemy, Vector2(push_x, s_launch_y), 0.75)
			hit_count += 1
	return hit_count
