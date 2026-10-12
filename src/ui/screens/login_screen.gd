extends HexScreen
## Sign-in: Google, or guest.
##
## Desktop uses a brand-and-form split; phones use a compact brand strip above
## one full-width, scrollable sign-in card.
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


func build() -> void:
	_busy = Auth.is_busy()

	var screen_scroll := UiKit.scroll(true)
	screen_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(screen_scroll)

	if OS.has_feature("mobile"):
		var stack := UiKit.vbox(Design.SPACE_MD)
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		screen_scroll.add_child(stack)
		stack.add_child(_build_mobile_brand_header())
		stack.add_child(_build_form_column())
	else:
		var columns := UiKit.hbox(Design.SPACE_HUGE)
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
		columns.alignment = BoxContainer.ALIGNMENT_CENTER
		screen_scroll.add_child(columns)
		columns.add_child(_build_brand_column())
		columns.add_child(_build_form_column())

	# `build()` runs again on a language change, so these are idempotent.
	UiKit.listen(EventBus.auth_state_changed, _on_auth_state_changed)
	UiKit.listen(EventBus.auth_failed, _on_auth_failed)
	UiKit.listen(EventBus.auth_signed_in, _on_signed_in)


# ---------------------------------------------------------------- brand side

func _build_brand_column() -> Control:
	var column := UiKit.vbox(Design.SPACE_LG)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.alignment = BoxContainer.ALIGNMENT_BEGIN

	var mark := _LoginMark.new()
	mark.custom_minimum_size = Vector2(104, 104)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(mark)

	var wordmark := UiKit.display(Loc.t(&"app.name"))
	column.add_child(wordmark)

	column.add_child(UiKit.label(Loc.t(&"app.tagline"), &"SectionLabel"))
	column.add_child(UiKit.divider(Design.ACCENT, 2))

	var bullets := UiKit.vbox(Design.SPACE_MD)
	column.add_child(bullets)
	for bullet in [
		{"icon": &"mode_br", "key": &"mode.br100.name", "desc": &"mode.br100.rules"},
		{"icon": &"wifi", "key": &"rooms.hotspot.title", "desc": &"rooms.hotspot.desc"},
		{"icon": &"target", "key": &"mode.snd.name", "desc": &"mode.snd.rules"},
	]:
		bullets.add_child(_build_bullet(bullet["icon"], bullet["key"], bullet["desc"]))

	column.add_child(UiKit.vertical_spacer(Design.SPACE_SM))
	column.add_child(_build_settings_shortcut())
	return column


func _build_mobile_brand_header() -> Control:
	var row := UiKit.hbox(Design.SPACE_MD)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var mark := _LoginMark.new()
	mark.custom_minimum_size = Vector2(60, 60)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var identity := UiKit.vbox(Design.SPACE_XXS)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(UiKit.subheading(Loc.t(&"app.name")))
	identity.add_child(UiKit.caption(Loc.t(&"app.tagline")))
	row.add_child(identity)

	var settings := UiKit.icon_button(&"settings", Design.TEXT_MUTED, 22.0,
		Loc.t(&"menu.settings"))
	UiKit.on_press(settings, _open_settings_modal)
	row.add_child(settings)
	return row


func _build_bullet(icon_kind: StringName, title_key: StringName, desc_key: StringName) -> Control:
	var row := UiKit.hbox(Design.SPACE_MD)
	var icon := HexIcon.make(icon_kind, Design.TEAL, 26.0, 1.8, Design.ACCENT)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var text_block := UiKit.vbox(Design.SPACE_XXS)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_child(UiKit.label(Loc.t(title_key), &"Label"))
	text_block.add_child(UiKit.paragraph(Loc.t(desc_key), 420.0, &"CaptionLabel"))
	row.add_child(text_block)
	return row


func _build_settings_shortcut() -> Control:
	var row := UiKit.hbox(Design.SPACE_SM)
	var button := UiKit.button(Loc.t(&"menu.settings"), &"GhostButton", &"settings")
	UiKit.on_press(button, _open_settings_modal)
	row.add_child(button)
	row.add_child(UiKit.spacer())
	return row


