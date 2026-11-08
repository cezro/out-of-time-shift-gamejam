extends SceneTree

## Comprehensive test suite porting all Chronos Shift tests from bevy-game-test/src/chrono_shift.rs
## PLUS tests for Reverse Gear (R), Turbo Shifter Overdrive & Knockdown, 3-Era Timeline Switching,
## Chronos Wells, Phase Traversal Scenarios, Chrono-Echoes, and Hidden Lore Glyphs.

const CSM = preload("res://scripts/chrono_shift/chrono_shift_model.gd")
const TS = preload("res://scripts/timeline/timeline_system.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

## Deterministic xorshift PRNG matching chrono_shift.rs::tests::Rng
class Rng extends RefCounted:
	var state: int = 0

	func _init(seed_val: int) -> void:
		state = seed_val

	func next_u32() -> int:
		# Simulate 64-bit unsigned xorshift in GDScript 64-bit signed int
		var x: int = state
		x = x ^ ((x << 13) & -1)
		x = x ^ ((x >> 7) & 0x01FFFFFFFFFFFFFF)
		x = x ^ ((x << 17) & -1)
		state = x
		return (x >> 32) & 0xFFFFFFFF

	func unit() -> float:
		return (float(next_u32()) / 4294967295.0) * 2.0 - 1.0

	func delta() -> Vector2:
		var scale: float = 0.02
		match next_u32() % 9:
			0:
				scale = 1e-6
			1:
				scale = 0.01
			2:
				scale = 0.04
			3:
				scale = 0.1
			4:
				scale = 0.5
			5:
				scale = 3.0
			6:
				scale = 1e6
			7:
				scale = 1e30
			_:
				scale = 0.02
		var d := Vector2(unit(), unit()) * scale
		var r: int = next_u32() % 64
		if r == 0:
			d.x = NAN
		elif r == 1:
			d.y = INF
		elif r == 2:
			d = Vector2(-INF, NAN)
		elif r >= 3 and r <= 10:
			d.x = 0.0
		elif r >= 11 and r <= 18:
			d.y = 0.0
		return d

func _assert(cond: bool, msg: String = "Assertion failed") -> void:
	if not cond:
		_tests_failed += 1
		push_error("FAIL: " + msg)
		assert(false, msg)

func _sample_segment_legal(a: Vector2, b: Vector2) -> bool:
	for i in range(101):
		var t: float = float(i) / 100.0
		if not CSM.is_legal(a.lerp(b, t)):
			return false
	return true

func _make_test_shifter_state() -> CSM.ChronoShifterState:
	var s := CSM.ChronoShifterState.new()
	s.acclimatization.mastered_tier = 6
	for i in range(s.acclimatization.tolerance.size()):
		s.acclimatization.tolerance[i] = 1.0
	return s

func _engage_gear(s: CSM.ChronoShifterState, gear: int, frames: int = 40) -> void:
	s.step_control(CSM.ShifterInput.new(true, Vector2.ZERO, 0, gear), 0.016)
	for _i in range(frames):
		s.step_control(CSM.ShifterInput.new(true), 0.016)

func _run_frames(s: CSM.ChronoShifterState, held: bool, frames: int) -> void:
	for _i in range(frames):
		s.step_control(CSM.ShifterInput.new(held), 0.016)

# ---------------------------------------------------------------------------------------------
# Ported Chronos Shift Tests (1 - 30)
# ---------------------------------------------------------------------------------------------

func test_01_gear_positions_are_legal_and_dilations_strictly_decrease() -> void:
	for i in range(CSM.STANDARD_GEARS.size()):
		var g: int = CSM.STANDARD_GEARS[i]
		var pos: Vector2 = CSM.gear_pos(g)
		_assert(CSM.is_legal(pos), "Gear pos must be legal: %d" % g)
		_assert(g == i, "Gear index mismatch")
		_assert(CSM.slot_gear(pos) == g, "slot_gear must match gear")
		_assert(absf(CSM.dilation_at(pos) - CSM.gear_dilation(g)) < 1e-6, "dilation_at mismatch")
	for i in range(CSM.STANDARD_GEARS.size() - 1):
		var g0: int = CSM.STANDARD_GEARS[i]
		var g1: int = CSM.STANDARD_GEARS[i + 1]
		_assert(CSM.gear_dilation(g1) < CSM.gear_dilation(g0), "Dilations must strictly decrease")

func test_02_fuzz_constrain_step_always_legal_and_never_tunnels() -> void:
	var rng := Rng.new(0x1E3779B97F4A7C15)
	var p := Vector2.ZERO
	for i in range(2500):
		var d: Vector2 = rng.delta()
		var np: Vector2 = CSM.constrain_step(p, d)
		_assert(CSM.is_legal(np), "step %d: illegal %s from %s by %s" % [i, str(np), str(p), str(d)])
		if is_finite(d.x) and is_finite(d.y) and d.length() <= CSM.MAX_SUBSTEP:
			if absf(p.y) > CSM.RAIL_TOL:
				_assert(np.x == p.x, "step %d: left slot sideways" % i)
			if absf(np.y) > CSM.RAIL_TOL and absf(p.y) <= CSM.RAIL_TOL:
				_assert(absf(p.x - np.x) <= CSM.COL_TOL + CSM.MAX_SUBSTEP + 1e-5, "step %d: wall tunnel" % i)
			_assert((np - p).length() <= CSM.MAX_SUBSTEP + CSM.COL_TOL + 1e-5, "step %d: jump too far" % i)
		p = np
		if rng.next_u32() % 200 == 0:
			p = CSM.project_legal(Vector2(rng.unit() * 5.0, rng.unit() * 5.0))
			_assert(CSM.is_legal(p), "project_legal must be legal")
	_assert(CSM.is_legal(CSM.constrain_step(Vector2(NAN, INF), Vector2(NAN, 1.0))), "NaN/Inf constrain_step legal")

func test_03_huge_deltas_cannot_tunnel_through_walls() -> void:
	var p: Vector2 = CSM.constrain_step(Vector2(0.5, 0.0), Vector2(0.0, 1e9))
	_assert(p.x == 0.5, "Off-column x preserved")
	_assert(p.y <= CSM.RAIL_TOL + 1e-6, "Stopped by rail wall")
	_assert(CSM.constrain_step(CSM.gear_pos(CSM.Gear.G1), Vector2(1e9, 0.0)) == CSM.gear_pos(CSM.Gear.G1), "Deep in slot 1 sideways blocked")
	_assert(CSM.constrain_step(CSM.gear_pos(CSM.Gear.G6), Vector2(-INF, 0.0)) == CSM.gear_pos(CSM.Gear.G6), "Deep in slot 6 sideways blocked")
	p = CSM.constrain_step(CSM.gear_pos(CSM.Gear.G1), Vector2(2.0, -1.0))
	_assert(CSM.is_legal(p), "Diagonal shove out of slot 1 legal")
	_assert(absf(p.y) <= CSM.RAIL_TOL + 1e-6, "Must travel down to rail first")
	p = CSM.constrain_step(Vector2(0.15, 0.0), Vector2(0.0, 0.5))
	_assert(p.x == 0.0, "Captured by center column")
	_assert(absf(p.y - 0.5) < 1e-5, "Entered center slot to 0.5")

func test_04_detent_seats_into_gear_and_rail() -> void:
	var settle := func(start: Vector2) -> Vector2:
		var curr: Vector2 = start
		for _i in range(120):
			curr = CSM.detent_step(curr, 1.0 / 60.0)
			_assert(CSM.is_legal(curr), "detent_step legal")
		return curr

	_assert(settle.call(Vector2(0.0, 0.7)) == CSM.gear_pos(CSM.Gear.G3), "Seats into G3")
	_assert(settle.call(Vector2(1.0, -0.6)) == CSM.gear_pos(CSM.Gear.G6), "Seats into G6")
	_assert(settle.call(Vector2(0.0, 0.3)) == Vector2.ZERO, "Returns to neutral below SEAT_THRESHOLD")
	_assert(settle.call(Vector2(0.4, 0.05)) == Vector2.ZERO, "Returns to center column on rail")
	_assert(settle.call(Vector2(0.7, 0.0)) == Vector2(1.0, 0.0), "Returns to right column on rail")
	_assert(CSM.seated_gear(CSM.gear_pos(CSM.Gear.G3)) == CSM.Gear.G3, "seated_gear G3")
	_assert(CSM.seated_gear(Vector2(0.0, 0.5)) == -1, "Not seated at 0.5")

func test_05_engagement_is_monotonic_and_bounded() -> void:
	var prev: float = -1.0
	for i in range(1001):
		var y: float = float(i) / 1000.0
		var e: float = CSM.engagement(Vector2(0.0, y))
		_assert(e >= 0.0 and e <= 1.0, "engagement in [0,1]")
		_assert(e >= prev - 1e-7, "engagement monotonic")
		prev = e
	_assert(CSM.engagement(Vector2(0.0, 0.1)) == 0.0, "engagement 0 below ENGAGE_START")
	_assert(CSM.engagement(Vector2(0.0, 1.0)) == 1.0, "engagement 1 at end")
	_assert(CSM.engagement(Vector2(0.5, 0.0)) == 0.0, "engagement 0 off-column")
	for g in [
		CSM.Gear.G1,
		CSM.Gear.G2,
		CSM.Gear.G3,
		CSM.Gear.G4,
		CSM.Gear.G5,
		CSM.Gear.G6
	]:
		var prev_d: float = 1.0 + 1e-6
		var gpos: Vector2 = CSM.gear_pos(g)
		var gdil: float = CSM.gear_dilation(g)
		for i in range(101):
			var p := Vector2(gpos.x, gpos.y * float(i) / 100.0)
			var d: float = CSM.dilation_at(p)
			_assert(d <= prev_d + 1e-6 and d >= gdil - 1e-6 and d <= 1.0, "dilation monotonic in slot")
			prev_d = d

func test_06_drain_mapping_monotonic_and_matches_table() -> void:
	_assert(CSM.drain_for_dilation(1.0) == 0.0, "No drain at 1.0")
	_assert(absf(CSM.drain_for_dilation(0.0) - CSM.MAX_DRAIN) < 1e-4, "MAX_DRAIN at 0.0")
	var prev: float = INF
	for i in range(101):
		var d: float = CSM.drain_for_dilation(float(i) / 100.0)
		_assert(d <= prev and d >= 0.0 and d <= CSM.MAX_DRAIN, "drain monotonic")
		prev = d
	var expected_pairs := [
		[CSM.Gear.G1, 4.7],
		[CSM.Gear.G2, 15.2],
		[CSM.Gear.G3, 28.8],
		[CSM.Gear.G4, 43.3],
		[CSM.Gear.G5, 58.1],
		[CSM.Gear.G6, 69.1],
	]
	for pair in expected_pairs:
		var g: int = pair[0]
		var exp_val: float = pair[1]
		var actual: float = CSM.drain_for_dilation(CSM.gear_dilation(g))
		_assert(absf(actual - exp_val) < 0.2, "drain table match for gear %d" % g)
	_assert(CSM.drain_for_dilation(NAN) == 0.0, "NaN drain is 0")
	_assert(CSM.meter_drain(0.996) == 0.0, "meter_drain above threshold is 0")
	_assert(CSM.meter_drain(0.5) > 0.0, "meter_drain at 0.5 > 0")

func test_07_planned_paths_are_legal_and_reach_target() -> void:
	var starts: Array[Vector2] = []
	for g in CSM.STANDARD_GEARS:
		starts.append(CSM.gear_pos(g))
	starts.append_array([
		Vector2(0.4, 0.08),
		Vector2(-0.9, -0.1),
		Vector2(0.0, 0.5),
		Vector2(1.0, -0.3),
		Vector2(-1.0, 0.0),
	])
	for s in starts:
		for g in CSM.STANDARD_GEARS:
			var path: Array[Vector2] = CSM.plan_gear_path(s, g)
			var last: Vector2 = s
			for wp in path:
				_assert(CSM.is_legal(wp), "waypoint legal")
				_assert(_sample_segment_legal(last, wp), "segment legal")
				last = wp
			var p: Vector2 = s
			var frames: int = 0
			while not path.is_empty():
				p = CSM.follow_path(p, path, CSM.PATH_SPEED, 1.0 / 60.0)
				_assert(CSM.is_legal(p), "follow_path legal")
				frames += 1
				_assert(frames < 120, "path converged")
			if g != CSM.Gear.N or absf(s.y) > CSM.RAIL_TOL or s != Vector2.ZERO:
				_assert(p == CSM.gear_pos(g), "path reached target gear")

func test_08_wheel_shifts_are_sequential_and_legal() -> void:
	var m := CSM.ShifterModel.new()
	var expected: int = CSM.Gear.N
	for _step in range(8):
		m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 1, -1), 1.0, 1.0 / 60.0)
		expected = CSM.next_gear(expected, 1)
		for _f in range(60):
			m.step(CSM.ShifterInput.new(true), 1.0, 1.0 / 60.0)
			_assert(CSM.is_legal(m.knob), "wheel shift up knob legal")
		_assert(m.knob == CSM.gear_pos(expected), "wheel shift up reached expected")
	_assert(expected == CSM.Gear.G6, "saturated at G6")
	for _step in range(8):
		m.step(CSM.ShifterInput.new(true, Vector2.ZERO, -1, -1), 1.0, 1.0 / 60.0)
		expected = CSM.next_gear(expected, -1)
		for _f in range(60):
			m.step(CSM.ShifterInput.new(true), 1.0, 1.0 / 60.0)
			_assert(CSM.is_legal(m.knob), "wheel shift down knob legal")
		_assert(m.knob == CSM.gear_pos(expected), "wheel shift down reached expected")
	_assert(expected == CSM.Gear.N, "saturated at N")

