class_name GameController
extends Node2D

## Main Scene Controller, Deterministic Simulation Loop, Procedural + Modular Renderer, and HUD
## for OUT OF TIME — Chronos Shift.
##
## Coordinate Convention:
## All simulation math uses +Y = UP (floor_y = -260.0, jump_force = +580.0, GATE_CENTER = Vector2(480, 150)).
## Godot Node2D._draw() and screen coordinates use +Y = DOWN; convert via to_screen() and to_sim().

const FLOOR_Y: float = -260.0
const ARENA_HALF_WIDTH: float = 580.0
const CEILING_Y: float = 360.0


class GhostTrailData extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var facing: float = 1.0
	var velocity: Vector2 = Vector2.ZERO
	var is_grounded: bool = true
	var anim_time: float = 0.0
	var is_attacking: bool = false
	var attack_progress: float = 0.0
	var stance: String = "normal"
	var timer: float = 0.25
	var max_timer: float = 0.25
	var color: Color = Color(0.0, 0.85, 1.0, 0.55)
	var era: int = 1
	var loadout_id: String = "player_shift_staff"

	func _init(
		p_pos: Vector2 = Vector2.ZERO,
		p_facing: float = 1.0,
		p_vel: Vector2 = Vector2.ZERO,
		p_grounded: bool = true,
		p_anim_time: float = 0.0,
		p_stance: String = "normal",
		p_duration: float = 0.25,
		p_color: Color = Color(0.0, 0.85, 1.0, 0.55),
		p_era: int = 1,
		p_loadout_id: String = "player_shift_staff"
	) -> void:
		position = p_pos
		facing = p_facing
		velocity = p_vel
		is_grounded = p_grounded
		anim_time = p_anim_time
		stance = p_stance
		timer = p_duration
		max_timer = p_duration
		color = p_color
		era = p_era
		loadout_id = p_loadout_id


# ---------------------------------------------------------------------------------------------
# Coordinate Conversion Helpers (+Y Up Sim <-> +Y Down Screen)
# ---------------------------------------------------------------------------------------------

static func to_screen(sim_pos: Vector2) -> Vector2:
	return Vector2(sim_pos.x, -sim_pos.y)


static func to_sim(screen_pos: Vector2) -> Vector2:
	return Vector2(screen_pos.x, -screen_pos.y)


# ---------------------------------------------------------------------------------------------
# Core State Instances
# ---------------------------------------------------------------------------------------------

var chrono: ChronoState = ChronoState.new()
var player: PlayerKinematics.PlayerState = PlayerKinematics.PlayerState.new()
var energy: PlayerKinematics.ChronoEnergy = PlayerKinematics.ChronoEnergy.new()
var combo: CombatMath.ComboState = CombatMath.ComboState.new()
var wave_mgr: EnemyAI.WaveManager = EnemyAI.WaveManager.new()
var shifter: ChronoShiftModel.ChronoShifterState = ChronoShiftModel.ChronoShifterState.new()
var timeline: TimelineSystem.TimelineState = TimelineSystem.TimelineState.new()
var asset_registry: ModularAssetSystem.ModularAssetRegistry = ModularAssetSystem.ModularAssetRegistry.new()
var audio_mgr: GameAudioManager = null

# ---------------------------------------------------------------------------------------------
# Active Entity Arrays
# ---------------------------------------------------------------------------------------------

var enemies: Array = []
var bullets: Array = []
var ragdolls: Array = []
var particles: Array = []
var ghost_trails: Array = []
var slash_visuals: Array = []
var warp_visuals: Array = []
var shockwave_visuals: Array = []

# ---------------------------------------------------------------------------------------------
# Animation, Camera, Input & Customization State
# ---------------------------------------------------------------------------------------------

var anim_time: float = 0.0
var camera: Camera2D = null
var camera_sim_pos: Vector2 = Vector2.ZERO
var last_aim_world: Vector2 = Vector2(120.0, -240.0)
var last_stance: String = "normal"
var attack_anim_timer: float = 0.0
var attack_anim_duration: float = 0.18
var ghost_spawn_timer: float = 0.0
var customization_tier: int = 0
var customization_cycle_count: int = 0
var _runtime_badge_texture: Texture2D = null
var draw_call_count: int = 0
var last_draw_primitive_count: int = 0
var _can_issue_canvas_draws: bool = false
var _is_in_canvas_draw_pass: bool = false
var ghost_distance_accum: float = 0.0
var ghost_last_pos: Vector2 = Vector2.ZERO
var player_dynamics_ctx: ModularAssetSystem.PoseDynamicsContext = ModularAssetSystem.PoseDynamicsContext.new()
var player_prev_vx: float = 0.0
var player_accel_x: float = 0.0
var player_dt_last: float = 0.016
var player_rig: StickmanProcedural = null
var _echo_rig_pool: Array = []
var _enemy_rig_pool: Array = []
const MAX_ECHO_RIGS: int = 4

# Hardware input accumulators for live _process loop
var _hw_mouse_drag: Vector2 = Vector2.ZERO
var _hw_wheel_steps: int = 0
var _hw_jump_pressed: bool = false
var _hw_dash_pressed: bool = false
var _hw_slash_pressed: bool = false
var _hw_heavy_pressed: bool = false
var _hw_parry_pressed: bool = false
var _hw_warp_pressed: bool = false
var _hw_shift_jump_to: int = -1
var _hw_timeline_shift_pressed: bool = false
var _hw_toggle_mode_pressed: bool = false
var _hw_cycle_custom_pressed: bool = false
var _hw_reset_pressed: bool = false

# ---------------------------------------------------------------------------------------------
# HUD Nodes
# ---------------------------------------------------------------------------------------------

var hud_layer: CanvasLayer = null
var health_bar: ProgressBar = null
var health_label: Label = null
var energy_bar: ProgressBar = null
var energy_label: Label = null
var era_label: Label = null
var rig_label: Label = null
var wave_label: Label = null
var dilation_banner_label: Label = null
var score_label: Label = null
var combo_label: Label = null
var style_rank_label: Label = null
var shifter_readout_label: Label = null
var controls_label: Label = null


func _init() -> void:
	audio_mgr = GameAudioManager.new()
	audio_mgr.name = "GameAudioManager"
	player.loadout_id = "player_shift_staff"
	player.position = Vector2(0.0, FLOOR_Y)
	player.is_grounded = true
	_init_runtime_badge_texture()
	_load_manifest_if_present()


func _ready() -> void:
	_ensure_scene_nodes()
	_update_hud()
	queue_redraw()


func _init_runtime_badge_texture() -> void:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.92, 1.0, 1.0))
	for x in range(4, 12):
		for y in range(4, 12):
			img.set_pixel(x, y, Color(0.95, 0.78, 0.25, 1.0))
	_runtime_badge_texture = ImageTexture.create_from_image(img)


func _load_manifest_if_present() -> void:
	var manifest_path: String = "res://assets/modular_parts_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var f := FileAccess.open(manifest_path, FileAccess.READ)
		if f != null:
			var json_str: String = f.get_as_text()
			f.close()
			asset_registry.load_manifest_json(json_str)


func _ensure_scene_nodes() -> void:
	if audio_mgr == null:
		audio_mgr = GameAudioManager.new()
		audio_mgr.name = "GameAudioManager"
	if audio_mgr.get_parent() == null:
		add_child(audio_mgr)

	if camera == null:
		camera = Camera2D.new()
		camera.name = "MainCamera2D"
		camera.position = Vector2.ZERO
		camera.enabled = true
		add_child(camera)

	if hud_layer == null:
		_build_hud()

	_ensure_player_rig()
	_init_echo_rig_pool()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW:
		_is_in_canvas_draw_pass = true


func _exit_tree() -> void:
	if audio_mgr != null and is_instance_valid(audio_mgr):
		audio_mgr.stop_all()
	for erig in _echo_rig_pool:
		if is_instance_valid(erig) and erig.get_parent() == null:
			erig.free()
	_echo_rig_pool.clear()
	for erig in _enemy_rig_pool:
		if is_instance_valid(erig) and erig.get_parent() == null:
			erig.free()
	_enemy_rig_pool.clear()


func _ensure_player_rig() -> void:
	if player_rig == null and is_inside_tree():
		player_rig = get_node_or_null("Player") as StickmanProcedural
		if player_rig == null:
			var rig_node = asset_registry.instantiate_rig("player_procedural_stickman")
			if rig_node is CharacterBody2D:
				player_rig = rig_node as StickmanProcedural
				player_rig.name = "Player"
				add_child(player_rig)
		if player_rig != null:
			player_rig.autonomous_physics = false
			player_rig.visible = true
			player_rig.scale = Vector2(0.12, 0.12)
			player_rig.modulate = Color(0.96, 0.98, 1.0, 1.0)
			player_rig.z_index = 5


func _init_echo_rig_pool() -> void:
	if not _echo_rig_pool.is_empty() or not is_inside_tree():
		return
	for i in range(MAX_ECHO_RIGS):
		var rig_node = asset_registry.instantiate_rig("player_procedural_stickman")
		if rig_node is CharacterBody2D:
			var sp := rig_node as StickmanProcedural
			sp.autonomous_physics = false
			sp.visible = false
			sp.scale = Vector2(0.12, 0.12)
			sp.z_index = 4
			sp.name = "EchoRig_%d" % i
			add_child(sp)
			_echo_rig_pool.append(sp)


func _update_echo_rigs(real_dt: float) -> void:
	if _echo_rig_pool.is_empty() or not is_inside_tree():
		return
	var active_echoes: Array = timeline.echoes
	for i in range(_echo_rig_pool.size()):
		var rig = _echo_rig_pool[i]
		if rig is StickmanProcedural:
			var sp: StickmanProcedural = rig as StickmanProcedural
			if i < active_echoes.size():
				var echo: TimelineSystem.ChronoEchoData = active_echoes[i]
				var e_alpha: float = 0.75 if echo.era == timeline.current_era else 0.30
				sp.visible = true
				sp.global_position = to_screen(echo.origin) + Vector2(0.0, -38.4)
				sp.scale = Vector2(0.12, 0.12)
				sp.facing = echo.facing
				sp.modulate = Color(0.2, 0.95, 1.0, e_alpha)
				var godot_vel := Vector2(echo.velocity.x, -echo.velocity.y)
				sp.update_procedural_animation(godot_vel, echo.is_grounded, echo.facing, echo.stance, real_dt)
			else:
				sp.visible = false


func _ensure_enemy_rig_pool(count: int) -> void:
	if not is_inside_tree():
		return
	while _enemy_rig_pool.size() < count:
		var rig_node = asset_registry.instantiate_rig("player_procedural_stickman")
		if rig_node is CharacterBody2D:
			var erig := rig_node as StickmanProcedural
			erig.autonomous_physics = false
			erig.visible = false
			erig.scale = Vector2(0.12, 0.12)
			erig.z_index = 4
			erig.name = "EnemyRig_%d" % _enemy_rig_pool.size()
			add_child(erig)
			_enemy_rig_pool.append(erig)
		else:
			break


func _update_enemy_rigs(dt: float) -> void:
	if not is_inside_tree():
		return
	_ensure_enemy_rig_pool(enemies.size())
	for i in range(_enemy_rig_pool.size()):
		var rig = _enemy_rig_pool[i]
		if not (rig is StickmanProcedural):
			continue
		var erig := rig as StickmanProcedural
		if i < enemies.size():
			var enemy: EnemyAI.EnemyData = enemies[i]
			if enemy == null:
				erig.visible = false
				continue
			var is_active_era: bool = (enemy.era == timeline.current_era or timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL)
			var e_alpha: float = 1.0 if is_active_era else 0.28
			erig.visible = true
			erig.global_position = to_screen(enemy.position) + Vector2(0.0, -38.4)
			var base_scale: float = 0.15 if enemy.enemy_type == EnemyAI.EnemyType.HEAVY else 0.12
			erig.scale = Vector2(base_scale, base_scale)
			erig.facing = enemy.facing

			match enemy.enemy_type:
				EnemyAI.EnemyType.RUNNER:
					erig.modulate = Color(1.0, 0.35, 0.35, e_alpha)
				EnemyAI.EnemyType.NINJA:
					erig.modulate = Color(0.75, 0.25, 0.95, e_alpha)
				EnemyAI.EnemyType.HEAVY:
					erig.modulate = Color(1.0, 0.55, 0.15, e_alpha)
				EnemyAI.EnemyType.GUNNER_SEMI:
					erig.modulate = Color(0.25, 1.0, 0.55, e_alpha)
				EnemyAI.EnemyType.GUNNER_AUTO:
					erig.modulate = Color(1.0, 0.85, 0.2, e_alpha)
				EnemyAI.EnemyType.SNIPER:
					erig.modulate = Color(0.2, 0.75, 1.0, e_alpha)
				_:
					erig.modulate = Color(1.0, 0.4, 0.4, e_alpha)

			var e_state := "idle"
			if enemy.state == EnemyAI.StateKind.ATTACK:
				e_state = "heavy_slash" if enemy.enemy_type == EnemyAI.EnemyType.HEAVY else "slash"
			elif enemy.state == EnemyAI.StateKind.WINDUP:
				e_state = "parry_guard"
			elif not enemy.is_grounded:
				e_state = "jump"
			elif absf(enemy.velocity.x) > 10.0:
				e_state = "run"

			var godot_vel := Vector2(enemy.velocity.x, -enemy.velocity.y)
			erig.update_procedural_animation(godot_vel, enemy.is_grounded, enemy.facing, e_state, dt)
		else:
			erig.visible = false


func _resolve_player_anim_state() -> String:
	if player.parry_timer > 0.0:
		return "parry_guard"
	if attack_anim_timer > 0.0:
		if last_stance == "heavy_slash":
			return "heavy_slash"
		return "slash"
	if player.is_slamming:
		return "downward_slam"
	if player.is_wall_sliding:
		return "wall_slide"
	if player.is_climbing_vine:
		return "air"
	if not player.is_grounded:
		return "jump" if player.velocity.y > 0.0 else "fall"
	if player.dash_timer > 0.0 or absf(player.velocity.x) > 15.0:
		return "run"
	return "idle"


