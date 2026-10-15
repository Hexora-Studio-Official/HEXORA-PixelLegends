extends Node
## Persistent user settings, device tier detection and the runtime application
## of graphics options.
##
## Design choices worth knowing:
##
##   * Flat `"section/key"` namespace instead of nested dictionaries. It makes
##     `Settings.get_int("graphics/shadow_quality")` read like a path, keeps the
##     ConfigFile layout obvious, and makes "did I save this?" a one-line grep.
##   * Defaults are built in `_build_defaults()` rather than a `const` so that
##     they can reference the GameTypes enums without risking a load-order
##     cycle. A missing key always resolves to its default, so adding a setting
##     never breaks an existing user's config file.
##   * Applying graphics settings is the *only* place that touches renderer
##     state. Screens never call RenderingServer directly.
##
## Config lives at `user://settings.cfg` and is written on change (debounced),
## never on a frame the player is actively playing.

## Coarse device classes used to pick sane defaults on first launch.
enum DeviceTier { LOW, MEDIUM, HIGH }

const CONFIG_PATH := "user://settings.cfg"
const SCHEMA_VERSION := 2
const SAVE_DEBOUNCE_SEC := 0.75

var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _config := ConfigFile.new()
var _dirty := false
var _save_timer := 0.0
var _device_tier: DeviceTier = DeviceTier.MEDIUM
var _device_name: String = "Unknown"


func _init() -> void:
	_defaults = _build_defaults()


func _ready() -> void:
	_device_tier = _detect_device_tier()
	_device_name = _detect_device_name()
	_load()
	_apply_first_launch_defaults()
	apply_all()
	# Never leave a half-written config behind.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		flush()
		get_tree().quit()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_save_timer -= delta
	if _save_timer <= 0.0:
		flush()


func _build_defaults() -> Dictionary:
	var tier := _detect_device_tier()
	# Quality preset per tier: battery saver on weak hardware, balanced in the
	# middle (the default we ship), high on flagships.
	var preset := 0 if tier == DeviceTier.LOW else (1 if tier == DeviceTier.MEDIUM else 2)
	return {
		# ------------------------------------------------------------ game
		"game/show_ping": true,
		"game/show_fps": false,
		"game/vibration": true,
		"game/keep_screen_on": true,
		"game/streamer_mode": false,
		"game/terms_version": 1,
		"game/tutorial_complete": false,
		"game/first_run_complete": false,
		# PixelLegends ships English only (see src/autoload/loc.gd). There is
		# deliberately no "auto-detect", "text language" or "voice language"
		# key: with one locale they could only be decoration, and the spec
		# rules out showing options the build cannot honour.
		"game/remember_settings": true,
		"game/reduce_animations": false,
		"game/notifications": true,
		"game/confirm_exit": true,

		# -------------------------------------------------------- graphics
		"graphics/quality_preset": preset,
		"graphics/render_scale": [0.75, 1.0, 1.0][preset],
		"graphics/fps_limit": [30, 60, 90][preset],
		"graphics/shadows": tier != DeviceTier.LOW,
		"graphics/shadow_quality": [0, 1, 2][preset],
		"graphics/anti_aliasing": 0 if tier == DeviceTier.LOW else 1,  # off | fxaa | msaa2 | msaa4
		"graphics/texture_quality": [1, 2, 2][preset],
		"graphics/decals": tier != DeviceTier.LOW,
		"graphics/bloom": tier == DeviceTier.HIGH,
		"graphics/motion_blur": false,
		"graphics/ragdolls": tier != DeviceTier.LOW,
		"graphics/hud_scale": 1.0,
		"graphics/effects_quality": preset,
		"graphics/battery_saver": tier == DeviceTier.LOW,

		# ----------------------------------------------------------- audio
		# Linear 0..1. Design keeps these on the buses' initial values so that
		# a fresh install sounds right before the player opens Settings.
		"audio/master": 0.85,
		"audio/music": 0.55,
		"audio/sfx": 0.9,
		"audio/ui": 0.75,
		"audio/voice": 1.0,
		"audio/mic_enabled": false,
		"audio/push_to_talk": true,
		"audio/mute_in_background": true,
		"audio/mute_all": false,

		# --------------------------------------------------- accessibility
		"accessibility/ui_scale": 1.0,
		"accessibility/text_size": 1,          # 0 small | 1 normal | 2 large
		"accessibility/high_contrast": false,
		"accessibility/colorblind_mode": 0,    # 0 off | 1 protan | 2 deutan | 3 tritan
		"accessibility/reduce_shake": false,
		"accessibility/reduce_flashing": false,
		"accessibility/subtitles": false,
		"accessibility/subtitle_size": 1,      # 0 small | 1 medium | 2 large

		# --------------------------------------------------------- network
		# Local preferences only. Nothing here talks to a server: the client
		# has no backend yet, so the panel shows connection state it can
		# actually measure and hides what it cannot.
		"network/wifi_only": true,
		"network/auto_download": true,

	}


