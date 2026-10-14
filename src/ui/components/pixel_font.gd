class_name PixelFont
extends RefCounted
## A 5x7 bitmap face drawn as solid rectangles.
##
## The project ships Chakra Petch and Vazirmatn — both excellent, neither
## pixel. Rather than pull in a licensed bitmap font (and an extra asset to
## ship, attribute and import) for the one place the art direction calls for
## real pixel lettering, the face is defined here as data and rasterised with
## `draw_rect`. Squares on a whole-pixel grid, so it stays crisp at any scale
## and needs no filtering, no mipmaps and no import step.
##
## Glyphs cover what on-screen pixel lettering actually needs: A-Z, 0-9 and a
## handful of separators. Anything else renders as a blank cell rather than
## throwing, so a mistyped string degrades instead of crashing a splash.

const GLYPH_W := 5
const GLYPH_H := 7

## Blank cell returned for characters the face does not carry.
const BLANK := [
	".....",
	".....",
	".....",
	".....",
	".....",
	".....",
	".....",
]

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", ".##..", ".#..."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	":": [".....", ".##..", ".##..", ".....", ".##..", ".##..", "....."],
	"'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


static func glyph(character: String) -> Array:
	var rows: Array = []
	var found = GLYPHS.get(character.to_upper(), BLANK)
	for row in found:
		rows.append(String(row))
	return rows


## Size of `text` in glyph cells, including tracking between characters.
static func measure_cells(text: String, tracking: int = 1) -> Vector2i:
	if text.is_empty():
		return Vector2i(0, GLYPH_H)
	var columns := text.length() * GLYPH_W + maxi(0, text.length() - 1) * tracking
	return Vector2i(columns, GLYPH_H)


## Pixel size of `text` once scaled.
static func measure_pixels(text: String, scale: float, tracking: int = 1) -> Vector2:
	var cells := measure_cells(text, tracking)
	return Vector2(float(cells.x) * scale, float(cells.y) * scale)


## Rasterise `text` onto `canvas`, with its top-left corner at `origin`.
## `per_cell` optionally recolours each lit pixel; it receives the character
## index, the column and the row within the glyph and returns the colour to
## use, which is how per-letter gradients are done.
static func draw(
	canvas: CanvasItem,
	text: String,
	origin: Vector2,
	scale: float,
	tracking: int = 1,
	colour := Color.WHITE,
	alpha := 1.0,
	per_cell: Callable = Callable()
) -> void:
	if canvas == null or text.is_empty() or scale <= 0.0 or alpha <= 0.0:
		return
	var advance := float(GLYPH_W + tracking) * scale
	var x := origin.x
	for index in text.length():
		var rows := glyph(text.substr(index, 1))
		for row_index in rows.size():
			var row := String(rows[row_index])
			for column in row.length():
				if row.substr(column, 1) != "#":
					continue
				var pixel := colour
				if per_cell.is_valid():
					pixel = per_cell.call(index, column, row_index)
				# Snap to the whole-pixel grid: a scaled bitmap that lands on
				# half pixels shimmers.
				var px := floorf(x + float(column) * scale)
				var py := floorf(origin.y + float(row_index) * scale)
				canvas.draw_rect(Rect2(px, py, ceilf(scale), ceilf(scale)),
					Color(pixel.r, pixel.g, pixel.b, pixel.a * alpha))
		x += advance


## Rasterise a single character, positioned and coloured independently. Used
## when each letter needs its own entrance transform.
static func draw_character(
	canvas: CanvasItem,
	character: String,
	origin: Vector2,
	scale: float,
	colour := Color.WHITE,
	alpha := 1.0
) -> void:
	if canvas == null or scale <= 0.0 or alpha <= 0.0:
		return
	var rows := glyph(character)
	for row_index in rows.size():
		var row := String(rows[row_index])
		for column in row.length():
			if row.substr(column, 1) != "#":
				continue
			var px := floorf(origin.x + float(column) * scale)
			var py := floorf(origin.y + float(row_index) * scale)
			canvas.draw_rect(Rect2(px, py, ceilf(scale), ceilf(scale)),
				Color(colour.r, colour.g, colour.b, colour.a * alpha))
