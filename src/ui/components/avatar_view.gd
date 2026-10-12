class_name AvatarView
extends Control
## Procedural operator avatar: a hexagon, an accent derived from the player's
## uid, and their initials.
##
## There are no avatar images in phase 1 — and rather than showing a grey
## placeholder (which reads as "broken"), we generate something deterministic:
## the same account always gets the same colour and shape on every device.

const PALETTE: Array[Color] = [
	Color("baff4a"), Color("47d9ff"), Color("648dff"), Color("b48cff"),
	Color("50e3a4"), Color("ffc857"), Color("ff6480"), Color("7aa2ff"),
]

var initials: String = "??":
	set(value):
		initials = value
		if _label != null:
			_label.text = initials

## Index into PALETTE. Derived from the uid, not chosen at random.
var palette_index: int = 0:
	set(value):
		palette_index = value
		queue_redraw()

var show_level: bool = false:
	set(value):
		show_level = value
		if _level_label != null:
			_level_label.visible = value

var level: int = 1:
	set(value):
		level = value
		if _level_label != null:
			_level_label.text = str(level)

var _label: Label
var _level_label: Label


static func make(for_profile: PlayerProfile, pixel_size: float = 48.0) -> AvatarView:
	var avatar := AvatarView.new()
	avatar.custom_minimum_size = Vector2(pixel_size, pixel_size)
	avatar.size = Vector2(pixel_size, pixel_size)
	avatar.palette_index = posmod(for_profile.avatar_color, PALETTE.size()) \
		if for_profile.avatar_color >= 0 else absi(for_profile.uid.hash()) % PALETTE.size()
	avatar.initials = for_profile.initials()
	avatar.level = for_profile.level
	return avatar


## Colour for a palette index — also used by the roster rows so a player's
## colour is consistent everywhere.
static func color_for_index(index: int) -> Color:
	return PALETTE[posmod(index, PALETTE.size())]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_level_label.position = Vector2(0, -6)
	_level_label.visible = false
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_restyle()
		queue_redraw()


func _ready() -> void:
	_restyle()


func _restyle() -> void:
	var side := minf(size.x, size.y)
	if _label != null:
		_label.add_theme_font_override("font", Design.font_display)
		_label.add_theme_font_size_override("font_size", int(maxf(10.0, side * 0.36)))
		_label.add_theme_color_override("font_color", Design.TEXT_INVERSE)
	if _level_label != null:
		_level_label.add_theme_font_override("font", Design.font_label)
		_level_label.add_theme_font_size_override("font_size", int(maxf(8.0, side * 0.20)))
		_level_label.add_theme_color_override("font_color", Design.TEXT_MUTED)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var centre := size * 0.5
	var radius := side * 0.5 - 2.0
	var accent := color_for_index(palette_index)

	var hexagon := PackedVector2Array()
	for corner in 6:
		var angle := PI / 3.0 * float(corner) - PI / 2.0
		hexagon.append(centre + Vector2(cos(angle), sin(angle)) * radius)

	# Fill: accent at low alpha so the initials stay legible, then a solid
	# accent outline. Reads as a designed badge rather than a circle avatar.
	draw_colored_polygon(hexagon, Color(accent.r, accent.g, accent.b, 0.20))
	var outline := hexagon.duplicate()
	outline.append(hexagon[0])
	draw_polyline(outline, accent, maxf(1.5, side * 0.045), true)


## Compact circular variant used in dense lists (kill feed, roster chips).
func set_compact(compact: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label != null:
		_label.add_theme_font_size_override("font_size",
			int(maxf(9.0, minf(size.x, size.y) * (0.34 if compact else 0.36))))
	queue_redraw()
