class_name HeroesBuildsPanel
extends RefCounted
## Unified MOBA preparation suite covering Heroes, 6-slot Hero Builds, and the
## in-match Item Encyclopedia — each directly addressable from the main menu.

const ROLES := ["All", "Tank", "Fighter", "Assassin", "Mage", "Marksman", "Support"]
const ITEM_CATS := ["All", "Attack", "Magic", "Defense", "Movement", "Roam"]


static func open(host: Control, data: HubPreviewData, initial_tab: int = 0) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"HEROES, BUILDS & ITEMS",
		&"hero",
		"Inspect original 5v5 heroes, customize 6-slot equipment presets, and browse items"
	)
	var state := {
		"tab": initial_tab,
		"role": "All",
		"hero_id": data.featured_hero_id,
		"slot_index": 0,
		"build_index": 0,
		"item_cat": "All",
	}

	var render_ref: Array[Callable] = []
	var render := func(tab_idx: int) -> void:
		state["tab"] = tab_idx
		shell.clear_body()
		match tab_idx:
			0: _build_heroes_tab(shell, data, state, render_ref[0])
			1: _build_builds_tab(shell, data, state, render_ref[0])
			_: _build_items_tab(shell, data, state, render_ref[0])
	render_ref.append(render)

	shell.set_tabs(["HEROES", "BUILDS", "ITEMS"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_heroes_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var role_bar := HFlowContainer.new()
	role_bar.add_theme_constant_override("h_separation", Design.SPACE_XS)
	role_bar.add_theme_constant_override("v_separation", Design.SPACE_XS)
	for raw_role in ROLES:
		var picked: String = String(raw_role)
		var chip := UiKit.chip(picked, String(state["role"]) == picked)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["role"] = picked
			rerender.call(0)
		)
		role_bar.add_child(chip)
	shell.body.add_child(role_bar)

	var split := UiKit.grid(2, Design.SPACE_MD)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(split)

	var roster_col := UiKit.vbox(Design.SPACE_SM)
	roster_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(roster_col)

	for hero: Dictionary in data.heroes:
		var role_name := String(hero["role"])
		if String(state["role"]) != "All" and role_name != String(state["role"]):
			continue
		var hid := String(hero["id"])
		var active := hid == String(state["hero_id"])
		var card := UiKit.panel(&"HudCardActivePanel" if active else &"HudCardPanel")
		roster_col.add_child(card)
		var row := UiKit.hbox(Design.SPACE_MD)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(row)

		var badge_tone: Color = hero["tier_color"]
		row.add_child(HexIcon.make(&"hero", badge_tone, 30.0, 2.2))

		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label(String(hero["name"]), &"BodyLabel"))
		info.add_child(UiKit.caption("%s · %s · %s" % [
			role_name, String(hero["lane"]), String(hero["specialty"])
		]))
		row.add_child(info)

		var status_text := "OWNED" if bool(hero["owned"]) else ("%d COINS" % int(hero["cost_coins"]))
		row.add_child(UiKit.pill(
			status_text,
			Design.SUCCESS if bool(hero["owned"]) else Design.ACCENT_HI,
			&"ChipPanel"
		))

		var inspect_btn := UiKit.button("VIEW", &"GlassButton")
		inspect_btn.custom_minimum_size = Vector2(96, 42)
		UiKit.on_press(inspect_btn, func() -> void:
			state["hero_id"] = hid
			rerender.call(0)
		)
		row.add_child(inspect_btn)

	# Detail pane for selected hero
	var selected := data.hero_by_id(String(state["hero_id"]))
	var detail := UiKit.panel(&"HudCardPanel")
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(detail)

	var dcol := UiKit.vbox(Design.SPACE_SM)
	detail.add_child(dcol)

	var dhead := UiKit.subheading(String(selected["name"]))
	dhead.add_theme_color_override("font_color", selected["tier_color"])
	dcol.add_child(dhead)
	dcol.add_child(UiKit.caption("%s  ·  %s  ·  %s" % [
		String(selected["role"]), String(selected["lane"]), String(selected["specialty"])
	]))

	var stats_grid := UiKit.grid(2, Design.SPACE_XS)
	stats_grid.add_child(UiKit.stat_tile("Base HP", str(int(selected["hp"])), Design.SUCCESS))
	stats_grid.add_child(UiKit.stat_tile("Attack", str(int(selected["atk"])), Design.WARNING))
	stats_grid.add_child(UiKit.stat_tile("Defense", str(int(selected["def"])), Design.TEAL))
	stats_grid.add_child(UiKit.stat_tile("Move Speed", str(int(selected["speed"])), Design.ACCENT_HI))
	dcol.add_child(stats_grid)

	dcol.add_child(UiKit.divider())
	for ability_key in ["passive", "skill_1", "skill_2", "ultimate"]:
		dcol.add_child(UiKit.paragraph(String(selected[ability_key]).strip_edges(), 460.0))

	var dactions := UiKit.hbox(Design.SPACE_SM)
	var showcase_btn := UiKit.button("SET MAIN HERO", &"GlassButton", &"star")
	showcase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(showcase_btn, func() -> void:
		data.featured_hero_id = String(selected["id"])
		data.changed.emit()
		EventBus.toast_requested.emit("%s set as featured hero." % String(selected["name"]), &"success")
	)
	dactions.add_child(showcase_btn)

	var edit_build_btn := UiKit.button("CUSTOMIZE BUILD", &"HudPlayButton", &"hammer")
	edit_build_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(edit_build_btn, func() -> void:
		state["build_index"] = 0
		shell.select_tab(1)
	, "confirm")
	dactions.add_child(edit_build_btn)
	dcol.add_child(dactions)


