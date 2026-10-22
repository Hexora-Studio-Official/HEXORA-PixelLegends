class_name RankingsPanel
extends RefCounted
## Personal statistics, Regional leaderboard, and Global leaderboard panels.


static func open(host: Control, data: HubPreviewData, initial_tab: int = 0) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"STATS & LEADERBOARDS",
		&"chart",
		"Personal performance breakdown, Regional standings, and Global top players"
	)

	var render := func(tab_idx: int) -> void:
		shell.clear_body()
		match tab_idx:
			0: _build_personal_tab(shell, data)
			1: _build_leaderboard_tab(shell, data.regional_leaders, "EUROPE / REGIONAL STANDINGS", "#42 · Gold II (640 pts)")
			_: _build_leaderboard_tab(shell, data.global_leaders, "GLOBAL TOP 100 LEGENDS", "Unranked (Top 10,000+)")

	shell.set_tabs(["PERSONAL STATS", "REGIONAL RANKING", "GLOBAL RANKING"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_personal_tab(shell: HubOverlayShell, data: HubPreviewData) -> void:
	var tiles := UiKit.grid(4, Design.SPACE_SM)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_child(UiKit.stat_tile("Avg KDA Ratio", "4.28", Design.ACCENT_HI))
	tiles.add_child(UiKit.stat_tile("Teamfight Part.", "71.4%", Design.TEAL))
	tiles.add_child(UiKit.stat_tile("Turret Damage / Min", "1,420", Design.WARNING))
	tiles.add_child(UiKit.stat_tile("Longest Win Streak", "7 Wins", Design.SUCCESS))
	shell.body.add_child(tiles)

	var card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(card)
	var col := UiKit.vbox(Design.SPACE_SM)
	card.add_child(col)

	var heading := UiKit.micro("PERFORMANCE BY MODE (PREVIEW SAMPLE)")
	heading.add_theme_color_override("font_color", Design.ACCENT_HI)
	col.add_child(heading)

	for row_data: Dictionary in data.personal_mode_stats:
		var item_card := UiKit.panel(&"InsetPanel")
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		item_card.add_child(row)

		var mname := UiKit.subheading(String(row_data["mode"]))
		mname.add_theme_font_size_override("font_size", Design.FONT_LEAD)
		mname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mname)

		row.add_child(UiKit.pill("MATCHES: %d" % int(row_data["matches"]), Design.TEXT, &"ChipPanel"))
		row.add_child(UiKit.pill("WIN RATE: %s" % String(row_data["win_rate"]), Design.SUCCESS, &"SuccessChipPanel"))
		row.add_child(UiKit.pill("KDA: %s" % String(row_data["kda"]), Design.TEAL, &"TealChipPanel"))
		row.add_child(UiKit.pill("MVP: %d" % int(row_data["mvp"]), Design.ACCENT_HI, &"AccentChipPanel"))
		col.add_child(item_card)


static func _build_leaderboard_tab(
	shell: HubOverlayShell, entries: Array[Dictionary], heading_text: String, my_rank_text: String
) -> void:
	var card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(card)
	var col := UiKit.vbox(Design.SPACE_SM)
	card.add_child(col)

	var top := UiKit.hbox(Design.SPACE_SM)
	var heading := UiKit.micro(heading_text)
	heading.add_theme_color_override("font_color", Design.ACCENT_HI)
	top.add_child(heading)
	top.add_child(UiKit.spacer())
	top.add_child(UiKit.pill("YOUR STANDING · " + my_rank_text, Design.TEAL, &"TealChipPanel"))
	col.add_child(top)

	for entry: Dictionary in entries:
		var place := int(entry["place"])
		var row_panel := UiKit.panel(&"HudCardActivePanel" if place == 1 else &"InsetPanel")
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row_panel.add_child(row)

		var badge_color := Design.ACCENT_HI if place == 1 else (
			Design.TEAL if place <= 3 else Design.TEXT_MUTED
		)
		row.add_child(UiKit.pill("#%d" % place, badge_color, &"ChipPanel"))

		var name_col := UiKit.vbox(2)
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.add_child(UiKit.label(
			"%s  %s" % [String(entry["squad"]), String(entry["name"])], &"BodyLabel"
		))
		name_col.add_child(UiKit.caption(String(entry["tier"])))
		row.add_child(name_col)

		row.add_child(UiKit.pill("WIN " + String(entry["win"]), Design.SUCCESS, &"SuccessChipPanel"))
		row.add_child(UiKit.pill(String(entry["points"]), Design.ACCENT_HI, &"AccentChipPanel"))
		col.add_child(row_panel)
