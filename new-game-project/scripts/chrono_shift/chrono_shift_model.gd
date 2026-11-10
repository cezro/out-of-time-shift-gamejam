class_name ChronoShiftModel
extends RefCounted

## Chronos Shift — interactive H-pattern stick-shift time dilator model.
## Pure, deterministic kinematic core + ShifterModel state machine + GearAcclimatization
## ported 1:1 from bevy-game-test/src/chrono_shift.rs plus Reverse Gear (R) and Turbo Shifter Overdrive.

# ---------------------------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------------------------

## Half-thickness of the neutral rail band (gate units).
const RAIL_TOL: float = 0.12
## How close (in x) the knob must be to a column to be allowed to enter its slot.
const COL_TOL: float = 0.2
## Gate columns.
const COLUMNS: Array[float] = [-1.0, 0.0, 1.0]
## Maximum sub-step length; must be well below 2 * RAIL_TOL so the band cannot be skipped.
const MAX_SUBSTEP: float = 0.05
## Per-axis clamp on a single input delta (the whole gate is only ~4 units of path long).
const MAX_DELTA: float = 8.0
## Slot depth at which engagement begins.
const ENGAGE_START: float = 0.15
## Slot depth beyond which the detent seats the knob into the gear end instead of the rail.
const SEAT_THRESHOLD: float = 0.45
## Detent spring stiffness (1/s).
const DETENT_K: float = 16.0
## Animated path speed for wheel / number-key / release shifts (gate units per second).
const PATH_SPEED: float = 24.0
## Raw mouse pixels per gate unit while dragging the stick.
const DRAG_PX_PER_UNIT: float = 90.0
## Per-frame drag magnitude (gate units) below which mouse jitter is ignored.
const DRAG_DEADZONE: float = 0.02
## Drain at dilation 0 (energy per second).
const MAX_DRAIN: float = 75.0
## Below this dilation the world counts as dilated (drain on, regen off).
const DILATING_THRESHOLD: float = 0.995
## Meter fraction required to recover from a stall.
const STALL_RECOVER_FRAC: float = 0.2
## Gate fade in/out duration (s).
const FADE_TIME: float = 0.15
## Stall red flash duration (s).
const STALL_FLASH_TIME: float = 0.45
## Gear-seat micro shake duration (s).
const SEAT_KICK_TIME: float = 0.12
## Largest dt the model integrates in one call (guards against hitches).
const MAX_DT: float = 0.25

## Gate centre relative to the camera: screen (1120, 210) on a 1280x720 window.
const GATE_CENTER: Vector2 = Vector2(480.0, 150.0)
## Pixels per gate unit.
const GATE_SCALE: float = 40.0
## Visual half-width of a gate channel (gate units).
const CHANNEL_HALF: float = 0.14

# ---------------------------------------------------------------------------------------------
# Gears
# ---------------------------------------------------------------------------------------------

enum Gear {
	N = 0,
	G1 = 1,
	G2 = 2,
	G3 = 3,
	G4 = 4,
	G5 = 5,
	G6 = 6,
	R = 7,
}

const GEAR_DILATIONS: Array[float] = [1.0, 0.75, 0.55, 0.38, 0.24, 0.12, 0.04, 0.90]
const STANDARD_GEARS: Array[int] = [Gear.N, Gear.G1, Gear.G2, Gear.G3, Gear.G4, Gear.G5, Gear.G6]
const ALL_GEARS: Array[int] = [Gear.N, Gear.G1, Gear.G2, Gear.G3, Gear.G4, Gear.G5, Gear.G6, Gear.R]

