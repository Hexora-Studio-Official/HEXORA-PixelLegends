#!/usr/bin/env python3
"""Regenerate src/ui/components/pixel_font.gd.

Reads the project's own Chakra Petch Bold, rasterises it onto a fine
art-pixel grid, adds an outline plus a top highlight and bottom shade,
and emits the run-length-encoded data together with the GDScript that
decodes it.

Requires:  pip install fonttools brotli pillow
Run from the repository root:  python3 tools/build_pixel_font.py
"""
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

CAP_H, RIM = 92, 3
SRC = "/home/user/HEXORA-PixelLegends/assets/fonts/ChakraPetch-Bold.woff2"
OUT = "/home/user/HEXORA-PixelLegends/src/ui/components/pixel_font.gd"

f = TTFont(SRC); f.flavor = None
f.save("/tmp/CPB.ttf")
upm = f["head"].unitsPerEm
cap = getattr(f["OS/2"], "sCapHeight", 0) or int(0.7 * upm)
size = round(CAP_H * upm / cap)
font = ImageFont.truetype("/tmp/CPB.ttf", size)
ascent, descent = font.getmetrics()
LINE_H = ascent + descent + 2
BASE = ascent + 1
CW = size * 2

def render(ch):
    im = Image.new("L", (CW, LINE_H), 0)
    ImageDraw.Draw(im).text((0, BASE), ch, fill=255, font=font, anchor="ls")
    px = im.load()
    return [[px[x, y] >= 128 for x in range(CW)] for y in range(LINE_H)]

def dilate(m):
    out = [[False] * CW for _ in range(LINE_H)]
    for y in range(LINE_H):
        for x in range(CW):
            if not m[y][x]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < LINE_H and 0 <= nx < CW:
                        out[ny][nx] = True
    return out

def build(ch):
    mask, dil = render(ch), dilate(render(ch))
    def at(y, x):
        if y < 0 or y >= LINE_H:
            return False
        return mask[y][x]
    tone = [[0] * CW for _ in range(LINE_H)]
    for y in range(LINE_H):
        for x in range(CW):
            if mask[y][x]:
                if not at(y - RIM, x):
                    tone[y][x] = 4
                elif not at(y + RIM, x):
                    tone[y][x] = 2
                else:
                    tone[y][x] = 3
            elif dil[y][x]:
                tone[y][x] = 1
    xs = [x for y in range(LINE_H) for x in range(CW) if tone[y][x]]
    ys = [y for y in range(LINE_H) if any(tone[y])]
    if not xs:
        return None
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    runs = []
    for y in range(y0, y1):
        row, run, prev = [], 0, tone[y][x0]
        for x in range(x0, x1):
            if tone[y][x] == prev:
                run += 1
            else:
                row += [run, prev]; run, prev = 1, tone[y][x]
        row += [run, prev]
        runs += row
    return {"adv": int(round(font.getlength(ch))), "dx": x0, "dy": y0,
            "w": x1 - x0, "h": y1 - y0, "runs": runs}

TEXT = "HEXORA-STUDIO"
glyphs = {c: build(c) for c in sorted(set(TEXT))}
glyphs = {c: g for c, g in glyphs.items() if g}
total_runs = sum(len(g["runs"]) for g in glyphs.values())
print("ارتفاعِ خط %d | بلندیِ بزرگ %d | حروف %d | اعدادِ داده %d"
      % (LINE_H, CAP_H, len(glyphs), total_runs))

def wrap(items, width=132):
    lines, cur = [], ""
    for it in items:
        add = ("" if not cur else ", ") + str(it)
        if len(cur) + len(add) > width:
            lines.append(cur + ","); cur = str(it)
        else:
            cur += add
    if cur:
        lines.append(cur)
    return lines

