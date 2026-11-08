class_name ModularAssetSystem
extends RefCounted

## Procedural Piece-by-Piece Modular Rig & Asset System for OUT OF TIME.
## Ports bevy-game-test's StickmanPose / generate_stickman_pose and extends it with:
## - 20 anatomical & equipment PartSlots
## - 11 modular WeaponPieceSlots (including the interlocking Shift Staff / Chronos Key)
## - 4 render backends (PROCEDURAL_VECTOR, TEXTURE_SPRITE, CUSTOM_POLYGON, PACKED_SCENE)
## - Ragdoll upper/lower loadout splitting on slice kills
## - Runtime & JSON manifest piece-by-piece injection for godot-mcp compatibility

enum PartSlot {
	HEAD = 0,
	EYES = 1,
	HAT_HELMET = 2,
	SCARF_CAPE = 3,
	TORSO = 4,
	PELVIS = 5,
	UPPER_ARM_L = 6,
	FOREARM_L = 7,
	HAND_L = 8,
	UPPER_ARM_R = 9,
	FOREARM_R = 10,
	HAND_R = 11,
	THIGH_L = 12,
	SHIN_L = 13,
	FOOT_L = 14,
	THIGH_R = 15,
	SHIN_R = 16,
	FOOT_R = 17,
	WEAPON_MAIN = 18,
	WEAPON_OFFHAND = 19,
}

enum WeaponPieceSlot {
	POMMEL = 0,
	GRIP = 1,
	GUARD = 2,
	SHAFT_LOWER = 3,
	GEARWORK_CORE = 4,
	SHAFT_UPPER = 5,
	BLADE_EDGE = 6,
	KEY_TEETH = 7,
	MUZZLE_BARREL = 8,
	OPTIC_SCOPE = 9,
	MAGAZINE = 10,
}

enum AssetRenderBackend {
	PROCEDURAL_VECTOR = 0,
	TEXTURE_SPRITE = 1,
	CUSTOM_POLYGON = 2,
	PACKED_SCENE = 3,
}

const UPPER_BODY_SLOTS: Array[int] = [
	PartSlot.HEAD,
	PartSlot.EYES,
	PartSlot.HAT_HELMET,
	PartSlot.SCARF_CAPE,
	PartSlot.TORSO,
	PartSlot.UPPER_ARM_L,
	PartSlot.FOREARM_L,
	PartSlot.HAND_L,
	PartSlot.UPPER_ARM_R,
	PartSlot.FOREARM_R,
	PartSlot.HAND_R,
]

const LOWER_BODY_SLOTS: Array[int] = [
	PartSlot.PELVIS,
	PartSlot.THIGH_L,
	PartSlot.SHIN_L,
	PartSlot.FOOT_L,
	PartSlot.THIGH_R,
	PartSlot.SHIN_R,
	PartSlot.FOOT_R,
]


# ============================================================================
# Serialization Conversion Helpers
# ============================================================================

