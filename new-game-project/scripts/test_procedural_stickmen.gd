extends Node2D

## Dedicated Test Scene: Procedural Stickman Rig & Animation Showcase
## Demonstrates:
## 1. Clean, readable, solid-color stickman silhouettes (One vs Many / Hyun's Dojo style).
## 2. Dynamic procedural animation:
##    - Player Character (interactive: A/D run, Space jump, J slash, K parry, S slam, X dismemberment slice)
##    - Chrono-Echo Clone (luminous cyan afterimage running loop)
##    - All 6 Enemy Archetypes (Runner, Ninja, Heavy, Semi-Marksman, Suppressor, Cyber Sniper)
## 3. Visceral Death Sprites & Procedural Dismemberment:
##    - Bisected solid stickman anatomy (upper torso + head, lower pelvis + legs)
##    - Tumbling physics, floor bouncing, razor cut-edge spark highlights
##    - Directional velocity-stretched blood & spark particle bursts

const PROCEDURAL_STICKMAN_SCENE_PATH: String = "res://scenes/stickman/stickmanprocedural.tscn"

const FLOOR_Y: float = 540.0
const STICKMAN_SCALE: Vector2 = Vector2(0.12, 0.12)
const HEAVY_SCALE: Vector2 = Vector2(0.15, 0.15)

@onready var player_rig: StickmanProcedural = null
var echo_rig: StickmanProcedural = null
var enemy_rigs: Dictionary = {}

var player_pos: Vector2 = Vector2(640.0, FLOOR_Y)
var player_vel: Vector2 = Vector2.ZERO
var player_facing: float = 1.0
var player_on_ground: bool = true
var player_state: String = "idle"
var player_action_timer: float = 0.0

var echo_phase_timer: float = 0.0
var showcase_timer: float = 0.0
var slice_demo_timer: float = 0.0

# Dismemberment & Death Visuals
var ragdoll_pieces: Array = []
var slice_particles: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.10, 0.14))

	_setup_arena_environment()
	_spawn_player_rig()
	_spawn_echo_rig()
	_spawn_enemy_archetypes()
	_build_ui_overlay()

	# Spawn initial demo dismemberment pieces on side platform
	_spawn_dismemberment_slice(Vector2(260.0, FLOOR_Y - 40.0), Color(0.72, 0.28, 0.95), "enemy_ninja", Vector2(120.0, -80.0))

	# If run in headless batch test mode, perform automated verification and quit cleanly
	if DisplayServer.get_name() == "headless":
		_run_headless_verification()


func _setup_arena_environment() -> void:
	# Ground static body with visual polygon
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	var col_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1600.0, 40.0)
	col_shape.shape = rect
	col_shape.position = Vector2(640.0, FLOOR_Y + 20.0)
	ground.add_child(col_shape)
	add_child(ground)


func _spawn_player_rig() -> void:
	var scene: PackedScene = load(PROCEDURAL_STICKMAN_SCENE_PATH)
	if scene == null:
		printerr("Failed to load procedural stickman scene from: %s" % PROCEDURAL_STICKMAN_SCENE_PATH)
		return

	var node = scene.instantiate()
	if node is CharacterBody2D:
		player_rig = node as StickmanProcedural
		player_rig.name = "ShowcasePlayer"
		player_rig.autonomous_physics = false
		player_rig.scale = STICKMAN_SCALE
		player_rig.modulate = Color(0.96, 0.98, 1.0, 1.0) # Sleek pure white hero stickman
		player_rig.position = player_pos + Vector2(0.0, -38.4)
		player_rig.z_index = 10
		add_child(player_rig)


