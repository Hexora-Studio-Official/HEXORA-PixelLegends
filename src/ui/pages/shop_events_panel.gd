class_name ShopEventsPanel
extends RefCounted
## In-game Storefront (Featured, Heroes, Skins) and Live Events hub (7-Day
## Sign-In Calendar + Daily Missions) using local preview balances.

const SHOP_TABS := ["All", "Featured", "Heroes", "Skins"]


static func open(host: Control, data: HubPreviewData, initial_tab: int = 0) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"STOREFRONT & EVENTS",
		&"store" if initial_tab == 0 else &"star",
		"Preview bundles, heroes, skins, daily login rewards, and seasonal missions"
	)
	var state := {"tab": initial_tab, "shop_cat": "All"}

	var render := func(tab_idx: int) -> void:
		state["tab"] = tab_idx
		shell.clear_body()
		if tab_idx == 0:
			_build_shop_tab(shell, data, state, shell.refresh_tab)
		else:
			_build_events_tab(shell, data, shell.refresh_tab)

	shell.set_tabs(["SHOP", "EVENTS"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_shop_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var top := UiKit.hbox(Design.SPACE_SM)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	for raw_cat in SHOP_TABS:
		var picked: String = String(raw_cat)
		var chip := UiKit.chip(picked, String(state["shop_cat"]) == picked)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["shop_cat"] = picked
			rerender.call(0)
		)
		top.add_child(chip)
	top.add_child(UiKit.spacer())
	top.add_child(UiKit.pill("COINS · %d" % data.coins, Design.ACCENT_HI, &"AccentChipPanel"))
	top.add_child(UiKit.pill("GEMS · %d" % data.gems, Design.TEAL, &"TealChipPanel"))
	shell.body.add_child(top)

	var grid := UiKit.grid(3, Design.SPACE_MD)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(grid)

	for idx in data.shop_offers.size():
		var offer: Dictionary = data.shop_offers[idx]
		if String(state["shop_cat"]) != "All" and String(offer["tab"]) != String(state["shop_cat"]):
			continue
		var bought := bool(offer["bought"])
		var card := UiKit.panel(&"HudCardActivePanel" if bought else &"HudCardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UiKit.vbox(Design.SPACE_SM)
		card.add_child(col)

		var is_gems := String(offer["currency"]) == "gems"
		var price := int(offer["price"])
		col.add_child(UiKit.pill(String(offer["tab"]), Design.VIOLET if is_gems else Design.TEAL, &"ChipPanel"))
		col.add_child(UiKit.label(String(offer["name"]), &"BodyLabel"))
		col.add_child(UiKit.paragraph(String(offer["desc"]), 360.0))

		var buy_label := "OWNED" if bought else ("%d %s" % [price, "GEMS" if is_gems else "COINS"])
		var btn := UiKit.button(
			buy_label,
			&"GlassButton" if bought else &"HudPlayButton",
			&"check" if bought else &"coin"
		)
		btn.disabled = bought
		var offer_idx := idx
		UiKit.on_press(btn, func() -> void:
			if is_gems:
				if data.gems < price:
					EventBus.toast_requested.emit("Not enough preview Arcane Gems.", &"error")
					return
				data.gems -= price
			else:
				if data.coins < price:
					EventBus.toast_requested.emit("Not enough preview Battle Coins.", &"error")
					return
				data.coins -= price
			data.shop_offers[offer_idx]["bought"] = true
			data.changed.emit()
			EventBus.toast_requested.emit("Unlocked %s (preview)." % String(offer["name"]), &"success")
			rerender.call(0)
		, "confirm")
		col.add_child(btn)
		grid.add_child(card)


static func _build_events_tab(
	shell: HubOverlayShell, data: HubPreviewData, rerender: Callable
) -> void:
	var calendar_card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(calendar_card)
	var ccol := UiKit.vbox(Design.SPACE_SM)
	calendar_card.add_child(ccol)

	var ctitle := UiKit.micro("7-DAY CITADEL CHECK-IN REWARDS")
	ctitle.add_theme_color_override("font_color", Design.ACCENT_HI)
	ccol.add_child(ctitle)

	var days_grid := UiKit.grid(7, Design.SPACE_XS)
	days_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for idx in data.login_rewards.size():
		var item: Dictionary = data.login_rewards[idx]
		var ready := bool(item["ready"])
		var claimed := bool(item["claimed"])
		var dcard := UiKit.panel(&"HudCardActivePanel" if (ready and not claimed) else &"InsetPanel")
		dcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dcol := UiKit.vbox(4)
		dcol.alignment = BoxContainer.ALIGNMENT_CENTER
		dcard.add_child(dcol)
		dcol.add_child(UiKit.micro(String(item["day"]).to_upper()))
		var rlbl := UiKit.caption(String(item["reward"]))
		rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dcol.add_child(rlbl)
		var btn_text := "CLAIMED" if claimed else ("CLAIM" if ready else "LOCKED")
		var dbtn := UiKit.button(
			btn_text,
			&"HudPlayButton" if (ready and not claimed) else &"GlassButton"
		)
		dbtn.custom_minimum_size = Vector2(0, 38)
		dbtn.disabled = claimed or not ready
		var day_idx := idx
		UiKit.on_press(dbtn, func() -> void:
			if data.claim_login_day(day_idx):
				EventBus.toast_requested.emit("Claimed %s!" % String(item["reward"]), &"success")
				rerender.call(1)
		, "confirm")
		dcol.add_child(dbtn)
		days_grid.add_child(dcard)
	ccol.add_child(days_grid)

	# Daily & Season Quests
	var quests_card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(quests_card)
	var qcol := UiKit.vbox(Design.SPACE_SM)
	quests_card.add_child(qcol)

	var qtitle := UiKit.micro("DAILY BATTLE MISSIONS")
	qtitle.add_theme_color_override("font_color", Design.TEAL)
	qcol.add_child(qtitle)

	for idx in data.quests.size():
		var quest: Dictionary = data.quests[idx]
		var done := bool(quest["done"])
		var claimed := bool(quest["claimed"])
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(String(quest["title"]), &"BodyLabel"))
		info.add_child(UiKit.caption("Progress: %s  ·  Reward: +%d Coins" % [
			String(quest["progress"]), int(quest["coins"])
		]))
		row.add_child(info)

		var qbtn := UiKit.button(
			"CLAIMED" if claimed else ("CLAIM" if done else "IN PROGRESS"),
			&"HudPlayButton" if (done and not claimed) else &"GlassButton"
		)
		qbtn.custom_minimum_size = Vector2(150, 42)
		qbtn.disabled = claimed or not done
		var q_idx := idx
		UiKit.on_press(qbtn, func() -> void:
			if data.claim_quest(q_idx):
				EventBus.toast_requested.emit(
					"Mission reward +%d Coins claimed!" % int(quest["coins"]), &"success"
				)
				rerender.call(1)
		, "confirm")
		row.add_child(qbtn)
		qcol.add_child(row)
