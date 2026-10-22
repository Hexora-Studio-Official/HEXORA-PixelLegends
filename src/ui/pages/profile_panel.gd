class_name ProfilePanel
extends RefCounted
## Player profile window with live local callsign editing, UID copy, League
## career summary, showcase hero selector, and quick links to Social & Rankings.


static func open(
	host: Control,
	data: HubPreviewData,
	on_open_social: Callable,
	on_open_rankings: Callable
) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"PLAYER PROFILE",
		&"profile",
		"Local player identity, League career summary, and hero showcase"
	)

	var render_ref: Array[Callable] = []
	var render := func() -> void:
		shell.clear_body()
		_build_identity_card(shell, data, on_open_social, render_ref[0])
		_build_stats_summary(shell, on_open_rankings)
		_build_showcase_card(shell, data, render_ref[0])
	render_ref.append(render)
	render.call()
	return shell


static func _build_identity_card(
	shell: HubOverlayShell,
	data: HubPreviewData,
	on_open_social: Callable,
	rerender: Callable
) -> void:
	var card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(card)

	var outer := UiKit.vbox(Design.SPACE_MD)
	card.add_child(outer)

	var top_row := UiKit.hbox(Design.SPACE_LG)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(top_row)

	var profile := Session.profile
	if profile != null:
		top_row.add_child(AvatarView.make(profile, 78.0))

	var info := UiKit.vbox(Design.SPACE_XXS)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := UiKit.heading(Session.display_name())
	name_lbl.add_theme_font_size_override("font_size", Design.FONT_H3)
	info.add_child(name_lbl)

	var uid_str := profile.uid if profile != null and not profile.uid.is_empty() else "LOCAL-GUEST-01"
	var sub_lbl := UiKit.caption(
		"UID: %s  ·  [%s] %s  ·  %s" % [
			uid_str.substr(0, 12).to_upper(),
			String(data.squad_info["tag"]),
			String(data.squad_info["name"]),
			Loc.t(&"home.guest_profile"),
		]
	)
	info.add_child(sub_lbl)
	top_row.add_child(info)

	var social_box := UiKit.hbox(Design.SPACE_SM)
	var followers_btn := UiKit.button(
		"FOLLOWERS (%d)" % data.followers.size(), &"GlassButton", &"friends"
	)
	UiKit.on_press(followers_btn, func() -> void:
		shell.dismiss()
		if on_open_social.is_valid():
			on_open_social.call(1)
	)
	social_box.add_child(followers_btn)

	var following_btn := UiKit.button(
		"FOLLOWING (%d)" % data.following.size(), &"GlassButton", &"friends"
	)
	UiKit.on_press(following_btn, func() -> void:
		shell.dismiss()
		if on_open_social.is_valid():
			on_open_social.call(2)
	)
	social_box.add_child(following_btn)

	var copy_btn := UiKit.button(Loc.t(&"common.copy"), &"GlassButton", &"copy")
	UiKit.on_press(copy_btn, func() -> void:
		DisplayServer.clipboard_set(uid_str)
		EventBus.toast_requested.emit(Loc.t(&"toast.copied"), &"info")
	)
	social_box.add_child(copy_btn)

	var sign_out_btn := UiKit.button(Loc.t(&"settings.account.sign_out"), &"DangerButton", &"logout")
	UiKit.on_press(sign_out_btn, func() -> void:
		shell.dismiss()
		Auth.sign_out()
	, "back")
	social_box.add_child(sign_out_btn)
	top_row.add_child(social_box)

	# Inline live player name editor persisted locally to user://profile.json
	var edit_row := UiKit.hbox(Design.SPACE_SM)
	edit_row.alignment = BoxContainer.ALIGNMENT_CENTER
	edit_row.add_child(UiKit.caption("Change Callsign:"))
	var name_input := LineEdit.new()
	name_input.theme_type_variation = &"HexLineEdit"
	name_input.text = Session.profile.display_name if Session.profile != null else ""
	name_input.placeholder_text = Loc.t(&"home.edit_placeholder")
	name_input.max_length = 16
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_row.add_child(name_input)

	var save_btn := UiKit.button(Loc.t(&"home.edit_save"), &"HudPlayButton", &"check")
	save_btn.custom_minimum_size = Vector2(165, 46)
	UiKit.on_press(save_btn, func() -> void:
		var candidate := name_input.text.strip_edges()
		var validator := RegEx.new()
		validator.compile("^[A-Za-z0-9_]{3,16}$")
		if validator.search(candidate) == null:
			EventBus.toast_requested.emit(Loc.t(&"home.edit_invalid"), &"error")
			return
		Session.update_profile({"display_name": candidate})
		EventBus.toast_requested.emit(Loc.t(&"home.edit_saved"), &"success")
		rerender.call()
	, "confirm")
	edit_row.add_child(save_btn)
	outer.add_child(edit_row)


static func _build_stats_summary(shell: HubOverlayShell, on_open_rankings: Callable) -> void:
	var row := UiKit.grid(4, Design.SPACE_SM)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UiKit.stat_tile("Current League", "GOLD II ★★★", Design.ACCENT_HI))
	row.add_child(UiKit.stat_tile("Matches (Preview)", "48", Design.TEXT))
	row.add_child(UiKit.stat_tile("Win Rate", "62.5%", Design.SUCCESS))
	row.add_child(UiKit.stat_tile("Career MVPs", "14", Design.TEAL))
	shell.body.add_child(row)

	var rankings_btn := UiKit.button(
		"VIEW PERSONAL, REGIONAL & GLOBAL RANKINGS", &"HudLobbyButton", &"chart"
	)
	rankings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(rankings_btn, func() -> void:
		shell.dismiss()
		if on_open_rankings.is_valid():
			on_open_rankings.call(0)
	)
	shell.body.add_child(rankings_btn)


static func _build_showcase_card(
	shell: HubOverlayShell, data: HubPreviewData, rerender: Callable
) -> void:
	var card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(card)
	var col := UiKit.vbox(Design.SPACE_SM)
	card.add_child(col)

	var current_hero := data.hero_by_id(data.featured_hero_id)
	var title := UiKit.micro("PROFILE SHOWCASE HERO: %s (%s)" % [
		String(current_hero["name"]).to_upper(),
		String(current_hero["role"]).to_upper(),
	])
	title.add_theme_color_override("font_color", Design.ACCENT_HI)
	col.add_child(title)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", Design.SPACE_SM)
	flow.add_theme_constant_override("v_separation", Design.SPACE_SM)
	for hero: Dictionary in data.heroes:
		var hid := String(hero["id"])
		var btn := UiKit.chip(
			"%s · %s" % [String(hero["name"]), String(hero["role"])],
			hid == data.featured_hero_id
		)
		UiKit.on_press(btn, func() -> void:
			data.featured_hero_id = hid
			data.changed.emit()
			rerender.call()
		)
		flow.add_child(btn)
	col.add_child(flow)