func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)

	# --- TOP-LEFT PANEL: Health, Chrono Energy, Era Indicator, Modular Rig Status ---
	var top_left := VBoxContainer.new()
	top_left.name = "TopLeftHUD"
	top_left.position = Vector2(18.0, 14.0)
	top_left.custom_minimum_size = Vector2(360.0, 120.0)
	hud_layer.add_child(top_left)

	var hp_row := HBoxContainer.new()
	top_left.add_child(hp_row)
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "HP: 100 / 100"
	health_label.custom_minimum_size = Vector2(120.0, 22.0)
	health_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38, 1.0))
	hp_row.add_child(health_label)

	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(210.0, 18.0)
	hp_row.add_child(health_bar)

	var en_row := HBoxContainer.new()
	top_left.add_child(en_row)
	energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.text = "CHRONO: 100%"
	energy_label.custom_minimum_size = Vector2(120.0, 22.0)
	energy_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	en_row.add_child(energy_label)

	energy_bar = ProgressBar.new()
	energy_bar.name = "EnergyBar"
	energy_bar.min_value = 0.0
	energy_bar.max_value = 100.0
	energy_bar.value = 100.0
	energy_bar.show_percentage = false
	energy_bar.custom_minimum_size = Vector2(210.0, 18.0)
	en_row.add_child(energy_bar)

	era_label = Label.new()
	era_label.name = "EraLabel"
	era_label.text = "ERA: PRESENT [INDUSTRIAL CLOCKWORK]"
	era_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.35, 1.0))
	top_left.add_child(era_label)

	rig_label = Label.new()
	rig_label.name = "RigLabel"
	rig_label.text = "RIG: Chronos Nomad [7 Weapon / 18 Body Parts]"
	rig_label.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0, 0.92))
	top_left.add_child(rig_label)

	# --- TOP-CENTER PANEL: Wave / Campaign Zone & Dilation Banner ---
	var top_center := VBoxContainer.new()
	top_center.name = "TopCenterHUD"
	top_center.position = Vector2(420.0, 14.0)
	top_center.custom_minimum_size = Vector2(440.0, 80.0)
	hud_layer.add_child(top_center)

	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.text = "HORDE ARENA — WAVE 1 [INTERMISSION]"
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
	top_center.add_child(wave_label)

	dilation_banner_label = Label.new()
	dilation_banner_label.name = "DilationBannerLabel"
	dilation_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dilation_banner_label.text = ""
	dilation_banner_label.add_theme_color_override("font_color", Color(0.15, 0.98, 1.0, 1.0))
	top_center.add_child(dilation_banner_label)

	# --- TOP-RIGHT PANEL: Score, Combo, DMC Style Rank Badge, Shifter Readout ---
	var top_right := VBoxContainer.new()
	top_right.name = "TopRightHUD"
	top_right.position = Vector2(880.0, 14.0)
	top_right.custom_minimum_size = Vector2(380.0, 320.0)
	hud_layer.add_child(top_right)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.text = "SCORE: 0"
	score_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1.0))
	top_right.add_child(score_label)

	combo_label = Label.new()
	combo_label.name = "ComboLabel"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.text = "COMBO: 0 (1x)"
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25, 1.0))
	top_right.add_child(combo_label)

	style_rank_label = Label.new()
	style_rank_label.name = "StyleRankLabel"
	style_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	style_rank_label.text = "STYLE: D"
	style_rank_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1.0))
	top_right.add_child(style_rank_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 195.0)
	top_right.add_child(spacer)

	shifter_readout_label = Label.new()
	shifter_readout_label.name = "ShifterReadoutLabel"
	shifter_readout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shifter_readout_label.text = "GEAR N  ·  1.00x  ·  DRAIN 0/s"
	shifter_readout_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38, 1.0))
	top_right.add_child(shifter_readout_label)

	# --- BOTTOM PANEL: Controls Reference Guide ---
	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.position = Vector2(16.0, 690.0)
	controls_label.custom_minimum_size = Vector2(1248.0, 24.0)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.text = "[A/D] Move  [W/Space] Jump/Wall-Jump  [E] Dash  [LMB/J] Slash  [S+LMB] Slam  [RMB/K] Launch  [F] Parry  [Q] Warp  [Hold Shift] Chronos Gear (1-6/0/R)  [Tab/C] Era Shift  [M] Mode  [P] Rig Custom  [R] Reset"
	controls_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92, 0.88))
	hud_layer.add_child(controls_label)


# ---------------------------------------------------------------------------------------------
# Live OS Input Event Collection & _process Loop
# ---------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if Input.is_key_pressed(KEY_SHIFT):
			# Screen +Y is down, gate +Y is up -> negate relative.y
			_hw_mouse_drag += Vector2(mm.relative.x, -mm.relative.y) / ChronoShiftModel.DRAG_PX_PER_UNIT

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					_hw_slash_pressed = true
				MOUSE_BUTTON_RIGHT:
					_hw_heavy_pressed = true
				MOUSE_BUTTON_MIDDLE:
					_hw_dash_pressed = true
				MOUSE_BUTTON_WHEEL_UP:
					if Input.is_key_pressed(KEY_SHIFT):
						_hw_wheel_steps += 1
				MOUSE_BUTTON_WHEEL_DOWN:
					if Input.is_key_pressed(KEY_SHIFT):
						_hw_wheel_steps -= 1

	elif event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo:
			var shift_down: bool = Input.is_key_pressed(KEY_SHIFT) or ke.shift_pressed
			match ke.keycode:
				KEY_W, KEY_SPACE, KEY_UP:
					_hw_jump_pressed = true
				KEY_E:
					_hw_dash_pressed = true
				KEY_J:
					_hw_slash_pressed = true
				KEY_K:
					_hw_heavy_pressed = true
				KEY_F:
					_hw_parry_pressed = true
				KEY_Q:
					_hw_warp_pressed = true
				KEY_TAB, KEY_C:
					_hw_timeline_shift_pressed = true
				KEY_M:
					_hw_toggle_mode_pressed = true
				KEY_P:
					_hw_cycle_custom_pressed = true
				KEY_0, KEY_QUOTELEFT:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.N
				KEY_1:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G1
				KEY_2:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G2
				KEY_3:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G3
				KEY_4:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G4
				KEY_5:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G5
				KEY_6:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.G6
				KEY_R:
					if shift_down:
						_hw_shift_jump_to = ChronoShiftModel.Gear.R
					else:
						_hw_reset_pressed = true


func _poll_hardware_input() -> Dictionary:
	var move_x: float = 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_x += 1.0

	var down_held: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var jump_held: bool = (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_UP)
	)
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)

	var mouse_screen: Vector2 = get_global_mouse_position()
	var mouse_sim: Vector2 = to_sim(mouse_screen)

	var hw: Dictionary = {
		"move_x": move_x,
		"down_held": down_held,
		"jump_held": jump_held,
		"jump_pressed": _hw_jump_pressed,
		"dash_pressed": _hw_dash_pressed,
		"slash_pressed": _hw_slash_pressed,
		"heavy_pressed": _hw_heavy_pressed,
		"parry_pressed": _hw_parry_pressed,
		"warp_pressed": _hw_warp_pressed,
		"shift_held": shift_held,
		"shift_drag": _hw_mouse_drag,
		"shift_wheel": _hw_wheel_steps,
		"shift_gear": _hw_shift_jump_to,
		"timeline_shift": _hw_timeline_shift_pressed,
		"toggle_mode": _hw_toggle_mode_pressed,
		"cycle_customization": _hw_cycle_custom_pressed,
		"reset": _hw_reset_pressed,
		"aim_world": mouse_sim,
		"cursor_screen": mouse_screen,
	}

	_hw_mouse_drag = Vector2.ZERO
	_hw_wheel_steps = 0
	_hw_jump_pressed = false
	_hw_dash_pressed = false
	_hw_slash_pressed = false
	_hw_heavy_pressed = false
	_hw_parry_pressed = false
	_hw_warp_pressed = false
	_hw_shift_jump_to = -1
	_hw_timeline_shift_pressed = false
	_hw_toggle_mode_pressed = false
	_hw_cycle_custom_pressed = false
	_hw_reset_pressed = false

	return hw


func _process(delta: float) -> void:
	step_simulation(delta, _poll_hardware_input())


# ---------------------------------------------------------------------------------------------
# Public Gameplay Operations (Reset, Mode Toggle, Timeline Shift, Modular Customization)
# ---------------------------------------------------------------------------------------------

func reset_game() -> void:
	chrono.reset()
	player.reset()
	player.loadout_id = "player_shift_staff"
	energy.reset()
	combo.reset()
	wave_mgr.reset()
	shifter = ChronoShiftModel.ChronoShifterState.new()

	enemies.clear()
	bullets.clear()
	ragdolls.clear()
	particles.clear()
	ghost_trails.clear()
	slash_visuals.clear()
	warp_visuals.clear()
	shockwave_visuals.clear()

	if timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL:
		timeline.setup_campaign_traversal()
		player.position = timeline.checkpoint_pos
		_spawn_campaign_enemies()
	else:
		timeline.setup_horde_arena()
		player.position = Vector2(0.0, FLOOR_Y)

	player.is_grounded = true
	camera_sim_pos = Vector2(player.position.x if timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL else 0.0, 0.0)
	_ensure_scene_nodes()
	_update_camera(0.0)
	_update_hud()
	queue_redraw()


func toggle_game_mode() -> int:
	if timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
		timeline.setup_campaign_traversal()
		enemies.clear()
		bullets.clear()
		ragdolls.clear()
		particles.clear()
		player.reset()
		player.loadout_id = "player_shift_staff"
		player.position = timeline.checkpoint_pos
		player.is_grounded = true
		_spawn_campaign_enemies()
	else:
		timeline.setup_horde_arena()
		enemies.clear()
		bullets.clear()
		ragdolls.clear()
		particles.clear()
		wave_mgr.reset()
		player.reset()
		player.loadout_id = "player_shift_staff"
		player.position = Vector2(0.0, FLOOR_Y)
		player.is_grounded = true
		camera_sim_pos = Vector2.ZERO

	_update_hud()
	queue_redraw()
	return timeline.mode


func _spawn_campaign_enemies() -> void:
	enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.RUNNER, Vector2(300.0, -200.0), TimelineSystem.TimelineEra.PAST))
	enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.GUNNER_SEMI, Vector2(620.0, -200.0), TimelineSystem.TimelineEra.PRESENT))
	enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.SNIPER, Vector2(980.0, -200.0), TimelineSystem.TimelineEra.FUTURE))
	enemies.append(EnemyAI.EnemyData.new(EnemyAI.EnemyType.HEAVY, Vector2(1550.0, 120.0), TimelineSystem.TimelineEra.PRESENT))


## Cycles modular piece-by-piece cosmetic armor and weapon attachments on "player_shift_staff"
## at runtime to showcase live procedural/polygon/texture piece injection.
func cycle_player_modular_customization() -> int:
	customization_cycle_count += 1
	customization_tier = (customization_tier + 1) % 4
	var loadout_id: String = "player_shift_staff"

	match customization_tier:
		1:
			# Tier 1: Clockwork Cyber-Crown Helmet + Twin Chrono Pauldrons + Overclocked Key Teeth
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_chrono_crown_helm",
				"slot": ModularAssetSystem.PartSlot.HAT_HELMET,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [
					Vector2(-8.0, 0.0),
					Vector2(-5.0, 10.0),
					Vector2(0.0, 6.0),
					Vector2(5.0, 10.0),
					Vector2(8.0, 0.0),
				],
				"primary_color": Color(0.95, 0.78, 0.25, 1.0),
				"secondary_color": Color(0.0, 0.95, 1.0, 1.0),
				"line_width": 2.4,
			})
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_chrono_pauldron_l",
				"slot": ModularAssetSystem.PartSlot.UPPER_ARM_L,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-5.0, -4.0), Vector2(5.0, -4.0), Vector2(6.0, 5.0), Vector2(-4.0, 5.0)],
				"primary_color": Color(0.0, 0.90, 1.0, 0.95),
			})
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_chrono_pauldron_r",
				"slot": ModularAssetSystem.PartSlot.UPPER_ARM_R,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-5.0, -4.0), Vector2(5.0, -4.0), Vector2(6.0, 5.0), Vector2(-4.0, 5.0)],
				"primary_color": Color(0.0, 0.90, 1.0, 0.95),
			})
			asset_registry.apply_weapon_piece_to_loadout(loadout_id, {
				"piece_id": "custom_overclocked_key_teeth",
				"piece_slot": ModularAssetSystem.WeaponPieceSlot.KEY_TEETH,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-2.0, -2.0), Vector2(6.0, -2.0), Vector2(6.0, 11.0), Vector2(-2.0, 11.0)],
				"color": Color(1.0, 0.84, 0.28, 1.0),
				"glow_color": Color(0.2, 1.0, 1.0, 0.9),
				"rotates_with_gear": true,
				"key_tooth_length": 13.5,
			})

		2:
			# Tier 2: Aegis Breastplate + Kinetic Greaves + Upper Shaft Resonator Ring
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_aegis_breastplate",
				"slot": ModularAssetSystem.PartSlot.TORSO,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-7.0, -9.0), Vector2(7.0, -9.0), Vector2(9.0, 9.0), Vector2(-9.0, 9.0)],
				"primary_color": Color(0.88, 0.72, 0.28, 1.0),
				"secondary_color": Color(0.0, 0.95, 1.0, 1.0),
			})
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_kinetic_greave_l",
				"slot": ModularAssetSystem.PartSlot.SHIN_L,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-3.0, -6.0), Vector2(3.0, -6.0), Vector2(4.0, 6.0), Vector2(-4.0, 6.0)],
				"primary_color": Color(0.15, 0.95, 1.0, 1.0),
			})
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_kinetic_greave_r",
				"slot": ModularAssetSystem.PartSlot.SHIN_R,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(-3.0, -6.0), Vector2(3.0, -6.0), Vector2(4.0, 6.0), Vector2(-4.0, 6.0)],
				"primary_color": Color(0.15, 0.95, 1.0, 1.0),
			})
			asset_registry.apply_weapon_piece_to_loadout(loadout_id, {
				"piece_id": "custom_upper_resonator_shaft",
				"piece_slot": ModularAssetSystem.WeaponPieceSlot.SHAFT_UPPER,
				"backend": ModularAssetSystem.AssetRenderBackend.PROCEDURAL_VECTOR,
				"length": 11.0,
				"thickness": 3.4,
				"color": Color(0.95, 0.78, 0.28, 1.0),
				"glow_color": Color(0.2, 1.0, 1.0, 0.9),
				"rotates_with_gear": true,
				"key_tooth_length": 5.0,
			})

		3:
			# Tier 3: Texture Sprite Hood Crest + Singularity Blade Edge + Optic Scope
			asset_registry.apply_part_to_loadout(loadout_id, {
				"part_id": "custom_sprite_crest_helm",
				"slot": ModularAssetSystem.PartSlot.HAT_HELMET,
				"backend": ModularAssetSystem.AssetRenderBackend.TEXTURE_SPRITE,
				"texture": _runtime_badge_texture,
				"primary_color": Color(1.0, 1.0, 1.0, 1.0),
				"offset": Vector2(0.0, 4.0),
				"scale": Vector2(1.1, 1.1),
			})
			asset_registry.apply_weapon_piece_to_loadout(loadout_id, {
				"piece_id": "custom_singularity_blade",
				"piece_slot": ModularAssetSystem.WeaponPieceSlot.BLADE_EDGE,
				"backend": ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON,
				"polygon_points": [Vector2(0.0, -2.5), Vector2(24.0, -4.5), Vector2(30.0, 0.0), Vector2(24.0, 4.5), Vector2(0.0, 2.5)],
				"color": Color(1.0, 0.25, 0.75, 1.0),
				"glow_color": Color(0.2, 0.95, 1.0, 0.95),
			})

		_:
			# Tier 0: Reset to clean default preset while preserving cycle count
			var fresh_reg := ModularAssetSystem.ModularAssetRegistry.new()
			var default_player := fresh_reg.get_loadout(loadout_id)
			if default_player != null:
				asset_registry.register_loadout(default_player)

	if audio_mgr != null:
		audio_mgr.play_sfx("warp", 1.25)
	_update_hud()
	queue_redraw()
	return customization_tier