# Internal lexical-scope static core so inner classes never depend on global class cache initialization
class _Core extends RefCounted:
	static func finite_or(v: float, fallback: float) -> float:
		if is_finite(v):
			return v
		return fallback

	static func smoothstep_01(t: float) -> float:
		var c: float = clampf(finite_or(t, 0.0), 0.0, 1.0)
		return c * c * (3.0 - 2.0 * c)

	static func gear_pos(g: int) -> Vector2:
		match g:
			Gear.N:
				return Vector2.ZERO
			Gear.G1:
				return Vector2(-1.0, 1.0)
			Gear.G2:
				return Vector2(-1.0, -1.0)
			Gear.G3:
				return Vector2(0.0, 1.0)
			Gear.G4:
				return Vector2(0.0, -1.0)
			Gear.G5:
				return Vector2(1.0, 1.0)
			Gear.G6:
				return Vector2(1.0, -1.0)
			Gear.R:
				return Vector2(1.0, -1.0)
			_:
				return Vector2.ZERO

	static func gear_dilation(g: int) -> float:
		var idx: int = clampi(g, 0, GEAR_DILATIONS.size() - 1)
		return GEAR_DILATIONS[idx]

	static func gear_label(g: int) -> String:
		match g:
			Gear.N:
				return "N"
			Gear.G1:
				return "1"
			Gear.G2:
				return "2"
			Gear.G3:
				return "3"
			Gear.G4:
				return "4"
			Gear.G5:
				return "5"
			Gear.G6:
				return "6"
			Gear.R:
				return "R"
			_:
				return "N"

	static func from_slot(col: float, y: float) -> int:
		var ci: int = int(clampf(roundf(col + 1.0), 0.0, 2.0))
		var top: bool = y > 0.0
		var idx: int = 1 + 2 * ci + (0 if top else 1)
		return clampi(idx, 0, 6)

	static func next_gear(g: int, steps: int) -> int:
		var base: int = clampi(g, 0, 6)
		var clamped_steps: int = clampi(steps, -7, 7)
		return clampi(base + clamped_steps, 0, 6)

	static func nearest_column(x: float) -> float:
		var c: float = roundf(clampf(finite_or(x, 0.0), -1.0, 1.0))
		if c == 0.0:
			return absf(0.0)
		return c

	static func exact_column(x: float) -> Variant:
		if not is_finite(x):
			return null
		for c in COLUMNS:
			if absf(x - c) < 1e-3:
				return c
		return null

	static func is_legal(p: Vector2) -> bool:
		return (
			is_finite(p.x)
			and is_finite(p.y)
			and absf(p.x) <= 1.0
			and absf(p.y) <= 1.0
			and (absf(p.y) <= RAIL_TOL or exact_column(p.x) != null)
		)

	static func project_legal(p: Vector2) -> Vector2:
		var x: float = clampf(finite_or(p.x, 0.0), -1.0, 1.0)
		var y: float = clampf(finite_or(p.y, 0.0), -1.0, 1.0)
		if x == 0.0:
			x = absf(0.0)
		if y == 0.0:
			y = absf(0.0)
		if absf(y) > RAIL_TOL:
			return Vector2(nearest_column(x), y)
		return Vector2(x, y)

	static func micro_step(p: Vector2, d: Vector2) -> Vector2:
		if absf(p.y) <= RAIL_TOL:
			var nx: float = clampf(p.x + d.x, -1.0, 1.0)
			var ny: float = p.y + d.y
			if absf(ny) > RAIL_TOL:
				var col: float = nearest_column(nx)
				var can_enter: bool = false
				if col == 0.0:
					can_enter = absf(d.x) <= 0.005 and absf(nx - col) <= COL_TOL
				else:
					can_enter = absf(nx - col) <= COL_TOL
				if can_enter:
					nx = col
					ny = clampf(ny, -1.0, 1.0)
				else:
					ny = clampf(ny, -RAIL_TOL, RAIL_TOL)
			if nx == 0.0:
				nx = absf(0.0)
			if ny == 0.0:
				ny = absf(0.0)
			return Vector2(nx, ny)
		else:
			var col: float = nearest_column(p.x)
			var ny: float = clampf(p.y + d.y, -1.0, 1.0)
			if ny == 0.0:
				ny = absf(0.0)
			return Vector2(col, ny)

	static func constrain_step(p: Vector2, delta: Vector2) -> Vector2:
		var curr: Vector2 = project_legal(p)
		var dx: float = 0.0 if is_nan(delta.x) else clampf(delta.x, -MAX_DELTA, MAX_DELTA)
		var dy: float = 0.0 if is_nan(delta.y) else clampf(delta.y, -MAX_DELTA, MAX_DELTA)
		var d := Vector2(dx, dy)
		var d_len: float = d.length()
		if d_len <= 0.0:
			return curr
		var n: int = maxi(1, int(ceilf(d_len / MAX_SUBSTEP)))
		var step: Vector2 = d / float(n)
		for _i in range(n):
			curr = micro_step(curr, step)
		return curr

	static func engagement(p: Vector2) -> float:
		if not is_finite(p.x) or not is_finite(p.y) or exact_column(p.x) == null:
			return 0.0
		return smoothstep_01((absf(p.y) - ENGAGE_START) / (1.0 - ENGAGE_START))

	static func slot_gear(p: Vector2) -> int:
		var col: Variant = exact_column(p.x)
		if col != null and p.y != 0.0 and is_finite(p.y):
			return from_slot(float(col), p.y)
		return Gear.N

	static func display_gear(p: Vector2) -> int:
		if engagement(p) > 0.0:
			return slot_gear(p)
		return Gear.N

	static func dilation_at(p: Vector2) -> float:
		var e: float = engagement(p)
		var d: float = 1.0 + (gear_dilation(slot_gear(p)) - 1.0) * e
		return clampf(d, GEAR_DILATIONS[6], 1.0)

	static func drain_for_dilation(d: float) -> float:
		var clean_d: float = clampf(finite_or(d, 1.0), 0.0, 1.0)
		return MAX_DRAIN * (1.0 - clean_d) * (1.0 - clean_d)

	static func meter_drain(dilation: float) -> float:
		var clean_d: float = finite_or(dilation, 1.0)
		if clean_d < DILATING_THRESHOLD:
			return drain_for_dilation(clean_d)
		return 0.0

	static func stall_update(stalled: bool, energy_frac: float) -> bool:
		var f: float = finite_or(energy_frac, 0.0)
		if f <= 0.0:
			return true
		elif stalled:
			return f < STALL_RECOVER_FRAC
		return false

	static func detent_target(p: Vector2) -> Vector2:
		var lp: Vector2 = project_legal(p)
		if absf(lp.y) > RAIL_TOL:
			var col: float = nearest_column(lp.x)
			if absf(lp.y) >= SEAT_THRESHOLD:
				return Vector2(col, signf(lp.y))
			return Vector2(col, 0.0)
		return Vector2(nearest_column(lp.x), 0.0)

	static func detent_step(p: Vector2, dt: float) -> Vector2:
		var lp: Vector2 = project_legal(p)
		var target: Vector2 = detent_target(lp)
		var diff: Vector2 = target - lp
		if diff.length() < 0.004:
			return target
		var clean_dt: float = clampf(finite_or(dt, 0.0), 0.0, MAX_DT)
		var alpha: float = 1.0 - exp(-DETENT_K * clean_dt)
		return constrain_step(lp, diff * alpha)

	static func seated_gear(p: Vector2) -> int:
		if exact_column(p.x) != null and is_finite(p.y) and absf(p.y) >= 0.999:
			return slot_gear(p)
		return -1

	static func plan_gear_path(from: Vector2, target: int) -> Array[Vector2]:
		var start: Vector2 = project_legal(from)
		var goal: Vector2 = gear_pos(target)
		var raw_path: Array[Vector2] = []
		var in_slot: bool = absf(start.y) > RAIL_TOL
		var same_slot: bool = (
			in_slot
			and target != Gear.N
			and nearest_column(start.x) == goal.x
			and signf(start.y) == signf(goal.y)
		)

		if not same_slot:
			if in_slot:
				raw_path.append(Vector2(nearest_column(start.x), 0.0))
			raw_path.append(Vector2(goal.x, 0.0))
		if target != Gear.N:
			raw_path.append(goal)

		var cleaned: Array[Vector2] = []
		var last: Vector2 = start
		for wp in raw_path:
			if (wp - last).length() > 1e-6:
				cleaned.append(wp)
				last = wp
		return cleaned

	static func follow_path(p: Vector2, path: Array[Vector2], speed: float, dt: float) -> Vector2:
		var curr: Vector2 = project_legal(p)
		var budget: float = maxf(finite_or(speed * dt, 0.0), 0.0)
		while budget > 1e-5:
			if path.is_empty():
				break
			var wp: Vector2 = path[0]
			var to: Vector2 = wp - curr
			var dist: float = to.length()
			if dist <= 1e-5:
				curr = wp
				path.pop_front()
				continue
			if dist <= budget:
				var np: Vector2 = constrain_step(curr, to)
				if (np - wp).length() < 1e-3 and is_legal(wp):
					curr = wp
					path.pop_front()
					budget -= dist
				else:
					path.clear()
					return np
			else:
				var move_vec: Vector2 = to / dist * budget
				var np: Vector2 = constrain_step(curr, move_vec)
				if move_vec.length() > 1e-4 and (np - curr).length() < move_vec.length() * 0.1:
					path.clear()
				curr = np
				budget = 0.0
		return curr

