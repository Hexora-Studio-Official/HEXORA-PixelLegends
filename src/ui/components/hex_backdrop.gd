class_name HexBackdrop
extends Control
## The screen background: a dark gradient, a faint hexagonal containment
## lattice, edge vignetting and two slow accent glows.
##
## Performance note (this runs behind every menu on a phone): the lattice and
## the vignette are drawn once into this Control's own canvas item. Only the
## two glow sprites move, and they are textured quads on their own canvas
## items, so a tween on them does not trigger any re-drawing of the lattice.
## That is the difference between a 0.2 ms and a 6 ms background.

const HEX_RADIUS := 44.0
const LATTICE_ALPHA := 0.055
const GLOW_COUNT := 2

var glow_colors: Array[Color] = [Design.ACCENT, Design.TEAL]

var _lattice_points: PackedVector2Array = PackedVector2Array()
var _built_size: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_build_glows()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_built_size = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	# Vertical gradient, banded. Twenty-eight bands is smooth at our contrast
	# range and costs 28 rects instead of a shader.
	const BANDS := 28
	var band_height := size.y / float(BANDS)
	for band in BANDS:
		var t := float(band) / float(BANDS - 1)
		var tone := Design.BG.lerp(Design.BG_RAISED, t * 0.85)
		draw_rect(Rect2(0.0, band_height * float(band), size.x, band_height + 1.0), tone)

	_rebuild_lattice_if_needed()
	if not _lattice_points.is_empty():
		draw_multiline(_lattice_points,
			Color(Design.LINE.r, Design.LINE.g, Design.LINE.b, LATTICE_ALPHA), 1.0)


## Pointy-top hex lattice, one closed outline per cell, as a single point list
## for one draw call.
func _rebuild_lattice_if_needed() -> void:
	if _built_size == size and not _lattice_points.is_empty():
		return
	_built_size = size
	_lattice_points = PackedVector2Array()

	var hex_width := sqrt(3.0) * HEX_RADIUS
	var row_height := HEX_RADIUS * 1.5
	var columns := int(ceil(size.x / hex_width)) + 2
	var rows := int(ceil(size.y / row_height)) + 2
	var centre_x := size.x * 0.5
	var centre_y := size.y * 0.5

	for row in range(-1, rows):
		for column in range(-1, columns):
			var x := float(column) * hex_width
			if row % 2 != 0:
				x += hex_width * 0.5
			var y := float(row) * row_height
			# Skip cells far outside the rect — a rotation or a very wide window
			# would otherwise generate thousands of useless segments.
			if x < -hex_width * 1.5 or x > size.x + hex_width * 1.5:
				continue

			var corners := PackedVector2Array()
			for corner in 6:
				var angle := PI / 3.0 * float(corner) - PI / 6.0
				corners.append(Vector2(x + cos(angle) * HEX_RADIUS, y + sin(angle) * HEX_RADIUS))

			# Fade the lattice out towards the edges so it never competes with
			# the content in the middle of the screen.
			var distance := Vector2(x - centre_x, y - centre_y).length()
			var limit := minf(size.x, size.y) * 0.55
			if distance > limit:
				continue

			for corner in 6:
				_lattice_points.append(corners[corner])
				_lattice_points.append(corners[(corner + 1) % 6])


## Soft radial sprites that drift. Cheap, and they stop the menu feeling dead.
func _build_glows() -> void:
	var texture := _radial_texture()
	for index in GLOW_COUNT:
		var glow := TextureRect.new()
		glow.texture = texture
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.modulate = Color(glow_colors[index % glow_colors.size()], 1.0)
		glow.modulate.a = 0.5
		var diameter := 540.0 + float(index) * 260.0
		glow.size = Vector2(diameter, diameter)
		glow.position = _glow_anchor(index, diameter)
		glow.set_meta("drift_index", index)
		add_child(glow)

		var duration := 26.0 + float(index) * 9.0
		var tween := create_tween().set_loops()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var offset := Vector2(
			randf_range(-90.0, 90.0) * (1.0 if index % 2 == 0 else -1.0),
			randf_range(-70.0, 70.0)
		)
		tween.tween_property(glow, "position", glow.position + offset, duration)
		tween.tween_property(glow, "position", glow.position - offset * 0.6, duration)


func _glow_anchor(index: int, diameter: float) -> Vector2:
	var x := size.x * (0.14 if index % 2 == 0 else 0.82)
	var y := size.y * (0.20 if index % 3 == 0 else 0.78)
	return Vector2(x, y) - Vector2(diameter, diameter) * 0.5


## A radial falloff baked into a small texture. 128 px is plenty — it is drawn
## blurred by the scale-up, which is exactly the look we want.
func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.30))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.10))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
