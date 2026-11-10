class_name GameAudioManager
extends Node

## Audio manager for OUT OF TIME.
## Preloads all combat, movement, and time-dilation SFX and plays them safely
## in both interactive and headless (--headless / dummy audio driver) modes.

const SFX_PATHS: Dictionary = {
	"slash": "res://assets/audio/slash.wav",
	"warp": "res://assets/audio/warp.wav",
	"slowmo_enter": "res://assets/audio/slowmo_enter.wav",
	"slowmo_exit": "res://assets/audio/slowmo_exit.wav",
	"slice_kill": "res://assets/audio/slice_kill.wav",
	"dash": "res://assets/audio/dash.wav",
	"jump": "res://assets/audio/jump.wav",
}

const POOL_SIZE: int = 8

var streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var last_played_sfx: String = ""
var play_counts: Dictionary = {}


func _init() -> void:
	_load_streams()


func _ready() -> void:
	if _players.is_empty():
		for i in range(POOL_SIZE):
			var player := AudioStreamPlayer.new()
			player.name = "SfxPlayer_%d" % i
			add_child(player)
			_players.append(player)


func _load_streams() -> void:
	for sfx_key in SFX_PATHS.keys():
		var path: String = SFX_PATHS[sfx_key]
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is AudioStream:
				streams[sfx_key] = res


## Plays the requested sound effect safely (no-op on audio hardware if headless/dummy,
## while still tracking playback state for deterministic verification).
func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var key: String = sfx_name.strip_edges().to_lower()
	if key.ends_with(".wav"):
		key = key.substr(0, key.length() - 4)

	if not streams.has(key) and SFX_PATHS.has(key):
		var path: String = SFX_PATHS[key]
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is AudioStream:
				streams[key] = res

	last_played_sfx = key
	play_counts[key] = int(play_counts.get(key, 0)) + 1

	if not streams.has(key):
		return

	var clean_pitch: float = clampf(pitch_scale, 0.1, 4.0) if is_finite(pitch_scale) else 1.0
	var clean_vol: float = clampf(volume_db, -80.0, 24.0) if is_finite(volume_db) else 0.0

	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return

	if _players.is_empty():
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	var player: AudioStreamPlayer = _players[_next_player_idx % _players.size()]
	_next_player_idx = (_next_player_idx + 1) % _players.size()
	if player != null and player.is_inside_tree():
		player.stream = streams[key]
		player.pitch_scale = clean_pitch
		player.volume_db = clean_vol
		player.play()


## Stops all audio players and detaches active streams so audio server resources
## and playback handles do not leak on scene teardown.
func stop_all() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _exit_tree() -> void:
	stop_all()
	for player in _players:
		if is_instance_valid(player) and player.get_parent() == null:
			player.free()
	_players.clear()
	streams.clear()