## Shifts timeline (PAST -> PRESENT -> FUTURE or to target_era), preserves player momentum,
## and detonates any ChronoEchoes waiting in the newly entered era to slice enemies in that era.
func perform_timeline_shift(target_era: int = -1) -> Dictionary:
	var prev_era: int = timeline.current_era
	var shift_res: Dictionary = timeline.try_shift_timeline(player.position, target_era, false, player.velocity)
	if not shift_res.get("shifted", false):
		return shift_res

	player.velocity = shift_res.get("preserved_velocity", player.velocity)

	ghost_trails.append(GhostTrailData.new(
		player.position,
		player.facing,
		player.velocity,
		player.is_grounded,
		anim_time,
		last_stance,
		0.30,
		 Color(0.4, 0.95, 1.0, 0.6),
		prev_era,
		player.loadout_id
	))

	if audio_mgr != null:
		audio_mgr.play_sfx("warp", 1.15)
	chrono.trigger_shake(4.5)

	# Detonate ChronoEchoes in the target era and slice enemies within each echo's radius!
	var detonated: Array = shift_res.get("detonated_echoes", [])
	var echo_slice_events: Array = []
	var active_enemies_by_id: Dictionary = _build_active_enemies_by_id()

	for echo_var in detonated:
		var echo: TimelineSystem.ChronoEchoData = echo_var
		if echo == null:
			continue

		var sw := CombatMath.ShockwaveVisualData.new()
		sw.origin = echo.origin
		sw.current_radius = 16.0
		sw.max_radius = echo.radius
		sw.timer = 0.26
		sw.duration = 0.26
		sw.color = Color(0.25, 0.95, 1.0, 0.95)
		shockwave_visuals.append(sw)

		for eid in active_enemies_by_id.keys():
			var enemy: EnemyAI.EnemyData = active_enemies_by_id[eid]
			if enemy == null:
				continue
			var enemy_center: Vector2 = enemy.position + Vector2(0.0, 16.0)
			if echo.origin.distance_to(enemy_center) <= echo.radius + enemy.hitbox_radius or echo.origin.distance_to(enemy.position) <= echo.radius + enemy.hitbox_radius:
				var dir: Vector2 = echo.aim_dir if echo.aim_dir.length_squared() > 1e-4 else Vector2(player.facing, 0.0)
				var impulse: Vector2 = dir * 380.0 + Vector2(0.0, 220.0)
				echo_slice_events.append(CombatMath.SliceEventData.new(eid, enemy_center, dir, impulse, true, false, false))

	if not echo_slice_events.is_empty():
		_resolve_slices(echo_slice_events, active_enemies_by_id)

	return shift_res


# ---------------------------------------------------------------------------------------------
# Deterministic Simulation Step
# ---------------------------------------------------------------------------------------------

static func _safe_float(v: Variant, fallback: float = 0.0) -> float:
	if v is float or v is int:
		var f: float = float(v)
		return f if is_finite(f) else fallback
	return fallback


static func _safe_int(v: Variant, fallback: int = 0) -> int:
	if v is int:
		return v
	if v is float:
		return int(v) if is_finite(v) else fallback
	return fallback


func step_simulation(real_dt: float, input_override: Dictionary = {}) -> void:
	_ensure_scene_nodes()

	var dt: float = clampf(real_dt, 0.0, 0.25) if (is_finite(real_dt) and real_dt > 0.0) else 0.0
	anim_time += dt

	# 1. Extract inputs from input_override
	var reset_pressed: bool = bool(input_override.get("reset", input_override.get("reset_game", false)))
	if reset_pressed:
		reset_game()
		return

	var toggle_mode_pressed: bool = bool(input_override.get("toggle_mode", input_override.get("mode_toggle", false)))
	if toggle_mode_pressed:
		toggle_game_mode()

	var cycle_custom_pressed: bool = bool(input_override.get("cycle_customization", input_override.get("customize", false)))
	if cycle_custom_pressed:
		cycle_player_modular_customization()

	var raw_move_x: Variant = input_override.get("move_x", input_override.get("input_x", input_override.get("axis_x", 0.0)))
	var move_x: float = _safe_float(raw_move_x, 0.0)
	if bool(input_override.get("move_left", input_override.get("left", false))):
		move_x -= 1.0
	if bool(input_override.get("move_right", input_override.get("right", false))):
		move_x += 1.0
	move_x = clampf(move_x, -1.0, 1.0) if is_finite(move_x) else 0.0

	var down_held: bool = bool(input_override.get("down_held", input_override.get("down", input_override.get("crouch", false))))
	var jump_pressed: bool = bool(input_override.get("jump_pressed", input_override.get("jump", false)))
	var jump_held: bool = bool(input_override.get("jump_held", jump_pressed))
	var dash_pressed: bool = bool(input_override.get("dash_pressed", input_override.get("dash", false)))
	var slash_pressed: bool = bool(input_override.get("slash_pressed", input_override.get("slash", input_override.get("attack", input_override.get("light_slash", false)))))
	var slam_pressed: bool = bool(input_override.get("downward_slam", input_override.get("slam", false)))
	var heavy_pressed: bool = bool(input_override.get("heavy_pressed", input_override.get("heavy", input_override.get("heavy_slash", input_override.get("launcher", false)))))
	var parry_pressed: bool = bool(input_override.get("parry_pressed", input_override.get("parry", input_override.get("deflect", false))))
	var warp_pressed: bool = bool(input_override.get("warp_pressed", input_override.get("warp", input_override.get("teleport", false))))
	var timeline_shift_pressed: bool = bool(input_override.get("timeline_shift", input_override.get("shift_timeline", input_override.get("tab", false))))
	var target_era_input: int = _safe_int(input_override.get("target_era", -1), -1)

	var shift_jump_to: int = _safe_int(input_override.get("shift_gear", input_override.get("jump_to", input_override.get("gear", -1))), -1)
	var shift_held: bool = bool(input_override.get("shift_held", input_override.get("shift", shift_jump_to >= 0)))
	var shift_drag: Vector2 = Vector2.ZERO
	if input_override.get("shift_drag") is Vector2:
		shift_drag = input_override.get("shift_drag")
	elif input_override.get("drag") is Vector2:
		shift_drag = input_override.get("drag")
	elif input_override.get("mouse_delta") is Vector2:
		var md: Vector2 = input_override.get("mouse_delta")
		if md.is_finite():
			shift_drag = Vector2(md.x, -md.y) / ChronoShiftModel.DRAG_PX_PER_UNIT
	if not shift_drag.is_finite():
		shift_drag = Vector2.ZERO
	var shift_wheel: int = _safe_int(input_override.get("shift_wheel", input_override.get("wheel_steps", 0)), 0)

	var default_aim_world: Vector2 = player.position + Vector2(player.facing * 120.0, 16.0)
	var raw_aim_world: Vector2 = default_aim_world
	if input_override.get("aim_world") is Vector2:
		raw_aim_world = input_override.get("aim_world")
	elif input_override.get("cursor_world") is Vector2:
		raw_aim_world = input_override.get("cursor_world")
	elif input_override.get("aim_pos") is Vector2:
		raw_aim_world = input_override.get("aim_pos")
	elif input_override.get("mouse_world") is Vector2:
		raw_aim_world = input_override.get("mouse_world")
	if not raw_aim_world.is_finite():
		raw_aim_world = default_aim_world
	last_aim_world = raw_aim_world

	var cursor_screen: Variant = input_override.get("cursor_screen", to_screen(raw_aim_world))
	if cursor_screen is Vector2 and not (cursor_screen as Vector2).is_finite():
		cursor_screen = to_screen(raw_aim_world)

	# 2. Step Chronos Shift H-Gate & Time Control
	if not shifter.is_held():
		shifter.frozen_aim = null
	shifter.energy_current = energy.current
	shifter.energy_max = energy.max_energy
	var shifter_input := ChronoShiftModel.ShifterInput.new(shift_held, shift_drag, shift_wheel, shift_jump_to)
	shifter.step_control(shifter_input, dt, raw_aim_world, cursor_screen)

	energy.current = shifter.energy_current
	if shifter.dilation_edge == true:
		audio_mgr.play_sfx("slowmo_enter")
	elif shifter.dilation_edge == false:
		audio_mgr.play_sfx("slowmo_exit")

	chrono.slowmo_factor = shifter.slowmo_factor
	chrono.is_dilating = shifter.is_dilating
	if shifter.screen_shake > 0.0:
		chrono.trigger_shake(shifter.screen_shake)
		shifter.screen_shake = 0.0
	chrono.update(dt)

	shifter.dilation_factor = chrono.dilation_factor
	shifter.hitstop_timer = chrono.hitstop_timer
	shifter.shake_offset = chrono.shake_offset

	var effective_aim: Vector2 = (
		shifter.frozen_aim
		if (shifter.aim_frozen() and shifter.frozen_aim is Vector2)
		else raw_aim_world
	)

	# 3. Timeline Shift (Tab / C)
	if timeline_shift_pressed:
		perform_timeline_shift(target_era_input)

	var player_dt: float = chrono.get_player_dt(dt)
	var turbo_mult: float = shifter.acclimatization.get_turbo_speed_multiplier(shifter.model.get_active_gear())
	player_dt *= turbo_mult

	# 4. Tick Player Cooldowns & Attack Animation Timers
	if attack_anim_timer > 0.0:
		attack_anim_timer = maxf(0.0, attack_anim_timer - dt)
		if attack_anim_timer <= 0.0 and last_stance == "heavy_slash":
			last_stance = "normal"

	if player_dt > 0.0:
		player.dash_cooldown = maxf(0.0, player.dash_cooldown - player_dt)
		player.slash_cooldown = maxf(0.0, player.slash_cooldown - player_dt)
		player.heavy_cooldown = maxf(0.0, player.heavy_cooldown - player_dt)
		player.warp_cooldown = maxf(0.0, player.warp_cooldown - player_dt)
		player.parry_timer = maxf(0.0, player.parry_timer - player_dt)
		player.parry_cooldown = maxf(0.0, player.parry_cooldown - player_dt)
		player.invulnerability_timer = maxf(0.0, player.invulnerability_timer - player_dt)

	if absf(move_x) > 0.01 and player.dash_timer <= 0.0:
		player.facing = signf(move_x)

	# 5. Combat & Dash Initiation
	# 5a. Downward Slam or Light Slash (LMB / J)
	var wants_slam: bool = slam_pressed or (slash_pressed and down_held and not player.is_grounded)
	if wants_slam and not player.is_grounded and not player.is_slamming:
		if PlayerKinematics.start_downward_slam(player):
			last_stance = "downward_slam"
			audio_mgr.play_sfx("slash", 0.8)
	elif slash_pressed:
		_execute_light_slash(effective_aim)

	# 5b. Kinetic Dash (E / Middle Mouse) — runs after slash so dash can cancel slash_cooldown!
	if dash_pressed and player.dash_cooldown <= 0.0:
		if PlayerKinematics.start_dash(player, move_x):
			audio_mgr.play_sfx("dash")
			ghost_spawn_timer = 0.03
			ghost_distance_accum = 0.0
			ghost_last_pos = player.position
			ghost_trails.append(GhostTrailData.new(
				player.position,
				player.facing,
				player.velocity,
				player.is_grounded,
				anim_time,
				"normal",
				0.24,
				Color(0.0, 0.9, 1.0, 0.65),
				timeline.current_era,
				player.loadout_id
			))
			timeline.spawn_chrono_echo(
				player.position + Vector2(0.0, 16.0),
				player.dash_dir,
				timeline.current_era,
				"dash",
				95.0,
				3.0,
				player.facing,
				player.velocity,
				player.is_grounded,
				"normal",
				anim_time,
				player.loadout_id
			)

	# 5c. Heavy Launcher Attack (RMB / K)
	if heavy_pressed and player.heavy_cooldown <= 0.0:
		_execute_heavy_launcher(effective_aim)

	# 5d. Directional Deflect / Parry (F)
	if parry_pressed and player.parry_cooldown <= 0.0:
		player.parry_timer = 0.22
		player.parry_cooldown = 0.35
		last_stance = "parry_guard"
		audio_mgr.play_sfx("slash", 1.35)

	if player.parry_timer > 0.0:
		_process_active_parry_window(effective_aim)
	elif last_stance == "parry_guard":
		last_stance = "normal"

	# 5e. Chrono Warp (Q)
	if warp_pressed:
		_execute_chrono_warp(effective_aim)

	# 6. Step Player Kinematics, Collisions, Slam Shockwave, Jump Pads, Lasers & Lore Glyphs
	if player_dt > 0.0:
		_step_player_movement_and_environment(move_x, down_held, jump_held, jump_pressed, input_override, player_dt)

	# 7. Step World Entities (WaveManager, Enemies, Bullets, Ragdolls, Particles, Visuals)
	var updated_world_dt: float = chrono.get_world_dt(dt)
	_step_world_entities(dt, updated_world_dt, effective_aim)
	_update_echo_rigs(dt)
	_update_enemy_rigs(updated_world_dt)

	# 8. Update Camera & HUD and request redraw
	_update_camera(dt)
	_update_hud()
	queue_redraw()