func test_09_gear_persists_on_release_and_manual_neutral_return() -> void:
	var m := CSM.ShifterModel.new()
	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G6), 1.0, 0.016)
	for _i in range(60):
		m.step(CSM.ShifterInput.new(true), 1.0, 0.016)
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G6), "Reached G6")
	_assert(absf(m.dilation - 0.04) < 1e-6, "Dilation 0.04")
	_assert(absf(m.fade - 1.0) < 1e-6, "Fade 1.0")

	for _i in range(60):
		var out: CSM.ShiftOutput = m.step(CSM.ShifterInput.new(), 1.0, 0.016)
		_assert(CSM.is_legal(m.knob), "Legal on release")
		_assert(m.knob == CSM.gear_pos(CSM.Gear.G6), "Gear stays engaged on Shift release")
		_assert(absf(out.dilation - 0.04) < 1e-6, "Time dilation remains active while cruising")
	_assert(absf(m.fade - 0.85) < 0.01, "HUD stays persistently visible in gear")

	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.N), 1.0, 0.016)
	for _i in range(60):
		m.step(CSM.ShifterInput.new(true), 1.0, 0.016)
	_assert(m.knob == Vector2.ZERO, "Returned to Neutral")
	_assert(m.dilation == 1.0, "Dilation 1.0 in Neutral")

	for _i in range(60):
		m.step(CSM.ShifterInput.new(), 1.0, 0.016)
	_assert(m.knob == Vector2.ZERO, "Still Neutral")
	_assert(m.fade == 0.0, "Faded out in Neutral")

