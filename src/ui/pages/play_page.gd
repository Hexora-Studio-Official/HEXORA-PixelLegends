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
var _estimate: Label


func build() -> void:
	body.add_child(header(&"play.title", &"play.subtitle", _build_region_badge()))
	body.add_child(_build_quick_card())
	body.add_child(_build_modes())
	body.add_child(_build_options())
	body.add_child(_build_search())
	body.add_child(_build_offline_card())


func _build_region_badge() -> Control:
	var row := UiKit.hbox(Design.SPACE_SM)
	var region := Settings.get_int("game/region")
	row.add_child(UiKit.pill(Loc.t(GameTypes.region_key(region)), Design.TEAL, &"TealChipPanel"))
	if Friends.is_in_party():
		row.add_child(UiKit.pill(
			Loc.t(&"play.party_size", {"count": Friends.party_size()}),
			Design.ACCENT, &"AccentChipPanel"))
	return row


func _build_quick_card() -> Control:
	var panel := UiKit.panel(&"BannerPanel")
	var row := UiKit.hbox(Design.SPACE_LG)
	panel.add_child(row)

	var column := UiKit.vbox(Design.SPACE_XXS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.subheading(Loc.t(&"play.quick")))
	column.add_child(UiKit.paragraph(Loc.t(&"play.quick.body"), 560.0, &"CaptionLabel"))
	row.add_child(column)

	var button := UiKit.button(Loc.t(&"play.quick.button"), &"PrimaryButton", &"bolt")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(button, func() -> void: _start_queue(_quick_pool(), true), "confirm")
	row.add_child(button)
	return panel


## Every ruleset the queue is allowed to pick from, minus anything that cannot
## run on this device right now.
func _quick_pool() -> Array[StringName]:
	var ids: Array[StringName] = []
	for mode in GameCatalog.matchmaking_pool():
		if _mode_available(mode):
			ids.append(mode.id)
	return ids


func _mode_available(mode: GameMode) -> bool:
	if Api.is_configured():
		return true
	# No backend: only what one phone can host over a hotspot.
	return mode.supports_lan and mode.max_players <= RoomService.MAX_LAN_PLAYERS


func _build_modes() -> Control:
	var column := UiKit.vbox(Design.SPACE_MD)
	column.add_child(UiKit.section_header(Loc.t(&"play.modes")))
	column.add_child(UiKit.paragraph(Loc.t(&"play.modes.hint"), 720.0, &"CaptionLabel"))

	var online_only := UiKit.micro(Loc.t(&"play.online_only"))
	column.add_child(online_only)

	var grid := UiKit.grid(2, Design.SPACE_MD)
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
	var column := UiKit.vbox(Design.SPACE_MD)
	column.add_child(UiKit.section_header(Loc.t(&"play.options")))

	var row := UiKit.hbox(Design.SPACE_MD)
	var ranked := UiKit.chip(Loc.t(&"play.ranked"), ranked_enabled)
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
	column.add_child(UiKit.paragraph(Loc.t(&"play.ranked.hint"), 720.0, &"CaptionLabel"))
	return column


func _build_search() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM)
	_estimate = UiKit.muted("")
	column.add_child(_estimate)

	_search_button = UiKit.button("", &"PrimaryButton", &"play")
	_search_button.custom_minimum_size = Vector2(0, 60)
	UiKit.on_press(_search_button, func() -> void: _start_queue(selected, false), "confirm")
	column.add_child(_search_button)
	return column


func _build_offline_card() -> Control:
	var column := card(&"rooms.hotspot.title")
	column.add_child(UiKit.paragraph(Loc.t(&"rooms.hotspot.desc"), 720.0, &"CaptionLabel"))

	var row := UiKit.hbox(Design.SPACE_MD)
	var host := UiKit.button(Loc.t(&"rooms.create"), &"OutlineButton", &"plus")
	UiKit.on_press(host, func() -> void: _open_rooms_tab(0))
	row.add_child(host)

	var join := UiKit.button(Loc.t(&"rooms.hotspot.discover"), &"OutlineButton", &"wifi")
	UiKit.on_press(join, func() -> void: _open_rooms_tab(2))
	row.add_child(join)
	column.add_child(row)
	return column


# ------------------------------------------------------------------ behaviour

## Ask the menu shell to open Rooms on a specific tab. Play does not own that
## page, so it does not reach into it: it asks the shell for the instance and
## tells it which tab to show.
func _open_rooms_tab(index: int) -> void:
	var shell := _find_shell()
	if shell == null:
		return
	shell.call("open_page", &"rooms")
	var rooms := shell.call("page", &"rooms") as RoomsPage
	if rooms != null:
		rooms.tab = index
		rooms.rebuild()


func _find_shell() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("open_page"):
			return node
		node = node.get_parent()
	return null


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
	var names := PackedStringArray()
	var total := 0.0
	for mode_id in selected:
		var mode := GameCatalog.resolve(mode_id)
		names.append(Loc.t(mode.short_key))
		total += float(Matchmaking.BASE_WAIT_SEC.get(mode_id, 14.0))
	var average := total / float(maxi(1, selected.size()))
	UiKit.set_label_text(_search_button, Loc.t(&"play.search", {"count": selected.size()}))
	_estimate.text = "%s · %s" % [
		" / ".join(names),
		Loc.t(&"play.estimated", {"time": _humanise(average)}),
	]


func _humanise(seconds: float) -> String:
	if seconds < 45.0:
		return "~%ds" % maxi(5, int(round(seconds / 5.0)) * 5)
	return Loc.t(&"common.minutes_short", {"value": maxi(1, int(round(seconds / 60.0)))})


func _start_queue(modes: Array[StringName], quick: bool) -> void:
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
		for mode_id in _cards.keys():
			UiKit.set_card_active(_cards[mode_id], selected.has(mode_id))
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
	_refresh()


func _sanitise(ids: Array[StringName]) -> Array[StringName]:
	var kept: Array[StringName] = []
	for mode_id in ids:
		var mode := GameCatalog.by_id(mode_id)
		if mode != null and _mode_available(mode):
			kept.append(mode_id)
	return kept