class _Ser:
	static func color_to_dict(c: Color) -> Dictionary:
		return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "hex": c.to_html(true)}

	static func color_from_variant(v: Variant, fallback: Color = Color.WHITE) -> Color:
		if v is Color:
			return v
		if v is String:
			var s: String = v
			if Color.html_is_valid(s):
				return Color.html(s)
			return fallback
		if v is Dictionary:
			var d: Dictionary = v
			if d.has("r") and d.has("g") and d.has("b"):
				return Color(
					float(d.get("r", 1.0)),
					float(d.get("g", 1.0)),
					float(d.get("b", 1.0)),
					float(d.get("a", 1.0))
				)
			if d.has("hex") and Color.html_is_valid(str(d["hex"])):
				return Color.html(str(d["hex"]))
		if v is Array:
			var arr: Array = v
			if arr.size() >= 4:
				return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
			elif arr.size() == 3:
				return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
		return fallback

	static func vec2_to_dict(v: Vector2) -> Dictionary:
		return {"x": v.x, "y": v.y}

	static func vec2_from_variant(v: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
		if v is Vector2:
			return v
		if v is Dictionary:
			var d: Dictionary = v
			return Vector2(float(d.get("x", fallback.x)), float(d.get("y", fallback.y)))
		if v is Array:
			var arr: Array = v
			if arr.size() >= 2:
				return Vector2(float(arr[0]), float(arr[1]))
		return fallback

	static func poly_to_array(poly: PackedVector2Array) -> Array:
		var out: Array = []
		for pt in poly:
			out.append({"x": pt.x, "y": pt.y})
		return out

	static func poly_from_variant(v: Variant) -> PackedVector2Array:
		if v is PackedVector2Array:
			return v.duplicate()
		var out := PackedVector2Array()
		if v is Array:
			for item in v:
				out.append(vec2_from_variant(item))
		return out

	static func parse_slot_enum(v: Variant, enum_dict: Dictionary, fallback: int = 0) -> int:
		if v is int or v is float:
			return int(v)
		if v is String:
			var key: String = v.strip_edges().to_upper()
			if enum_dict.has(key):
				return int(enum_dict[key])
			if key.is_valid_int():
				return key.to_int()
		return fallback


# ============================================================================
# Data Classes
# ============================================================================

class PartPieceSpec extends RefCounted:
	var part_id: String = ""
	var slot: int = PartSlot.HEAD
	var backend: int = AssetRenderBackend.PROCEDURAL_VECTOR
	var texture_path: String = ""
	var texture: Texture2D = null
	var scene_path: String = ""
	var polygon_points: PackedVector2Array = PackedVector2Array()
	var line_width: float = 2.5
	var primary_color: Color = Color.WHITE
	var secondary_color: Color = Color.CYAN
	var offset: Vector2 = Vector2.ZERO
	var rotation_offset: float = 0.0
	var scale: Vector2 = Vector2.ONE
	var region_rect: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
	var z_offset: int = 0
	var metadata: Dictionary = {}

	func _init(
		p_part_id: String = "",
		p_slot: int = PartSlot.HEAD,
		p_backend: int = AssetRenderBackend.PROCEDURAL_VECTOR,
		p_primary_color: Color = Color.WHITE,
		p_secondary_color: Color = Color.CYAN,
		p_line_width: float = 2.5
	) -> void:
		part_id = p_part_id
		slot = p_slot
		backend = p_backend
		primary_color = p_primary_color
		secondary_color = p_secondary_color
		line_width = p_line_width

	func duplicate_spec() -> PartPieceSpec:
		var copy := PartPieceSpec.new(
			part_id, slot, backend, primary_color, secondary_color, line_width
		)
		copy.texture_path = texture_path
		copy.texture = texture
		copy.scene_path = scene_path
		copy.polygon_points = polygon_points.duplicate()
		copy.offset = offset
		copy.rotation_offset = rotation_offset
		copy.scale = scale
		copy.region_rect = region_rect
		copy.z_offset = z_offset
		copy.metadata = metadata.duplicate(true)
		return copy

	func to_dict() -> Dictionary:
		return {
			"part_id": part_id,
			"slot": slot,
			"backend": backend,
			"texture_path": texture_path,
			"scene_path": scene_path,
			"polygon_points": _Ser.poly_to_array(polygon_points),
			"line_width": line_width,
			"primary_color": _Ser.color_to_dict(primary_color),
			"secondary_color": _Ser.color_to_dict(secondary_color),
			"offset": _Ser.vec2_to_dict(offset),
			"rotation_offset": rotation_offset,
			"scale": _Ser.vec2_to_dict(scale),
			"region_rect": {
				"x": region_rect.position.x,
				"y": region_rect.position.y,
				"w": region_rect.size.x,
				"h": region_rect.size.y,
			},
			"z_offset": z_offset,
			"metadata": metadata.duplicate(true),
		}

	static func from_dict(d: Dictionary) -> PartPieceSpec:
		var spec := PartPieceSpec.new()
		spec.part_id = str(d.get("part_id", "unnamed_part"))
		spec.slot = _Ser.parse_slot_enum(d.get("slot", PartSlot.HEAD), PartSlot, PartSlot.HEAD)
		spec.backend = _Ser.parse_slot_enum(
			d.get("backend", AssetRenderBackend.PROCEDURAL_VECTOR),
			AssetRenderBackend,
			AssetRenderBackend.PROCEDURAL_VECTOR
		)
		spec.texture_path = str(d.get("texture_path", ""))
		if d.get("texture") is Texture2D:
			spec.texture = d.get("texture")
		elif not spec.texture_path.is_empty() and ResourceLoader.exists(spec.texture_path):
			var loaded_tex = ResourceLoader.load(spec.texture_path)
			if loaded_tex is Texture2D:
				spec.texture = loaded_tex
		spec.scene_path = str(d.get("scene_path", ""))
		spec.polygon_points = _Ser.poly_from_variant(d.get("polygon_points", []))
		spec.line_width = float(d.get("line_width", 2.5))
		spec.primary_color = _Ser.color_from_variant(d.get("primary_color"), Color.WHITE)
		spec.secondary_color = _Ser.color_from_variant(d.get("secondary_color"), Color.CYAN)
		spec.offset = _Ser.vec2_from_variant(d.get("offset"), Vector2.ZERO)
		spec.rotation_offset = float(d.get("rotation_offset", 0.0))
		spec.scale = _Ser.vec2_from_variant(d.get("scale"), Vector2.ONE)
		if d.has("region_rect"):
			var rr = d.get("region_rect")
			if rr is Rect2:
				spec.region_rect = rr
			elif rr is Dictionary:
				spec.region_rect = Rect2(
					float(rr.get("x", 0.0)),
					float(rr.get("y", 0.0)),
					float(rr.get("w", 0.0)),
					float(rr.get("h", 0.0))
				)
		spec.z_offset = int(d.get("z_offset", 0))
		if d.get("metadata") is Dictionary:
			spec.metadata = (d.get("metadata") as Dictionary).duplicate(true)
		return spec


class WeaponPieceSpec extends RefCounted:
	var piece_id: String = ""
	var piece_slot: int = WeaponPieceSlot.BLADE_EDGE
	var backend: int = AssetRenderBackend.PROCEDURAL_VECTOR
	var texture_path: String = ""
	var texture: Texture2D = null
	var polygon_points: PackedVector2Array = PackedVector2Array()
	var local_offset: Vector2 = Vector2.ZERO
	var length: float = 12.0
	var thickness: float = 2.5
	var color: Color = Color.CYAN
	var glow_color: Color = Color(0.6, 1.0, 1.0, 0.8)
	var rotates_with_gear: bool = false
	var key_tooth_length: float = 0.0

	func _init(
		p_piece_id: String = "",
		p_piece_slot: int = WeaponPieceSlot.BLADE_EDGE,
		p_backend: int = AssetRenderBackend.PROCEDURAL_VECTOR,
		p_length: float = 12.0,
		p_thickness: float = 2.5,
		p_color: Color = Color.CYAN,
		p_glow_color: Color = Color(0.6, 1.0, 1.0, 0.8),
		p_rotates_with_gear: bool = false,
		p_key_tooth_length: float = 0.0
	) -> void:
		piece_id = p_piece_id
		piece_slot = p_piece_slot
		backend = p_backend
		length = p_length
		thickness = p_thickness
		color = p_color
		glow_color = p_glow_color
		rotates_with_gear = p_rotates_with_gear
		key_tooth_length = p_key_tooth_length

	func duplicate_spec() -> WeaponPieceSpec:
		var copy := WeaponPieceSpec.new(
			piece_id,
			piece_slot,
			backend,
			length,
			thickness,
			color,
			glow_color,
			rotates_with_gear,
			key_tooth_length
		)
		copy.texture_path = texture_path
		copy.texture = texture
		copy.polygon_points = polygon_points.duplicate()
		copy.local_offset = local_offset
		return copy

	func to_dict() -> Dictionary:
		return {
			"piece_id": piece_id,
			"piece_slot": piece_slot,
			"backend": backend,
			"texture_path": texture_path,
			"polygon_points": _Ser.poly_to_array(polygon_points),
			"local_offset": _Ser.vec2_to_dict(local_offset),
			"length": length,
			"thickness": thickness,
			"color": _Ser.color_to_dict(color),
			"glow_color": _Ser.color_to_dict(glow_color),
			"rotates_with_gear": rotates_with_gear,
			"key_tooth_length": key_tooth_length,
		}

	static func from_dict(d: Dictionary) -> WeaponPieceSpec:
		var spec := WeaponPieceSpec.new()
		spec.piece_id = str(d.get("piece_id", "unnamed_weapon_piece"))
		var raw_slot = d.get("piece_slot", d.get("slot", WeaponPieceSlot.BLADE_EDGE))
		spec.piece_slot = _Ser.parse_slot_enum(
			raw_slot, WeaponPieceSlot, WeaponPieceSlot.BLADE_EDGE
		)
		spec.backend = _Ser.parse_slot_enum(
			d.get("backend", AssetRenderBackend.PROCEDURAL_VECTOR),
			AssetRenderBackend,
			AssetRenderBackend.PROCEDURAL_VECTOR
		)
		spec.texture_path = str(d.get("texture_path", ""))
		if d.get("texture") is Texture2D:
			spec.texture = d.get("texture")
		elif not spec.texture_path.is_empty() and ResourceLoader.exists(spec.texture_path):
			var loaded_tex = ResourceLoader.load(spec.texture_path)
			if loaded_tex is Texture2D:
				spec.texture = loaded_tex
		spec.polygon_points = _Ser.poly_from_variant(d.get("polygon_points", []))
		spec.local_offset = _Ser.vec2_from_variant(d.get("local_offset"), Vector2.ZERO)
		spec.length = float(d.get("length", 12.0))
		spec.thickness = float(d.get("thickness", 2.5))
		spec.color = _Ser.color_from_variant(d.get("color"), Color.CYAN)
		spec.glow_color = _Ser.color_from_variant(
			d.get("glow_color"), Color(0.6, 1.0, 1.0, 0.8)
		)
		spec.rotates_with_gear = bool(d.get("rotates_with_gear", false))
		spec.key_tooth_length = float(d.get("key_tooth_length", 0.0))
		return spec


class WeaponAssemblySpec extends RefCounted:
	var weapon_id: String = ""
	var weapon_class: String = "shift_staff_cane"
	var pieces: Dictionary = {} # int (WeaponPieceSlot) -> WeaponPieceSpec

	func _init(p_weapon_id: String = "", p_weapon_class: String = "shift_staff_cane") -> void:
		weapon_id = p_weapon_id
		weapon_class = p_weapon_class
		pieces = {}

	func set_piece(piece: WeaponPieceSpec) -> void:
		if piece == null:
			return
		pieces[piece.piece_slot] = piece

	func get_piece(slot: int) -> WeaponPieceSpec:
		return pieces.get(slot, null)

	func remove_piece(slot: int) -> void:
		pieces.erase(slot)

	func duplicate_assembly() -> WeaponAssemblySpec:
		var copy := WeaponAssemblySpec.new(weapon_id, weapon_class)
		for slot_key in pieces.keys():
			var p: WeaponPieceSpec = pieces[slot_key]
			if p != null:
				copy.pieces[int(slot_key)] = p.duplicate_spec()
		return copy

	## Computes world transforms for each attached WeaponPieceSlot between hilt_pos and tip_pos.
	## For "shift_staff_cane", as gear_alignment approaches 1.0, interlocking GEARWORK_CORE cogs
	## and KEY_TEETH bits rotate into phase alignment along the shaft to form the ornate Chronos Key.
	func compute_piece_transforms(
		hilt_pos: Vector2,
		tip_pos: Vector2,
		facing: float,
		gear_alignment: float = 0.0,
		anim_time: float = 0.0
	) -> Array[Dictionary]:
		var results: Array[Dictionary] = []
		var face_sign: float = 1.0 if facing >= 0.0 else -1.0
		var axis_vec: Vector2 = tip_pos - hilt_pos
		var total_len: float = axis_vec.length()
		var dir: Vector2 = (
			axis_vec / total_len
			if total_len > 0.001
			else Vector2(face_sign, 0.0)
		)
		if total_len <= 0.001:
			total_len = 36.0
		var base_angle: float = dir.angle()
		# Perpendicular vector oriented consistently with facing for key teeth / scopes
		var perp: Vector2 = Vector2(-dir.y, dir.x) * face_sign
		var clamped_align: float = clampf(gear_alignment, 0.0, 1.0)
		var is_shift_staff: bool = (weapon_class == "shift_staff_cane")

		var sorted_slots: Array = pieces.keys()
		sorted_slots.sort()

		for slot_var in sorted_slots:
			var slot: int = int(slot_var)
			var piece: WeaponPieceSpec = pieces[slot]
			if piece == null:
				continue

			# Normalized start/end ratios along the weapon axis [0 = hilt, 1 = tip]
			var t_start: float = 0.0
			var t_end: float = 0.2
			var lateral_dist: float = 0.0

			match slot:
				WeaponPieceSlot.POMMEL:
					t_start = -0.08
					t_end = 0.02
				WeaponPieceSlot.GRIP:
					t_start = 0.0
					t_end = 0.20
				WeaponPieceSlot.GUARD:
					t_start = 0.20
					t_end = 0.28
				WeaponPieceSlot.SHAFT_LOWER:
					t_start = 0.28
					t_end = 0.52
				WeaponPieceSlot.GEARWORK_CORE:
					t_start = 0.48
					t_end = 0.68
				WeaponPieceSlot.SHAFT_UPPER:
					t_start = 0.68
					t_end = 0.88
				WeaponPieceSlot.BLADE_EDGE:
					t_start = 0.28
					t_end = 1.0
				WeaponPieceSlot.KEY_TEETH:
					t_start = 0.78
					t_end = 0.95
				WeaponPieceSlot.MUZZLE_BARREL:
					t_start = 0.20
					t_end = 1.0
				WeaponPieceSlot.OPTIC_SCOPE:
					t_start = 0.22
					t_end = 0.55
					lateral_dist = 3.5
				WeaponPieceSlot.MAGAZINE:
					t_start = 0.30
					t_end = 0.46
					lateral_dist = -4.0
				_:
					t_start = 0.0
					t_end = 0.5

			var local_world_offset: Vector2 = (
				dir * piece.local_offset.x + perp * piece.local_offset.y + perp * lateral_dist
			)
			var start_pos: Vector2 = hilt_pos + dir * (total_len * t_start) + local_world_offset
			var end_pos: Vector2 = hilt_pos + dir * (total_len * t_end) + local_world_offset
			var center_pos: Vector2 = (start_pos + end_pos) * 0.5

			# Gearwork & Key-Teeth rotational alignment physics for Shift Staff
			var gear_phase_offset: float = 0.0
			var tooth_extension_ratio: float = 1.0
			if piece.rotates_with_gear or (
				is_shift_staff and (slot == WeaponPieceSlot.GEARWORK_CORE or slot == WeaponPieceSlot.KEY_TEETH)
			):
				# When gear_alignment < 1.0, interlocking cogs & key wards are out-of-phase and spinning.
				# At gear_alignment == 1.0, phase offset collapses to 0.0 (locked into Chronos Key alignment).
				var unaligned_factor: float = 1.0 - clamped_align
				var slot_phase_seed: float = 0.85 if slot == WeaponPieceSlot.GEARWORK_CORE else -1.15
				gear_phase_offset = unaligned_factor * (slot_phase_seed + anim_time * 3.5)
				tooth_extension_ratio = lerpf(0.25, 1.0, clamped_align)

			var piece_rotation: float = base_angle + gear_phase_offset
			var effective_tooth_len: float = piece.key_tooth_length * tooth_extension_ratio
			var tooth_dir: Vector2 = perp.rotated(gear_phase_offset)
			var tooth_tip: Vector2 = center_pos + tooth_dir * effective_tooth_len

			if slot == WeaponPieceSlot.KEY_TEETH and piece.key_tooth_length > 0.0:
				end_pos = tooth_tip

			var world_poly := PackedVector2Array()
			if piece.polygon_points.size() > 0:
				for pt in piece.polygon_points:
					var rotated_pt: Vector2 = pt.rotated(piece_rotation)
					world_poly.append(center_pos + rotated_pt)

			results.append({
				"piece_id": piece.piece_id,
				"piece_slot": slot,
				"slot": slot,
				"backend": piece.backend,
				"start": start_pos,
				"end": end_pos,
				"center": center_pos,
				"world_pos": center_pos,
				"position": center_pos,
				"rotation": piece_rotation,
				"angle": piece_rotation,
				"shaft_angle": base_angle,
				"gear_phase_offset": gear_phase_offset,
				"key_alignment": clamped_align,
				"is_key_aligned": clamped_align >= 0.95,
				"tooth_extension_ratio": tooth_extension_ratio,
				"key_tooth_length": effective_tooth_len,
				"tooth_tip": tooth_tip,
				"length": piece.length,
				"thickness": piece.thickness,
				"color": piece.color,
				"glow_color": piece.glow_color,
				"texture": piece.texture,
				"texture_path": piece.texture_path,
				"polygon_world": world_poly,
			})

		return results

	func to_dict() -> Dictionary:
		var pieces_dict: Dictionary = {}
		for slot_key in pieces.keys():
			var p: WeaponPieceSpec = pieces[slot_key]
			if p != null:
				pieces_dict[str(slot_key)] = p.to_dict()
		return {
			"weapon_id": weapon_id,
			"weapon_class": weapon_class,
			"pieces": pieces_dict,
		}

	static func from_dict(d: Dictionary) -> WeaponAssemblySpec:
		var assembly := WeaponAssemblySpec.new(
			str(d.get("weapon_id", "default_weapon")),
			str(d.get("weapon_class", "shift_staff_cane"))
		)
		var raw_pieces = d.get("pieces", {})
		if raw_pieces is Dictionary:
			for k in raw_pieces.keys():
				var p_data = raw_pieces[k]
				if p_data is Dictionary:
					var spec := WeaponPieceSpec.from_dict(p_data)
					assembly.set_piece(spec)
		elif raw_pieces is Array:
			for p_data in raw_pieces:
				if p_data is Dictionary:
					var spec := WeaponPieceSpec.from_dict(p_data)
					assembly.set_piece(spec)
		return assembly


class CharacterLoadout extends RefCounted:
	var loadout_id: String = ""
	var display_name: String = ""
	var body_color: Color = Color.WHITE
	var accent_color: Color = Color.CYAN
	var parts: Dictionary = {} # int (PartSlot) -> PartPieceSpec
	var weapon_assembly: WeaponAssemblySpec = null

	func _init(
		p_loadout_id: String = "",
		p_display_name: String = "",
		p_body_color: Color = Color.WHITE,
		p_accent_color: Color = Color.CYAN
	) -> void:
		loadout_id = p_loadout_id
		display_name = p_display_name
		body_color = p_body_color
		accent_color = p_accent_color
		parts = {}
		weapon_assembly = WeaponAssemblySpec.new(p_loadout_id + "_weapon", "katana")

	func equip_part(part: PartPieceSpec) -> void:
		if part == null:
			return
		parts[part.slot] = part

	func unequip_slot(slot: int) -> void:
		parts.erase(slot)

	func get_part(slot: int) -> PartPieceSpec:
		return parts.get(slot, null)

	func equip_weapon_piece(piece: WeaponPieceSpec) -> void:
		if piece == null:
			return
		if weapon_assembly == null:
			weapon_assembly = WeaponAssemblySpec.new(loadout_id + "_weapon", "shift_staff_cane")
		weapon_assembly.set_piece(piece)

	func duplicate_loadout() -> CharacterLoadout:
		var copy := CharacterLoadout.new(loadout_id, display_name, body_color, accent_color)
		for slot_key in parts.keys():
			var p: PartPieceSpec = parts[slot_key]
			if p != null:
				copy.parts[int(slot_key)] = p.duplicate_spec()
		if weapon_assembly != null:
			copy.weapon_assembly = weapon_assembly.duplicate_assembly()
		return copy

	## Splits this CharacterLoadout into {"upper": CharacterLoadout, "lower": CharacterLoadout}
	## so severed RagdollPart::UpperTorso and RagdollPart::LowerLegs retain their exact
	## custom helmets, scarves, armor polygons, and boots when sliced in half.
	func split_for_ragdoll() -> Dictionary:
		var upper := CharacterLoadout.new(
			loadout_id + "_upper",
			display_name + " (Upper Torso)",
			body_color,
			accent_color
		)
		var lower := CharacterLoadout.new(
			loadout_id + "_lower",
			display_name + " (Lower Legs)",
			body_color,
			accent_color
		)
		if weapon_assembly != null:
			upper.weapon_assembly = weapon_assembly.duplicate_assembly()
		else:
			upper.weapon_assembly = null
		lower.weapon_assembly = null

		for slot_id in UPPER_BODY_SLOTS:
			if parts.has(slot_id) and parts[slot_id] != null:
				upper.equip_part((parts[slot_id] as PartPieceSpec).duplicate_spec())

		for slot_id in LOWER_BODY_SLOTS:
			if parts.has(slot_id) and parts[slot_id] != null:
				lower.equip_part((parts[slot_id] as PartPieceSpec).duplicate_spec())

		return {
			"upper": upper,
			"lower": lower,
		}

	func to_dict() -> Dictionary:
		var parts_dict: Dictionary = {}
		for slot_key in parts.keys():
			var p: PartPieceSpec = parts[slot_key]
			if p != null:
				parts_dict[str(slot_key)] = p.to_dict()
		return {
			"loadout_id": loadout_id,
			"display_name": display_name,
			"body_color": _Ser.color_to_dict(body_color),
			"accent_color": _Ser.color_to_dict(accent_color),
			"parts": parts_dict,
			"weapon_assembly": weapon_assembly.to_dict() if weapon_assembly != null else {},
		}

	static func from_dict(d: Dictionary) -> CharacterLoadout:
		var loadout := CharacterLoadout.new(
			str(d.get("loadout_id", "custom_loadout")),
			str(d.get("display_name", "Custom Loadout")),
			_Ser.color_from_variant(d.get("body_color"), Color.WHITE),
			_Ser.color_from_variant(d.get("accent_color"), Color.CYAN)
		)
		var raw_parts = d.get("parts", {})
		if raw_parts is Dictionary:
			for k in raw_parts.keys():
				var p_data = raw_parts[k]
				if p_data is Dictionary:
					loadout.equip_part(PartPieceSpec.from_dict(p_data))
		elif raw_parts is Array:
			for p_data in raw_parts:
				if p_data is Dictionary:
					loadout.equip_part(PartPieceSpec.from_dict(p_data))

		if d.get("weapon_assembly") is Dictionary and not (d.get("weapon_assembly") as Dictionary).is_empty():
			loadout.weapon_assembly = WeaponAssemblySpec.from_dict(d.get("weapon_assembly"))
		return loadout


# ============================================================================
# StickmanPose & StickmanPoseSolver (Port of bevy-game-test/src/render.rs)
# ============================================================================

class StickmanPose extends RefCounted:
	var head_center: Vector2 = Vector2.ZERO
	var head_radius: float = 8.5
	var neck: Vector2 = Vector2.ZERO
	var pelvis: Vector2 = Vector2.ZERO
	# Arms
	var left_shoulder: Vector2 = Vector2.ZERO
	var left_elbow: Vector2 = Vector2.ZERO
	var left_hand: Vector2 = Vector2.ZERO
	var right_shoulder: Vector2 = Vector2.ZERO
	var right_elbow: Vector2 = Vector2.ZERO
	var right_hand: Vector2 = Vector2.ZERO
	# Legs
	var left_hip: Vector2 = Vector2.ZERO
	var left_knee: Vector2 = Vector2.ZERO
	var left_foot: Vector2 = Vector2.ZERO
	var right_hip: Vector2 = Vector2.ZERO
	var right_knee: Vector2 = Vector2.ZERO
	var right_foot: Vector2 = Vector2.ZERO
	# Weapon
	var sword_hilt: Vector2 = Vector2.ZERO
	var sword_tip: Vector2 = Vector2.ZERO
	# Scarf / Headband trail points (3 nodes)
	var scarf_nodes: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var stance: String = "normal"


class StickmanPoseSolver extends RefCounted:
	## Exact port of generate_stickman_pose from bevy-game-test/src/render.rs,
	## extended with optional stance parameter ("normal", "heavy_slash",
	## "downward_slam", "parry_guard", "wall_slide", "well_unlock").
	static func generate_stickman_pose(
		pos: Vector2,
		facing: float,
		velocity: Vector2,
		is_grounded: bool,
		anim_time: float,
		is_attacking: bool,
		attack_progress: float,
		is_enemy: bool,
		stance: String = "normal"
	) -> StickmanPose:
		var face_dir: float = 1.0 if facing >= 0.0 else -1.0
		var speed: float = absf(velocity.x)
		var is_running: bool = is_grounded and speed > 20.0
		var is_jumping: bool = not is_grounded

		var base_pelvis: Vector2 = pos + Vector2(0.0, 16.0)
		var pelvis: Vector2 = base_pelvis
		var neck: Vector2 = pelvis + Vector2(face_dir * 3.0, 24.0)

		# Torso lean based on movement or special martial stance
		if stance == "heavy_slash":
			pelvis.y -= 2.0
			neck.x += face_dir * 8.0
		elif stance == "downward_slam":
			pelvis.y += 4.0
			neck = pelvis + Vector2(face_dir * 2.0, 22.0)
		elif stance == "parry_guard":
			pelvis.y -= 1.5
			neck = pelvis + Vector2(-face_dir * 1.5, 23.5)
		elif stance == "wall_slide":
			neck = pelvis + Vector2(-face_dir * 2.0, 24.0)
		elif is_running:
			pelvis.y += absf(sin(anim_time * 14.0)) * 3.0
			neck.x += face_dir * 6.0
		elif is_jumping:
			neck.x += face_dir * 4.0

		var head_center: Vector2 = neck + Vector2(face_dir * 3.0, 10.0)
		var head_radius: float = 7.5 if is_enemy else 8.5

		# Legs
		var left_hip: Vector2 = pelvis + Vector2(-face_dir * 3.0, 0.0)
		var right_hip: Vector2 = pelvis + Vector2(face_dir * 3.0, 0.0)
		var left_knee: Vector2
		var left_foot: Vector2
		var right_knee: Vector2
		var right_foot: Vector2

		if stance == "wall_slide":
			# Wall-slide: one boot planted high against wall, other leg extended down
			left_knee = left_hip + Vector2(-face_dir * 5.0, -6.0)
			left_foot = left_knee + Vector2(-face_dir * 3.0, -7.0)
			right_knee = right_hip + Vector2(face_dir * 4.0, -13.0)
			right_foot = right_knee + Vector2(face_dir * 2.0, -13.0)
		elif stance == "downward_slam" or is_jumping:
			# Jumping / falling pose: legs tucked
			left_knee = left_hip + Vector2(-face_dir * 6.0, -10.0)
			left_foot = left_knee + Vector2(-face_dir * 4.0, -10.0)
			right_knee = right_hip + Vector2(face_dir * 8.0, -8.0)
			right_foot = right_knee + Vector2(face_dir * 6.0, -12.0)
		elif is_running:
			# Running stride
			var phase: float = anim_time * clampf(speed * 0.04, 8.0, 22.0)
			var l_angle: float = sin(phase)
			var r_angle: float = sin(phase + PI)

			left_knee = left_hip + Vector2(l_angle * 12.0, -12.0 - absf(l_angle) * 3.0)
			left_foot = left_knee + Vector2(l_angle * 10.0, -14.0)

			right_knee = right_hip + Vector2(r_angle * 12.0, -12.0 - absf(r_angle) * 3.0)
			right_foot = right_knee + Vector2(r_angle * 10.0, -14.0)
		else:
			# Idle breathing stance
			var breath: float = sin(anim_time * 3.0) * 1.5
			left_knee = left_hip + Vector2(-face_dir * 4.0, -13.0 + breath)
			left_foot = left_knee + Vector2(0.0, -13.0)
			right_knee = right_hip + Vector2(face_dir * 6.0, -12.0 + breath)
			right_foot = right_knee + Vector2(0.0, -14.0)

		# Arms & Weapon
		var left_shoulder: Vector2 = neck + Vector2(-face_dir * 4.0, -2.0)
		var right_shoulder: Vector2 = neck + Vector2(face_dir * 4.0, -2.0)
		var left_elbow: Vector2
		var left_hand: Vector2
		var right_elbow: Vector2
		var right_hand: Vector2
		var sword_hilt: Vector2
		var sword_tip: Vector2

		if stance == "downward_slam":
			# Plunging vertical slam: Shift Staff driven straight downward beneath feet
			right_hand = pelvis + Vector2(face_dir * 4.0, 4.0)
			right_elbow = right_shoulder + Vector2(face_dir * 8.0, -4.0)
			left_hand = right_hand + Vector2(-face_dir * 2.0, 2.0)
			left_elbow = left_shoulder + Vector2(-face_dir * 5.0, -4.0)
			var slam_dir := Vector2(0.0, -1.0)
			sword_hilt = right_hand - slam_dir * 6.0
			sword_tip = right_hand + slam_dir * 40.0
		elif stance == "parry_guard":
			# Defensive ward guard: Shift Staff held upright/diagonal across torso & head
			right_hand = pelvis + Vector2(face_dir * 12.0, 8.0)
			right_elbow = right_shoulder + Vector2(face_dir * 8.0, -8.0)
			left_hand = neck + Vector2(face_dir * 12.0, 2.0)
			left_elbow = left_shoulder + Vector2(face_dir * 6.0, -4.0)
			var guard_dir := Vector2(face_dir * 0.25, 0.968).normalized()
			sword_hilt = right_hand - guard_dir * 4.0
			sword_tip = right_hand + guard_dir * 38.0
		elif stance == "heavy_slash":
			# Wide high-gear heavy cleave arc
			var sweep: float = clampf(1.0 - attack_progress, 0.0, 1.0)
			var swing_angle: float = 1.35 - sweep * 2.6
			var hand_dir := Vector2(face_dir * cos(swing_angle), sin(swing_angle)).normalized()
			right_hand = right_shoulder + hand_dir * 24.0
			right_elbow = (right_shoulder + right_hand) * 0.5 + Vector2(0.0, 7.0)
			left_hand = right_hand + Vector2(-face_dir * 3.0, -1.0)
			left_elbow = (left_shoulder + left_hand) * 0.5
			sword_hilt = right_hand - hand_dir * 6.0
			sword_tip = right_hand + hand_dir * 44.0
		elif stance == "wall_slide":
			# One hand bracing wall, weapon angled down-away
			left_elbow = left_shoulder + Vector2(-face_dir * 6.0, 4.0)
			left_hand = left_elbow + Vector2(-face_dir * 5.0, 6.0)
			right_elbow = right_shoulder + Vector2(face_dir * 7.0, -6.0)
			right_hand = right_elbow + Vector2(face_dir * 8.0, -4.0)
			var slide_blade_dir := Vector2(face_dir * 0.75, -0.66).normalized()
			sword_hilt = right_hand - slide_blade_dir * 5.0
			sword_tip = right_hand + slide_blade_dir * 34.0
		elif stance == "well_unlock":
			# Extending the Shift Staff horizontally as the ornate Chronos Key
			right_elbow = right_shoulder + Vector2(face_dir * 10.0, -2.0)
			right_hand = right_shoulder + Vector2(face_dir * 20.0, 0.0)
			left_elbow = left_shoulder + Vector2(face_dir * 8.0, -4.0)
			left_hand = right_hand + Vector2(-face_dir * 4.0, -1.0)
			var key_dir := Vector2(face_dir, 0.0)
			sword_hilt = right_hand - key_dir * 4.0
			sword_tip = right_hand + key_dir * 38.0
		elif is_attacking:
			# Forward slash swing pose (exact match to bevy-game-test/src/render.rs)
			var sweep: float = clampf(1.0 - attack_progress, 0.0, 1.0)
			var swing_angle: float = -0.8 + sweep * 2.2
			var hand_dir := Vector2(face_dir * cos(swing_angle), sin(swing_angle))

			right_hand = right_shoulder + hand_dir * 22.0
			right_elbow = (right_shoulder + right_hand) * 0.5 + Vector2(0.0, 6.0)
			left_hand = right_hand + Vector2(-face_dir * 4.0, -2.0)
			left_elbow = (left_shoulder + left_hand) * 0.5

			var blade_dir: Vector2 = hand_dir.normalized()
			sword_hilt = right_hand - blade_dir * 6.0
			sword_tip = right_hand + blade_dir * 38.0
		elif is_running:
			# Pumping arms (exact match to bevy-game-test/src/render.rs)
			var arm_phase: float = anim_time * clampf(speed * 0.04, 8.0, 22.0)
			var l_swing: float = sin(arm_phase + PI)
			var r_swing: float = sin(arm_phase)

			left_elbow = left_shoulder + Vector2(l_swing * 8.0, -10.0)
			left_hand = left_elbow + Vector2(l_swing * 6.0, -8.0)

			right_elbow = right_shoulder + Vector2(r_swing * 8.0, -8.0)
			right_hand = right_elbow + Vector2(face_dir * 10.0, 4.0)

			var sword_dir: Vector2 = Vector2(face_dir * 0.8, -0.6).normalized()
			sword_hilt = right_hand - sword_dir * 4.0
			sword_tip = right_hand + sword_dir * 32.0
		else:
			# Idle ready stance (exact match to bevy-game-test/src/render.rs)
			left_elbow = left_shoulder + Vector2(-face_dir * 4.0, -10.0)
			left_hand = pelvis + Vector2(face_dir * 4.0, 4.0)

			right_elbow = right_shoulder + Vector2(face_dir * 6.0, -8.0)
			right_hand = pelvis + Vector2(face_dir * 8.0, 6.0)

			var sword_dir: Vector2 = Vector2(face_dir * 0.7, 0.7).normalized()
			sword_hilt = right_hand - sword_dir * 5.0
			sword_tip = right_hand + sword_dir * 34.0

		# Scarf / Headband ribbon (exact match to bevy-game-test/src/render.rs)
		var head_back: Vector2 = head_center + Vector2(-face_dir * head_radius, 0.0)
		var scarf_0: Vector2 = head_back + Vector2(
			-face_dir * 8.0, (sin(anim_time * 8.0) * 3.0) - velocity.y * 0.02
		)
		var scarf_1: Vector2 = scarf_0 + Vector2(
			-face_dir * 10.0, (sin(anim_time * 8.0 + 1.2) * 4.0) - velocity.y * 0.03
		)
		var scarf_2: Vector2 = scarf_1 + Vector2(
			-face_dir * 12.0, (sin(anim_time * 8.0 + 2.4) * 5.0) - velocity.y * 0.04
		)

		var pose := StickmanPose.new()
		pose.head_center = head_center
		pose.head_radius = head_radius
		pose.neck = neck
		pose.pelvis = pelvis
		pose.left_shoulder = left_shoulder
		pose.left_elbow = left_elbow
		pose.left_hand = left_hand
		pose.right_shoulder = right_shoulder
		pose.right_elbow = right_elbow
		pose.right_hand = right_hand
		pose.left_hip = left_hip
		pose.left_knee = left_knee
		pose.left_foot = left_foot
		pose.right_hip = right_hip
		pose.right_knee = right_knee
		pose.right_foot = right_foot
		pose.sword_hilt = sword_hilt
		pose.sword_tip = sword_tip
		pose.scarf_nodes = [scarf_0, scarf_1, scarf_2]
		pose.stance = stance
		return pose

	## Computes bone transform {"start", "end", "center", "angle", "length"} for any PartSlot.
	static func compute_slot_transform(
		pose: StickmanPose,
		slot: int,
		facing: float = 1.0
	) -> Dictionary:
		var face_dir: float = 1.0 if facing >= 0.0 else -1.0
		var start_pt: Vector2 = Vector2.ZERO
		var end_pt: Vector2 = Vector2.ZERO
		var center_pt: Vector2 = Vector2.ZERO
		var custom_center: bool = false
		var override_len: float = -1.0

		match slot:
			PartSlot.HEAD:
				start_pt = pose.neck
				end_pt = pose.head_center + Vector2(0.0, pose.head_radius)
				center_pt = pose.head_center
				custom_center = true
				override_len = pose.head_radius * 2.0
			PartSlot.EYES:
				var eye_center: Vector2 = pose.head_center + Vector2(face_dir * 3.0, 1.0)
				start_pt = eye_center - Vector2(face_dir * 1.5, 0.0)
				end_pt = eye_center + Vector2(face_dir * 1.5, 0.0)
				center_pt = eye_center
				custom_center = true
				override_len = 3.0
			PartSlot.HAT_HELMET:
				var crown: Vector2 = pose.head_center + Vector2(0.0, pose.head_radius * 0.75)
				start_pt = pose.head_center
				end_pt = pose.head_center + Vector2(0.0, pose.head_radius * 1.65)
				center_pt = crown
				custom_center = true
				override_len = pose.head_radius * 1.65
			PartSlot.SCARF_CAPE:
				start_pt = pose.head_center + Vector2(-face_dir * pose.head_radius, 0.0)
				if pose.scarf_nodes.size() >= 3:
					end_pt = pose.scarf_nodes[2]
					center_pt = pose.scarf_nodes[1]
					custom_center = true
				else:
					end_pt = start_pt + Vector2(-face_dir * 28.0, 0.0)
			PartSlot.TORSO:
				start_pt = pose.pelvis
				end_pt = pose.neck
			PartSlot.PELVIS:
				start_pt = pose.left_hip
				end_pt = pose.right_hip
				center_pt = pose.pelvis
				custom_center = true
			PartSlot.UPPER_ARM_L:
				start_pt = pose.left_shoulder
				end_pt = pose.left_elbow
			PartSlot.FOREARM_L:
				start_pt = pose.left_elbow
				end_pt = pose.left_hand
			PartSlot.HAND_L:
				var l_arm_dir: Vector2 = (pose.left_hand - pose.left_elbow).normalized()
				if l_arm_dir.length_squared() < 0.001:
					l_arm_dir = Vector2(face_dir, 0.0)
				start_pt = pose.left_hand
				end_pt = pose.left_hand + l_arm_dir * 4.5
				center_pt = pose.left_hand
				custom_center = true
			PartSlot.UPPER_ARM_R:
				start_pt = pose.right_shoulder
				end_pt = pose.right_elbow
			PartSlot.FOREARM_R:
				start_pt = pose.right_elbow
				end_pt = pose.right_hand
			PartSlot.HAND_R:
				var r_arm_dir: Vector2 = (pose.right_hand - pose.right_elbow).normalized()
				if r_arm_dir.length_squared() < 0.001:
					r_arm_dir = Vector2(face_dir, 0.0)
				start_pt = pose.right_hand
				end_pt = pose.right_hand + r_arm_dir * 4.5
				center_pt = pose.right_hand
				custom_center = true
			PartSlot.THIGH_L:
				start_pt = pose.left_hip
				end_pt = pose.left_knee
			PartSlot.SHIN_L:
				start_pt = pose.left_knee
				end_pt = pose.left_foot
			PartSlot.FOOT_L:
				start_pt = pose.left_foot
				end_pt = pose.left_foot + Vector2(face_dir * 5.5, 0.0)
			PartSlot.THIGH_R:
				start_pt = pose.right_hip
				end_pt = pose.right_knee
			PartSlot.SHIN_R:
				start_pt = pose.right_knee
				end_pt = pose.right_foot
			PartSlot.FOOT_R:
				start_pt = pose.right_foot
				end_pt = pose.right_foot + Vector2(face_dir * 5.5, 0.0)
			PartSlot.WEAPON_MAIN:
				start_pt = pose.sword_hilt
				end_pt = pose.sword_tip
			PartSlot.WEAPON_OFFHAND:
				var off_dir: Vector2 = Vector2(-face_dir * 0.7, 0.7).normalized()
				start_pt = pose.left_hand
				end_pt = pose.left_hand + off_dir * 16.0
			_:
				start_pt = pose.pelvis
				end_pt = pose.neck

		if not custom_center:
			center_pt = (start_pt + end_pt) * 0.5
		var seg: Vector2 = end_pt - start_pt
		var length: float = override_len if override_len > 0.0 else maxf(seg.length(), 0.001)
		var angle: float = seg.angle() if seg.length_squared() > 0.0001 else 0.0

		return {
			"start": start_pt,
			"end": end_pt,
			"center": center_pt,
			"angle": angle,
			"length": length,
		}


# ============================================================================
# ModularAssetRegistry (Presets + Runtime & JSON Manifest API)
# ============================================================================

class ModularAssetRegistry extends RefCounted:
	var parts: Dictionary = {} # String (part_id) -> PartPieceSpec
	var weapon_pieces: Dictionary = {} # String (piece_id) -> WeaponPieceSpec
	var loadouts: Dictionary = {} # String (loadout_id) -> CharacterLoadout

	func _init() -> void:
		_init_builtin_presets()

	func register_part(part: PartPieceSpec) -> void:
		if part == null or part.part_id.is_empty():
			return
		parts[part.part_id] = part

	func get_registered_part(part_id: String) -> PartPieceSpec:
		return parts.get(part_id, null)

	func register_weapon_piece(piece: WeaponPieceSpec) -> void:
		if piece == null or piece.piece_id.is_empty():
			return
		weapon_pieces[piece.piece_id] = piece

	func get_registered_weapon_piece(piece_id: String) -> WeaponPieceSpec:
		return weapon_pieces.get(piece_id, null)

	func register_loadout(loadout: CharacterLoadout) -> void:
		if loadout == null or loadout.loadout_id.is_empty():
			return
		loadouts[loadout.loadout_id] = loadout

	func get_loadout(loadout_id: String) -> CharacterLoadout:
		return loadouts.get(loadout_id, null)

	func apply_part_to_loadout(loadout_id: String, part_dict: Dictionary) -> bool:
		var loadout: CharacterLoadout = get_loadout(loadout_id)
		if loadout == null:
			return false
		var spec := PartPieceSpec.from_dict(part_dict)
		register_part(spec)
		loadout.equip_part(spec)
		return true

	func apply_weapon_piece_to_loadout(loadout_id: String, piece_dict: Dictionary) -> bool:
		var loadout: CharacterLoadout = get_loadout(loadout_id)
		if loadout == null:
			return false
		var spec := WeaponPieceSpec.from_dict(piece_dict)
		register_weapon_piece(spec)
		loadout.equip_weapon_piece(spec)
		return true

	func export_manifest_json() -> String:
		var exported_parts: Array = []
		var part_keys: Array = parts.keys()
		part_keys.sort()
		for k in part_keys:
			var p: PartPieceSpec = parts[k]
			if p != null:
				exported_parts.append(p.to_dict())

		var exported_weapon_pieces: Array = []
		var wp_keys: Array = weapon_pieces.keys()
		wp_keys.sort()
		for k in wp_keys:
			var wp: WeaponPieceSpec = weapon_pieces[k]
			if wp != null:
				exported_weapon_pieces.append(wp.to_dict())

		var exported_loadouts: Dictionary = {}
		var lo_keys: Array = loadouts.keys()
		lo_keys.sort()
		for k in lo_keys:
			var lo: CharacterLoadout = loadouts[k]
			if lo != null:
				exported_loadouts[str(k)] = lo.to_dict()

		var manifest: Dictionary = {
			"version": "1.0",
			"parts": exported_parts,
			"weapon_pieces": exported_weapon_pieces,
			"loadouts": exported_loadouts,
		}
		return JSON.stringify(manifest, "\t")

	func load_manifest_json(json_string: String) -> bool:
		if json_string.strip_edges().is_empty():
			return false
		var parsed = JSON.parse_string(json_string)
		if not (parsed is Dictionary):
			return false
		var manifest: Dictionary = parsed

		# 1. Load standalone parts catalog
		var raw_parts = manifest.get("parts", [])
		if raw_parts is Array:
			for item in raw_parts:
				if item is Dictionary:
					var spec := PartPieceSpec.from_dict(item)
					register_part(spec)
					if item.has("target_loadout"):
						var target_id: String = str(item["target_loadout"])
						if loadouts.has(target_id):
							(loadouts[target_id] as CharacterLoadout).equip_part(spec.duplicate_spec())
		elif raw_parts is Dictionary:
			for k in raw_parts.keys():
				var item = raw_parts[k]
				if item is Dictionary:
					var spec := PartPieceSpec.from_dict(item)
					register_part(spec)

		# 2. Load standalone weapon_pieces catalog
		var raw_wps = manifest.get("weapon_pieces", [])
		if raw_wps is Array:
			for item in raw_wps:
				if item is Dictionary:
					var wp_spec := WeaponPieceSpec.from_dict(item)
					register_weapon_piece(wp_spec)
					if item.has("target_loadout"):
						var target_id: String = str(item["target_loadout"])
						if loadouts.has(target_id):
							(loadouts[target_id] as CharacterLoadout).equip_weapon_piece(wp_spec.duplicate_spec())
		elif raw_wps is Dictionary:
			for k in raw_wps.keys():
				var item = raw_wps[k]
				if item is Dictionary:
					var wp_spec := WeaponPieceSpec.from_dict(item)
					register_weapon_piece(wp_spec)

		# 3. Load full loadouts
		var raw_loadouts = manifest.get("loadouts", {})
		if raw_loadouts is Dictionary:
			for lo_id in raw_loadouts.keys():
				var lo_dict = raw_loadouts[lo_id]
				if lo_dict is Dictionary:
					var loadout := CharacterLoadout.from_dict(lo_dict)
					register_loadout(loadout)
		elif raw_loadouts is Array:
			for lo_dict in raw_loadouts:
				if lo_dict is Dictionary:
					var loadout := CharacterLoadout.from_dict(lo_dict)
					register_loadout(loadout)

		return true

	func _populate_base_humanoid_parts(
		loadout: CharacterLoadout,
		prefix: String,
		body_col: Color,
		accent_col: Color,
		thickness: float = 2.5
	) -> void:
		var all_body_slots: Array[int] = [
			PartSlot.HEAD,
			PartSlot.EYES,
			PartSlot.TORSO,
			PartSlot.PELVIS,
			PartSlot.UPPER_ARM_L,
			PartSlot.FOREARM_L,
			PartSlot.HAND_L,
			PartSlot.UPPER_ARM_R,
			PartSlot.FOREARM_R,
			PartSlot.HAND_R,
			PartSlot.THIGH_L,
			PartSlot.SHIN_L,
			PartSlot.FOOT_L,
			PartSlot.THIGH_R,
			PartSlot.SHIN_R,
			PartSlot.FOOT_R,
		]
		for s in all_body_slots:
			var p_col: Color = accent_col if s == PartSlot.EYES else body_col
			var part := PartPieceSpec.new(
				"%s_slot_%d" % [prefix, s],
				s,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				p_col,
				accent_col,
				thickness
			)
			register_part(part)
			loadout.equip_part(part)

	func _init_builtin_presets() -> void:
		# --------------------------------------------------------------------
		# 1. PLAYER: "player_shift_staff"
		# Crisp white body, electric cyan scarf, Brass & Cyan Mechanical Cane / Shift Staff
		# --------------------------------------------------------------------
		var player_white := Color(1.0, 1.0, 1.0, 1.0)
		var electric_cyan := Color(0.0, 0.85, 1.0, 0.95)
		var brass_gold := Color(0.88, 0.72, 0.28, 1.0)
		var cane_glow := Color(0.6, 1.0, 1.0, 0.85)

		var player := CharacterLoadout.new(
			"player_shift_staff",
			"Chronos Nomad (Shift Staff)",
			player_white,
			electric_cyan
		)
		_populate_base_humanoid_parts(player, "player", player_white, electric_cyan, 2.6)

		var player_scarf := PartPieceSpec.new(
			"player_chronos_scarf",
			PartSlot.SCARF_CAPE,
			AssetRenderBackend.PROCEDURAL_VECTOR,
			electric_cyan,
			cane_glow,
			2.8
		)
		register_part(player_scarf)
		player.equip_part(player_scarf)

		var shift_staff := WeaponAssemblySpec.new("shift_staff_chronos_key", "shift_staff_cane")
		var staff_pieces: Array[WeaponPieceSpec] = [
			WeaponPieceSpec.new(
				"staff_pommel_counterweight",
				WeaponPieceSlot.POMMEL,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				4.0,
				3.2,
				brass_gold,
				cane_glow,
				false,
				0.0
			),
			WeaponPieceSpec.new(
				"staff_grip_wrapped",
				WeaponPieceSlot.GRIP,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				8.0,
				2.8,
				Color(0.25, 0.3, 0.38, 1.0),
				cane_glow,
				false,
				0.0
			),
			WeaponPieceSpec.new(
				"staff_guard_crook",
				WeaponPieceSlot.GUARD,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				5.0,
				3.0,
				brass_gold,
				cane_glow,
				false,
				4.5
			),
			WeaponPieceSpec.new(
				"staff_shaft_lower",
				WeaponPieceSlot.SHAFT_LOWER,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				10.0,
				2.6,
				player_white,
				cane_glow,
				false,
				0.0
			),
			WeaponPieceSpec.new(
				"staff_gearwork_core",
				WeaponPieceSlot.GEARWORK_CORE,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				8.0,
				3.6,
				brass_gold,
				cane_glow,
				true,
				5.5
			),
			WeaponPieceSpec.new(
				"staff_blade_edge",
				WeaponPieceSlot.BLADE_EDGE,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				26.0,
				2.4,
				electric_cyan,
				cane_glow,
				false,
				0.0
			),
			WeaponPieceSpec.new(
				"staff_chronos_key_teeth",
				WeaponPieceSlot.KEY_TEETH,
				AssetRenderBackend.PROCEDURAL_VECTOR,
				7.0,
				2.8,
				brass_gold,
				electric_cyan,
				true,
				9.5
			),
		]
		for wp in staff_pieces:
			register_weapon_piece(wp)
			shift_staff.set_piece(wp)

		# Also register SHAFT_UPPER in the global weapon piece catalog for modular swapping
		var optional_upper_shaft := WeaponPieceSpec.new(
			"staff_shaft_upper",
			WeaponPieceSlot.SHAFT_UPPER,
			AssetRenderBackend.PROCEDURAL_VECTOR,
			9.0,
			2.5,
			brass_gold,
			cane_glow,
			true,
			0.0
		)
		register_weapon_piece(optional_upper_shaft)

		player.weapon_assembly = shift_staff
		var player_weapon_slot := PartPieceSpec.new(
			"player_main_weapon_slot",
			PartSlot.WEAPON_MAIN,
			AssetRenderBackend.PROCEDURAL_VECTOR,
			electric_cyan,
			brass_gold,
			2.8
		)
		register_part(player_weapon_slot)
		player.equip_part(player_weapon_slot)
		register_loadout(player)

		# --------------------------------------------------------------------
		# 2. ENEMY: "enemy_runner" (Crimson melee slasher)
		# --------------------------------------------------------------------
		var runner_body := Color(0.85, 0.2, 0.2, 1.0)
		var runner_blade := Color(1.0, 0.3, 0.2, 1.0)
		var runner := CharacterLoadout.new(
			"enemy_runner",
			"Crimson Slasher",
			runner_body,
			runner_blade
		)
		_populate_base_humanoid_parts(runner, "runner", runner_body, Color(1.0, 0.1, 0.1, 1.0), 2.4)
		runner.weapon_assembly = WeaponAssemblySpec.new("runner_machete", "katana")
		var runner_grip := WeaponPieceSpec.new(
			"runner_grip", WeaponPieceSlot.GRIP, AssetRenderBackend.PROCEDURAL_VECTOR, 6.0, 2.2, runner_body, runner_blade
		)
		var runner_edge := WeaponPieceSpec.new(
			"runner_blade", WeaponPieceSlot.BLADE_EDGE, AssetRenderBackend.PROCEDURAL_VECTOR, 28.0, 2.5, runner_blade, runner_blade
		)
		register_weapon_piece(runner_grip)
		register_weapon_piece(runner_edge)
		runner.weapon_assembly.set_piece(runner_grip)
		runner.weapon_assembly.set_piece(runner_edge)
		register_loadout(runner)

		# --------------------------------------------------------------------
		# 3. ENEMY: "enemy_ninja" (Violet assassin with twin-edge katana & ninja cowl)
		# --------------------------------------------------------------------
		var ninja_body := Color(0.5, 0.1, 0.7, 1.0)
		var ninja_accent := Color(0.8, 0.2, 1.0, 1.0)
		var ninja := CharacterLoadout.new(
			"enemy_ninja",
			"Chronos Shadow Ninja",
			ninja_body,
			ninja_accent
		)
		_populate_base_humanoid_parts(ninja, "ninja", ninja_body, Color(1.0, 0.15, 0.4, 1.0), 2.3)
		var ninja_cowl := PartPieceSpec.new(
			"ninja_cowl_hood",
			PartSlot.HAT_HELMET,
			AssetRenderBackend.CUSTOM_POLYGON,
			ninja_body,
			ninja_accent,
			2.0
		)
		ninja_cowl.polygon_points = PackedVector2Array([
			Vector2(-8.0, -2.0), Vector2(0.0, 9.0), Vector2(8.0, -2.0), Vector2(0.0, 2.0)
		])
		var ninja_scarf := PartPieceSpec.new(
			"ninja_shadow_scarf",
			PartSlot.SCARF_CAPE,
			AssetRenderBackend.PROCEDURAL_VECTOR,
			ninja_accent,
			ninja_body,
			2.2
		)
		register_part(ninja_cowl)
		register_part(ninja_scarf)
		ninja.equip_part(ninja_cowl)
		ninja.equip_part(ninja_scarf)

		ninja.weapon_assembly = WeaponAssemblySpec.new("ninja_twin_katana", "katana")
		var ninja_guard := WeaponPieceSpec.new(
			"ninja_tsuba_guard", WeaponPieceSlot.GUARD, AssetRenderBackend.PROCEDURAL_VECTOR, 4.0, 2.5, ninja_accent, ninja_accent
		)
		var ninja_blade := WeaponPieceSpec.new(
			"ninja_katana_blade", WeaponPieceSlot.BLADE_EDGE, AssetRenderBackend.PROCEDURAL_VECTOR, 34.0, 2.2, ninja_accent, ninja_accent
		)
		register_weapon_piece(ninja_guard)
		register_weapon_piece(ninja_blade)
		ninja.weapon_assembly.set_piece(ninja_guard)
		ninja.weapon_assembly.set_piece(ninja_blade)
		register_loadout(ninja)

		# --------------------------------------------------------------------
		# 4. ENEMY: "enemy_heavy" (Past-era armored Golem/Guardian with polygon plates & cleaver)
		# --------------------------------------------------------------------
		var heavy_body := Color(0.8, 0.35, 0.1, 1.0)
		var heavy_accent := Color(1.0, 0.5, 0.0, 1.0)
		var heavy := CharacterLoadout.new(
			"enemy_heavy",
			"Ancient Stone Guardian",
			heavy_body,
			heavy_accent
		)
		_populate_base_humanoid_parts(heavy, "heavy", heavy_body, heavy_accent, 3.8)

		var chest_plate := PartPieceSpec.new(
			"heavy_golem_chestplate",
			PartSlot.TORSO,
			AssetRenderBackend.CUSTOM_POLYGON,
			heavy_body,
			heavy_accent,
			3.5
		)
		chest_plate.polygon_points = PackedVector2Array([
			Vector2(-9.0, -10.0),
			Vector2(9.0, -10.0),
			Vector2(12.0, 10.0),
			Vector2(-12.0, 10.0),
		])
		var pauldron_l := PartPieceSpec.new(
			"heavy_pauldron_l",
			PartSlot.UPPER_ARM_L,
			AssetRenderBackend.CUSTOM_POLYGON,
			heavy_body,
			heavy_accent,
			3.2
		)
		pauldron_l.polygon_points = PackedVector2Array([
			Vector2(-6.0, -5.0), Vector2(6.0, -5.0), Vector2(8.0, 5.0), Vector2(-4.0, 5.0)
		])
		var pauldron_r := PartPieceSpec.new(
			"heavy_pauldron_r",
			PartSlot.UPPER_ARM_R,
			AssetRenderBackend.CUSTOM_POLYGON,
			heavy_body,
			heavy_accent,
			3.2
		)
		pauldron_r.polygon_points = PackedVector2Array([
			Vector2(-6.0, -5.0), Vector2(6.0, -5.0), Vector2(8.0, 5.0), Vector2(-4.0, 5.0)
		])
		var heavy_helm := PartPieceSpec.new(
			"heavy_crest_helmet",
			PartSlot.HAT_HELMET,
			AssetRenderBackend.CUSTOM_POLYGON,
			heavy_accent,
			heavy_body,
			3.0
		)
		heavy_helm.polygon_points = PackedVector2Array([
			Vector2(-8.0, 0.0), Vector2(0.0, 12.0), Vector2(8.0, 0.0)
		])
		register_part(chest_plate)
		register_part(pauldron_l)
		register_part(pauldron_r)
		register_part(heavy_helm)
		heavy.equip_part(chest_plate)
		heavy.equip_part(pauldron_l)
		heavy.equip_part(pauldron_r)
		heavy.equip_part(heavy_helm)

		heavy.weapon_assembly = WeaponAssemblySpec.new("heavy_stone_cleaver", "heavy_cleaver")
		var cleaver_blade := WeaponPieceSpec.new(
			"heavy_cleaver_polygon_blade",
			WeaponPieceSlot.BLADE_EDGE,
			AssetRenderBackend.CUSTOM_POLYGON,
			36.0,
			5.5,
			heavy_accent,
			heavy_body
		)
		cleaver_blade.polygon_points = PackedVector2Array([
			Vector2(0.0, -3.0), Vector2(28.0, -7.0), Vector2(34.0, 0.0), Vector2(28.0, 7.0), Vector2(0.0, 3.0)
		])
		register_weapon_piece(cleaver_blade)
		heavy.weapon_assembly.set_piece(cleaver_blade)
		register_loadout(heavy)

		# --------------------------------------------------------------------
		# 5. ENEMY: "enemy_gunner_semi" (Emerald marksman with modular rifle + scope + stock)
		# --------------------------------------------------------------------
		var semi_body := Color(0.2, 0.8, 0.45, 1.0)
		var semi_accent := Color(0.3, 1.0, 0.55, 1.0)
		var gunner_semi := CharacterLoadout.new(
			"enemy_gunner_semi",
			"Emerald Marksman",
			semi_body,
			semi_accent
		)
		_populate_base_humanoid_parts(gunner_semi, "gunner_semi", semi_body, semi_accent, 2.4)
		gunner_semi.weapon_assembly = WeaponAssemblySpec.new("semi_marksman_rifle", "semi_rifle")
		var semi_stock := WeaponPieceSpec.new(
			"semi_rifle_stock", WeaponPieceSlot.GRIP, AssetRenderBackend.PROCEDURAL_VECTOR, 6.0, 2.5, semi_body, semi_accent
		)
		var semi_barrel := WeaponPieceSpec.new(
			"semi_rifle_barrel", WeaponPieceSlot.MUZZLE_BARREL, AssetRenderBackend.PROCEDURAL_VECTOR, 26.0, 2.4, semi_accent, semi_accent
		)
		var semi_scope := WeaponPieceSpec.new(
			"semi_optic_scope", WeaponPieceSlot.OPTIC_SCOPE, AssetRenderBackend.PROCEDURAL_VECTOR, 12.0, 2.0, semi_accent, semi_accent
		)
		register_weapon_piece(semi_stock)
		register_weapon_piece(semi_barrel)
		register_weapon_piece(semi_scope)
		gunner_semi.weapon_assembly.set_piece(semi_stock)
		gunner_semi.weapon_assembly.set_piece(semi_barrel)
		gunner_semi.weapon_assembly.set_piece(semi_scope)
		register_loadout(gunner_semi)

		# --------------------------------------------------------------------
		# 6. ENEMY: "enemy_gunner_auto" (Amber gunner with double-barrel SMG + drum magazine)
		# --------------------------------------------------------------------
		var auto_body := Color(0.95, 0.7, 0.1, 1.0)
		var auto_accent := Color(1.0, 0.85, 0.2, 1.0)
		var gunner_auto := CharacterLoadout.new(
			"enemy_gunner_auto",
			"Amber Suppressor",
			auto_body,
			auto_accent
		)
		_populate_base_humanoid_parts(gunner_auto, "gunner_auto", auto_body, auto_accent, 2.5)
		gunner_auto.weapon_assembly = WeaponAssemblySpec.new("auto_double_smg", "auto_smg")
		var smg_grip := WeaponPieceSpec.new(
			"smg_grip", WeaponPieceSlot.GRIP, AssetRenderBackend.PROCEDURAL_VECTOR, 5.0, 2.4, auto_body, auto_accent
		)
		var smg_barrel := WeaponPieceSpec.new(
			"smg_twin_barrel", WeaponPieceSlot.MUZZLE_BARREL, AssetRenderBackend.PROCEDURAL_VECTOR, 18.0, 3.2, auto_accent, auto_accent
		)
		var smg_drum := WeaponPieceSpec.new(
			"smg_drum_magazine", WeaponPieceSlot.MAGAZINE, AssetRenderBackend.PROCEDURAL_VECTOR, 6.0, 3.5, auto_accent, auto_body
		)
		register_weapon_piece(smg_grip)
		register_weapon_piece(smg_barrel)
		register_weapon_piece(smg_drum)
		gunner_auto.weapon_assembly.set_piece(smg_grip)
		gunner_auto.weapon_assembly.set_piece(smg_barrel)
		gunner_auto.weapon_assembly.set_piece(smg_drum)
		register_loadout(gunner_auto)

		# --------------------------------------------------------------------
		# 7. ENEMY: "enemy_sniper" (Future-era cyber sniper with long rail-barrel + laser sight + visor)
		# --------------------------------------------------------------------
		var sniper_body := Color(0.15, 0.65, 0.95, 1.0)
		var sniper_accent := Color(1.0, 0.15, 0.35, 1.0)
		var sniper := CharacterLoadout.new(
			"enemy_sniper",
			"Future Cyber Sniper",
			sniper_body,
			sniper_accent
		)
		_populate_base_humanoid_parts(sniper, "sniper", sniper_body, sniper_accent, 2.3)
		var sniper_visor := PartPieceSpec.new(
			"sniper_cyber_visor",
			PartSlot.EYES,
			AssetRenderBackend.CUSTOM_POLYGON,
			sniper_accent,
			sniper_body,
			2.2
		)
		sniper_visor.polygon_points = PackedVector2Array([
			Vector2(-2.0, -1.5), Vector2(6.0, -1.5), Vector2(7.0, 1.5), Vector2(-1.0, 1.5)
		])
		register_part(sniper_visor)
		sniper.equip_part(sniper_visor)

		sniper.weapon_assembly = WeaponAssemblySpec.new("cyber_rail_sniper", "sniper_laser")
		var rail_grip := WeaponPieceSpec.new(
			"rail_sniper_stock", WeaponPieceSlot.GRIP, AssetRenderBackend.PROCEDURAL_VECTOR, 8.0, 2.5, sniper_body, sniper_accent
		)
		var rail_barrel := WeaponPieceSpec.new(
			"rail_sniper_long_barrel", WeaponPieceSlot.MUZZLE_BARREL, AssetRenderBackend.PROCEDURAL_VECTOR, 38.0, 2.6, sniper_body, sniper_accent
		)
		var laser_module := WeaponPieceSpec.new(
			"rail_sniper_laser_optic", WeaponPieceSlot.OPTIC_SCOPE, AssetRenderBackend.PROCEDURAL_VECTOR, 16.0, 2.2, sniper_accent, sniper_accent
		)
		register_weapon_piece(rail_grip)
		register_weapon_piece(rail_barrel)
		register_weapon_piece(laser_module)
		sniper.weapon_assembly.set_piece(rail_grip)
		sniper.weapon_assembly.set_piece(rail_barrel)
		sniper.weapon_assembly.set_piece(laser_module)
		register_loadout(sniper)
