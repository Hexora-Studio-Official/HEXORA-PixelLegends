extends HexScreen
## Sign-in: Google, or guest.
##
## A responsive centered sign-in card; the viewport scrolls when the screen is
## too short, and the card never exceeds the device's safe content width.
##
## Two things here are deliberate and worth keeping:
##   1. Settings is reachable before sign-in. The Google client ID has to be
##      configurable by a reviewer who has no account yet.
##   2. Guest mode is a first-class button, not a hidden fallback. It is the
##      only path that works with no network, no backend and no Google project.

var _google_button: Button
var _guest_button: Button
var _error_banner: PanelContainer
var _error_label: Label
var _status_row: HBoxContainer
var _busy: bool = false
var _card: PanelContainer


func build() -> void:
	_busy = Auth.is_busy()

	var scroll := UiKit.scroll(true)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(center)

	_card = UiKit.panel(&"CardPanel")
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_card)
	_fit_card_width()
	call_deferred("_fit_card_width")

	var column := UiKit.vbox(Design.SPACE_MD)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.add_child(column)
	column.add_child(_build_brand_header())
	column.add_child(UiKit.divider(Design.LINE_STRONG, 2))
	column.add_child(_build_form_column())

	# `build()` runs again on a language change, so these are idempotent.
	UiKit.listen(EventBus.auth_state_changed, _on_auth_state_changed)
	UiKit.listen(EventBus.auth_failed, _on_auth_failed)
	UiKit.listen(EventBus.auth_signed_in, _on_signed_in)
	UiKit.prepare_scroll_content(center)


func _fit_card_width() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var available_width := safe_content_width()
	if available_width <= 0.0:
		available_width = get_viewport_rect().size.x
	if available_width <= 0.0:
		return
	var gutter := minf(float(Design.SPACE_MD), available_width * 0.04)
	_card.custom_minimum_size.x = minf(900.0, maxf(0.0, available_width - gutter * 2.0))


func on_screen_resized() -> void:
	_fit_card_width()


func _build_brand_header() -> Control:
	var row := UiKit.hbox(Design.SPACE_LG)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var mark := PixelFieldMark.new()
	mark.custom_minimum_size = Vector2(76, 76)
	row.add_child(mark)

	var identity := UiKit.vbox(Design.SPACE_XS)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(UiKit.subheading(Loc.t(&"app.name")))
	identity.add_child(UiKit.label(Loc.t(&"app.tagline"), &"BodyMutedLabel"))
	row.add_child(identity)
	return row


