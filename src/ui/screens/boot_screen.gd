extends HexScreen
## Boot: brand reveal, service warm-up, then hand off to the right screen.
##
## Deliberately shows what is happening rather than a spinner: three named
## steps that tick off as they complete. On a cold Android start this is the
## difference between "it is working" and "it is frozen".

enum Step { SERVICES, SESSION, READY }

const MIN_DISPLAY_SEC := 1.5

var _logo: Control
var _wordmark: Label
var _tagline: Label
var _step_rows: Array[Dictionary] = []
var _status_label: Label
var _elapsed: float = 0.0
var _services_done: bool = false
var _session_done: bool = false
var _finished: bool = false


func build() -> void:
	var root := UiKit.vbox(Design.SPACE_XL)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(root)

	# ---- brand block -------------------------------------------------------
	_logo = _build_logo()
	root.add_child(_logo)

	_wordmark = UiKit.display(Loc.t(&"app.name"))
	_wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wordmark.add_theme_color_override("font_color", Design.TEXT)
	root.add_child(_wordmark)

	_tagline = UiKit.label(Loc.t(&"app.tagline"), &"SectionLabel")
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_tagline)

	root.add_child(UiKit.vertical_spacer(Design.SPACE_XXL))

	# ---- progress steps ----------------------------------------------------
	var steps := UiKit.vbox(Design.SPACE_SM)
	steps.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	steps.custom_minimum_size = Vector2(340, 0)
	root.add_child(steps)
	_step_rows.clear()
	_step_rows.append(_build_step_row(&"boot.loading_services"))
	_step_rows.append(_build_step_row(&"boot.checking_session"))
	_step_rows.append(_build_step_row(&"boot.ready"))
	for row in _step_rows:
		steps.add_child(row["root"])

	root.add_child(UiKit.vertical_spacer(Design.SPACE_XL))

	_status_label = UiKit.micro(_version_text())
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	# ---- wire the world ----------------------------------------------------
	_services_done = true
	_mark_step(Step.SERVICES, true)
	_advance_status_visuals()


## Version line under the logo.
func _version_text() -> String:
	return Loc.t(&"app.version_label", {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
	})


