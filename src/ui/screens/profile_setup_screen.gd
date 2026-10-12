extends HexScreen
## Two-step operator setup. Each step fits in a centered card so the player
## never has to hunt for a clipped action or fight a nested scroll container.

enum Step { IDENTITY, COLOUR }

const CALLSIGN_MIN := 3
const CALLSIGN_MAX := 16
const HANDLE_PATTERN := "^[A-Za-z0-9_]+$"

var _step: int = Step.IDENTITY
var _initialized: bool = false
var _callsign := ""
var _callsign_field: LineEdit
var _hint_label: Label
var _continue_button: Button
var _region: int = GameTypes.Region.AUTO
var _palette_index: int = 0
var _region_chips: Array[Button] = []
var _region_values: Array[int] = []
var _swatches: Array[Control] = []
var _preview: AvatarView
var _preview_name_label: Label
var _regex := RegEx.new()


func build() -> void:
	_regex.compile(HANDLE_PATTERN)
	if not _initialized:
		_callsign = Session.profile.display_name
		_region = Settings.get_int("game/region")
		_palette_index = Session.profile.avatar_color if Session.profile.avatar_color >= 0 \
			else absi(Session.profile.uid.hash()) % AvatarView.PALETTE.size()
		_initialized = true

	_callsign_field = null
	_hint_label = null
	_continue_button = null
	_preview = null
	_preview_name_label = null

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)

	var viewport_width := get_viewport_rect().size.x
	var card_width := minf(920.0, maxf(360.0, viewport_width - Design.SPACE_XXL * 2.0))
	var card := UiKit.panel(&"CardPanel")
	card.custom_minimum_size = Vector2(card_width, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(card)

	var column := UiKit.vbox(Design.SPACE_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(column)
	column.add_child(_build_brand_header())
	column.add_child(UiKit.progress(&"ThinBar", 0.5 if _step == Step.IDENTITY else 1.0, 8))

	if _step == Step.IDENTITY:
		column.add_child(_build_identity_step())
	else:
		column.add_child(_build_colour_step())

	_validate()


func _build_brand_header() -> Control:
	var row := UiKit.hbox(Design.SPACE_MD)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var mark := PixelFieldMark.new()
	mark.custom_minimum_size = Vector2(60, 60)
	row.add_child(mark)

	var identity := UiKit.vbox(Design.SPACE_XXS)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(UiKit.subheading(Loc.t(&"app.name")))
	identity.add_child(UiKit.caption(Loc.t(&"auth.setup.title")))
	row.add_child(identity)
	return row


func _build_identity_step() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := UiKit.subheading(Loc.t(&"auth.setup.callsign"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_callsign_field = LineEdit.new()
	_callsign_field.theme_type_variation = &"HexLineEdit"
	_callsign_field.text = _callsign
	_callsign_field.placeholder_text = Loc.t(&"auth.setup.callsign_hint")
	_callsign_field.max_length = CALLSIGN_MAX
	_callsign_field.custom_minimum_size = Vector2(0, 60)
	_callsign_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_callsign_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callsign_field.text_changed.connect(_on_callsign_changed)
	column.add_child(_callsign_field)

	_hint_label = UiKit.label(Loc.t(&"auth.setup.callsign_hint"), &"BodyMutedLabel")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint_label)

	var region_label := UiKit.label(Loc.t(&"auth.setup.region"), &"SectionLabel")
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(region_label)

	var region_grid := UiKit.grid(3, Design.SPACE_SM)
	region_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_region_chips.clear()
	_region_values.clear()
	for region in GameTypes.selectable_regions():
		var chip := UiKit.chip(Loc.t(GameTypes.region_key(region)), region == _region)
		chip.custom_minimum_size = Vector2(0, 60)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_region_values.append(region)
		var captured_region := region
		UiKit.on_press(chip, func() -> void: _on_region_selected(captured_region))
		region_grid.add_child(chip)
		_region_chips.append(chip)
	column.add_child(region_grid)

	_continue_button = UiKit.button(Loc.t(&"common.next"), &"PrimaryButton", &"chevron")
	_continue_button.custom_minimum_size = Vector2(0, 64)
	_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(_continue_button, _continue_to_colour, "confirm")
	column.add_child(_continue_button)
	return column


func _build_colour_step() -> Control:
	var column := UiKit.vbox(Design.SPACE_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := UiKit.subheading(Loc.t(&"auth.setup.avatar"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var identity_row := UiKit.hbox(Design.SPACE_MD)
	identity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview = AvatarView.new()
	_preview.custom_minimum_size = Vector2(88, 88)
	_preview.palette_index = _palette_index
	var profile_preview := PlayerProfile.new()
	profile_preview.display_name = _callsign
	_preview.initials = profile_preview.initials()
	_preview.show_level = true
	_preview.level = Session.profile.level
	identity_row.add_child(_preview)

	var identity := UiKit.vbox(Design.SPACE_XS)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_name_label = UiKit.subheading(_callsign)
	identity.add_child(_preview_name_label)
	identity.add_child(UiKit.pill(Loc.t(GameTypes.region_key(_region)), Design.TEAL, &"TealChipPanel"))
	identity_row.add_child(identity)
	column.add_child(identity_row)

	var palette_label := UiKit.label(Loc.t(&"auth.setup.avatar"), &"SectionLabel")
	palette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(palette_label)

	var palette_center := CenterContainer.new()
	palette_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var palette_grid := UiKit.grid(4, Design.SPACE_SM)
	palette_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_swatches.clear()
	for index in AvatarView.PALETTE.size():
		var swatch := _build_swatch(index)
		palette_grid.add_child(swatch)
		_swatches.append(swatch)
	palette_center.add_child(palette_grid)
	column.add_child(palette_center)

	var actions := UiKit.hbox(Design.SPACE_MD)
	var enter := UiKit.button(Loc.t(&"auth.setup.enter"), &"PrimaryButton", &"check")
	enter.custom_minimum_size = Vector2(0, 64)
	enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(enter, _on_enter_pressed, "confirm")

	var back := UiKit.button(Loc.t(&"common.back"), &"OutlineButton", &"chevron")
	back.custom_minimum_size = Vector2(0, 64)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(back, _back_to_identity, "back")

	# Add the primary action first so it appears on the leading (right) side in RTL.
	actions.add_child(enter)
	actions.add_child(back)
	column.add_child(actions)
	return column


func _build_swatch(index: int) -> Control:
	var swatch := _Swatch.new()
	swatch.custom_minimum_size = Vector2(72, 72)
	swatch.palette_index = index
	swatch.selected = index == _palette_index
	swatch.tooltip_text = Loc.t(&"auth.setup.avatar")
	swatch.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_on_colour_selected(index)
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_on_colour_selected(index)
	)
	return swatch


func _on_callsign_changed(_text: String) -> void:
	_callsign = _callsign_field.text.strip_edges()
	if _preview != null:
		var preview := PlayerProfile.new()
		preview.display_name = _callsign
		_preview.initials = preview.initials()
		if _preview_name_label != null:
			_preview_name_label.text = _callsign if not _callsign.is_empty() else "—"
	_validate()


func _on_region_selected(region: int) -> void:
	_region = region
	for index in _region_chips.size():
		UiKit.set_chip_active(_region_chips[index], _region_values[index] == region)
	Audio.play_ui("toggle_on")


func _on_colour_selected(index: int) -> void:
	_palette_index = index
	for position in _swatches.size():
		var swatch := _swatches[position] as _Swatch
		swatch.selected = position == index
	if _preview != null:
		_preview.palette_index = index
	Audio.play_ui("click")


func _validation_error(callsign: String) -> String:
	if callsign.length() < CALLSIGN_MIN or callsign.length() > CALLSIGN_MAX:
		return Loc.t(&"auth.setup.callsign_hint")
	if _regex.search(callsign) == null:
		return Loc.t(&"auth.setup.callsign_hint")
	return ""


func _validate() -> void:
	if _callsign_field == null:
		return
	var error := _validation_error(_callsign)
	var valid := error.is_empty()
	if _continue_button != null:
		_continue_button.disabled = not valid
	if _hint_label != null:
		_hint_label.text = Loc.t(&"auth.setup.callsign_hint") if valid else error
		_hint_label.add_theme_color_override("font_color",
			Design.TEXT_MUTED if valid else Design.DANGER)


func _continue_to_colour() -> void:
	_callsign = _callsign_field.text.strip_edges()
	if not _validation_error(_callsign).is_empty():
		_validate()
		Audio.play_ui("error")
		return
	_step = Step.COLOUR
	rebuild()


func _back_to_identity() -> void:
	_step = Step.IDENTITY
	rebuild()


func _on_enter_pressed() -> void:
	var callsign := _callsign.strip_edges()
	if not _validation_error(callsign).is_empty():
		_step = Step.IDENTITY
		rebuild()
		Audio.play_ui("error")
		return

	Settings.set_value("game/region", _region)
	Settings.set_value("game/first_run_complete", true)
	Session.update_profile({
		"display_name": callsign,
		"region": _region,
		"avatar_color": _palette_index,
		"tutorial_complete": false,
	})

	Audio.play_ui("confirm")
	Router.clear_history()
	Router.goto(&"menu")


func on_back_requested() -> void:
	if _step == Step.COLOUR:
		_back_to_identity()
		return
	Router.goto(&"menu")


## Crisp pixel swatches with a visible selected frame.
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
		if side <= 2.0:
			return
		var inset := 5.0
		var rect := Rect2(Vector2(inset, inset), Vector2(side, side) - Vector2(inset * 2.0, inset * 2.0))
		var color := AvatarView.color_for_index(palette_index)
		draw_rect(rect, color)
		draw_rect(rect, Design.ACCENT if selected else Design.LINE_STRONG,
			false, 4.0 if selected else 2.0)

		if selected:
			var mark_size := side * 0.20
			var mark_rect := Rect2(rect.position + Vector2(4, 4), Vector2(mark_size, mark_size))
			draw_rect(mark_rect, Design.BG)
			draw_rect(Rect2(mark_rect.position + Vector2(mark_size * 0.25, mark_size * 0.25),
				Vector2(mark_size * 0.5, mark_size * 0.5)), Design.ACCENT)
