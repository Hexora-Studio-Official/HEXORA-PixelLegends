class_name SettingsDialog
extends Control
## The settings panel, reachable from the entrance before sign-in.
##
## Six categories down one side, the active category's rows in a scroll on
## the other, and a footer with Reset / Cancel / Apply.
##
## Two ideas here are worth stating, because they decide most of the code.
##
## FIRST — what needs Apply. Graphics changes are staged; everything else
## lands immediately. The reason is recovery, not ceremony: a wrong
## resolution scale or anti-aliasing mode can leave a phone showing
## something the player cannot read their way out of, so those wait behind
## a button with a Cancel next to it. Language and audio are safe to undo
## by simply moving the control again, so they apply at once — which is
## what the specification asks for.
##
## SECOND — what is shown at all. This client has no backend, one locale and
## no gameplay yet. A settings row that stores a number nothing reads is
## worse than no row: it promises something the build does not do. So
## options with no live effect are rendered disabled and say why, and
## options that would need a server are not rendered at all. Nothing here
## invents a ping number, a server status or a support URL.
##
## Rows write through `Settings`, which applies and persists; the write is
## debounced before it reaches disk.

signal close_requested

enum Cat { GENERAL, GRAPHICS, AUDIO, ACCESSIBILITY, NETWORK, ABOUT }

const CATEGORIES: Array[StringName] = [
	&"settings.cat.general",
	&"settings.cat.graphics",
	&"settings.cat.audio",
	&"settings.cat.accessibility",
	&"settings.cat.network",
	&"settings.cat.about",
]

## Any key with one of these prefixes is staged until Apply is pressed.
const APPLY_PREFIXES: Array[String] = ["graphics/"]

## Keys this panel lets the player change, and therefore all Cancel restores. Cancel restores exactly these and
## nothing else, which is why account and progression keys are absent: they
## are not settings a player edits from here.
const EXPOSED_KEYS: Array[String] = [
	"game/remember_settings", "game/reduce_animations", "game/notifications",
	"game/confirm_exit", "game/show_fps", "game/vibration",
	"graphics/quality_preset", "graphics/render_scale", "graphics/fps_limit",
	"graphics/anti_aliasing", "graphics/shadows", "graphics/shadow_quality",
	"graphics/decals", "graphics/bloom", "graphics/motion_blur",
	"graphics/ragdolls", "graphics/effects_quality", "graphics/hud_scale",
	"graphics/battery_saver",
	"audio/master", "audio/music", "audio/sfx", "audio/ui", "audio/voice",
	"audio/mute_all", "audio/mute_in_background",
	"accessibility/text_size", "accessibility/ui_scale",
	"accessibility/high_contrast", "accessibility/colorblind_mode",
	"accessibility/reduce_shake", "accessibility/reduce_flashing",
	"accessibility/subtitles", "accessibility/subtitle_size",
	"network/wifi_only", "network/auto_download",
]

## Width of the category rail. Below this the panel switches to a strip
## above the content, because a rail plus readable rows does not fit.
const RAIL_WIDTH := 200.0

var _active: int = Cat.GENERAL
## Staged changes: settings key -> value not yet written.
var _pending: Dictionary = {}
## Values when the panel opened, so Cancel can put them back.
var _snapshot: Dictionary = {}

var _rail: VBoxContainer
var _rail_buttons: Array[Button] = []
var _content: VBoxContainer
var _apply_button: Button
var _cancel_button: Button
var _confirm_layer: Control


func _ready() -> void:
	_snapshot = _capture()
	_build()


## Every key this panel can write, and its value right now. Taken on open so
## Cancel has something to restore even for staged keys.
func _capture() -> Dictionary:
	var captured := {}
	for key in EXPOSED_KEYS:
		captured[key] = Settings.get_value(key)
	return captured




# ------------------------------------------------------------------- skeleton

