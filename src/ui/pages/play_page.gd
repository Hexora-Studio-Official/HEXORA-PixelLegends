class_name PlayPage
extends MenuPage
## Deploy screen: pick rulesets, then queue.
##
## Selection is a *set*, not a single choice, because a real queue accepts
## several rulesets at once and starts whichever fills first. The UI keeps
## mode choice and match settings in the foreground, with one compact queue
## action instead of competing calls to action.
##
## Offline the pool is trimmed to what a hotspot can actually hold — queueing
## for a 100-player battle royale with no internet would be a lie with a
## progress bar on it.

var selected: Array[StringName] = []
var ranked_enabled: bool = false

var _cards: Dictionary = {}          ## mode id -> Button
var _mode_grid: GridContainer
var _mode_cards_stacked: bool = false
var _search_button: Button
var _ranked_button: Button
var _search_dock: PanelContainer


func build() -> void:
	if _search_dock != null and is_instance_valid(_search_dock):
		remove_child(_search_dock)
		_search_dock.queue_free()
		_search_dock = null
	_cards.clear()
	_mode_grid = null
	_mode_cards_stacked = false
	_ranked_button = null
	_search_button = null

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
	call_deferred("_fit_mode_grid")


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


func _build_modes() -> Control:
	var column := UiKit.vbox(Design.SPACE_SM)
	column.add_child(UiKit.section_header(Loc.t(&"play.modes")))
	var hint := UiKit.paragraph(Loc.t(&"play.select_hint"), 1120.0, &"CaptionLabel")
	hint.max_lines_visible = 2
	column.add_child(hint)

	var available_width := body.custom_minimum_size.x
	var columns := _mode_columns(available_width)
	_mode_cards_stacked = columns == 2
	_mode_grid = UiKit.grid(columns, Design.SPACE_SM)
	_mode_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_mode_grid()
	column.add_child(_mode_grid)
	return column


func _mode_columns(available_width: float) -> int:
	return 3 if available_width >= 820.0 else 2 if available_width >= 460.0 else 1


func _populate_mode_grid() -> void:
	if _mode_grid == null or not is_instance_valid(_mode_grid):
		return
	for child in _mode_grid.get_children():
		_mode_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	for mode in GameCatalog.matchmaking_pool():
		var available := _mode_available(mode)
		var card := UiKit.mode_card(
			mode, selected.has(mode.id), Callable(), _mode_cards_stacked)
		if not _mode_cards_stacked:
			card.custom_minimum_size.y = 88.0
		card.clip_contents = true
		card.disabled = not available
		if not available:
			card.tooltip_text = Loc.t(&"play.needs_online")
		else:
			card.pressed.connect(_toggle_mode.bind(mode.id))
			UiKit.on_hover(card)
		_cards[mode.id] = card
		_mode_grid.add_child(card)


func _fit_mode_grid() -> void:
	if _mode_grid == null or not is_instance_valid(_mode_grid):
		return
	var available_width := body.custom_minimum_size.x
	if available_width <= 0.0:
		available_width = body.size.x
	var columns := _mode_columns(available_width)
	var stacked := columns == 2
	if _mode_grid.columns != columns or _mode_cards_stacked != stacked:
		_mode_grid.columns = columns
		_mode_cards_stacked = stacked
		_populate_mode_grid()


func on_page_resized() -> void:
	_fit_mode_grid()
	_fit_search_button()


func _build_options() -> Control:
	var holder := UiKit.panel(&"CardPanel")
	var column := UiKit.vbox(Design.SPACE_SM)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(column)
	column.add_child(UiKit.section_header(Loc.t(&"play.options")))

	column.add_child(_build_option_row(
		&"play.ranked", &"play.ranked.hint", ranked_enabled, true))
	return holder


func _build_option_row(
		title_key: StringName, hint_key: StringName, enabled: bool, ranked: bool) -> Control:
	var option_enabled := enabled
	var row := UiKit.hbox(Design.SPACE_MD)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var details := UiKit.vbox(Design.SPACE_XXS)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiKit.label(Loc.t(title_key), &"BodyLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(title)
	if hint_key != &"":
		var resolved_hint := hint_key
		if ranked and not Api.is_configured():
			ranked_enabled = false
			option_enabled = false
			resolved_hint = &"play.ranked.offline"
		var hint := UiKit.label(Loc.t(resolved_hint), &"CaptionLabel")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.max_lines_visible = 2
		hint.custom_minimum_size.x = 0.0
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(hint)
	row.add_child(details)

	var toggle := Button.new()
	toggle.mouse_filter = Control.MOUSE_FILTER_PASS
	toggle.custom_minimum_size = Vector2(112, 56)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle.clip_text = true
	toggle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_option_button(toggle, option_enabled)
	if ranked:
		_ranked_button = toggle
		toggle.disabled = not Api.is_configured()
		if not toggle.disabled:
			UiKit.on_press(toggle, func() -> void:
				ranked_enabled = not ranked_enabled
				_set_option_button(_ranked_button, ranked_enabled)
			)
	row.add_child(toggle)
	return row


func _set_option_button(button: Button, enabled: bool) -> void:
	if button == null:
		return
	button.theme_type_variation = &"ChipButtonActive" if enabled else &"ChipButton"
	button.text = Loc.t(&"common.enabled" if enabled else &"common.disabled")


func _build_search() -> Button:
	_search_button = UiKit.button("", &"PrimaryButton", &"play")
	_search_button.custom_minimum_size = Vector2(0, 56)
	_search_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(_search_button, func() -> void: _start_queue(selected), "confirm")
	_fit_search_button()
	return _search_button


func _fit_search_button() -> void:
	if _search_button == null or not is_instance_valid(_search_button):
		return
	var available_width := size.x
	if available_width <= 0.0:
		available_width = body.custom_minimum_size.x
	if available_width <= 0.0:
		return
	_search_button.custom_minimum_size.x = minf(460.0,
		maxf(0.0, available_width - Design.SPACE_XL * 2.0))


func _attach_search_dock(search: Button) -> void:
	const DOCK_HEIGHT := 84.0
	scroll.offset_bottom = -DOCK_HEIGHT

	var dock := UiKit.panel(&"ActionDockPanel")
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_top = -DOCK_HEIGHT
	dock.offset_bottom = 0.0
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(center)
	center.add_child(search)
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
	UiKit.set_label_text(_search_button, Loc.t(&"play.search", {
		"count": selected.size(),
	}))


func _start_queue(modes: Array[StringName]) -> void:
	if modes.is_empty():
		EventBus.toast_requested.emit(Loc.t(&"play.keep_one"), &"warning")
		return
	var result := Matchmaking.start_queue(modes.duplicate(), Settings.get_int("game/region"),
		ranked_enabled and Api.is_configured())
	if not bool(result["ok"]):
		_report(result)
		return
	# The overlay owns the queue UI from here; this page just hands it the turn.
	EventBus.matchmaking_state_changed.emit(GameTypes.MatchmakingState.SEARCHING)


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