# ---------------------------------------------------------------------------------------------
# Public Static API matching chrono_shift.rs 1:1
# ---------------------------------------------------------------------------------------------

static func finite_or(v: float, fallback: float) -> float:
	return _Core.finite_or(v, fallback)

static func smoothstep_01(t: float) -> float:
	return _Core.smoothstep_01(t)

static func gear_pos(g: int) -> Vector2:
	return _Core.gear_pos(g)

static func gear_dilation(g: int) -> float:
	return _Core.gear_dilation(g)

static func gear_label(g: int) -> String:
	return _Core.gear_label(g)

static func from_slot(col: float, y: float) -> int:
	return _Core.from_slot(col, y)

static func next_gear(g: int, steps: int) -> int:
	return _Core.next_gear(g, steps)

static func nearest_column(x: float) -> float:
	return _Core.nearest_column(x)

static func exact_column(x: float) -> Variant:
	return _Core.exact_column(x)

static func is_legal(p: Vector2) -> bool:
	return _Core.is_legal(p)

static func project_legal(p: Vector2) -> Vector2:
	return _Core.project_legal(p)

static func micro_step(p: Vector2, d: Vector2) -> Vector2:
	return _Core.micro_step(p, d)

static func constrain_step(p: Vector2, delta: Vector2) -> Vector2:
	return _Core.constrain_step(p, delta)