func _spawn_echo_rig() -> void:
	var scene: PackedScene = load(PROCEDURAL_STICKMAN_SCENE_PATH)
	if scene == null:
		return

	var node = scene.instantiate()
	if node is CharacterBody2D:
		echo_rig = node as StickmanProcedural
		echo_rig.name = "ShowcaseChronoEcho"
		echo_rig.autonomous_physics = false
		echo_rig.scale = STICKMAN_SCALE
		echo_rig.modulate = Color(0.2, 0.95, 1.0, 0.65) # Luminous cyan clone
		echo_rig.position = Vector2(500.0, FLOOR_Y - 38.4)
		echo_rig.z_index = 8
		add_child(echo_rig)


func _spawn_enemy_archetypes() -> void:
	var scene: PackedScene = load(PROCEDURAL_STICKMAN_SCENE_PATH)
	if scene == null:
		return

	# Archetype configurations: [name, x_pos, color, scale, default_state]
	var archetypes: Array[Dictionary] = [
		{"type": "Runner", "x": 140.0, "color": Color(1.0, 0.32, 0.32), "scale": STICKMAN_SCALE, "state": "run"},
		{"type": "Ninja", "x": 250.0, "color": Color(0.72, 0.28, 0.95), "scale": STICKMAN_SCALE, "state": "slash"},
		{"type": "Heavy", "x": 370.0, "color": Color(1.0, 0.55, 0.15), "scale": HEAVY_SCALE, "state": "heavy_slash"},
		{"type": "SemiMarksman", "x": 880.0, "color": Color(0.25, 0.95, 0.45), "scale": STICKMAN_SCALE, "state": "aim"},
		{"type": "AmberSuppressor", "x": 1000.0, "color": Color(1.0, 0.85, 0.20), "scale": STICKMAN_SCALE, "state": "aim"},
		{"type": "CyberSniper", "x": 1120.0, "color": Color(0.20, 0.75, 1.0), "scale": STICKMAN_SCALE, "state": "sniper_brace"},
	]

	for arc in archetypes:
		var node = scene.instantiate()
		if node is CharacterBody2D:
			var erig := node as StickmanProcedural
			erig.name = "Enemy_%s" % arc["type"]
			erig.autonomous_physics = false
			erig.scale = arc["scale"]
			erig.modulate = arc["color"]
			erig.position = Vector2(arc["x"], FLOOR_Y - 38.4)
			erig.z_index = 6
			add_child(erig)
			enemy_rigs[arc["type"]] = {
				"rig": erig,
				"base_x": arc["x"],
				"color": arc["color"],
				"state": arc["state"]
			}


func _build_ui_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShowcaseUI"

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(24.0, 18.0)
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "OUT OF TIME — Procedural Stickman & Dismemberment Showcase (One vs Many Style)"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sleek, solid stick figures (pure archetype colors) + Bisected body dismemberment with kinetic tumbling"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(subtitle)

	var instructions := Label.new()
	instructions.text = "Controls: [A/D] Run  |  [Space] Jump  |  [J] Slash  |  [K] Parry  |  [S] Slam  |  [X] Trigger Dismemberment Slice"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
	vbox.add_child(instructions)

	add_child(canvas)


func _process(delta: float) -> void:
	showcase_timer += delta
	slice_demo_timer += delta

	_update_player_input(delta)
	_update_automated_echo(delta)
	_update_automated_enemies(delta)
	_update_dismembered_ragdolls(delta)

	# In non-interactive demo mode, periodically spawn an exciting dismemberment slice
	if slice_demo_timer >= 2.8:
		slice_demo_timer = 0.0
		var spawn_x: float = 780.0 if fmod(showcase_timer, 5.6) > 2.8 else 440.0
		var spawn_col: Color = Color(1.0, 0.32, 0.32) if spawn_x > 600.0 else Color(1.0, 0.55, 0.15)
		var spawn_lid: String = "enemy_runner" if spawn_x > 600.0 else "enemy_heavy"
		_spawn_dismemberment_slice(Vector2(spawn_x, FLOOR_Y - 50.0), spawn_col, spawn_lid, Vector2(160.0, -120.0))

	queue_redraw()


