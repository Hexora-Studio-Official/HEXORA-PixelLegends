class_name HexBackdrop
extends Control
## Crisp, low-contrast voxel field used behind full-screen UI.
##
## The entrance and battle hub layer the supplied PixelLegends key art over
## their own full-bleed background; utility screens can reuse this quiet grid.

const BAND_COUNT := 24
const PIXEL_CELL := 72.0
const GRID_ALPHA := 0.045


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	# Broad, restrained sky-to-ground wash; all edges remain hard so the base
	# does not soften the pixel art placed above it.
	var band_height := size.y / float(BAND_COUNT)
	for band in BAND_COUNT:
		var t := float(band) / float(BAND_COUNT - 1)
		var tone := Design.BG.lerp(Design.BG_RAISED, t * 0.72)
		draw_rect(Rect2(0.0, band_height * float(band), size.x, band_height + 1.0), tone)

	var columns := ceili(size.x / PIXEL_CELL)
	var rows := ceili(size.y / PIXEL_CELL)
	for row in rows:
		for column in columns:
			var cell := Vector2(column, row)
			var seed := posmod(column * 31 + row * 17 + column * row * 13, 29)
			if seed > 3:
				continue
			var pixel_color := Design.TEAL if seed == 0 else \
				Design.SUCCESS if seed == 1 else Design.ACCENT
			var pixel_size := 8.0 if seed == 0 else 4.0
			var local_x := float(posmod(seed * 17 + row * 11, 56))
			var local_y := float(posmod(seed * 7 + column * 19, 56))
			var alpha := GRID_ALPHA if seed != 0 else GRID_ALPHA * 1.5
			draw_rect(Rect2(cell * PIXEL_CELL + Vector2(local_x, local_y),
				Vector2(pixel_size, pixel_size)),
				Color(pixel_color.r, pixel_color.g, pixel_color.b, alpha))

	# Sparse square guide lines give pages a shared grid without competing with
	# text, buttons, or the full-bleed entrance artwork.
	var grid_color := Color(Design.LINE.r, Design.LINE.g, Design.LINE.b, 0.065)
	for x in range(0, int(size.x), int(PIXEL_CELL * 2.0)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y), int(PIXEL_CELL * 2.0)):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
