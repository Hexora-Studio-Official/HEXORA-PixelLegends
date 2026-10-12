extends HexScreen
## First-run operator setup: callsign, home region, accent colour.
##
## Shown once per account, immediately after the first successful sign-in, and
## remembered by `game/first_run_complete`. The region chosen here becomes the
## default matchmaking region, so it is worth asking for before the player ever
## queues — guessing it from the IP would be wrong for anyone on a VPN and
## insulting for anyone who travels.

const CALLSIGN_MIN := 3
const CALLSIGN_MAX := 16
const HANDLE_PATTERN := "^[A-Za-z0-9_]+$"

var _callsign_field: LineEdit
var _hint_label: Label
var _enter_button: Button
var _region: int = GameTypes.Region.AUTO
var _palette_index: int = 0

var _region_chips: Array[Button] = []
var _swatches: Array[Control] = []
var _preview: AvatarView
var _preview_name_label: Label
var _regex := RegEx.new()


func build() -> void:
	_regex.compile(HANDLE_PATTERN)
	_region = Settings.get_int("game/region")
	_palette_index = absi(Session.profile.uid.hash()) % AvatarView.PALETTE.size()

	var screen_scroll := UiKit.scroll(true)
	screen_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(screen_scroll)

	if OS.has_feature("mobile"):
		# A single column avoids the desktop preview/form split becoming a narrow
		# two-up layout on phones. The outer scroll keeps every choice reachable.
		var stack := UiKit.vbox(Design.SPACE_MD)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen_scroll.add_child(stack)
		stack.add_child(_build_mobile_preview())
		stack.add_child(_build_form_column())
	else:
		var columns := UiKit.hbox(Design.SPACE_HUGE)
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columns.alignment = BoxContainer.ALIGNMENT_CENTER
		screen_scroll.add_child(columns)
		columns.add_child(_build_preview_column())
		columns.add_child(_build_form_column())

	_validate()


# ------------------------------------------------------------------- preview

func _build_preview_column() -> Control:
	var column := UiKit.vbox(Design.SPACE_LG)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_preview = AvatarView.new()
	_preview.custom_minimum_size = Vector2(168, 168)
	_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preview.palette_index = _palette_index
	_preview.initials = Session.profile.initials()
	_preview.show_level = true
	_preview.level = Session.profile.level
	column.add_child(_preview)

	_preview_name_label = UiKit.heading(Session.profile.display_name)
	column.add_child(_preview_name_label)

	var meta := UiKit.hbox(Design.SPACE_SM)
	meta.add_child(UiKit.pill(Loc.t(GameTypes.region_key(_region)), Design.TEAL, &"TealChipPanel"))
	if Session.profile.email.is_empty():
		meta.add_child(UiKit.pill(Loc.t(&"auth.guest.badge"), Design.WARNING))
	else:
		meta.add_child(UiKit.pill(Session.profile.email, Design.TEXT_MUTED))
	column.add_child(meta)

	column.add_child(UiKit.paragraph(Loc.t(&"auth.setup.subtitle"), 420.0))
	return column


func _build_mobile_preview() -> Control:
	# Keep the identity preview compact and aligned with its text, rather than
	# spending half the first screen on a decorative avatar.
	var row := UiKit.hbox(Design.SPACE_MD)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	_preview = AvatarView.new()
	_preview.custom_minimum_size = Vector2(72, 72)
	_preview.palette_index = _palette_index
	_preview.initials = Session.profile.initials()
	_preview.show_level = true
	_preview.level = Session.profile.level
	row.add_child(_preview)

	var identity := UiKit.vbox(Design.SPACE_XS)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_name_label = UiKit.subheading(Session.profile.display_name)
	_preview_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_preview_name_label)
	if Session.is_guest():
		identity.add_child(UiKit.pill(Loc.t(&"auth.guest.badge"), Design.WARNING))
	else:
		identity.add_child(UiKit.pill(
			Loc.t(GameTypes.region_key(_region)), Design.TEAL, &"TealChipPanel"))
	row.add_child(identity)
	return row


# ---------------------------------------------------------------------- form

