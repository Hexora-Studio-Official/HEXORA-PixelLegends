class_name SocialSquadPanel
extends RefCounted
## Match Invite drawer, Followers & Following social lists, and 5v5 Squad hub.


static func open(
	host: Control,
	data: HubPreviewData,
	initial_tab: int = 0,
	on_go_lobby: Callable = Callable()
) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"SOCIAL, SQUAD & PARTY INVITE",
		&"friends",
		"Invite friends to your 5v5 lobby, manage Followers/Following, and coordinate your Squad"
	)
	var state := {"tab": initial_tab}

	var render_ref: Array[Callable] = []
	var render := func(tab_idx: int) -> void:
		state["tab"] = tab_idx
		shell.clear_body()
		match tab_idx:
			0: _build_invite_tab(shell, data, on_go_lobby, render_ref[0])
			1: _build_follow_list_tab(shell, data, data.followers, "PLAYERS FOLLOWING YOU", render_ref[0], 1)
			2: _build_following_tab(shell, data, render_ref[0])
			_: _build_squad_tab(shell, data)
	render_ref.append(render)

	shell.set_tabs(["INVITE FRIENDS", "FOLLOWERS", "FOLLOWING", "SQUAD"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_invite_tab(
	shell: HubOverlayShell, data: HubPreviewData, on_go_lobby: Callable, rerender: Callable
) -> void:
	var mode_entry := data.mode_by_id(data.selected_mode_id)
	var banner := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(banner)
	var brow := UiKit.hbox(Design.SPACE_MD)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(brow)

	var binfo := UiKit.vbox(2)
	binfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	binfo.add_child(UiKit.subheading("INVITE ALLIES TO %s LOBBY" % String(mode_entry["name"])))
	binfo.add_child(UiKit.caption("Invited friends join your local 5v5 party slots immediately."))
	brow.add_child(binfo)

	var open_lobby_btn := UiKit.button("OPEN 5V5 LOBBY", &"HudPlayButton", &"play")
	UiKit.on_press(open_lobby_btn, func() -> void:
		shell.dismiss()
		if on_go_lobby.is_valid():
			on_go_lobby.call()
	, "confirm")
	brow.add_child(open_lobby_btn)

	for friend_entry: Dictionary in data.friends:
		var online := bool(friend_entry["online"])
		var already := data.is_in_lobby(String(friend_entry["id"]))
		var row_card := UiKit.panel(&"HudCardActivePanel" if already else &"HudCardPanel")
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row_card.add_child(row)

		row.add_child(UiKit.status_dot(
			"ONLINE" if online else "OFFLINE",
			Design.SUCCESS if online else Design.TEXT_DIM
		))

		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(String(friend_entry["name"]), &"BodyLabel"))
		info.add_child(UiKit.caption("%s  ·  Main: %s  ·  %s" % [
			String(friend_entry["rank"]),
			String(friend_entry.get("role", "Flex")),
			String(friend_entry["status"]),
		]))
		row.add_child(info)

		var btn := UiKit.button(
			"IN PARTY" if already else ("INVITE" if online else "OFFLINE"),
			&"HudLobbyButton" if (online and not already) else &"GlassButton",
			&"check" if already else &"invite"
		)
		btn.custom_minimum_size = Vector2(150, 44)
		btn.disabled = already or not online
		UiKit.on_press(btn, func() -> void:
			if data.invite_friend_to_lobby(friend_entry):
				EventBus.toast_requested.emit(
					"%s joined your 5v5 party lobby!" % String(friend_entry["name"]), &"success"
				)
				rerender.call(0)
			else:
				EventBus.toast_requested.emit("All 5 party slots are full.", &"error")
		, "confirm")
		row.add_child(btn)
		shell.body.add_child(row_card)


static func _build_follow_list_tab(
	shell: HubOverlayShell,
	data: HubPreviewData,
	list: Array[Dictionary],
	heading_text: String,
	rerender: Callable,
	tab_index: int
) -> void:
	var heading := UiKit.micro("%s (%d)" % [heading_text, list.size()])
	heading.add_theme_color_override("font_color", Design.ACCENT_HI)
	shell.body.add_child(heading)

	for person: Dictionary in list:
		var card := UiKit.panel(&"HudCardPanel")
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)

		var online := bool(person["online"])
		row.add_child(UiKit.status_dot(
			String(person["status"]),
			Design.SUCCESS if online else Design.TEXT_DIM
		))

		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(String(person["name"]), &"BodyLabel"))
		info.add_child(UiKit.caption("League Tier: " + String(person["rank"])))
		row.add_child(info)

		var is_following := bool(person.get("is_following", false))
		var follow_btn := UiKit.button(
			"UNFOLLOW" if is_following else "FOLLOW BACK",
			&"GlassButton" if is_following else &"HudPlayButton"
		)
		follow_btn.custom_minimum_size = Vector2(155, 42)
		UiKit.on_press(follow_btn, func() -> void:
			data.toggle_follow_user(person)
			rerender.call(tab_index)
		)
		row.add_child(follow_btn)

		var inv_btn := UiKit.button("INVITE", &"HudLobbyButton", &"invite")
		inv_btn.custom_minimum_size = Vector2(126, 42)
		inv_btn.disabled = not online
		UiKit.on_press(inv_btn, func() -> void:
			if data.invite_friend_to_lobby(person):
				EventBus.toast_requested.emit(
					"Invited %s to party lobby!" % String(person["name"]), &"success"
				)
		, "confirm")
		row.add_child(inv_btn)
		shell.body.add_child(card)