out = []
out.append('''class_name PixelFont
extends RefCounted
## A high-resolution MICRO-PIXEL typeface, stored as run-length-encoded
## bitmaps and baked into an image at runtime.
##
## The project specification is explicit about this (section 2, "Visual
## Direction", and section 29, "Final Visual Target"):
##
##   "High-Resolution 3D Pixel Art ... Micro-Pixel Stylized Graphics ...
##    Fine pixel clusters ... The game must NOT look like Minecraft."
##
## and lists among the things the game must NOT become: "Large chunky
## pixels", "Chunky pixel art", "Extremely low-resolution".
##
## The previous face here was a 7x9 grid drawn with one rectangle per cell.
## At wordmark scale that put a single art pixel at roughly 27 device pixels
## across — which is precisely the "large chunky pixel" the spec rules out.
## This face puts it at two to three device pixels, so the lettering reads as
## pixel art the way the spec asks: fine, sharp, detailed.
##
## Generated, not hand-authored: the outlines come from the project's own
## Chakra Petch Bold, rasterised at a cap height of %d art pixels, quantised
## to a hard two-level edge (no anti-aliasing — soft edges would read as
## vector text, not as pixels), then given a %d-pixel outline and a %d-pixel
## top highlight / bottom shade so the letterforms have relief at small size.
## The result is a fine pixel grid with real typography, which is what
## "high-resolution pixel" means.
##
## Storage: each glyph is one flat array of [run length, tone] pairs, scanned
## row by row. Five tones (transparent, outline, shade, body, highlight) and
## long runs of background make this far smaller than a byte per pixel.
##
## Regenerate rather than hand-edit: see tools/build_pixel_font.py.
''' % (CAP_H, 1, RIM))
out.append("const LINE_H := %d" % LINE_H)
out.append("const CAP_H := %d" % CAP_H)
out.append("")
out.append("## Tone multipliers applied to the letter's own colour, so a single")
out.append("## bitmap can be tinted per letter without a second bake.")
out.append("const TONE_OUTLINE := 0.18")
out.append("const TONE_SHADE := 0.58")
out.append("const TONE_BODY := 0.88")
out.append("const TONE_HIGHLIGHT := 1.0")
out.append("")
out.append("## `adv` is the advance in art pixels; `dx`/`dy` place the bitmap")
out.append("## relative to the pen origin; `runs` is [length, tone, ...].")
out.append("const GLYPHS := {")
for ch, g in glyphs.items():
    out.append('\t"%s": {' % ch)
    out.append('\t\t"adv": %d, "dx": %d, "dy": %d, "w": %d, "h": %d,' %
               (g["adv"], g["dx"], g["dy"], g["w"], g["h"]))
    lines = wrap(g["runs"])
    out.append('\t\t"runs": [')
    for i, line in enumerate(lines):
        out.append("\t\t\t" + line.rstrip(",") + ("," if i < len(lines) - 1 else ""))
    out.append("\t\t],")
    out.append("\t},")
out.append("}")

out.append("""

static func glyph(character: String) -> Dictionary:
	return GLYPHS.get(character.to_upper(), {})


## Size of `text` in art pixels, including tracking between characters.
static func measure_units(text: String, tracking: int) -> Vector2i:
	if text.is_empty():
		return Vector2i(0, LINE_H)
	var width := 0
	for index in text.length():
		var g := glyph(text.substr(index, 1))
		var advance := CAP_H / 2
		if not g.is_empty():
			advance = int(g["adv"])
		width += advance + tracking
	return Vector2i(maxi(1, width - tracking), LINE_H)


## Bake a whole line into one image.
##
## Returns a dictionary holding the image, the source rect of every character
## inside it, and each character's offset from the line's top-left in art
## pixels. Baking once and then drawing regions is what makes a fine art-pixel
## grid affordable: painting the same line rectangle by rectangle would be tens
## of thousands of draw commands every frame.
static func bake(text: String, tracking: int, colours: Array[Color]) -> Dictionary:
	var size := measure_units(text, tracking)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var rects: Array[Rect2i] = []
	var positions: Array[Vector2] = []
	var pen := 0
	for index in text.length():
		var g := glyph(text.substr(index, 1))
		var advance := CAP_H / 2
		if g.is_empty():
			rects.append(Rect2i())
			positions.append(Vector2())
			pen += advance + tracking
			continue
		advance = int(g["adv"])
		var colour := Color.WHITE
		if index < colours.size():
			colour = colours[index]
		var left := pen + int(g["dx"])
		var top := int(g["dy"])
		_paint(image, g, left, top, colour)
		rects.append(Rect2i(left, top, int(g["w"]), int(g["h"])))
		positions.append(Vector2(float(left), float(top)))
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


## One bitmap serves every colour: the tone levels scale the letter's own
## colour instead of storing one, so the outline is always a dark version of
## the face and the highlight its brightest version.
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
""")


pathlib_path = __import__("pathlib").Path(OUT)
pathlib_path.write_text("\n".join(out).rstrip("\n") + "\n", encoding="utf-8")
print("نوشته شد: %s  (%d خط, %.0f کیلوبایت)"
      % (OUT, len(out), pathlib_path.stat().st_size / 1024.0))
