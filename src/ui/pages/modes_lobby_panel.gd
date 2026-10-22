class_name ModesLobbyPanel
extends RefCounted
## Game mode selector (Classic, League, Dead Field, VS AI) and interactive 5v5
## party lobby room with teammate slots, AI tier control, party chat and preview
## matchmaking timer.

const AI_TIERS := ["Easy", "Normal", "Hard"]
const PRIVACY_LABELS := ["Open Party", "Friends Only"]


static func open(
	host: Control,
	data: HubPreviewData,
	start_in_lobby: bool = false,
	on_open_invite: Callable = Callable()
) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"BATTLE ARENA & LOBBY",
		&"swords",
		"Select a 5v5 game mode or assemble your party lobby"
	)
	var state := {"tab": 1 if start_in_lobby else 0}
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.autostart = true
	shell.add_child(ticker)

	var render_ref: Array[Callable] = []
	var render := func(tab_index: int) -> void:
		state["tab"] = tab_index
		shell.clear_body()
		if tab_index == 0:
			_build_modes_tab(shell, data)
		else:
			_build_lobby_tab(shell, data, on_open_invite, render_ref[0])
	render_ref.append(render)

	ticker.timeout.connect(func() -> void:
		if data.queue_active:
			data.queue_seconds += 1.0
			if int(state["tab"]) == 1 and is_instance_valid(shell):
				render.call(1)
	)

	var refresh_cb := func() -> void:
		if is_instance_valid(shell):
			render.call(int(state["tab"]))
	data.changed.connect(refresh_cb)
	shell.closed.connect(func() -> void:
		if data.changed.is_connected(refresh_cb):
			data.changed.disconnect(refresh_cb)
	)

	shell.set_tabs(["GAME MODES", "5V5 PARTY LOBBY"], int(state["tab"]), render)
	render.call(int(state["tab"]))
	return shell


