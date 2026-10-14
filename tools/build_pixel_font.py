#!/usr/bin/env python3
"""Regenerate src/ui/components/pixel_font.gd.

Reads the project's own Chakra Petch Bold, rasterises it onto a fine art-pixel
grid, and emits run-length-encoded glyph data plus the GDScript that decodes
it. Two faces are produced from the one source:

    GLYPHS      the wordmark — 1-pixel outline plus a 3-pixel top highlight and
                bottom shade, so the letterforms carry relief at large size.
    SUB_GLYPHS  the subtitle line — flat, no bevel. Same source, same grid,
                deliberately plainer, so the two lines read as different
                voices of one family rather than one face at two sizes.

Requires:  pip install fonttools brotli pillow
Run from the repository root:  python3 tools/build_pixel_font.py
"""
import pathlib

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "fonts" / "ChakraPetch-Bold.woff2"
OUT = ROOT / "src" / "ui" / "components" / "pixel_font.gd"

CAP_H = 92            # cap height in art pixels
WORDMARK_RIM = 3      # bevel thickness for the wordmark
WORDMARK_TEXT = "HEXORA-STUDIO"
SUBTITLE_TEXT = "PIXEL LEGENDS"

_probe = TTFont(SRC)
_probe.flavor = None
TMP = "/tmp/_pixellegends_bold.ttf"
_probe.save(TMP)

_units_per_em = _probe["head"].unitsPerEm
_cap = getattr(_probe["OS/2"], "sCapHeight", 0) or int(0.7 * _units_per_em)
_size = round(CAP_H * _units_per_em / _cap)
_font = ImageFont.truetype(TMP, _size)
_ascent, _descent = _font.getmetrics()
LINE_H = _ascent + _descent + 2
BASELINE = _ascent + 1
CANVAS_W = _size * 2


def _render(character):
    image = Image.new("L", (CANVAS_W, LINE_H), 0)
    ImageDraw.Draw(image).text((0, BASELINE), character, fill=255,
                               font=_font, anchor="ls")
    pixels = image.load()
    return [[pixels[x, y] >= 128 for x in range(CANVAS_W)] for y in range(LINE_H)]


def _dilate(mask):
    grown = [[False] * CANVAS_W for _ in range(LINE_H)]
    for y in range(LINE_H):
        for x in range(CANVAS_W):
            if not mask[y][x]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < LINE_H and 0 <= nx < CANVAS_W:
                        grown[ny][nx] = True
    return grown


def _build(character, rim):
    """Rasterise one glyph. Returns None when it has no ink (a space)."""
    mask = _render(character)
    grown = _dilate(mask)
    advance = int(round(_font.getlength(character)))

    def filled(y, x):
        if y < 0 or y >= LINE_H:
            return False
        return mask[y][x]

    tone = [[0] * CANVAS_W for _ in range(LINE_H)]
    for y in range(LINE_H):
        for x in range(CANVAS_W):
            if mask[y][x]:
                if rim > 0 and not filled(y - rim, x):
                    tone[y][x] = 4          # top highlight
                elif rim > 0 and not filled(y + rim, x):
                    tone[y][x] = 2          # bottom shade
                else:
                    tone[y][x] = 3          # body
            elif grown[y][x]:
                tone[y][x] = 1              # outline

    inked_x = [x for y in range(LINE_H) for x in range(CANVAS_W) if tone[y][x]]
    if not inked_x:
        return None
    inked_y = [y for y in range(LINE_H) if any(tone[y])]
    x0, x1 = min(inked_x), max(inked_x) + 1
    y0, y1 = min(inked_y), max(inked_y) + 1

    runs = []
    for y in range(y0, y1):
        run, previous = 0, tone[y][x0]
        row = []
        for x in range(x0, x1):
            if tone[y][x] == previous:
                run += 1
            else:
                row += [run, previous]
                run, previous = 1, tone[y][x]
        row += [run, previous]
        runs += row
    return {"adv": advance, "dx": x0, "dy": y0,
            "w": x1 - x0, "h": y1 - y0, "runs": runs}


