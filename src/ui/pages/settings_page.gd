class_name SettingsPage
extends MenuPage
## Device preferences in three tabs: game, graphics and audio.
##
## The page is shown in a modal on the entrance and battle hub, so preferences
## remain reachable before and after local guest sign-in. Each visible row
## writes directly to `Settings`, which applies and persists the change.

enum Tab { GAME, GRAPHICS, AUDIO }

const TAB_KEYS: Array[StringName] = [
	&"settings.tab.game", &"settings.tab.graphics", &"settings.tab.audio",
]

var active_tab: int = Tab.GAME

var _tab_row: HBoxContainer
var _tab_chips: Array[Button] = []


func build() -> void:
	body.add_child(header(&"settings.title", &"settings.subtitle"))

	# ---- tab strip ---------------------------------------------------------
	_tab_row = UiKit.hbox(Design.SPACE_SM)
	_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_tab_row)
	_tab_chips.clear()
	for index in TAB_KEYS.size():
		var chip := UiKit.chip(Loc.t(TAB_KEYS[index]), index == active_tab)
		var tab_index := index
		UiKit.on_press(chip, func() -> void: _select_tab(tab_index))
		_tab_row.add_child(chip)
		_tab_chips.append(chip)
	body.add_child(UiKit.divider())

	match active_tab:
		Tab.GAME: _build_game()
		Tab.GRAPHICS: _build_graphics()
		Tab.AUDIO: _build_audio()


func _select_tab(index: int) -> void:
	if index == active_tab:
		return
	active_tab = index
	# Rebuild only the page body: the tab strip stays exactly as it is, so the
	# chips do not flicker on every tap.
	rebuild()


# ------------------------------------------------------------------ game tab

func _build_game() -> void:
	var general := card(&"settings.tab.game")
	general.add_child(_toggle_row(&"settings.show_ping", "game/show_ping"))
	general.add_child(_toggle_row(&"settings.show_fps", "game/show_fps"))
	general.add_child(_toggle_row(&"settings.vibration", "game/vibration"))
	general.add_child(_toggle_row(&"settings.keep_screen_on", "game/keep_screen_on"))
	general.add_child(_toggle_row(&"settings.streamer_mode", "game/streamer_mode"))


# -------------------------------------------------------------- graphics tab

func _build_graphics() -> void:
	var tier_hint := "%s  ·  %s" % [
		Loc.t(&"settings.graphics.device_hint", {"tier": Settings.device_tier_label()}),
		Settings.device_name(),
	]
	var preset := card(&"settings.graphics.quality")
	preset.add_child(UiKit.paragraph(tier_hint, 720.0, &"CaptionLabel"))
	preset.add_child(_custom_row(&"settings.graphics.quality", _build_preset_chips()))
	preset.add_child(UiKit.paragraph(Loc.t(&"settings.graphics.note_fps"), 720.0))

	var video := card(&"settings.tab.graphics")
	video.add_child(_slider_row(&"settings.graphics.resolution_scale", "graphics/render_scale",
		0.5, 1.0, 0.05, "percent"))
	video.add_child(_slider_row(&"settings.graphics.hud_scale", "graphics/hud_scale",
		0.75, 1.4, 0.05, "percent"))
	video.add_child(_option_row(&"settings.graphics.fps", "graphics/fps_limit",
		[
			{"value": 0, "text": Loc.t(&"common.none")},
			{"value": 30, "text": "30"},
			{"value": 45, "text": "45"},
			{"value": 60, "text": "60"},
			{"value": 90, "text": "90"},
			{"value": 120, "text": "120"},
		], &""))
	video.add_child(_option_row(&"settings.graphics.aa", "graphics/anti_aliasing",
		[
			{"value": 0, "key": &"settings.graphics.aa.off"},
			{"value": 1, "key": &"settings.graphics.aa.fxaa"},
			{"value": 2, "key": &"settings.graphics.aa.msaa2"},
			{"value": 3, "key": &"settings.graphics.aa.msaa4"},
		], &""))
	video.add_child(_toggle_row(&"settings.graphics.shadows", "graphics/shadows"))
	video.add_child(_option_row(&"settings.graphics.shadow_quality", "graphics/shadow_quality",
		[
			{"value": 0, "text": Loc.t(&"settings.graphics.quality.low")},
			{"value": 1, "text": Loc.t(&"settings.graphics.quality.medium")},
			{"value": 2, "text": Loc.t(&"settings.graphics.quality.high")},
		], &""))
	video.add_child(_toggle_row(&"settings.graphics.decals", "graphics/decals"))
	video.add_child(_toggle_row(&"settings.graphics.bloom", "graphics/bloom"))
	video.add_child(_toggle_row(&"settings.graphics.ragdolls", "graphics/ragdolls"))