# ----------------------------------------------------------------- form side

func _build_form_column() -> Control:
	var card := UiKit.panel(&"CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var column := UiKit.vbox(Design.SPACE_LG)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(column)

	column.add_child(UiKit.heading(Loc.t(&"auth.login.title")))
	column.add_child(UiKit.paragraph(Loc.t(&"auth.login.subtitle"), 520.0))

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
	_google_button.custom_minimum_size = Vector2(0, 60)
	UiKit.on_press(_google_button, _on_google_pressed)
	column.add_child(_google_button)

	if not Auth.google_is_configured():
		column.add_child(UiKit.paragraph(
			Loc.t(&"auth.error.not_configured"), 520.0, &"CaptionLabel"))

	# ---- separator ---------------------------------------------------------
	var separator := UiKit.hbox(Design.SPACE_MD)
	var left := UiKit.divider()
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_child(left)
	separator.add_child(UiKit.micro(Loc.t(&"common.none")))
	var right := UiKit.divider()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.add_child(right)
	column.add_child(separator)

	# ---- guest -------------------------------------------------------------
	_guest_button = UiKit.button(Loc.t(&"auth.login.guest"), &"OutlineButton", &"profile")
	_guest_button.custom_minimum_size = Vector2(0, 56)
	UiKit.on_press(_guest_button, _on_guest_pressed)
	column.add_child(_guest_button)
	column.add_child(UiKit.paragraph(Loc.t(&"auth.login.guest_hint"), 520.0, &"CaptionLabel"))

	column.add_child(UiKit.divider())

	# ---- server status -----------------------------------------------------
	_status_row = UiKit.hbox(Design.SPACE_SM)
	column.add_child(_status_row)
	_refresh_status()

	# ---- legal -------------------------------------------------------------
	var legal := RichTextLabel.new()
	legal.bbcode_enabled = true
	legal.fit_content = true
	legal.scroll_active = false
	legal.custom_minimum_size = Vector2(0, 40)
	legal.add_theme_font_override("normal_font", Design.font_ui)
	legal.add_theme_font_size_override("normal_font_size", Design.FONT_MICRO)
	legal.add_theme_color_override("default_color", Design.TEXT_DIM)
	legal.layout_direction = Loc.layout_direction()
	legal.text = "%s [url=terms]%s[/url] · [url=privacy]%s[/url]" % [
		Loc.t(&"auth.login.legal"), Loc.t(&"auth.login.terms"), Loc.t(&"auth.login.privacy"),
	]
	legal.meta_clicked.connect(_on_legal_clicked)
	column.add_child(legal)

	_apply_busy_state(_busy)
	return card


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


## Static version of the boot logo, at sign-in size. Kept as its own class so
## the login screen does not depend on the boot scene.
class _LoginMark extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side := minf(size.x, size.y)
		if side <= 4.0:
			return
		var centre := size * 0.5
		var radius := side * 0.44
		var hexagon := PackedVector2Array()
		for corner in 6:
			var angle := PI / 3.0 * float(corner) - PI / 2.0
			hexagon.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		hexagon.append(hexagon[0])
		draw_polyline(hexagon, Design.ACCENT, maxf(2.0, side * 0.05), true)

		var bar_width := side * 0.07
		var bar_height := side * 0.4
		draw_rect(Rect2(centre.x - side * 0.16 - bar_width * 0.5,
			centre.y - bar_height * 0.5, bar_width, bar_height), Design.ACCENT_HI)
		draw_rect(Rect2(centre.x + side * 0.16 - bar_width * 0.5,
			centre.y - bar_height * 0.5, bar_width, bar_height), Design.ACCENT_HI)
		draw_rect(Rect2(centre.x - side * 0.09, centre.y - bar_width * 0.5,
			side * 0.18, bar_width), Design.TEAL)
		draw_arc(centre, radius * 1.12, 0.0, TAU, 48,
			Color(Design.TEAL.r, Design.TEAL.g, Design.TEAL.b, 0.28), 2.0, true)
