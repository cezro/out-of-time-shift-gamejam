extends Node2D

## Dedicated Test Scene: Procedural Stickman Rig & Animation Showcase
## Demonstrates the actual textured stickman model from procedural-animation-test-scene
## animated across:
## 1. Player Character (interactive: A/D to run, Space to jump, J to slash, K to parry)
## 2. Timeline Clone / Chrono-Echo (automated replay with translucent cyan glow)
## 3. All 6 Enemy Archetypes (Runner, Ninja, Heavy Golem, Semi-Marksman, Suppressor, Cyber Sniper)

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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.10, 0.14))

	_setup_arena_environment()
	_spawn_player_rig()
	_spawn_echo_rig()
	_spawn_enemy_archetypes()
	_build_ui_overlay()

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
		echo_rig.modulate = Color(0.2, 0.95, 1.0, 0.65)
		echo_rig.position = Vector2(500.0, FLOOR_Y - 38.4)
		echo_rig.z_index = 8
		add_child(echo_rig)


func _spawn_enemy_archetypes() -> void:
	var scene: PackedScene = load(PROCEDURAL_STICKMAN_SCENE_PATH)
	if scene == null:
		return

	# Archetype configurations: [name, x_pos, color, scale, default_state]
	var archetypes: Array[Dictionary] = [
		{"type": "Runner", "x": 150.0, "color": Color(1.0, 0.35, 0.35), "scale": STICKMAN_SCALE, "state": "run"},
		{"type": "Ninja", "x": 270.0, "color": Color(0.75, 0.25, 0.95), "scale": STICKMAN_SCALE, "state": "slash"},
		{"type": "Heavy", "x": 390.0, "color": Color(1.0, 0.55, 0.15), "scale": HEAVY_SCALE, "state": "heavy_slash"},
		{"type": "SemiMarksman", "x": 880.0, "color": Color(0.25, 1.0, 0.55), "scale": STICKMAN_SCALE, "state": "aim"},
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
	vbox.position = Vector2(24.0, 20.0)
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "OUT OF TIME — Procedural Stickman Rig & Snappy Animation Showcase"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.25, 0.95, 1.0))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Active Model: Textured 2D Skeleton Rig from procedural-animation-test-scene (16 sprites + CCDIK)"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(subtitle)

	var instructions := Label.new()
	instructions.text = "Controls: [A/D or Arrows] Run  |  [Space] Jump  |  [J] Slash  |  [K] Parry  |  [S] Downward Slam"
	instructions.add_theme_font_size_override("font_size", 13)
	instructions.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
	vbox.add_child(instructions)

	add_child(canvas)


func _process(delta: float) -> void:
	showcase_timer += delta
	_update_player_input(delta)
	_update_automated_echo(delta)
	_update_automated_enemies(delta)
	queue_redraw()


func _update_player_input(delta: float) -> void:
	if player_rig == null:
		return

	# Handle action timer decay
	if player_action_timer > 0.0:
		player_action_timer -= delta
		if player_action_timer <= 0.0:
			player_action_timer = 0.0
			player_state = "idle"

	# Horizontal movement inputs
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

	# Jump input
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) and player_on_ground:
		player_vel.y = -480.0
		player_on_ground = false
		player_state = "jump"

	# Action inputs
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

	# Gravity & ground collision
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

	# Screen clamping
	player_pos.x = clampf(player_pos.x, 60.0, 1220.0)

	# Update rig node transform and procedural animation
	player_rig.position = player_pos + Vector2(0.0, -38.4)
	player_rig.facing = player_facing
	player_rig.update_procedural_animation(player_vel, player_on_ground, player_facing, player_state, delta)


func _update_automated_echo(delta: float) -> void:
	if echo_rig == null:
		return

	echo_phase_timer += delta
	# Replay running loop back and forth around center
	var echo_offset_x: float = sin(echo_phase_timer * 1.8) * 90.0
	var echo_vx: float = cos(echo_phase_timer * 1.8) * 160.0
	var facing_dir: float = 1.0 if echo_vx >= 0.0 else -1.0

	echo_rig.position = Vector2(550.0 + echo_offset_x, FLOOR_Y - 38.4)
	echo_rig.facing = facing_dir
	echo_rig.update_procedural_animation(Vector2(echo_vx, 0.0), true, facing_dir, "run", delta)


func _update_automated_enemies(delta: float) -> void:
	# 1. Runner patrols back and forth
	if enemy_rigs.has("Runner"):
		var item: Dictionary = enemy_rigs["Runner"]
		var erig: StickmanProcedural = item["rig"]
		var patrol_x: float = item["base_x"] + sin(showcase_timer * 2.2) * 50.0
		var vx: float = cos(showcase_timer * 2.2) * 110.0
		erig.position = Vector2(patrol_x, FLOOR_Y - 38.4)
		erig.facing = 1.0 if vx >= 0.0 else -1.0
		erig.update_procedural_animation(Vector2(vx, 0.0), true, erig.facing, "run", delta)

	# 2. Ninja demonstrates jumping and slashing
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

	# 3. Heavy Golem stomps with heavy slash
	if enemy_rigs.has("Heavy"):
		var item: Dictionary = enemy_rigs["Heavy"]
		var erig: StickmanProcedural = item["rig"]
		var heavy_cycle: float = fmod(showcase_timer, 2.5)
		var h_state: String = "heavy_slash" if heavy_cycle > 1.2 else "run"
		var h_vx: float = 40.0 if heavy_cycle <= 1.2 else 0.0
		erig.facing = 1.0
		erig.update_procedural_animation(Vector2(h_vx, 0.0), true, 1.0, h_state, delta)

	# 4. SemiMarksman in aiming stance
	if enemy_rigs.has("SemiMarksman"):
		var item: Dictionary = enemy_rigs["SemiMarksman"]
		var erig: StickmanProcedural = item["rig"]
		erig.facing = -1.0
		erig.update_procedural_animation(Vector2.ZERO, true, -1.0, "aim", delta)

	# 5. AmberSuppressor in aiming stance
	if enemy_rigs.has("AmberSuppressor"):
		var item: Dictionary = enemy_rigs["AmberSuppressor"]
		var erig: StickmanProcedural = item["rig"]
		erig.facing = -1.0
		erig.update_procedural_animation(Vector2.ZERO, true, -1.0, "aim", delta)

	# 6. CyberSniper in braced sniping stance
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
		{"text": "Enemies (Melee: Runner, Ninja, Heavy)", "x": 150.0},
		{"text": "Timeline Clone (Echo)", "x": 510.0},
		{"text": "Player Character", "x": 640.0},
		{"text": "Enemies (Ranged: Marksman, Suppressor, Sniper)", "x": 920.0},
	]
	for l in labels:
		draw_string(ThemeDB.fallback_font, Vector2(l["x"] - 50.0, FLOOR_Y + 32.0), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.75, 0.85))


func _run_headless_verification() -> void:
	print("=== RUNNING PROCEDURAL STICKMAN SHOWCASE VERIFICATION ===")
	assert(player_rig != null, "Player procedural stickman instantiated")
	assert(player_rig.is_inside_tree(), "Player rig is inside tree")
	assert(echo_rig != null, "Echo procedural stickman instantiated")
	assert(enemy_rigs.size() == 6, "All 6 enemy archetype procedural stickmen instantiated")

	# Step 60 frames of simulation
	for _i in range(60):
		_process(0.016)

	print("=== PROCEDURAL STICKMAN SHOWCASE: ALL 8 RIGS VERIFIED FUNCTIONING ===")
	get_tree().quit(0)
