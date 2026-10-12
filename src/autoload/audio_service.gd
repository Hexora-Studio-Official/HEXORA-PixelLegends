extends Node
## Audio routing, procedural interface cues and music playback.
##
## Bus layout (see default_bus_layout.tres): Master → Music / SFX / UI / Voice.
## Settings owns the volume values; this service is what actually plays things,
## so the two never fight over a bus.
##
## Music is loaded on demand from `res://assets/audio/music/<id>.ogg`. No track
## ships yet — the phase 1 menu is intentionally clean — but dropping a file
## with the right name in that folder activates it with no code change. That is
## also why the music player exists at all rather than being deferred.

const MUSIC_DIR := "res://assets/audio/music/"
const UI_VOICE_COUNT := 6

## Convenience ids used by the Router and the screens. Kept as constants so no
## call site has to invent a track name.
const TRACK_MENU := "menu_ambient"
const TRACK_LOBBY := "lobby_pulse"
const TRACK_MATCH := "match_tension"

var _cues: Dictionary = {}                     ## name -> AudioStreamWAV
var _ui_players: Array[AudioStreamPlayer] = []
var _next_ui_player: int = 0
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active_is_a: bool = true
var _music_track: String = ""
var _music_fade_tween: Tween
var _missing_tracks: Dictionary = {}           ## warn once per track


func _ready() -> void:
	_build_cues()
	_build_players()
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.language_changed.connect(_on_language_changed)


func _build_cues() -> void:
	for name in ToneSynth.cue_names():
		_cues[name] = ToneSynth.cue(name)


func _build_players() -> void:
	# UI cues are extremely short and frequently overlap (a click on top of a
	# hover), so they get their own round-robin pool.
	for index in UI_VOICE_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "UiVoice%d" % index
		player.bus = &"UI"
		add_child(player)
		_ui_players.append(player)

	# World/gameplay effects reuse the same pool pattern on the SFX bus.
	for index in 8:
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % index
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)

	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	_music_a.bus = &"Music"
	_music_a.volume_db = -60.0
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	_music_b.bus = &"Music"
	_music_b.volume_db = -60.0
	add_child(_music_b)


func _on_settings_changed(section: StringName) -> void:
	# Settings writes the bus volumes; nothing to re-apply here. This hook
	# exists so the service can react to future audio options (mono output,
	# mute-in-background) in one place.
	if section == &"audio":
		if Settings.get_bool("audio/mute_in_background", true):
			var muted := not get_window().has_focus()
			_set_music_paused(muted)


func _on_language_changed(_locale: String) -> void:
	# A language change implies a UI rebuild; a soft cue covers the transition.
	play_ui("whoosh")


# ------------------------------------------------------------------ interface

## Play a named procedural cue on the UI bus. Unknown names warn once and are
## ignored, so a typo never crashes a screen.
func play_ui(cue_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _cues.has(cue_name):
		push_warning("Audio: unknown UI cue '%s'." % cue_name)
		return
	var player := _ui_players[_next_ui_player]
	_next_ui_player = (_next_ui_player + 1) % _ui_players.size()
	player.stream = _cues[cue_name]
	player.pitch_scale = clampf(pitch, 0.05, 4.0)
	player.volume_db = volume_db
	player.play()


## Play a full stream on the SFX bus, returning the player so callers can stop
## or follow it (a looping search pulse, for instance).
func play_sfx(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.05, 4.0)
	player.volume_db = volume_db
	player.play()
	return player


## Short haptic + click for a primary action, so call sites stay one line.
func feedback(cue_name: String = "click") -> void:
	play_ui(cue_name)
	if Controls != null:
		Controls.haptic(12)


# ----------------------------------------------------------------------- music

## Crossfade to a track. Passing "" or the already-playing track is a no-op,
## which lets screens call this unconditionally in `_ready()`.
func play_music(track_id: String, fade_seconds: float = 1.2) -> void:
	if track_id == _music_track:
		return
	var stream := _load_track(track_id)
	if stream == null:
		_music_track = track_id
		return
	_music_track = track_id

	var incoming := _music_b if _music_active_is_a else _music_a
	var outgoing := _music_a if _music_active_is_a else _music_b
	_music_active_is_a = not _music_active_is_a

	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()

	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween().set_parallel(true)
	_music_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_seconds)
	_music_fade_tween.tween_property(outgoing, "volume_db", -60.0, fade_seconds)
	_music_fade_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade_seconds: float = 0.8) -> void:
	_music_track = ""
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween().set_parallel(true)
	for player in [_music_a, _music_b]:
		if player.playing:
			_music_fade_tween.tween_property(player, "volume_db", -60.0, fade_seconds)
	_music_fade_tween.chain().tween_callback(_stop_all_music)


func _stop_all_music() -> void:
	_music_a.stop()
	_music_b.stop()


func current_track() -> String:
	return _music_track


func _set_music_paused(paused: bool) -> void:
	for player in [_music_a, _music_b]:
		player.stream_paused = paused


## Loads `<MUSIC_DIR><id>.ogg`, or null when the asset is absent. Missing music
## is a normal state in phase 1, not an error, so it is logged once at debug
## level only.
func _load_track(track_id: String) -> AudioStream:
	if track_id.is_empty():
		return null
	var path := MUSIC_DIR + track_id + ".ogg"
	if not ResourceLoader.exists(path):
		if not _missing_tracks.has(path):
			_missing_tracks[path] = true
			if OS.is_debug_build():
				print("Audio: no track at %s (music stays silent)." % path)
		return null
	var stream := ResourceLoader.load(path)
	return stream as AudioStream


## Used by the Settings "test tone" button, and to preview a cue in the audio
## mixer UI later.
func preview_cue(cue_name: String) -> void:
	play_ui(cue_name, 1.0, 0.0)


## Every cue name, for developer tooling.
func cue_names() -> PackedStringArray:
	return ToneSynth.cue_names()