# ---------------------------------------------------------------------------------------------
# Internal Combat & Movement Helpers
# ---------------------------------------------------------------------------------------------

func _build_active_enemies_by_id() -> Dictionary:
	var dict: Dictionary = {}
	for enemy in enemies:
		if enemy != null and enemy.era == timeline.current_era:
			dict[enemy.get_instance_id()] = enemy
	return dict


func _execute_light_slash(aim_world: Vector2) -> void:
	if player.slash_cooldown > 0.0 or chrono.is_hitstop_active():
		return

	var origin: Vector2 = player.position + Vector2(0.0, 16.0)
	var to_aim: Vector2 = aim_world - origin
	var aim_dir: Vector2 = to_aim.normalized() if to_aim.length_squared() > 1e-4 else Vector2(player.facing, 0.0)
	player.facing = 1.0 if aim_dir.x >= 0.0 else -1.0

	var active_enemies_by_id: Dictionary = _build_active_enemies_by_id()
	var slash_res: Dictionary = CombatMath.perform_katana_slash(
		player,
		aim_world,
		active_enemies_by_id,
		bullets,
		chrono,
		player.parry_timer > 0.0
	)

	var arc_vis := CombatMath.SlashArcVisualData.new()
	arc_vis.origin = origin
	arc_vis.angle = aim_dir.angle()
	arc_vis.arc_span = PI * 0.75
	arc_vis.radius = 80.0
	arc_vis.timer = 0.14
	arc_vis.duration = 0.14
	arc_vis.color = Color(0.2, 0.95, 1.0, 1.0)
	slash_visuals.append(arc_vis)

	timeline.spawn_chrono_echo(
		origin,
		aim_dir,
		timeline.current_era,
		"slash",
		95.0,
		3.0,
		player.facing,
		player.velocity,
		player.is_grounded,
		last_stance,
		anim_time,
		player.loadout_id
	)
	audio_mgr.play_sfx("slash")
	last_stance = "normal"
	attack_anim_timer = 0.18
	attack_anim_duration = 0.18

	var slice_events: Array = slash_res.get("slice_events", [])
	if not slice_events.is_empty():
		_resolve_slices(slice_events, active_enemies_by_id)
	elif int(slash_res.get("hit_bullets", 0)) == 0:
		shifter.acclimatization.on_miss(shifter.model.get_active_gear(), false)


func _execute_heavy_launcher(aim_world: Vector2) -> void:
	player.heavy_cooldown = 0.38
	var origin: Vector2 = player.position + Vector2(0.0, 16.0)
	var to_aim: Vector2 = aim_world - origin
	var aim_dir: Vector2 = to_aim.normalized() if to_aim.length_squared() > 1e-4 else Vector2(player.facing, 0.0)
	player.facing = 1.0 if aim_dir.x >= 0.0 else -1.0

	var launched_count: int = 0
	for enemy in enemies:
		if enemy == null or enemy.era != timeline.current_era:
			continue
		var dist: float = enemy.position.distance_to(player.position)
		if dist <= 105.0 + enemy.hitbox_radius:
			var launch_vel := Vector2(player.facing * 90.0, 560.0)
			EnemyAI.launch_enemy(enemy, launch_vel, 0.75)
			launched_count += 1

	var vis := CombatMath.SlashArcVisualData.new()
	vis.origin = origin
	vis.angle = aim_dir.angle()
	vis.arc_span = PI * 0.95
	vis.radius = 105.0
	vis.timer = 0.20
	vis.duration = 0.20
	vis.color = Color(1.0, 0.72, 0.18, 1.0)
	slash_visuals.append(vis)

	timeline.spawn_chrono_echo(
		origin,
		aim_dir,
		timeline.current_era,
		"heavy",
		95.0,
		3.0,
		player.facing,
		player.velocity,
		player.is_grounded,
		"heavy_slash",
		anim_time,
		player.loadout_id
	)
	last_stance = "heavy_slash"
	attack_anim_timer = 0.24
	attack_anim_duration = 0.24
	audio_mgr.play_sfx("slash", 0.75)

	if launched_count > 0:
		combo.style_points = minf(100.0, combo.style_points + 8.0 * float(launched_count))
		combo.timer = maxf(combo.timer, combo.window)
		chrono.trigger_hitstop(ChronoState.HITSTOP_NORMAL)
		chrono.trigger_shake(6.5)


func _process_active_parry_window(aim_world: Vector2) -> void:
	var p_center: Vector2 = player.position + Vector2(0.0, 16.0)
	var parry_range: float = 95.0

	# 1. Deflect incoming bullets
	for bullet in bullets:
		if bullet == null or bullet.is_reflected:
			continue
		if bullet.era != -1 and bullet.era != timeline.current_era:
			continue
		if bullet.position.distance_to(p_center) <= parry_range + bullet.radius:
			var to_aim: Vector2 = aim_world - p_center
			var def_dir: Vector2 = (
				to_aim.normalized()
				if to_aim.length_squared() > 1e-4
				else -bullet.velocity.normalized()
			)
			bullet.deflect(def_dir, 1.5)
			combo.style_points = minf(100.0, combo.style_points + 10.0)
			combo.timer = maxf(combo.timer, combo.window)
			chrono.trigger_hitstop(ChronoState.HITSTOP_PARRY)
			chrono.trigger_shake(6.0)
			audio_mgr.play_sfx("slice_kill", 1.35)

	# 2. Parry close melee attackers (or insta-kill in Reverse Gear R!)
	var in_reverse: bool = (shifter.model.get_active_gear() == ChronoShiftModel.Gear.R)
	var active_enemies_by_id: Dictionary = _build_active_enemies_by_id()
	var reverse_kill_events: Array = []

	for eid in active_enemies_by_id.keys():
		var enemy: EnemyAI.EnemyData = active_enemies_by_id[eid]
		if enemy == null:
			continue
		if enemy.position.distance_to(player.position) <= 85.0 + enemy.hitbox_radius:
			if in_reverse:
				var dir: Vector2 = (enemy.position - player.position).normalized()
				if dir.length_squared() < 1e-4:
					dir = Vector2(player.facing, 0.0)
				reverse_kill_events.append(CombatMath.SliceEventData.new(
					eid,
					enemy.position + Vector2(0.0, 16.0),
					dir,
					dir * 420.0 + Vector2(0.0, 220.0),
					false,
					true,
					false
				))
			elif enemy.state in [EnemyAI.StateKind.WINDUP, EnemyAI.StateKind.ATTACK]:
				enemy.state = EnemyAI.StateKind.HITSTUN
				enemy.state_timer = 0.65
				enemy.velocity = Vector2(-enemy.facing * 240.0, 180.0)
				combo.style_points = minf(100.0, combo.style_points + 8.0)
				combo.timer = maxf(combo.timer, combo.window)
				chrono.trigger_hitstop(ChronoState.HITSTOP_PARRY)
				chrono.trigger_shake(5.5)

	if not reverse_kill_events.is_empty():
		_resolve_slices(reverse_kill_events, active_enemies_by_id)


func _execute_chrono_warp(aim_world: Vector2) -> void:
	if shifter.model.stalled:
		return

	var start_pos: Vector2 = player.position
	var active_enemies_by_id: Dictionary = _build_active_enemies_by_id()
	var warp_res: Dictionary = CombatMath.perform_chrono_warp(
		player,
		energy,
		aim_world,
		active_enemies_by_id,
		chrono
	)
	shifter.energy_current = energy.current
	shifter.energy_frac = clampf(energy.current / energy.max_energy, 0.0, 1.0) if energy.max_energy > 0.0 else 0.0

	if not warp_res.get("did_warp", false):
		return

	var end_pos: Vector2 = player.position
	var wb := CombatMath.WarpBeamVisualData.new()
	wb.start = start_pos + Vector2(0.0, 16.0)
	wb.end = end_pos + Vector2(0.0, 16.0)
	wb.timer = 0.25
	wb.duration = 0.25
	wb.color = Color(0.0, 1.0, 0.9, 1.0)
	warp_visuals.append(wb)

	# Spawn 3 ghost trails along the warp path
	for i in range(1, 4):
		var t: float = float(i) * 0.25
		var trail_pos: Vector2 = start_pos.lerp(end_pos, t)
		ghost_trails.append(GhostTrailData.new(
			trail_pos,
			player.facing,
			Vector2.ZERO,
			false,
			anim_time,
			"normal",
			0.28,
			Color(0.0, 1.0, 0.92, 0.65),
			timeline.current_era,
			player.loadout_id
		))

	var warp_dir: Vector2 = (end_pos - start_pos).normalized()
	if warp_dir.length_squared() < 1e-4:
		warp_dir = Vector2(player.facing, 0.0)
	timeline.spawn_chrono_echo(
		end_pos + Vector2(0.0, 16.0),
		warp_dir,
		timeline.current_era,
		"warp",
		95.0,
		3.0,
		player.facing,
		player.velocity,
		player.is_grounded,
		last_stance,
		anim_time,
		player.loadout_id
	)
	audio_mgr.play_sfx("warp")

	var slice_events: Array = warp_res.get("slice_events", [])
	if not slice_events.is_empty():
		_resolve_slices(slice_events, active_enemies_by_id)
	else:
		shifter.acclimatization.on_miss(shifter.model.get_active_gear(), true)


func _resolve_slices(events: Array, active_enemies_by_id: Dictionary) -> void:
	if events.is_empty():
		return

	var res: Dictionary = CombatMath.resolve_slice_events(
		events,
		chrono,
		combo,
		wave_mgr,
		energy,
		active_enemies_by_id
	)
	shifter.energy_current = energy.current
	shifter.energy_frac = clampf(energy.current / energy.max_energy, 0.0, 1.0) if energy.max_energy > 0.0 else 0.0
	shifter.hitstop_timer = chrono.hitstop_timer

	var killed_ids: Array = res.get("killed_ids", [])
	if not killed_ids.is_empty():
		for i in range(enemies.size() - 1, -1, -1):
			var e = enemies[i]
			if e == null or killed_ids.has(e.get_instance_id()):
				enemies.remove_at(i)

		shifter.acclimatization.on_flawless_kill(shifter.model.get_active_gear(), killed_ids.size())
		audio_mgr.play_sfx("slice_kill")

	for piece_var in res.get("ragdolls", []):
		var piece: RagdollPhysics.RagdollPieceData = piece_var
		if piece == null:
			continue
		piece.era = timeline.current_era
		var base_lo := asset_registry.get_loadout(piece.loadout_id)
		if base_lo != null:
			var split_dict: Dictionary = base_lo.split_for_ragdoll()
			var upper_lo: ModularAssetSystem.CharacterLoadout = split_dict["upper"]
			var lower_lo: ModularAssetSystem.CharacterLoadout = split_dict["lower"]
			asset_registry.register_loadout(upper_lo)
			asset_registry.register_loadout(lower_lo)
		ragdolls.append(piece)

	for part_var in res.get("particles", []):
		var part: RagdollPhysics.SliceParticleData = part_var
		if part == null:
			continue
		part.era = timeline.current_era
		particles.append(part)


func _step_player_movement_and_environment(
	move_x: float,
	down_held: bool,
	jump_held: bool,
	jump_pressed: bool,
	input_override: Dictionary,
	player_dt: float
) -> void:
	if player.dash_timer > 0.0:
		player.dash_timer = maxf(0.0, player.dash_timer - player_dt)
		player.velocity = player.dash_dir * player.config.dash_speed
		ghost_distance_accum += (player.position - ghost_last_pos).length()
		ghost_last_pos = player.position
		ghost_spawn_timer -= player_dt
		if ghost_distance_accum >= 32.0 or (ghost_spawn_timer <= 0.0 and ghost_distance_accum >= 16.0):
			ghost_distance_accum = 0.0
			ghost_spawn_timer = 0.04
			ghost_trails.append(GhostTrailData.new(
				player.position,
				player.facing,
				player.velocity,
				player.is_grounded,
				anim_time,
				"normal",
				0.20,
				Color(0.0, 0.85, 1.0, 0.50),
				timeline.current_era,
				player.loadout_id
			))
	elif player.is_slamming:
		player.velocity = Vector2(0.0, player.config.slam_speed)
		last_stance = "downward_slam"
	else:
		var grabbed_vine: TimelineSystem.VineClimbData = timeline.check_vine_grab(player.position)
		if grabbed_vine != null and not player.is_grounded:
			player.is_climbing_vine = true
			player.velocity.x = move_x * (player.config.max_speed * 0.5)
			if jump_pressed:
				player.velocity.y = player.config.jump_force
				player.is_climbing_vine = false
				audio_mgr.play_sfx("jump")
			else:
				player.velocity.y = 180.0 if jump_held else (-160.0 if down_held else 0.0)
		else:
			player.is_climbing_vine = false
			player.velocity.x = PlayerKinematics.step_horizontal_velocity(
				player.velocity.x,
				move_x,
				player.config,
				player_dt
			)

			var wall_normal_x: float = _safe_float(input_override.get("wall_normal_x", 0.0), 0.0)
			if absf(wall_normal_x) < 0.01 and timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
				if player.position.x <= -568.0:
					wall_normal_x = 1.0
				elif player.position.x >= 568.0:
					wall_normal_x = -1.0

			var did_wall_jump: bool = PlayerKinematics.step_wall_slide_and_rebound(
				player,
				wall_normal_x,
				jump_pressed,
				player_dt
			)
			if did_wall_jump:
				last_stance = "normal"
				audio_mgr.play_sfx("jump", 1.1)
			else:
				if player.is_wall_sliding:
					last_stance = "wall_slide"
				elif last_stance == "wall_slide":
					last_stance = "normal"

				var v_res: Dictionary = PlayerKinematics.step_vertical_velocity(
					player.velocity.y,
					player.is_grounded,
					jump_held,
					jump_pressed,
					player.coyote_timer,
					player.jump_buffer_timer,
					player.config,
					player_dt
				)
				player.velocity.y = v_res["vy"]
				player.coyote_timer = v_res["coyote_timer"]
				player.jump_buffer_timer = v_res["jump_buffer_timer"]
				if v_res["did_jump"]:
					player.is_grounded = false
					audio_mgr.play_sfx("jump")
				if player.is_wall_sliding and player.velocity.y < player.config.wall_slide_speed:
					player.velocity.y = player.config.wall_slide_speed

	var prev_pos: Vector2 = player.position
	player.position += player.velocity * player_dt

	if timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
		player.position.x = clampf(player.position.x, -570.0, 570.0)
	else:
		player.position.x = clampf(player.position.x, -200.0, 1850.0)

	var was_slamming: bool = player.is_slamming
	var landed: bool = false
	var active_platforms: Array[TimelineSystem.PhasePlatformData] = timeline.get_active_platforms()

	if player.velocity.y <= 0.0 and (not down_held or was_slamming):
		for plat in active_platforms:
			if plat == null:
				continue
			if player.position.x >= plat.min_x and player.position.x <= plat.max_x:
				if prev_pos.y >= plat.y - 4.0 and player.position.y <= plat.y:
					player.position.y = plat.y
					player.velocity.y = 0.0
					landed = true
					break

	if not landed:
		if timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
			if player.position.y <= FLOOR_Y:
				player.position.y = FLOOR_Y
				player.velocity.y = 0.0
				landed = true
		else:
			if player.position.y < -350.0:
				player.position = timeline.checkpoint_pos
				player.velocity = Vector2.ZERO
				landed = true

	player.is_grounded = landed
	if landed:
		player.is_wall_sliding = false
		player.is_climbing_vine = false
		if was_slamming:
			player.is_slamming = false
			last_stance = "normal"
			_trigger_slam_landing_shockwave()

	# Jump pads
	var boost: Vector2 = timeline.check_jump_pad(player.position, player.velocity.y)
	if boost.length_squared() > 1.0:
		player.velocity = boost
		player.is_grounded = false
		player.is_slamming = false
		audio_mgr.play_sfx("jump", 1.3)

	# Laser hazards
	if timeline.check_laser_hazard(player.position, player.invulnerability_timer > 0.0):
		_damage_player(25.0)

	# Lore glyphs
	var collected_glyphs: Array[TimelineSystem.LoreGlyphData] = timeline.check_lore_glyphs(player.position)
	for _g in collected_glyphs:
		combo.score += 500
		combo.style_points = minf(100.0, combo.style_points + 15.0)
		audio_mgr.play_sfx("warp", 1.4)

	# Acceleration & procedural rig dynamics
	if player_dt > 0.0001:
		player_accel_x = clampf((player.velocity.x - player_prev_vx) / player_dt, -3500.0, 3500.0)
	else:
		player_accel_x = 0.0
	player_prev_vx = player.velocity.x
	player_dt_last = player_dt

	if player_rig != null:
		var godot_vel := Vector2(player.velocity.x, -player.velocity.y)
		player_rig.global_position = to_screen(player.position) + Vector2(0.0, -38.4)
		player_rig.update_procedural_animation(
			godot_vel,
			player.is_grounded,
			player.facing,
			_resolve_player_anim_state(),
			player_dt
		)


