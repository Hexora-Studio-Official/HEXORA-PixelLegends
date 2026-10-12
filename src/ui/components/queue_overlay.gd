class_name QueueOverlay
extends Control
## The "finding a match" overlay.
##
## Covers the whole screen while matchmaking runs, and re-renders itself from
## the Matchmaking service's state rather than owning any of it. That means the
## queue keeps running if the player navigates to another page, and cancelling
## from anywhere produces the same result.
##
## When the local simulation is driving (no backend configured) the overlay says
## so on screen. A queue that quietly fabricates opponents is the kind of thing
## that ships by accident.

enum Mode { HIDDEN, SEARCHING, FOUND, CONNECTING }

var _mode: int = Mode.HIDDEN

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _elapsed_label: Label
var _pool_label: Label
var _modes_label: Label
var _simulated_pill: Control
var _radar: _Radar
var _actions: HBoxContainer
var _secondary_actions: HBoxContainer
var _accept_countdown: Label

var _found_ticket: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	layout_direction = Loc.layout_direction()

	_dim = ColorRect.new()
	_dim.color = Color(Design.BG.r, Design.BG.g, Design.BG.b, 0.88)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	_panel = UiKit.panel(&"CardPanel")
	_panel.custom_minimum_size = Vector2(560, 0)
	centre.add_child(_panel)

	var column := UiKit.vbox(Design.SPACE_LG)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(column)

	_radar = _Radar.new()
	_radar.custom_minimum_size = Vector2(160, 160)
	_radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_radar)

	_title = UiKit.heading(Loc.t(&"queue.title"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_subtitle = UiKit.muted(Loc.t(&"queue.searching"))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	column.add_child(UiKit.divider())

	var stats := UiKit.hbox(Design.SPACE_LG)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(_build_stat(&"queue.elapsed", "00:00"))
	_elapsed_label = stats.get_child(stats.get_child_count() - 1).get_meta(&"value_label")
	stats.add_child(_build_stat(&"queue.players", "0"))
	_pool_label = stats.get_child(stats.get_child_count() - 1).get_meta(&"value_label")
	stats.add_child(_build_stat(&"play.estimated", Matchmaking.estimated_wait_label()))
	column.add_child(stats)

	_modes_label = UiKit.caption("")
	_modes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_modes_label)

	_simulated_pill = UiKit.pill(Loc.t(&"common.phase_two"), Design.WARNING)
	_simulated_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_simulated_pill)

	_accept_countdown = UiKit.label("", &"TealLabel")
	_accept_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_accept_countdown.visible = false
	column.add_child(_accept_countdown)

	_actions = UiKit.hbox(Design.SPACE_MD)
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_actions)

	_secondary_actions = UiKit.hbox(Design.SPACE_MD)
	_secondary_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_secondary_actions)

	EventBus.matchmaking_state_changed.connect(_on_state_changed)
	EventBus.matchmaking_tick.connect(_on_tick)
	EventBus.matchmaking_found.connect(_on_found)
	EventBus.matchmaking_cancelled.connect(_on_cancelled)
	EventBus.language_changed.connect(_on_language_changed)


func _build_stat(caption_key: StringName, initial: String) -> Control:
	var tile := UiKit.stat_tile(Loc.t(caption_key), initial, Design.TEXT)
	return tile


func is_open() -> bool:
	return _mode != Mode.HIDDEN


func open() -> void:
	if is_open():
		return
	visible = true
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_render()