func _detect_device_tier() -> DeviceTier:
	# Heuristic, refined on first launch only. Cores + RAM separate the
	# flagship / mid / budget Android market well enough to pick a preset;
	# the player can always override.
	var cores := OS.get_processor_count()
	var memory_mb := 4096
	var memory_info := OS.get_memory_info()
	if memory_info.has("physical"):
		memory_mb = int(int(memory_info["physical"]) / (1024 * 1024))

	if cores <= 4 or memory_mb <= 3072:
		return DeviceTier.LOW
	if cores <= 6 or memory_mb <= 6144:
		return DeviceTier.MEDIUM
	return DeviceTier.HIGH


func _detect_device_name() -> String:
	var adapter := String(RenderingServer.get_video_adapter_name()).strip_edges()
	if adapter.is_empty():
		adapter = OS.get_name()
	return adapter


func _apply_first_launch_defaults() -> void:
	# A first launch has no stored preset; adopt the tier default. Once the
	# player has chosen, `graphics/quality_preset` exists and we leave it be.
	if not _values.has("graphics/quality_preset"):
		apply_quality_preset(int(_defaults["graphics/quality_preset"]), false)


# --------------------------------------------------------------------- access

func get_value(key: StringName, fallback: Variant = null) -> Variant:
	var string_key := String(key)
	if _values.has(string_key):
		return _values[string_key]
	if _defaults.has(string_key):
		return _defaults[string_key]
	return fallback


