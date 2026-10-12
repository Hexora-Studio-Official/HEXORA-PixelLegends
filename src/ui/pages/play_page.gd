class_name PlayPage
extends MenuPage
## Deploy screen: pick rulesets, then queue.
##
## Selection is a *set*, not a single choice, because a real queue accepts
## several rulesets at once and starts whichever fills first. The UI says that
## out loud instead of hiding it behind a dropdown: cards toggle, the button
## shows how many are selected, and the estimate is the average of the pool.
##
## Offline the pool is trimmed to what a hotspot can actually hold — queueing
## for a 100-player battle royale with no internet would be a lie with a
## progress bar on it.

var selected: Array[StringName] = []
var ranked_enabled: bool = true
var fill_squad: bool = true

var _cards: Dictionary = {}          ## mode id -> Button
var _search_button: Button
var _quick_button: Button
var _estimate: Label
var _search_dock: PanelContainer


func build() -> void:
	if _search_dock != null and is_instance_valid(_search_dock):
		remove_child(_search_dock)
		_search_dock.queue_free()
		_search_dock = null
	var subtitle := &"" if OS.has_feature("mobile") else &"play.subtitle"
	body.add_child(header(&"play.title", subtitle, _build_region_badge()))
	body.add_child(_build_modes())
	body.add_child(_build_options())
	var search := _build_search()
	if OS.has_feature("mobile"):
		_attach_search_dock(search)
	else:
		body.add_child(search)
	_refresh()


func _build_region_badge() -> Control:
	var row := UiKit.hbox(Design.SPACE_SM)
	var region := Settings.get_int("game/region")
	row.add_child(UiKit.pill(Loc.t(GameTypes.region_key(region)), Design.TEAL, &"TealChipPanel"))
	if Friends.is_in_party():
		row.add_child(UiKit.pill(
			Loc.t(&"play.party_size", {"count": Friends.party_size()}),
			Design.ACCENT, &"AccentChipPanel"))
	return row


func _mode_available(mode: GameMode) -> bool:
	if Api.is_configured():
		return true
	# Matchmaking mirrors the local room cap only for battle royale; smaller
	# LAN modes can still fill with the capped local pool.
	return mode.supports_lan and not (
		mode.is_battle_royale and mode.max_players > RoomService.MAX_LAN_PLAYERS
	)


func _quick_pool() -> Array[StringName]:
	var ids: Array[StringName] = []
	for mode in GameCatalog.matchmaking_pool():
		if _mode_available(mode):
			ids.append(mode.id)
	return ids


func _build_modes() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM if OS.has_feature("mobile") else Design.SPACE_MD)
	column.add_child(UiKit.section_header(Loc.t(&"play.modes")))
	column.add_child(UiKit.paragraph(Loc.t(&"play.modes.hint"), 1120.0, &"CaptionLabel"))
	column.add_child(UiKit.micro(Loc.t(&"play.online_only")))

	var grid := UiKit.grid(3, Design.SPACE_MD)
	_cards.clear()
	for mode in GameCatalog.matchmaking_pool():
		var available := _mode_available(mode)
		var card := UiKit.mode_card(mode, selected.has(mode.id))
		card.disabled = not available
		if not available:
			card.tooltip_text = Loc.t(&"play.needs_online")
		else:
			card.pressed.connect(_toggle_mode.bind(mode.id))
			UiKit.on_hover(card)
		_cards[mode.id] = card
		grid.add_child(card)
	column.add_child(grid)
	return column


func _build_options() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM if OS.has_feature("mobile") else Design.SPACE_MD)
	column.add_child(UiKit.section_header(Loc.t(&"play.options")))

	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", Design.SPACE_SM)
	row.add_theme_constant_override("v_separation", Design.SPACE_SM)
	var ranked := UiKit.chip(Loc.t(&"play.ranked"), ranked_enabled)
	ranked.tooltip_text = Loc.t(&"play.ranked.hint")
	UiKit.on_press(ranked, func() -> void:
		ranked_enabled = not ranked_enabled
		UiKit.set_chip_active(ranked, ranked_enabled)
	)
	row.add_child(ranked)

	var squad := UiKit.chip(Loc.t(&"play.fill_squad"), fill_squad)
	UiKit.on_press(squad, func() -> void:
		fill_squad = not fill_squad
		UiKit.set_chip_active(squad, fill_squad)
	)
	row.add_child(squad)
	column.add_child(row)
	return column


