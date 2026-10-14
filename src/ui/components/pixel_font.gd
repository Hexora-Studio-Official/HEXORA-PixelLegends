class_name PixelFont
extends RefCounted
## A 7x9 bitmap face drawn as solid rectangles.
##
## The project ships Chakra Petch and Vazirmatn — both excellent, neither
## pixel. Rather than pull in a licensed bitmap font (and an extra asset to
## ship, attribute and import) for the one place the art direction calls for
## real pixel lettering, the face is defined here as data and rasterised with
## `draw_rect`. Squares on a whole-pixel grid, so it stays crisp at any scale
## and needs no filtering, no mipmaps and no import step.
##
## The grid is 7x9 rather than 5x7: at the size a wordmark is drawn, a 5x7
## letter is only thirty-five squares and every curve collapses into a stair.
## Two extra columns give O, S, G and C real shoulders.
##
## Glyphs cover A-Z, 0-9 and the separators on-screen lettering needs.
## Anything else renders as a blank cell rather than throwing, so a mistyped
## string degrades instead of crashing the splash.

const GLYPH_W := 7
const GLYPH_H := 9

## Blank cell returned for characters the face does not carry.
const BLANK := [
	".......",
	".......",
	".......",
	".......",
	".......",
	".......",
	".......",
	".......",
	".......",
]

const GLYPHS := {
	"A": ["..###..", ".##.##.", "##...##", "##...##", "#######", "##...##", "##...##", "##...##", "##...##"],
	"B": ["######.", "##...##", "##...##", "######.", "##...##", "##...##", "##...##", "##...##", "######."],
	"C": [".#####.", "##...##", "##.....", "##.....", "##.....", "##.....", "##.....", "##...##", ".#####."],
	"D": ["######.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "######."],
	"E": ["#######", "##.....", "##.....", "##.....", "######.", "##.....", "##.....", "##.....", "#######"],
	"F": ["#######", "##.....", "##.....", "##.....", "######.", "##.....", "##.....", "##.....", "##....."],
	"G": [".#####.", "##...##", "##.....", "##.....", "##.####", "##...##", "##...##", "##...##", ".#####."],
	"H": ["##...##", "##...##", "##...##", "#######", "##...##", "##...##", "##...##", "##...##", "##...##"],
	"I": ["#######", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "#######"],
	"J": ["#######", "...###.", "...###.", "...###.", "...###.", "...###.", "##.###.", "##.###.", ".####.."],
	"K": ["##...##", "##..##.", "##.##..", "####...", "###....", "####...", "##.##..", "##..##.", "##...##"],
	"L": ["##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######"],
	"M": ["##...##", "###.###", "#######", "##.#.##", "##.#.##", "##...##", "##...##", "##...##", "##...##"],
	"N": ["##...##", "###..##", "####.##", "####.##", "##.####", "##.####", "##..###", "##..###", "##...##"],
	"O": [".#####.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
	"P": ["######.", "##...##", "##...##", "##...##", "######.", "##.....", "##.....", "##.....", "##....."],
	"Q": [".#####.", "##...##", "##...##", "##...##", "##...##", "##.#.##", "##..##.", ".####.#", "....###"],
	"R": ["######.", "##...##", "##...##", "##...##", "######.", "##.##..", "##..##.", "##...##", "##...##"],
	"S": [".######", "##...##", "##.....", "##.....", ".#####.", ".....##", ".....##", "##...##", "######."],
	"T": ["#######", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###.."],
	"U": ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
	"V": ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".##.##.", ".##.##.", "..###.."],
	"W": ["##...##", "##...##", "##...##", "##.#.##", "##.#.##", "##.#.##", "#######", "###.###", "##...##"],
	"X": ["##...##", "##...##", ".##.##.", "..###..", "..###..", "..###..", ".##.##.", "##...##", "##...##"],
	"Y": ["##...##", "##...##", ".##.##.", "..###..", "..###..", "..###..", "..###..", "..###..", "..###.."],
	"Z": ["#######", ".....##", "....##.", "...##..", "..##...", ".##....", "##.....", "##.....", "#######"],
	"0": [".#####.", "##...##", "##..###", "##.####", "###.###", "####.##", "###..##", "##...##", ".#####."],
	"1": ["..###..", ".####..", "##.###.", "...###.", "...###.", "...###.", "...###.", "...###.", "#######"],
	"2": [".#####.", "##...##", ".....##", "....##.", "...##..", "..##...", ".##....", "##.....", "#######"],
	"3": ["######.", "....##.", "....##.", ".#####.", "....##.", "....##.", "....##.", "##...##", ".#####."],
	"4": ["....##.", "...###.", "..####.", ".##.##.", "##..##.", "#######", "....##.", "....##.", "....##."],
	"5": ["#######", "##.....", "##.....", "######.", ".....##", ".....##", ".....##", "##...##", ".#####."],
	"6": ["..####.", ".##....", "##.....", "##.....", "######.", "##...##", "##...##", "##...##", ".#####."],
	"7": ["#######", ".....##", "....##.", "...##..", "..##...", ".##....", ".##....", ".##....", ".##...."],
	"8": [".#####.", "##...##", "##...##", ".#####.", "##...##", "##...##", "##...##", "##...##", ".#####."],
	"9": [".#####.", "##...##", "##...##", "##...##", ".######", ".....##", "....##.", "...##..", ".##...."],
	"-": [".......", ".......", ".......", ".......", "#######", ".......", ".......", ".......", "......."],
	".": [".......", ".......", ".......", ".......", ".......", ".......", ".......", ".####..", ".####.."],
	",": [".......", ".......", ".......", ".......", ".......", ".####..", ".####..", ".##....", ".#....."],
	"!": ["..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", ".......", "..###.."],
	"?": [".#####.", "##...##", ".....##", "....##.", "...##..", "..###..", ".......", "..###..", "..###.."],
	":": [".......", ".####..", ".####..", ".......", ".####..", ".####..", ".......", ".......", "......."],
	"'": ["..###..", "..###..", ".......", ".......", ".......", ".......", ".......", ".......", "......."],
	" ": [".......", ".......", ".......", ".......", ".......", ".......", ".......", ".......", "......."],
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


## Rasterise one character with a hard offset shadow behind it.
##
## Flat squares on their own read as crude at wordmark scale. A one-cell
## shadow in a contrasting ink gives the letter an edge to sit against, which
## is most of the difference between a bitmap face that looks designed and one
## that looks like a placeholder.
static func draw_character_shadowed(
	canvas: CanvasItem,
	character: String,
	origin: Vector2,
	scale: float,
	colour: Color,
	shadow: Color,
	alpha: float,
	shadow_cells: float
) -> void:
	if canvas == null or scale <= 0.0 or alpha <= 0.0:
		return
	var offset := scale * shadow_cells
	draw_character(canvas, character, origin + Vector2(offset, offset), scale,
		shadow, alpha)
	draw_character(canvas, character, origin, scale, colour, alpha)
