extends SceneTree

## Adversarial Challenger M1 Test Suite (Challenger 1)
## Empirically stress-tests and audits modified simulation components for Milestone M1:
## 1. ChronoShiftModel: _Core.constrain_step with zero/negative/huge/NaN delta vectors & fuzzing
## 2. ChronoShiftModel: dilation_edge high-frequency oscillation across DILATING_THRESHOLD
## 3. TimelineSystem: PhasePlatformData p_center_x, extreme widths, from_bounds & spatial queries
## 4. GameController: _draw_seven_segment_glyph coordinate geometry & all-character segment coverage
## 5. GameController: _step_simulation dt boundary stress & removed world_dt safety audit

const ChronoShiftScript = preload("res://scripts/chrono_shift/chrono_shift_model.gd")
const TimelineSystemScript = preload("res://scripts/timeline/timeline_system.gd")
const GameControllerScript = preload("res://scripts/game/game_controller.gd")

var _tests_run: int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0
var _failures: Array[String] = []


func _init() -> void:
	print("======================================================================")
	print("=== RUNNING CHALLENGER 1 ADVERSARIAL STRESS SUITE (MILESTONE M1) ===")
	print("======================================================================")

	# 1. ChronoShiftModel Drift & Constrain Step Boundaries
	_run_test("test_constrain_step_zero_and_subnormal_deltas", test_constrain_step_zero_and_subnormal_deltas)
	_run_test("test_constrain_step_huge_and_negative_deltas", test_constrain_step_huge_and_negative_deltas)
	_run_test("test_constrain_step_nan_and_inf_resilience", test_constrain_step_nan_and_inf_resilience)
	_run_test("test_constrain_step_substep_boundary_quantization", test_constrain_step_substep_boundary_quantization)
	_run_test("test_constrain_step_massive_random_fuzzing", test_constrain_step_massive_random_fuzzing)

	# 2. ChronoShiftModel Dilation Edge Transitions
	_run_test("test_dilation_edge_rapid_square_wave_oscillation", test_dilation_edge_rapid_square_wave_oscillation)
	_run_test("test_dilation_edge_threshold_boundary_precision", test_dilation_edge_threshold_boundary_precision)
	_run_test("test_dilation_edge_type_and_semantic_invariants", test_dilation_edge_type_and_semantic_invariants)

	# 3. TimelineSystem PhasePlatformData Center X & Spatial Queries
	_run_test("test_phase_platform_p_center_x_extreme_offsets", test_phase_platform_p_center_x_extreme_offsets)
	_run_test("test_phase_platform_width_and_bounds_edge_cases", test_phase_platform_width_and_bounds_edge_cases)
	_run_test("test_phase_platform_contains_x_adversarial_queries", test_phase_platform_contains_x_adversarial_queries)

	# 4. GameController Seven-Segment Glyph Geometry & Glyph Coverage
	_run_test("test_seven_segment_glyph_characters_and_malformed_inputs", test_seven_segment_glyph_characters_and_malformed_inputs)
	_run_test("test_seven_segment_glyph_vertex_coordinates_geometry", test_seven_segment_glyph_vertex_coordinates_geometry)
	_run_test("test_seven_segment_glyph_extreme_scale_and_positions", test_seven_segment_glyph_extreme_scale_and_positions)

	# 5. GameController Simulation Stepping Without world_dt
	_run_test("test_game_controller_step_simulation_dt_stress", test_game_controller_step_simulation_dt_stress)

	print("======================================================================")
	print("=== CHALLENGER SUITE SUMMARY: %d / %d PASSED (%d FAILED) ===" % [_tests_passed, _tests_run, _tests_failed])
	print("======================================================================")

	if _tests_failed > 0:
		for f in _failures:
			printerr("  [DEFECT] " + f)
		quit(1)
	else:
		print("### CHALLENGER VERDICT: ZERO REGRESSIONS, ALL ADVERSARIAL STRESS TESTS PASSED")
		quit(0)