static func _build_builds_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var hero_row := HFlowContainer.new()
	hero_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	hero_row.add_theme_constant_override("v_separation", Design.SPACE_XS)
	for hero: Dictionary in data.heroes:
		var hid := String(hero["id"])
		var chip := UiKit.chip(String(hero["name"]), hid == String(state["hero_id"]))
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["hero_id"] = hid
			state["build_index"] = 0
			state["slot_index"] = 0
			rerender.call(1)
		)
		hero_row.add_child(chip)
	shell.body.add_child(hero_row)

	var cur_hero_id := String(state["hero_id"])
	var presets: Array = data.hero_builds.get(cur_hero_id, [])
	if presets.is_empty():
		return
	var b_idx := clampi(int(state["build_index"]), 0, presets.size() - 1)
	var preset: Dictionary = presets[b_idx]
	var slots: Array = preset["slots"]

	var preset_card := UiKit.panel(&"HudCardPanel")
	shell.body.add_child(preset_card)
	var pcol := UiKit.vbox(Design.SPACE_SM)
	preset_card.add_child(pcol)

	var top_bar := UiKit.hbox(Design.SPACE_SM)
	for idx in presets.size():
		var p_dict: Dictionary = presets[idx]
		var p_chip := UiKit.chip(String(p_dict["title"]), idx == b_idx)
		var target_idx := idx
		UiKit.on_press(p_chip, func() -> void:
			state["build_index"] = target_idx
			rerender.call(1)
		)
		top_bar.add_child(p_chip)
	top_bar.add_child(UiKit.spacer())

	var total_gold := 0
	for item_id in slots:
		total_gold += int(data.item_by_id(String(item_id))["cost"])
	top_bar.add_child(UiKit.pill("TOTAL COST · %d GOLD" % total_gold, Design.ACCENT_HI, &"AccentChipPanel"))
	pcol.add_child(top_bar)

	var slot_grid := UiKit.grid(6, Design.SPACE_SM)
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s_idx in 6:
		var item_entry := data.item_by_id(String(slots[s_idx]))
		var selected_slot := s_idx == int(state["slot_index"])
		var s_card := UiKit.panel(&"HudCardActivePanel" if selected_slot else &"InsetPanel")
		s_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var scol := UiKit.vbox(4)
		scol.alignment = BoxContainer.ALIGNMENT_CENTER
		s_card.add_child(scol)
		scol.add_child(UiKit.micro("SLOT %d" % (s_idx + 1)))
		var ilbl := UiKit.caption(String(item_entry["name"]))
		ilbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ilbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scol.add_child(ilbl)
		var pick_slot := UiKit.button("EDIT" if not selected_slot else "EDITING", &"GlassButton")
		pick_slot.custom_minimum_size = Vector2(0, 38)
		var target_slot := s_idx
		UiKit.on_press(pick_slot, func() -> void:
			state["slot_index"] = target_slot
			rerender.call(1)
		)
		scol.add_child(pick_slot)
		slot_grid.add_child(s_card)
	pcol.add_child(slot_grid)

	pcol.add_child(UiKit.micro(
		"TAP AN ITEM BELOW TO ASSIGN IT TO SLOT %d:" % (int(state["slot_index"]) + 1)
	))
	var pool := UiKit.grid(2, Design.SPACE_SM)
	for item: Dictionary in data.items:
		var row_card := UiKit.panel(&"InsetPanel")
		var r := UiKit.hbox(Design.SPACE_SM)
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		row_card.add_child(r)
		var info := UiKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label("%s  (%dg)" % [String(item["name"]), int(item["cost"])], &"BodyLabel"))
		info.add_child(UiKit.caption(String(item["stats"])))
		r.add_child(info)
		var equip_btn := UiKit.button("EQUIP", &"HudLobbyButton")
		equip_btn.custom_minimum_size = Vector2(104, 42)
		var new_id := String(item["id"])
		UiKit.on_press(equip_btn, func() -> void:
			slots[int(state["slot_index"])] = new_id
			data.changed.emit()
			EventBus.toast_requested.emit("Updated Slot %d with %s." % [
				int(state["slot_index"]) + 1, String(item["name"])
			], &"success")
			rerender.call(1)
		)
		r.add_child(equip_btn)
		pool.add_child(row_card)
	shell.body.add_child(pool)