static func _build_modes_tab(shell: HubOverlayShell, data: HubPreviewData) -> void:
	var grid := UiKit.grid(2, Design.SPACE_MD)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(grid)

	for mode: Dictionary in data.modes:
		var mode_id := String(mode["id"])
		var is_selected := mode_id == data.selected_mode_id
		var card := UiKit.panel(&"HudCardActivePanel" if is_selected else &"HudCardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)

		var col := UiKit.vbox(Design.SPACE_SM)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(col)

		var top := UiKit.hbox(Design.SPACE_SM)
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		var tone: Color = mode["accent"]
		var icon := HexIcon.make(mode["icon"], tone, 34.0, 2.3)
		top.add_child(icon)

		var titles := UiKit.vbox(2)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := UiKit.subheading(String(mode["name"]))
		name_lbl.add_theme_color_override("font_color", tone if is_selected else Design.TEXT)
		titles.add_child(name_lbl)
		titles.add_child(UiKit.caption(String(mode["subtitle"])))
		top.add_child(titles)

		top.add_child(UiKit.pill(String(mode["badge"]), tone, &"ChipPanel"))
		col.add_child(top)

		col.add_child(UiKit.paragraph(String(mode["summary"]), 520.0))

		var meta := UiKit.hbox(Design.SPACE_MD)
		meta.add_child(UiKit.micro(String(mode["lanes"]).to_upper()))
		meta.add_child(UiKit.spacer())
		var dur := UiKit.micro("EST. " + String(mode["duration"]).to_upper())
		dur.add_theme_color_override("font_color", Design.ACCENT_HI)
		meta.add_child(dur)
		col.add_child(meta)

		var actions := UiKit.hbox(Design.SPACE_SM)
		var pick_btn := UiKit.button(
			"SELECTED" if is_selected else "SELECT MODE",
			&"GlassButton",
			&"check" if is_selected else &""
		)
		pick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_btn.disabled = is_selected
		UiKit.on_press(pick_btn, func() -> void:
			data.select_mode(mode_id)
		)
		actions.add_child(pick_btn)

		var lobby_btn := UiKit.button("ENTER LOBBY", &"HudPlayButton", &"play")
		lobby_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(lobby_btn, func() -> void:
			data.select_mode(mode_id)
			shell.select_tab(1)
		, "confirm")
		actions.add_child(lobby_btn)
		col.add_child(actions)


static func _build_lobby_tab(
	shell: HubOverlayShell,
	data: HubPreviewData,
	on_open_invite: Callable,
	rerender: Callable
) -> void:
	var current_mode := data.mode_by_id(data.selected_mode_id)
	var bar := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(bar)

	var bar_row := HFlowContainer.new()
	bar_row.add_theme_constant_override("h_separation", Design.SPACE_SM)
	bar_row.add_theme_constant_override("v_separation", Design.SPACE_XS)
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(bar_row)

	for entry: Dictionary in data.modes:
		var mid := String(entry["id"])
		var chip := UiKit.chip(String(entry["name"]), mid == data.selected_mode_id)
		chip.custom_minimum_size.y = 44.0
		UiKit.on_press(chip, func() -> void:
			data.queue_active = false
			data.queue_seconds = 0.0
			data.select_mode(mid)
		)
		bar_row.add_child(chip)

	if data.selected_mode_id == "vs_ai":
		for idx in AI_TIERS.size():
			var ai_chip := UiKit.chip("AI: " + AI_TIERS[idx], idx == data.ai_difficulty)
			ai_chip.custom_minimum_size.y = 44.0
			var tier_idx := idx
			UiKit.on_press(ai_chip, func() -> void:
				data.ai_difficulty = tier_idx
				rerender.call(1)
			)
			bar_row.add_child(ai_chip)

	var priv_btn := UiKit.chip(PRIVACY_LABELS[data.room_privacy], false)
	priv_btn.custom_minimum_size.y = 44.0
	UiKit.on_press(priv_btn, func() -> void:
		data.room_privacy = (data.room_privacy + 1) % PRIVACY_LABELS.size()
		rerender.call(1)
	)
	bar_row.add_child(priv_btn)

	# ---- 5v5 Team Slots ----------------------------------------------------
	var slots_grid := UiKit.grid(5, Design.SPACE_SM)
	slots_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(slots_grid)

	slots_grid.add_child(_build_host_slot_card())
	for slot_idx in 4:
		slots_grid.add_child(_build_ally_slot_card(slot_idx, data, on_open_invite))

	# ---- Lower Split: Party Chat + Matchmaking Action ----------------------
	var bottom_grid := UiKit.grid(2, Design.SPACE_MD)
	bottom_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(bottom_grid)

	bottom_grid.add_child(_build_lobby_chat_card(data))
	bottom_grid.add_child(_build_queue_card(current_mode, data, rerender))


static func _build_host_slot_card() -> Control:
	var card := UiKit.panel(&"HudCardActivePanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(Design.SPACE_XS)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	col.add_child(UiKit.pill("HOST · SLOT 1", Design.ACCENT_HI, &"AccentChipPanel"))
	if Session.profile != null:
		var av := AvatarView.make(Session.profile, 54.0)
		av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(av)
	var name_lbl := UiKit.label(Session.display_name(), &"BodyLabel")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_lbl)

	var tier_lbl := UiKit.micro("GOLD II · READY")
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", Design.SUCCESS)
	col.add_child(tier_lbl)
	return card


static func _build_ally_slot_card(
	slot_idx: int, data: HubPreviewData, on_open_invite: Callable
) -> Control:
	var occupant: Dictionary = data.lobby_teammates[slot_idx]
	var card := UiKit.panel(&"HudCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(Design.SPACE_XS)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	col.add_child(UiKit.pill("ALLY · SLOT %d" % (slot_idx + 2), Design.TEAL, &"TealChipPanel"))
	if occupant.is_empty():
		var empty_lbl := UiKit.caption("Open Team Slot")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty_lbl)

		var inv_btn := UiKit.button("INVITE", &"HudLobbyButton", &"invite")
		inv_btn.custom_minimum_size = Vector2(0, 44)
		inv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(inv_btn, func() -> void:
			if on_open_invite.is_valid():
				on_open_invite.call()
		)
		col.add_child(inv_btn)
	else:
		var ally_name := UiKit.label(String(occupant["name"]), &"BodyLabel")
		ally_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ally_name)

		var meta := UiKit.micro("%s · %s" % [
			String(occupant.get("rank", "Gold")),
			String(occupant.get("role", "Flex")),
		])
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta.add_theme_color_override("font_color", Design.ACCENT_HI)
		col.add_child(meta)

		var kick_btn := UiKit.button("REMOVE", &"DangerPillButton")
		kick_btn.custom_minimum_size = Vector2(0, 40)
		kick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(kick_btn, func() -> void:
			data.remove_lobby_slot(slot_idx)
		, "back")
		col.add_child(kick_btn)
	return card