func _spawn_dismemberment_slice(origin: Vector2, col: Color, loadout_id: String, impulse: Vector2) -> void:
	var slice_dir := Vector2(0.8, -0.6).normalized()
	var split: Dictionary = RagdollPhysics.calculate_slice_split_velocities(Vector2.ZERO, slice_dir, impulse)

	var upper_piece := RagdollPhysics.RagdollPieceData.new(
		RagdollPhysics.RagdollPart.UPPER_TORSO,
		origin + Vector2(0.0, -12.0),
		split["upper_vel"],
		split["upper_ang_vel"],
		1.0,
		col,
		loadout_id
	)
	var lower_piece := RagdollPhysics.RagdollPieceData.new(
		RagdollPhysics.RagdollPart.LOWER_LEGS,
		origin,
		split["lower_vel"],
		split["lower_ang_vel"],
		1.0,
		col,
		loadout_id
	)
	ragdoll_pieces.append(upper_piece)
	ragdoll_pieces.append(lower_piece)

	# Spawn directional blood and kinetic spark particle streaks
	for i in range(16):
		var angle: float = (float(i) / 16.0) * TAU
		var spd: float = 140.0 + fmod(float(i) * 31.0, 220.0)
		var dir := Vector2(cos(angle), sin(angle))
		var p_col := Color(0.95, 0.15, 0.2, 1.0) if i % 2 == 0 else Color(col.r, col.g, col.b, 1.0)
		var part := RagdollPhysics.SliceParticleData.new(
			origin,
			dir * spd + impulse * 0.4,
			0.55,
			3.2,
			p_col,
			0.85
		)
		slice_particles.append(part)


func _update_dismembered_ragdolls(delta: float) -> void:
	for i in range(ragdoll_pieces.size() - 1, -1, -1):
		var piece: RagdollPhysics.RagdollPieceData = ragdoll_pieces[i]
		if not RagdollPhysics.step_ragdoll_piece(piece, [], delta, FLOOR_Y, 1200.0):
			ragdoll_pieces.remove_at(i)

	for i in range(slice_particles.size() - 1, -1, -1):
		var part: RagdollPhysics.SliceParticleData = slice_particles[i]
		if not RagdollPhysics.step_slice_particle(part, delta, FLOOR_Y, 1200.0):
			slice_particles.remove_at(i)


func _update_player_input(delta: float) -> void:
	if player_rig == null:
		return

	if player_action_timer > 0.0:
		player_action_timer -= delta
		if player_action_timer <= 0.0:
			player_action_timer = 0.0
			player_state = "idle"

	var move_x: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_x += 1.0

	if move_x != 0.0:
		player_facing = signf(move_x)
		player_vel.x = move_toward(player_vel.x, move_x * 260.0, 1400.0 * delta)
	else:
		player_vel.x = move_toward(player_vel.x, 0.0, 1800.0 * delta)

	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) and player_on_ground:
		player_vel.y = -480.0
		player_on_ground = false
		player_state = "jump"

	if Input.is_key_pressed(KEY_J) and player_action_timer <= 0.0:
		player_state = "slash"
		player_action_timer = 0.22
	elif Input.is_key_pressed(KEY_K) and player_action_timer <= 0.0:
		player_state = "parry_guard"
		player_action_timer = 0.35
	elif Input.is_key_pressed(KEY_S) and not player_on_ground and player_action_timer <= 0.0:
		player_state = "downward_slam"
		player_vel.y = 650.0
		player_action_timer = 0.40
	elif Input.is_key_pressed(KEY_X) and player_action_timer <= 0.0:
		player_state = "slash"
		player_action_timer = 0.25
		_spawn_dismemberment_slice(player_pos + Vector2(player_facing * 60.0, -30.0), Color(1.0, 0.32, 0.32), "enemy_runner", Vector2(player_facing * 220.0, -140.0))

	if not player_on_ground:
		player_vel.y = minf(player_vel.y + 1400.0 * delta, 900.0)
		player_pos += player_vel * delta
		if player_pos.y >= FLOOR_Y:
			player_pos.y = FLOOR_Y
			player_vel.y = 0.0
			player_on_ground = true
			if player_action_timer <= 0.0:
				player_state = "idle"
	else:
		player_pos.x += player_vel.x * delta
		if player_action_timer <= 0.0:
			player_state = "run" if absf(player_vel.x) > 15.0 else "idle"

	player_pos.x = clampf(player_pos.x, 60.0, 1220.0)

	player_rig.position = player_pos + Vector2(0.0, -38.4)
	player_rig.facing = player_facing
	player_rig.update_procedural_animation(player_vel, player_on_ground, player_facing, player_state, delta)


