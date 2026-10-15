extends HexScreen
## PixelLegends' visual-only battle hub. Match, hero, squad and collection
## controls are deliberately placeholders; only local profile editing and the
## device settings panel have behaviour in this phase.

const BACKGROUND_PATH := "res://assets/Pixel Legends_ 5v5 Fantasy Showdown.png"
## Below this width the explore rail stops being a side rail and becomes a bar
## under the top bar, instead of disappearing.
const RAIL_WIDE_MIN := 1040.0
const RAIL_NARROW_TOP := 148.0
const RAIL_NARROW_MIN_HEIGHT := 96.0
## Height of one nav chip. Mirrored in the layout maths so the rail can work
## out how tall two rows are.
const NAV_BUTTON_HEIGHT := 58.0
## Wide enough (minus margins) to carry all four destinations on one row.
const NAV_ROW_WIDE_MIN := 620.0
## Height of the bottom battle dock, mirrored here so the rail can be clamped
## against it instead of guessing.
const BATTLE_DOCK_HEIGHT := 150.0

const NAV_ITEMS: Array[Dictionary] = [
	{"text": &"home.modes", "icon": &"play"},
	{"text": &"home.heroes", "icon": &"crown"},
	{"text": &"home.squad", "icon": &"friends"},
	{"text": &"home.collection", "icon": &"arsenal"},
]

var _background: TextureRect
var _background_shade: ColorRect
var _top_bar: HBoxContainer
var _atmosphere: Atmosphere
var _profile_card: PanelContainer
var _build_tag: PanelContainer
var _settings_button: Button
var _left_rail: PanelContainer
var _spotlight: PanelContainer
var _battle_dock: PanelContainer
var _battle_row: HBoxContainer
var _battle_emblem: HexIcon
var _battle_soon: Label
var _battle_play: Button
## How the rail is currently built; -1 means "not built yet".
var _rail_signature_built: int = -1
## Rows the narrow rail wrapped into, used to size it without guessing.
var _rail_rows: int = 1
var _edit_name_button: Button
var _name_label: Label
var _account_label: Label
var _avatar: AvatarView


func _init() -> void:
	backdrop_enabled = false
	safe_padding = Design.SPACE_LG


func build() -> void:
	if _background == null or not is_instance_valid(_background):
		_background = TextureRect.new()
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.texture = load(BACKGROUND_PATH) as Texture2D
		_background.z_index = -2
		add_child(_background)

	if _background_shade == null or not is_instance_valid(_background_shade):
		_background_shade = ColorRect.new()
		_background_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background_shade.color = Color(0.012, 0.03, 0.062, 0.18)
		_background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_shade.z_index = -1
		add_child(_background_shade)

	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "Atmosphere"
		# Above the artwork and its shade, below every control in `content`.
		_atmosphere.z_index = -1
		add_child(_atmosphere)

	_build_top_bar()
	_build_left_rail()
	_build_spotlight()
	_build_battle_dock()
	_layout_menu()
	UiKit.listen(EventBus.profile_changed, _on_profile_changed)


func _ready() -> void:
	super._ready()
	# The artwork used to breathe here: an endless 1.0 → 1.028 scale loop.
	# Scaling a full-bleed texture by a fraction of a percent makes the pixel
	# grid shimmer, so the art read as trembling rather than as moving. The
	# artwork now stays perfectly still and `Atmosphere` puts living light in
	# front of it instead.


func on_screen_resized() -> void:
	_layout_menu()


func _build_top_bar() -> void:
	_top_bar = UiKit.hbox(Design.SPACE_MD)
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 0.0
	_top_bar.offset_right = 0.0
	_top_bar.offset_top = 0.0
	_top_bar.offset_bottom = 100.0
	_top_bar.add_theme_constant_override("separation", Design.SPACE_MD)
	content.add_child(_top_bar)

	_top_bar.add_child(_build_profile_card())
	_top_bar.add_child(UiKit.spacer())

	_build_tag = UiKit.panel(&"EntranceDockPanel")
	_build_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tag := UiKit.micro(Loc.t(&"home.preview_badge"))
	tag.add_theme_color_override("font_color", Design.ACCENT_HI)
	_build_tag.add_child(tag)
	_top_bar.add_child(_build_tag)

	_settings_button = UiKit.icon_button(
		&"settings", Design.ACCENT, 24.0, Loc.t(&"menu.settings"))
	_settings_button.custom_minimum_size = Vector2(58, 58)
	_settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_hover(_settings_button)
	UiKit.on_press(_settings_button, _open_settings_modal, "click")
	_top_bar.add_child(_settings_button)