func _trigger_slam_landing_shockwave() -> void:
	var active_era_enemies: Array = []
	for enemy in enemies:
		if enemy != null and enemy.era == timeline.current_era:
			active_era_enemies.append(enemy)

	var launched_count: int = CombatMath.apply_slam_shockwave(
		player.position,
		160.0,
		active_era_enemies,
		540.0
	)

	var sw := CombatMath.ShockwaveVisualData.new()
	sw.origin = player.position
	sw.current_radius = 12.0
	sw.max_radius = 160.0
	sw.timer = 0.28
	sw.duration = 0.28
	sw.color = Color(1.0, 0.55, 0.1, 0.95)
	shockwave_visuals.append(sw)

	chrono.trigger_hitstop(ChronoState.HITSTOP_SLAM)
	chrono.trigger_shake(10.0)
	shifter.hitstop_timer = chrono.hitstop_timer
	audio_mgr.play_sfx("slice_kill", 0.75)

	if launched_count > 0:
		combo.style_points = minf(100.0, combo.style_points + 7.5 * float(launched_count))
		combo.timer = maxf(combo.timer, combo.window)


func _damage_player(amount: float) -> void:
	if player.invulnerability_timer > 0.0 or amount <= 0.0:
		return

	player.health = maxf(0.0, player.health - amount)
	player.invulnerability_timer = 0.55
	combo.on_damage_taken()
	chrono.trigger_shake(9.0)

	shifter.apply_damage_knockdown()
	chrono.slowmo_factor = shifter.slowmo_factor
	chrono.is_dilating = shifter.is_dilating
	if shifter.acclimatization.reverse_insta_death:
		player.health = 0.0

	if player.health <= 0.0:
		player.health = player.max_health
		player.position = timeline.checkpoint_pos if timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL else Vector2(0.0, FLOOR_Y)
		player.velocity = Vector2.ZERO
		shifter.acclimatization.reverse_insta_death = false


func _step_world_entities(real_dt: float, world_dt: float, aim_world: Vector2) -> void:
	timeline.tick(world_dt)
	combo.update(real_dt)

	# 1. Wave Manager progression in HORDE_ARENA mode
	if timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
		var wave_dt: float = real_dt if wave_mgr.is_real_time_phase() else world_dt
		var wave_act: Dictionary = wave_mgr.update(wave_dt, ARENA_HALF_WIDTH * 2.0, FLOOR_Y)
		if wave_act.get("action") == "spawn_enemy":
			var e_type: int = int(wave_act.get("enemy_type", EnemyAI.EnemyType.RUNNER))
			var e_pos: Vector2 = wave_act.get("position", Vector2(400.0, FLOOR_Y))
			var e_era: int = timeline.current_era
			enemies.append(EnemyAI.EnemyData.new(e_type, e_pos, e_era))

	# 2. Step Enemies
	if world_dt > 0.0:
		for enemy in enemies:
			if enemy == null:
				continue
			var ai_res: Dictionary = EnemyAI.step_enemy_ai(enemy, player.position, world_dt)
			var enemy_plats: Array = []
			for p in timeline.platforms:
				if p.era == -1 or p.era == enemy.era:
					enemy_plats.append(p)
			EnemyAI.step_enemy_physics(
				enemy,
				float(ai_res.get("move_dir", 0.0)),
				bool(ai_res.get("should_jump", false)),
				enemy_plats,
				world_dt,
				FLOOR_Y,
				1200.0
			)

			if enemy.era == timeline.current_era:
				var fired_bullet: CombatMath.BulletData = EnemyAI.step_gunner_attack(enemy, player.position, world_dt)
				if fired_bullet != null:
					bullets.append(fired_bullet)

				# Melee attack hit check
				var is_gunner: bool = enemy.enemy_type in [
					EnemyAI.EnemyType.GUNNER_SEMI,
					EnemyAI.EnemyType.GUNNER_AUTO,
					EnemyAI.EnemyType.SNIPER,
				]
				if not is_gunner and enemy.state == EnemyAI.StateKind.ATTACK and not enemy.attack_has_hit:
					if enemy.position.distance_to(player.position) <= enemy.attack_range + 12.0:
						enemy.attack_has_hit = true
						if player.parry_timer > 0.0:
							_process_active_parry_window(aim_world)
						else:
							_damage_player(enemy.attack_damage)

	# 3. Step Bullets
	if world_dt > 0.0:
		var reflected_kill_events: Array = []
		var active_enemies_by_id: Dictionary = _build_active_enemies_by_id()
		var p_center: Vector2 = player.position + Vector2(0.0, 16.0)

		for i in range(bullets.size() - 1, -1, -1):
			var b: CombatMath.BulletData = bullets[i]
			if b == null:
				bullets.remove_at(i)
				continue

			if not b.step_bullet(world_dt, ARENA_HALF_WIDTH, FLOOR_Y, CEILING_Y):
				bullets.remove_at(i)
				continue

			if b.is_reflected:
				var hit_enemy: bool = false
				for eid in active_enemies_by_id.keys():
					var enemy: EnemyAI.EnemyData = active_enemies_by_id[eid]
					if enemy == null:
						continue
					var e_center: Vector2 = enemy.position + Vector2(0.0, 16.0)
					if b.position.distance_to(e_center) <= b.radius + enemy.hitbox_radius:
						var dir: Vector2 = b.velocity.normalized() if b.velocity.length_squared() > 1e-4 else Vector2.RIGHT
						reflected_kill_events.append(CombatMath.SliceEventData.new(
							eid,
							e_center,
							dir,
							dir * 360.0 + Vector2(0.0, 180.0),
							false,
							true,
							false
						))
						hit_enemy = true
						break
				if hit_enemy:
					b.damage = 0.0
					b.lifetime = 0.0
					bullets.remove_at(i)
			else:
				if b.era == -1 or b.era == timeline.current_era:
					if b.position.distance_to(p_center) <= b.radius + 16.0:
						if player.parry_timer > 0.0:
							var to_aim: Vector2 = aim_world - p_center
							var def_dir: Vector2 = (
								to_aim.normalized()
								if to_aim.length_squared() > 1e-4
								else -b.velocity.normalized()
							)
							b.deflect(def_dir, 1.5)
							chrono.trigger_hitstop(ChronoState.HITSTOP_PARRY)
						else:
							_damage_player(b.damage)
							bullets.remove_at(i)

		if not reflected_kill_events.is_empty():
			_resolve_slices(reflected_kill_events, active_enemies_by_id)

	# 4. Step Ragdoll Halves & Slice Particles
	var active_plats: Array[TimelineSystem.PhasePlatformData] = timeline.get_active_platforms()
	for i in range(ragdolls.size() - 1, -1, -1):
		if not RagdollPhysics.step_ragdoll_piece(ragdolls[i], active_plats, world_dt, FLOOR_Y, 1200.0):
			ragdolls.remove_at(i)

	for i in range(particles.size() - 1, -1, -1):
		if not RagdollPhysics.step_slice_particle(particles[i], world_dt, FLOOR_Y, 1200.0):
			particles.remove_at(i)

	# 5. Step Visual Effects (GhostTrails, SlashArcs, WarpBeams, Shockwaves)
	for i in range(ghost_trails.size() - 1, -1, -1):
		var g: GhostTrailData = ghost_trails[i]
		if g == null:
			ghost_trails.remove_at(i)
			continue
		g.timer -= real_dt
		if g.timer <= 0.0:
			ghost_trails.remove_at(i)

	for i in range(slash_visuals.size() - 1, -1, -1):
		var sv: CombatMath.SlashArcVisualData = slash_visuals[i]
		if sv == null:
			slash_visuals.remove_at(i)
			continue
		sv.timer -= real_dt
		if sv.timer <= 0.0:
			slash_visuals.remove_at(i)

	for i in range(warp_visuals.size() - 1, -1, -1):
		var wv: CombatMath.WarpBeamVisualData = warp_visuals[i]
		if wv == null:
			warp_visuals.remove_at(i)
			continue
		wv.timer -= real_dt
		if wv.timer <= 0.0:
			warp_visuals.remove_at(i)

	for i in range(shockwave_visuals.size() - 1, -1, -1):
		var sw: CombatMath.ShockwaveVisualData = shockwave_visuals[i]
		if sw == null:
			shockwave_visuals.remove_at(i)
			continue
		sw.timer -= real_dt
		if sw.timer <= 0.0:
			shockwave_visuals.remove_at(i)
		else:
			var progress: float = 1.0 - clampf(sw.timer / maxf(0.001, sw.duration), 0.0, 1.0)
			sw.current_radius = lerpf(12.0, sw.max_radius, progress)


func _update_camera(dt: float) -> void:
	if timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL:
		var follow_alpha: float = minf(1.0, dt * 8.0) if dt > 0.0 else 1.0
		camera_sim_pos.x = lerpf(camera_sim_pos.x, player.position.x, follow_alpha)
		camera_sim_pos.y = 0.0
	else:
		camera_sim_pos = Vector2.ZERO

	if camera != null:
		var shake_screen := Vector2(chrono.shake_offset.x, -chrono.shake_offset.y)
		camera.position = to_screen(camera_sim_pos) + shake_screen


func _update_hud() -> void:
	if hud_layer == null:
		return

	if health_bar != null:
		health_bar.max_value = player.max_health
		health_bar.value = player.health
	if health_label != null:
		health_label.text = "HP: %d / %d" % [int(roundf(player.health)), int(roundf(player.max_health))]

	var energy_pct: int = int(roundf(clampf((energy.current / maxf(1.0, energy.max_energy)) * 100.0, 0.0, 100.0)))
	if energy_bar != null:
		energy_bar.max_value = energy.max_energy
		energy_bar.value = energy.current
	if energy_label != null:
		energy_label.text = "CHRONO: %d%%" % energy_pct

	var palette: Dictionary = timeline.get_era_palette()
	if era_label != null:
		era_label.text = "ERA: %s [%s]" % [str(palette.get("name", "PRESENT")), str(palette.get("subtitle", "INDUSTRIAL CLOCKWORK"))]
		era_label.add_theme_color_override("font_color", palette.get("accent_color", Color.CYAN))

	if rig_label != null:
		var lo := asset_registry.get_loadout(player.loadout_id)
		var wp_count: int = lo.weapon_assembly.pieces.size() if (lo != null and lo.weapon_assembly != null) else 0
		var part_count: int = lo.parts.size() if lo != null else 0
		rig_label.text = "RIG: %s [%d Weapon / %d Body Parts | Tier %d]" % [
			lo.display_name if lo != null else "Chronos Nomad",
			wp_count,
			part_count,
			customization_tier,
		]

	if wave_label != null:
		var collected_count: int = 0
		for g in timeline.lore_glyphs:
			if g.collected:
				collected_count += 1
		if timeline.mode == TimelineSystem.GameMode.CAMPAIGN_TRAVERSAL:
			var zone_num: int = 1
			if player.position.x >= 1100.0:
				zone_num = 3
			elif player.position.x >= 550.0:
				zone_num = 2
			wave_label.text = "CAMPAIGN TRAVERSAL — ZONE %d | LORE GLYPHS: %d / %d" % [
				zone_num,
				collected_count,
				timeline.lore_glyphs.size(),
			]
		else:
			var phase_name: String = "ACTIVE"
			match wave_mgr.phase:
				EnemyAI.WavePhase.INTERMISSION:
					phase_name = "INTERMISSION"
				EnemyAI.WavePhase.SPAWNING:
					phase_name = "SPAWNING"
				EnemyAI.WavePhase.ACTIVE:
					phase_name = "ACTIVE (%d ALIVE)" % wave_mgr.alive_count
				EnemyAI.WavePhase.WAVE_CLEARED:
					phase_name = "WAVE CLEARED!"
			wave_label.text = "HORDE ARENA — WAVE %d [%s] | GLYPHS: %d/%d" % [
				wave_mgr.current_wave,
				phase_name,
				collected_count,
				timeline.lore_glyphs.size(),
			]

	if dilation_banner_label != null:
		if not shifter.acclimatization.feedback_banner.is_empty():
			dilation_banner_label.text = "<< %s >>" % shifter.acclimatization.feedback_banner
		elif chrono.is_dilating:
			dilation_banner_label.text = "<< CHRONO DILATION ACTIVE (%.2fx) >>" % chrono.dilation_factor
		else:
			dilation_banner_label.text = ""

	if score_label != null:
		score_label.text = "SCORE: %06d" % combo.score
	if combo_label != null:
		combo_label.text = "COMBO: %d (%dx)" % [combo.count, combo.multiplier]
	if style_rank_label != null:
		var rank: String = combo.get_style_rank()
		style_rank_label.text = "STYLE: %s" % rank
		var rank_col := Color(0.85, 0.85, 0.9, 1.0)
		match rank:
			"SSS":
				rank_col = Color(1.0, 0.2, 0.45, 1.0)
			"SS":
				rank_col = Color(1.0, 0.65, 0.1, 1.0)
			"S":
				rank_col = Color(1.0, 0.9, 0.2, 1.0)
			"A":
				rank_col = Color(0.2, 0.95, 1.0, 1.0)
			"B":
				rank_col = Color(0.35, 0.95, 0.45, 1.0)
		style_rank_label.add_theme_color_override("font_color", rank_col)

	if shifter_readout_label != null:
		shifter_readout_label.text = ChronoShiftModel.readout_text(
			shifter.model,
			shifter.drain_per_sec,
			shifter.energy_frac,
			shifter.acclimatization
		)