func test_10_stall_forces_neutral_and_locks_until_twenty_percent() -> void:
	_assert(CSM.stall_update(false, 0.0), "Stalls at 0")
	_assert(CSM.stall_update(true, 0.19), "Stays stalled at 0.19")
	_assert(not CSM.stall_update(true, 0.2), "Recovers at 0.20")
	_assert(not CSM.stall_update(false, 0.05), "Not stalled at 0.05 if not already stalled")
	_assert(CSM.stall_update(false, NAN), "NaN triggers stall")

	var m := CSM.ShifterModel.new()
	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G5), 1.0, 0.016)
	for _i in range(60):
		m.step(CSM.ShifterInput.new(true), 1.0, 0.016)
	_assert(m.dilation < 0.2, "In G5 slowmo")
	var out: CSM.ShiftOutput = m.step(CSM.ShifterInput.new(true), 0.0, 0.016)
	_assert(out.newly_stalled and m.stalled, "Newly stalled")
	_assert(out.dilation == 1.0, "Stall cuts dilation immediately")
	_assert(m.stall_flash > 0.9, "Stall flash active")
	for _i in range(60):
		var out2: CSM.ShiftOutput = m.step(
			CSM.ShifterInput.new(true, Vector2(0.0, -1.0), 3, CSM.Gear.G6),
			0.1,
			0.016
		)
		_assert(out2.dilation == 1.0, "Locked out while < 20%")
	_assert(m.knob == Vector2.ZERO, "Knob forced to Neutral")
	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G2), 0.25, 0.016)
	for _i in range(60):
		m.step(CSM.ShifterInput.new(true), 0.25, 0.016)
	_assert(not m.stalled, "Recovered from stall")
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G2), "Shifted to G2")

func test_11_drag_moves_knob_through_gate() -> void:
	var m := CSM.ShifterModel.new()
	for _i in range(20):
		m.step(CSM.ShifterInput.new(true, Vector2(-0.1, 0.0)), 1.0, 0.016)
	for _i in range(20):
		m.step(CSM.ShifterInput.new(true, Vector2(0.0, 0.1)), 1.0, 0.016)
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G1), "Dragged into G1")
	m.step(CSM.ShifterInput.new(true, Vector2(5.0, 0.0)), 1.0, 0.016)
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G1), "Sideways drag in slot blocked")

func test_12_fuzz_shifter_model_random_inputs() -> void:
	var rng := Rng.new(42)
	var m := CSM.ShifterModel.new()
	for i in range(2000):
		var held: bool = (rng.next_u32() % 10) != 0
		var drag: Vector2 = rng.delta() if (rng.next_u32() % 3 == 0) else Vector2.ZERO
		var wheel_steps: int = int(rng.next_u32() % 7) - 3
		var jump_to: int = int(rng.next_u32() % 7) if (rng.next_u32() % 8 == 0) else -1
		var input := CSM.ShifterInput.new(held, drag, wheel_steps, jump_to)
		var energy: float = 0.0 if (rng.next_u32() % 50 == 0) else absf(rng.unit())
		var dt: float = 1.0 / 60.0
		match rng.next_u32() % 5:
			0:
				dt = 0.0
			1:
				dt = 1.0
			2:
				dt = NAN
			_:
				dt = 1.0 / 60.0
		var out: CSM.ShiftOutput = m.step(input, energy, dt)
		_assert(CSM.is_legal(m.knob), "frame %d: knob legal" % i)
		_assert(is_finite(out.dilation) and out.dilation >= 0.04 and out.dilation <= 1.0, "dilation in bounds")
		_assert(m.fade >= 0.0 and m.fade <= 1.0, "fade in bounds")
		for wp in m.path:
			_assert(CSM.is_legal(wp), "path waypoint legal")

func test_13_readout_format() -> void:
	var m := CSM.ShifterModel.new()
	m.knob = CSM.gear_pos(CSM.Gear.G4)
	m.dilation = 0.24
	var accl := CSM.GearAcclimatization.new()
	accl.mastered_tier = 4
	accl.tolerance[4] = 1.0
	var text: String = CSM.readout_text(m, CSM.drain_for_dilation(0.24), 1.0, accl)
	_assert(text == "GEAR 4  ·  0.24x  ·  [MASTERED ✨]  ·  DRAIN 43/s", "Mastered readout format: " + text)

	var unmastered := CSM.GearAcclimatization.new()
	var burnout_str: String = CSM.readout_text(m, CSM.drain_for_dilation(0.24) * 10.5, 1.0, unmastered)
	_assert(burnout_str.contains("⚠️ BURNOUT"), "Burnout string contains warning")

	m.stalled = true
	_assert(CSM.readout_text(m, 0.0, 0.1, accl).begins_with("STALL"), "Stall string begins with STALL")

func test_14_energy_update_with_drain_helper() -> void:
	var s := CSM.ChronoShifterState.new()
	s.update_with_drain(43.0, 1.0)
	_assert(absf(s.energy_current - 57.0) < 1e-4, "Drained 43")
	s.update_with_drain(0.0, 1.0)
	_assert(absf(s.energy_current - (57.0 + s.energy_regen_rate)) < 1e-4, "Regenerated")
	s.update_with_drain(1000.0, 1.0)
	_assert(s.energy_current == 0.0, "Clamped at 0")
	s.update_with_drain(NAN, 1.0)
	_assert(is_finite(s.energy_current), "Finite after NaN drain")

func test_15_app_chrono_state_follows_shifter() -> void:
	var s := _make_test_shifter_state()
	_assert(not s.is_dilating, "Initially not dilating")

	_engage_gear(s, CSM.Gear.G4, 40)
	_assert(absf(s.slowmo_factor - 0.24) < 1e-4, "G4 slowmo_factor")
	_assert(s.is_dilating, "is_dilating in G4")
	_assert(absf(s.dilation_factor - 0.24) < 0.02, "smoothing converges")
	_assert(s.is_held() and s.aim_frozen(), "held and aim_frozen")
	_assert(absf(s.base_drain_per_sec - CSM.drain_for_dilation(0.24)) < 1e-3, "base_drain_per_sec")
	_assert(absf(s.drain_per_sec - CSM.drain_for_dilation(0.24) * 0.05) < 1e-3, "mastered drain_per_sec")
	_assert(s.energy_current < 100.0, "energy drained")

	# Wheel up two notches -> gear 6
	for _i in range(2):
		s.step_control(CSM.ShifterInput.new(true, Vector2.ZERO, 1, -1), 0.016)
	_run_frames(s, true, 40)
	_assert(absf(s.slowmo_factor - 0.04) < 1e-4, "Wheel up to G6")

	# Drag up 3 gate units -> out of slot 6 into slot 5
	s.step_control(CSM.ShifterInput.new(true, Vector2(0.0, 3.0)), 0.016)
	_run_frames(s, true, 30)
	_assert(absf(s.slowmo_factor - 0.12) < 1e-4, "Dragged into G5")

	s.energy_current = 100.0
	_run_frames(s, false, 60)
	_assert(absf(s.slowmo_factor - 0.12) < 1e-4, "Cruising in G5")
	_assert(s.is_dilating, "Still dilating on release")
	_assert(not s.is_held(), "Not held")
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G5), "Knob stays at G5")

	# Return to neutral
	_engage_gear(s, CSM.Gear.N, 60)
	_assert(s.slowmo_factor == 1.0, "Neutral slowmo_factor 1.0")
	_assert(not s.is_dilating, "Not dilating in Neutral")
	_assert(absf(s.dilation_factor - 1.0) < 0.01, "dilation_factor 1.0")
	_assert(s.model.knob == Vector2.ZERO, "Knob at ZERO")