def _table(text, rim):
    built = {}
    for character in sorted(set(text)):
        glyph = _build(character, rim)
        if glyph is None:
            # Blanks still need their advance or the line collapses.
            built[character] = {"adv": int(round(_font.getlength(character))),
                                "dx": 0, "dy": 0, "w": 0, "h": 0, "runs": []}
        else:
            built[character] = glyph
    return built


def _wrap(items, width=132):
    lines, current = [], ""
    for item in items:
        addition = ("" if not current else ", ") + str(item)
        if len(current) + len(addition) > width:
            lines.append(current + ",")
            current = str(item)
        else:
            current += addition
    if current:
        lines.append(current)
    return lines


def _emit(table):
    lines = ["{"]
    for character, glyph in table.items():
        lines.append('\t"%s": {' % character)
        lines.append('\t\t"adv": %d, "dx": %d, "dy": %d, "w": %d, "h": %d,' % (
            glyph["adv"], glyph["dx"], glyph["dy"], glyph["w"], glyph["h"]))
        wrapped = _wrap(glyph["runs"])
        if wrapped:
            lines.append('\t\t"runs": [')
            for index, row in enumerate(wrapped):
                lines.append("\t\t\t" + row.rstrip(",")
                             + ("," if index < len(wrapped) - 1 else ""))
            lines.append("\t\t],")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines)


HEADER = """class_name PixelFont
extends RefCounted
## High-resolution MICRO-PIXEL typefaces, stored as run-length-encoded bitmaps
## and baked into an image at runtime.
##
## The project specification is explicit about this (section 2, "Visual
## Direction", and section 29, "Final Visual Target"):
##
##   "High-Resolution 3D Pixel Art ... Micro-Pixel Stylized Graphics ...
##    Fine pixel clusters ... The game must NOT look like Minecraft."
##
## and lists among the things the game must NOT become: "Large chunky pixels",
## "Chunky pixel art", "Extremely low-resolution".
##
## The face this replaced was a 7x9 grid drawn one rectangle per cell, which
## put a single art pixel at roughly 27 device pixels across — precisely the
## "large chunky pixel" the spec rules out. Both faces here are rasterised at a
## cap height of __CAP__ art pixels, which lands one art pixel at two or three
## device pixels: pixel art as the spec asks for it, fine and sharp.
##
## Two faces, one source:
##
##   GLYPHS      the wordmark. Carries a 1-pixel outline and a 3-pixel top
##               highlight / bottom shade, so the letterforms hold relief at
##               wordmark scale.
##   SUB_GLYPHS  the subtitle line. Same grid, deliberately flat — no bevel —
##               and drawn smaller, so the two lines read as two voices of one
##               family rather than as one face at two sizes.
##
## Generated, not hand-authored: outlines come from the project's own Chakra
## Petch Bold, quantised to a hard two-level edge. No anti-aliasing — soft
## edges read as vector text, not as pixels.
##
## Storage: each glyph is one flat array of [run length, tone] pairs scanned
## row by row. Five tones and long background runs make this far smaller than
## a byte per pixel.
##
## Regenerate rather than hand-edit: see tools/build_pixel_font.py.
"""