# ---------------------------------------------------------------------------------------------
# Full Procedural + Modular _draw() Renderer
# ---------------------------------------------------------------------------------------------

func _d_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_line(from, to, color, width, antialiased)


func _d_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_rect(rect, color, filled, width, antialiased)


func _d_arc(
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	point_count: int,
	color: Color,
	width: float = -1.0,
	antialiased: bool = false
) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)


func _d_circle(
	position_scr: Vector2,
	radius: float,
	color: Color,
	filled: bool = true,
	width: float = -1.0,
	antialiased: bool = false
) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_circle(position_scr, radius, color, filled, width, antialiased)


func _d_polygon(points: PackedVector2Array, color: Color) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_colored_polygon(points, color)


func _d_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_polyline(points, color, width, antialiased)


func _d_tex_rect(
	texture: Texture2D,
	rect: Rect2,
	tile: bool = false,
	modulate_col: Color = Color.WHITE,
	transpose: bool = false
) -> void:
	last_draw_primitive_count += 1
	if _can_issue_canvas_draws:
		draw_texture_rect(texture, rect, tile, modulate_col, transpose)


func _draw() -> void:
	_can_issue_canvas_draws = _is_in_canvas_draw_pass and is_inside_tree()
	draw_call_count += 1
	last_draw_primitive_count = 0

	var palette: Dictionary = timeline.get_era_palette()
	var bg_col: Color = palette.get("bg_color", Color(0.08, 0.10, 0.14, 1.0))
	var accent_col: Color = palette.get("accent_color", Color(0.25, 0.90, 1.0, 1.0))
	var plat_col: Color = palette.get("platform_color", Color(0.75, 0.62, 0.34, 1.0))
	var ghost_col: Color = palette.get("ghost_color", Color(0.75, 0.62, 0.34, 0.22))

	var cam_screen: Vector2 = to_screen(camera_sim_pos)

	# 1. Era Background & Grid
	_d_rect(Rect2(cam_screen.x - 960.0, cam_screen.y - 540.0, 1920.0, 1080.0), bg_col, true)
	var grid_col := Color(accent_col.r, accent_col.g, accent_col.b, 0.07)
	var start_gx: int = int(floorf((camera_sim_pos.x - 800.0) / 80.0)) * 80
	for gx in range(start_gx, start_gx + 1680, 80):
		_d_line(to_screen(Vector2(float(gx), -400.0)), to_screen(Vector2(float(gx), 400.0)), grid_col, 1.0)
	for gy in range(-320, 360, 80):
		_d_line(
			to_screen(Vector2(camera_sim_pos.x - 800.0, float(gy))),
			to_screen(Vector2(camera_sim_pos.x + 800.0, float(gy))),
			grid_col,
			1.0
		)

	# Floor line in Horde Arena
	if timeline.mode == TimelineSystem.GameMode.HORDE_ARENA:
		_d_line(
			to_screen(Vector2(-ARENA_HALF_WIDTH, FLOOR_Y)),
			to_screen(Vector2(ARENA_HALF_WIDTH, FLOOR_Y)),
			plat_col,
			4.0
		)
		_d_line(
			to_screen(Vector2(-ARENA_HALF_WIDTH, FLOOR_Y)),
			to_screen(Vector2(-ARENA_HALF_WIDTH, CEILING_Y)),
			Color(plat_col.r, plat_col.g, plat_col.b, 0.45),
			3.0
		)
		_d_line(
			to_screen(Vector2(ARENA_HALF_WIDTH, FLOOR_Y)),
			to_screen(Vector2(ARENA_HALF_WIDTH, CEILING_Y)),
			Color(plat_col.r, plat_col.g, plat_col.b, 0.45),
			3.0
		)

	# 2. Chronos Wells (ornate brass/cyan rings + checkpoint beacon)
	for well in timeline.chronos_wells:
		if well == null:
			continue
		var w_scr: Vector2 = to_screen(well.position + Vector2(0.0, 28.0))
		var brass := Color(0.88, 0.72, 0.28, 0.85)
		var cyan := Color(0.15, 0.95, 1.0, 0.90)
		_d_arc(w_scr, 28.0, 0.0, TAU, 32, brass, 3.0)
		_d_arc(w_scr, 20.0, anim_time * 1.5, anim_time * 1.5 + PI * 1.5, 24, cyan, 2.2)
		for tooth_i in range(8):
			var a: float = anim_time * 0.8 + float(tooth_i) * (TAU / 8.0)
			var dir := Vector2(cos(a), sin(a))
			_d_line(w_scr + dir * 24.0, w_scr + dir * 32.0, brass, 2.5)
		if well.is_active_checkpoint:
			_d_line(w_scr, w_scr + Vector2(0.0, -90.0), Color(0.2, 0.95, 1.0, 0.25), 6.0)

	# 3. Vines, Jump Pads, Lasers, Lore Glyphs
	for vine in timeline.vines:
		if vine == null:
			continue
		var v_alpha: float = 0.95 if (vine.era == -1 or vine.era == timeline.current_era) else 0.22
		var v_col := Color(0.32, 0.85, 0.38, v_alpha)
		_d_line(to_screen(Vector2(vine.x, vine.min_y)), to_screen(Vector2(vine.x, vine.max_y)), v_col, 4.0)

	for pad in timeline.jump_pads:
		if pad == null:
			continue
		var p_alpha: float = 0.95 if (pad.era == -1 or pad.era == timeline.current_era) else 0.22
		var p_scr: Vector2 = to_screen(pad.position)
		_d_rect(Rect2(p_scr.x - pad.width * 0.5, p_scr.y - 6.0, pad.width, 8.0), Color(0.1, 0.95, 1.0, p_alpha), true)
		_d_line(p_scr + Vector2(-14.0, -10.0), p_scr + Vector2(0.0, -20.0), Color(1.0, 0.3, 0.8, p_alpha), 2.5)
		_d_line(p_scr + Vector2(14.0, -10.0), p_scr + Vector2(0.0, -20.0), Color(1.0, 0.3, 0.8, p_alpha), 2.5)

	for laser in timeline.lasers:
		if laser == null:
			continue
		var l_active: bool = (laser.era == -1 or laser.era == timeline.current_era)
		var l_top: Vector2 = to_screen(Vector2(laser.x, laser.max_y))
		var l_bot: Vector2 = to_screen(Vector2(laser.x, laser.min_y))
		if l_active:
			_d_line(l_top, l_bot, Color(1.0, 0.12, 0.35, 0.35), laser.half_width * 1.6)
			_d_line(l_top, l_bot, Color(1.0, 0.25, 0.55, 0.95), 3.5)
		else:
			_d_line(l_top, l_bot, Color(0.5, 0.55, 0.6, 0.22), 2.0)

	for glyph in timeline.lore_glyphs:
		if glyph == null or glyph.collected:
			continue
		var g_alpha: float = 0.95 if (glyph.era == -1 or glyph.era == timeline.current_era) else 0.25
		var g_scr: Vector2 = to_screen(glyph.position)
		var r: float = 12.0
		var pts := PackedVector2Array([
			g_scr + Vector2(0.0, -r),
			g_scr + Vector2(r, 0.0),
			g_scr + Vector2(0.0, r),
			g_scr + Vector2(-r, 0.0),
			g_scr + Vector2(0.0, -r),
		])
		_d_polyline(pts, Color(0.95, 0.85, 0.3, g_alpha), 2.2)
		_d_circle(g_scr, 4.0, Color(0.2, 0.95, 1.0, g_alpha))

	# 4. Inactive & Active Era Platforms
	for plat in timeline.get_inactive_platforms():
		var p_scr: Vector2 = to_screen(Vector2(plat.min_x, plat.y))
		_d_rect(Rect2(p_scr.x, p_scr.y, plat.width(), plat.thickness), ghost_col, false, 1.8)

	for plat in timeline.get_active_platforms():
		var p_scr: Vector2 = to_screen(Vector2(plat.min_x, plat.y))
		_d_rect(Rect2(p_scr.x, p_scr.y, plat.width(), plat.thickness), plat_col, true)
		_d_line(p_scr, p_scr + Vector2(plat.width(), 0.0), accent_col, 2.5)

	# 5. Chrono-Echoes (Modular stickman pose with era-colored tint and fading alpha)
	for echo_i in range(timeline.echoes.size()):
		var echo: TimelineSystem.ChronoEchoData = timeline.echoes[echo_i]
		if echo == null:
			continue
		var echo_era_palette: Dictionary = timeline.get_era_palette(echo.era)
		var echo_accent: Color = echo_era_palette.get("accent_color", Color(0.25, 0.90, 1.0, 1.0))
		var base_alpha: float = 0.85 if echo.era == timeline.current_era else 0.35
		var echo_fade: float = echo.fade_ratio() if echo.has_method("fade_ratio") else clampf(echo.timer / maxf(0.001, echo.max_timer), 0.0, 1.0)
		var echo_alpha: float = base_alpha * echo_fade
		var echo_tint := Color(echo_accent.r, echo_accent.g, echo_accent.b, echo_alpha)

		var echo_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
			echo.origin,
			echo.facing,
			echo.velocity,
			echo.is_grounded,
			echo.anim_time,
			echo.is_attacking,
			echo.attack_progress,
			false,
			echo.stance
		)
		var echo_rig_active: bool = (_echo_rig_pool.size() > echo_i and _echo_rig_pool[echo_i] != null and _echo_rig_pool[echo_i].visible)
		_draw_modular_character(echo_pose, echo.loadout_id, echo.facing, 0.0, echo_alpha, echo_tint, echo_rig_active)

		var e_scr: Vector2 = to_screen(echo.origin)
		var dir_scr := Vector2(echo.aim_dir.x, -echo.aim_dir.y)
		if dir_scr.length_squared() > 0.01:
			_d_line(e_scr, e_scr + dir_scr * 24.0, Color(echo_accent.r, echo_accent.g, echo_accent.b, echo_alpha * 0.85), 2.2)

	# 6. Ghost Trails
	for ghost in ghost_trails:
		if ghost == null:
			continue
		var g_ratio: float = clampf(ghost.timer / maxf(0.001, ghost.max_timer), 0.0, 1.0)
		var g_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
			ghost.position,
			ghost.facing,
			ghost.velocity,
			ghost.is_grounded,
			ghost.anim_time,
			ghost.is_attacking,
			ghost.attack_progress,
			false,
			ghost.stance
		)
		var g_col := Color(ghost.color.r, ghost.color.g, ghost.color.b, ghost.color.a * g_ratio)
		_draw_modular_character(g_pose, ghost.loadout_id, ghost.facing, 0.0, g_ratio * 0.75, g_col)
		if absf(ghost.velocity.x) > 400.0:
			var ca_col := Color(1.0, 0.25, 0.55, g_col.a * 0.45)
			var ca_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
				ghost.position - Vector2(ghost.facing * 5.0, 0.0),
				ghost.facing,
				ghost.velocity,
				ghost.is_grounded,
				ghost.anim_time,
				ghost.is_attacking,
				ghost.attack_progress,
				false,
				ghost.stance
			)
			_draw_pose_skeleton(ca_pose, ca_col, 1.8)

	# 7. Enemies (active era = full alpha; inactive era = glowing translucent shadow alpha = 0.28)
	for enemy_idx in range(enemies.size()):
		var enemy: EnemyAI.EnemyData = enemies[enemy_idx]
		if enemy == null:
			continue
		var e_alpha: float = 1.0 if enemy.era == timeline.current_era else 0.28
		var e_attacking: bool = (enemy.state == EnemyAI.StateKind.ATTACK)
		var e_atk_prog: float = (
			clampf(enemy.state_timer / maxf(0.001, enemy.state_duration), 0.0, 1.0)
			if e_attacking
			else 0.0
		)
		var e_stance: String = "normal"
		if not enemy.is_grounded or enemy.state == EnemyAI.StateKind.JUGGLED:
			if enemy.velocity.y < -100.0 and enemy.enemy_type == EnemyAI.EnemyType.NINJA:
				e_stance = "downward_slam"
			else:
				e_stance = "jump"
		elif enemy.state == EnemyAI.StateKind.WINDUP:
			if enemy.enemy_type == EnemyAI.EnemyType.HEAVY or enemy.enemy_type == EnemyAI.EnemyType.RUNNER:
				e_stance = "heavy_slash"
			else:
				e_stance = "parry_guard"
		elif enemy.state == EnemyAI.StateKind.ATTACK:
			if enemy.enemy_type == EnemyAI.EnemyType.HEAVY:
				e_stance = "heavy_slash"
			elif enemy.enemy_type == EnemyAI.EnemyType.NINJA:
				e_stance = "downward_slam"
			else:
				e_stance = "heavy_slash"
		elif enemy.state == EnemyAI.StateKind.HITSTUN:
			e_stance = "parry_guard"

		var e_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
			enemy.position,
			enemy.facing,
			enemy.velocity,
			enemy.is_grounded,
			anim_time,
			e_attacking,
			e_atk_prog,
			true,
			e_stance
		)
		var erig_active: bool = (_enemy_rig_pool.size() > enemy_idx and _enemy_rig_pool[enemy_idx] != null and _enemy_rig_pool[enemy_idx].visible)
		_draw_modular_character(e_pose, enemy.loadout_id, enemy.facing, 0.0, e_alpha, Color(0, 0, 0, 0), erig_active)

		# Windup telegraph
		if enemy.state == EnemyAI.StateKind.WINDUP:
			var head_scr: Vector2 = to_screen(e_pose.head_center)
			_d_arc(head_scr, 14.0, 0.0, TAU, 16, Color(1.0, 0.2, 0.2, 0.85 * e_alpha), 2.0)
			if enemy.enemy_type == EnemyAI.EnemyType.SNIPER:
				var muzzle_sim: Vector2 = enemy.position + Vector2(enemy.facing * 20.0, 14.0)
				var laser_end_sim: Vector2 = muzzle_sim + enemy.laser_aim_dir * 520.0
				_d_line(
					to_screen(muzzle_sim),
					to_screen(laser_end_sim),
					Color(1.0, 0.15, 0.3, 0.75 * e_alpha),
					1.6
				)

	# 8. Player & Interlocking Shift Staff
	var near_well: bool = (timeline.is_near_chronos_well(player.position) != null)
	var active_gear: int = shifter.model.get_active_gear()
	var gear_alignment: float = 1.0 if near_well else clampf(float(active_gear) / 6.0, 0.0, 1.0)
	var p_attacking: bool = (attack_anim_timer > 0.0)
	var p_atk_prog: float = (
		clampf(attack_anim_timer / maxf(0.001, attack_anim_duration), 0.0, 1.0)
		if p_attacking
		else 0.0
	)
	var p_stance: String = last_stance
	if near_well and not p_attacking and absf(player.velocity.x) < 15.0 and player.is_grounded:
		p_stance = "well_unlock"

	var player_pose := ModularAssetSystem.StickmanPoseSolver.generate_stickman_pose(
		player.position,
		player.facing,
		player.velocity,
		player.is_grounded,
		anim_time,
		p_attacking,
		p_atk_prog,
		false,
		p_stance,
		player_accel_x,
		player_dynamics_ctx,
		player_dt_last
	)
	var p_rig_active: bool = (player_rig != null and player_rig.visible)
	_draw_modular_character(player_pose, player.loadout_id, player.facing, gear_alignment, 1.0, Color(0, 0, 0, 0), p_rig_active)

	if player.parry_timer > 0.0:
		var ward_scr: Vector2 = to_screen(player.position + Vector2(0.0, 20.0))
		_d_arc(ward_scr, 34.0, -PI * 0.45, PI * 0.45, 20, Color(0.95, 0.82, 0.3, 0.95), 3.2)

	# 9. Ragdoll Halves (using split loadouts)
	for piece_var in ragdolls:
		var piece: RagdollPhysics.RagdollPieceData = piece_var
		if piece == null:
			continue
		_draw_ragdoll_piece(piece)

	# 10. SliceParticles, SlashArcVisuals, WarpBeamVisuals, ShockwaveVisuals, Bullets
	for part_var in particles:
		var part: RagdollPhysics.SliceParticleData = part_var
		if part == null:
			continue
		var p_scr: Vector2 = to_screen(part.position)
		var p_vel_scr := Vector2(part.velocity.x, -part.velocity.y) * 0.022
		if p_vel_scr.length_squared() > 6.0:
			_d_line(p_scr, p_scr - p_vel_scr, part.color, part.size * 1.1)
			_d_circle(p_scr, part.size * 0.6, part.color)
		else:
			_d_circle(p_scr, part.size, part.color)

	for sv_var in slash_visuals:
		var sv: CombatMath.SlashArcVisualData = sv_var
		if sv == null:
			continue
		var ratio: float = clampf(sv.timer / maxf(0.001, sv.duration), 0.0, 1.0)
		var col := Color(sv.color.r, sv.color.g, sv.color.b, sv.color.a * ratio)
		var scr_origin: Vector2 = to_screen(sv.origin)
		var scr_angle: float = -sv.angle
		_d_arc(scr_origin, sv.radius, scr_angle - sv.arc_span * 0.5, scr_angle + sv.arc_span * 0.5, 24, col, 4.0 * ratio + 1.5)

	for wv_var in warp_visuals:
		var wv: CombatMath.WarpBeamVisualData = wv_var
		if wv == null:
			continue
		var ratio: float = clampf(wv.timer / maxf(0.001, wv.duration), 0.0, 1.0)
		var col := Color(wv.color.r, wv.color.g, wv.color.b, wv.color.a * ratio)
		_d_line(to_screen(wv.start), to_screen(wv.end), col, 8.0 * ratio + 1.5)

	for sw_var in shockwave_visuals:
		var sw: CombatMath.ShockwaveVisualData = sw_var
		if sw == null:
			continue
		var ratio: float = clampf(sw.timer / maxf(0.001, sw.duration), 0.0, 1.0)
		var col := Color(sw.color.r, sw.color.g, sw.color.b, sw.color.a * ratio)
		_d_arc(to_screen(sw.origin), sw.current_radius, 0.0, TAU, 32, col, 3.5 * ratio + 1.0)

	for b_var in bullets:
		var b: CombatMath.BulletData = b_var
		if b == null:
			continue
		var b_scr: Vector2 = to_screen(b.position)
		var b_col: Color = Color(0.2, 1.0, 0.95, 1.0) if b.is_reflected else (Color(1.0, 0.25, 0.55, 1.0) if b.bounces_remaining > 0 else Color(1.0, 0.85, 0.2, 1.0))
		_d_circle(b_scr, b.radius, b_col)
		var tail_dir := Vector2(-b.velocity.x, b.velocity.y).normalized()
		_d_line(b_scr, b_scr + tail_dir * 16.0, Color(b_col.r, b_col.g, b_col.b, 0.65), 2.5)

	# 11. Top-Right Chronos Shift H-Gate Cockpit
	_draw_chrono_shift_cockpit()
	_is_in_canvas_draw_pass = false