func test_16_app_meter_drains_faster_in_higher_gears() -> void:
	var losses: Array[float] = []
	for g in [CSM.Gear.G1, CSM.Gear.G2, CSM.Gear.G4, CSM.Gear.G6]:
		var s := _make_test_shifter_state()
		_engage_gear(s, g, 40)
		s.energy_current = 100.0
		_run_frames(s, true, 30)
		losses.append(100.0 - s.energy_current)
	for i in range(losses.size() - 1):
		_assert(losses[i + 1] > losses[i], "drain strictly increases in higher gears")
	_assert(absf(losses[3] - CSM.drain_for_dilation(0.04) * 0.05 * 0.48) < 1.0, "G6 mastered drain matches formula")

func test_17_app_meter_stalls_at_zero() -> void:
	var s := _make_test_shifter_state()
	_engage_gear(s, CSM.Gear.G6, 40)
	s.energy_current = 0.2
	_run_frames(s, true, 10)
	_assert(s.model.stalled, "Stalled at 0 energy")
	_run_frames(s, true, 30)
	_assert(not s.is_dilating, "Not dilating when stalled")
	_assert(s.slowmo_factor == 1.0, "slowmo_factor 1.0 when stalled")
	_assert(s.model.knob == Vector2.ZERO, "Knob at ZERO when stalled")
	_assert(s.energy_current >= 0.0 and s.energy_current < 20.0, "Energy regenerating below 20%")

	# Locked out below 20%
	s.step_control(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G6), 0.016)
	_run_frames(s, true, 20)
	_assert(not s.is_dilating, "Still locked out below 20%")

	# Recharge above 20% -> shifting works again
	s.energy_current = 30.0
	_engage_gear(s, CSM.Gear.G3, 40)
	_assert(absf(s.slowmo_factor - 0.38) < 1e-4, "Shifted to G3 after recovery")

func test_18_adversarial_floating_point_precision_traps() -> void:
	var neg_zero: float = -0.0
	var test_floats: Array[float] = [
		neg_zero,
		0.0,
		1e-45,
		-1e-45,
		1e-38,
		-1e-38,
		NAN,
		INF,
		-INF,
		1.17549435e-38,
		-1.17549435e-38,
	]
	_assert(CSM.nearest_column(neg_zero) == 0.0, "nearest_column normalizes -0.0")
	_assert(CSM.exact_column(neg_zero) == 0.0, "exact_column -0.0 is 0.0")

	for fx in test_floats:
		for fy in test_floats:
			var p := Vector2(fx, fy)
			var proj: Vector2 = CSM.project_legal(p)
			_assert(CSM.is_legal(proj), "project_legal legal for extreme float")
			_assert(is_finite(proj.x) and is_finite(proj.y), "project_legal finite")

			var d: float = CSM.dilation_at(p)
			_assert(is_finite(d) and d >= CSM.GEAR_DILATIONS[6] and d <= 1.0, "dilation_at valid")

			var eng: float = CSM.engagement(p)
			_assert(is_finite(eng) and eng >= 0.0 and eng <= 1.0, "engagement valid")

			var target: Vector2 = CSM.detent_target(p)
			_assert(CSM.is_legal(target), "detent_target legal")

			var stepped: Vector2 = CSM.detent_step(p, fy)
			_assert(CSM.is_legal(stepped), "detent_step legal")

		var drain: float = CSM.drain_for_dilation(fx)
		_assert(is_finite(drain) and drain >= 0.0 and drain <= CSM.MAX_DRAIN, "drain_for_dilation valid")

		var m_drain: float = CSM.meter_drain(fx)
		_assert(is_finite(m_drain) and m_drain >= 0.0, "meter_drain valid")

		var _s1: bool = CSM.stall_update(false, fx)
		var _s2: bool = CSM.stall_update(true, fx)

	var corrupted_model := CSM.ShifterModel.new()
	corrupted_model.knob = Vector2(neg_zero, neg_zero)
	corrupted_model.dilation = NAN
	var accl := CSM.GearAcclimatization.new()
	var txt: String = CSM.readout_text(corrupted_model, NAN, NAN, accl)
	_assert(not txt.is_empty(), "readout_text non-empty on NaNs")

func test_19_adversarial_rapid_opposing_inputs_anti_tunneling() -> void:
	for g in [
		CSM.Gear.G1,
		CSM.Gear.G2,
		CSM.Gear.G3,
		CSM.Gear.G4,
		CSM.Gear.G5,
		CSM.Gear.G6
	]:
		var p: Vector2 = CSM.gear_pos(g)
		_assert(CSM.constrain_step(p, Vector2(8.0, 0.0)) == p, "Slot wall +8")
		_assert(CSM.constrain_step(p, Vector2(-8.0, 0.0)) == p, "Slot wall -8")
		_assert(CSM.constrain_step(p, Vector2(1e6, 0.0)) == p, "Slot wall +1e6")
		_assert(CSM.constrain_step(p, Vector2(-1e6, 0.0)) == p, "Slot wall -1e6")

	for off_x in [-0.7, -0.5, -0.3, 0.3, 0.5, 0.7]:
		var p := Vector2(off_x, 0.0)
		var up: Vector2 = CSM.constrain_step(p, Vector2(0.0, 8.0))
		_assert(absf(up.x - off_x) < 1e-6 and up.y <= CSM.RAIL_TOL + 1e-6, "Rail upper wall")
		var down: Vector2 = CSM.constrain_step(p, Vector2(0.0, -8.0))
		_assert(absf(down.x - off_x) < 1e-6 and down.y >= -CSM.RAIL_TOL - 1e-6, "Rail lower wall")

	var m := CSM.ShifterModel.new()
	m.knob = CSM.gear_pos(CSM.Gear.G1)
	var opposing_shoves: Array[Vector2] = [
		Vector2(8.0, 8.0),
		Vector2(-8.0, -8.0),
		Vector2(8.0, -8.0),
		Vector2(-8.0, 8.0),
		Vector2(1e6, -1e6),
		Vector2(-1e6, 1e6),
		Vector2(0.0, -100.0),
		Vector2(100.0, 0.0),
		Vector2(-100.0, 0.0),
		Vector2(0.0, 100.0),
	]
	for i in range(1000):
		var shove: Vector2 = opposing_shoves[i % opposing_shoves.size()]
		var out: CSM.ShiftOutput = m.step(CSM.ShifterInput.new(true, shove), 1.0, 0.016)
		_assert(CSM.is_legal(m.knob), "Rapid opposing shove legal at step %d" % i)
		_assert(is_finite(out.dilation) and out.dilation >= 0.04 and out.dilation <= 1.0, "Rapid shove dilation valid")

func test_20_adversarial_meter_depletion_and_recovery_hysteresis() -> void:
	var m := CSM.ShifterModel.new()
	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G6), 1.0, 0.016)
	for _i in range(50):
		m.step(CSM.ShifterInput.new(true), 1.0, 0.016)
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G6), "At G6")

	var out: CSM.ShiftOutput = m.step(CSM.ShifterInput.new(true), 0.0, 0.016)
	_assert(m.stalled and out.newly_stalled, "Stalled on empty")
	_assert(out.dilation == 1.0, "Dilation cut to 1.0")
	_assert(CSM.meter_drain(out.dilation) == 0.0, "Drain halted")

	for _i in range(30):
		var out_locked: CSM.ShiftOutput = m.step(
			CSM.ShifterInput.new(true, Vector2(0.0, -5.0), 5, CSM.Gear.G6),
			0.10,
			0.016
		)
		_assert(m.stalled and out_locked.dilation == 1.0, "Stays locked at 10%")

	for _i in range(40):
		m.step(CSM.ShifterInput.new(true), 0.15, 0.016)
	_assert(m.knob == Vector2.ZERO, "Returned to Neutral while stalled")

	var out_rec: CSM.ShiftOutput = m.step(CSM.ShifterInput.new(true), 0.21, 0.016)
	_assert(not m.stalled and not out_rec.newly_stalled, "Clears stall at 21%")

	m.step(CSM.ShifterInput.new(true, Vector2.ZERO, 0, CSM.Gear.G3), 0.50, 0.016)
	for _i in range(50):
		m.step(CSM.ShifterInput.new(true), 0.50, 0.016)
	_assert(m.knob == CSM.gear_pos(CSM.Gear.G3), "Re-engaged G3")
	_assert(absf(m.dilation - 0.38) < 1e-4, "G3 dilation active")