static func engagement(p: Vector2) -> float:
	return _Core.engagement(p)

static func slot_gear(p: Vector2) -> int:
	return _Core.slot_gear(p)

static func display_gear(p: Vector2) -> int:
	return _Core.display_gear(p)

static func dilation_at(p: Vector2) -> float:
	return _Core.dilation_at(p)

static func drain_for_dilation(d: float) -> float:
	return _Core.drain_for_dilation(d)

static func meter_drain(dilation: float) -> float:
	return _Core.meter_drain(dilation)

static func stall_update(stalled: bool, energy_frac: float) -> bool:
	return _Core.stall_update(stalled, energy_frac)

static func detent_target(p: Vector2) -> Vector2:
	return _Core.detent_target(p)

static func detent_step(p: Vector2, dt: float) -> Vector2:
	return _Core.detent_step(p, dt)

static func seated_gear(p: Vector2) -> int:
	return _Core.seated_gear(p)

static func plan_gear_path(from: Vector2, target: int) -> Array[Vector2]:
	return _Core.plan_gear_path(from, target)

static func follow_path(p: Vector2, path: Array[Vector2], speed: float, dt: float) -> Vector2:
	return _Core.follow_path(p, path, speed, dt)

## Outline segments (gate units) of the H-gate channel: Array of [Vector2, Vector2] pairs.
static func gate_outline() -> Array:
	var w: float = CHANNEL_HALF
	var top: float = 1.0 + w
	var s: Array = []
	for sign_val in [1.0, -1.0]:
		for c in COLUMNS:
			s.append([Vector2(c - w, sign_val * top), Vector2(c + w, sign_val * top)])
		s.append([Vector2(-1.0 + w, sign_val * w), Vector2(-1.0 + w, sign_val * top)])
		s.append([Vector2(-w, sign_val * w), Vector2(-w, sign_val * top)])
		s.append([Vector2(w, sign_val * w), Vector2(w, sign_val * top)])
		s.append([Vector2(1.0 - w, sign_val * w), Vector2(1.0 - w, sign_val * top)])
		s.append([Vector2(-1.0 + w, sign_val * w), Vector2(-w, sign_val * w)])
		s.append([Vector2(w, sign_val * w), Vector2(1.0 - w, sign_val * w)])
	s.append([Vector2(-1.0 - w, -top), Vector2(-1.0 - w, top)])
	s.append([Vector2(1.0 + w, -top), Vector2(1.0 + w, top)])
	return s

## 7-segment glyph segments: a, b, c, d, e, f, g.
static func seven_segments(ch: String) -> Array[bool]:
	match ch:
		"0":
			return [true, true, true, true, true, true, false]
		"1":
			return [false, true, true, false, false, false, false]
		"2":
			return [true, true, false, true, true, false, true]
		"3":
			return [true, true, true, true, false, false, true]
		"4":
			return [false, true, true, false, false, true, true]
		"5":
			return [true, false, true, true, false, true, true]
		"6":
			return [true, false, true, true, true, true, true]
		"R":
			return [true, true, true, false, true, true, true]
		_:
			return [false, false, false, false, false, false, false]

# ---------------------------------------------------------------------------------------------
# Combat Accuracy & Acclimatization (Plus Turbo Shifter Overdrive & Reverse Gear)
# ---------------------------------------------------------------------------------------------