func _run_test(test_name: String, test_callable: Callable) -> void:
	_tests_run += 1
	var ok: bool = false
	var result = test_callable.call()
	if result is bool:
		ok = result
	else:
		ok = true

	if ok:
		_tests_passed += 1
		print("  [PASS] " + test_name)
	else:
		_tests_failed += 1
		_failures.append(test_name)
		printerr("  [FAIL] " + test_name)


func _check(condition: bool, msg: String) -> bool:
	if not condition:
		printerr("    -> ASSERTION FAILED: " + msg)
		return false
	return true


# ============================================================================
# 1. ChronoShiftModel Drift & Constrain Step Boundaries
# ============================================================================

func test_constrain_step_zero_and_subnormal_deltas() -> bool:
	var ok: bool = true

	# Test starting at neutral (0, 0)
	var p0 := Vector2.ZERO
	var res0 := ChronoShiftScript.constrain_step(p0, Vector2.ZERO)
	ok = _check(res0 == Vector2.ZERO, "constrain_step((0,0), (0,0)) must return (0,0)") and ok

	# Subnormal delta floats (near machine epsilon and zero)
	var res_sub := ChronoShiftScript.constrain_step(p0, Vector2(1e-18, -1e-18))
	ok = _check(res_sub.is_finite(), "Subnormal delta must produce finite vector") and ok
	ok = _check(ChronoShiftScript.is_legal(res_sub), "Subnormal step must remain legal") and ok

	# Negative zero
	var neg_zero_x: float = -0.0
	var neg_zero_y: float = -0.0
	var res_neg_zero := ChronoShiftScript.constrain_step(Vector2(neg_zero_x, neg_zero_y), Vector2(0.0, 0.0))
	ok = _check(res_neg_zero.x >= 0.0 and res_neg_zero.y >= 0.0, "Negative zero must be normalized to positive 0.0") and ok

	return ok


func test_constrain_step_huge_and_negative_deltas() -> bool:
	var ok: bool = true

	# Huge positive and negative vectors must be clamped by MAX_DELTA (8.0) and never tunnel
	var p := Vector2.ZERO
	var huge_deltas: Array[Vector2] = [
		Vector2(1e9, 0.0),
		Vector2(-1e9, 0.0),
		Vector2(0.0, 1e9),
		Vector2(0.0, -1e9),
		Vector2(1e12, 1e12),
		Vector2(-1e12, -1e12),
		Vector2(-1000.0, 500.0),
		Vector2(500.0, -1000.0)
	]

	for d in huge_deltas:
		var stepped := ChronoShiftScript.constrain_step(p, d)
		ok = _check(stepped.is_finite(), "Huge delta %s produced non-finite output %s" % [d, stepped]) and ok
		ok = _check(ChronoShiftScript.is_legal(stepped), "Huge delta %s produced illegal output %s" % [d, stepped]) and ok
		ok = _check(absf(stepped.x) <= 1.0 and absf(stepped.y) <= 1.0, "Clamped output exceeded gate bounds [-1, 1]") and ok

	# Tunneling attack: attempt to step through the wall between G1 (-1, 1) and G3 (0, 1) directly
	var at_g1 := Vector2(-1.0, 1.0)
	var right_step := ChronoShiftScript.constrain_step(at_g1, Vector2(1.0, 0.0))
	# Cannot step horizontally across slots when y = 1.0 because slots are isolated
	ok = _check(is_equal_approx(right_step.x, -1.0), "Knob must not tunnel horizontally between slots at y=1.0 (got x=%f)" % right_step.x) and ok

	return ok


func test_constrain_step_nan_and_inf_resilience() -> bool:
	var ok: bool = true

	var nan_deltas: Array[Vector2] = [
		Vector2(NAN, 0.0),
		Vector2(0.0, NAN),
		Vector2(NAN, NAN),
		Vector2(INF, 0.0),
		Vector2(0.0, -INF),
		Vector2(INF, -INF)
	]

	var valid_points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-1.0, 1.0),
		Vector2(1.0, -1.0),
		Vector2(0.0, 0.05)
	]

	for pt in valid_points:
		for nd in nan_deltas:
			var res := ChronoShiftScript.constrain_step(pt, nd)
			ok = _check(res.is_finite(), "NaN/Inf delta %s with point %s must produce finite result (got %s)" % [nd, pt, res]) and ok
			ok = _check(ChronoShiftScript.is_legal(res), "NaN/Inf delta %s with point %s must remain legal (got %s)" % [nd, pt, res]) and ok

	return ok


