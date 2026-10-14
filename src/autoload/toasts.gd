extends Node
## Transient messages, stacked above every screen.
##
## Owns its own CanvasLayer (layer 90) so a toast survives a scene change —
## for example, a sign-out notice remains visible after routing to the boot
## screen. Screens emit `EventBus.toast_requested`; the UI is English/LTR.

const MAX_VISIBLE := 4
const DURATION_SEC := 3.4
## Errors and warnings stay up long enough to be read twice.
const DURATION_LONG_SEC := 5.0
const WIDTH := 380

var _layer: CanvasLayer
var _root: MarginContainer
var _row: HBoxContainer
var _stack: VBoxContainer
var _spacer: Control


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ToastLayer"
	_layer.layer = 90
	add_child(_layer)

	_root = MarginContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		_root.add_theme_constant_override("margin_%s" % side, Design.SPACE_XL)
	_root.add_theme_constant_override("margin_top", Design.SPACE_XL)
	_root.add_theme_constant_override("margin_bottom", Design.SPACE_XL)
	_layer.add_child(_root)

	# Row layout: the fixed-width toast stack followed by a spacer.
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)

	_stack = VBoxContainer.new()
	_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stack.add_theme_constant_override("separation", Design.SPACE_SM)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_stack)

	_spacer = Control.new()
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_spacer)

	_apply_direction()
	EventBus.toast_requested.connect(show_toast)
	EventBus.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	_apply_direction()


## Direction has to be set explicitly on the top of our layer: our Controls are
## not children of a screen, so they cannot inherit it from one.
func _apply_direction() -> void:
	var direction := Loc.layout_direction()
	for control in [_root, _row, _stack]:
		control.layout_direction = direction


func _toast_width() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return float(WIDTH)
	var screen_width := viewport.get_visible_rect().size.x
	return minf(float(WIDTH), screen_width * 0.46)


## Show a message. `kind` is "info" | "success" | "warning" | "error".
func show_toast(message: String, kind: StringName = &"info") -> void:
	if message.strip_edges().is_empty():
		return
	_trim_to_limit()
	var toast := _build_toast(message, kind)
	_stack.add_child(toast)
	_animate_in(toast, kind)


func _trim_to_limit() -> void:
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()


func _accent_for(kind: StringName) -> Color:
	match kind:
		&"success": return Design.SUCCESS
		&"warning": return Design.WARNING
		&"error": return Design.DANGER
		_: return Design.TEAL


func _cue_for(kind: StringName) -> String:
	match kind:
		&"success": return "confirm"
		&"warning": return "click"
		&"error": return "error"
		_: return "click"


func _build_toast(message: String, kind: StringName) -> Control:
	var accent := _accent_for(kind)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(_toast_width(), 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	# Toasts must never eat a tap meant for the game underneath.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Design.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", Design.font_ui)
	label.add_theme_font_size_override("font_size", Design.FONT_SMALL)
	label.add_theme_color_override("font_color", Design.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(label)
	return panel


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Design.SURFACE_ALT.r, Design.SURFACE_ALT.g, Design.SURFACE_ALT.b, 0.96)
	box.set_corner_radius_all(Design.RADIUS_MD)
	box.border_color = Design.LINE_STRONG
	box.set_border_width_all(Design.BORDER_THIN)
	box.set_content_margin_all(float(Design.SPACE_MD))
	box.anti_aliasing = false
	return box


func _animate_in(toast: Control, kind: StringName) -> void:
	Audio.play_ui(_cue_for(kind), 1.0, -3.0)

	toast.modulate = Color(1, 1, 1, 0)
	toast.position.x = -40.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	tween.tween_property(toast, "position:x", 0.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(DURATION_LONG_SEC if kind == &"error" or kind == &"warning" else DURATION_SEC)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)


## Drop every visible toast — used when the Router changes screens and the old
## context no longer applies.
func clear() -> void:
	for child in _stack.get_children():
		_stack.remove_child(child)
		child.queue_free()


func visible_count() -> int:
	return _stack.get_child_count()