func _draw_pose_skeleton(pose: ModularAssetSystem.StickmanPose, col: Color, width: float) -> void:
	if pose.head_radius > 0.0:
		_d_circle(to_screen(pose.head_center), pose.head_radius, col)
	var b_width: float = maxf(width, 6.0)
	_d_line(to_screen(pose.pelvis), to_screen(pose.neck), col, b_width * 1.2)
	_d_circle(to_screen(pose.neck), b_width * 0.5, col)
	_d_circle(to_screen(pose.pelvis), b_width * 0.5, col)
	_d_line(to_screen(pose.left_shoulder), to_screen(pose.left_elbow), col, b_width * 0.85)
	_d_circle(to_screen(pose.left_elbow), b_width * 0.4, col)
	_d_line(to_screen(pose.left_elbow), to_screen(pose.left_hand), col, b_width * 0.75)
	_d_circle(to_screen(pose.left_hand), b_width * 0.45, col)
	_d_line(to_screen(pose.right_shoulder), to_screen(pose.right_elbow), col, b_width * 0.95)
	_d_circle(to_screen(pose.right_elbow), b_width * 0.45, col)
	_d_line(to_screen(pose.right_elbow), to_screen(pose.right_hand), col, b_width * 0.85)
	_d_circle(to_screen(pose.right_hand), b_width * 0.5, col)
	_d_line(to_screen(pose.left_hip), to_screen(pose.left_knee), col, b_width * 0.95)
	_d_circle(to_screen(pose.left_knee), b_width * 0.45, col)
	_d_line(to_screen(pose.left_knee), to_screen(pose.left_foot), col, b_width * 0.85)
	_d_circle(to_screen(pose.left_foot), b_width * 0.45, col)
	_d_line(to_screen(pose.right_hip), to_screen(pose.right_knee), col, b_width * 1.05)
	_d_circle(to_screen(pose.right_knee), b_width * 0.5, col)
	_d_line(to_screen(pose.right_knee), to_screen(pose.right_foot), col, b_width * 0.95)
	_d_circle(to_screen(pose.right_foot), b_width * 0.5, col)
	if pose.sword_hilt != pose.sword_tip:
		_d_line(to_screen(pose.sword_hilt), to_screen(pose.sword_tip), col, b_width * 0.6)


func _draw_modular_character(
	pose: ModularAssetSystem.StickmanPose,
	loadout_id: String,
	facing: float,
	gear_alignment: float,
	alpha_mult: float,
	tint_color: Color = Color(0, 0, 0, 0),
	has_active_rig: bool = false
) -> void:
	var loadout := asset_registry.get_loadout(loadout_id)
	if loadout == null:
		var fallback_col := Color(1.0, 1.0, 1.0, alpha_mult) if tint_color.a <= 0.0 else Color(tint_color.r, tint_color.g, tint_color.b, tint_color.a * alpha_mult)
		_draw_pose_skeleton(pose, fallback_col, 2.5)
		return

	# Render all equipped anatomical & armor PartSlots
	for slot_key in loadout.parts.keys():
		var slot: int = int(slot_key)
		if slot == ModularAssetSystem.PartSlot.WEAPON_MAIN:
			continue
		var part: ModularAssetSystem.PartPieceSpec = loadout.parts[slot]
		if part == null:
			continue

		# Fast-path: procedural skeleton lines already drawn by active procedural rig
		if has_active_rig and part.backend == ModularAssetSystem.AssetRenderBackend.PROCEDURAL_VECTOR and slot != ModularAssetSystem.PartSlot.SCARF_CAPE:
			continue
		if has_active_rig and part.backend == ModularAssetSystem.AssetRenderBackend.PACKED_SCENE:
			continue

		var xform: Dictionary = ModularAssetSystem.StickmanPoseSolver.compute_slot_transform(pose, slot, facing)
		var start_sim: Vector2 = xform["start"]
		var end_sim: Vector2 = xform["end"]
		var center_sim: Vector2 = xform["center"] + part.offset
		var bone_angle: float = float(xform["angle"]) + part.rotation_offset
		var base_p: Color = tint_color if tint_color.a > 0.0 else part.primary_color
		var base_s: Color = tint_color if tint_color.a > 0.0 else part.secondary_color
		var p_col := Color(base_p.r, base_p.g, base_p.b, base_p.a * alpha_mult)
		var s_col := Color(base_s.r, base_s.g, base_s.b, base_s.a * alpha_mult)

		match part.backend:
			ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON:
				if part.polygon_points.size() >= 3:
					var scr_poly := PackedVector2Array()
					for pt in part.polygon_points:
						var scaled_pt := Vector2(pt.x * part.scale.x, pt.y * part.scale.y)
						var sim_pt: Vector2 = center_sim + scaled_pt.rotated(bone_angle)
						scr_poly.append(to_screen(sim_pt))
					_d_polygon(scr_poly, p_col)
				elif not has_active_rig:
					_d_line(to_screen(start_sim), to_screen(end_sim), p_col, part.line_width)

			ModularAssetSystem.AssetRenderBackend.TEXTURE_SPRITE:
				if part.texture != null:
					var tex_size: Vector2 = part.texture.get_size() * part.scale
					var scr_pos: Vector2 = to_screen(center_sim) - tex_size * 0.5
					_d_tex_rect(part.texture, Rect2(scr_pos, tex_size), false, p_col)
				elif not has_active_rig:
					_d_circle(to_screen(center_sim), 6.0, p_col)

			ModularAssetSystem.AssetRenderBackend.PACKED_SCENE:
				if not has_active_rig:
					_d_line(to_screen(start_sim), to_screen(end_sim), p_col, part.line_width)
					_d_circle(to_screen(center_sim), 3.0, s_col)

			_:
				if slot == ModularAssetSystem.PartSlot.SCARF_CAPE and pose.scarf_nodes.size() >= 3:
					var head_back: Vector2 = pose.head_center + Vector2((-1.0 if facing >= 0.0 else 1.0) * pose.head_radius, 0.0)
					_d_line(to_screen(head_back), to_screen(pose.scarf_nodes[0]), p_col, part.line_width)
					_d_line(to_screen(pose.scarf_nodes[0]), to_screen(pose.scarf_nodes[1]), p_col, part.line_width)
					_d_line(to_screen(pose.scarf_nodes[1]), to_screen(pose.scarf_nodes[2]), s_col, part.line_width * 0.85)
				elif not has_active_rig:
					if slot == ModularAssetSystem.PartSlot.HEAD:
						_d_arc(to_screen(pose.head_center), pose.head_radius, 0.0, TAU, 20, p_col, part.line_width)
					else:
						_d_line(to_screen(start_sim), to_screen(end_sim), p_col, part.line_width)

	# Render modular WeaponAssemblySpec (including Shift Staff interlocking cogs & key-teeth!)
	if loadout.weapon_assembly != null:
		var wp_xforms: Array[Dictionary] = loadout.weapon_assembly.compute_piece_transforms(
			pose.sword_hilt,
			pose.sword_tip,
			facing,
			gear_alignment,
			anim_time
		)
		for wp_item in wp_xforms:
			var base_wc: Color = tint_color if tint_color.a > 0.0 else wp_item["color"]
			var base_gc: Color = tint_color if tint_color.a > 0.0 else wp_item["glow_color"]
			var w_col := Color(base_wc.r, base_wc.g, base_wc.b, base_wc.a * alpha_mult)
			var g_col := Color(base_gc.r, base_gc.g, base_gc.b, base_gc.a * alpha_mult)
			var backend: int = int(wp_item["backend"])
			var w_slot: int = int(wp_item["piece_slot"])

			if backend == ModularAssetSystem.AssetRenderBackend.CUSTOM_POLYGON and (wp_item["polygon_world"] as PackedVector2Array).size() >= 3:
				var poly_sim: PackedVector2Array = wp_item["polygon_world"]
				var poly_scr := PackedVector2Array()
				for pt in poly_sim:
					poly_scr.append(to_screen(pt))
				_d_polygon(poly_scr, w_col)
			elif w_slot == ModularAssetSystem.WeaponPieceSlot.GEARWORK_CORE:
				var c_scr: Vector2 = to_screen(wp_item["center"])
				_d_arc(c_scr, 5.0, 0.0, TAU, 12, w_col, 2.2)
				var phase_angle: float = float(wp_item["rotation"])
				for cog_i in range(4):
					var ca: float = phase_angle + float(cog_i) * (PI * 0.5)
					var c_dir := Vector2(cos(ca), -sin(ca))
					_d_line(c_scr - c_dir * 6.5, c_scr + c_dir * 6.5, g_col, 1.8)
			elif w_slot == ModularAssetSystem.WeaponPieceSlot.KEY_TEETH:
				_d_line(to_screen(wp_item["center"]), to_screen(wp_item["tooth_tip"]), w_col, float(wp_item["thickness"]))
			else:
				_d_line(to_screen(wp_item["start"]), to_screen(wp_item["end"]), w_col, float(wp_item["thickness"]))