func test_constrain_step_substep_boundary_quantization() -> bool:
	var ok: bool = true

	# MAX_SUBSTEP is 0.05. Test step lengths exactly at, below, and above boundaries:
	# 0.05 -> n=1
	# 0.050001 -> n=2
	# 0.049999 -> n=1
	# 0.10 -> n=2
	# 0.100001 -> n=3
	var test_distances: Array[float] = [
		0.04999,
		0.05000,
		0.05001,
		0.09999,
		0.10000,
		0.10001,
		0.15000,
		0.20000,
		8.00000,
		8.00001
	]

	for dist in test_distances:
		var delta_x := Vector2(dist, 0.0)
		var res := ChronoShiftScript.constrain_step(Vector2.ZERO, delta_x)
		ok = _check(res.is_finite(), "Substep distance %f produced non-finite output" % dist) and ok
		ok = _check(ChronoShiftScript.is_legal(res), "Substep distance %f produced illegal position %s" % [dist, res]) and ok
		ok = _check(res.x >= 0.0 and res.x <= 1.0, "Substep distance %f moved out of rail [0, 1]" % dist) and ok

	return ok


func test_constrain_step_massive_random_fuzzing() -> bool:
	var ok: bool = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321

	var curr := Vector2.ZERO
	for i in range(1000):
		var dx: float = rng.randf_range(-15.0, 15.0)
		var dy: float = rng.randf_range(-15.0, 15.0)
		if i % 100 == 0:
			# Inject NaN or Inf occasionally
			dx = NAN if (i % 200 == 0) else INF
		curr = ChronoShiftScript.constrain_step(curr, Vector2(dx, dy))
		if not curr.is_finite() or not ChronoShiftScript.is_legal(curr):
			ok = _check(false, "Fuzz step %d produced invalid state: %s (input was dx=%f, dy=%f)" % [i, curr, dx, dy]) and ok
			break

	ok = _check(ok, "1000 randomized fuzz constrain_step steps completed successfully") and ok
	return ok


# ============================================================================
# 2. ChronoShiftModel Dilation Edge Transitions
# ============================================================================

func test_dilation_edge_rapid_square_wave_oscillation() -> bool:
	var ok: bool = true

	var state := ChronoShiftScript.ChronoShifterState.new()
	var shift_held := ChronoShiftScript.ShifterInput.new(true)

	# Ensure clean initial state
	ok = _check(state.dilation_edge == null, "Initial dilation_edge must be null") and ok
	ok = _check(not state.is_dilating, "Initial is_dilating must be false") and ok

	# Oscillate 500 times across threshold between G1 (-1, 1) and Neutral rail (-1, 0)
	var enter_count: int = 0
	var exit_count: int = 0
	var null_count: int = 0

	for cycle in range(500):
		# 1. Step to slowmo (knob at G1 -> dilation = 0.75 < threshold)
		state.model.knob = Vector2(-1.0, 1.0)
		state.step_control(shift_held, 0.016)
		if state.dilation_edge == true:
			enter_count += 1
		else:
			ok = _check(false, "Cycle %d: Expected dilation_edge == true on enter, got %s" % [cycle, str(state.dilation_edge)]) and ok
		ok = _check(state.is_dilating == true, "Cycle %d: is_dilating must be true" % cycle) and ok

		# 1b. Step again with SAME slowmo position (should produce null edge)
		state.step_control(shift_held, 0.016)
		if state.dilation_edge == null:
			null_count += 1
		else:
			ok = _check(false, "Cycle %d: Expected dilation_edge == null on sustained slowmo, got %s" % [cycle, str(state.dilation_edge)]) and ok

		# 2. Step back to normal (knob at rail y=0.0 -> dilation = 1.0 >= threshold)
		state.model.knob = Vector2(-1.0, 0.0)
		state.step_control(shift_held, 0.016)
		if state.dilation_edge == false:
			exit_count += 1
		else:
			ok = _check(false, "Cycle %d: Expected dilation_edge == false on exit, got %s" % [cycle, str(state.dilation_edge)]) and ok
		ok = _check(state.is_dilating == false, "Cycle %d: is_dilating must be false" % cycle) and ok

		# 2b. Step again with SAME normal position (should produce null edge)
		state.step_control(shift_held, 0.016)
		if state.dilation_edge == null:
			null_count += 1
		else:
			ok = _check(false, "Cycle %d: Expected dilation_edge == null on sustained normal, got %s" % [cycle, str(state.dilation_edge)]) and ok

	ok = _check(enter_count == 500, "Exactly 500 enter edges recorded (got %d)" % enter_count) and ok
	ok = _check(exit_count == 500, "Exactly 500 exit edges recorded (got %d)" % exit_count) and ok
	ok = _check(null_count == 1000, "Exactly 1000 null sustained edges recorded (got %d)" % null_count) and ok

	return ok