static func _build_following_tab(
	shell: HubOverlayShell, data: HubPreviewData, rerender: Callable
) -> void:
	var add_card := UiKit.panel(&"HudCardPanel")
	var add_row := UiKit.hbox(Design.SPACE_SM)
	add_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_card.add_child(add_row)

	var search_field := LineEdit.new()
	search_field.theme_type_variation = &"HexLineEdit"
	search_field.placeholder_text = "Enter player name to Follow (preview)..."
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(search_field)

	var add_btn := UiKit.button("FOLLOW PLAYER", &"HudPlayButton", &"plus")
	add_btn.custom_minimum_size = Vector2(180, 44)
	UiKit.on_press(add_btn, func() -> void:
		var handle := search_field.text.strip_edges()
		if handle.length() < 3:
			EventBus.toast_requested.emit("Enter at least 3 characters.", &"error")
			return
		data.following.append({
			"id": "custom_" + str(data.following.size() + 1),
			"name": handle,
			"rank": "Gold III",
			"status": "Online",
			"online": true,
			"is_following": true,
		})
		data.changed.emit()
		EventBus.toast_requested.emit("Now following %s." % handle, &"success")
		rerender.call(2)
	, "confirm")
	add_row.add_child(add_btn)
	shell.body.add_child(add_card)

	var snapshot := data.following.duplicate()
	_build_follow_list_tab(shell, data, snapshot, "PLAYERS YOU FOLLOW", rerender, 2)


static func _build_squad_tab(shell: HubOverlayShell, data: HubPreviewData) -> void:
	var info := data.squad_info
	var hero_card := UiKit.panel(&"HudCardActivePanel")
	shell.body.add_child(hero_card)
	var hcol := UiKit.vbox(Design.SPACE_SM)
	hero_card.add_child(hcol)

	var htop := UiKit.hbox(Design.SPACE_MD)
	htop.alignment = BoxContainer.ALIGNMENT_CENTER
	htop.add_child(HexIcon.make(&"shield", Design.ACCENT_HI, 40.0, 2.4, Design.TEAL))

	var titles := UiKit.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UiKit.subheading("[%s] %s  ·  Lv.%d" % [
		String(info["tag"]), String(info["name"]), int(info["level"])
	]))
	titles.add_child(UiKit.caption(String(info["motto"])))
	htop.add_child(titles)

	htop.add_child(UiKit.pill("MEMBERS " + String(info["members_count"]), Design.TEAL, &"TealChipPanel"))
	htop.add_child(UiKit.pill("WEEKLY " + String(info["weekly_activity"]), Design.ACCENT_HI, &"AccentChipPanel"))
	hcol.add_child(htop)

	var split := UiKit.grid(2, Design.SPACE_MD)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(split)

	var roster_card := UiKit.panel(&"HudCardPanel")
	var rcol := UiKit.vbox(Design.SPACE_XS)
	roster_card.add_child(rcol)
	var rtitle := UiKit.micro("ACTIVE SQUAD ROSTER")
	rtitle.add_theme_color_override("font_color", Design.TEAL)
	rcol.add_child(rtitle)
	var members: Array = info["members"]
	for m: Dictionary in members:
		var mrow := UiKit.hbox(Design.SPACE_SM)
		mrow.add_child(UiKit.label(String(m["name"]), &"BodyLabel"))
		mrow.add_child(UiKit.spacer())
		mrow.add_child(UiKit.pill(String(m["role"]), Design.ACCENT_HI, &"ChipPanel"))
		mrow.add_child(UiKit.caption("%d pts" % int(m["points"])))
		rcol.add_child(mrow)
	split.add_child(roster_card)

	var finder_card := UiKit.panel(&"HudCardPanel")
	var fcol := UiKit.vbox(Design.SPACE_XS)
	finder_card.add_child(fcol)
	var ftitle := UiKit.micro("DISCOVER OTHER SQUADS (PREVIEW)")
	ftitle.add_theme_color_override("font_color", Design.ACCENT_HI)
	fcol.add_child(ftitle)
	for sq: Dictionary in data.squad_directory:
		var srow := UiKit.hbox(Design.SPACE_SM)
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		var slbl := UiKit.label("[%s] %s (%s)" % [
			String(sq["tag"]), String(sq["name"]), String(sq["members"])
		], &"BodyLabel")
		slbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(slbl)
		var apply_btn := UiKit.button("APPLY", &"GlassButton")
		apply_btn.custom_minimum_size = Vector2(104, 40)
		var sq_name := String(sq["name"])
		UiKit.on_press(apply_btn, func() -> void:
			EventBus.toast_requested.emit(
				"Application queued for %s (server preview)." % sq_name, &"info"
			)
		)
		srow.add_child(apply_btn)
		fcol.add_child(srow)
	split.add_child(finder_card)