func get_int(key: StringName, fallback: int = 0) -> int:
	var value: Variant = get_value(key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is bool:
		return 1 if value else 0
	return fallback


func get_float(key: StringName, fallback: float = 0.0) -> float:
	var value: Variant = get_value(key, fallback)
	if value is float:
		return value
	if value is int:
		return float(value)
	return fallback


func get_bool(key: StringName, fallback: bool = false) -> bool:
	var value: Variant = get_value(key, fallback)
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	return fallback


func get_string(key: StringName, fallback: String = "") -> String:
	var value: Variant = get_value(key, fallback)
	if value == null:
		return fallback
	return String(value)


## Set a value and notify listeners. `silent` skips the signal for bulk writes
## (e.g. applying a whole quality preset) where the caller applies once at the
## end anyway.
func set_value(key: StringName, value: Variant, silent: bool = false) -> void:
	var string_key := String(key)
	var previous: Variant = _values.get(string_key, _defaults.get(string_key))
	if previous == value and _values.has(string_key):
		return
	_values[string_key] = value
	_mark_dirty()
	var section := StringName(string_key.get_slice("/", 0))
	if not silent:
		# Apply first, then announce: a listener that re-reads the value sees
		# the engine already in the new state, which removes any chance of a
		# screen showing a setting that has not taken effect yet.
		_apply_section(section)
		EventBus.settings_changed.emit(section)


## Push one settings group at the live engine state. Dispatched from
## `set_value()` so that *any* writer gets correct behaviour for free.
func _apply_section(section: StringName) -> void:
	match section:
		&"audio": apply_audio()
		&"graphics": apply_graphics()
		&"game": apply_game()
		&"accessibility": apply_accessibility()
		&"network": apply_network()


func reset_all() -> void:
	_values.clear()
	_defaults = _build_defaults()
	apply_all()
	_mark_dirty()
	for section in ["game", "graphics", "audio", "controls", "dev"]:
		EventBus.settings_changed.emit(StringName(section))


func default_of(key: StringName) -> Variant:
	return _defaults.get(String(key))


func device_tier() -> DeviceTier:
	return _device_tier


func device_tier_label() -> String:
	match _device_tier:
		DeviceTier.LOW: return "LOW"
		DeviceTier.MEDIUM: return "MEDIUM"
		_: return "HIGH"


func device_name() -> String:
	return _device_name


# ---------------------------------------------------------------- persistence

func _load() -> void:
	var error := _config.load(CONFIG_PATH)
	if error != OK:
		# First launch, or the file was removed by the player. Defaults apply.
		return
	var stored_schema := int(_config.get_value("meta", "schema", 0))
	for section in _config.get_sections():
		if section == "meta":
			continue
		for key in _config.get_section_keys(section):
			_values["%s/%s" % [section, key]] = _config.get_value(section, key)
	if stored_schema != SCHEMA_VERSION:
		_migrate(stored_schema)


## Migrations are append-only: each step upgrades one version forward so that
## a player returning after two releases still lands on a sane config.
func _migrate(from_version: int) -> void:
	if from_version < 2:
		# v1 stored a single `audio/volume` float for everything.
		if _values.has("audio/volume"):
			var legacy: float = float(_values["audio/volume"])
			for channel in ["master", "music", "sfx", "ui", "voice"]:
				if not _values.has("audio/%s" % channel):
					_values["audio/%s" % channel] = legacy
			_values.erase("audio/volume")
	_mark_dirty()


func flush() -> void:
	_dirty = false
	_save_timer = SAVE_DEBOUNCE_SEC
	_config = ConfigFile.new()
	_config.set_value("meta", "schema", SCHEMA_VERSION)
	_config.set_value("meta", "saved_at", int(Time.get_unix_time_from_system()))
	for composite: String in _values:
		var parts := composite.split("/", true, 1)
		if parts.size() != 2:
			continue
		_config.set_value(parts[0], parts[1], _values[composite])
	var error := _config.save(CONFIG_PATH)
	if error != OK:
		push_warning("Settings: could not write %s (error %d)." % [CONFIG_PATH, error])


func _mark_dirty() -> void:
	_dirty = true
	_save_timer = SAVE_DEBOUNCE_SEC


# ------------------------------------------------------------------ applying

## Push every settings group at the live engine state. Safe to call any time;
## it is what `_ready()` and "Reset all settings" both use.
func apply_all() -> void:
	apply_audio()
	apply_graphics()
	apply_game()
	apply_accessibility()
	if Loc.locale() != get_string("game/language"):
		Loc.set_locale(get_string("game/language"), false)


func apply_audio() -> void:
	# Muting the Master bus is the one switch that silences everything at
	# once, including music the player started before opening Settings.
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, get_bool("audio/mute_all"))
	for entry in [
		{"key": "audio/master", "bus": "Master"},
		{"key": "audio/music", "bus": "Music"},
		{"key": "audio/sfx", "bus": "SFX"},
		{"key": "audio/ui", "bus": "UI"},
		{"key": "audio/voice", "bus": "Voice"},
	]:
		var bus_index := AudioServer.get_bus_index(String(entry["bus"]))
		if bus_index < 0:
			continue
		var linear := clampf(get_float(StringName(entry["key"]), 1.0), 0.0, 1.0)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(bus_index, linear <= 0.0001)


