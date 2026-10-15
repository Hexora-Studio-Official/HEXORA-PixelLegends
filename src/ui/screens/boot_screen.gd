extends HexScreen
## PixelLegends entrance: a brief service/session load, followed by the
## guest-first sign-in panel. The other sign-in choices remain visible but are
## intentionally unavailable in this visual-only phase.

const BACKGROUND_PATH := "res://assets/Pixel Legends_ 5v5 Fantasy Showdown.png"
const MIN_DISPLAY_SEC := 1.35
## Widest the entrance dock ever gets. Beyond this the buttons stop reading as
## a group and start reading as three unrelated bars.
const DOCK_MAX_WIDTH := 640.0
const BRAND_MARK_SIZE := 68.0
const BRAND_MARK_SIZE_COMPACT := 52.0
## How far an unavailable choice is dimmed. Enough to read as "not yet", not
## so much that the label becomes unreadable against the artwork.
const INACTIVE_ALPHA := 0.68

var _background: TextureRect
var _background_shade: ColorRect
var _action_panel: PanelContainer
var _brand_mark: Control
var _atmosphere: Atmosphere
var _play_button: Button
var _google_button: Button
var _guest_button: Button
var _settings_button: Button
var _settings_layer: Control
var _settings_dialog: SettingsDialog
var _progress: ProgressBar
var _error_label: Label
var _elapsed := 0.0
var _session_done := false
var _actions_revealed := false
var _busy := false


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
		_background_shade.color = Color(0.012, 0.03, 0.062, 0.16)
		_background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_shade.z_index = -1
		add_child(_background_shade)

	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "Atmosphere"
		# Above the artwork and its shade, below every control in `content`.
		_atmosphere.z_index = -1
		add_child(_atmosphere)

	_settings_button = UiKit.button(Loc.t(&"menu.settings"), &"GlassButton", &"settings")
	_settings_button.custom_minimum_size = Vector2(156, 56)
	# Named so the headless check in tests/ can find the real button
	# instead of guessing at it by its label text.
	_settings_button.name = "EntranceSettingsButton"
	# Visible from the first frame. It used to be revealed with the sign-in
	# dock, which meant a player could not reach graphics, audio or text size
	# until after signing in — even when the reason they wanted Settings was
	# that the entrance itself was hard to read.
	_settings_button.visible = true
	_settings_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_settings_button.position = Vector2(Design.SPACE_LG, Design.SPACE_LG)
	UiKit.on_hover(_settings_button)
	UiKit.on_press(_settings_button, _open_settings_modal, "click")
	content.add_child(_settings_button)

	_action_panel = UiKit.panel(&"EntranceDockPanel")
	_action_panel.anchor_left = 0.5
	_action_panel.anchor_right = 0.5
	_action_panel.visible = false
	# Width and height are measured from the dock's own content in
	# `_layout_actions()` rather than hard-coded here, so a longer translation
	# or a larger system font can never be clipped by a fixed rectangle.
	content.add_child(_action_panel)

	var stack := UiKit.vbox(Design.SPACE_SM)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.add_child(stack)

	_brand_mark = PixelLegendsMark.new()
	_brand_mark.custom_minimum_size = Vector2(BRAND_MARK_SIZE, BRAND_MARK_SIZE)
	_brand_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(_brand_mark)

	var eyebrow := UiKit.micro(Loc.t(&"splash.choose_path").to_upper())
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Design.ACCENT_HI)
	stack.add_child(eyebrow)

	var buttons := UiKit.vbox(Design.SPACE_SM)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(buttons)

	# This order is not arbitrary: docs/PROJECT_SPEC.txt lists the entrance
	# choices as Play, Login With Google, Login As Guest. Keep it.
	_play_button = UiKit.button(Loc.t(&"splash.play"), &"GlassButton", &"play")
	_play_button.disabled = true
	_play_button.tooltip_text = Loc.t(&"common.soon")
	buttons.add_child(_inactive_choice_slot(_play_button))

	_google_button = UiKit.button(
		Loc.t(&"splash.login.google"), &"GlassButton", &"google")
	_google_button.disabled = true
	_google_button.tooltip_text = Loc.t(&"common.soon")
	buttons.add_child(_inactive_choice_slot(_google_button))

	_guest_button = UiKit.button(
		Loc.t(&"splash.login.guest"), &"GlassPrimaryButton", &"profile")
	UiKit.on_hover(_guest_button, "hover")
	UiKit.on_press(_guest_button, _on_guest_pressed, "confirm")
	buttons.add_child(_guest_button)

	_error_label = UiKit.label("", &"DangerLabel")
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	stack.add_child(_error_label)

	_progress = UiKit.progress(&"ThinBar", 0.0, 3)
	_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress.offset_left = 0.0
	_progress.offset_right = 0.0
	_progress.offset_top = -3.0
	_progress.offset_bottom = 0.0
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	UiKit.listen(EventBus.auth_state_changed, _on_auth_state_changed)
	UiKit.listen(EventBus.auth_signed_in, _on_signed_in)
	UiKit.listen(EventBus.auth_failed, _on_auth_failed)
	_layout_actions()
	# Measure again after the first layout pass: the dock's minimum size is
	# only known once its labels have been given a real width to wrap at.
	call_deferred("_layout_actions")


