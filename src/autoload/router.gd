extends Node
## Screen navigation.
##
## Three jobs, and nothing else:
##   1. Map a route name to a scene so no call site writes a `res://` path.
##   2. Own the transition (fade + input lock) so a screen can change itself
##      without knowing how it will be animated.
##   3. Keep a back stack, so "Back" means what the player expects.
##
## Screens are separate scenes rather than one mega-scene because Android kills
## backgrounded apps: re-entering the game should land on a cheap, predictable
## screen (login or menu), not rebuild the whole hub.

const SCREENS := {
	&"boot": "res://src/ui/screens/boot_screen.tscn",
	&"login": "res://src/ui/screens/login_screen.tscn",
	&"setup": "res://src/ui/screens/profile_setup_screen.tscn",
	&"menu": "res://src/ui/screens/main_menu_screen.tscn",
}

const FADE_OUT_SEC := 0.16
const FADE_IN_SEC := 0.24

var route: StringName = &""
## Free-form bag a screen can read in `_ready()` for "which room did I tap".
var context: Dictionary = {}

var _history: Array[StringName] = []
var _fade: ColorRect
var _layer: CanvasLayer
var _loading: Control
var _loading_label: Label
var _busy: bool = false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "RouterLayer"
	_layer.layer = 100
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.color = Design.BG
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

	_build_loading_overlay()


# -------------------------------------------------------------------- routes

func has_route(candidate: StringName) -> bool:
	return SCREENS.has(candidate)


func route_path(candidate: StringName) -> String:
	return String(SCREENS.get(candidate, ""))


## Change screen. Awaitable; callers that care about the new scene being live
## can `await Router.goto(...)`.
func goto(next_route: StringName, next_context: Dictionary = {}) -> void:
	if _busy:
		return
	if not SCREENS.has(next_route):
		push_error("Router: unknown route '%s'." % next_route)
		return
	_busy = true
	context = next_context
	if route != &"" and route != next_route:
		_history.append(route)

	await _fade_to(1.0, FADE_OUT_SEC)
	var error := get_tree().change_scene_to_file(SCREENS[next_route])
	if error != OK:
		push_error("Router: could not load '%s' (error %d)." % [SCREENS[next_route], error])
		_busy = false
		return
	# One frame for the new scene's `_ready` to run before we reveal it, so the
	# player never sees a half-built layout.
	await get_tree().process_frame
	await _fade_to(0.0, FADE_IN_SEC)
	route = next_route
	_busy = false
	EventBus.route_changed.emit(route)


## Return to the previous screen, or to `fallback` when the stack is empty.
func back(fallback: StringName = &"menu") -> void:
	if _busy:
		return
	var previous: StringName = _history.pop_back() if not _history.is_empty() else fallback
	await goto(previous, context)


func clear_history() -> void:
	_history.clear()


func is_busy() -> bool:
	return _busy


func history_depth() -> int:
	return _history.size()


## Where a signed-in player should land, and where a signed-out one should go.
## One place decides, so boot/login/menu never disagree.
func route_for_auth_state() -> StringName:
	match Auth.state:
		GameTypes.AuthState.SIGNED_IN:
			if not Settings.get_bool("game/first_run_complete", false):
				return &"setup"
			return &"menu"
		GameTypes.AuthState.RESTORING, GameTypes.AuthState.UNKNOWN, GameTypes.AuthState.SIGNING_IN:
			return &"boot"
		_:
			return &"login"


# ------------------------------------------------------------------ loading

func _build_loading_overlay() -> void:
	_loading = Control.new()
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading.visible = false
	_layer.add_child(_loading)

	var dim := ColorRect.new()
	dim.color = Color(Design.BG.r, Design.BG.g, Design.BG.b, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(centre)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _loading_style())
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Design.SPACE_SM)
	panel.add_child(column)

	var title := Label.new()
	title.text = Loc.t(&"common.loading")
	title.theme_type_variation = &"TealLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.layout_direction = Loc.layout_direction()
	column.add_child(title)

	_loading_label = Label.new()
	_loading_label.theme_type_variation = &"BodyMutedLabel"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.layout_direction = Loc.layout_direction()
	column.add_child(_loading_label)

	EventBus.language_changed.connect(func(_locale: String) -> void:
		title.text = Loc.t(&"common.loading")
		title.layout_direction = Loc.layout_direction()
		_loading_label.layout_direction = Loc.layout_direction()
	)


func _loading_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Design.SURFACE_ALT
	box.set_corner_radius_all(Design.RADIUS_LG)
	box.border_color = Design.LINE_STRONG
	box.set_border_width_all(Design.BORDER_THIN)
	box.content_margin_left = float(Design.SPACE_HUGE)
	box.content_margin_right = float(Design.SPACE_HUGE)
	box.content_margin_top = float(Design.SPACE_XL)
	box.content_margin_bottom = float(Design.SPACE_XL)
	return box


## Show a blocking spinner. Returns immediately; await `hide_loading()` when the
## work is done.
func show_loading(label: String = "") -> void:
	if _loading == null:
		return
	_loading_label.text = label
	_loading.visible = true
	_loading.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_loading, "modulate:a", 1.0, 0.12)
	EventBus.loading_started.emit(label)


func set_loading_label(label: String) -> void:
	if _loading_label != null:
		_loading_label.text = label


func hide_loading() -> void:
	if _loading == null or not _loading.visible:
		return
	var tween := create_tween()
	tween.tween_property(_loading, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func() -> void:
		if _loading != null:
			_loading.visible = false
	)
	EventBus.loading_finished.emit()


# -------------------------------------------------------------------- fade

func _fade_to(alpha: float, duration: float) -> void:
	if _fade == null:
		return
	# Block input for the whole transition, not just the visible part.
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.01 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished


# --------------------------------------------------------------------- quit

## Quit to the platform. On Android this is the same as sending the app to the
## background, which the player expects from a "quit" button.
func quit_game() -> void:
	Settings.flush()
	await _fade_to(1.0, 0.3)
	get_tree().quit()