func test_21_adversarial_camera_shake_overflow_and_audio_edges() -> void:
	var s := _make_test_shifter_state()
	for _i in range(1000):
		s.trigger_shake(100.0)
		_assert(s.screen_shake <= 20.0, "Screen shake capped at 20.0")
	for _i in range(120):
		s.update_chrono(0.016)
		_assert(is_finite(s.shake_offset.x) and is_finite(s.shake_offset.y), "shake_offset finite")
		_assert(s.shake_offset.length() <= 20.0 + 1e-3, "shake_offset bounded")
	_assert(s.screen_shake == 0.0 and s.shake_offset == Vector2.ZERO, "Shake decayed to zero")

	var s2 := _make_test_shifter_state()
	_assert(s2.dilation_edge == null, "Initially no dilation_edge")
	_engage_gear(s2, CSM.Gear.G4, 40)
	_assert(s2.dilation_edge == null, "dilation_edge cleared after transition")
	_run_frames(s2, false, 30)
	_assert(s2.dilation_edge == null, "dilation_edge remains null while cruising")

func test_22_adversarial_scheduling_order_and_concurrent_inputs() -> void:
	var s := _make_test_shifter_state()
	for frame in range(60):
		var jump_g: int = CSM.Gear.G5 if (frame % 2 == 0) else -1
		var drag := Vector2(10.0, 10.0) / CSM.DRAG_PX_PER_UNIT
		s.step_control(CSM.ShifterInput.new(true, drag, 1, jump_g), 0.016, Vector2(120.0, -40.0))
		_assert(s.model.fade >= 0.0 and s.model.fade <= 1.0, "fade valid")
		_assert(CSM.is_legal(s.model.knob), "knob legal")

	s.energy_current = 100.0
	_run_frames(s, false, 40)
	_assert(not s.is_held(), "Not held")
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G6), "Settled in G6")

	_engage_gear(s, CSM.Gear.N, 40)
	_assert(s.model.knob == Vector2.ZERO and s.model.dilation == 1.0, "Returned to N")

func test_23_adversarial_warp_and_shift_energy_starvation() -> void:
	var s := _make_test_shifter_state()
	_engage_gear(s, CSM.Gear.G6, 40)
	_assert(absf(s.slowmo_factor - 0.04) < 1e-4, "In G6")

	s.energy_current = 25.1
	s.frozen_aim = Vector2(200.0, 0.0)
	_assert(s.consume_teleport(), "Consumed 25.0 warp energy")
	_run_frames(s, true, 5)
	_assert(s.model.stalled, "Shifter stalled when energy starved from warp + drain")
	_assert(s.slowmo_factor == 1.0, "Slowmo cut to 1.0")
	_assert(not s.can_teleport(), "Cannot warp while stalled/depleted")

func test_24_gear_acclimatization_flawless_progression_and_mastery() -> void:
	var accl := CSM.GearAcclimatization.new()
	_assert(accl.mastered_tier == 0, "Initial mastered_tier 0")
	_assert(not accl.is_mastered(CSM.Gear.G1), "G1 not mastered")
	_assert(accl.burnout_multiplier(CSM.Gear.G1) == 1.0, "G1 has 1.0x baseline drain")

	_assert(not accl.on_flawless_kill(CSM.Gear.G1, 1), "1st kill in G1")
	_assert(accl.mastered_tier == 0, "Still tier 0")
	_assert(absf(accl.tolerance[1] - 0.5) < 1e-4, "50% tolerance")
	_assert(accl.flawless_streak == 1, "Streak 1")
	_assert(accl.burnout_multiplier(CSM.Gear.G1) == 1.0, "Still 1.0x")

	_assert(accl.on_flawless_kill(CSM.Gear.G1, 1), "2nd kill masters G1")
	_assert(accl.mastered_tier == 1, "Tier 1 mastered")
	_assert(accl.is_mastered(CSM.Gear.G1), "G1 is_mastered")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G1) - 0.05) < 1e-6, "Mastered G1 has 0.05x drain")
	_assert(accl.flawless_streak == 2, "Streak 2")
	_assert(accl.feedback_banner.contains("GEAR 1 MASTERED"), "Feedback banner G1 mastered")

	_assert(accl.burnout_multiplier(CSM.Gear.G2) == 1.0, "G2 now has 1.0x drain")
	_assert(not accl.on_flawless_kill(CSM.Gear.G2, 1), "G2 kill 1")
	_assert(not accl.on_flawless_kill(CSM.Gear.G2, 1), "G2 kill 2")
	_assert(accl.on_flawless_kill(CSM.Gear.G2, 1), "G2 kill 3 masters G2")
	_assert(accl.mastered_tier == 2 and accl.is_mastered(CSM.Gear.G2), "G2 mastered")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G2) - 0.05) < 1e-6, "G2 has 0.05x drain")

func test_25_gear_acclimatization_miss_penalty_and_streak_reset() -> void:
	var accl := CSM.GearAcclimatization.new()
	accl.on_flawless_kill(CSM.Gear.G1, 2)
	_assert(accl.mastered_tier == 1, "Tier 1")

	accl.on_flawless_kill(CSM.Gear.G2, 1)
	_assert(accl.flawless_streak == 3, "Streak 3")
	var tol_before: float = accl.tolerance[2]
	_assert(absf(tol_before - 0.3333) < 0.01, "G2 tolerance ~0.333")

	accl.on_miss(CSM.Gear.G2, false)
	_assert(accl.flawless_streak == 0, "Streak reset on slash miss")
	_assert(accl.tolerance[2] < tol_before, "Tolerance penalized")
	_assert(accl.feedback_banner.contains("SLASH MISSED"), "Banner SLASH MISSED")

	accl.on_miss(CSM.Gear.G2, false)
	_assert(accl.tolerance[2] == 0.0, "Tolerance clamped at 0.0")

	accl.on_flawless_kill(CSM.Gear.G2, 2)
	_assert(absf(accl.tolerance[2] - 0.6666) < 0.01, "Rebuilt to 0.666")

	accl.on_miss(CSM.Gear.G2, true)
	_assert(accl.flawless_streak == 0, "Streak reset on warp miss")
	_assert(absf(accl.tolerance[2] - 0.2666) < 0.01, "Penalized by 0.40")
	_assert(accl.feedback_banner.contains("WARP MISSED"), "Banner WARP MISSED")

	accl.on_damage(CSM.Gear.G2)
	_assert(accl.flawless_streak == 0, "Streak reset on damage")
	_assert(absf(accl.tolerance[2] - 0.0666) < 0.01, "Penalized by 0.20")
	_assert(accl.feedback_banner.contains("HIT TAKEN"), "Banner HIT TAKEN")

	var g1_before: float = accl.tolerance[1]
	accl.on_miss(CSM.Gear.G1, false)
	accl.on_miss(CSM.Gear.G1, true)
	accl.on_damage(CSM.Gear.G1)
	_assert(accl.tolerance[1] == g1_before and accl.is_mastered(CSM.Gear.G1), "Mastered gear immune")