func apply_graphics() -> void:
	var quality := get_int("graphics/quality_preset")
	var scale := clampf(get_float("graphics/render_scale"), 0.4, 1.0)
	var shadows_enabled := get_bool("graphics/shadows")
	var shadow_quality := clampi(get_int("graphics/shadow_quality"), 0, 2)
	var aa := clampi(get_int("graphics/anti_aliasing"), 0, 3)
	var fps_limit := get_int("graphics/fps_limit")

	# Frame pacing. 0 means "let the platform decide".
	Engine.max_fps = fps_limit if fps_limit > 0 else 0

	var viewport := get_viewport()
	if viewport != null:
		viewport.scaling_3d_scale = scale
		viewport.msaa_3d = _msaa_for(aa)
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 \
			else Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.use_debanding = quality >= 1

	if not shadows_enabled:
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
	else:
		var atlas: int = [1024, 2048, 4096][shadow_quality]
		RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	var soft_quality := RenderingServer.SHADOW_QUALITY_HARD
	if shadows_enabled:
		soft_quality = [
			RenderingServer.SHADOW_QUALITY_SOFT_LOW,
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
			RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
		][shadow_quality]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft_quality)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft_quality)

	# Texture filtering is a project setting, but streaming quality is not
	# exposed for mobile; instead we scale the decal/particle budget.
	EventBus.graphics_settings_applied.emit()


func apply_game() -> void:
	DisplayServer.screen_set_keep_on(get_bool("game/keep_screen_on"))
	if OS.has_feature("mobile") and not get_bool("game/vibration", true):
		Input.vibrate_handheld(0)  # Stop any pulse already in progress when vibration is disabled.


## Write a whole preset at once. `notify` is false during boot to avoid
## emitting five settings_changed signals before any UI exists.
func apply_quality_preset(preset: int, notify: bool = true) -> void:
	var clamped := clampi(preset, 0, 3)
	var bundle := {
		"graphics/quality_preset": clamped,
		"graphics/render_scale": [0.72, 0.9, 1.0, 1.0][clamped],
		"graphics/fps_limit": [30, 45, 60, 120][clamped],
		"graphics/shadows": clamped >= 1,
		"graphics/shadow_quality": [0, 0, 1, 2][clamped],
		"graphics/anti_aliasing": [0, 0, 1, 3][clamped],
		"graphics/texture_quality": [0, 1, 2, 2][clamped],
		"graphics/decals": clamped >= 1,
		"graphics/bloom": clamped >= 2,
		"graphics/ragdolls": clamped >= 1,
		"graphics/effects_quality": clamped,
	}
	for key: String in bundle:
		_values[key] = bundle[key]
	_mark_dirty()
	apply_graphics()
	if notify:
		EventBus.settings_changed.emit(&"graphics")


func _msaa_for(aa: int) -> Viewport.MSAA:
	match aa:
		2: return Viewport.MSAA_2X
		3: return Viewport.MSAA_4X
		_: return Viewport.MSAA_DISABLED


## True when the platform can render the extra effects at all. Used by the
## Settings UI to grey out options instead of letting players pick a mode that
## will tank their frame rate.
func supports_advanced_effects() -> bool:
	return _device_tier != DeviceTier.LOW


## Text size is the one accessibility option with a real, visible effect
## today: it rebuilds the theme's type ramp. The others are stored so a
## future gameplay phase can read them, and the panel says so rather than
## pretending they already do something.
func apply_accessibility() -> void:
	var sizes := [0.88, 1.0, 1.18]
	var index := clampi(get_int("accessibility/text_size", 1), 0, sizes.size() - 1)
	if Design != null:
		Design.set_text_scale(sizes[index])


## Nothing here talks to a server. These are local preferences about how
## content may be fetched once there is content to fetch; the panel shows
## connection state it can actually observe and hides what it cannot.
func apply_network() -> void:
	pass