func _build_search() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estimate = UiKit.muted("")
	_estimate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estimate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_estimate)

	var actions := UiKit.hbox(Design.SPACE_SM)
	_search_button = UiKit.button("", &"PrimaryButton", &"play")
	_search_button.custom_minimum_size = Vector2(0, 64)
	_search_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(_search_button, func() -> void: _start_queue(selected), "confirm")
	actions.add_child(_search_button)

	_quick_button = UiKit.button(Loc.t(&"play.quick.button"), &"OutlineButton", &"bolt")
	_quick_button.custom_minimum_size = Vector2(0, 64)
	_quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_press(_quick_button, func() -> void: _start_queue(_quick_pool(), true), "confirm")
	actions.add_child(_quick_button)

	column.add_child(actions)
	return column


func _attach_search_dock(search: Control) -> void:
	const DOCK_HEIGHT := 140.0
	scroll.offset_bottom = -DOCK_HEIGHT

	var dock := UiKit.panel(&"TopBarPanel")
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -DOCK_HEIGHT
	dock.offset_bottom = 0.0
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	dock.add_child(search)
	add_child(dock)
	_search_dock = dock


# ------------------------------------------------------------------ behaviour

func _toggle_mode(mode_id: StringName) -> void:
	if selected.has(mode_id):
		# Never let the selection go empty: an empty set means "everything",
		# which is not what tapping a selected card means. Deselecting the last
		# one would silently widen the search instead of narrowing it.
		if selected.size() == 1:
			Audio.play_ui("error", 1.0, -8.0)
			EventBus.toast_requested.emit(Loc.t(&"play.keep_one"), &"warning")
			return
		selected.erase(mode_id)
		Audio.play_ui("toggle_off")
	else:
		selected.append(mode_id)
		Audio.play_ui("toggle_on")
	Controls.haptic(8)

	var card: Button = _cards.get(mode_id, null)
	if card != null:
		UiKit.set_card_active(card, selected.has(mode_id))
	_refresh()


func _refresh() -> void:
	if _search_button == null:
		return
	var total := 0.0
	for mode_id in selected:
		total += float(Matchmaking.BASE_WAIT_SEC.get(mode_id, 14.0))
	var average := total / float(maxi(1, selected.size()))
	UiKit.set_label_text(_search_button, Loc.t(&"play.search", {"count": selected.size()}))
	_estimate.text = "%s · %s · %s" % [
		Loc.t(&"play.search.count", {"count": selected.size()}),
		Loc.t(&"play.estimated"),
		_humanise(average),
	]


func _humanise(seconds: float) -> String:
	if seconds < 45.0:
		return "~%ds" % maxi(5, int(round(seconds / 5.0)) * 5)
	return Loc.t(&"common.minutes_short", {"value": maxi(1, int(round(seconds / 60.0)))})


func _start_queue(modes: Array[StringName], quick: bool = false) -> void:
	if modes.is_empty():
		EventBus.toast_requested.emit(Loc.t(&"play.keep_one"), &"warning")
		return
	var result := Matchmaking.start_queue(modes.duplicate(), Settings.get_int("game/region"),
		ranked_enabled)
	if not bool(result["ok"]):
		_report(result)
		return
	# The overlay owns the queue UI from here; this page just hands it the turn.
	EventBus.matchmaking_state_changed.emit(GameTypes.MatchmakingState.SEARCHING)
	if quick:
		selected = modes.duplicate()
		for mode_id: StringName in _cards:
			var card := _cards[mode_id] as Button
			UiKit.set_card_active(card, selected.has(mode_id))
		_refresh()


func _report(result: Dictionary) -> void:
	match String(result.get("reason", "")):
		"party_too_large":
			EventBus.toast_requested.emit(Loc.t(&"play.party_too_big", {
				"max": int(result.get("max_squad", 1)),
			}), &"warning")
		"no_modes":
			EventBus.toast_requested.emit(Loc.t(&"play.needs_online"), &"warning")
		"already_searching":
			EventBus.toast_requested.emit(Loc.t(&"toast.queued"), &"info")
		_:
			EventBus.toast_requested.emit(Loc.t(&"toast.phase_notice", {
				"phase": Loc.t(&"common.phase_two"),
			}), &"warning")
	Audio.play_ui("error")


func on_shown() -> void:
	# The player may have joined a party or switched region on another page.
	selected = _sanitise(selected)
	if selected.is_empty():
		selected = [&"tdm"]
	for mode_id: StringName in _cards:
		var card := _cards[mode_id] as Button
		UiKit.set_card_active(card, selected.has(mode_id))
	_refresh()


func _sanitise(ids: Array[StringName]) -> Array[StringName]:
	var kept: Array[StringName] = []
	for mode_id in ids:
		var mode := GameCatalog.by_id(mode_id)
		if mode != null and _mode_available(mode):
			kept.append(mode_id)
	return kept