func test_26_burnout_multiplier_consecutive_vs_skipped_gears() -> void:
	var accl := CSM.GearAcclimatization.new()
	_assert(accl.burnout_multiplier(CSM.Gear.G1) == 1.0, "G1 1.0x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G2) - 6.5) < 1e-4, "G2 6.5x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G3) - 8.5) < 1e-4, "G3 8.5x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G4) - 10.5) < 1e-4, "G4 10.5x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G5) - 12.5) < 1e-4, "G5 12.5x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G6) - 14.5) < 1e-4, "G6 14.5x")

	var base_g6: float = CSM.drain_for_dilation(0.04)
	var burnout_drain: float = base_g6 * accl.burnout_multiplier(CSM.Gear.G6)
	_assert(burnout_drain > 1000.0, "Unmastered G6 drain > 1000/s")

	accl.on_flawless_kill(CSM.Gear.G1, 2)
	_assert(accl.mastered_tier == 1, "M1")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G1) - 0.05) < 1e-4, "G1 0.05x")
	_assert(accl.burnout_multiplier(CSM.Gear.G2) == 1.0, "G2 1.0x")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G3) - 5.7) < 1e-4, "G3 lowered to 5.7x")

	accl.on_flawless_kill(CSM.Gear.G2, 3)
	_assert(accl.mastered_tier == 2, "M2")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G2) - 0.05) < 1e-4, "G2 0.05x")
	var g3_mult: float = accl.burnout_multiplier(CSM.Gear.G3)
	var g3_drain: float = CSM.drain_for_dilation(CSM.gear_dilation(CSM.Gear.G3)) * g3_mult
	var g2_init_drain: float = CSM.drain_for_dilation(CSM.gear_dilation(CSM.Gear.G2))
	_assert(absf(g3_drain - g2_init_drain) < 1e-4, "G3 drain at M2 equals G2 initial drain")
	_assert(g3_mult <= 1.0, "G3 does not burn out at M2")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G4) - 4.9) < 1e-4, "G4 lowered to 4.9x")

	accl.on_flawless_kill(CSM.Gear.G6, 10)
	_assert(accl.tolerance[6] <= 0.50, "Skipped gear tolerance capped at 0.50")
	_assert(accl.mastered_tier == 2, "Cannot skip prerequisite gears")
	_assert(accl.feedback_banner.contains("MASTER G5 FIRST"), "Feedback banner MASTER G5 FIRST")

func test_27_app_gear_persists_across_shift_presses_and_changes() -> void:
	var s := _make_test_shifter_state()
	_engage_gear(s, CSM.Gear.G2, 30)
	_assert(absf(s.slowmo_factor - 0.55) < 1e-4, "G2 slowmo")

	s.energy_current = 100.0
	_run_frames(s, false, 30)
	_assert(absf(s.slowmo_factor - 0.55) < 1e-4 and s.is_dilating, "Persists in G2 on release")
	_assert(not s.is_held() and s.model.knob == CSM.gear_pos(CSM.Gear.G2), "Knob stays in G2")

	_run_frames(s, true, 20)
	_assert(s.is_held() and s.model.knob == CSM.gear_pos(CSM.Gear.G2), "Holding Shift again keeps G2")

	_run_frames(s, false, 20)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G2), "Releasing again keeps G2")

	_engage_gear(s, CSM.Gear.G4, 30)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G4), "Changed to G4")

	s.energy_current = 100.0
	_run_frames(s, false, 30)
	_assert(absf(s.slowmo_factor - 0.24) < 1e-4 and s.model.knob == CSM.gear_pos(CSM.Gear.G4), "Stays in G4")

	s.energy_current = 0.0
	_run_frames(s, false, 10)
	_assert(s.model.stalled and s.model.knob == Vector2.ZERO and s.slowmo_factor == 1.0, "Empty energy stalls to Neutral")

func test_28_hold_shift_move_to_1st_release_shift_maintains_1st() -> void:
	var s := _make_test_shifter_state()
	_engage_gear(s, CSM.Gear.G1, 30)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G1), "In G1")
	_assert(absf(s.slowmo_factor - 0.75) < 1e-4 and s.is_dilating, "G1 dilation")

	_run_frames(s, false, 60)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G1), "Maintains G1 on release")
	_assert(not s.is_held(), "Not held")
	_assert(absf(s.model.fade - 0.85) < 0.02, "Cruising fade 0.85")
	_assert(absf(s.slowmo_factor - 0.75) < 1e-4 and s.is_dilating, "Dilation remains 0.75")

func test_29_drag_diagonal_to_1st_maintains_1st() -> void:
	var s := _make_test_shifter_state()
	for _i in range(15):
		var drag := Vector2(-20.0, 20.0) / CSM.DRAG_PX_PER_UNIT
		s.step_control(CSM.ShifterInput.new(true, drag), 0.016)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G1), "Diagonal drag reached G1")
	_run_frames(s, false, 30)
	_assert(s.model.knob == CSM.gear_pos(CSM.Gear.G1), "Maintains G1 after diagonal drag release")
	_assert(absf(s.slowmo_factor - 0.75) < 1e-4 and s.is_dilating, "G1 slowmo active")

func test_30_mastery_near_zero_and_gear3_matches_gear2_initial_drain_positive_proof() -> void:
	var accl := CSM.GearAcclimatization.new()
	_assert(accl.burnout_multiplier(CSM.Gear.N) == 1.0, "N 1.0")
	_assert(accl.burnout_multiplier(CSM.Gear.G1) == 1.0, "G1 1.0")
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G2) - 6.5) < 1e-4, "G2 6.5")

	accl.mastered_tier = 1
	accl.tolerance[1] = 1.0
	_assert(absf(accl.burnout_multiplier(CSM.Gear.G1) - 0.05) < 1e-4, "G1 0.05")
	var g2_initial_drain: float = CSM.drain_for_dilation(CSM.gear_dilation(CSM.Gear.G2)) * accl.burnout_multiplier(CSM.Gear.G2)

	accl.mastered_tier = 2
	accl.tolerance[2] = 1.0
	var g3_mult: float = accl.burnout_multiplier(CSM.Gear.G3)
	var g3_drain: float = CSM.drain_for_dilation(CSM.gear_dilation(CSM.Gear.G3)) * g3_mult
	_assert(absf(g3_drain - g2_initial_drain) < 1e-4, "G3 drain matches G2 initial drain")
	_assert(g3_mult <= 1.0, "G3 no burnout at M2")

	for gear in [CSM.Gear.G4, CSM.Gear.G5, CSM.Gear.G6]:
		var previous_burnout: float = 999.0
		var a := CSM.GearAcclimatization.new()
		for tier in range(gear - 1):
			a.mastered_tier = tier
			var mult: float = a.burnout_multiplier(gear)
			_assert(mult < previous_burnout, "Burnout strictly decreases as tier increases")
			previous_burnout = mult

# ---------------------------------------------------------------------------------------------
# New OUT OF TIME Spec Tests (31 - 35)
# ---------------------------------------------------------------------------------------------

