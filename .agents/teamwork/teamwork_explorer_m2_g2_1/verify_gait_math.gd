extends SceneTree

func _init() -> void:
	print("=== Running Procedural Gait Math Verification ===")
	for v in [0.0, 50.0, 100.0, 180.0, 220.0, 340.0, 780.0]:
		var f: float = 1.8 + 2.0 * tanh(v / 180.0)
		var omega: float = TAU * f
		print("v=%6.1f -> cadence=%.3f Hz, omega=%.2f rad/s" % [v, f, omega])

	# Test piecewise stance-lock and Hermite swing
	var stride_half: float = 14.0
	var step_height: float = 6.0
	for deg in [0, 45, 90, 135, 180, 225, 270, 315, 360]:
		var phase: float = deg_to_rad(float(deg))
		var pt := evaluate_foot(phase, stride_half, step_height)
		print("phase=%3d deg -> x=%6.2f, y=%6.2f (%s)" % [deg, pt.x, pt.y, "STANCE" if phase < PI else "SWING"])
	
	quit(0)

func evaluate_foot(phase: float, stride_half: float, step_height: float) -> Vector2:
	if phase < PI:
		var t_stance: float = phase / PI
		var x: float = stride_half * (1.0 - 2.0 * t_stance)
		return Vector2(x, 0.0)
	else:
		var tau: float = (phase - PI) / PI
		var smooth_tau: float = tau * tau * (3.0 - 2.0 * tau)
		var x: float = -stride_half + 2.0 * stride_half * smooth_tau
		var y: float = step_height * 4.0 * tau * (1.0 - tau)
		return Vector2(x, y)
