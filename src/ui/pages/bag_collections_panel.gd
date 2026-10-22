class_name BagCollectionsPanel
extends RefCounted
## Player Inventory (backpack items, trial cards, chests) and Cosmetics
## Collections (skins, recall FX, elimination FX, avatar frames, emotes).

const INV_CATS := ["All", "Consumables", "Trials", "Chests"]
const COL_GROUPS := [
	{"id": "skin", "label": "Skins"},
	{"id": "recall", "label": "Recall FX"},
	{"id": "elim", "label": "Elimination FX"},
	{"id": "frame", "label": "Avatar Frames"},
	{"id": "emote", "label": "Emotes"},
]


static func open(host: Control, data: HubPreviewData, initial_tab: int = 0) -> HubOverlayShell:
	var shell := HubOverlayShell.open(
		host,
		"INVENTORY & COLLECTIONS",
		&"bag",
		"Manage backpack consumables, trial packs, battle effects, and skins"
	)
	var state := {"tab": initial_tab, "inv_cat": "All", "col_group": "skin"}

	var render_ref: Array[Callable] = []
	var render := func(tab_idx: int) -> void:
		state["tab"] = tab_idx
		shell.clear_body()
		if tab_idx == 0:
			_build_inventory_tab(shell, data, state, render_ref[0])
		else:
			_build_collections_tab(shell, data, state, render_ref[0])
	render_ref.append(render)

	shell.set_tabs(["INVENTORY", "COLLECTIONS"], initial_tab, render)
	render.call(initial_tab)
	return shell


static func _build_inventory_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var filter_row := HFlowContainer.new()
	filter_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	for raw_cat in INV_CATS:
		var picked: String = String(raw_cat)
		var chip := UiKit.chip(picked, String(state["inv_cat"]) == picked)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["inv_cat"] = picked
			rerender.call(0)
		)
		filter_row.add_child(chip)
	shell.body.add_child(filter_row)

	var grid := UiKit.grid(2, Design.SPACE_MD)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(grid)

	for idx in data.inventory.size():
		var entry: Dictionary = data.inventory[idx]
		if String(state["inv_cat"]) != "All" and String(entry["cat"]) != String(state["inv_cat"]):
			continue
		var qty := int(entry["qty"])
		if qty <= 0:
			continue
		var card := UiKit.panel(&"HudCardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UiKit.vbox(Design.SPACE_XS)
		card.add_child(col)

		var head := UiKit.hbox(Design.SPACE_SM)
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(HexIcon.make(&"bag", Design.ACCENT_HI, 24.0))
		var title := UiKit.label(String(entry["name"]), &"BodyLabel")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UiKit.pill("×%d" % qty, Design.TEAL, &"TealChipPanel"))
		col.add_child(head)

		col.add_child(UiKit.paragraph(String(entry["desc"]), 460.0))

		var use_btn := UiKit.button("USE / OPEN (PREVIEW)", &"GlassButton", &"check")
		use_btn.custom_minimum_size = Vector2(0, 42)
		var item_index := idx
		UiKit.on_press(use_btn, func() -> void:
			data.inventory[item_index]["qty"] = maxi(0, int(data.inventory[item_index]["qty"]) - 1)
			data.coins += 150
			data.changed.emit()
			EventBus.toast_requested.emit(
				"Used %s (+150 Coins preview reward)." % String(entry["name"]), &"success"
			)
			rerender.call(0)
		, "confirm")
		col.add_child(use_btn)
		grid.add_child(card)


static func _build_collections_tab(
	shell: HubOverlayShell, data: HubPreviewData, state: Dictionary, rerender: Callable
) -> void:
	var group_row := HFlowContainer.new()
	group_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	for raw_grp in COL_GROUPS:
		var grp: Dictionary = raw_grp
		var gid := String(grp["id"])
		var chip := UiKit.chip(String(grp["label"]), String(state["col_group"]) == gid)
		chip.custom_minimum_size.y = 42.0
		UiKit.on_press(chip, func() -> void:
			state["col_group"] = gid
			rerender.call(1)
		)
		group_row.add_child(chip)
	shell.body.add_child(group_row)

	var active_group := String(state["col_group"])
	var equipped_id := String(data.equipped_cosmetics.get(active_group, ""))
	var entries: Array = data.collections.get(active_group, [])

	var grid := UiKit.grid(3, Design.SPACE_MD)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.body.add_child(grid)

	for raw_item in entries:
		var item: Dictionary = raw_item
		var cid := String(item["id"])
		var is_eq := cid == equipped_id
		var owned := bool(item["owned"])
		var card := UiKit.panel(&"HudCardActivePanel" if is_eq else &"HudCardPanel")
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := UiKit.vbox(Design.SPACE_SM)
		card.add_child(col)

		var rarity := String(item["rarity"])
		var tone := Design.ACCENT_HI if rarity == "LEGENDARY" else (
			Design.VIOLET if rarity == "EPIC" else Design.TEAL
		)
		col.add_child(UiKit.pill(rarity, tone, &"ChipPanel"))
		col.add_child(UiKit.label(String(item["name"]), &"BodyLabel"))

		var btn := UiKit.button(
			"EQUIPPED" if is_eq else ("EQUIP" if owned else "LOCKED · SHOP"),
			&"HudPlayButton" if (owned and not is_eq) else &"GlassButton",
			&"check" if is_eq else &""
		)
		btn.disabled = is_eq or not owned
		UiKit.on_press(btn, func() -> void:
			data.equipped_cosmetics[active_group] = cid
			data.changed.emit()
			EventBus.toast_requested.emit("Equipped %s." % String(item["name"]), &"success")
			rerender.call(1)
		, "confirm")
		col.add_child(btn)
		grid.add_child(card)