func test_31_reverse_gear_and_turbo_shifter_overdrive_and_knockdown() -> void:
	# 1. Reverse Gear (R): accessible via jump_to = Gear.R while holding Shift
	var s := _make_test_shifter_state()
	_engage_gear(s, CSM.Gear.R, 40)
	_assert(s.model.get_active_gear() == CSM.Gear.R, "Active gear is Reverse (R)")
	_assert(absf(s.slowmo_factor - 0.90) < 1e-4, "Reverse gear dilation is 0.90")
	var r_readout: String = CSM.readout_text(s.model, s.drain_per_sec, s.energy_frac, s.acclimatization)
	_assert(r_readout.begins_with("GEAR R"), "Readout displays GEAR R: " + r_readout)

	# Taking damage in Reverse Gear triggers insta-death!
	var knocked_from_r: int = s.apply_damage_knockdown()
	_assert(s.acclimatization.reverse_insta_death, "Reverse gear damage triggers insta-death")
	_assert(knocked_from_r == CSM.Gear.N, "Knocked to Neutral on Reverse insta-death")

	# 2. Turbo Shifter Overdrive in Gear 5 / Gear 6:
	var s2 := _make_test_shifter_state()
	_engage_gear(s2, CSM.Gear.G5, 40)
	_assert(s2.acclimatization.is_turbo_active(CSM.Gear.G5), "Turbo active in G5 before overheat")
	_assert(absf(s2.acclimatization.get_turbo_speed_multiplier(CSM.Gear.G5) - 1.35) < 1e-4, "Turbo grants 1.35x speed boost")
	var base_mult_before: float = s2.acclimatization.burnout_multiplier(CSM.Gear.G5)

	# Sustain Gear 5 for > 6.0s -> triggers turbo_overheated debuff (2.5x drain)
	for _i in range(70):
		s2.acclimatization.tick(0.1, CSM.Gear.G5)
	_assert(s2.acclimatization.turbo_overheated, "Turbo overheated after > 6.0s in Gear 5")
	_assert(not s2.acclimatization.is_turbo_active(CSM.Gear.G5), "Turbo boost disabled when overheated")
	var overheated_mult: float = s2.acclimatization.burnout_multiplier(CSM.Gear.G5)
	_assert(absf(overheated_mult - base_mult_before * 2.5) < 1e-4, "Overheat multiplies drain by 2.5x")

	# Shifting down to Gear 2 clears turbo overheat
	s2.acclimatization.tick(0.1, CSM.Gear.G2)
	_assert(not s2.acclimatization.turbo_overheated and s2.acclimatization.turbo_overuse_timer == 0.0, "Shifting down clears overheat")

	# 3. Damage Knockdown from Gear 2..6 -> knocks down to Gear 1
	_engage_gear(s2, CSM.Gear.G6, 40)
	_assert(s2.model.get_active_gear() == CSM.Gear.G6, "In G6 before hit")
	var knocked_gear: int = s2.apply_damage_knockdown()
	_assert(knocked_gear == CSM.Gear.G1, "Hit in G6 knocks down to G1")
	_assert(s2.model.get_active_gear() == CSM.Gear.G1, "Active gear is now G1")
	_assert(absf(s2.slowmo_factor - 0.75) < 1e-4, "Dilation knocked to G1 (0.75)")

func test_32_timeline_switching_at_chronos_wells_preserving_velocity() -> void:
	var ts := TS.TimelineState.new()
	ts.setup_horde_arena()
	_assert(ts.current_era == TS.TimelineEra.PRESENT, "Starts in PRESENT")

	var well_pos := Vector2(-300.0, -120.0)
	var near_well: TS.ChronosWellData = ts.is_near_chronos_well(well_pos + Vector2(20.0, 0.0))
	_assert(near_well != null and near_well.id == "well_arena_left", "Detected nearby Chronos Well")

	# Far from any Chronos Well with require_well = true -> shift blocked
	var blocked_res: Dictionary = ts.try_shift_timeline(Vector2(0.0, 500.0), -1, true, Vector2(320.0, -140.0))
	_assert(not blocked_res["shifted"], "Shift blocked when require_well=true and far from well")

	# At Chronos Well: cycle PRESENT -> FUTURE -> PAST -> PRESENT while preserving velocity
	var player_vel := Vector2(340.0, 420.0)
	var res1: Dictionary = ts.try_shift_timeline(well_pos, -1, true, player_vel)
	_assert(res1["shifted"], "Shifted at Chronos Well")
	_assert(res1["new_era"] == TS.TimelineEra.FUTURE, "PRESENT -> FUTURE")
	_assert(res1["preserved_velocity"] == player_vel, "Player velocity preserved across shift")
	_assert(res1["checkpoint_updated"] and ts.checkpoint_pos == well_pos, "Checkpoint updated to well")

	var res2: Dictionary = ts.try_shift_timeline(well_pos, -1, true, player_vel)
	_assert(res2["new_era"] == TS.TimelineEra.PAST, "FUTURE -> PAST")

	var res3: Dictionary = ts.try_shift_timeline(well_pos, -1, true, player_vel)
	_assert(res3["new_era"] == TS.TimelineEra.PRESENT, "PAST -> PRESENT")

func test_33_phase_traversal_scenarios_missing_platforms_laser_phasing_momentum_chaining() -> void:
	var ts := TS.TimelineState.new()
	ts.setup_campaign_traversal()
	_assert(ts.mode == TS.GameMode.CAMPAIGN_TRAVERSAL, "Campaign Traversal mode active")

	# Scenario 1: Missing Platforms (Pit at x = 300, y = -200)
	ts.try_shift_timeline(Vector2.ZERO, TS.TimelineEra.PRESENT, false)
	var present_bridge_found: bool = false
	for p in ts.get_active_platforms():
		if p.contains_x(300.0):
			present_bridge_found = true
	_assert(not present_bridge_found, "Bridge at x=300 is collapsed/missing in PRESENT")

	ts.try_shift_timeline(Vector2.ZERO, TS.TimelineEra.PAST, false)
	var past_bridge_found: bool = false
	for p in ts.get_active_platforms():
		if p.contains_x(300.0):
			past_bridge_found = true
	_assert(past_bridge_found, "Stone bridge at x=300 is intact in PAST")

	# Scenario 2: Hazard Phasing (Future vertical laser grid at x = 850)
	var laser_pos := Vector2(850.0, -150.0)
	ts.try_shift_timeline(laser_pos, TS.TimelineEra.FUTURE, false)
	_assert(ts.check_laser_hazard(laser_pos, false), "Laser grid at x=850 is lethal in FUTURE")
	_assert(not ts.check_laser_hazard(laser_pos, true), "Invulnerable dash bypasses laser")
	ts.try_shift_timeline(laser_pos, TS.TimelineEra.PRESENT, false)
	_assert(not ts.check_laser_hazard(laser_pos, false), "Laser grid becomes harmless drywall in PRESENT")

	# Scenario 3: Momentum Chaining (Future JumpPad -> Past Vine -> Present Catwalk)
	var pad_pos := Vector2(1250.0, -200.0)
	ts.try_shift_timeline(pad_pos, TS.TimelineEra.FUTURE, false)
	var boost: Vector2 = ts.check_jump_pad(pad_pos, 0.0)
	_assert(boost.y >= 800.0, "Future energy jump pad launches player upward")

	var vine_pos := Vector2(1350.0, 80.0)
	ts.try_shift_timeline(vine_pos, TS.TimelineEra.PAST, false, boost)
	var vine: TS.VineClimbData = ts.check_vine_grab(vine_pos)
	_assert(vine != null, "Snagged hanging vine mid-flight in PAST")

	ts.try_shift_timeline(Vector2(1550.0, 120.0), TS.TimelineEra.PRESENT, false)
	var catwalk_found: bool = false
	for p in ts.get_active_platforms():
		if p.contains_x(1550.0) and absf(p.y - 120.0) < 1e-3:
			catwalk_found = true
	_assert(catwalk_found, "Landed on high steel catwalk in PRESENT")