func _build_profile_card() -> PanelContainer:
	_profile_card = UiKit.panel(&"EntranceDockPanel")
	_profile_card.custom_minimum_size = Vector2(430, 86)
	_profile_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := UiKit.hbox(Design.SPACE_MD)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_card.add_child(row)

	var profile := Session.profile
	if profile != null:
		_avatar = AvatarView.make(profile, 58.0)
		row.add_child(_avatar)

	var identity := UiKit.vbox(Design.SPACE_XXS)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = UiKit.subheading(Session.display_name())
	_name_label.add_theme_font_size_override("font_size", Design.FONT_SUBHEAD)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	identity.add_child(_name_label)

	_account_label = UiKit.micro("")
	_account_label.add_theme_color_override("font_color", Design.TEXT_DIM)
	identity.add_child(_account_label)
	row.add_child(identity)

	_edit_name_button = UiKit.button(Loc.t(&"home.edit_name"), &"GlassButton", &"profile")
	_edit_name_button.custom_minimum_size = Vector2(132, 50)
	UiKit.on_hover(_edit_name_button)
	UiKit.on_press(_edit_name_button, _open_name_editor, "click")
	row.add_child(_edit_name_button)

	_refresh_profile_labels(profile)
	return _profile_card


## Placeholder destinations announce themselves instead of silently ignoring a
## tap. On a touch screen there is no tooltip and no hover state, so a button
## that does nothing is indistinguishable from a broken one; and the whole hub
## is placeholders right now, so silence would be the normal case.
func _on_placeholder_pressed() -> void:
	EventBus.toast_requested.emit(Loc.t(&"home.feature_note"), &"info")


## The explore rail, vertical on wide screens and horizontal on narrow ones.
##
## It used to be hidden outright below 1040px. That is every phone in portrait,
## so the navigation of a mobile-first game simply disappeared on the platform
## it targets. Reflowing it into a compact bar keeps the destinations visible
## without shrinking their tap targets.
func _build_left_rail() -> void:
	if _left_rail == null:
		_left_rail = UiKit.panel(&"EntranceDockPanel")
		_left_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
		content.add_child(_left_rail)

	# Rebuilt when the arrangement changes, so drop the previous one.
	for child in _left_rail.get_children():
		_left_rail.remove_child(child)
		child.queue_free()

	_rail_rows = 1
	if _rail_is_wide():
		_build_rail_column()
	else:
		_build_rail_rows()


## Wide layout: a vertical side rail with its heading and note.
func _build_rail_column() -> void:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_rail.add_child(column)

	var title := UiKit.micro(Loc.t(&"home.explore").to_upper())
	title.add_theme_color_override("font_color", Design.ACCENT_HI)
	column.add_child(title)
	column.add_child(UiKit.divider(Color(0.72, 0.9, 1.0, 0.28), 1))

	for entry: Dictionary in NAV_ITEMS:
		column.add_child(_make_nav_button(entry, false))

	column.add_child(UiKit.spacer())
	var note := UiKit.paragraph(Loc.t(&"home.feature_note"), 230.0, &"CaptionLabel")
	note.add_theme_color_override("font_color", Design.TEXT_DIM)
	column.add_child(note)


## Narrow layout: the destinations become one or two rows of equal chips
## across the full width. Squeezing all four into a single row on a phone
## would give each of them about 78px, which is narrower than a thumb and
## turns "COLLECTION" into an ellipsis.
func _build_rail_rows() -> void:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_rail.add_child(column)

	var per_row := 4 if get_viewport_rect().size.x >= NAV_ROW_WIDE_MIN else 2
	_rail_rows = maxi(1, int(ceili(float(NAV_ITEMS.size()) / float(per_row))))
	var row_box: HBoxContainer = null
	for index in NAV_ITEMS.size():
		if index % per_row == 0:
			row_box = UiKit.hbox(Design.SPACE_SM)
			row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_child(row_box)
		row_box.add_child(_make_nav_button(NAV_ITEMS[index], true))


