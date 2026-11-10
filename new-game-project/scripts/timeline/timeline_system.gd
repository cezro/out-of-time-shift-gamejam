class_name TimelineSystem
extends RefCounted

## OUT OF TIME — 3-Era Parallel Timeline System, Chronos Wells, Phase Traversal,
## Hazard Phasing, Momentum Chaining, Chrono-Echoes, and Hidden Lore Glyphs.

enum TimelineEra {
	PAST = 0,
	PRESENT = 1,
	FUTURE = 2,
}

enum GameMode {
	HORDE_ARENA = 0,
	CAMPAIGN_TRAVERSAL = 1,
}

# ---------------------------------------------------------------------------------------------
# Data Structures
# ---------------------------------------------------------------------------------------------

class ChronosWellData extends RefCounted:
	var id: String = ""
	var position: Vector2 = Vector2.ZERO
	var interact_radius: float = 68.0
	var is_active_checkpoint: bool = false
	var staff_inserted_anim: float = 0.0

	func _init(
		p_id: String = "",
		p_position: Vector2 = Vector2.ZERO,
		p_interact_radius: float = 68.0,
		p_is_active_checkpoint: bool = false
	) -> void:
		id = p_id
		position = p_position
		interact_radius = p_interact_radius
		is_active_checkpoint = p_is_active_checkpoint

class PhasePlatformData extends RefCounted:
	var min_x: float = 0.0
	var max_x: float = 0.0
	var y: float = 0.0
	var thickness: float = 12.0
	## -1 = present in all eras, 0 = Past stone bridge, 1 = Present steel catwalk, 2 = Future hard-light bridge
	var era: int = -1

	func _init(
		p_center_x: float = 0.0,
		p_y: float = 0.0,
		p_width: float = 200.0,
		p_era: int = -1,
		p_thickness: float = 12.0
	) -> void:
		min_x = p_center_x - p_width * 0.5
		max_x = p_center_x + p_width * 0.5
		y = p_y
		era = p_era
		thickness = p_thickness

	static func from_bounds(
		p_min_x: float,
		p_max_x: float,
		p_y: float,
		p_era: int = -1,
		p_thickness: float = 12.0
	) -> PhasePlatformData:
		var plat := PhasePlatformData.new()
		plat.min_x = minf(p_min_x, p_max_x)
		plat.max_x = maxf(p_min_x, p_max_x)
		plat.y = p_y
		plat.era = p_era
		plat.thickness = p_thickness
		return plat

	func center_x() -> float:
		return (min_x + max_x) * 0.5

	func width() -> float:
		return max_x - min_x

	func is_active_in_era(current_era: int) -> bool:
		return era == -1 or era == current_era

	func contains_x(px: float) -> bool:
		return px >= min_x and px <= max_x

class LaserHazardData extends RefCounted:
	var x: float = 0.0
	var min_y: float = -220.0
	var max_y: float = 120.0
	var era: int = TimelineEra.FUTURE
	var half_width: float = 14.0

	func _init(
		p_x: float = 0.0,
		p_min_y: float = -220.0,
		p_max_y: float = 120.0,
		p_era: int = TimelineEra.FUTURE,
		p_half_width: float = 14.0
	) -> void:
		x = p_x
		min_y = minf(p_min_y, p_max_y)
		max_y = maxf(p_min_y, p_max_y)
		era = p_era
		half_width = p_half_width

class JumpPadData extends RefCounted:
	var position: Vector2 = Vector2.ZERO
	var width: float = 70.0
	var boost_velocity: Vector2 = Vector2(0.0, 820.0)
	var era: int = TimelineEra.FUTURE

	func _init(
		p_position: Vector2 = Vector2.ZERO,
		p_width: float = 70.0,
		p_boost_velocity: Vector2 = Vector2(0.0, 820.0),
		p_era: int = TimelineEra.FUTURE
	) -> void:
		position = p_position
		width = p_width
		boost_velocity = p_boost_velocity
		era = p_era

