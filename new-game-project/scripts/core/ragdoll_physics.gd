class_name RagdollPhysics
extends RefCounted

## Ragdoll half-split velocity calculation and physics stepping for sliced enemies and particles.
## Ported from bevy-game-test/src/ragdoll.rs + OUT OF TIME modular asset spec.

enum RagdollPart {
	UPPER_TORSO,
	LOWER_LEGS,
}


class RagdollPieceData extends RefCounted:
	var part: int = RagdollPart.UPPER_TORSO
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var angular_velocity: float = 0.0
	var rotation: float = 0.0
	var facing: float = 1.0
	var lifetime: float = 4.5
	var max_lifetime: float = 4.5
	var is_settled: bool = false
	var color: Color = Color.WHITE
	var era: int = 1
	var loadout_id: String = "enemy_runner"
	var custom_parts: Dictionary = {}

	func _init(
		p_part: int = RagdollPart.UPPER_TORSO,
		p_pos: Vector2 = Vector2.ZERO,
		p_vel: Vector2 = Vector2.ZERO,
		p_ang_vel: float = 0.0,
		p_facing: float = 1.0,
		p_color: Color = Color.WHITE,
		p_loadout_id: String = "enemy_runner",
		p_custom_parts: Dictionary = {}
	) -> void:
		part = p_part
		position = p_pos
		velocity = p_vel
		angular_velocity = p_ang_vel
		rotation = 0.0
		facing = p_facing
		lifetime = 4.5
		max_lifetime = 4.5
		is_settled = false
		color = p_color
		loadout_id = p_loadout_id
		custom_parts = p_custom_parts


class SliceParticleData extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var lifetime: float = 0.6
	var max_lifetime: float = 0.6
	var size: float = 3.5
	var color: Color = Color(0.95, 0.15, 0.2, 1.0)
	var gravity_scale: float = 0.8
	var era: int = 1

	func _init(
		p_pos: Vector2 = Vector2.ZERO,
		p_vel: Vector2 = Vector2.ZERO,
		p_lifetime: float = 0.6,
		p_size: float = 3.5,
		p_color: Color = Color(0.95, 0.15, 0.2, 1.0),
		p_gravity_scale: float = 0.8
	) -> void:
		position = p_pos
		velocity = p_vel
		lifetime = p_lifetime
		max_lifetime = p_lifetime
		size = p_size
		color = p_color
		gravity_scale = p_gravity_scale


## Pure calculation: derives linear and angular velocities for both ragdoll halves after a slice.
## Returns {"upper_vel": Vector2, "upper_ang_vel": float, "lower_vel": Vector2, "lower_ang_vel": float}
static func calculate_slice_split_velocities(
	base_velocity: Vector2,
	slice_dir: Vector2,
	impulse: Vector2
) -> Dictionary:
	var dir: Vector2 = slice_dir.normalized() if slice_dir.length_squared() > 1e-4 else Vector2(0.0, 1.0)
	var normal: Vector2 = Vector2(-dir.y, dir.x)

	# Upper half gets pushed upward and along normal
	var upper_vel: Vector2 = base_velocity * 0.4 + impulse + normal * 180.0 + Vector2(0.0, 140.0)
	var upper_ang_vel: float = (dir.x * -14.0) + (normal.y * 8.0)

	# Lower half gets pushed slightly downward/opposite and along base motion
	var lower_vel: Vector2 = base_velocity * 0.4 + impulse * 0.6 - normal * 140.0 + Vector2(0.0, 40.0)
	var lower_ang_vel: float = (dir.x * 12.0) - (normal.y * 6.0)

	return {
		"upper_vel": upper_vel,
		"upper_ang_vel": upper_ang_vel,
		"lower_vel": lower_vel,
		"lower_ang_vel": lower_ang_vel,
	}


## Steps a single ragdoll piece's physics, platform landing, bounce (0.28), and settle (abs(vy) <= 80.0).
## Returns true if the piece is still alive, or false if its lifetime has expired (should be despawned).
static func step_ragdoll_piece(
	piece: RagdollPieceData,
	platforms: Array,
	dt: float,
	floor_y: float = -260.0,
	gravity: float = 1200.0
) -> bool:
	if piece == null:
		return false
	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	if safe_dt <= 0.0:
		return piece.lifetime > 0.0

	piece.lifetime -= safe_dt
	if piece.lifetime <= 0.0:
		return false

	if piece.is_settled:
		return true

	piece.velocity.y -= gravity * safe_dt
	piece.position.x += piece.velocity.x * safe_dt
	piece.position.y += piece.velocity.y * safe_dt
	piece.rotation += piece.angular_velocity * safe_dt

	var feet_y: float = piece.position.y
	var landed: bool = false

	if feet_y <= floor_y:
		piece.position.y = floor_y
		landed = true
	else:
		for plat in platforms:
			if plat == null:
				continue
			if piece.position.x >= plat.min_x and piece.position.x <= plat.max_x:
				if feet_y <= plat.y and (feet_y - piece.velocity.y * safe_dt) >= plat.y - 12.0:
					piece.position.y = plat.y
					landed = true
					break

	if landed:
		if absf(piece.velocity.y) > 80.0:
			piece.velocity.y = -piece.velocity.y * 0.28
			piece.velocity.x *= 0.75
			piece.angular_velocity *= 0.6
		else:
			piece.velocity = Vector2.ZERO
			piece.angular_velocity = 0.0
			piece.is_settled = true

	return true


## Steps a single slice particle's physics and floor bounce.
## Returns true if the particle is still alive, or false if its lifetime has expired.
static func step_slice_particle(
	part: SliceParticleData,
	dt: float,
	floor_y: float = -260.0,
	gravity: float = 1200.0
) -> bool:
	if part == null:
		return false
	var safe_dt: float = maxf(0.0, dt) if is_finite(dt) else 0.0
	if safe_dt <= 0.0:
		return part.lifetime > 0.0

	part.lifetime -= safe_dt
	if part.lifetime <= 0.0:
		return false

	part.velocity.y -= gravity * part.gravity_scale * safe_dt
	part.position.x += part.velocity.x * safe_dt
	part.position.y += part.velocity.y * safe_dt

	if part.position.y <= floor_y:
		part.position.y = floor_y
		part.velocity.y = -part.velocity.y * 0.35
		part.velocity.x *= 0.7

	return true