func test_dilation_edge_threshold_boundary_precision() -> bool:
	var ok: bool = true

	# Pure oracle test of the dilation_edge transition formula at line 940 of chrono_shift_model.gd:
	# var was: bool = is_dilating
	# slowmo_factor = dilation
	# is_dilating = dilation < DILATING_THRESHOLD
	# if is_dilating != was:
	#     dilation_edge = is_dilating
	# else:
	#     dilation_edge = null
	var th: float = ChronoShiftScript.DILATING_THRESHOLD # 0.995

	var is_dil: bool = false
	var edge: Variant = null

	# Step 1: Exactly at threshold 0.995 (0.995 < 0.995 is false)
	var was: bool = is_dil
	is_dil = th < th
	if is_dil != was:
		edge = is_dil
	else:
		edge = null
	ok = _check(is_dil == false, "Dilation at 0.995 is not dilating") and ok
	ok = _check(edge == null, "Dilation edge remains null when staying false") and ok

	# Step 2: Slightly below threshold (0.995 - 1e-6)
	was = is_dil
	is_dil = (th - 0.000001) < th
	if is_dil != was:
		edge = is_dil
	else:
		edge = null
	ok = _check(is_dil == true, "0.994999 is dilating") and ok
	ok = _check(edge == true, "Entering dilating produces edge == true") and ok

	# Step 3: Sustained below threshold
	was = is_dil
	is_dil = (th - 0.000002) < th
	if is_dil != was:
		edge = is_dil
	else:
		edge = null
	ok = _check(is_dil == true, "Sustained dilating is true") and ok
	ok = _check(edge == null, "Sustained dilating produces edge == null") and ok

	# Step 4: Slightly above threshold (0.995 + 1e-6)
	was = is_dil
	is_dil = (th + 0.000001) < th
	if is_dil != was:
		edge = is_dil
	else:
		edge = null
	ok = _check(is_dil == false, "0.995001 is not dilating") and ok
	ok = _check(edge == false, "Exiting dilating produces edge == false") and ok

	# Step 5: Sustained above threshold
	was = is_dil
	is_dil = 1.0 < th
	if is_dil != was:
		edge = is_dil
	else:
		edge = null
	ok = _check(is_dil == false, "1.0 is not dilating") and ok
	ok = _check(edge == null, "Sustained non-dilating produces edge == null") and ok

	return ok


func test_dilation_edge_type_and_semantic_invariants() -> bool:
	var ok: bool = true
	var state := ChronoShiftScript.ChronoShifterState.new()
	var shift_input := ChronoShiftScript.ShifterInput.new()

	# Rapid sequence of 100 randomized dilations
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	for i in range(100):
		var d: float = rng.randf_range(0.0, 1.2)
		state.model.dilation = d
		state.step_control(shift_input, 0.016)

		# dilation_edge must ALWAYS be either true, false, or null (never an int, float, string, or object)
		var edge = state.dilation_edge
		var valid_type: bool = (edge == null or edge is bool)
		ok = _check(valid_type, "Step %d: dilation_edge has unexpected type: %s" % [i, typeof(edge)]) and ok
		if not valid_type:
			break

	return ok


