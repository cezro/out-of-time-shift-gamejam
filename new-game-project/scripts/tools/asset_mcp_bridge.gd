#!/usr/bin/env -S godot --headless --script
class_name AssetMcpBridge
extends SceneTree

## Godot-MCP Asset Bridge for Piece-by-Piece Modular Asset Registration.
## Mirrors register_modular_part and register_weapon_piece from tools/godot-mcp/src/scripts/godot_operations.gd
## so external AI agents, CLI tools, or runtime scripts can register character parts,
## weapon pieces, polygons, and textures into res://assets/modular_parts_manifest.json.

const DEFAULT_MANIFEST_PATH: String = "res://assets/modular_parts_manifest.json"
const RigSystem = preload("res://scripts/modular_rig/modular_asset_system.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var script_index: int = args.find("--script")
	if script_index == -1 or script_index + 1 >= args.size():
		return
	var active_script: String = args[script_index + 1]
	if not active_script.ends_with("asset_mcp_bridge.gd"):
		# Instantiated as a helper object inside another script or test runner
		return

	var operation_index: int = script_index + 2
	var params_index: int = script_index + 3
	if args.size() <= params_index:
		printerr("[ERROR] Usage: godot --headless --script asset_mcp_bridge.gd <operation> <json_params>")
		quit(1)
		return

	var operation: String = args[operation_index]
	var params_json: String = args[params_index]
	var parsed = JSON.parse_string(params_json)
	if not (parsed is Dictionary):
		printerr("[ERROR] Failed to parse JSON parameters: " + params_json)
		quit(1)
		return

	var params: Dictionary = parsed
	var ok: bool = false
	match operation:
		"register_modular_part":
			ok = register_modular_part(params)
		"register_weapon_piece":
			ok = register_weapon_piece(params)
		_:
			printerr("[ERROR] Unknown operation: " + operation)
			quit(1)
			return

	quit(0 if ok else 1)


static func load_or_init_manifest(manifest_path: String = DEFAULT_MANIFEST_PATH) -> Dictionary:
	var full_path: String = _normalize_res_path(manifest_path)
	if FileAccess.file_exists(full_path):
		var f := FileAccess.open(full_path, FileAccess.READ)
		if f != null:
			var raw_text: String = f.get_as_text()
			f.close()
			var parsed = JSON.parse_string(raw_text)
			if parsed is Dictionary:
				var d: Dictionary = parsed
				if not d.has("version"):
					d["version"] = "1.0"
				if not (d.get("parts") is Array):
					d["parts"] = []
				if not (d.get("weapon_pieces") is Array):
					d["weapon_pieces"] = []
				if not (d.get("loadouts") is Dictionary):
					d["loadouts"] = {}
				return d
	return {
		"version": "1.0",
		"parts": [],
		"weapon_pieces": [],
		"loadouts": {},
	}


static func save_manifest(manifest_path: String, manifest: Dictionary) -> bool:
	var full_path: String = _normalize_res_path(manifest_path)
	var base_dir: String = full_path.get_base_dir()
	var abs_dir: String = ProjectSettings.globalize_path(base_dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var err: Error = DirAccess.make_dir_recursive_absolute(abs_dir)
		if err != OK:
			printerr("[ERROR] Failed to create directory: " + abs_dir)
			return false

	var f := FileAccess.open(full_path, FileAccess.WRITE)
	if f == null:
		printerr("[ERROR] Failed to open manifest for writing: " + full_path)
		return false
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	return true


static func register_modular_part(params: Dictionary) -> bool:
	var manifest_path: String = RigSystem._Ser.safe_str(params.get("manifest_path"), DEFAULT_MANIFEST_PATH)
	if manifest_path.is_empty():
		manifest_path = DEFAULT_MANIFEST_PATH
	manifest_path = _normalize_res_path(manifest_path)

	var part_id: String = RigSystem._Ser.safe_str(params.get("part_id"), "")
	if part_id.is_empty():
		printerr("[ERROR] register_modular_part requires a non-empty 'part_id'")
		return false

	var manifest: Dictionary = load_or_init_manifest(manifest_path)
	var spec = RigSystem.PartPieceSpec.from_dict(params)
	var part_entry: Dictionary = spec.to_dict()
	if params.has("target_loadout"):
		var target_lo: String = RigSystem._Ser.safe_str(params.get("target_loadout"), "")
		if not target_lo.is_empty():
			part_entry["target_loadout"] = target_lo

	var parts_list: Array = manifest["parts"]
	var replaced: bool = false
	for i in range(parts_list.size()):
		if parts_list[i] is Dictionary and RigSystem._Ser.safe_str(parts_list[i].get("part_id"), "") == part_id:
			parts_list[i] = part_entry
			replaced = true
			break
	if not replaced:
		parts_list.append(part_entry)

	if not save_manifest(manifest_path, manifest):
		return false
	print("[INFO] Registered modular part '" + part_id + "' in " + manifest_path)
	return true


static func register_weapon_piece(params: Dictionary) -> bool:
	var manifest_path: String = RigSystem._Ser.safe_str(params.get("manifest_path"), DEFAULT_MANIFEST_PATH)
	if manifest_path.is_empty():
		manifest_path = DEFAULT_MANIFEST_PATH
	manifest_path = _normalize_res_path(manifest_path)

	var piece_id: String = RigSystem._Ser.safe_str(params.get("piece_id"), "")
	if piece_id.is_empty():
		printerr("[ERROR] register_weapon_piece requires a non-empty 'piece_id'")
		return false

	var manifest: Dictionary = load_or_init_manifest(manifest_path)
	var spec = RigSystem.WeaponPieceSpec.from_dict(params)
	var piece_entry: Dictionary = spec.to_dict()
	if params.has("target_loadout"):
		var target_lo: String = RigSystem._Ser.safe_str(params.get("target_loadout"), "")
		if not target_lo.is_empty():
			piece_entry["target_loadout"] = target_lo

	var wp_list: Array = manifest["weapon_pieces"]
	var replaced: bool = false
	for i in range(wp_list.size()):
		if wp_list[i] is Dictionary and RigSystem._Ser.safe_str(wp_list[i].get("piece_id"), "") == piece_id:
			wp_list[i] = piece_entry
			replaced = true
			break
	if not replaced:
		wp_list.append(piece_entry)

	if not save_manifest(manifest_path, manifest):
		return false
	print("[INFO] Registered modular weapon piece '" + piece_id + "' in " + manifest_path)
	return true


static func _normalize_res_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	return "res://" + path
