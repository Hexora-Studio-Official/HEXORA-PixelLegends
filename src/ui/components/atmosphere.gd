class_name Atmosphere
extends Control
## Living air in front of the key art: drifting embers, a soft vignette, and a
## slow light sweep.
##
## This replaces the old "breathing zoom", which scaled the full-bleed artwork
## between 1.0 and 1.035 forever. Scaling a large texture by a fraction of a
## percent makes the pixel grid shimmer: the art never actually moves, it just
## looks like it is trembling. That read as a cheap wobble, so it is gone.
##
## Nothing here touches the artwork. The embers float *in front* of it, which
## is what makes a still image feel alive without ever shaking it.

## Embers are pixel squares; these are the only sizes we ever draw, so the
## effect stays crisp at any resolution instead of turning into blurry dots.
const EMBER_SIZES: Array[float] = [2.0, 2.0, 3.0, 4.0]

## One ember per this many square pixels, clamped so phones and desktops both
## get a sensible population.
const EMBER_AREA_PER_MOTE := 26000.0
const EMBER_MIN_COUNT := 36
const EMBER_MAX_COUNT := 130

## Vertical travel speed, in logical pixels per second. Slow enough to read as
## atmosphere rather than as snow.
const RISE_SPEED_MIN := 13.0
const RISE_SPEED_MAX := 34.0

const SWAY_AMPLITUDE_MIN := 7.0
const SWAY_AMPLITUDE_MAX := 26.0
const SWAY_PERIOD_MIN := 4.0
const SWAY_PERIOD_MAX := 9.5

## How much of the screen edge the vignette darkens.
const VIGNETTE_BANDS := 16
const VIGNETTE_STRENGTH := 0.42

## The light sweep: a broad, very faint diagonal sheen crossing the screen.
const SWEEP_PERIOD := 26.0
const SWEEP_WIDTH := 0.42
const SWEEP_STRENGTH := 0.05

var _embers: Array[Dictionary] = []
var _elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()
var _cached_signature: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 0x5EED
	clip_contents = true


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if _cached_signature != size:
		_cached_signature = size
		_seed_embers()
	_draw_vignette()
	_draw_sweep()
	_draw_embers()


# ------------------------------------------------------------------- vignette

## Concentric bands rather than a gradient texture: no asset needed, no
## filtering, and it stays pixel-clean at any screen scale.
func _draw_vignette() -> void:
	var band_w := size.x / float(VIGNETTE_BANDS * 2)
	var band_h := size.y / float(VIGNETTE_BANDS * 2)
	for band in VIGNETTE_BANDS:
		var t := float(band) / float(VIGNETTE_BANDS)
		var alpha := VIGNETTE_STRENGTH * (1.0 - t) * (1.0 - t)
		if alpha <= 0.002:
			continue
		var shade := Color(Design.BG.r, Design.BG.g, Design.BG.b, alpha)
		var inset_x := band_w * float(band)
		var inset_y := band_h * float(band)
		# Top
		draw_rect(Rect2(inset_x, inset_y, size.x - inset_x * 2.0, band_h + 1.0), shade)
		# Bottom
		draw_rect(Rect2(inset_x, size.y - inset_y - band_h,
			size.x - inset_x * 2.0, band_h + 1.0), shade)
		# Left
		draw_rect(Rect2(inset_x, inset_y, band_w + 1.0, size.y - inset_y * 2.0), shade)
		# Right
		draw_rect(Rect2(size.x - inset_x - band_w, inset_y, band_w + 1.0,
			size.y - inset_y * 2.0), shade)


# ---------------------------------------------------------------- light sweep

## A single soft sheen travelling across the frame. Kept extremely faint on
## purpose: it should be felt, not noticed.
func _draw_sweep() -> void:
	var cycle := fmod(_elapsed, SWEEP_PERIOD) / SWEEP_PERIOD
	var travel := size.x * (1.0 + SWEEP_WIDTH * 2.0)
	var centre := -size.x * SWEEP_WIDTH + cycle * travel
	var strips := 18
	var strip_w := size.x * SWEEP_WIDTH / float(strips)
	for strip in strips:
		var x := centre + strip_w * float(strip)
		var t := float(strip) / float(strips - 1)
		# Raised cosine so the band has no hard edges.
		var falloff := sinf(t * PI)
		var alpha := SWEEP_STRENGTH * falloff * falloff
		if alpha <= 0.002:
			continue
		var slant := size.y * 0.16
		draw_rect(Rect2(x, -slant, strip_w + 1.0, size.y + slant * 2.0),
			Color(Design.ACCENT_HI.r, Design.ACCENT_HI.g, Design.ACCENT_HI.b, alpha))


# --------------------------------------------------------------------- embers

func _seed_embers() -> void:
	_embers.clear()
	var count := int(clampf(size.x * size.y / EMBER_AREA_PER_MOTE,
		float(EMBER_MIN_COUNT), float(EMBER_MAX_COUNT)))
	_rng.seed = 0x5EED
	for _i in count:
		_embers.append({
			"lane": _rng.randf(),
			"offset": _rng.randf() * (size.y + 80.0),
			"speed": _rng.randf_range(RISE_SPEED_MIN, RISE_SPEED_MAX),
			"size": EMBER_SIZES[_rng.randi() % EMBER_SIZES.size()],
			"sway": _rng.randf_range(SWAY_AMPLITUDE_MIN, SWAY_AMPLITUDE_MAX),
			"period": _rng.randf_range(SWAY_PERIOD_MIN, SWAY_PERIOD_MAX),
			"phase": _rng.randf() * TAU,
			"alpha": _rng.randf_range(0.28, 0.85),
			"warm": _rng.randf() > 0.42,
		})


func _draw_embers() -> void:
	var span := size.y + 80.0
	for ember in _embers:
		var risen := fmod(_elapsed * float(ember["speed"]) + float(ember["offset"]), span)
		var y := size.y + 40.0 - risen
		var sway := sinf(_elapsed * TAU / float(ember["period"]) + float(ember["phase"]))
		var x := float(ember["lane"]) * size.x + sway * float(ember["sway"])

		# Fade in from the bottom edge and out toward the top so embers never
		# pop into or out of existence on screen.
		var life := clampf(risen / span, 0.0, 1.0)
		var fade := sinf(life * PI)
		var alpha := float(ember["alpha"]) * fade
		if alpha <= 0.004:
			continue

		var base := Design.ACCENT if bool(ember["warm"]) else Design.TEAL
		var glow := base.lerp(Design.TEXT, 0.35)
		var s := float(ember["size"])
		# Snap to whole pixels: a drifting ember that lands on half pixels
		# shimmers, which is exactly the artefact this class exists to avoid.
		var px := floorf(x)
		var py := floorf(y)
		# A one-pixel halo underneath, then the ember itself.
		draw_rect(Rect2(px - s, py - s, s * 3.0, s * 3.0),
			Color(base.r, base.g, base.b, alpha * 0.16))
		draw_rect(Rect2(px, py, s, s), Color(glow.r, glow.g, glow.b, alpha))