func _build_preset_chips() -> HBoxContainer:
	var row := UiKit.hbox(Design.SPACE_SM)
	var current := Settings.get_int("graphics/quality_preset")
	var keys: Array[StringName] = [
		&"settings.graphics.quality.low", &"settings.graphics.quality.medium",
		&"settings.graphics.quality.high", &"settings.graphics.quality.ultra",
	]
	var chips: Array[Button] = []
	for index in keys.size():
		var chip := UiKit.chip(Loc.t(keys[index]), index == current)
		var preset := index
		UiKit.on_press(chip, func() -> void:
			Settings.apply_quality_preset(preset)
			for other in chips.size():
				UiKit.set_chip_active(chips[other], other == preset)
			Audio.play_ui("toggle_on")
		)
		row.add_child(chip)
		chips.append(chip)
	return row


# ----------------------------------------------------------------- audio tab

func _build_audio() -> void:
	var mix := card(&"settings.tab.audio")
	for entry in [
		{"key": &"settings.audio.master", "setting": "audio/master"},
		{"key": &"settings.audio.music", "setting": "audio/music"},
		{"key": &"settings.audio.sfx", "setting": "audio/sfx"},
		{"key": &"settings.audio.ui", "setting": "audio/ui"},
		{"key": &"settings.audio.voice", "setting": "audio/voice"},
	]:
		mix.add_child(_slider_row(entry["key"], entry["setting"], 0.0, 1.0, 0.05, "percent"))

	var test := UiKit.button(Loc.t(&"settings.audio.test"), &"OutlineButton")
	UiKit.on_press(test, func() -> void:
		Audio.preview_cue("confirm")
		Audio.play_music(Audio.TRACK_MENU)
	)
	mix.add_child(test)

	var voice := card(&"settings.audio.voice")
	voice.add_child(_toggle_row(&"settings.audio.mic", "audio/mic_enabled"))
	voice.add_child(_toggle_row(&"settings.audio.mic_push", "audio/push_to_talk"))
	voice.add_child(_toggle_row(&"settings.audio.muted_when_bg", "audio/mute_in_background"))


# -------------------------------------------------------------- controls tab

func _build_controls() -> void:
	var scheme := card(&"settings.tab.controls")
	scheme.add_child(_option_row(&"settings.controls.preset", "controls/preset",
		[
			{"value": 0, "key": &"settings.controls.preset.mobile"},
			{"value": 1, "key": &"settings.controls.preset.mobile3"},
			{"value": 2, "key": &"settings.controls.preset.gamepad"},
			{"value": 3, "key": &"settings.controls.preset.keyboard"},
		], &""))

	var aim := card(&"menu.section.combat")
	aim.add_child(_slider_row(&"settings.controls.sensitivity", "controls/sensitivity",
		0.0, 1.0, 0.01, "percent"))
	aim.add_child(_slider_row(&"settings.controls.ads_sensitivity", "controls/ads_sensitivity",
		0.2, 1.6, 0.05, "percent"))
	aim.add_child(_toggle_row(&"settings.controls.invert_y", "controls/invert_y"))
	aim.add_child(_toggle_row(&"settings.controls.auto_sprint", "controls/auto_sprint"))
	aim.add_child(_toggle_row(&"settings.controls.tap_to_fire", "controls/tap_to_fire"))
	aim.add_child(_toggle_row(&"settings.controls.gyro", "controls/gyro_enabled",
		&"settings.controls.gyro.hint"))

	var hud := card(&"settings.controls.hud_layout")
	hud.add_child(UiKit.paragraph(Loc.t(&"settings.controls.touch_hint"), 720.0))
	hud.add_child(_slider_row(&"settings.controls.button_scale", "controls/button_scale",
		0.7, 1.5, 0.05, "percent"))
	hud.add_child(_slider_row(&"settings.controls.button_opacity", "controls/button_opacity",
		0.3, 1.0, 0.05, "percent"))
	hud.add_child(_toggle_row(&"settings.controls.left_handed", "controls/left_handed"))
	var reset := UiKit.button(Loc.t(&"settings.controls.reset_layout"), &"OutlineButton")
	UiKit.on_press(reset, func() -> void:
		Settings.set_value("controls/hud_layout", {})
		EventBus.toast_requested.emit(Loc.t(&"toast.settings_saved"), &"success")
	)
	hud.add_child(reset)