func _build_form_column() -> VBoxContainer:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := UiKit.subheading(Loc.t(&"auth.login.title"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiKit.paragraph(Loc.t(&"auth.login.subtitle"), 760.0, &"BodyMutedLabel")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	# ---- error banner (hidden until something fails) -----------------------
	_error_banner = UiKit.panel(&"WarnPanel")
	_error_label = UiKit.label("", &"BodyLabel")
	_error_label.add_theme_color_override("font_color", Design.DANGER)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_banner.add_child(_error_label)
	_error_banner.visible = false
	column.add_child(_error_banner)

	# ---- Google ------------------------------------------------------------
	_google_button = UiKit.button(Loc.t(&"auth.login.google"), &"PrimaryButton", &"google")
	_google_button.custom_minimum_size = Vector2(0, 68)
	_google_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(_google_button, _on_google_pressed)
	column.add_child(_google_button)

	if not Auth.google_is_configured():
		var setup_note := UiKit.paragraph(
			Loc.t(&"auth.error.not_configured"), 760.0, &"BodyMutedLabel")
		setup_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(setup_note)

	# ---- divider and guest entry ------------------------------------------
	var separator := UiKit.hbox(Design.SPACE_MD)
	var left := UiKit.divider()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_child(left)
	separator.add_child(UiKit.label(Loc.t(&"auth.login.separator"), &"CaptionLabel"))
	var right := UiKit.divider()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_child(right)
	column.add_child(separator)

	_guest_button = UiKit.button(Loc.t(&"auth.login.guest"), &"OutlineButton", &"profile")
	_guest_button.custom_minimum_size = Vector2(0, 68)
	_guest_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(_guest_button, _on_guest_pressed)
	column.add_child(_guest_button)

	var guest_hint := UiKit.paragraph(Loc.t(&"auth.login.guest_hint"), 760.0, &"BodyMutedLabel")
	guest_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(guest_hint)

	_status_row = UiKit.hbox(Design.SPACE_SM)
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_status_row)
	_refresh_status()

	var legal := RichTextLabel.new()
	legal.bbcode_enabled = true
	legal.fit_content = true
	legal.scroll_active = false
	legal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legal.custom_minimum_size = Vector2(0, 28)
	legal.add_theme_font_override("normal_font", Design.font_ui)
	legal.add_theme_font_size_override("normal_font_size", Design.FONT_SMALL)
	legal.add_theme_color_override("default_color", Design.TEXT_MUTED)
	legal.layout_direction = Loc.layout_direction()
	legal.text = "%s [url=terms]%s[/url] · [url=privacy]%s[/url]" % [
		Loc.t(&"auth.login.legal"), Loc.t(&"auth.login.terms"), Loc.t(&"auth.login.privacy"),
	]
	legal.meta_clicked.connect(_on_legal_clicked)
	column.add_child(legal)

	var settings := UiKit.button(Loc.t(&"menu.settings"), &"GhostButton", &"settings")
	settings.custom_minimum_size = Vector2(0, 52)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(settings, _open_settings_modal)
	column.add_child(settings)

	_apply_busy_state(_busy)
	return column


func _refresh_status() -> void:
	if _status_row == null:
		return
	for child in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()

	var configured := Api.is_configured()
	var online := Api.is_online()
	var text := Loc.t(&"auth.login.server_checking")
	var tone := Design.TEXT_MUTED
	if not configured:
		text = Loc.t(&"auth.login.offline_ok")
		tone = Design.WARNING
	elif online:
		text = Loc.t(&"auth.login.server_ok")
		tone = Design.SUCCESS
	else:
		text = Loc.t(&"auth.login.server_down")
		tone = Design.DANGER
	_status_row.add_child(UiKit.status_dot(text, tone))


# ------------------------------------------------------------------ actions

func _on_google_pressed() -> void:
	if _busy:
		return
	hide_error()
	_busy = true
	_apply_busy_state(true)
	Auth.sign_in_with_google()


func _on_guest_pressed() -> void:
	if _busy:
		return
	hide_error()
	# A guest can pick a callsign on the setup screen; the generated one here
	# only has to be valid until then.
	Auth.sign_in_as_guest()


func _on_legal_clicked(meta: Variant) -> void:
	# Phase 1 has no hosted documents; be honest rather than opening a dead URL.
	EventBus.toast_requested.emit(
		"%s — %s" % [String(meta), Loc.t(&"common.phase_two")], &"info")


func _open_settings_modal() -> void:
	var page := SettingsPage.new()
	if page is Control:
		(page as Control).custom_minimum_size = Vector2(760, 560)

	var wrapper := UiKit.panel(&"CardPanel")
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


# -------------------------------------------------------------- state wiring

func _on_auth_state_changed(state: int) -> void:
	_busy = state == GameTypes.AuthState.SIGNING_IN or state == GameTypes.AuthState.RESTORING
	_apply_busy_state(_busy)
	if state == GameTypes.AuthState.SIGNED_OUT:
		hide_error()


func _on_auth_failed(message: String) -> void:
	_busy = false
	_apply_busy_state(false)
	show_error(message)


func _on_signed_in(_profile: PlayerProfile) -> void:
	_busy = false
	_apply_busy_state(false)
	Router.clear_history()
	Router.goto(Router.route_for_auth_state())


func _apply_busy_state(busy: bool) -> void:
	if _google_button != null:
		_google_button.disabled = busy
		UiKit.set_label_text(_google_button,
			Loc.t(&"auth.login.google_busy") if busy else Loc.t(&"auth.login.google"))
	if _guest_button != null:
		_guest_button.disabled = busy
	if busy:
		Router.set_loading_label(Loc.t(&"auth.state.signing_in"))
		Router.show_loading()
	else:
		Router.hide_loading()


func show_error(message: String) -> void:
	if _error_banner == null:
		return
	_error_label.text = message
	_error_banner.visible = true
	Audio.play_ui("error")


func hide_error() -> void:
	if _error_banner != null:
		_error_banner.visible = false


func on_back_requested() -> void:
	if _busy:
		Auth.cancel_google_sign_in()
		return
	Router.quit_game()