func test_34_chrono_echo_creation_decay_and_detonation() -> void:
	var ts := TS.TimelineState.new()
	ts.setup_horde_arena()

	# Spawn a slash echo in PRESENT and a dash echo in PAST
	var echo1: TS.ChronoEchoData = ts.spawn_chrono_echo(
		Vector2(100.0, -150.0),
		Vector2(1.0, 0.0),
		TS.TimelineEra.PRESENT,
		"slash"
	)
	var echo2: TS.ChronoEchoData = ts.spawn_chrono_echo(
		Vector2(-120.0, -150.0),
		Vector2(-1.0, 0.0),
		TS.TimelineEra.PAST,
		"dash"
	)
	_assert(absf(echo1.timer - 3.0) < 1e-4 and ts.echoes.size() == 2, "2 echoes active with 3.0s timer")

	# Shift to FUTURE, tick 1.0s
	ts.try_shift_timeline(Vector2.ZERO, TS.TimelineEra.FUTURE, false)
	ts.tick(1.0)
	_assert(absf(echo1.timer - 2.0) < 1e-4, "Echo timer decayed to 2.0s")

	# Shift back to PRESENT -> detonates echo1!
	var shift_res: Dictionary = ts.try_shift_timeline(Vector2.ZERO, TS.TimelineEra.PRESENT, false)
	var detonated: Array = shift_res["detonated_echoes"]
	_assert(detonated.size() == 1 and detonated[0] == echo1, "Shifting back to PRESENT detonated echo1")
	_assert(ts.echoes.size() == 1 and ts.echoes[0] == echo2, "Only echo2 remains waiting in PAST")

	# Tick 2.5s so echo2 expires naturally (> 3.0s total)
	ts.tick(2.5)
	_assert(ts.echoes.is_empty(), "echo2 expired after 3.0s lifetime")

func test_35_lore_glyph_collection_in_timeline_pockets() -> void:
	var ts := TS.TimelineState.new()
	ts.setup_campaign_traversal()
	_assert(ts.lore_glyphs.size() == 3, "3 Lore Glyphs placed in campaign traversal pockets")

	# Glyph 1 is at (300, -170) in PAST
	var g1_pos := Vector2(300.0, -170.0)
	ts.try_shift_timeline(g1_pos, TS.TimelineEra.PRESENT, false)
	_assert(ts.check_lore_glyphs(g1_pos).is_empty(), "Cannot collect PAST glyph while in PRESENT")

	ts.try_shift_timeline(g1_pos, TS.TimelineEra.PAST, false)
	var collected_past: Array[TS.LoreGlyphData] = ts.check_lore_glyphs(g1_pos)
	_assert(collected_past.size() == 1 and collected_past[0].id == "glyph_past_bridge", "Collected PAST Lore Glyph")
	_assert(ts.check_lore_glyphs(g1_pos).is_empty(), "Cannot collect same glyph twice")

	# Collect remaining 2 glyphs in PRESENT and FUTURE
	var g2_pos := Vector2(850.0, -170.0)
	ts.try_shift_timeline(g2_pos, TS.TimelineEra.PRESENT, false)
	_assert(ts.check_lore_glyphs(g2_pos).size() == 1, "Collected PRESENT Lore Glyph")

	var g3_pos := Vector2(1550.0, 150.0)
	ts.try_shift_timeline(g3_pos, TS.TimelineEra.FUTURE, false)
	_assert(ts.check_lore_glyphs(g3_pos).size() == 1, "Collected FUTURE Lore Glyph")

func _run_test(name_str: String, fn: Callable) -> void:
	_tests_run += 1
	fn.call()
	_tests_passed += 1
	print("  [PASS] %s" % name_str)

func _init() -> void:
	print("=== Running Chronos Shift & Timeline System Test Suite ===")
	_run_test("01_gear_positions_are_legal_and_dilations_strictly_decrease", test_01_gear_positions_are_legal_and_dilations_strictly_decrease)
	_run_test("02_fuzz_constrain_step_always_legal_and_never_tunnels", test_02_fuzz_constrain_step_always_legal_and_never_tunnels)
	_run_test("03_huge_deltas_cannot_tunnel_through_walls", test_03_huge_deltas_cannot_tunnel_through_walls)
	_run_test("04_detent_seats_into_gear_and_rail", test_04_detent_seats_into_gear_and_rail)
	_run_test("05_engagement_is_monotonic_and_bounded", test_05_engagement_is_monotonic_and_bounded)
	_run_test("06_drain_mapping_monotonic_and_matches_table", test_06_drain_mapping_monotonic_and_matches_table)
	_run_test("07_planned_paths_are_legal_and_reach_target", test_07_planned_paths_are_legal_and_reach_target)
	_run_test("08_wheel_shifts_are_sequential_and_legal", test_08_wheel_shifts_are_sequential_and_legal)
	_run_test("09_gear_persists_on_release_and_manual_neutral_return", test_09_gear_persists_on_release_and_manual_neutral_return)
	_run_test("10_stall_forces_neutral_and_locks_until_twenty_percent", test_10_stall_forces_neutral_and_locks_until_twenty_percent)
	_run_test("11_drag_moves_knob_through_gate", test_11_drag_moves_knob_through_gate)
	_run_test("12_fuzz_shifter_model_random_inputs", test_12_fuzz_shifter_model_random_inputs)
	_run_test("13_readout_format", test_13_readout_format)
	_run_test("14_energy_update_with_drain_helper", test_14_energy_update_with_drain_helper)
	_run_test("15_app_chrono_state_follows_shifter", test_15_app_chrono_state_follows_shifter)
	_run_test("16_app_meter_drains_faster_in_higher_gears", test_16_app_meter_drains_faster_in_higher_gears)
	_run_test("17_app_meter_stalls_at_zero", test_17_app_meter_stalls_at_zero)
	_run_test("18_adversarial_floating_point_precision_traps", test_18_adversarial_floating_point_precision_traps)
	_run_test("19_adversarial_rapid_opposing_inputs_anti_tunneling", test_19_adversarial_rapid_opposing_inputs_anti_tunneling)
	_run_test("20_adversarial_meter_depletion_and_recovery_hysteresis", test_20_adversarial_meter_depletion_and_recovery_hysteresis)
	_run_test("21_adversarial_camera_shake_overflow_and_audio_edges", test_21_adversarial_camera_shake_overflow_and_audio_edges)
	_run_test("22_adversarial_scheduling_order_and_concurrent_inputs", test_22_adversarial_scheduling_order_and_concurrent_inputs)
	_run_test("23_adversarial_warp_and_shift_energy_starvation", test_23_adversarial_warp_and_shift_energy_starvation)
	_run_test("24_gear_acclimatization_flawless_progression_and_mastery", test_24_gear_acclimatization_flawless_progression_and_mastery)
	_run_test("25_gear_acclimatization_miss_penalty_and_streak_reset", test_25_gear_acclimatization_miss_penalty_and_streak_reset)
	_run_test("26_burnout_multiplier_consecutive_vs_skipped_gears", test_26_burnout_multiplier_consecutive_vs_skipped_gears)
	_run_test("27_app_gear_persists_across_shift_presses_and_changes", test_27_app_gear_persists_across_shift_presses_and_changes)
	_run_test("28_hold_shift_move_to_1st_release_shift_maintains_1st", test_28_hold_shift_move_to_1st_release_shift_maintains_1st)
	_run_test("29_drag_diagonal_to_1st_maintains_1st", test_29_drag_diagonal_to_1st_maintains_1st)
	_run_test("30_mastery_near_zero_and_gear3_matches_gear2_initial_drain_positive_proof", test_30_mastery_near_zero_and_gear3_matches_gear2_initial_drain_positive_proof)
	_run_test("31_reverse_gear_and_turbo_shifter_overdrive_and_knockdown", test_31_reverse_gear_and_turbo_shifter_overdrive_and_knockdown)
	_run_test("32_timeline_switching_at_chronos_wells_preserving_velocity", test_32_timeline_switching_at_chronos_wells_preserving_velocity)
	_run_test("33_phase_traversal_scenarios_missing_platforms_laser_phasing_momentum_chaining", test_33_phase_traversal_scenarios_missing_platforms_laser_phasing_momentum_chaining)
	_run_test("34_chrono_echo_creation_decay_and_detonation", test_34_chrono_echo_creation_decay_and_detonation)
	_run_test("35_lore_glyph_collection_in_timeline_pockets", test_35_lore_glyph_collection_in_timeline_pockets)

	print("=== ALL %d/%d TESTS PASSED (failed: %d) ===" % [_tests_passed, _tests_run, _tests_failed])
	quit(0 if _tests_failed == 0 else 1)