class VineClimbData extends RefCounted:
	var x: float = 0.0
	var min_y: float = -80.0
	var max_y: float = 180.0
	var era: int = TimelineEra.PAST
	var grab_radius: float = 28.0

	func _init(
		p_x: float = 0.0,
		p_min_y: float = -80.0,
		p_max_y: float = 180.0,
		p_era: int = TimelineEra.PAST,
		p_grab_radius: float = 28.0
	) -> void:
		x = p_x
		min_y = minf(p_min_y, p_max_y)
		max_y = maxf(p_min_y, p_max_y)
		era = p_era
		grab_radius = p_grab_radius

class ChronoEchoData extends RefCounted:
	var origin: Vector2 = Vector2.ZERO
	var aim_dir: Vector2 = Vector2.RIGHT
	var era: int = TimelineEra.PRESENT
	var timer: float = 3.0
	var max_timer: float = 3.0
	var radius: float = 95.0
	var echo_type: String = "slash"
	var facing: float = 1.0
	var velocity: Vector2 = Vector2.ZERO
	var is_grounded: bool = true
	var stance: String = "normal"
	var anim_time: float = 0.0
	var loadout_id: String = "player_shift_staff"
	var is_attacking: bool = false
	var attack_progress: float = 0.0

	func _init(
		p_origin: Vector2 = Vector2.ZERO,
		p_aim_dir: Vector2 = Vector2.RIGHT,
		p_era: int = TimelineEra.PRESENT,
		p_echo_type: String = "slash",
		p_radius: float = 95.0,
		p_timer: float = 3.0,
		p_facing: float = 1.0,
		p_velocity: Vector2 = Vector2.ZERO,
		p_grounded: bool = true,
		p_stance: String = "normal",
		p_anim_time: float = 0.0,
		p_loadout_id: String = "player_shift_staff"
	) -> void:
		origin = Vector2(
			p_origin.x if is_finite(p_origin.x) else 0.0,
			p_origin.y if is_finite(p_origin.y) else 0.0
		)
		aim_dir = (
			p_aim_dir.normalized()
			if (is_finite(p_aim_dir.x) and is_finite(p_aim_dir.y) and p_aim_dir.length_squared() > 1e-6)
			else Vector2.RIGHT
		)
		era = p_era
		echo_type = p_echo_type
		radius = maxf(1.0, p_radius) if is_finite(p_radius) else 95.0
		var safe_t: float = maxf(0.01, p_timer) if is_finite(p_timer) else 3.0
		timer = safe_t
		max_timer = safe_t
		facing = 1.0 if (is_finite(p_facing) and p_facing >= 0.0) else -1.0
		velocity = Vector2(
			p_velocity.x if is_finite(p_velocity.x) else 0.0,
			p_velocity.y if is_finite(p_velocity.y) else 0.0
		)
		is_grounded = p_grounded
		stance = p_stance if not p_stance.is_empty() else "normal"
		anim_time = fmod(p_anim_time, 10000.0) if is_finite(p_anim_time) else 0.0
		loadout_id = p_loadout_id if not p_loadout_id.is_empty() else "player_shift_staff"
		is_attacking = (echo_type == "slash" or echo_type == "heavy")
		attack_progress = 0.55 if echo_type == "slash" else (0.65 if echo_type == "heavy" else 0.0)

	func fade_ratio() -> float:
		return clampf(timer / maxf(0.001, max_timer), 0.0, 1.0)


class LoreGlyphData extends RefCounted:
	var id: String = ""
	var title: String = ""
	var position: Vector2 = Vector2.ZERO
	var era: int = TimelineEra.PAST
	var radius: float = 28.0
	var collected: bool = false

	func _init(
		p_id: String = "",
		p_title: String = "",
		p_position: Vector2 = Vector2.ZERO,
		p_era: int = TimelineEra.PAST,
		p_radius: float = 28.0
	) -> void:
		id = p_id
		title = p_title
		position = p_position
		era = p_era
		radius = p_radius
		collected = false