func _build() -> void:
	var panel := UiKit.panel(&"GlassModalPanel")
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var column := UiKit.vbox(Design.SPACE_MD)
	panel.add_child(column)

	# ---- header -----------------------------------------------------------
	var header := UiKit.hbox(Design.SPACE_MD)
	header.add_child(UiKit.heading(Loc.t(&"settings.dialog.title")))
	header.add_child(UiKit.spacer())
	var close := UiKit.icon_button(&"close", Design.TEXT_MUTED, 20.0)
	close.custom_minimum_size = Vector2(Design.TOUCH_TARGET_MIN, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(close, func() -> void: request_close(), "back")
	header.add_child(close)
	column.add_child(header)
	column.add_child(UiKit.divider())

	# ---- body -------------------------------------------------------------
	var body := UiKit.hbox(Design.SPACE_MD)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_build_rail(body)

	var scroll := UiKit.scroll()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(480, 400)
	body.add_child(scroll)
	_content = UiKit.vbox(Design.SPACE_MD)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.prepare_scroll_content(_content)
	scroll.add_child(_content)

	# ---- footer -----------------------------------------------------------
	column.add_child(UiKit.divider())
	var footer := UiKit.hbox(Design.SPACE_SM)
	var reset := UiKit.button(Loc.t(&"settings.footer.reset"), &"DangerButton")
	reset.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(reset, _on_reset, "click")
	footer.add_child(reset)
	footer.add_child(UiKit.spacer())

	_cancel_button = UiKit.button(Loc.t(&"common.cancel"), &"GlassButton")
	_cancel_button.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(_cancel_button, _on_cancel, "back")
	footer.add_child(_cancel_button)

	_apply_button = UiKit.button(Loc.t(&"settings.footer.apply"), &"GlassPrimaryButton")
	_apply_button.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(_apply_button, _on_apply, "confirm")
	footer.add_child(_apply_button)
	column.add_child(footer)

	_render_content()
	_refresh_footer()


func _build_rail(parent: Container) -> void:
	_rail = UiKit.vbox(Design.SPACE_SM)
	_rail.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	parent.add_child(_rail)
	_rail_buttons.clear()
	for index in CATEGORIES.size():
		var button := UiKit.chip(Loc.t(CATEGORIES[index]), index == _active)
		button.custom_minimum_size = Vector2(RAIL_WIDTH, Design.TOUCH_TARGET_MIN)
		button.size_flags_horizontal = Control.SIZE_FILL
		var category := index
		UiKit.on_press(button, func() -> void: _select(category))
		_rail.add_child(button)
		_rail_buttons.append(button)


func _select(category: int) -> void:
	if category == _active:
		return
	_active = category
	for index in _rail_buttons.size():
		UiKit.set_chip_active(_rail_buttons[index], index == _active)
	_render_content()


# --------------------------------------------------------------------- footer

func _refresh_footer() -> void:
	var dirty := not _pending.is_empty()
	if _apply_button != null:
		_apply_button.disabled = not dirty
	if _cancel_button != null:
		_cancel_button.disabled = not dirty


func _on_apply() -> void:
	for key in _pending:
		Settings.set_value(key, _pending[key])
	_pending.clear()
	_snapshot = _capture()
	_render_content()
	_refresh_footer()
	Audio.play_ui("confirm")


func _on_cancel() -> void:
	for key in _pending:
		if _snapshot.has(key):
			Settings.set_value(key, _snapshot[key])
	_pending.clear()
	_render_content()
	_refresh_footer()
	Audio.play_ui("back")


func _on_reset() -> void:
	_confirm(Loc.t(&"settings.confirm.reset_title"),
		Loc.t(&"settings.confirm.reset_body"),
		Loc.t(&"settings.footer.reset"), func() -> void:
			Settings.reset_all()
			_pending.clear()
			_snapshot = _capture()
			_render_content()
			_refresh_footer()
	)


## Close, unless there is staged work — then ask first. Called by the close
## button and by Android back through the host screen.
func request_close() -> void:
	if _confirm_layer != null:
		return
	if _pending.is_empty():
		close_requested.emit()
		return
	_confirm(Loc.t(&"settings.confirm.discard_title"),
		Loc.t(&"settings.confirm.discard_body"),
		Loc.t(&"common.discard"), func() -> void:
			close_requested.emit()
	)


# ------------------------------------------------------------------ confirm

## A small sheet over this panel rather than a second modal: stacking two
## modal layers makes the dim rectangle darken twice and lets a stray tap
## close the wrong one.
func _confirm(title: String, body: String, action: String, on_yes: Callable) -> void:
	if _confirm_layer != null:
		return
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Design.BG.r, Design.BG.g, Design.BG.b, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(centre)

	var sheet := UiKit.panel(&"GlassModalPanel")
	sheet.custom_minimum_size = Vector2(420, 0)
	centre.add_child(sheet)
	var column := UiKit.vbox(Design.SPACE_MD)
	sheet.add_child(column)
	column.add_child(UiKit.subheading(title))
	column.add_child(UiKit.paragraph(body, 380.0))
	var row := UiKit.hbox(Design.SPACE_SM)
	var no := UiKit.button(Loc.t(&"common.cancel"), &"GlassButton")
	no.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(no, _dismiss_confirm, "back")
	row.add_child(no)
	var yes := UiKit.button(action, &"DangerButton")
	yes.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(yes, func() -> void:
		_dismiss_confirm()
		on_yes.call()
	, "click")
	row.add_child(yes)
	column.add_child(row)
	add_child(_confirm_layer)


func _dismiss_confirm() -> void:
	if _confirm_layer == null:
		return
	_confirm_layer.queue_free()
	_confirm_layer = null


# ------------------------------------------------------------------ writing

## Route a change: stage it if the key needs confirmation, write it now if it
## does not. Every row goes through here, which is what keeps the Apply
## button honest.
func _change(key: String, value: Variant) -> void:
	if _needs_apply(key):
		_pending[key] = value
		_refresh_footer()
		return
	# Immediate: nothing is staged, so Apply must stay disabled.
	Settings.set_value(key, value)


static func _needs_apply(key: String) -> bool:
	for prefix in APPLY_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false


## The value a control should show: the staged one if there is a staged one,
## otherwise what is stored.
func _shown(key: String) -> Variant:
	if _pending.has(key) and _pending[key] != null:
		return _pending[key]
	return Settings.get_value(key)


# --------------------------------------------------------------------- rows

func _render_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	match _active:
		Cat.GENERAL: _render_general()
		Cat.GRAPHICS: _render_graphics()
		Cat.AUDIO: _render_audio()
		Cat.ACCESSIBILITY: _render_accessibility()
		Cat.NETWORK: _render_network()
		Cat.ABOUT: _render_about()


func _render_general() -> void:
	var general := _card(&"settings.cat.general")
	general.add_child(_read_only_row(&"settings.general.language",
		Loc.t(&"settings.general.language.english"),
		&"settings.general.language.note"))
	general.add_child(_toggle_row(&"settings.general.remember", "game/remember_settings"))
	general.add_child(_toggle_row(&"settings.general.reduce_animations",
		"game/reduce_animations"))
	general.add_child(_toggle_row(&"settings.general.confirm_exit", "game/confirm_exit"))
	general.add_child(_toggle_row(&"settings.general.notifications",
		"game/notifications", &"settings.unavailable.note", true))
	general.add_child(_toggle_row(&"settings.general.performance_stats",
		"game/show_fps"))

	var danger := _card(&"settings.general.reset_card")
	danger.add_child(UiKit.paragraph(Loc.t(&"settings.general.reset_note"), 460.0))
	var reset := UiKit.button(Loc.t(&"settings.general.reset_all"), &"DangerButton")
	reset.custom_minimum_size = Vector2(240, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(reset, _on_reset, "click")
	danger.add_child(reset)


func _render_graphics() -> void:
	var tier_hint := "%s  ·  %s" % [
		Loc.t(&"settings.graphics.device_hint", {"tier": Settings.device_tier_label()}),
		Settings.device_name(),
	]
	var preset := _card(&"settings.graphics.quality")
	preset.add_child(UiKit.paragraph(tier_hint, 520.0, &"CaptionLabel"))
	preset.add_child(_option_row(&"settings.graphics.quality", "graphics/quality_preset", [
		{"value": 0, "key": &"settings.graphics.quality.low"},
		{"value": 1, "key": &"settings.graphics.quality.medium"},
		{"value": 2, "key": &"settings.graphics.quality.high"},
		{"value": 3, "key": &"settings.graphics.quality.ultra"},
	]))
	preset.add_child(UiKit.paragraph(Loc.t(&"settings.graphics.note_fps"), 520.0))

	var video := _card(&"settings.graphics.video")
	video.add_child(_slider_row(&"settings.graphics.resolution_scale",
		"graphics/render_scale", 0.5, 1.0, 0.05))
	video.add_child(_option_row(&"settings.graphics.fps", "graphics/fps_limit", [
		{"value": 0, "text": "Auto"},
		{"value": 30, "text": "30"},
		{"value": 45, "text": "45"},
		{"value": 60, "text": "60"},
		{"value": 90, "text": "90"},
		{"value": 120, "text": "120"},
	]))
	video.add_child(_option_row(&"settings.graphics.aa", "graphics/anti_aliasing", [
		{"value": 0, "key": &"settings.graphics.aa.off"},
		{"value": 1, "key": &"settings.graphics.aa.fxaa"},
		{"value": 2, "key": &"settings.graphics.aa.msaa2"},
		{"value": 3, "key": &"settings.graphics.aa.msaa4"},
	]))

	var detail := _card(&"settings.graphics.detail")
	detail.add_child(_toggle_row(&"settings.graphics.shadows", "graphics/shadows"))
	detail.add_child(_option_row(&"settings.graphics.shadow_quality",
		"graphics/shadow_quality", [
			{"value": 0, "key": &"settings.graphics.quality.low"},
			{"value": 1, "key": &"settings.graphics.quality.medium"},
			{"value": 2, "key": &"settings.graphics.quality.high"},
		]))
	detail.add_child(_option_row(&"settings.graphics.effects",
		"graphics/effects_quality", [
			{"value": 0, "key": &"settings.graphics.quality.low"},
			{"value": 1, "key": &"settings.graphics.quality.medium"},
			{"value": 2, "key": &"settings.graphics.quality.high"},
			{"value": 3, "key": &"settings.graphics.quality.ultra"},
		]))
	detail.add_child(_toggle_row(&"settings.graphics.bloom", "graphics/bloom"))
	detail.add_child(_toggle_row(&"settings.graphics.motion_blur", "graphics/motion_blur"))
	detail.add_child(_toggle_row(&"settings.graphics.decals", "graphics/decals"))
	detail.add_child(_toggle_row(&"settings.graphics.battery_saver",
		"graphics/battery_saver"))

	var restore := _card(&"settings.graphics.restore_card")
	restore.add_child(UiKit.paragraph(Loc.t(&"settings.graphics.restore_note"), 460.0))
	var button := UiKit.button(Loc.t(&"settings.graphics.restore"), &"OutlineButton")
	button.custom_minimum_size = Vector2(260, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(button, _on_reset_graphics, "click")
	restore.add_child(button)


func _on_reset_graphics() -> void:
	_confirm(Loc.t(&"settings.confirm.reset_title"),
		Loc.t(&"settings.graphics.restore_body"),
		Loc.t(&"settings.graphics.restore"), func() -> void:
			Settings.apply_quality_preset(Settings.device_tier())
			_pending.clear()
			_snapshot = _capture()
			_render_content()
			_refresh_footer()
	)


func _render_audio() -> void:
	var mix := _card(&"settings.audio.mix")
	for entry in [
		{"key": &"settings.audio.master", "setting": "audio/master"},
		{"key": &"settings.audio.music", "setting": "audio/music"},
		{"key": &"settings.audio.sfx", "setting": "audio/sfx"},
		{"key": &"settings.audio.ui", "setting": "audio/ui"},
		{"key": &"settings.audio.voice", "setting": "audio/voice"},
	]:
		mix.add_child(_slider_row(entry["key"], entry["setting"], 0.0, 1.0, 0.05))

	var switches := _card(&"settings.audio.switches")
	switches.add_child(_toggle_row(&"settings.audio.mute_all", "audio/mute_all"))
	switches.add_child(_toggle_row(&"settings.audio.muted_when_bg",
		"audio/mute_in_background"))
	switches.add_child(_toggle_row(&"settings.audio.vibration", "game/vibration"))


func _render_accessibility() -> void:
	var text := _card(&"settings.access.text_card")
	text.add_child(_option_row(&"settings.access.text_size",
		"accessibility/text_size", [
			{"value": 0, "key": &"settings.access.size.small"},
			{"value": 1, "key": &"settings.access.size.normal"},
			{"value": 2, "key": &"settings.access.size.large"},
		]))
	text.add_child(_slider_row(&"settings.access.ui_scale",
		"accessibility/ui_scale", 0.8, 1.3, 0.05))

	var subs := _card(&"settings.access.subtitles_card")
	subs.add_child(_toggle_row(&"settings.access.subtitles",
		"accessibility/subtitles", &"settings.unavailable.note", true))
	subs.add_child(_option_row(&"settings.access.subtitle_size",
		"accessibility/subtitle_size", [
			{"value": 0, "key": &"settings.access.size.small"},
			{"value": 1, "key": &"settings.access.size.medium"},
			{"value": 2, "key": &"settings.access.size.large"},
		], true))

	# These need gameplay to act on: there is no match, no team colour and no
	# screen effect in the client yet, so they are stored and shown as inert
	# rather than switched on as if they did something.
	var later := _card(&"settings.access.gameplay_card")
	later.add_child(UiKit.paragraph(Loc.t(&"settings.unavailable.note"), 460.0))
	later.add_child(_toggle_row(&"settings.access.high_contrast",
		"accessibility/high_contrast", &"", true))
	later.add_child(_option_row(&"settings.access.colorblind",
		"accessibility/colorblind_mode", [
			{"value": 0, "key": &"settings.access.cb.off"},
			{"value": 1, "key": &"settings.access.cb.protan"},
			{"value": 2, "key": &"settings.access.cb.deutan"},
			{"value": 3, "key": &"settings.access.cb.tritan"},
		], true))
	later.add_child(_toggle_row(&"settings.access.reduce_shake",
		"accessibility/reduce_shake", &"", true))
	later.add_child(_toggle_row(&"settings.access.reduce_flashing",
		"accessibility/reduce_flashing", &"", true))


func _render_network() -> void:
	var status := _card(&"settings.cat.network")
	# Honest: there is no reachability API in Godot and no backend to probe,
	# so the panel says what it knows instead of inventing a number.
	status.add_child(_read_only_row(&"settings.net.connection",
		Loc.t(&"settings.net.connection.unknown")))
	status.add_child(_read_only_row(&"settings.net.server",
		Loc.t(&"settings.net.server.unavailable")))

	var usage := _card(&"settings.net.usage_card")
	usage.add_child(_toggle_row(&"settings.net.wifi_only", "network/wifi_only"))
	usage.add_child(_toggle_row(&"settings.net.auto_download", "network/auto_download"))
	usage.add_child(UiKit.paragraph(Loc.t(&"settings.net.note"), 460.0))


func _render_about() -> void:
	var info := _card(&"settings.cat.about")
	# Every one of these reads returns a Variant, and this project treats
	# untyped inference as an error — so the casts are load-bearing, not
	# decoration.
	var version := String(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var build_id := String(ProjectSettings.get_setting("application/config/build", "dev"))
	var engine_version := String(Engine.get_version_info()["string"])
	info.add_child(_read_only_row(&"settings.about.version", String(version)))
	info.add_child(_read_only_row(&"settings.about.build", String(build_id)))
	info.add_child(_read_only_row(&"settings.about.engine", String(engine_version)))

	var legal := _card(&"settings.about.legal_card")
	legal.add_child(UiKit.paragraph(Loc.t(&"settings.about.legal_note"), 460.0))
	for key in [
		&"settings.about.terms", &"settings.about.privacy", &"settings.about.licenses",
		&"settings.about.support", &"settings.about.report", &"settings.about.credits",
		&"settings.about.updates",
	]:
		legal.add_child(_link_row(key))


# ---------------------------------------------------------------- row kinds

func _card(title_key: StringName) -> VBoxContainer:
	var holder := UiKit.panel(&"CardPanel")
	var column := UiKit.vbox(Design.SPACE_SM)
	holder.add_child(column)
	column.add_child(UiKit.subheading(Loc.t(title_key)))
	_content.add_child(holder)
	return column


func _row(label_key: StringName, control: Control, hint_key: StringName = &"",
		disabled: bool = false) -> HBoxContainer:
	var row := UiKit.hbox(Design.SPACE_LG)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var text_block := UiKit.vbox(Design.SPACE_XXS)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_child(UiKit.label(Loc.t(label_key), &"BodyLabel"))
	if hint_key != &"":
		text_block.add_child(UiKit.paragraph(Loc.t(hint_key), 420.0, &"CaptionLabel"))
	row.add_child(text_block)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	if disabled and control is Button:
		(control as Button).disabled = true
	return row


func _read_only_row(label_key: StringName, value: String,
		hint_key: StringName = &"") -> Control:
	return _row(label_key, UiKit.label(value, &"ValueLabel"), hint_key)


## A row that would open a URL. There are no URLs yet, so it is inert and
## says so — a dead link is worse than no link.
func _link_row(label_key: StringName) -> Control:
	var button := UiKit.button(Loc.t(label_key), &"GlassButton")
	button.custom_minimum_size = Vector2(240, Design.TOUCH_TARGET_MIN)
	button.disabled = true
	button.modulate.a = 0.55
	return _row(label_key, button, &"settings.unavailable.note")


func _toggle_row(label_key: StringName, settings_key: String,
		hint_key: StringName = &"", disabled: bool = false) -> Control:
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(_shown(settings_key))
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.disabled = disabled
	toggle.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
	toggle.toggled.connect(func(pressed: bool) -> void:
		_change(settings_key, pressed)
		Audio.play_ui("toggle_on" if pressed else "toggle_off")
		Controls.haptic(8)
	)
	return _row(label_key, toggle, hint_key, disabled)


func _slider_row(label_key: StringName, settings_key: String, minimum: float,
		maximum: float, step: float) -> Control:
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
	slider.value = float(_shown(settings_key))
	slider.custom_minimum_size = Vector2(220, Design.TOUCH_TARGET_MIN)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var format := func(value: float) -> String:
		return "%d%%" % int(round(value * 100.0))
	value_label.text = format.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = format.call(value)
		_change(settings_key, value)
	)
	holder.add_child(value_label)
	holder.add_child(slider)
	return _row(label_key, holder)


func _option_row(label_key: StringName, settings_key: String, options: Array,
		disabled: bool = false) -> Control:
	var wrap := options.size() > 3
	var holder: Container = HFlowContainer.new() if wrap else UiKit.hbox(Design.SPACE_SM)
	if holder is HFlowContainer:
		(holder as HFlowContainer).add_theme_constant_override("h_separation", Design.SPACE_SM)
		(holder as HFlowContainer).add_theme_constant_override("v_separation", Design.SPACE_SM)
	else:
		(holder as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END

	var chips: Array[Button] = []
	var current: Variant = _shown(settings_key)
	for option: Dictionary in options:
		var text := String(option.get("text", ""))
		if text.is_empty() and option.has("key"):
			text = Loc.t(StringName(option["key"]))
		var value: Variant = option["value"]
		var chip := UiKit.chip(text, _same(value, current))
		chip.disabled = disabled
		chip.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
		if disabled:
			chip.modulate.a = 0.55
		UiKit.on_press(chip, func() -> void:
			_change(settings_key, value)
			for index in chips.size():
				UiKit.set_chip_active(chips[index], _same(options[index]["value"], value))
			Audio.play_ui("toggle_on")
			Controls.haptic(8)
		)
		holder.add_child(chip)
		chips.append(chip)
	return _row(label_key, holder, &"", disabled)


static func _same(left: Variant, right: Variant) -> bool:
	if left is int and right is float:
		return float(left) == right
	if left is float and right is int:
		return left == float(right)
	return left == right