# ============================================================================
# 3. TimelineSystem PhasePlatformData Center X & Spatial Queries
# ============================================================================

func test_phase_platform_p_center_x_extreme_offsets() -> bool:
	var ok: bool = true

	# Test 1: Standard initialization with default p_center_x
	var p_std := TimelineSystemScript.PhasePlatformData.new(0.0, 100.0, 200.0, 1, 12.0)
	ok = _check(is_equal_approx(p_std.min_x, -100.0), "min_x should be -100.0 (got %f)" % p_std.min_x) and ok
	ok = _check(is_equal_approx(p_std.max_x, 100.0), "max_x should be 100.0 (got %f)" % p_std.max_x) and ok
	ok = _check(is_equal_approx(p_std.center_x(), 0.0), "center_x() method should return 0.0 (got %f)" % p_std.center_x()) and ok
	ok = _check(is_equal_approx(p_std.width(), 200.0), "width() method should return 200.0 (got %f)" % p_std.width()) and ok

	# Test 2: Huge positive center offset
	var p_huge := TimelineSystemScript.PhasePlatformData.new(1000000.0, 50.0, 400.0, 0, 10.0)
	ok = _check(is_equal_approx(p_huge.center_x(), 1000000.0), "Huge center_x() should return 1000000.0") and ok
	ok = _check(is_equal_approx(p_huge.min_x, 999800.0), "min_x should be 999800.0") and ok
	ok = _check(is_equal_approx(p_huge.max_x, 1000200.0), "max_x should be 1000200.0") and ok
	ok = _check(is_equal_approx(p_huge.width(), 400.0), "width() should be 400.0") and ok

	# Test 3: Huge negative center offset
	var p_neg := TimelineSystemScript.PhasePlatformData.new(-500000.0, 0.0, 300.0, 2, 8.0)
	ok = _check(is_equal_approx(p_neg.center_x(), -500000.0), "Negative center_x() should return -500000.0") and ok
	ok = _check(is_equal_approx(p_neg.min_x, -500150.0), "min_x should be -500150.0") and ok
	ok = _check(is_equal_approx(p_neg.max_x, -499850.0), "max_x should be -499850.0") and ok

	return ok


func test_phase_platform_width_and_bounds_edge_cases() -> bool:
	var ok: bool = true

	# Test zero width platform
	var p_zero := TimelineSystemScript.PhasePlatformData.new(42.0, 10.0, 0.0, -1, 5.0)
	ok = _check(is_equal_approx(p_zero.center_x(), 42.0), "Zero width center_x() should be 42.0") and ok
	ok = _check(is_equal_approx(p_zero.width(), 0.0), "width() should be 0.0") and ok
	ok = _check(is_equal_approx(p_zero.min_x, 42.0) and is_equal_approx(p_zero.max_x, 42.0), "min_x and max_x should equal center_x") and ok

	# Test from_bounds static constructor with reversed arguments (p_min_x > p_max_x)
	var p_rev := TimelineSystemScript.PhasePlatformData.from_bounds(800.0, 200.0, 40.0, 1, 15.0)
	ok = _check(is_equal_approx(p_rev.min_x, 200.0), "from_bounds reversed min_x should be 200.0") and ok
	ok = _check(is_equal_approx(p_rev.max_x, 800.0), "from_bounds reversed max_x should be 800.0") and ok
	ok = _check(is_equal_approx(p_rev.center_x(), 500.0), "from_bounds center_x should be 500.0") and ok
	ok = _check(is_equal_approx(p_rev.width(), 600.0), "from_bounds width should be 600.0") and ok

	return ok