# ---------------------------------------------------------------------------------------------
# Static Era Helpers
# ---------------------------------------------------------------------------------------------

static func get_era_name(era: int) -> String:
	match era:
		TimelineEra.PAST:
			return "PAST"
		TimelineEra.PRESENT:
			return "PRESENT"
		TimelineEra.FUTURE:
			return "FUTURE"
		_:
			return "PRESENT"

static func get_era_palette(era: int) -> Dictionary:
	match era:
		TimelineEra.PAST:
			return {
				"name": "PAST",
				"subtitle": "ANCIENT RUINS",
				"bg_color": Color(0.11, 0.09, 0.06, 1.0),
				"platform_color": Color(0.68, 0.56, 0.36, 1.0),
				"accent_color": Color(0.45, 0.85, 0.38, 1.0),
				"ghost_color": Color(0.68, 0.56, 0.36, 0.22),
			}
		TimelineEra.PRESENT:
			return {
				"name": "PRESENT",
				"subtitle": "INDUSTRIAL CLOCKWORK",
				"bg_color": Color(0.08, 0.10, 0.14, 1.0),
				"platform_color": Color(0.75, 0.62, 0.34, 1.0),
				"accent_color": Color(0.25, 0.90, 1.00, 1.0),
				"ghost_color": Color(0.75, 0.62, 0.34, 0.22),
			}
		TimelineEra.FUTURE:
			return {
				"name": "FUTURE",
				"subtitle": "NEON SINGULARITY",
				"bg_color": Color(0.05, 0.04, 0.12, 1.0),
				"platform_color": Color(0.20, 0.95, 1.00, 1.0),
				"accent_color": Color(1.00, 0.22, 0.68, 1.0),
				"ghost_color": Color(0.20, 0.95, 1.00, 0.22),
			}
		_:
			return get_era_palette(TimelineEra.PRESENT)

# ---------------------------------------------------------------------------------------------
# TimelineState
# ---------------------------------------------------------------------------------------------