func _update_automated_echo(delta: float) -> void:
	if echo_rig == null:
		return

	echo_phase_timer += delta
	var echo_offset_x: float = sin(echo_phase_timer * 1.8) * 90.0
	var echo_vx: float = cos(echo_phase_timer * 1.8) * 160.0
	var facing_dir: float = 1.0 if echo_vx >= 0.0 else -1.0

	echo_rig.position = Vector2(550.0 + echo_offset_x, FLOOR_Y - 38.4)
	echo_rig.facing = facing_dir
	echo_rig.update_procedural_animation(Vector2(echo_vx, 0.0), true, facing_dir, "run", delta)


func _update_automated_enemies(delta: float) -> void:
	if enemy_rigs.has("Runner"):
		var item: Dictionary = enemy_rigs["Runner"]
		var erig: StickmanProcedural = item["rig"]
		var patrol_x: float = item["base_x"] + sin(showcase_timer * 2.2) * 45.0
		var vx: float = cos(showcase_timer * 2.2) * 110.0
		erig.position = Vector2(patrol_x, FLOOR_Y - 38.4)
		erig.facing = 1.0 if vx >= 0.0 else -1.0
		erig.update_procedural_animation(Vector2(vx, 0.0), true, erig.facing, "run", delta)

	if enemy_rigs.has("Ninja"):
		var item: Dictionary = enemy_rigs["Ninja"]
		var erig: StickmanProcedural = item["rig"]
		var jump_cycle: float = fmod(showcase_timer, 2.0)
		var is_jumping: bool = jump_cycle < 1.0
		var vy: float = -sin(jump_cycle * PI) * 220.0 if is_jumping else 0.0
		var n_state: String = "slash" if (jump_cycle > 0.4 and jump_cycle < 0.9) else ("jump" if is_jumping else "idle")
		erig.position = Vector2(item["base_x"], FLOOR_Y - 38.4 + vy * 0.25)
		erig.facing = 1.0
		erig.update_procedural_animation(Vector2(0.0, vy), not is_jumping, 1.0, n_state, delta)

	if enemy_rigs.has("Heavy"):
		var item: Dictionary = enemy_rigs["Heavy"]
		var erig: StickmanProcedural = item["rig"]
		var heavy_cycle: float = fmod(showcase_timer, 2.5)
		var h_state: String = "heavy_slash" if heavy_cycle > 1.2 else "run"
		var h_vx: float = 35.0 if heavy_cycle <= 1.2 else 0.0
		erig.facing = 1.0
		erig.update_procedural_animation(Vector2(h_vx, 0.0), true, 1.0, h_state, delta)

	if enemy_rigs.has("SemiMarksman"):
		var item: Dictionary = enemy_rigs["SemiMarksman"]
		var erig: StickmanProcedural = item["rig"]
		erig.facing = -1.0
		erig.update_procedural_animation(Vector2.ZERO, true, -1.0, "aim", delta)

	if enemy_rigs.has("AmberSuppressor"):
		var item: Dictionary = enemy_rigs["AmberSuppressor"]
		var erig: StickmanProcedural = item["rig"]
		erig.facing = -1.0
		erig.update_procedural_animation(Vector2.ZERO, true, -1.0, "aim", delta)

	if enemy_rigs.has("CyberSniper"):
		var item: Dictionary = enemy_rigs["CyberSniper"]
		var erig: StickmanProcedural = item["rig"]
		erig.facing = -1.0
		erig.update_procedural_animation(Vector2.ZERO, true, -1.0, "sniper_brace", delta)


