class_name PixelFieldMark
extends Control
## Shared PixelField monogram used by the app icon, boot screen and sign-in.
## The block-built PF mark is intentionally crisp at small Android sizes.

const PIXEL_ROWS: Array[String] = [
	"111001111",
	"100101000",
	"111001110",
	"100001000",
	"100001000",
	"100001000",
	"100001000",
]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(56, 56)


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 8.0:
		return

	var frame_size := side * 0.96
	var frame_rect := Rect2((size - Vector2(frame_size, frame_size)) * 0.5,
		Vector2(frame_size, frame_size))
	draw_rect(frame_rect, Design.SURFACE_ALT)
	draw_rect(frame_rect, Design.LINE_STRONG, false,
		float(maxi(1, int(round(side * 0.025)))))

	var cell := side * 0.075
	var gap := side * 0.018
	var mark_width := 9.0 * cell + 8.0 * gap
	var mark_height := 7.0 * cell + 6.0 * gap
	var origin := size * 0.5 - Vector2(mark_width, mark_height) * 0.5
	for row_index in PIXEL_ROWS.size():
		var row := PIXEL_ROWS[row_index]
		for column in row.length():
			if row.substr(column, 1) != "1":
				continue
			var color := Design.TEAL if column < 4 else Design.ACCENT
			var position := origin + Vector2(
				float(column) * (cell + gap), float(row_index) * (cell + gap))
			draw_rect(Rect2(position, Vector2(cell, cell)), color)