class TimelineState extends RefCounted:
	var current_era: int = TimelineEra.PRESENT
	var previous_era: int = TimelineEra.PAST
	var mode: int = GameMode.HORDE_ARENA
	var shift_flash_timer: float = 0.0
	var checkpoint_pos: Vector2 = Vector2(0.0, -200.0)
	var checkpoint_era: int = TimelineEra.PRESENT

	var chronos_wells: Array[ChronosWellData] = []
	var platforms: Array[PhasePlatformData] = []
	var lasers: Array[LaserHazardData] = []
	var jump_pads: Array[JumpPadData] = []
	var vines: Array[VineClimbData] = []
	var echoes: Array[ChronoEchoData] = []
	var lore_glyphs: Array[LoreGlyphData] = []
	var era_enemy_stack_timers: Array[float] = [0.0, 0.0, 0.0]

	func _init() -> void:
		era_enemy_stack_timers = [0.0, 0.0, 0.0]
		setup_horde_arena()

	func _clear_entities() -> void:
		chronos_wells.clear()
		platforms.clear()
		lasers.clear()
		jump_pads.clear()
		vines.clear()
		echoes.clear()
		lore_glyphs.clear()
		era_enemy_stack_timers = [0.0, 0.0, 0.0]

	## Sets up the Horde Arena with Chronos Wells, Past ancient ruin pillars/vines,
	## Present industrial catwalks matching bevy-game-test (-300,-120), (300,-120), (0,20),
	## and Future hard-light high bridges + jump pads.
	func setup_horde_arena() -> void:
		_clear_entities()
		mode = GameMode.HORDE_ARENA
		current_era = TimelineEra.PRESENT
		previous_era = TimelineEra.PAST
		checkpoint_pos = Vector2(0.0, -200.0)
		checkpoint_era = TimelineEra.PRESENT

		# Chronos Wells
		chronos_wells.append(ChronosWellData.new("well_arena_center", Vector2(0.0, -200.0), 68.0, true))
		chronos_wells.append(ChronosWellData.new("well_arena_left", Vector2(-300.0, -120.0), 68.0, false))
		chronos_wells.append(ChronosWellData.new("well_arena_right", Vector2(300.0, -120.0), 68.0, false))

		# Present industrial catwalks matching bevy-game-test: (-300,-120,w=240), (300,-120,w=240), (0,20,w=200)
		platforms.append(PhasePlatformData.new(-300.0, -120.0, 240.0, TimelineEra.PRESENT, 12.0))
		platforms.append(PhasePlatformData.new(300.0, -120.0, 240.0, TimelineEra.PRESENT, 12.0))
		platforms.append(PhasePlatformData.new(0.0, 20.0, 200.0, TimelineEra.PRESENT, 12.0))

		# Past ancient ruin stone bridges
		platforms.append(PhasePlatformData.new(-220.0, -90.0, 220.0, TimelineEra.PAST, 14.0))
		platforms.append(PhasePlatformData.new(220.0, -90.0, 220.0, TimelineEra.PAST, 14.0))
		platforms.append(PhasePlatformData.new(0.0, 50.0, 260.0, TimelineEra.PAST, 14.0))

		# Future hard-light high bridges
		platforms.append(PhasePlatformData.new(-320.0, -60.0, 200.0, TimelineEra.FUTURE, 10.0))
		platforms.append(PhasePlatformData.new(320.0, -60.0, 200.0, TimelineEra.FUTURE, 10.0))
		platforms.append(PhasePlatformData.new(0.0, 90.0, 240.0, TimelineEra.FUTURE, 10.0))

		# Past hanging vines
		vines.append(VineClimbData.new(-180.0, -120.0, 60.0, TimelineEra.PAST))
		vines.append(VineClimbData.new(180.0, -120.0, 60.0, TimelineEra.PAST))

		# Future energy jump pads
		jump_pads.append(JumpPadData.new(Vector2(-420.0, -200.0), 70.0, Vector2(0.0, 820.0), TimelineEra.FUTURE))
		jump_pads.append(JumpPadData.new(Vector2(420.0, -200.0), 70.0, Vector2(0.0, 820.0), TimelineEra.FUTURE))

		# Future security laser grid
		lasers.append(LaserHazardData.new(-520.0, -200.0, 80.0, TimelineEra.FUTURE))
		lasers.append(LaserHazardData.new(520.0, -200.0, 80.0, TimelineEra.FUTURE))

		# Hidden Lore Glyphs across the 3 eras
		lore_glyphs.append(LoreGlyphData.new("arena_glyph_past", "Root of the Sundial", Vector2(0.0, 75.0), TimelineEra.PAST))
		lore_glyphs.append(LoreGlyphData.new("arena_glyph_present", "Gearwright's Oath", Vector2(-300.0, -95.0), TimelineEra.PRESENT))
		lore_glyphs.append(LoreGlyphData.new("arena_glyph_future", "Echoes Beyond Zero", Vector2(0.0, 115.0), TimelineEra.FUTURE))

	## Sets up a multi-zone traversal course implementing all 3 PDF Phase Traversal Scenarios:
	## Zone 1: Missing Platforms pit crossed via Past stone bridge or Future hard-light platform.
	## Zone 2: Hazard Phasing Future vertical laser grid bypassed by shifting to Present mid-dash.
	## Zone 3: Momentum Chaining Future energy jump pad -> Past hanging vine -> Present catwalk,
	## plus 3 hidden Lore Glyphs in timeline pockets.
	func setup_campaign_traversal() -> void:
		_clear_entities()
		mode = GameMode.CAMPAIGN_TRAVERSAL
		current_era = TimelineEra.PRESENT
		previous_era = TimelineEra.PAST
		checkpoint_pos = Vector2(0.0, -200.0)
		checkpoint_era = TimelineEra.PRESENT

		# --- Zone 1: Missing Platforms (x = -100 .. 600) ---
		# Starting ground present in all eras
		platforms.append(PhasePlatformData.new(0.0, -200.0, 200.0, -1, 14.0))
		chronos_wells.append(ChronosWellData.new("well_zone1_start", Vector2(0.0, -200.0), 68.0, true))

		# Pit at x = 100..500: missing in Present! Intact in Past (stone bridge) and Future (hard-light bridge)
		platforms.append(PhasePlatformData.new(300.0, -200.0, 320.0, TimelineEra.PAST, 14.0))
		platforms.append(PhasePlatformData.new(300.0, -180.0, 320.0, TimelineEra.FUTURE, 10.0))

		# Zone 2 entry platform (all eras)
		platforms.append(PhasePlatformData.new(600.0, -200.0, 220.0, -1, 14.0))
		chronos_wells.append(ChronosWellData.new("well_zone2_entry", Vector2(600.0, -200.0), 68.0, false))

		# --- Zone 2: Hazard Phasing (x = 600 .. 1100) ---
		platforms.append(PhasePlatformData.new(850.0, -200.0, 500.0, -1, 14.0))
		# Future vertical laser grid at x = 850: lethal in Future, harmless unpowered drywall in Present/Past
		lasers.append(LaserHazardData.new(850.0, -220.0, 120.0, TimelineEra.FUTURE, 16.0))
		chronos_wells.append(ChronosWellData.new("well_zone3_entry", Vector2(1100.0, -200.0), 68.0, false))

		# --- Zone 3: Momentum Chaining (x = 1100 .. 1680) ---
		platforms.append(PhasePlatformData.new(1220.0, -200.0, 240.0, -1, 14.0))
		# Step 1: Future energy jump pad launches player upward at x = 1250
		jump_pads.append(JumpPadData.new(Vector2(1250.0, -200.0), 70.0, Vector2(0.0, 820.0), TimelineEra.FUTURE))
		# Step 2: Past dense hanging vine at x = 1350 snagged mid-flight
		vines.append(VineClimbData.new(1350.0, -40.0, 220.0, TimelineEra.PAST, 30.0))
		# Step 3: Present high steel catwalk at x = 1550, y = 120
		platforms.append(PhasePlatformData.new(1550.0, 120.0, 260.0, TimelineEra.PRESENT, 12.0))
		chronos_wells.append(ChronosWellData.new("well_zone3_summit", Vector2(1550.0, 120.0), 68.0, false))

		# --- 3 Hidden Lore Glyphs in timeline pockets ---
		lore_glyphs.append(LoreGlyphData.new("glyph_past_bridge", "Chronicle of the Sovereign Stone", Vector2(300.0, -170.0), TimelineEra.PAST, 28.0))
		lore_glyphs.append(LoreGlyphData.new("glyph_present_conduit", "Dead-Grid Maintenance Log", Vector2(850.0, -170.0), TimelineEra.PRESENT, 28.0))
		lore_glyphs.append(LoreGlyphData.new("glyph_future_zenith", "Singularity Spire Transmission", Vector2(1550.0, 150.0), TimelineEra.FUTURE, 28.0))

	func is_near_chronos_well(player_pos: Vector2) -> ChronosWellData:
		if not is_finite(player_pos.x) or not is_finite(player_pos.y):
			return null
		var best_well: ChronosWellData = null
		var best_dist: float = INF
		for well in chronos_wells:
			var d: float = well.position.distance_to(player_pos)
			if d <= well.interact_radius and d < best_dist:
				best_dist = d
				best_well = well
		return best_well

	## Cycles PAST -> PRESENT -> FUTURE -> PAST or shifts to target_era, updates checkpoint if at a
	## Chronos Well, preserves player velocity/momentum, and triggers any ChronoEchoData waiting in current_era!
	func try_shift_timeline(
		player_pos: Vector2,
		target_era: int = -1,
		require_well: bool = false,
		player_velocity: Vector2 = Vector2.ZERO
	) -> Dictionary:
		var safe_pos := Vector2(
			player_pos.x if is_finite(player_pos.x) else 0.0,
			player_pos.y if is_finite(player_pos.y) else -200.0
		)
		var safe_vel := Vector2(
			player_velocity.x if is_finite(player_velocity.x) else 0.0,
			player_velocity.y if is_finite(player_velocity.y) else 0.0
		)
		var well: ChronosWellData = is_near_chronos_well(safe_pos)
		if require_well and well == null:
			return {
				"shifted": false,
				"new_era": current_era,
				"previous_era": previous_era,
				"detonated_echoes": [],
				"preserved_velocity": safe_vel,
				"checkpoint_updated": false,
			}

		var next_era: int = (current_era + 1) % 3
		if target_era >= 0 and target_era <= 2:
			next_era = target_era

		if next_era == current_era:
			return {
				"shifted": false,
				"new_era": current_era,
				"previous_era": previous_era,
				"detonated_echoes": [],
				"preserved_velocity": safe_vel,
				"checkpoint_updated": false,
			}

		previous_era = current_era
		current_era = next_era
		shift_flash_timer = 0.35

		var checkpoint_updated: bool = false
		if well != null:
			for w in chronos_wells:
				w.is_active_checkpoint = (w == well)
			well.staff_inserted_anim = 1.0
			checkpoint_pos = well.position
			checkpoint_era = current_era
			checkpoint_updated = true

		# Detonate any ChronoEchoData waiting in the newly entered era
		var detonated_echoes: Array[ChronoEchoData] = []
		var remaining_echoes: Array[ChronoEchoData] = []
		for echo in echoes:
			if echo.era == current_era and echo.timer > 0.0:
				detonated_echoes.append(echo)
			elif echo.timer > 0.0:
				remaining_echoes.append(echo)
		echoes = remaining_echoes

		era_enemy_stack_timers[current_era] = 0.0

		return {
			"shifted": true,
			"new_era": current_era,
			"previous_era": previous_era,
			"detonated_echoes": detonated_echoes,
			"preserved_velocity": safe_vel,
			"checkpoint_updated": checkpoint_updated,
		}

	func spawn_chrono_echo(
		origin: Vector2,
		aim_dir: Vector2,
		era: int,
		echo_type: String = "slash",
		p_radius: float = 95.0,
		p_timer: float = 3.0,
		p_facing: float = 1.0,
		p_velocity: Vector2 = Vector2.ZERO,
		p_grounded: bool = true,
		p_stance: String = "normal",
		p_anim_time: float = 0.0,
		p_loadout_id: String = "player_shift_staff"
	) -> ChronoEchoData:
		var echo := ChronoEchoData.new(
			origin,
			aim_dir,
			era,
			echo_type,
			p_radius,
			p_timer,
			p_facing,
			p_velocity,
			p_grounded,
			p_stance,
			p_anim_time,
			p_loadout_id
		)
		echoes.append(echo)
		return echo

	func tick(dt: float) -> void:
		var clean_dt: float = maxf(dt, 0.0) if is_finite(dt) else 0.0
		if shift_flash_timer > 0.0:
			shift_flash_timer = maxf(shift_flash_timer - clean_dt, 0.0)

		for well in chronos_wells:
			if well.staff_inserted_anim > 0.0:
				well.staff_inserted_anim = maxf(well.staff_inserted_anim - clean_dt * 2.0, 0.0)

		# Decay active Chrono-Echoes
		var active_echoes: Array[ChronoEchoData] = []
		for echo in echoes:
			echo.timer = maxf(echo.timer - clean_dt, 0.0)
			if echo.timer > 0.0:
				active_echoes.append(echo)
		echoes = active_echoes

		# Track enemy stacking timers in parallel timelines
		for e_idx in range(3):
			if e_idx == current_era:
				era_enemy_stack_timers[e_idx] = 0.0
			else:
				era_enemy_stack_timers[e_idx] += clean_dt

	func get_active_platforms() -> Array[PhasePlatformData]:
		var result: Array[PhasePlatformData] = []
		for p in platforms:
			if p.era == -1 or p.era == current_era:
				result.append(p)
		return result

	func get_inactive_platforms() -> Array[PhasePlatformData]:
		var result: Array[PhasePlatformData] = []
		for p in platforms:
			if p.era != -1 and p.era != current_era:
				result.append(p)
		return result

	func check_laser_hazard(player_pos: Vector2, player_invulnerable: bool) -> bool:
		if player_invulnerable:
			return false
		for laser in lasers:
			if (laser.era == -1 or laser.era == current_era):
				if absf(player_pos.x - laser.x) <= laser.half_width and player_pos.y >= laser.min_y and player_pos.y <= laser.max_y:
					return true
		return false

	func check_jump_pad(player_pos: Vector2, player_vy: float) -> Vector2:
		for pad in jump_pads:
			if pad.era == -1 or pad.era == current_era:
				if absf(player_pos.x - pad.position.x) <= pad.width * 0.5 and absf(player_pos.y - pad.position.y) <= 28.0 and player_vy <= 50.0:
					return pad.boost_velocity
		return Vector2.ZERO

	func check_vine_grab(player_pos: Vector2) -> VineClimbData:
		for vine in vines:
			if vine.era == -1 or vine.era == current_era:
				if absf(player_pos.x - vine.x) <= vine.grab_radius and player_pos.y >= vine.min_y and player_pos.y <= vine.max_y:
					return vine
		return null

	func check_lore_glyphs(player_pos: Vector2) -> Array[LoreGlyphData]:
		var newly_collected: Array[LoreGlyphData] = []
		for glyph in lore_glyphs:
			if not glyph.collected and (glyph.era == -1 or glyph.era == current_era):
				if glyph.position.distance_to(player_pos) <= glyph.radius:
					glyph.collected = true
					newly_collected.append(glyph)
		return newly_collected

	func get_era_name(era: int = -1) -> String:
		var target: int = current_era if era < 0 else era
		match target:
			TimelineEra.PAST:
				return "PAST"
			TimelineEra.PRESENT:
				return "PRESENT"
			TimelineEra.FUTURE:
				return "FUTURE"
			_:
				return "PRESENT"

	func get_era_palette(era: int = -1) -> Dictionary:
		var target: int = current_era if era < 0 else era
		match target:
			TimelineEra.PAST:
				return {
					"name": "PAST",
					"subtitle": "ANCIENT RUINS",
					"bg_color": Color(0.11, 0.09, 0.06, 1.0),
					"platform_color": Color(0.68, 0.56, 0.36, 1.0),
					"accent_color": Color(0.45, 0.85, 0.38, 1.0),
					"ghost_color": Color(0.68, 0.56, 0.36, 0.22),
				}
			TimelineEra.PRESENT:
				return {
					"name": "PRESENT",
					"subtitle": "INDUSTRIAL CLOCKWORK",
					"bg_color": Color(0.08, 0.10, 0.14, 1.0),
					"platform_color": Color(0.75, 0.62, 0.34, 1.0),
					"accent_color": Color(0.25, 0.90, 1.00, 1.0),
					"ghost_color": Color(0.75, 0.62, 0.34, 0.22),
				}
			TimelineEra.FUTURE:
				return {
					"name": "FUTURE",
					"subtitle": "NEON SINGULARITY",
					"bg_color": Color(0.05, 0.04, 0.12, 1.0),
					"platform_color": Color(0.20, 0.95, 1.00, 1.0),
					"accent_color": Color(1.00, 0.22, 0.68, 1.0),
					"ghost_color": Color(0.20, 0.95, 1.00, 0.22),
				}
			_:
				return get_era_palette(TimelineEra.PRESENT)