class GearAcclimatization extends RefCounted:
	const TURBO_MAX_TIME: float = 6.0
	const TURBO_SPEED_BOOST: float = 1.35
	const TURBO_OVERHEAT_DRAIN_MULT: float = 2.5

	var mastered_tier: int = 0
	var tolerance: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
	var flawless_streak: int = 0
	var feedback_banner: String = ""
	var feedback_timer: float = 0.0

	# PDF Page 6: Turbo Shifter Overuse & Knockdown + Reverse Gear
	var turbo_overuse_timer: float = 0.0
	var turbo_overheated: bool = false
	var reverse_insta_death: bool = false
	var last_active_gear: int = Gear.N

	func _init() -> void:
		tolerance = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]

	static func required_kills(gear_idx: int) -> int:
		match gear_idx:
			1:
				return 2 # G1: 2 flawless kills
			2:
				return 3 # G2: 3 flawless kills
			3:
				return 3 # G3: 3 flawless kills
			4:
				return 4 # G4: 4 flawless kills
			5:
				return 4 # G5: 4 flawless kills
			6:
				return 5 # G6: 5 flawless kills (Stasis)
			_:
				return 1

	func tick(dt: float, active_gear: int = 0) -> void:
		var clean_dt: float = maxf(_Core.finite_or(dt, 0.0), 0.0)
		if feedback_timer > 0.0:
			feedback_timer = maxf(feedback_timer - clean_dt, 0.0)
			if feedback_timer <= 0.0:
				feedback_banner = ""

		last_active_gear = active_gear
		if active_gear == Gear.G5 or active_gear == Gear.G6:
			turbo_overuse_timer += clean_dt
			if turbo_overuse_timer > TURBO_MAX_TIME and not turbo_overheated:
				turbo_overheated = true
				feedback_banner = "⚠️ TURBO OVERHEAT! SHIFT DOWN!"
				feedback_timer = 2.0
		elif active_gear >= Gear.N and active_gear <= Gear.G4:
			turbo_overuse_timer = 0.0
			turbo_overheated = false

	func is_turbo_active(active_gear: int = -1) -> bool:
		var g: int = last_active_gear if active_gear < 0 else active_gear
		return (g == Gear.G5 or g == Gear.G6) and not turbo_overheated

	func get_turbo_speed_multiplier(active_gear: int = -1) -> float:
		return TURBO_SPEED_BOOST if is_turbo_active(active_gear) else 1.0

	func on_flawless_kill(active_gear: int, count: int) -> bool:
		var idx: int = clampi(active_gear, 0, 7)
		if idx == 0 or idx == Gear.R or count <= 0:
			return false
		flawless_streak += count

		var req: float = float(required_kills(idx))
		var add: float = float(count) / req
		var newly_mastered: bool = false

		if mastered_tier >= idx - 1:
			var prev: float = tolerance[idx]
			tolerance[idx] = minf(tolerance[idx] + add, 1.0)
			if tolerance[idx] >= 0.999 and prev < 0.999:
				newly_mastered = true
				while mastered_tier < 6 and tolerance[mastered_tier + 1] >= 0.999:
					mastered_tier += 1
				feedback_banner = "GEAR %d MASTERED! ✨" % idx
				feedback_timer = 2.2
			elif not newly_mastered:
				feedback_banner = "FLAWLESS! [G%d: %d%%]" % [idx, int(roundf(tolerance[idx] * 100.0))]
				feedback_timer = 1.2
		else:
			tolerance[idx] = minf(tolerance[idx] + add * 0.4, 0.5)
			feedback_banner = "FLAWLESS (MASTER G%d FIRST)" % (idx - 1)
			feedback_timer = 1.2

		return newly_mastered

	func on_miss(active_gear: int, is_warp: bool) -> void:
		var idx: int = clampi(active_gear, 0, 7)
		flawless_streak = 0
		if idx > 0 and idx <= 6 and tolerance[idx] < 0.999:
			var penalty: float = 0.40 if is_warp else 0.30
			tolerance[idx] = maxf(tolerance[idx] - penalty, 0.0)
			if is_warp:
				feedback_banner = "⚠️ WARP MISSED - FOCUS LOST!"
			else:
				feedback_banner = "⚠️ SLASH MISSED - FOCUS LOST!"
			feedback_timer = 1.2

	func on_damage(active_gear: int) -> void:
		flawless_streak = 0
		var idx: int = clampi(active_gear, 0, 7)
		if idx == Gear.R:
			reverse_insta_death = true
		if idx > 0 and idx <= 6 and tolerance[idx] < 0.999:
			tolerance[idx] = maxf(tolerance[idx] - 0.20, 0.0)
			feedback_banner = "⚠️ HIT TAKEN - CADENCE BROKEN!"
			feedback_timer = 1.2

	## PDF Page 6: Taking damage in Gears 2..6 knocks the shifter down to Gear 1;
	## Taking damage in Reverse Gear (R) triggers insta-death!
	func on_damage_gear_knockdown(active_gear: int) -> int:
		on_damage(active_gear)
		if active_gear == Gear.R:
			reverse_insta_death = true
			feedback_banner = "💀 REVERSE PARRY FAILED - INSTA-DEATH!"
			feedback_timer = 2.5
			return Gear.N
		elif active_gear >= Gear.G2 and active_gear <= Gear.G6:
			turbo_overuse_timer = 0.0
			turbo_overheated = false
			feedback_banner = "⚠️ HIT TAKEN - KNOCKED DOWN TO GEAR 1!"
			feedback_timer = 1.5
			return Gear.G1
		return active_gear

	func burnout_multiplier(active_gear: int) -> float:
		var idx: int = clampi(active_gear, 0, 7)
		if idx == 0 or idx == Gear.R:
			return 1.0
		var base_mult: float = 1.0
		if idx <= mastered_tier:
			base_mult = 0.05
		elif idx == mastered_tier + 1:
			if idx <= 2:
				base_mult = 1.0
			else:
				var denom: float = _Core.drain_for_dilation(_Core.gear_dilation(idx))
				if denom > 1e-4:
					base_mult = _Core.drain_for_dilation(_Core.gear_dilation(Gear.G2)) / denom
				else:
					base_mult = 1.0
		else:
			var skipped: float = float(maxi(0, idx - (mastered_tier + 1)))
			var relief: float = float(mastered_tier) * 0.8
			var tol: float = clampf(_Core.finite_or(tolerance[idx], 0.0), 0.0, 1.0)
			base_mult = maxf(2.5 + skipped * 2.0 + (1.0 - tol) * 2.0 - relief, 1.5)

		if turbo_overheated and (idx == Gear.G5 or idx == Gear.G6):
			base_mult *= TURBO_OVERHEAT_DRAIN_MULT
		return base_mult

	func is_mastered(gear: int) -> bool:
		var idx: int = clampi(gear, 0, 7)
		return idx == 0 or idx == Gear.R or (mastered_tier >= idx and tolerance[idx] >= 0.999)