API = """
const LINE_H := __LINE__
const CAP_H := __CAP__

## Tone multipliers applied to a letter's own colour, so one bitmap serves
## every colour: the outline is always a dark version of the face and the
## highlight its brightest version.
const TONE_OUTLINE := 0.18
const TONE_SHADE := 0.58
const TONE_BODY := 0.88
const TONE_HIGHLIGHT := 1.0

## `adv` is the advance in art pixels; `dx`/`dy` place the bitmap relative to
## the pen origin; `runs` is [length, tone, ...], row-major.
const GLYPHS := __WORD__

const SUB_GLYPHS := __SUB__


static func glyph(character: String) -> Dictionary:
	return GLYPHS.get(character.to_upper(), {})


static func subtitle_glyph(character: String) -> Dictionary:
	return SUB_GLYPHS.get(character.to_upper(), {})


static func measure_units(text: String, tracking: int) -> Vector2i:
	return _measure(GLYPHS, text, tracking)


static func measure_subtitle_units(text: String, tracking: int) -> Vector2i:
	return _measure(SUB_GLYPHS, text, tracking)


## Size of `text` in art pixels, including tracking between characters.
static func _measure(table: Dictionary, text: String, tracking: int) -> Vector2i:
	if text.is_empty():
		return Vector2i(0, LINE_H)
	var width := 0
	for index in text.length():
		var advance := CAP_H / 2
		var g: Dictionary = table.get(text.substr(index, 1).to_upper(), {})
		if not g.is_empty():
			advance = int(g["adv"])
		width += advance + tracking
	return Vector2i(maxi(1, width - tracking), LINE_H)


static func bake(text: String, tracking: int, colours: Array[Color]) -> Dictionary:
	return _bake(GLYPHS, text, tracking, colours)


static func bake_subtitle(text: String, tracking: int, colours: Array[Color]) -> Dictionary:
	return _bake(SUB_GLYPHS, text, tracking, colours)


## Bake a whole line into one image.
##
## Returns a dictionary holding the image, the source rect of every character
## inside it, and each character's offset from the line's top-left in art
## pixels. Baking once and then drawing regions is what makes a __CAP__-pixel
## grid affordable: painting the same line rectangle by rectangle would be tens
## of thousands of draw commands every frame.
static func _bake(table: Dictionary, text: String, tracking: int,
		colours: Array[Color]) -> Dictionary:
	var size := _measure(table, text, tracking)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var rects: Array[Rect2i] = []
	var positions: Array[Vector2] = []
	var pen := 0
	for index in text.length():
		var g: Dictionary = table.get(text.substr(index, 1).to_upper(), {})
		var advance := CAP_H / 2
		if not g.is_empty():
			advance = int(g["adv"])
		var colour := Color.WHITE
		if index < colours.size():
			colour = colours[index]
		if not g.is_empty() and int(g["w"]) > 0 and int(g["h"]) > 0:
			var left := pen + int(g["dx"])
			var top := int(g["dy"])
			_paint(image, g, left, top, colour)
			rects.append(Rect2i(left, top, int(g["w"]), int(g["h"])))
			positions.append(Vector2(float(left), float(top)))
		else:
			rects.append(Rect2i())
			positions.append(Vector2())
		pen += advance + tracking
	return {"image": image, "rects": rects, "positions": positions, "size": size}


## Replay the run-length pairs as one fill_rect per run. Runs are horizontal
## and never cross a row, so the cursor simply wraps.
static func _paint(image: Image, g: Dictionary, left: int, top: int, colour: Color) -> void:
	var runs: Array = g["runs"]
	var width: int = g["w"]
	var x := 0
	var y := 0
	var index := 0
	while index + 1 < runs.size():
		var length: int = runs[index]
		var tone: int = runs[index + 1]
		index += 2
		if tone > 0:
			image.fill_rect(Rect2i(left + x, top + y, length, 1), _tone(tone, colour))
		x += length
		if x >= width:
			x = 0
			y += 1


static func _tone(level: int, colour: Color) -> Color:
	var multiplier := TONE_BODY
	match level:
		1:
			multiplier = TONE_OUTLINE
		2:
			multiplier = TONE_SHADE
		4:
			multiplier = TONE_HIGHLIGHT
	return Color(colour.r * multiplier, colour.g * multiplier, colour.b * multiplier, colour.a)
"""


def main() -> None:
    word = _table(WORDMARK_TEXT, WORDMARK_RIM)
    sub = _table(SUBTITLE_TEXT, 0)
    print("ارتفاعِ خط %d | بلندیِ بزرگ %d" % (LINE_H, CAP_H))
    print("  عنوان: %d حرف، %d عددِ داده" % (len(word), sum(len(g["runs"]) for g in word.values())))
    print("  زیرنویس: %d حرف، %d عددِ داده" % (len(sub), sum(len(g["runs"]) for g in sub.values())))

    api = (API.replace("__LINE__", str(LINE_H))
              .replace("__CAP__", str(CAP_H))
              .replace("__WORD__", _emit(word))
              .replace("__SUB__", _emit(sub)))
    text = HEADER.replace("__CAP__", str(CAP_H)) + api
    OUT.write_text(text.rstrip("\n") + "\n", encoding="utf-8")
    print("نوشته شد: %s (%d خط، %.0f کیلوبایت)"
          % (OUT, text.count("\n"), OUT.stat().st_size / 1024.0))


if __name__ == "__main__":
    main()
