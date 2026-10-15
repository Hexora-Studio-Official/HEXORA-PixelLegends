class_name HexScreen
extends Control
## Base class for every full-screen scene.
##
## Handles the four things each screen would otherwise reimplement:
##   1. background  — the hex backdrop is added underneath the content.
##   2. direction   — layout_direction follows the locale, explicitly, on the
##                    root of the screen so every child inherits correctly.
##   3. rebuild     — when the language changes, screens are rebuilt from
##                    scratch. Building in code makes this cheap and removes a
##                    whole category of "translate once and never update" bugs.
##   4. entrance    — a short fade/slide so navigations do not pop.
##
## Screens override `build()` and, when they hold state that a rebuild must
## preserve, keep it in member variables (a rebuild reads them back).

## Set to false for screens that draw their own background (the 3D menu
## backdrop in phase 2, for instance).
## Upper bound on the horizontal inset taken from the device safe area, as a
## fraction of the screen width. Keeps a wide handset from eating the layout.
const MAX_SAFE_INSET_WIDTH_FRACTION := 0.06
## Upper bound as a fraction of the screen height. Real cutouts are bounded by
## the short edge of the panel, so on landscape phones this is the tighter of
## the two caps (~86 px on a 1080 px tall screen).
const MAX_SAFE_INSET_HEIGHT_FRACTION := 0.08

var backdrop_enabled: bool = true
## Slide the content up slightly on entry.
var entrance_offset: float = 24.0
## Extra padding applied inside the device safe area.
var safe_padding: int = Design.SPACE_XL

var content: Control
var _backdrop: HexBackdrop
var _safe: MarginContainer
var _horizontal_safe_inset: float = Design.SPACE_XL
var _safe_inset_left: float = Design.SPACE_XL
var _safe_inset_right: float = Design.SPACE_XL


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	if backdrop_enabled:
		_backdrop = HexBackdrop.new()
		_backdrop.name = "Backdrop"
		add_child(_backdrop)

	_safe = MarginContainer.new()
	_safe.name = "SafeArea"
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_safe)
	_apply_safe_padding()

	content = Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	_safe.add_child(content)

	_apply_direction()
	EventBus.language_changed.connect(_on_language_changed)
	build()
	_animate_entrance()


## Override. Populate `content`.
func build() -> void:
	pass


## Override only when a screen can update its text without a full rebuild.
## The default is a rebuild, which is always correct and never stale.
func retranslate() -> void:
	rebuild()


## Tear the content down and build it again. State kept in member variables
## survives; anything transient is intentionally lost.
func rebuild() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_apply_direction()
	build()


func _on_language_changed(_locale: String) -> void:
	retranslate()


func _apply_direction() -> void:
	var direction := Loc.layout_direction()
	if _safe != null:
		_safe.layout_direction = direction
	if content != null:
		content.layout_direction = direction
	layout_direction = direction


## Notches and rounded corners: keep content clear of the cutout, without ever
## letting the safe area hollow the screen out.
##
## `DisplayServer.get_display_safe_area()` is a hint, and an unreliable one.
## Two things used to go wrong here:
##
##   1. It reports *physical* pixels, but the layout works in *logical* UI
##      units. Converting physical → logical means dividing by the window /
##      viewport ratio. The old code multiplied instead, so on a high-density
##      phone a 140 px cutout became a 280 px inset.
##   2. The result was mirrored onto both edges with no upper bound, so a
##      single device cutout pushed every element away from *both* sides and
##      squeezed the layout toward the middle of a landscape screen.
##
## Now each edge gets its own inset, correctly converted, and capped against
## both screen dimensions. A cutout is physically bounded by the short edge of
## the panel, so the height cap is what keeps phones honest.
func _apply_safe_padding() -> void:
	var base := float(safe_padding)
	var left := base
	var right := base

	var viewport_size := get_viewport_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	if width <= 1.0 or height <= 1.0:
		# Before the first layout pass the control has no size; the viewport
		# itself always does, so prefer it and fall back to the window.
		var window_size := Vector2(DisplayServer.window_get_size())
		if width <= 1.0:
			width = window_size.x
		if height <= 1.0:
			height = window_size.y

	var cap := maxf(base, minf(width * MAX_SAFE_INSET_WIDTH_FRACTION,
		height * MAX_SAFE_INSET_HEIGHT_FRACTION))

	var safe := Design.safe_area()
	var window_size := Vector2(DisplayServer.window_get_size())
	if safe.size != Vector2i.ZERO and window_size.x > 0.0 and width > 1.0:
		# Physical → logical. On a 2x display one physical pixel is half a
		# logical unit, hence the division by the window / viewport ratio.
		var logical_per_physical := width / window_size.x
		var physical_left := float(safe.position.x)
		var physical_right := float(window_size.x - (safe.position.x + safe.size.x))
		if physical_left > 0.0:
			left = clampf(physical_left * logical_per_physical, base, cap)
		if physical_right > 0.0:
			right = clampf(physical_right * logical_per_physical, base, cap)

	_safe_inset_left = left
	_safe_inset_right = right
	_horizontal_safe_inset = (left + right) * 0.5

	_safe.add_theme_constant_override("margin_left", int(round(left)))
	_safe.add_theme_constant_override("margin_right", int(round(right)))
	_safe.add_theme_constant_override("margin_top", safe_padding)
	_safe.add_theme_constant_override("margin_bottom", safe_padding)


func safe_content_width() -> float:
	return maxf(0.0, get_viewport_rect().size.x - _horizontal_safe_inset * 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _safe != null:
		_apply_safe_padding()
		on_screen_resized()


## Screens with width-constrained cards can update them when the device rotates.
func on_screen_resized() -> void:
	pass


func _animate_entrance() -> void:
	if content == null:
		return
	content.modulate.a = 0.0
	content.position.y = entrance_offset
	var tween := create_tween().set_parallel(true)
	tween.tween_property(content, "modulate:a", 1.0, 0.28)
	tween.tween_property(content, "position:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Android's system back gesture arrives as ui_cancel. Screens decide what
	# that means; the base class only consumes it so it cannot leak to a
	# screen underneath.
	accept_event()
	on_back_requested()


## Override for a per-screen back behaviour. Default: nothing (the platform
## will background the app, which is what Android users expect from a menu).
func on_back_requested() -> void:
	pass