# ---------------------------------------------------------------------------------------------
# Shifter state machine (pure)
# ---------------------------------------------------------------------------------------------

class ShifterInput extends RefCounted:
	var held: bool = false
	var drag: Vector2 = Vector2.ZERO
	var wheel_steps: int = 0
	var jump_to: int = -1

	func _init(
		p_held: bool = false,
		p_drag: Vector2 = Vector2.ZERO,
		p_wheel_steps: int = 0,
		p_jump_to: int = -1
	) -> void:
		held = p_held
		drag = p_drag
		wheel_steps = p_wheel_steps
		jump_to = p_jump_to

class ShiftOutput extends RefCounted:
	var dilation: float = 1.0
	var seated: int = -1
	var newly_stalled: bool = false

class ShifterModel extends RefCounted:
	var knob: Vector2 = Vector2.ZERO
	var held: bool = false
	var path: Array[Vector2] = []
	var target: int = -1
	var stalled: bool = false
	var stall_flash: float = 0.0
	var fade: float = 0.0
	var seat_kick: float = 0.0
	var last_seat: int = -1
	var dilation: float = 1.0
	var reverse_engaged: bool = false

	func set_target(g: int) -> void:
		reverse_engaged = (g == Gear.R)
		path = _Core.plan_gear_path(knob, g)
		target = -1 if path.is_empty() else g

	func ensure_heading_neutral() -> void:
		reverse_engaged = false
		var heading_n: bool = (target == Gear.N) and not path.is_empty()
		if not heading_n and knob != Vector2.ZERO:
			set_target(Gear.N)

	func get_active_gear() -> int:
		var dg: int = _Core.display_gear(knob)
		if reverse_engaged and (dg != Gear.N or target == Gear.R):
			return Gear.R
		return dg

	func step(input: ShifterInput, energy_frac: float, dt: float) -> ShiftOutput:
		var clean_dt: float = clampf(_Core.finite_or(dt, 0.0), 0.0, MAX_DT)
		var out := ShiftOutput.new()

		# 1. Stall hysteresis.
		var was_stalled: bool = stalled
		stalled = _Core.stall_update(stalled, energy_frac)
		if stalled and not was_stalled:
			out.newly_stalled = true
			if held or input.held or knob != Vector2.ZERO:
				stall_flash = 1.0
			set_target(Gear.N)

		# 2. Intent.
		held = input.held
		var dragged: bool = false
		if stalled:
			ensure_heading_neutral()
		elif held:
			var drag := Vector2(
				_Core.finite_or(input.drag.x, 0.0),
				_Core.finite_or(input.drag.y, 0.0)
			)
			if drag.length() > DRAG_DEADZONE:
				path.clear()
				target = -1
				reverse_engaged = false
				knob = _Core.constrain_step(knob, drag)
				dragged = true
			if input.jump_to >= 0:
				set_target(input.jump_to)
			elif input.wheel_steps != 0:
				reverse_engaged = false
				var base: int = target
				if base < 0:
					if absf(knob.y) > RAIL_TOL:
						base = _Core.slot_gear(knob)
					else:
						base = _Core.display_gear(knob)
				set_target(_Core.next_gear(base, input.wheel_steps))

		# 3. Integrate.
		if not path.is_empty():
			knob = _Core.follow_path(knob, path, PATH_SPEED, clean_dt)
			if path.is_empty():
				target = -1
		elif not dragged:
			knob = _Core.detent_step(knob, clean_dt)
		knob = _Core.project_legal(knob)

		if knob == Vector2.ZERO and target != Gear.R:
			reverse_engaged = false

		# 4. Seat clicks.
		var raw_seat: int = _Core.seated_gear(knob)
		var seat: int = (Gear.R if reverse_engaged else raw_seat) if raw_seat != -1 else -1
		if seat != last_seat:
			if seat != -1:
				out.seated = seat
				seat_kick = SEAT_KICK_TIME
			last_seat = seat

		# 5. Timers.
		var is_in_gear: bool = (target > 0) or (_Core.display_gear(knob) != Gear.N)
		var fade_target: float = 0.0
		if held:
			fade_target = 1.0
		elif stalled or not is_in_gear:
			fade_target = 0.0
		else:
			fade_target = 0.85

		var fade_step: float = clean_dt / FADE_TIME
		if fade < fade_target:
			fade = minf(fade + fade_step, fade_target)
		else:
			fade = maxf(fade - fade_step, fade_target)
		stall_flash = maxf(stall_flash - clean_dt / STALL_FLASH_TIME, 0.0)
		seat_kick = maxf(seat_kick - clean_dt, 0.0)

		# 6. Output.
		if stalled:
			dilation = 1.0
		elif not held and target > 0 and absf(knob.y) <= RAIL_TOL:
			dilation = _Core.gear_dilation(target)
		elif reverse_engaged:
			var e: float = _Core.engagement(knob)
			dilation = clampf(1.0 + (_Core.gear_dilation(Gear.R) - 1.0) * e, GEAR_DILATIONS[6], 1.0)
		else:
			dilation = _Core.dilation_at(knob)
		out.dilation = dilation
		return out