## The HEXORA mark, drawn rather than loaded: a hexagonal containment field with
## the crossed reticle, exactly like icon.svg but as live geometry so it can
## animate.
func _build_logo() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(148, 148)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mark := _LogoMark.new()
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(mark)

	holder.modulate.a = 0.0
	holder.scale = Vector2(0.86, 0.86)
	holder.pivot_offset = Vector2(74, 74)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(holder, "modulate:a", 1.0, 0.55)
	tween.tween_property(holder, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder


func _build_step_row(key: StringName) -> Dictionary:
	var row := UiKit.hbox(Design.SPACE_MD)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Design.SURFACE_HI
	style.set_corner_radius_all(Design.RADIUS_PILL)
	style.border_color = Design.LINE_STRONG
	style.set_border_width_all(1)
	dot.add_theme_stylebox_override("panel", style)
	row.add_child(dot)

	var text := UiKit.label(Loc.t(key), &"BodyMutedLabel")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var state := UiKit.micro("")
	row.add_child(state)
	return {"root": row, "dot": dot, "dot_style": style, "label": text, "state": state, "key": key}


func _mark_step(step: int, done: bool) -> void:
	if step < 0 or step >= _step_rows.size():
		return
	var row := _step_rows[step]
	var style: StyleBoxFlat = row["dot_style"]
	style.bg_color = Design.SUCCESS if done else Design.SURFACE_HI
	style.border_color = Design.SUCCESS if done else Design.LINE_STRONG
	var text: Label = row["label"]
	text.add_theme_color_override("font_color", Design.TEXT if done else Design.TEXT_MUTED)
	var state: Label = row["state"]
	state.text = Loc.t(&"common.ok") if done else "…"
	state.add_theme_color_override("font_color", Design.SUCCESS if done else Design.TEXT_DIM)


func _set_step_active(step: int) -> void:
	if step < 0 or step >= _step_rows.size():
		return
	var row := _step_rows[step]
	var style: StyleBoxFlat = row["dot_style"]
	style.bg_color = Design.ACCENT
	style.border_color = Design.ACCENT_HI
	(row["label"] as Label).add_theme_color_override("font_color", Design.TEXT)


func _advance_status_visuals() -> void:
	if _status_label != null:
		_status_label.text = _version_text()


func _ready() -> void:
	super._ready()
	# `build()` has already run by now (the base class calls it), so the step
	# rows exist and we can drive the sequence.
	_set_step_active(Step.SESSION)
	_restore_session()


func _restore_session() -> void:
	# Awaiting inside a screen is safe here: the node is freed by the Router
	# only after the transition, and the callback checks `is_inside_tree`.
	await Auth.restore_session()
	if not is_inside_tree():
		return
	_session_done = true
	_mark_step(Step.SESSION, true)
	_mark_step(Step.READY, true)


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	if not _services_done or not _session_done:
		return
	# Hold the logo on screen for a beat even when everything resolves
	# instantly — a one-frame boot screen looks like a bug.
	if _elapsed < MIN_DISPLAY_SEC:
		return
	_finished = true
	_finish()


func _finish() -> void:
	var destination := Router.route_for_auth_state()
	var tween := create_tween()
	tween.tween_property(content, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func() -> void:
		Router.clear_history()
		Router.goto(destination)
	)


func on_back_requested() -> void:
	# Backing out of the boot screen should leave the app, not strand it.
	Router.quit_game()


## Inner class: the animated mark. Drawing it here keeps the boot screen
## self-contained and lets the reticle spin up on entry.
class _LogoMark extends Control:
	var _progress: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		var tween := create_tween()
		tween.tween_method(_set_progress, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_CUBIC)

	func _set_progress(value: float) -> void:
		_progress = value
		queue_redraw()

	func _draw() -> void:
		var side := minf(size.x, size.y)
		if side <= 4.0:
			return
		var centre := size * 0.5
		var radius := side * 0.46
		var thickness := maxf(2.0, side * 0.045)

		# Containment hexagon, drawn progressively so it "closes".
		var corners := PackedVector2Array()
		for corner in 6:
			var angle := PI / 3.0 * float(corner) - PI / 2.0
			corners.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		var visible_corners := int(ceil(6.0 * _progress))
		for corner in visible_corners:
			var next := (corner + 1) % 6
			if corner + 1 >= visible_corners and visible_corners < 6:
				draw_line(corners[corner],
					corners[corner].lerp(corners[next], fmod(6.0 * _progress, 1.0)),
					Design.ACCENT, thickness, true)
			else:
				draw_line(corners[corner], corners[next], Design.ACCENT, thickness, true)

		if _progress < 0.6:
			return

		# Inner "H" and the reticle, fading in after the frame closes.
		var inner := (_progress - 0.6) / 0.4
		var bar_color := Color(Design.ACCENT_HI.r, Design.ACCENT_HI.g, Design.ACCENT_HI.b, inner)
		var bar_width := side * 0.075
		var bar_height := side * 0.42
		draw_rect(Rect2(centre.x - side * 0.17 - bar_width * 0.5,
			centre.y - bar_height * 0.5, bar_width, bar_height), bar_color)
		draw_rect(Rect2(centre.x + side * 0.17 - bar_width * 0.5,
			centre.y - bar_height * 0.5, bar_width, bar_height), bar_color)
		draw_rect(Rect2(centre.x - side * 0.10, centre.y - bar_width * 0.5,
			side * 0.20, bar_width),
			Color(Design.TEAL.r, Design.TEAL.g, Design.TEAL.b, inner))

		var reticle_radius := radius * (1.0 + (1.0 - inner) * 0.4)
		draw_arc(centre, reticle_radius, 0.0, TAU, 48,
			Color(Design.TEAL.r, Design.TEAL.g, Design.TEAL.b, inner * 0.5), 2.0, true)