func close() -> void:
	if not is_open():
		return
	_mode = Mode.HIDDEN
	Audio.play_ui("back", 1.0, -4.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_callback(func() -> void:
		visible = false
		_radar.set_scanning(false)
	)


# ------------------------------------------------------------------ rendering

func _on_state_changed(state: int) -> void:
	match state:
		GameTypes.MatchmakingState.SEARCHING:
			if not is_open():
				open()
			_mode = Mode.SEARCHING
			_radar.set_scanning(true)
			Audio.play_ui("search_pulse", 1.0, -8.0)
		GameTypes.MatchmakingState.FOUND:
			_mode = Mode.FOUND
			_radar.set_scanning(false)
		GameTypes.MatchmakingState.CONNECTING:
			_mode = Mode.CONNECTING
		GameTypes.MatchmakingState.IDLE:
			close()
	_render()


func _on_tick(elapsed: float, eta: float, players: int, expanding: bool) -> void:
	if _mode != Mode.SEARCHING:
		return
	if _elapsed_label != null:
		_elapsed_label.text = _format_clock(elapsed)
	if _pool_label != null:
		_pool_label.text = str(players)
	if _subtitle != null:
		_subtitle.text = Loc.t(&"queue.expand") if expanding else Loc.t(&"queue.searching")
	if _radar != null:
		# Progress towards the estimated wait drives the sweep speed, so the
		# overlay visibly "gets closer" rather than spinning pointlessly.
		_radar.progress = clampf(elapsed / maxf(eta, 1.0), 0.0, 1.0)


func _on_found(ticket: Dictionary) -> void:
	_found_ticket = ticket
	_mode = Mode.FOUND
	_render()


func _on_cancelled() -> void:
	close()


func _render() -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for child in _secondary_actions.get_children():
		_secondary_actions.remove_child(child)
		child.queue_free()

	match _mode:
		Mode.SEARCHING: _render_searching()
		Mode.FOUND: _render_found()
		Mode.CONNECTING: _render_connecting()
		_: pass


func _render_searching() -> void:
	_title.text = Loc.t(&"queue.title")
	_subtitle.text = Loc.t(&"queue.searching")
	_accept_countdown.visible = false
	_simulated_pill.visible = not Api.is_configured()

	var selected := Matchmaking.selected_modes()
	var names := PackedStringArray()
	for mode_id in selected:
		names.append(Loc.t(GameCatalog.resolve(mode_id).short_key))
	_modes_label.text = Loc.t(&"play.search.count", {"count": selected.size()}) \
		+ "  ·  " + " / ".join(names)

	var cancel := UiKit.button(Loc.t(&"queue.cancel"), &"OutlineButton", &"close")
	UiKit.on_press(cancel, func() -> void: Matchmaking.cancel_queue(), "back")
	_actions.add_child(cancel)


func _render_found() -> void:
	var mode := GameCatalog.resolve(StringName(_found_ticket.get("mode_id", "tdm")))
	_title.text = Loc.t(&"queue.found")
	_subtitle.text = Loc.t(mode.title_key)
	_simulated_pill.visible = bool(_found_ticket.get("simulated", true))
	_accept_countdown.visible = true

	var players: Array = _found_ticket.get("players", [])
	_modes_label.text = "%s  ·  %s  ·  %s" % [
		Loc.t(&"common.map"), String(_found_ticket.get("map_id", "?")),
		Loc.t(&"rooms.players_count", {"count": players.size(), "max": mode.lobby_capacity()}),
	]

	var accept := UiKit.button(Loc.t(&"queue.accept"), &"PrimaryButton", &"check")
	accept.custom_minimum_size = Vector2(180, 54)
	UiKit.on_press(accept, func() -> void: Matchmaking.accept_match(), "confirm")
	_actions.add_child(accept)

	var decline := UiKit.button(Loc.t(&"common.cancel"), &"OutlineButton")
	UiKit.on_press(decline, func() -> void: Matchmaking.decline_match(), "back")
	_actions.add_child(decline)

	# A compact roster preview so the player sees who they are about to play
	# with — including the fact that the opponents are simulated.
	var preview := UiKit.hbox(Design.SPACE_XS)
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_child(UiKit.micro(Loc.t(&"common.players")))
	for index in mini(players.size(), 8):
		var entry: Dictionary = players[index]
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = AvatarView.color_for_index(absi(String(entry.get("name", "x")).hash()))
		style.set_corner_radius_all(Design.RADIUS_SM)
		if bool(entry.get("is_local", false)):
			style.border_color = Design.TEXT
			style.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", style)
		dot.tooltip_text = "%s · LVL %d" % [entry.get("name", "?"), int(entry.get("level", 1))]
		preview.add_child(dot)
	if players.size() > 8:
		preview.add_child(UiKit.micro("+%d" % (players.size() - 8)))
	_secondary_actions.add_child(preview)


func _render_connecting() -> void:
	_title.text = Loc.t(&"queue.accept")
	_subtitle.text = Loc.t(&"mm.ready_check")
	_accept_countdown.visible = false
	_simulated_pill.visible = true
	# Phase 2 replaces this branch with the scene change into the match. Saying
	# so explicitly is the whole point of this state existing today.
	_modes_label.text = Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")})

	var back := UiKit.button(Loc.t(&"common.close"), &"OutlineButton")
	UiKit.on_press(back, func() -> void:
		Matchmaking.cancel_queue()
		close()
	, "back")
	_actions.add_child(back)


func _format_clock(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_language_changed(_locale: String) -> void:
	layout_direction = Loc.layout_direction()
	_drag_direction_to_children()
	_render()


func _drag_direction_to_children() -> void:
	# Our children are not Controls of a screen, so push direction down by hand.
	for child in get_children():
		if child is Control:
			(child as Control).layout_direction = Loc.layout_direction()


func _process(_delta: float) -> void:
	if _mode == Mode.FOUND and _accept_countdown != null and _accept_countdown.visible:
		# The service owns the real countdown; this mirrors it for the player.
		_accept_countdown.text = Loc.t(&"queue.accepting")


## Sweeping radar. One arc and a growing ring — cheap, and it communicates
## "searching" better than a spinner does.
class _Radar extends Control:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	var _angle: float = 0.0
	var _scanning: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_scanning(scanning: bool) -> void:
		_scanning = scanning
		set_process(scanning)
		queue_redraw()

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * 2.4, TAU)
		queue_redraw()

	func _draw() -> void:
		var side := minf(size.x, size.y)
		if side <= 8.0:
			return
		var centre := size * 0.5
		var radius := side * 0.44
		var accent := Design.ACCENT
		var teal := Design.TEAL

		for ring in 3:
			draw_arc(centre, radius * (0.4 + float(ring) * 0.3), 0.0, TAU, 40,
				Color(teal.r, teal.g, teal.b, 0.16), 1.5, true)

		if _scanning:
			draw_arc(centre, radius, _angle, _angle + PI * 0.5, 24, accent, 3.0, true)
			draw_line(centre, centre + Vector2(cos(_angle + PI * 0.5), sin(_angle + PI * 0.5)) * radius,
				Color(accent.r, accent.g, accent.b, 0.5), 2.0, true)

		# Progress ring: how close we are to the estimated wait.
		if progress > 0.0:
			draw_arc(centre, radius * 0.92, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0),
				64, teal, 4.0, true)

		draw_circle(centre, 4.0, accent)
