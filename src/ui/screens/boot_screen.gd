extends HexScreen
## PixelLegends entrance: a brief service/session load, followed by the
## guest-first sign-in panel. The other sign-in choices remain visible but are
## intentionally unavailable in this visual-only phase.

const BACKGROUND_PATH := "res://assets/Pixel Legends_ 5v5 Fantasy Showdown.png"
const MIN_DISPLAY_SEC := 1.35
const EDGE_MARGIN := 12.0

var _background: TextureRect
var _background_shade: ColorRect
var _action_panel: PanelContainer
var _play_button: Button
var _google_button: Button
var _guest_button: Button
var _settings_button: Button
var _progress: ProgressBar
var _error_label: Label
var _elapsed := 0.0
var _session_done := false
var _actions_revealed := false
var _busy := false


func _init() -> void:
	backdrop_enabled = false
	mirror_horizontal_safe_insets = false
	safe_padding = Design.SPACE_XS


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
		_background_shade.color = Color(0.025, 0.045, 0.10, 0.09)
		_background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_shade.z_index = -1
		add_child(_background_shade)

	_settings_button = UiKit.button(Loc.t(&"menu.settings"), &"GlassButton", &"settings")
	_settings_button.custom_minimum_size = Vector2(156, 56)
	_settings_button.visible = false
	_settings_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_settings_button.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	UiKit.on_hover(_settings_button)
	UiKit.on_press(_settings_button, _open_settings_modal, "click")
	content.add_child(_settings_button)

	_action_panel = UiKit.panel(&"EntranceDockPanel")
	_action_panel.anchor_left = 0.5
	_action_panel.anchor_right = 0.5
	_action_panel.anchor_top = 0.69
	_action_panel.anchor_bottom = 0.69
	_action_panel.offset_left = -320.0
	_action_panel.offset_right = 320.0
	_action_panel.offset_top = -118.0
	_action_panel.offset_bottom = 118.0
	_action_panel.visible = false
	content.add_child(_action_panel)

	var stack := UiKit.vbox(Design.SPACE_SM)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_panel.add_child(stack)

	var eyebrow := UiKit.micro(Loc.t(&"splash.choose_path").to_upper())
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", Design.ACCENT_HI)
	stack.add_child(eyebrow)

	var buttons := UiKit.vbox(Design.SPACE_SM)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(buttons)

	_play_button = UiKit.button(Loc.t(&"splash.play"), &"GlassButton", &"play")
	_play_button.custom_minimum_size = Vector2(190, 60)
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.disabled = true
	_play_button.modulate.a = 0.68
	_play_button.tooltip_text = Loc.t(&"common.soon")
	buttons.add_child(_play_button)

	_google_button = UiKit.button(
		Loc.t(&"splash.login.google"), &"GlassButton", &"google")
	_google_button.custom_minimum_size = Vector2(210, 60)
	_google_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_google_button.disabled = true
	_google_button.modulate.a = 0.68
	_google_button.tooltip_text = Loc.t(&"common.soon")
	buttons.add_child(_google_button)

	_guest_button = UiKit.button(
		Loc.t(&"splash.login.guest"), &"GlassPrimaryButton", &"profile")
	_guest_button.custom_minimum_size = Vector2(210, 60)
	_guest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _ready() -> void:
	super._ready()
	_restore_session()
	_animate_background()


func _animate_background() -> void:
	if _background == null:
		return
	_background.pivot_offset = get_viewport_rect().size * 0.5
	var tween := create_tween().set_loops()
	tween.tween_property(_background, "scale", Vector2(1.035, 1.035), 15.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_background, "scale", Vector2.ONE, 15.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _layout_actions() -> void:
	if _action_panel == null:
		return
	var viewport := get_viewport_rect().size
	var landscape := viewport.x >= viewport.y * 1.25
	var width := minf(1120.0, viewport.x * 0.62)
	var height := minf(430.0, maxf(280.0, viewport.y * 0.5))
	var right_offset := -EDGE_MARGIN
	var bottom_offset := -EDGE_MARGIN

	if landscape:
		_action_panel.anchor_left = 1.0
		_action_panel.anchor_right = 1.0
		_action_panel.anchor_top = 1.0
		_action_panel.anchor_bottom = 1.0
		_action_panel.offset_left = right_offset - width
		_action_panel.offset_right = right_offset
	else:
		_action_panel.anchor_left = 0.0
		_action_panel.anchor_right = 1.0
		_action_panel.anchor_top = 1.0
		_action_panel.anchor_bottom = 1.0
		_action_panel.offset_left = EDGE_MARGIN
		_action_panel.offset_right = right_offset
	_action_panel.offset_top = bottom_offset - height
	_action_panel.offset_bottom = bottom_offset

	if _settings_button != null:
		_settings_button.position = Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var compact := viewport.y < 650.0
	if _guest_button != null:
		_guest_button.custom_minimum_size.y = 56.0 if compact else 60.0
	if _play_button != null:
		_play_button.custom_minimum_size.y = 56.0 if compact else 60.0
	if _google_button != null:
		_google_button.custom_minimum_size.y = 56.0 if compact else 60.0


func on_screen_resized() -> void:
	_layout_actions()
	if _background != null:
		_background.pivot_offset = get_viewport_rect().size * 0.5


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
	if _settings_button != null:
		_settings_button.disabled = busy
		_settings_button.modulate.a = 0.68 if busy else 1.0
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
	var page := SettingsPage.new()
	page.custom_minimum_size = Vector2(760, 560)

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
	if _busy:
		Auth.cancel_google_sign_in()
		return
	Router.quit_game()