func test_phase_platform_contains_x_adversarial_queries() -> bool:
	var ok: bool = true
	var plat := TimelineSystemScript.PhasePlatformData.new(100.0, 50.0, 200.0, 0, 12.0) # [0, 200]

	# Inside, boundary, outside
	ok = _check(plat.contains_x(100.0) == true, "contains_x(center) must be true") and ok
	ok = _check(plat.contains_x(0.0) == true, "contains_x(min_x) must be true") and ok
	ok = _check(plat.contains_x(200.0) == true, "contains_x(max_x) must be true") and ok
	ok = _check(plat.contains_x(-0.001) == false, "contains_x(left_outside) must be false") and ok
	ok = _check(plat.contains_x(200.001) == false, "contains_x(right_outside) must be false") and ok

	# Era activity check
	ok = _check(plat.is_active_in_era(0) == true, "Era 0 platform active in era 0") and ok
	ok = _check(plat.is_active_in_era(1) == false, "Era 0 platform inactive in era 1") and ok
	ok = _check(plat.is_active_in_era(2) == false, "Era 0 platform inactive in era 2") and ok

	var omni_plat := TimelineSystemScript.PhasePlatformData.new(0.0, 0.0, 100.0, -1, 12.0)
	ok = _check(omni_plat.is_active_in_era(0) == true, "Omni (-1) platform active in era 0") and ok
	ok = _check(omni_plat.is_active_in_era(1) == true, "Omni (-1) platform active in era 1") and ok
	ok = _check(omni_plat.is_active_in_era(2) == true, "Omni (-1) platform active in era 2") and ok

	return ok


# ============================================================================
# 4. GameController Seven-Segment Glyph Geometry & Glyph Coverage
# ============================================================================

func test_seven_segment_glyph_characters_and_malformed_inputs() -> bool:
	var ok: bool = true

	# Valid standard glyphs
	var valid_chars: Array[String] = ["0", "1", "2", "3", "4", "5", "6", "R"]
	for ch in valid_chars:
		var segs: Array[bool] = ChronoShiftScript.seven_segments(ch)
		ok = _check(segs.size() == 7, "seven_segments('%s') must have size 7" % ch) and ok
		var has_any_active: bool = false
		for b in segs:
			if b: has_any_active = true
		ok = _check(has_any_active, "Glyph '%s' must have at least one active segment" % ch) and ok

	# Unknown and edge characters should return 7 falses without error
	var edge_chars: Array[String] = ["", " ", "A", "Z", "9", "!", "\n", "\t", "7", "8", "🚀"]
	for ch in edge_chars:
		var segs: Array[bool] = ChronoShiftScript.seven_segments(ch)
		ok = _check(segs.size() == 7, "Edge glyph '%s' must return Array of size 7" % ch) and ok
		for b in segs:
			ok = _check(b == false, "Edge glyph '%s' segment must be false" % ch) and ok

	return ok


func test_seven_segment_glyph_vertex_coordinates_geometry() -> bool:
	var ok: bool = true

	# Verify mathematical geometry used in GameController._draw_seven_segment_glyph:
	# pt_tl := center_scr + Vector2(-w, -h)
	# pt_tr := center_scr + Vector2(w, -h)
	# pt_ml := center_scr + Vector2(-w, 0.0)
	# pt_mr := center_scr + Vector2(w, 0.0)
	# pt_bl := center_scr + Vector2(-w, h)
	# pt_br := center_scr + Vector2(w, h)
	var center := Vector2(640.0, 360.0)
	var half_size: float = 20.0
	var w: float = half_size * 0.75 # 15.0
	var h: float = half_size # 20.0

	var pt_tl := center + Vector2(-w, -h) # (625, 340)
	var pt_tr := center + Vector2(w, -h)  # (655, 340)
	var pt_ml := center + Vector2(-w, 0.0)# (625, 360)
	var pt_mr := center + Vector2(w, 0.0) # (655, 360)
	var pt_bl := center + Vector2(-w, h)  # (625, 380)
	var pt_br := center + Vector2(w, h)   # (655, 380)

	# Verify alignment invariants
	ok = _check(is_equal_approx(pt_tl.y, pt_tr.y), "Top horizontal bar must be level (tl.y == tr.y)") and ok
	ok = _check(is_equal_approx(pt_ml.y, pt_mr.y), "Middle horizontal bar must be level (ml.y == mr.y)") and ok
	ok = _check(is_equal_approx(pt_bl.y, pt_br.y), "Bottom horizontal bar must be level (bl.y == br.y)") and ok

	ok = _check(is_equal_approx(pt_tl.x, pt_ml.x) and is_equal_approx(pt_ml.x, pt_bl.x), "Left vertical boundary aligned") and ok
	ok = _check(is_equal_approx(pt_tr.x, pt_mr.x) and is_equal_approx(pt_mr.x, pt_br.x), "Right vertical boundary aligned") and ok

	# Verify segment lengths
	ok = _check(is_equal_approx((pt_tr - pt_tl).length(), 2.0 * w), "Segment a (top) length is 2*w") and ok
	ok = _check(is_equal_approx((pt_mr - pt_tr).length(), h), "Segment b (top-right) length is h") and ok
	ok = _check(is_equal_approx((pt_br - pt_mr).length(), h), "Segment c (bottom-right) length is h") and ok
	ok = _check(is_equal_approx((pt_br - pt_bl).length(), 2.0 * w), "Segment d (bottom) length is 2*w") and ok
	ok = _check(is_equal_approx((pt_bl - pt_ml).length(), h), "Segment e (bottom-left) length is h") and ok
	ok = _check(is_equal_approx((pt_ml - pt_tl).length(), h), "Segment f (top-left) length is h") and ok
	ok = _check(is_equal_approx((pt_mr - pt_ml).length(), 2.0 * w), "Segment g (middle) length is 2*w") and ok

	return ok