## Readout text formatting (pure, shared with tests).
static func readout_text(
	model: ShifterModel,
	drain: float,
	energy_frac: float,
	acclimatization: GearAcclimatization
) -> String:
	var clean_efrac: float = clampf(_Core.finite_or(energy_frac, 0.0) * 100.0, 0.0, 100.0)
	if model.stalled:
		return "STALL  ·  GRIND  ·  RECHARGE %d%%" % int(roundf(clean_efrac))
	var active: int = model.get_active_gear()
	if active == Gear.N:
		return "GEAR N  ·  1.00x  ·  DRAIN 0/s"
	var burnout_mult: float = acclimatization.burnout_multiplier(active)
	var status: String = ""
	if not acclimatization.feedback_banner.is_empty():
		status = acclimatization.feedback_banner
	elif acclimatization.is_mastered(active):
		status = "MASTERED ✨"
	elif burnout_mult > 1.05 and active > acclimatization.mastered_tier + 1:
		status = "⚠️ BURNOUT!"
	else:
		status = "ADAPTING..."

	var clean_dilation: float = _Core.finite_or(model.dilation, 1.0)
	var clean_drain: float = _Core.finite_or(drain, 0.0)
	if burnout_mult > 1.05:
		return "GEAR %s  ·  %.2fx  ·  [%s]  ·  ⚠️ BURNOUT x%.1f  ·  DRAIN %d/s" % [
			_Core.gear_label(active),
			clean_dilation,
			status,
			burnout_mult,
			int(roundf(clean_drain))
		]
	return "GEAR %s  ·  %.2fx  ·  [%s]  ·  DRAIN %d/s" % [
		_Core.gear_label(active),
		clean_dilation,
		status,
		int(roundf(clean_drain))
	]

# ---------------------------------------------------------------------------------------------
# Full ChronoShifterState (combines ChronoShifter + ChronoState + ChronoEnergy for systems/tests)
# ---------------------------------------------------------------------------------------------