# ------------------------------------------------------------- developer tab

func _build_developer() -> void:
	var card_node := card(&"settings.dev.title")
	card_node.add_child(UiKit.paragraph(Loc.t(&"settings.dev.warning"), 720.0, &"WarningLabel"))

	card_node.add_child(_text_row(&"settings.dev.api_base", "dev/api_base_url",
		"https://api.example.com"))
	card_node.add_child(_text_row(&"settings.dev.google_client_id", "dev/google_client_id",
		"1234567890-abcdef.apps.googleusercontent.com"))
	card_node.add_child(_text_row(&"settings.dev.google_secret", "dev/google_client_secret",
		"GOCSPX-…"))
	card_node.add_child(UiKit.paragraph(Loc.t(&"settings.dev.google_secret.hint"), 720.0,
		&"CaptionLabel"))
	card_node.add_child(UiKit.key_value(
		Loc.t(&"settings.dev.redirect_uri"), Auth.expected_redirect_uri(), Design.TEAL))
	card_node.add_child(UiKit.paragraph(Loc.t(&"settings.dev.google_client_id.hint"), 720.0))
	card_node.add_child(UiKit.paragraph(Loc.t(&"settings.dev.google_client_id.android"), 720.0))

	# One-tap copy of the redirect URI: this value has to be pasted into the
	# Google Cloud Console, and a typo there costs an hour.
	var copy := UiKit.button(Loc.t(&"common.copy"), &"OutlineButton", &"copy")
	UiKit.on_press(copy, func() -> void:
		UiKit.copy_to_clipboard(Auth.expected_redirect_uri(),
			Loc.t(&"settings.dev.redirect_uri"))
	)
	card_node.add_child(copy)

	var dev := card(&"settings.tab.developer")
	dev.add_child(_toggle_row(&"settings.dev.mock_rooms", "dev/seed_mock_data"))
	dev.add_child(_int_slider_row(&"settings.dev.simulate_latency", "dev/simulated_latency_ms",
		0, 600, 25))

	var actions := UiKit.hbox(Design.SPACE_SM)
	var reset_settings := UiKit.button(Loc.t(&"settings.dev.reset_settings"), &"DangerButton")
	UiKit.on_press(reset_settings, func() -> void:
		Settings.reset_all()
		EventBus.toast_requested.emit(Loc.t(&"settings.dev.reset_settings.done"), &"success")
		rebuild()
	)
	actions.add_child(reset_settings)
	if Auth.is_signed_in():
		var sign_out := UiKit.button(Loc.t(&"auth.signout"), &"OutlineButton")
		UiKit.on_press(sign_out, func() -> void:
			Auth.sign_out()
			Router.clear_history()
			Router.goto(&"boot")
		)
		actions.add_child(sign_out)
	dev.add_child(actions)


# ------------------------------------------------------------------ row kinds

## Label on the leading side, control on the trailing side.
func _row(label_key: StringName, control: Control, hint_key: StringName = &"") -> VBoxContainer:
	var column := UiKit.vbox(Design.SPACE_XS)
	var row := UiKit.hbox(Design.SPACE_LG)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var text_block := UiKit.vbox(Design.SPACE_XXS)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_child(UiKit.label(Loc.t(label_key), &"BodyLabel"))
	if hint_key != &"":
		text_block.add_child(UiKit.paragraph(Loc.t(hint_key), 620.0, &"CaptionLabel"))
	row.add_child(text_block)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)

	column.add_child(row)
	column.add_child(UiKit.divider(Color(Design.LINE.r, Design.LINE.g, Design.LINE.b, 0.5)))
	return column


func _toggle_row(label_key: StringName, settings_key: String, hint_key: StringName = &"") -> Control:
	var toggle := CheckButton.new()
	toggle.button_pressed = Settings.get_bool(settings_key)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(pressed: bool) -> void:
		Settings.set_value(settings_key, pressed)
		Audio.play_ui("toggle_on" if pressed else "toggle_off")
		Controls.haptic(8)
	)
	return _row(label_key, toggle, hint_key)


