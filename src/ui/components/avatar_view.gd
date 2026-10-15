class_name AvatarView
extends Control
## Procedural player avatar: a stepped pixel frame, an accent derived from
## the player's uid, and their initials.
##
## There are no avatar images in phase 1 — and rather than showing a grey
## placeholder (which reads as "broken"), we generate something deterministic:
## the same account always gets the same colour and shape on every device.

## Drawn from the master palette so a generated avatar never introduces a hue
## the rest of the interface does not use.
const PALETTE: Array[Color] = [
	Color("ffc93c"), Color("38e0ff"), Color("4ade80"), Color("ff9f43"),
	Color("ff4d5e"), Color("2fd4ff"), Color("a3e635"), Color("ff7a45"),
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
	var accent := color_for_index(palette_index)
	var cell := side / 10.0
	var origin := (size - Vector2(side, side)) * 0.5
	var row_widths: Array[int] = [4, 6, 8, 10, 10, 10, 10, 8, 6, 4]
	var fill := Color(accent.r, accent.g, accent.b, 0.22)

	# A stepped, square silhouette replaces the old smooth hex badge. The
	# one-cell rim stays sharp at launcher/menu scale and the translucent core
	# leaves the initials readable.
	for row in row_widths.size():
		var width_cells := row_widths[row]
		var first_cell := int((10 - width_cells) / 2)
		var row_origin := origin + Vector2(first_cell * cell, row * cell)
		var row_size := Vector2(width_cells * cell, cell)
		draw_rect(Rect2(row_origin, row_size), accent if row == 0 or row == 9 else fill)
		if row > 0 and row < 9:
			draw_rect(Rect2(row_origin, Vector2(cell, cell)), accent)
			draw_rect(Rect2(row_origin + Vector2((width_cells - 1) * cell, 0),
				Vector2(cell, cell)), accent)


## Compact-size variant used in dense lists (kill feed, roster chips).
func set_compact(compact: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label != null:
		_label.add_theme_font_size_override("font_size",
			int(maxf(9.0, minf(size.x, size.y) * (0.34 if compact else 0.36))))
	queue_redraw()