func _ready() -> void:
	super._ready()
	_restore_session()
	# The artwork used to breathe here: an endless 1.0 → 1.035 scale loop.
	# Scaling a full-bleed texture by a fraction of a percent makes the pixel
	# grid shimmer, so the art read as trembling rather than as moving. The
	# artwork now stays perfectly still and `Atmosphere` puts living light in
	# front of it instead.


## A choice that exists but cannot be used yet.
##
## A disabled button only explains itself through `tooltip_text`, and Android
## never shows tooltips — on the platform this game targets, the player would
## simply see two buttons that silently refuse to work. The note makes the
## reason visible on every device, and keeping it attached to the button means
## the two can never drift apart.
func _inactive_choice_slot(button: Button) -> VBoxContainer:
	var slot := UiKit.vbox(Design.SPACE_XXS)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.modulate.a = INACTIVE_ALPHA
	slot.add_child(button)

	var note := UiKit.micro(Loc.t(&"common.soon").to_upper())
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Design.TEXT_MUTED)
	note.modulate.a = 0.8
	slot.add_child(note)
	return slot


## Size and place the entrance dock.
##
## Everything here is derived from the viewport and from the dock's own
## measured content. The previous version pinned the height to a constant,
## which meant any change to the copy, the font scale or the number of choices
## risked clipping the last button instead of reflowing around it.
func _layout_actions() -> void:
	if _action_panel == null:
		return
	var viewport := get_viewport_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		return

	var margin := Design.SPACE_MD
	var compact := viewport.y < 650.0

	# ---- buttons: full width of the dock, height follows the compact rule.
	# No fixed minimum width — that used to fight `SIZE_EXPAND_FILL` and could
	# push a 210px-wide button out of a 320px-wide dock on a small phone.
	var button_height := 56.0 if compact else 60.0
	for button: Button in [_guest_button, _play_button, _google_button]:
		if button == null:
			continue
		button.custom_minimum_size = Vector2(0.0, button_height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if _brand_mark != null:
		var mark_size := BRAND_MARK_SIZE_COMPACT if compact else BRAND_MARK_SIZE
		_brand_mark.custom_minimum_size = Vector2(mark_size, mark_size)

	# ---- width: as wide as it can be, capped so the group stays a group.
	var width := clampf(viewport.x - margin * 2.0, 240.0, DOCK_MAX_WIDTH)
	_action_panel.offset_left = -width * 0.5
	_action_panel.offset_right = width * 0.5

	# ---- height: measured from the content, never guessed.
	var height := maxf(_action_panel.get_combined_minimum_size().y, 160.0)

	# ---- position: low on tall screens, lifted on short ones, and clamped so
	# the dock can never hang off the bottom edge or collide with the top.
	var preferred := 0.53 if compact else (0.68 if viewport.x < 760.0 else 0.69)
	var centre_y := clampf(
		viewport.y * preferred,
		margin + height * 0.5,
		maxf(margin + height * 0.5, viewport.y - margin - height * 0.5))
	var anchor_y := centre_y / viewport.y
	_action_panel.anchor_top = anchor_y
	_action_panel.anchor_bottom = anchor_y
	_action_panel.offset_top = -height * 0.5
	_action_panel.offset_bottom = height * 0.5


func on_screen_resized() -> void:
	_layout_actions()


func _restore_session() -> void:
	await Auth.restore_session()
	if not is_inside_tree():
		return
	_session_done = true


func _process(delta: float) -> void:
	_elapsed += delta
	if _progress == null or not is_instance_valid(_progress):
		return
	if not _session_done:
		_progress.value = minf(0.92, _elapsed / MIN_DISPLAY_SEC * 0.92)
		return
	if _elapsed < MIN_DISPLAY_SEC:
		_progress.value = minf(0.98, _elapsed / MIN_DISPLAY_SEC * 0.98)
		return
	_progress.value = 1.0
	if _actions_revealed:
		return
	_actions_revealed = true
	_settings_button.visible = true
	_action_panel.visible = true
	_action_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_action_panel, "modulate:a", 1.0, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_progress.visible = false


func _set_busy(busy: bool) -> void:
	_busy = busy
	if _guest_button != null:
		_guest_button.disabled = busy
		_guest_button.modulate.a = 0.68 if busy else 1.0
	if busy:
		Router.set_loading_label(Loc.t(&"auth.state.signing_in"))
		Router.show_loading()
	else:
		Router.hide_loading()


func _on_auth_state_changed(state: int) -> void:
	if state == GameTypes.AuthState.RESTORING:
		return
	_set_busy(state == GameTypes.AuthState.SIGNING_IN)


func _on_auth_failed(message: String) -> void:
	_set_busy(false)
	if _error_label != null:
		_error_label.text = message
		_error_label.visible = true


func _on_signed_in(_profile: PlayerProfile) -> void:
	_set_busy(false)
	call_deferred("_route_after_sign_in")


func _route_after_sign_in() -> void:
	if not is_inside_tree():
		return
	Router.clear_history()
	Router.goto(Router.route_for_auth_state())


func _on_guest_pressed() -> void:
	if _busy:
		return
	_error_label.visible = false
	if Auth.is_signed_in():
		if Session.is_guest():
			Router.clear_history()
			Router.goto(&"menu")
		else:
			_error_label.text = Loc.t(&"splash.saved_account_unavailable")
			_error_label.visible = true
		return
	Auth.sign_in_as_guest()


func _open_settings_modal() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return
	_settings_dialog = SettingsDialog.new()
	# Never wider than the screen: on a narrow or very tall device the panel
	# has to fit rather than run off the edge. The modal wrapper scrolls, so
	# a short screen is still usable.
	# Sized against the screen it opens on, not the window. On a phone those
	# are the same rectangle, but a panel measured against the window and
	# placed inside a shorter screen is how the footer came to hang past the
	# bottom edge with the buttons half off it.
	var viewport := get_global_rect().size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		viewport = get_viewport_rect().size
	var width := 940.0 if viewport.x <= 1.0 else minf(940.0, viewport.x - Design.SPACE_LG * 2.0)
	# The categories moved from a side column to a strip along the top, which
	# gives the rows the full width but costs the panel a row of height. Take
	# it back, and never ask for more than the screen has.
	var height := minf(800.0, maxf(360.0, viewport.y - 96.0))
	_settings_dialog.custom_minimum_size = Vector2(width, height)
	_settings_dialog.close_requested.connect(_close_settings_modal)
	_settings_layer = UiKit.show_modal(self, _settings_dialog, width)


func _close_settings_modal() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		UiKit.close_modal(_settings_layer)
	_settings_layer = null
	_settings_dialog = null


func on_back_requested() -> void:
	# The panel decides for itself whether unsaved graphics work deserves a
	# question, so back here only routes to it.
	if _settings_dialog != null and is_instance_valid(_settings_dialog):
		_settings_dialog.request_close()
		return
	# There is no cancellable sign-in flow any more: guest entry is a single
	# local step. Back on the entrance means "leave the game", which is what
	# Android players expect from the system gesture.
	if Settings.get_bool("game/confirm_exit", true):
		_confirm_quit()
		return
	Router.quit_game()


## Leaving the game is the one destructive action on this screen, so it asks
## when the preference says to. Built from the same pieces as the panel's own
## confirmation sheet rather than reaching for a second modal layer.
func _confirm_quit() -> void:
	var sheet := UiKit.panel(&"GlassModalPanel")
	sheet.custom_minimum_size = Vector2(420, 0)
	var column := UiKit.vbox(Design.SPACE_MD)
	sheet.add_child(column)
	column.add_child(UiKit.subheading(Loc.t(&"settings.confirm.quit_title")))
	column.add_child(UiKit.paragraph(Loc.t(&"settings.confirm.quit_body"), 380.0))
	var row := UiKit.hbox(Design.SPACE_SM)
	var stay := UiKit.button(Loc.t(&"common.cancel"), &"GlassButton")
	stay.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	row.add_child(stay)
	var leave := UiKit.button(Loc.t(&"common.leave"), &"DangerButton")
	leave.custom_minimum_size = Vector2(140, Design.TOUCH_TARGET_MIN)
	row.add_child(leave)
	column.add_child(row)

	var layer := UiKit.show_modal(self, sheet, 460.0)
	UiKit.on_press(stay, func() -> void: UiKit.close_modal(layer), "back")
	UiKit.on_press(leave, func() -> void:
		UiKit.close_modal(layer)
		Router.quit_game()
	, "click")