func _draw_ragdoll_piece(piece: RagdollPhysics.RagdollPieceData) -> void:
	var ratio: float = clampf(piece.lifetime / maxf(0.001, piece.max_lifetime), 0.0, 1.0)
	var suffix: String = "_upper" if piece.part == RagdollPhysics.RagdollPart.UPPER_TORSO else "_lower"
	var split_id: String = piece.loadout_id + suffix
	var split_lo := asset_registry.get_loadout(split_id)
	var base_lo := asset_registry.get_loadout(piece.loadout_id)
	if split_lo == null and base_lo != null:
		var split_dict: Dictionary = base_lo.split_for_ragdoll()
		asset_registry.register_loadout(split_dict["upper"])
		asset_registry.register_loadout(split_dict["lower"])
		split_lo = asset_registry.get_loadout(split_id)

	var active_lo := split_lo if split_lo != null else base_lo
	var target_lid: String = split_id if split_lo != null else piece.loadout_id

	var r_pose := ModularAssetSystem.StickmanPoseSolver.generate_ragdoll_pose(
		piece.position,
		piece.rotation,
		piece.facing,
		piece.part,
		piece.loadout_id
	)

	# Determine archetype color
	var base_col: Color = piece.color
	if base_col == Color.WHITE or base_col.a <= 0.0:
		if active_lo != null and active_lo.body_color.a > 0.0:
			base_col = active_lo.body_color
		else:
			match piece.loadout_id:
				"enemy_runner": base_col = Color(1.0, 0.32, 0.32)
				"enemy_ninja": base_col = Color(0.72, 0.28, 0.95)
				"enemy_heavy": base_col = Color(1.0, 0.55, 0.15)
				"enemy_gunner_semi": base_col = Color(0.25, 0.95, 0.45)
				"enemy_gunner_auto": base_col = Color(1.0, 0.85, 0.2)
				"enemy_sniper": base_col = Color(0.2, 0.75, 1.0)
				_: base_col = Color(0.9, 0.25, 0.25)

	var p_alpha: float = clampf(ratio * 1.15, 0.0, 1.0)
	var col := Color(base_col.r, base_col.g, base_col.b, p_alpha)
	var back_col := Color(base_col.r * 0.80, base_col.g * 0.80, base_col.b * 0.86, p_alpha)

	if piece.part == RagdollPhysics.RagdollPart.UPPER_TORSO:
		# Solid head with clean outline (One vs Many style)
		_d_circle(to_screen(r_pose.head_center), r_pose.head_radius, col)
		_d_arc(to_screen(r_pose.head_center), r_pose.head_radius, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.35 * p_alpha), 1.2)
		# Bold torso
		_d_line(to_screen(r_pose.pelvis), to_screen(r_pose.neck), col, 8.5)
		_d_circle(to_screen(r_pose.neck), 4.25, col)
		# Back arm
		_d_line(to_screen(r_pose.left_shoulder), to_screen(r_pose.left_elbow), back_col, 5.2)
		_d_circle(to_screen(r_pose.left_elbow), 2.6, back_col)
		_d_line(to_screen(r_pose.left_elbow), to_screen(r_pose.left_hand), back_col, 4.6)
		_d_circle(to_screen(r_pose.left_hand), 2.6, back_col)
		# Front arm
		_d_line(to_screen(r_pose.right_shoulder), to_screen(r_pose.right_elbow), col, 6.0)
		_d_circle(to_screen(r_pose.right_elbow), 3.0, col)
		_d_line(to_screen(r_pose.right_elbow), to_screen(r_pose.right_hand), col, 5.4)
		_d_circle(to_screen(r_pose.right_hand), 3.0, col)
		# Equipped weapon
		if r_pose.sword_hilt != r_pose.sword_tip:
			_d_line(to_screen(r_pose.sword_hilt), to_screen(r_pose.sword_tip), Color(0.95, 0.95, 0.98, p_alpha), 3.4)
		# Severed cut plane highlight (clean angled slice plane)
		var cut_tan := Vector2(cos(-piece.rotation), sin(-piece.rotation)).orthogonal()
		var c1 := to_screen(r_pose.pelvis) - cut_tan * 7.5
		var c2 := to_screen(r_pose.pelvis) + cut_tan * 7.5
		_d_line(c1, c2, Color(col.r * 1.3, col.g * 0.3, col.b * 0.3, 0.8 * p_alpha), 6.5)
		_d_line(c1, c2, Color(1.0, 1.0, 1.0, 0.95 * p_alpha), 3.0)
		if not piece.is_settled and ratio > 0.2:
			var trail_v: Vector2 = Vector2(-piece.velocity.x, piece.velocity.y) * 0.016
			_d_circle(to_screen(r_pose.pelvis) + trail_v, 2.8, Color(0.95, 0.15, 0.2, 0.85 * p_alpha))
			_d_circle(to_screen(r_pose.pelvis) + trail_v * 1.8, 1.8, Color(0.95, 0.15, 0.2, 0.65 * p_alpha))
		if piece.is_settled:
			var p_floor := to_screen(piece.position)
			_d_line(p_floor - Vector2(10.0, 0.0), p_floor + Vector2(10.0, 0.0), Color(0.85, 0.12, 0.18, 0.55 * p_alpha), 2.8)
	else:
		# Lower legs piece
		var cut_tan := Vector2(cos(-piece.rotation), sin(-piece.rotation)).orthogonal()
		var c1 := to_screen(r_pose.pelvis) - cut_tan * 7.5
		var c2 := to_screen(r_pose.pelvis) + cut_tan * 7.5
		_d_line(c1, c2, Color(col.r * 1.3, col.g * 0.3, col.b * 0.3, 0.8 * p_alpha), 6.5)
		_d_line(c1, c2, Color(1.0, 1.0, 1.0, 0.95 * p_alpha), 3.0)
		_d_circle(to_screen(r_pose.pelvis), 4.25, col)
		# Hips
		_d_line(to_screen(r_pose.pelvis), to_screen(r_pose.left_hip), back_col, 6.8)
		_d_line(to_screen(r_pose.pelvis), to_screen(r_pose.right_hip), col, 7.2)
		# Back leg
		_d_line(to_screen(r_pose.left_hip), to_screen(r_pose.left_knee), back_col, 6.0)
		_d_circle(to_screen(r_pose.left_knee), 3.0, back_col)
		_d_line(to_screen(r_pose.left_knee), to_screen(r_pose.left_foot), back_col, 5.2)
		_d_circle(to_screen(r_pose.left_foot), 2.8, back_col)
		# Front leg
		_d_line(to_screen(r_pose.right_hip), to_screen(r_pose.right_knee), col, 6.8)
		_d_circle(to_screen(r_pose.right_knee), 3.4, col)
		_d_line(to_screen(r_pose.right_knee), to_screen(r_pose.right_foot), col, 5.8)
		_d_circle(to_screen(r_pose.right_foot), 3.2, col)
		if not piece.is_settled and ratio > 0.2:
			var trail_v: Vector2 = Vector2(-piece.velocity.x, piece.velocity.y) * 0.016
			_d_circle(to_screen(r_pose.pelvis) + trail_v, 2.8, Color(0.95, 0.15, 0.2, 0.85 * p_alpha))
		if piece.is_settled:
			var p_floor := to_screen(piece.position)
			_d_line(p_floor - Vector2(10.0, 0.0), p_floor + Vector2(10.0, 0.0), Color(0.85, 0.12, 0.18, 0.55 * p_alpha), 2.8)

	# Draw equipped modular pieces/armor on top of ragdoll piece
	if active_lo != null:
		_draw_modular_character(r_pose, target_lid, piece.facing, 0.0, ratio, Color(0, 0, 0, 0), true)


func _draw_chrono_shift_cockpit() -> void:
	var alpha: float = maxf(shifter.model.fade, 0.35)
	var gate_center_sim: Vector2 = camera_sim_pos + ChronoShiftModel.GATE_CENTER
	var scale_px: float = ChronoShiftModel.GATE_SCALE

	var brass_col := Color(0.88, 0.72, 0.28, 0.90 * alpha)
	var cyan_col := Color(0.15, 0.95, 1.0, 0.92 * alpha)
	var dark_bg := Color(0.05, 0.07, 0.11, 0.78 * alpha)

	var center_scr: Vector2 = to_screen(gate_center_sim)
	_d_rect(Rect2(center_scr.x - 68.0, center_scr.y - 68.0, 136.0, 136.0), dark_bg, true)
	_d_rect(Rect2(center_scr.x - 68.0, center_scr.y - 68.0, 136.0, 136.0), brass_col, false, 2.0)

	# 1. H-Gate Channel Outline (ChronoShiftModel.gate_outline())
	var segments: Array = ChronoShiftModel.gate_outline()
	for seg in segments:
		var a_sim: Vector2 = gate_center_sim + (seg[0] as Vector2) * scale_px
		var b_sim: Vector2 = gate_center_sim + (seg[1] as Vector2) * scale_px
		_d_line(to_screen(a_sim), to_screen(b_sim), brass_col, 2.2)

	# 2. 7-Segment Gear Glyphs (1..6 and R)
	var active_gear: int = shifter.model.get_active_gear()
	for g in [
		ChronoShiftModel.Gear.G1,
		ChronoShiftModel.Gear.G2,
		ChronoShiftModel.Gear.G3,
		ChronoShiftModel.Gear.G4,
		ChronoShiftModel.Gear.G5,
		ChronoShiftModel.Gear.G6,
	]:
		var g_pos: Vector2 = ChronoShiftModel.gear_pos(g)
		var glyph_sim: Vector2 = gate_center_sim + Vector2(g_pos.x * scale_px, g_pos.y * (scale_px + 15.0))
		var lbl: String = ChronoShiftModel.gear_label(g)
		if g == ChronoShiftModel.Gear.G6 and active_gear == ChronoShiftModel.Gear.R:
			lbl = "R"
		var is_selected: bool = (active_gear == g) or (g == ChronoShiftModel.Gear.G6 and active_gear == ChronoShiftModel.Gear.R)
		var glyph_col: Color = cyan_col if is_selected else Color(0.75, 0.65, 0.35, 0.65 * alpha)
		_draw_seven_segment_glyph(to_screen(glyph_sim), lbl, 4.5, glyph_col)

	# 3. Key-Bit Shaft from Neutral Rail to Knob
	var knob: Vector2 = shifter.model.knob
	var rail_anchor_sim: Vector2 = gate_center_sim + Vector2(knob.x * scale_px, 0.0)
	var knob_sim: Vector2 = gate_center_sim + knob * scale_px
	var rail_scr: Vector2 = to_screen(rail_anchor_sim)
	var knob_scr: Vector2 = to_screen(knob_sim)
	_d_line(rail_scr, knob_scr, cyan_col, 3.2)

	# Key teeth along shaft when engaged in slot
	if absf(knob.y) > 0.2:
		var mid_scr: Vector2 = (rail_scr + knob_scr) * 0.5
		_d_line(mid_scr, mid_scr + Vector2(7.0, 0.0), brass_col, 2.2)
		_d_line(mid_scr + Vector2(0.0, 4.0), mid_scr + Vector2(5.0, 4.0), brass_col, 2.0)

	# 4. Rotating 10-Tooth Brass/Cyan Cog Knob
	var knob_radius: float = 9.5
	var cog_rot: float = anim_time * (2.5 if chrono.is_dilating else 0.5)
	for i in range(10):
		var a: float = cog_rot + float(i) * (TAU / 10.0)
		var d := Vector2(cos(a), sin(a))
		_d_line(knob_scr + d * (knob_radius - 1.0), knob_scr + d * (knob_radius + 3.5), brass_col, 2.2)
	_d_circle(knob_scr, knob_radius, Color(0.12, 0.16, 0.22, 0.95 * alpha))
	_d_arc(knob_scr, knob_radius, 0.0, TAU, 20, cyan_col, 2.2)
	_d_circle(knob_scr, 3.5, cyan_col)


func _draw_seven_segment_glyph(center_scr: Vector2, ch: String, half_size: float, col: Color) -> void:
	var segs: Array[bool] = ChronoShiftModel.seven_segments(ch)
	if segs.size() < 7:
		return
	var w: float = half_size * 0.75
	var h: float = half_size
	var pt_tl := center_scr + Vector2(-w, -h)
	var pt_tr := center_scr + Vector2(w, -h)
	var pt_ml := center_scr + Vector2(-w, 0.0)
	var pt_mr := center_scr + Vector2(w, 0.0)
	var pt_bl := center_scr + Vector2(-w, h)
	var pt_br := center_scr + Vector2(w, h)

	if segs[0]:
		_d_line(pt_tl, pt_tr, col, 1.8) # a (top)
	if segs[1]:
		_d_line(pt_tr, pt_mr, col, 1.8) # b (top-right)
	if segs[2]:
		_d_line(pt_mr, pt_br, col, 1.8) # c (bottom-right)
	if segs[3]:
		_d_line(pt_bl, pt_br, col, 1.8) # d (bottom)
	if segs[4]:
		_d_line(pt_ml, pt_bl, col, 1.8) # e (bottom-left)
	if segs[5]:
		_d_line(pt_tl, pt_ml, col, 1.8) # f (top-left)
	if segs[6]:
		_d_line(pt_ml, pt_mr, col, 1.8) # g (middle)