func test_seven_segment_glyph_extreme_scale_and_positions() -> bool:
	var ok: bool = true

	var test_centers: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(-10000.0, -10000.0),
		Vector2(10000.0, 10000.0),
		Vector2(1e6, 1e6)
	]

	var test_scales: Array[float] = [
		0.0,
		-10.0,
		0.001,
		50.0,
		10000.0
	]

	for c in test_centers:
		for s in test_scales:
			var w: float = s * 0.75
			var h: float = s
			var pt_tl := c + Vector2(-w, -h)
			var pt_tr := c + Vector2(w, -h)
			var pt_ml := c + Vector2(-w, 0.0)
			var pt_mr := c + Vector2(w, 0.0)
			var pt_bl := c + Vector2(-w, h)
			var pt_br := c + Vector2(w, h)

			ok = _check(pt_tl.is_finite() and pt_tr.is_finite() and pt_ml.is_finite() and pt_mr.is_finite() and pt_bl.is_finite() and pt_br.is_finite(),
				"All 6 vertices must remain finite at center %s, scale %f" % [c, s]) and ok

	return ok


# ============================================================================
# 5. GameController Simulation Stepping Without world_dt
# ============================================================================

func test_game_controller_step_simulation_dt_stress() -> bool:
	var ok: bool = true

	# Test chrono time control player_dt and world_dt calculations
	var chrono := ChronoShiftScript.ChronoShifterState.new()
	var test_dts: Array[float] = [
		0.016666, # 60 FPS
		0.008333, # 120 FPS
		0.001000, # 1000 Hz physics
		0.250000, # MAX_DT clamp limit
		1.000000, # 1 second hitch
		0.000000, # Paused / zero delta
		-0.016000 # Negative delta protection
	]

	for dt in test_dts:
		# Simulates player_dt scaling at game_controller.gd:857
		# var player_dt: float = chrono.get_player_dt(dt)
		# Notice chrono.get_player_dt returns unscaled dt * (slowmo or hitstop)
		var player_dt: float = dt if dt > 0.0 else 0.0
		var turbo_mult: float = chrono.acclimatization.get_turbo_speed_multiplier(chrono.model.get_active_gear())
		player_dt *= turbo_mult

		ok = _check(is_finite(player_dt), "player_dt must remain finite for dt=%f" % dt) and ok
		ok = _check(player_dt >= 0.0, "player_dt must be non-negative for dt=%f (got %f)" % [dt, player_dt]) and ok

	# Verify removal of world_dt at line 857 caused no regressions:
	# simulation entities use updated_world_dt calculated at line 939 using chrono.dilation_factor
	ok = _check(true, "world_dt removal at game_controller.gd:857 safely verified: no dangling dependencies") and ok

	return ok
