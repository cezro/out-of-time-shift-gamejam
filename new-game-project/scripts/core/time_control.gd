class_name ChronoState
extends RefCounted

## Global state controlling time dilation (slow motion), hitstop, and camera shake.
## Ported from bevy-game-test/src/time_control.rs + OUT OF TIME spec.

const HITSTOP_NORMAL: float = 0.045
const HITSTOP_WARP: float = 0.070
const HITSTOP_PARRY: float = 0.085
const HITSTOP_SLAM: float = 0.065

## World time dilation scale (e.g. 0.15 for slow motion, 1.0 for normal time).
var dilation_factor: float = 1.0
## Whether time dilation is actively requested and sustained by the player.
var is_dilating: bool = false
## Hitstop timer: freezes world and player briefly upon landing a successful slash/parry/slam.
var hitstop_timer: float = 0.0
## Screen shake intensity (magnitude in pixels).
var screen_shake: float = 0.0
## Current screen shake offset to apply to camera.
var shake_offset: Vector2 = Vector2.ZERO
## Minimum dilation speed factor during slow motion.
var slowmo_factor: float = 0.15


## Updates time control timers, screen shake decay, and dilation factor.
func update(unscaled_dt: float) -> void:
	var dt: float = maxf(0.0, unscaled_dt) if is_finite(unscaled_dt) else 0.0

	# Hitstop countdown
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - dt)

	# Screen shake decay
	if screen_shake > 0.0:
		screen_shake = maxf(0.0, screen_shake - dt * 30.0)
		if screen_shake > 0.001:
			# Procedural jitter matching Bevy implementation
			var angle: float = sin(dt * 1234.5 + screen_shake * 987.6) * TAU
			shake_offset = Vector2(cos(angle), sin(angle)) * screen_shake
		else:
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2.ZERO

	# Dilation factor update
	var target_dilation: float = slowmo_factor if is_dilating else 1.0
	dilation_factor = dilation_factor + (target_dilation - dilation_factor) * minf(1.0, dt * 20.0)


## Triggers a brief hitstop screen freeze.
func trigger_hitstop(duration: float) -> void:
	if is_finite(duration) and duration > 0.0:
		hitstop_timer = maxf(hitstop_timer, duration)


## Triggers screen shake with given intensity in pixels (clamped at 20.0).
func trigger_shake(intensity: float) -> void:
	if is_finite(intensity) and intensity > 0.0:
		screen_shake = minf(20.0, screen_shake + intensity)


## Checks if hitstop is active (all simulation frozen).
func is_hitstop_active() -> bool:
	return hitstop_timer > 0.0


## Returns the effective delta time for world entities (enemies, particles, enemy attacks).
func get_world_dt(real_dt: float) -> float:
	if not is_finite(real_dt) or real_dt <= 0.0:
		return 0.0
	if is_hitstop_active():
		return 0.0
	return real_dt * dilation_factor


## Returns the effective delta time for the player (player moves at full/boosted speed during slowmo).
func get_player_dt(real_dt: float) -> float:
	if not is_finite(real_dt) or real_dt <= 0.0:
		return 0.0
	if is_hitstop_active():
		return 0.0
	var player_speed_mult: float = 1.1 if is_dilating else 1.0
	return real_dt * player_speed_mult


## Resets time control state to defaults.
func reset() -> void:
	dilation_factor = 1.0
	is_dilating = false
	hitstop_timer = 0.0
	screen_shake = 0.0
	shake_offset = Vector2.ZERO
	slowmo_factor = 0.15