static func _build_items_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var cat_row := HFlowContainer.new()
	cat_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	cat_row.add_theme_constant_override("v_separation", Design.SPACE_XS)
	for raw_cat in ITEM_CATS:
		var target_cat: String = String(raw_cat)
		var chip := UiKit.chip(target_cat, String(state["item_cat"]) == target_cat)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["item_cat"] = target_cat
			rerender.call(2)
		)
		cat_row.add_child(chip)
	shell.body.add_child(cat_row)

	var grid := UiKit.grid(2, Design.SPACE_MD)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(grid)

	for item: Dictionary in data.items:
		if String(state["item_cat"]) != "All" and String(item["cat"]) != String(state["item_cat"]):
			continue
		var card := UiKit.panel(&"HudCardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UiKit.vbox(Design.SPACE_XS)
		card.add_child(col)

		var head := UiKit.hbox(Design.SPACE_SM)
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(HexIcon.make(&"crystal", Design.ACCENT_HI, 24.0, 2.0, Design.TEAL))
		var name_lbl := UiKit.label(String(item["name"]), &"BodyLabel")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_lbl)
		head.add_child(UiKit.pill(String(item["cat"]), Design.TEAL, &"TealChipPanel"))
		head.add_child(UiKit.pill("%d G" % int(item["cost"]), Design.ACCENT_HI, &"AccentChipPanel"))
		col.add_child(head)

		var stats_lbl := UiKit.caption(String(item["stats"]))
		stats_lbl.add_theme_color_override("font_color", Design.SUCCESS)
		col.add_child(stats_lbl)
		col.add_child(UiKit.paragraph(String(item["passive"]), 460.0))
		grid.add_child(card)
