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
var backdrop_enabled: bool = true
## Slide the content up slightly on entry.
var entrance_offset: float = 24.0
## Extra padding applied inside the device safe area.
var safe_padding: int = Design.SPACE_XL
## Mirror the larger camera-cutout inset when a screen needs a centred safe canvas.
## Edge-docked hub screens can use the device's true left/right insets instead.
var mirror_horizontal_safe_insets: bool = true

var content: Control
var _backdrop: HexBackdrop
var _safe: MarginContainer
var _horizontal_safe_inset: float = Design.SPACE_XL
var _horizontal_safe_inset_left: float = Design.SPACE_XL
var _horizontal_safe_inset_right: float = Design.SPACE_XL


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


## Respect the actual device cutout on each edge. Most screens mirror the larger
## inset to keep centred content balanced; side-docked screens can opt out so
## one camera cutout does not create a matching empty gutter on the other side.
func _apply_safe_padding() -> void:
	var horizontal_left := safe_padding
	var horizontal_right := safe_padding
	var safe := Design.safe_area()
	var window_size := Vector2(DisplayServer.window_get_size())
	if safe.size != Vector2i.ZERO and window_size.x > 0.0:
		# Safe-area measurements are physical pixels. Convert each edge separately
		# to the UI's logical units before applying the optional symmetry rule.
		var scale := window_size.x / maxf(1.0, size.x if size.x > 1.0 else window_size.x)
		var physical_left := float(safe.position.x)
		var physical_right := float(window_size.x - (safe.position.x + safe.size.x))
		horizontal_left = maxi(safe_padding, int(round(physical_left * scale)))
		horizontal_right = maxi(safe_padding, int(round(physical_right * scale)))
	if mirror_horizontal_safe_insets:
		var mirrored_inset := maxi(horizontal_left, horizontal_right)
		horizontal_left = mirrored_inset
		horizontal_right = mirrored_inset
	_horizontal_safe_inset_left = float(horizontal_left)
	_horizontal_safe_inset_right = float(horizontal_right)
	_horizontal_safe_inset = maxf(_horizontal_safe_inset_left, _horizontal_safe_inset_right)

	for side in ["top", "bottom"]:
		_safe.add_theme_constant_override("margin_%s" % side, safe_padding)
	_safe.add_theme_constant_override("margin_left", horizontal_left)
	_safe.add_theme_constant_override("margin_right", horizontal_right)


func safe_content_width() -> float:
	return maxf(0.0, get_viewport_rect().size.x
		- _horizontal_safe_inset_left - _horizontal_safe_inset_right)


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