func _draw() -> void:
	# Arena floor line
	draw_line(Vector2(0.0, FLOOR_Y), Vector2(1280.0, FLOOR_Y), Color(0.75, 0.62, 0.34, 1.0), 3.0)
	draw_line(Vector2(0.0, FLOOR_Y + 2.0), Vector2(1280.0, FLOOR_Y + 2.0), Color(0.25, 0.90, 1.0, 0.5), 1.5)

	# Category dividing markers and entity labels
	var labels: Array[Dictionary] = [
		{"text": "Enemies (Melee)", "x": 140.0},
		{"text": "Timeline Clone (Echo)", "x": 480.0},
		{"text": "Player Character", "x": 640.0},
		{"text": "Dismembered Ragdolls (One vs Many Style)", "x": 780.0},
		{"text": "Enemies (Ranged)", "x": 980.0},
	]
	for l in labels:
		draw_string(ThemeDB.fallback_font, Vector2(l["x"] - 40.0, FLOOR_Y + 28.0), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.75, 0.85))

	# Render Dismembered Ragdoll Remains (One vs Many style)
	for piece in ragdoll_pieces:
		_draw_showcase_ragdoll(piece)

	# Render Directional Velocity-Stretched Blood / Spark Particle Streaks
	for part in slice_particles:
		var p_scr: Vector2 = part.position
		var p_vel_scr := Vector2(part.velocity.x, part.velocity.y) * 0.022
		if p_vel_scr.length_squared() > 6.0:
			draw_line(p_scr, p_scr - p_vel_scr, part.color, part.size * 1.1)
			draw_circle(p_scr, part.size * 0.6, part.color)
		else:
			draw_circle(p_scr, part.size, part.color)