class ChronoShifterState extends RefCounted:
	var model: ShifterModel = ShifterModel.new()
	var acclimatization: GearAcclimatization = GearAcclimatization.new()
	var base_drain_per_sec: float = 0.0
	var drain_per_sec: float = 0.0
	var burnout_multiplier: float = 1.0
	var energy_frac: float = 1.0

	var energy_current: float = 100.0
	var energy_max: float = 100.0
	var energy_drain_rate: float = 22.0
	var energy_regen_rate: float = 14.0
	var teleport_cost: float = 25.0
	var kill_restore: float = 25.0

	var anchor_screen: Variant = null
	var frozen_aim: Variant = null
	var aim_locked: bool = false
	var dilation_edge: Variant = null

	var dilation_factor: float = 1.0
	var is_dilating: bool = false
	var hitstop_timer: float = 0.0
	var screen_shake: float = 0.0
	var shake_offset: Vector2 = Vector2.ZERO
	var slowmo_factor: float = 1.0

	func is_held() -> bool:
		return model.held

	func aim_frozen() -> bool:
		return aim_locked

	func can_teleport() -> bool:
		return not model.stalled and energy_current >= teleport_cost

	func consume_teleport() -> bool:
		if can_teleport():
			energy_current = maxf(energy_current - teleport_cost, 0.0)
			energy_frac = clampf(energy_current / energy_max, 0.0, 1.0) if energy_max > 0.0 else 0.0
			return true
		return false

	func reward_kill() -> void:
		energy_current = minf(energy_current + kill_restore, energy_max)
		energy_frac = clampf(energy_current / energy_max, 0.0, 1.0) if energy_max > 0.0 else 0.0

	func update_with_drain(drain: float, dt: float) -> void:
		var clean_drain: float = maxf(_Core.finite_or(drain, 0.0), 0.0)
		var clean_dt: float = maxf(_Core.finite_or(dt, 0.0), 0.0)
		if clean_drain > 0.0:
			energy_current = maxf(energy_current - clean_drain * clean_dt, 0.0)
		else:
			energy_current = minf(energy_current + energy_regen_rate * clean_dt, energy_max)
		energy_frac = clampf(energy_current / energy_max, 0.0, 1.0) if energy_max > 0.0 else 0.0

	func trigger_shake(intensity: float) -> void:
		var clean_i: float = maxf(_Core.finite_or(intensity, 0.0), 0.0)
		screen_shake = minf(screen_shake + clean_i, 20.0)

	func trigger_hitstop(duration: float) -> void:
		hitstop_timer = maxf(hitstop_timer, _Core.finite_or(duration, 0.0))

	func update_chrono(unscaled_dt: float) -> void:
		var dt: float = maxf(_Core.finite_or(unscaled_dt, 0.0), 0.0)
		if hitstop_timer > 0.0:
			hitstop_timer = maxf(hitstop_timer - dt, 0.0)

		if screen_shake > 0.0:
			screen_shake = maxf(screen_shake - dt * 30.0, 0.0)
			if screen_shake > 0.001:
				var angle: float = sin(dt * 1234.5 + screen_shake * 987.6) * TAU
				shake_offset = Vector2(cos(angle), sin(angle)) * screen_shake
			else:
				shake_offset = Vector2.ZERO
		else:
			shake_offset = Vector2.ZERO

		var target_dilation: float = slowmo_factor if is_dilating else 1.0
		dilation_factor = dilation_factor + (target_dilation - dilation_factor) * minf(dt * 20.0, 1.0)

	func apply_damage_knockdown() -> int:
		var active: int = model.get_active_gear()
		var knocked_to: int = acclimatization.on_damage_gear_knockdown(active)
		if knocked_to != active:
			model.reverse_engaged = false
			model.path.clear()
			model.target = -1
			model.knob = _Core.gear_pos(knocked_to)
			model.dilation = _Core.gear_dilation(knocked_to)
			slowmo_factor = model.dilation
			is_dilating = model.dilation < DILATING_THRESHOLD
		return knocked_to

	func step_control(
		input: ShifterInput,
		dt: float,
		cursor_world: Variant = null,
		cursor_screen: Variant = null
	) -> ShiftOutput:
		energy_frac = clampf(energy_current / energy_max, 0.0, 1.0) if energy_max > 0.0 else 0.0
		var out: ShiftOutput = model.step(input, energy_frac, dt)
		var dilation: float = out.dilation
		var active_gear: int = model.get_active_gear()

		acclimatization.tick(dt, active_gear)

		var base_drain: float = _Core.meter_drain(dilation)
		var burnout_mult: float = (
			acclimatization.burnout_multiplier(active_gear)
			if dilation < DILATING_THRESHOLD
			else 1.0
		)
		var drain: float = base_drain * burnout_mult

		update_with_drain(drain, dt)
		base_drain_per_sec = base_drain
		burnout_multiplier = burnout_mult
		drain_per_sec = drain

		var was: bool = is_dilating
		slowmo_factor = dilation
		is_dilating = dilation < DILATING_THRESHOLD
		if is_dilating != was:
			dilation_edge = is_dilating
		else:
			dilation_edge = null

		if out.seated != -1 and model.held:
			trigger_shake(1.2)
		if out.newly_stalled and model.stall_flash > 0.0:
			trigger_shake(4.0)

		if model.held and not aim_locked:
			aim_locked = true
			if frozen_aim == null:
				frozen_aim = cursor_world
			anchor_screen = cursor_screen
		elif not model.held and aim_locked:
			aim_locked = false
			anchor_screen = null

		update_chrono(dt)
		return out