func _build_form_column() -> Control:
	var card := UiKit.panel(&"CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var column := UiKit.vbox(Design.SPACE_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(column)

	column.add_child(UiKit.heading(Loc.t(&"auth.setup.title")))

	# ---- callsign ----------------------------------------------------------
	var callsign_block := UiKit.vbox(Design.SPACE_XS)
	callsign_block.add_child(UiKit.label(Loc.t(&"auth.setup.callsign"), &"SectionLabel"))
	_callsign_field = LineEdit.new()
	_callsign_field.theme_type_variation = &"HexLineEdit"
	_callsign_field.text = Session.profile.display_name
	_callsign_field.placeholder_text = Loc.t(&"auth.setup.callsign_hint")
	_callsign_field.max_length = CALLSIGN_MAX
	_callsign_field.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
	_callsign_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_callsign_field.text_changed.connect(_on_callsign_changed)
	_callsign_field.text_submitted.connect(func(_text: String) -> void: _on_enter_pressed())
	callsign_block.add_child(_callsign_field)
	_hint_label = UiKit.paragraph(Loc.t(&"auth.setup.callsign_hint"), 520.0, &"CaptionLabel")
	callsign_block.add_child(_hint_label)
	column.add_child(callsign_block)

	# ---- region ------------------------------------------------------------
	var region_block := UiKit.vbox(Design.SPACE_XS)
	region_block.add_child(UiKit.label(Loc.t(&"auth.setup.region"), &"SectionLabel"))
	var region_row := HFlowContainer.new()
	region_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_row.add_theme_constant_override("h_separation", Design.SPACE_SM)
	region_row.add_theme_constant_override("v_separation", Design.SPACE_SM)
	_region_chips.clear()
	for region in GameTypes.selectable_regions():
		var chip := UiKit.chip(Loc.t(GameTypes.region_key(region)), region == _region)
		var captured := region
		UiKit.on_press(chip, func() -> void: _on_region_selected(captured))
		region_row.add_child(chip)
		_region_chips.append(chip)
	region_block.add_child(region_row)
	region_block.add_child(UiKit.paragraph(Loc.t(&"auth.setup.region_hint"), 520.0, &"CaptionLabel"))
	column.add_child(region_block)

	# ---- accent colour -----------------------------------------------------
	var colour_block := UiKit.vbox(Design.SPACE_XS)
	colour_block.add_child(UiKit.label(Loc.t(&"auth.setup.avatar"), &"SectionLabel"))
	var swatch_row := HFlowContainer.new()
	swatch_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch_row.add_theme_constant_override("h_separation", Design.SPACE_SM)
	swatch_row.add_theme_constant_override("v_separation", Design.SPACE_SM)
	_swatches.clear()
	for index in AvatarView.PALETTE.size():
		var swatch := _build_swatch(index)
		swatch_row.add_child(swatch)
		_swatches.append(swatch)
	colour_block.add_child(swatch_row)
	column.add_child(colour_block)

	column.add_child(UiKit.divider())

	_enter_button = UiKit.button(Loc.t(&"auth.setup.enter"), &"PrimaryButton", &"bolt")
	_enter_button.custom_minimum_size = Vector2(0, 58)
	UiKit.on_press(_enter_button, _on_enter_pressed)
	column.add_child(_enter_button)

	if Session.is_guest():
		column.add_child(UiKit.paragraph(Loc.t(&"auth.guest.upgrade"), 520.0, &"WarningLabel"))
	return card


## A hexagonal swatch that mirrors the avatar, so the choice is what the player
## actually gets rather than an abstract colour chip.
func _build_swatch(index: int) -> Control:
	var swatch := _Swatch.new()
	swatch.custom_minimum_size = Vector2(46, 46)
	swatch.palette_index = index
	swatch.selected = index == _palette_index
	swatch.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_on_colour_selected(index)
	)
	return swatch


# ------------------------------------------------------------------- actions

func _on_callsign_changed(_text: String) -> void:
	# Live preview: the avatar initials and the preview name follow what is
	# being typed, which makes the screen feel like it is listening.
	var cleaned := _callsign_field.text.strip_edges()
	var preview := PlayerProfile.new()
	preview.display_name = cleaned
	_preview.initials = preview.initials()
	if _preview_name_label != null:
		_preview_name_label.text = cleaned if not cleaned.is_empty() else "—"
	_validate()


func _on_region_selected(region: int) -> void:
	_region = region
	for index in _region_chips.size():
		UiKit.set_chip_active(_region_chips[index],
			GameTypes.selectable_regions()[index] == region)
	Audio.play_ui("toggle_on")


func _on_colour_selected(index: int) -> void:
	_palette_index = index
	for position in _swatches.size():
		(_swatches[position] as _Swatch).selected = position == index
		(_swatches[position] as _Swatch).queue_redraw()
	_preview.palette_index = index
	Audio.play_ui("click")


## Returns "" when the value is acceptable, otherwise a human-readable reason.
func _validation_error(callsign: String) -> String:
	if callsign.length() < CALLSIGN_MIN or callsign.length() > CALLSIGN_MAX:
		return Loc.t(&"auth.setup.callsign_hint")
	if _regex.search(callsign) == null:
		return Loc.t(&"auth.setup.callsign_hint")
	return ""


func _validate() -> void:
	var callsign := _callsign_field.text.strip_edges()
	var error := _validation_error(callsign)
	var valid := error.is_empty()
	if _enter_button != null:
		_enter_button.disabled = not valid
	if _hint_label != null:
		_hint_label.text = Loc.t(&"auth.setup.callsign_hint") if valid else error
		_hint_label.add_theme_color_override("font_color",
			Design.TEXT_MUTED if valid else Design.DANGER)


func _on_enter_pressed() -> void:
	var callsign := _callsign_field.text.strip_edges()
	if not _validation_error(callsign).is_empty():
		Audio.play_ui("error")
		return

	Settings.set_value("game/region", _region)
	Settings.set_value("game/first_run_complete", true)
	Session.update_profile({
		"display_name": callsign,
		"region": _region,
		"tutorial_complete": false,
	})

	Audio.play_ui("confirm")
	Router.clear_history()
	Router.goto(&"menu")


func on_back_requested() -> void:
	# Backing out before setup completes is allowed; it just means the question
	# is asked again on the next launch.
	Router.goto(&"menu")


## Hexagonal colour swatch. Its own class because it needs both a custom draw
## and a hit area.
class _Swatch extends Control:
	var palette_index: int = 0:
		set(value):
			palette_index = value
			queue_redraw()
	var selected: bool = false:
		set(value):
			selected = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var centre := size * 0.5
		var radius := side * 0.42
		var accent := AvatarView.color_for_index(palette_index)
		var hexagon := PackedVector2Array()
		for corner in 6:
			var angle := PI / 3.0 * float(corner) - PI / 2.0
			hexagon.append(centre + Vector2(cos(angle), sin(angle)) * radius)

		draw_colored_polygon(hexagon, Color(accent.r, accent.g, accent.b, 0.85))
		var outline := hexagon.duplicate()
		outline.append(hexagon[0])
		if selected:
			draw_polyline(outline, Design.TEXT, 3.0, true)
		else:
			draw_polyline(outline, Color(accent.r, accent.g, accent.b, 0.35), 1.5, true)