static func _build_lobby_chat_card(data: HubPreviewData) -> Control:
	var card := UiKit.panel(&"HudCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(Design.SPACE_XS)
	card.add_child(col)

	var heading := UiKit.micro("PARTY CHAT & QUICK CALLS")
	heading.add_theme_color_override("font_color", Design.TEAL)
	col.add_child(heading)

	var start_idx := maxi(0, data.lobby_messages.size() - 4)
	for idx in range(start_idx, data.lobby_messages.size()):
		var line := UiKit.caption(data.lobby_messages[idx])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)

	var quick_row := HFlowContainer.new()
	quick_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	quick_row.add_theme_constant_override("v_separation", Design.SPACE_XS)
	for phrase in ["Need Tank!", "I play Mid!", "Ready to queue!"]:
		var qbtn := UiKit.chip(phrase, false, &"", true)
		qbtn.custom_minimum_size = Vector2(126, 38)
		var text := phrase
		UiKit.on_press(qbtn, func() -> void:
			data.lobby_messages.append("[%s] %s" % [Session.display_name(), text])
			data.changed.emit()
		)
		quick_row.add_child(qbtn)
	col.add_child(quick_row)

	var input_row := UiKit.hbox(Design.SPACE_XS)
	var field := LineEdit.new()
	field.theme_type_variation = &"HexLineEdit"
	field.placeholder_text = "Message party..."
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(field)
	var send_btn := UiKit.button("SEND", &"GlassButton")
	send_btn.custom_minimum_size = Vector2(96, 44)
	var submit := func() -> void:
		var msg := field.text.strip_edges()
		if msg.is_empty():
			return
		data.lobby_messages.append("[%s] %s" % [Session.display_name(), msg])
		field.text = ""
		data.changed.emit()
	UiKit.on_press(send_btn, submit)
	field.text_submitted.connect(func(_v: String) -> void: submit.call())
	input_row.add_child(send_btn)
	col.add_child(input_row)
	return card


static func _build_queue_card(
	current_mode: Dictionary, data: HubPreviewData, rerender: Callable
) -> Control:
	var card := UiKit.panel(&"HudCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(Design.SPACE_SM)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var party_count := 1
	for slot in data.lobby_teammates:
		if not slot.is_empty():
			party_count += 1

	var title := UiKit.subheading("%s · %d / 5 PARTY" % [String(current_mode["name"]), party_count])
	title.add_theme_color_override("font_color", Design.ACCENT_HI)
	col.add_child(title)
	col.add_child(UiKit.paragraph(String(current_mode["summary"]), 460.0))

	if data.queue_active:
		var secs := int(data.queue_seconds)
		var timer_lbl := UiKit.label(
			"MATCHMAKING PREVIEW · %02d:%02d  (Dedicated server offline)" % [secs / 60, secs % 60],
			&"TealLabel"
		)
		col.add_child(timer_lbl)
		var cancel_btn := UiKit.button("CANCEL MATCHMAKING", &"DangerPillButton", &"close")
		cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(cancel_btn, func() -> void:
			data.queue_active = false
			data.queue_seconds = 0.0
			rerender.call(1)
		, "back")
		col.add_child(cancel_btn)
	else:
		var start_btn := UiKit.button("START MATCHMAKING", &"HudPlayButton", &"play")
		start_btn.custom_minimum_size = Vector2(0, 58)
		start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(start_btn, func() -> void:
			data.queue_active = true
			data.queue_seconds = 0.0
			EventBus.toast_requested.emit(
				"%s queue started (server preview mode)." % String(current_mode["name"]),
				&"info"
			)
			rerender.call(1)
		, "confirm")
		col.add_child(start_btn)
	return card