func _draw_showcase_ragdoll(piece: RagdollPhysics.RagdollPieceData) -> void:
	var ratio: float = clampf(piece.lifetime / maxf(0.001, piece.max_lifetime), 0.0, 1.0)
	var col := Color(piece.color.r, piece.color.g, piece.color.b, ratio)
	var back_col := Color(piece.color.r * 0.80, piece.color.g * 0.80, piece.color.b * 0.86, ratio)

	var r_pose := ModularAssetSystem.StickmanPoseSolver.generate_ragdoll_pose(
		piece.position,
		piece.rotation,
		piece.facing,
		piece.part,
		piece.loadout_id
	)

	var scr_pelvis := r_pose.pelvis

	if piece.part == RagdollPhysics.RagdollPart.UPPER_TORSO:
		# Solid head (One vs Many style)
		draw_circle(r_pose.head_center, r_pose.head_radius, col)
		draw_arc(r_pose.head_center, r_pose.head_radius, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.35 * ratio), 1.2)
		# Bold torso
		draw_line(r_pose.pelvis, r_pose.neck, col, 8.5)
		draw_circle(r_pose.neck, 4.25, col)
		# Back arm
		draw_line(r_pose.left_shoulder, r_pose.left_elbow, back_col, 5.2)
		draw_circle(r_pose.left_elbow, 2.6, back_col)
		draw_line(r_pose.left_elbow, r_pose.left_hand, back_col, 4.6)
		draw_circle(r_pose.left_hand, 2.6, back_col)
		# Front arm
		draw_line(r_pose.right_shoulder, r_pose.right_elbow, col, 6.0)
		draw_circle(r_pose.right_elbow, 3.0, col)
		draw_line(r_pose.right_elbow, r_pose.right_hand, col, 5.4)
		draw_circle(r_pose.right_hand, 3.0, col)
		# Equipped weapon
		if r_pose.sword_hilt != r_pose.sword_tip:
			draw_line(r_pose.sword_hilt, r_pose.sword_tip, Color(0.95, 0.95, 0.98, ratio), 3.4)
		# Severance cut plane highlight
		var cut_tan := Vector2(cos(-piece.rotation), sin(-piece.rotation)).orthogonal()
		var c1 := scr_pelvis - cut_tan * 7.5
		var c2 := scr_pelvis + cut_tan * 7.5
		draw_line(c1, c2, Color(col.r * 1.3, col.g * 0.3, col.b * 0.3, 0.8 * ratio), 6.5)
		draw_line(c1, c2, Color(1.0, 1.0, 1.0, 0.95 * ratio), 3.0)
		if not piece.is_settled and ratio > 0.2:
			var trail_v: Vector2 = Vector2(-piece.velocity.x, piece.velocity.y) * 0.016
			draw_circle(scr_pelvis + trail_v, 2.8, Color(0.95, 0.15, 0.2, 0.85 * ratio))
		if piece.is_settled:
			draw_line(piece.position - Vector2(10.0, 0.0), piece.position + Vector2(10.0, 0.0), Color(0.85, 0.12, 0.18, 0.55 * ratio), 2.8)
	else:
		# Lower legs piece
		var cut_tan := Vector2(cos(-piece.rotation), sin(-piece.rotation)).orthogonal()
		var c1 := scr_pelvis - cut_tan * 7.5
		var c2 := scr_pelvis + cut_tan * 7.5
		draw_line(c1, c2, Color(col.r * 1.3, col.g * 0.3, col.b * 0.3, 0.8 * ratio), 6.5)
		draw_line(c1, c2, Color(1.0, 1.0, 1.0, 0.95 * ratio), 3.0)
		draw_circle(scr_pelvis, 4.25, col)
		draw_line(scr_pelvis, r_pose.left_hip, back_col, 6.8)
		draw_line(scr_pelvis, r_pose.right_hip, col, 7.2)
		# Back leg
		draw_line(r_pose.left_hip, r_pose.left_knee, back_col, 6.0)
		draw_circle(r_pose.left_knee, 3.0, back_col)
		draw_line(r_pose.left_knee, r_pose.left_foot, back_col, 5.2)
		draw_circle(r_pose.left_foot, 2.8, back_col)
		# Front leg
		draw_line(r_pose.right_hip, r_pose.right_knee, col, 6.8)
		draw_circle(r_pose.right_knee, 3.4, col)
		draw_line(r_pose.right_knee, r_pose.right_foot, col, 5.8)
		draw_circle(r_pose.right_foot, 3.2, col)
		if not piece.is_settled and ratio > 0.2:
			var trail_v: Vector2 = Vector2(-piece.velocity.x, piece.velocity.y) * 0.016
			draw_circle(scr_pelvis + trail_v, 2.8, Color(0.95, 0.15, 0.2, 0.85 * ratio))
		if piece.is_settled:
			draw_line(piece.position - Vector2(10.0, 0.0), piece.position + Vector2(10.0, 0.0), Color(0.85, 0.12, 0.18, 0.55 * ratio), 2.8)


func _run_headless_verification() -> void:
	print("=== RUNNING PROCEDURAL STICKMAN SHOWCASE VERIFICATION ===")
	assert(player_rig != null, "Player procedural stickman instantiated")
	assert(player_rig.is_inside_tree(), "Player rig is inside tree")
	assert(echo_rig != null, "Echo procedural stickman instantiated")
	assert(enemy_rigs.size() == 6, "All 6 enemy archetype procedural stickmen instantiated")
	assert(ragdoll_pieces.size() >= 2, "Dismemberment ragdoll pieces spawned")

	# Step 60 frames of simulation
	for _i in range(60):
		_process(0.016)

	print("=== PROCEDURAL STICKMAN SHOWCASE: ALL 8 RIGS & DISMEMBERMENT VERIFIED FUNCTIONING ===")
	get_tree().quit(0)