func _slider_row(label_key: StringName, settings_key: String, minimum: float, maximum: float,
		step: float, display: String = "percent") -> Control:
	var holder := UiKit.hbox(Design.SPACE_MD)
	holder.alignment = BoxContainer.ALIGNMENT_END

	var value_label := UiKit.label("", &"NumericLabel")
	value_label.custom_minimum_size = Vector2(76, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var slider := HSlider.new()
	slider.theme_type_variation = &"HexSlider"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = Settings.get_float(settings_key, minimum)
	slider.custom_minimum_size = Vector2(240, Design.TOUCH_TARGET_MIN)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var format := func(value: float) -> String:
		if display != "percent":
			return str(int(round(value)))
		var percent := int(round(value * 100.0))
		return "%d%%" % percent

	value_label.text = format.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = format.call(value)
		# Write on every change: Settings applies immediately, and the write is
		# debounced before it hits disk.
		Settings.set_value(settings_key, value)
	)

	holder.add_child(value_label)
	holder.add_child(slider)
	return _row(label_key, holder)


func _int_slider_row(label_key: StringName, settings_key: String,
		minimum: int, maximum: int, step: int) -> Control:
	var holder := UiKit.hbox(Design.SPACE_MD)
	holder.alignment = BoxContainer.ALIGNMENT_END

	var value_label := UiKit.label("", &"NumericLabel")
	value_label.custom_minimum_size = Vector2(76, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var slider := HSlider.new()
	slider.theme_type_variation = &"HexSlider"
	slider.min_value = float(minimum)
	slider.max_value = float(maximum)
	slider.step = float(step)
	slider.value = float(Settings.get_int(settings_key))
	slider.custom_minimum_size = Vector2(240, Design.TOUCH_TARGET_MIN)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.text = str(int(slider.value))

	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = Loc.t(&"common.ping_ms", {"ms": int(value)}) if minimum > 0 \
			else str(int(value))
		Settings.set_value(settings_key, int(value))
	)
	if minimum > 0:
		value_label.text = Loc.t(&"common.ping_ms", {"ms": int(slider.value)})

	holder.add_child(value_label)
	holder.add_child(slider)
	return _row(label_key, holder)


## Mutually exclusive chips for a small set of values.
func _option_row(label_key: StringName, settings_key: String, options: Array,
		hint_key: StringName = &"") -> Control:
	# More than three choices would overflow a phone in landscape, so those
	# get a wrapping flow container; short sets stay on one line.
	var wrap := options.size() > 3
	var holder: Container = HFlowContainer.new() if wrap else UiKit.hbox(Design.SPACE_SM)
	if holder is HFlowContainer:
		(holder as HFlowContainer).add_theme_constant_override("h_separation", Design.SPACE_SM)
		(holder as HFlowContainer).add_theme_constant_override("v_separation", Design.SPACE_SM)
	else:
		(holder as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END

	var chips: Array[Button] = []
	var current: Variant = Settings.get_value(settings_key)
	for option: Dictionary in options:
		var text := String(option.get("text", ""))
		if text.is_empty() and option.has("key"):
			text = Loc.t(StringName(option["key"]))
		var value: Variant = option["value"]
		var chip := UiKit.chip(text, _values_equal(value, current))
		UiKit.on_press(chip, func() -> void:
			Settings.set_value(settings_key, value)
			for index in chips.size():
				UiKit.set_chip_active(chips[index],
					_values_equal(options[index]["value"], value))
			Audio.play_ui("toggle_on")
			Controls.haptic(8)
		)
		holder.add_child(chip)
		chips.append(chip)
	return _row(label_key, holder, hint_key)


## Free-form container row, for controls built by the caller.
func _custom_row(label_key: StringName, control: Control) -> Control:
	return _row(label_key, control)


func _text_row(label_key: StringName, settings_key: String, placeholder: String) -> Control:
	var field := LineEdit.new()
	field.theme_type_variation = &"HexLineEdit"
	field.placeholder_text = placeholder
	field.text = Settings.get_string(settings_key)
	field.custom_minimum_size = Vector2(340, Design.TOUCH_TARGET_MIN)
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Committing on focus loss as well as on Enter: on a phone the keyboard is
	# usually dismissed by tapping away, which is exactly when this fires.
	field.text_submitted.connect(func(text: String) -> void: _commit_text(settings_key, text))
	field.focus_exited.connect(func() -> void: _commit_text(settings_key, field.text))
	return _row(label_key, field)


func _commit_text(settings_key: String, text: String) -> void:
	var cleaned := text.strip_edges()
	if Settings.get_string(settings_key) == cleaned:
		return
	Settings.set_value(settings_key, cleaned)
	EventBus.toast_requested.emit(Loc.t(&"settings.dev.saved"), &"success")


static func _values_equal(left: Variant, right: Variant) -> bool:
	if left is int and right is float:
		return float(left) == right
	if left is float and right is int:
		return left == float(right)
	return left == right
