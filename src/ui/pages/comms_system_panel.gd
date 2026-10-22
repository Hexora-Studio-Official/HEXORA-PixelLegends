class_name CommsSystemPanel
extends RefCounted
## Live Chat channels (World, Region, Squad, Friends), System Mail & Rewards,
## and the Resource Downloads manager.

const CHANNELS := [
	{"id": "world", "label": "World Chat"},
	{"id": "region", "label": "Regional Chat"},
	{"id": "squad", "label": "Squad Chat"},
	{"id": "friends", "label": "Friends Whisper"},
]


static func open(host: Control, data: HubPreviewData, initial_tab: int = 0) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"CHAT, MAILBOX & DOWNLOADS",
		&"chat" if initial_tab == 0 else (&"mail" if initial_tab == 1 else &"download"),
		"Global & Squad chat channels, reward inbox, and asset pack manager"
	)
	var state := {"tab": initial_tab, "channel": "world"}

	var render := func(tab_idx: int) -> void:
		state["tab"] = tab_idx
		shell.clear_body()
		match tab_idx:
			0: _build_chat_tab(shell, data, state, shell.refresh_tab)
			1: _build_mail_tab(shell, data, shell.refresh_tab)
			_: _build_downloads_tab(shell, data, shell.refresh_tab)

	shell.set_tabs(["CHAT", "MESSAGES", "DOWNLOADS"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_chat_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var chan_bar := HFlowContainer.new()
	chan_bar.add_theme_constant_override("h_separation", Design.SPACE_XS)
	for raw_ch in CHANNELS:
		var ch: Dictionary = raw_ch
		var cid := String(ch["id"])
		var chip := UiKit.chip(String(ch["label"]), String(state["channel"]) == cid)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["channel"] = cid
			rerender.call(0)
		)
		chan_bar.add_child(chip)
	shell.body.add_child(chan_bar)

	var feed_card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(feed_card)
	var fcol := UiKit.vbox(Design.SPACE_SM)
	feed_card.add_child(fcol)

	var active_chan := String(state["channel"])
	var messages: Array = data.chats.get(active_chan, [])
	for raw_msg in messages:
		var msg: Dictionary = raw_msg
		var row := UiKit.hbox(Design.SPACE_SM)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var is_you := String(msg["tag"]) == "YOU"
		row.add_child(UiKit.pill(
			String(msg["tag"]),
			Design.ACCENT_HI if is_you else Design.TEAL,
			&"AccentChipPanel" if is_you else &"TealChipPanel"
		))
		var line := UiKit.label("%s:  %s" % [String(msg["sender"]), String(msg["text"])], &"BodyLabel")
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		fcol.add_child(row)

	var composer := UiKit.hbox(Design.SPACE_SM)
	var input := LineEdit.new()
	input.theme_type_variation = &"HexLineEdit"
	input.placeholder_text = "Type a message in %s..." % active_chan.capitalize()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer.add_child(input)

	var send_btn := UiKit.button("SEND MESSAGE", &"HudPlayButton", &"play")
	send_btn.custom_minimum_size = Vector2(180, 46)
	var do_send := func() -> void:
		var txt := input.text.strip_edges()
		if txt.is_empty():
			return
		data.send_chat(active_chan, Session.display_name(), txt)
		rerender.call(0)
	UiKit.on_press(send_btn, do_send, "confirm")
	input.text_submitted.connect(func(_v: String) -> void: do_send.call())
	composer.add_child(send_btn)
	shell.body.add_child(composer)


static func _build_mail_tab(
	shell: HubOverlayShell, data: HubPreviewData, rerender: Callable
) -> void:
	var header := UiKit.hbox(Design.SPACE_SM)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	var unread := data.unread_mail_count()
	header.add_child(UiKit.caption("Unclaimed rewards in inbox: %d" % unread))
	header.add_child(UiKit.spacer())

	var claim_all := UiKit.button("CLAIM ALL REWARDS", &"HudPlayButton", &"check")
	claim_all.disabled = unread == 0
	UiKit.on_press(claim_all, func() -> void:
		var count := data.claim_all_mail()
		EventBus.toast_requested.emit("Claimed %d mail reward(s)!" % count, &"success")
		rerender.call(1)
	, "confirm")
	header.add_child(claim_all)
	shell.body.add_child(header)

	for idx in data.mails.size():
		var mail: Dictionary = data.mails[idx]
		var claimed := bool(mail["claimed"])
		var card := UiKit.panel(&"HudCardPanel" if claimed else &"HudCardActivePanel")
		var col := UiKit.vbox(Design.SPACE_XS)
		card.add_child(col)

		var top := UiKit.hbox(Design.SPACE_SM)
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_child(HexIcon.make(&"mail", Design.TEXT_DIM if claimed else Design.ACCENT_HI, 24.0))
		var title := UiKit.subheading(String(mail["title"]))
		title.add_theme_font_size_override("font_size", Design.FONT_LEAD)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		top.add_child(UiKit.caption("%s · %s" % [String(mail["sender"]), String(mail["date"])]))
		col.add_child(top)

		col.add_child(UiKit.paragraph(String(mail["body"]), 780.0))

		var foot := UiKit.hbox(Design.SPACE_SM)
		foot.alignment = BoxContainer.ALIGNMENT_CENTER
		if int(mail["coins"]) > 0:
			foot.add_child(UiKit.pill("+%d COINS" % int(mail["coins"]), Design.ACCENT_HI, &"AccentChipPanel"))
		if int(mail["gems"]) > 0:
			foot.add_child(UiKit.pill("+%d GEMS" % int(mail["gems"]), Design.TEAL, &"TealChipPanel"))
		foot.add_child(UiKit.spacer())

		var btn := UiKit.button(
			"CLAIMED" if claimed else "CLAIM REWARD",
			&"GlassButton" if claimed else &"HudPlayButton",
			&"check"
		)
		btn.custom_minimum_size = Vector2(175, 42)
		btn.disabled = claimed
		var mail_idx := idx
		UiKit.on_press(btn, func() -> void:
			if data.claim_mail(mail_idx):
				EventBus.toast_requested.emit("Mail attachment claimed!", &"success")
				rerender.call(1)
		, "confirm")
		foot.add_child(btn)
		col.add_child(foot)
		shell.body.add_child(card)


static func _build_downloads_tab(
	shell: HubOverlayShell, data: HubPreviewData, rerender: Callable
) -> void:
	var ctrl_card := UiKit.panel(&"HudCardPanel")
	var crow := UiKit.hbox(Design.SPACE_MD)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_card.add_child(crow)

	var cinfo := UiKit.vbox(2)
	cinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cinfo.add_child(UiKit.subheading("RESOURCE PACK MANAGER"))
	cinfo.add_child(UiKit.caption(
		"Preview asset streaming status — CDN downloads will activate once backend storage is live."
	))
	crow.add_child(cinfo)

	var toggle_btn := UiKit.button(
		"RESUME ALL" if data.downloads_paused else "PAUSE ALL",
		&"HudPlayButton" if data.downloads_paused else &"GlassButton"
	)
	toggle_btn.custom_minimum_size = Vector2(165, 44)
	UiKit.on_press(toggle_btn, func() -> void:
		data.downloads_paused = not data.downloads_paused
		rerender.call(2)
	)
	crow.add_child(toggle_btn)
	shell.body.add_child(ctrl_card)

	for pack: Dictionary in data.download_packs:
		var card := UiKit.panel(&"HudCardPanel")
		var col := UiKit.vbox(Design.SPACE_XS)
		card.add_child(col)

		var row := UiKit.hbox(Design.SPACE_SM)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(HexIcon.make(&"download", Design.TEAL, 22.0))
		var name_lbl := UiKit.label(String(pack["name"]), &"BodyLabel")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		row.add_child(UiKit.caption(String(pack["size"])))
		var done := float(pack["progress"]) >= 0.999
		var state_text := "INSTALLED" if done else (
			"PAUSED" if data.downloads_paused else String(pack["status"]).to_upper()
		)
		row.add_child(UiKit.pill(
			state_text,
			Design.SUCCESS if done else Design.TEAL,
			&"SuccessChipPanel" if done else &"TealChipPanel"
		))
		col.add_child(row)

		var bar := UiKit.progress(&"XpBar" if done else &"RankBar", float(pack["progress"]), 10)
		col.add_child(bar)
		shell.body.add_child(card)