func _make_nav_button(entry: Dictionary, clip_label: bool) -> Button:
	var button := UiKit.button(Loc.t(entry["text"]), &"GlassNavButton", entry["icon"])
	button.custom_minimum_size = Vector2(0, NAV_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(button)
	UiKit.on_press(button, _on_placeholder_pressed, "click")
	if clip_label:
		# The inner label is only clipped in the narrow layout: a chip that is
		# told to shrink has to be allowed to shorten its own text instead of
		# pushing its neighbours out of the row.
		var text_label := UiKit.label_text(button)
		if text_label != null:
			text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			text_label.clip_text = true
			text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return button


func _rail_is_wide() -> bool:
	return get_viewport_rect().size.x >= RAIL_WIDE_MIN


## Changes whenever the rail needs rebuilding: side rail, one row, or two.
func _rail_signature() -> int:
	if _rail_is_wide():
		return 2
	return 1 if get_viewport_rect().size.x >= NAV_ROW_WIDE_MIN else 0


func _build_spotlight() -> void:
	_spotlight = UiKit.panel(&"EntranceDockPanel")
	_spotlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_spotlight.offset_left = 0.0
	_spotlight.offset_top = 0.0
	content.add_child(_spotlight)

	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_spotlight.add_child(column)

	var eyebrow := UiKit.micro(Loc.t(&"home.spotlight"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Design.ACCENT_HI)
	column.add_child(eyebrow)

	var crest := HexIcon.make(&"crown", Design.ACCENT, 56.0, 2.2)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(crest)

	var title := UiKit.heading(Loc.t(&"home.spotlight_title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Design.FONT_H3)
	column.add_child(title)

	var description := UiKit.paragraph(Loc.t(&"home.spotlight_body"), 280.0)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(description)

	var heroes := UiKit.button(Loc.t(&"home.heroes"), &"GlassButton", &"crown")
	heroes.custom_minimum_size = Vector2(0, 54)
	heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(heroes)
	UiKit.on_press(heroes, _on_placeholder_pressed, "click")
	column.add_child(heroes)


func _build_battle_dock() -> void:
	_battle_dock = UiKit.panel(&"EntranceDockPanel")
	_battle_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_battle_dock.offset_left = 0.0
	_battle_dock.offset_right = 0.0
	_battle_dock.offset_top = -150.0
	_battle_dock.offset_bottom = 0.0
	content.add_child(_battle_dock)

	_battle_row = UiKit.hbox(Design.SPACE_LG)
	_battle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_battle_dock.add_child(_battle_row)

	_battle_emblem = HexIcon.make(&"shield", Design.TEAL, 56.0, 2.2)
	_battle_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_battle_row.add_child(_battle_emblem)

	var copy := UiKit.vbox(Design.SPACE_XXS)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiKit.subheading(Loc.t(&"home.battle_title"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(title)
	var subtitle := UiKit.label(Loc.t(&"home.battle_subtitle"), &"BodyMutedLabel")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(subtitle)
	_battle_row.add_child(copy)

	_battle_soon = UiKit.micro(Loc.t(&"home.coming_soon"))
	_battle_soon.add_theme_color_override("font_color", Design.ACCENT_HI)
	_battle_row.add_child(_battle_soon)

	_battle_play = UiKit.button(Loc.t(&"home.battle_button"), &"GlassPrimaryButton", &"play")
	_battle_play.custom_minimum_size = Vector2(250, 72)
	_battle_play.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_hover(_battle_play)
	# No match to start in this milestone, but the button still answers a tap:
	# it explains what is missing instead of pretending the press never landed.
	UiKit.on_press(_battle_play, _on_placeholder_pressed, "confirm")
	_battle_row.add_child(_battle_play)


func _layout_menu() -> void:
	var viewport := get_viewport_rect().size
	if _top_bar != null:
		_top_bar.offset_left = Design.SPACE_MD
		_top_bar.offset_right = -Design.SPACE_MD
		_top_bar.offset_top = Design.SPACE_MD
		_top_bar.offset_bottom = 112.0
	if _profile_card != null:
		_profile_card.custom_minimum_size.x = minf(430.0, maxf(160.0, viewport.x - 162.0))
	if _build_tag != null:
		_build_tag.visible = viewport.x >= 900.0
	if _avatar != null:
		var avatar_side := 58.0 if viewport.x >= 800.0 else (32.0 if viewport.x < 520.0 else 40.0)
		_avatar.custom_minimum_size = Vector2(avatar_side, avatar_side)
		_avatar.size = Vector2(avatar_side, avatar_side)
	if _profile_card != null:
		var profile_row := _profile_card.get_child(0) as HBoxContainer
		if profile_row != null:
			profile_row.add_theme_constant_override(
				"separation", Design.SPACE_MD if viewport.x >= 800.0 else Design.SPACE_XS)
	if _edit_name_button != null:
		var edit_width := 132.0 if viewport.x >= 800.0 else (68.0 if viewport.x < 520.0 else 76.0)
		_edit_name_button.custom_minimum_size.x = edit_width
		UiKit.set_label_text(_edit_name_button,
			Loc.t(&"home.edit_name_short") if viewport.x < 520.0 else Loc.t(&"home.edit_name"))
	if _name_label != null:
		_name_label.add_theme_font_size_override(
			"font_size", Design.FONT_SUBHEAD if viewport.x >= 800.0 else Design.FONT_SMALL)
	if _settings_button != null:
		_settings_button.custom_minimum_size = Vector2(58.0, 58.0)

	# Rebuild the rail only when its arrangement actually changes, not on every
	# resize tick — rebuilding throws away perfectly good buttons.
	var rail_wide := _rail_is_wide()
	if _left_rail != null:
		if _rail_signature() != _rail_signature_built:
			_rail_signature_built = _rail_signature()
			_build_left_rail()
		_left_rail.visible = true
		_left_rail.offset_left = Design.SPACE_MD
		_left_rail.offset_top = RAIL_NARROW_TOP
		if rail_wide:
			_left_rail.offset_right = 284.0
			_left_rail.offset_bottom = maxf(520.0, viewport.y - 192.0)
		else:
			# Full-width bar. The panel reports the height of a single row, so
			# the extra rows it wrapped into are added here — otherwise a
			# two-row rail would be measured as one and clip the second row.
			_left_rail.offset_right = viewport.x - Design.SPACE_MD
			var extra_rows := float(maxi(0, _rail_rows - 1))
			_left_rail.offset_bottom = RAIL_NARROW_TOP + maxf(
				RAIL_NARROW_MIN_HEIGHT,
				_left_rail.get_combined_minimum_size().y
				+ extra_rows * (NAV_BUTTON_HEIGHT + Design.SPACE_SM))
	if _spotlight != null:
		_spotlight.visible = viewport.x >= 1380.0
		_spotlight.anchor_left = 1.0
		_spotlight.anchor_right = 1.0
		_spotlight.anchor_top = 0.0
		_spotlight.anchor_bottom = 0.0
		_spotlight.offset_left = -352.0
		_spotlight.offset_right = -Design.SPACE_MD
		_spotlight.offset_top = 148.0
		_spotlight.offset_bottom = 510.0
	if _battle_dock != null:
		_battle_dock.anchor_left = 0.0
		_battle_dock.anchor_right = 1.0
		_battle_dock.anchor_top = 1.0
		_battle_dock.anchor_bottom = 1.0
		_battle_dock.offset_top = -150.0
		_battle_dock.offset_bottom = -Design.SPACE_MD
		if viewport.x < 1040.0:
			_battle_dock.offset_left = Design.SPACE_SM
			_battle_dock.offset_right = -Design.SPACE_SM
		elif viewport.x < 1380.0:
			_battle_dock.offset_left = 304.0
			_battle_dock.offset_right = -Design.SPACE_MD
		else:
			_battle_dock.offset_left = 304.0
			_battle_dock.offset_right = -368.0

	# On a narrow screen the rail sits above the battle dock. Stop it from
	# sliding underneath: the bar ends where the dock begins, and if a landscape
	# phone leaves no room for even that, the dock — the only action on this
	# screen that does anything — keeps its place and the rail steps aside.
	if _left_rail != null and not rail_wide:
		var dock_top := viewport.y - BATTLE_DOCK_HEIGHT - Design.SPACE_SM
		if dock_top <= RAIL_NARROW_TOP + RAIL_NARROW_MIN_HEIGHT * 0.5:
			_left_rail.visible = false
		else:
			_left_rail.offset_bottom = minf(_left_rail.offset_bottom, dock_top)

	if _battle_row != null:
		var narrow := viewport.x < 760.0
		_battle_row.add_theme_constant_override(
			"separation", Design.SPACE_XS if narrow else Design.SPACE_LG)
		if _battle_emblem != null:
			_battle_emblem.visible = not narrow
		if _battle_soon != null:
			_battle_soon.visible = not narrow
		if _battle_play != null:
			_battle_play.custom_minimum_size.x = 152.0 if narrow else 250.0


func _on_profile_changed(profile: PlayerProfile) -> void:
	_refresh_profile_labels(profile)
	if _name_label != null:
		_name_label.text = Session.display_name()
	if _avatar != null:
		_avatar.initials = profile.initials()
		_avatar.level = profile.level


func _refresh_profile_labels(profile: PlayerProfile) -> void:
	if _account_label == null:
		return
	if profile == null:
		_account_label.text = Loc.t(&"home.guest_profile")
		return
	_account_label.text = Loc.t(&"common.level_short", {"level": profile.level}) \
		+ "  ·  " + (Loc.t(&"auth.guest.badge") if profile.is_guest else Loc.t(&"home.linked_profile"))


func _open_name_editor() -> void:
	if Session.profile == null:
		return
	var wrapper := UiKit.panel(&"GlassModalPanel")
	wrapper.custom_minimum_size = Vector2(480.0, 0.0)
	var column := UiKit.vbox(Design.SPACE_MD)
	wrapper.add_child(column)
	column.add_child(UiKit.subheading(Loc.t(&"home.edit_title")))
	column.add_child(UiKit.paragraph(Loc.t(&"home.edit_hint"), 520.0))

	var name_field := LineEdit.new()
	name_field.theme_type_variation = &"HexLineEdit"
	name_field.text = Session.profile.display_name
	name_field.placeholder_text = Loc.t(&"home.edit_placeholder")
	name_field.max_length = 16
	name_field.custom_minimum_size = Vector2(0.0, 58.0)
	name_field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(name_field)

	var error_label := UiKit.label("", &"DangerLabel")
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.visible = false
	column.add_child(error_label)

	var actions := UiKit.hbox(Design.SPACE_SM)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel := UiKit.button(Loc.t(&"common.cancel"), &"GlassButton")
	var save := UiKit.button(Loc.t(&"home.edit_save"), &"GlassPrimaryButton", &"check")
	cancel.custom_minimum_size = Vector2(130.0, 56.0)
	save.custom_minimum_size = Vector2(180.0, 56.0)
	actions.add_child(cancel)
	actions.add_child(save)
	column.add_child(actions)

	var layer := UiKit.show_modal(self, wrapper, 540.0)
	UiKit.on_hover(cancel)
	UiKit.on_hover(save)
	UiKit.on_press(cancel, func() -> void: UiKit.close_modal(layer), "back")
	var save_action := func() -> void:
		_save_display_name(name_field, error_label, layer)
	UiKit.on_press(save, save_action, "confirm")
	name_field.text_submitted.connect(func(_value: String) -> void:
		_save_display_name(name_field, error_label, layer))
	name_field.call_deferred("grab_focus")
	name_field.call_deferred("select_all")


func _save_display_name(field: LineEdit, error_label: Label, layer: Control) -> void:
	var candidate := field.text.strip_edges()
	var validator := RegEx.new()
	validator.compile("^[A-Za-z0-9_]{3,16}$")
	if candidate.length() < 3 or candidate.length() > 16 or validator.search(candidate) == null:
		error_label.text = Loc.t(&"home.edit_invalid")
		error_label.visible = true
		return
	Session.update_profile({"display_name": candidate})
	EventBus.toast_requested.emit(Loc.t(&"home.edit_saved"), &"success")
	UiKit.close_modal(layer)


func _open_settings_modal() -> void:
	var page := SettingsPage.new()
	page.custom_minimum_size = Vector2(760.0, 560.0)

	var wrapper := UiKit.panel(&"GlassModalPanel")
	var column := UiKit.vbox(Design.SPACE_MD)
	wrapper.add_child(column)
	var header := UiKit.hbox(Design.SPACE_MD)
	header.add_child(UiKit.subheading(Loc.t(&"settings.title")))
	header.add_child(UiKit.spacer())
	var close := UiKit.icon_button(&"close", Design.TEXT_MUTED, 20.0)
	header.add_child(close)
	column.add_child(header)
	column.add_child(UiKit.divider())
	column.add_child(page)
	var layer := UiKit.show_modal(self, wrapper, 800.0)
	UiKit.on_press(close, func() -> void: UiKit.close_modal(layer), "back")


func on_back_requested() -> void:
	Router.quit_game()
