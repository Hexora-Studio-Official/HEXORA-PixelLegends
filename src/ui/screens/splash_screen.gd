class_name SplashScreen
extends Control
## The studio sting: an explosion tears open the dark, HEXORA-STUDIO slams in
## as pixel type, and Pixel Legends settles underneath it.
##
## This is a scene, not a video, and not the engine boot splash. Videos add a
## decode step and megabytes to the APK, and the boot splash is drawn by the OS
## before Godot has even started — neither can carry an animation that belongs
## to the game. Everything here is procedural: the fire, the smoke, the type
## and the timing are all generated at runtime, so the sting costs nothing to
## ship and re-renders crisply at any resolution.
##
## The whole block — wordmark plus subtitle — is centred as one unit rather
## than the wordmark being placed at a fixed fraction of the height, so the
## composition stays balanced whatever the subtitle ends up measuring.
##
## Tap to skip. Players see this on every launch, so it is deliberately short.

# ------------------------------------------------------------------ timeline

const TIME_EXPLOSION := 0.50
const TIME_TITLE := 0.52
const TIME_SUBTITLE := 1.45
const TIME_HOLD_END := 2.90
const FADE_DURATION := 0.50

const LETTER_STAGGER := 0.05
const LETTER_DURATION := 0.32
const SUBTITLE_STAGGER := 0.045
const SUBTITLE_CHAR_DURATION := 0.30
const SUBTITLE_RISE := 26.0

# ------------------------------------------------------------------- layout

## The wordmark is sized to a fraction of the *width*, so it reads the same on
## a phone and on a desktop window.
const TITLE_WIDTH_FRACTION := 0.84
## ...but never taller than this fraction of the height.
const TITLE_MAX_HEIGHT_FRACTION := 0.22
const TITLE_TRACKING := 1
const TITLE_SHADOW_CELLS := 0.45

## Gap between the wordmark and the subtitle, as a fraction of screen height.
const SUBTITLE_GAP := 0.06
const SUBTITLE_SIZE_FRACTION := 0.072
const SUBTITLE_SIZE_MIN := 30
const SUBTITLE_SIZE_MAX := 88

const SUBTITLE_TEXT := "Pixel Legends"
const TITLE_TEXT := "HEXORA-STUDIO"

# ---------------------------------------------------------------- particles

const FIRE_COUNT := 130
const SMOKE_COUNT := 90
const SPARK_COUNT := 44

const FIRE_GRAVITY := -120.0
const FIRE_DRAG := 1.35
const SMOKE_RISE := -30.0
const SHOCKWAVE_DURATION := 0.85
const SHOCKWAVE_REACH := 0.62

## Resolution of the procedurally generated soft puff used for smoke and fire.
const PUFF_SIZE := 64

var _elapsed := 0.0
var _finishing := false
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _centre := Vector2.ZERO
var _title_scale := 12.0
var _title_origin := Vector2.ZERO
var _subtitle_size := 48
var _puff: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 0x1CE0
	_puff = _make_puff()


func _ready() -> void:
	_layout()
	resized.connect(_layout)


func _layout() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		return
	var cells := PixelFont.measure_cells(TITLE_TEXT, TITLE_TRACKING)
	var by_width := viewport.x * TITLE_WIDTH_FRACTION / float(cells.x)
	var by_height := viewport.y * TITLE_MAX_HEIGHT_FRACTION / float(PixelFont.GLYPH_H)
	_title_scale = minf(by_width, by_height)
	_subtitle_size = int(clampf(viewport.y * SUBTITLE_SIZE_FRACTION,
		float(SUBTITLE_SIZE_MIN), float(SUBTITLE_SIZE_MAX)))

	# Centre the pair as one block: wordmark, gap, then subtitle.
	var title_height := float(PixelFont.GLYPH_H) * _title_scale
	var gap := viewport.y * SUBTITLE_GAP
	var block_height := title_height + gap + float(_subtitle_size)
	var top := (viewport.y - block_height) * 0.5

	_centre = Vector2(viewport.x * 0.5, top + title_height * 0.5)
	var title_size := PixelFont.measure_pixels(TITLE_TEXT, _title_scale, TITLE_TRACKING)
	_title_origin = Vector2(_centre.x - title_size.x * 0.5, _centre.y - title_size.y * 0.5)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIME_EXPLOSION and _particles.is_empty():
		_spawn_blast()
	_advance_particles(delta)
	if not _finishing and _elapsed >= TIME_HOLD_END:
		_finishing = true
		_go_to_entrance()
	queue_redraw()


## `_input` rather than `_unhandled_input`: this control stops the mouse, so
## GUI events would be swallowed before they ever reached an unhandled hook.
func _input(event: InputEvent) -> void:
	if _finishing:
		return
	if event.is_action_pressed(&"ui_accept"):
		_skip()
		return
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_skip()
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_skip()


func _skip() -> void:
	get_viewport().set_input_as_handled()
	_finishing = true
	_go_to_entrance()


func _go_to_entrance() -> void:
	# Fade on the splash itself, then hand over. The entrance screen runs its
	# own restore and reveal, so it picks up from black cleanly.
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await fade.finished
	if Router.has_route(&"boot"):
		Router.goto(&"boot")


# ------------------------------------------------------------------ particles

## A radial alpha falloff, generated once.
##
## Smoke drawn as flat squares is just a grid of boxes. A soft falloff is what
## makes a puff read as volume, and building it from an Image means no asset
## has to be shipped or imported.
func _make_puff() -> Texture2D:
	var image := Image.create(PUFF_SIZE, PUFF_SIZE, false, Image.FORMAT_RGBA8)
	var middle := Vector2(PUFF_SIZE * 0.5, PUFF_SIZE * 0.5)
	for y in PUFF_SIZE:
		for x in PUFF_SIZE:
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(middle)
			var t := clampf(1.0 - distance / (PUFF_SIZE * 0.5), 0.0, 1.0)
			# Smoothstep, so the edge feathers instead of stepping.
			var alpha := t * t * (3.0 - 2.0 * t)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _spawn_blast() -> void:
	_rng.seed = 0x1CE0
	var reach := get_viewport_rect().size.y
	for _i in FIRE_COUNT:
		var angle := _rng.randf() * TAU
		var speed := _rng.randf_range(0.35, 1.0) * reach * 0.95
		_particles.append({
			"kind": "fire",
			"pos": _centre + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 0.4)) * reach * 0.045,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed * 0.72),
			"life": 0.0,
			"span": _rng.randf_range(0.55, 1.35),
			"size": _rng.randf_range(14.0, 40.0),
			"seed": _rng.randf(),
		})
	for _i in SMOKE_COUNT:
		var angle := _rng.randf() * TAU
		var speed := _rng.randf_range(0.1, 0.45) * reach * 0.5
		_particles.append({
			"kind": "smoke",
			"pos": _centre + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6)) * reach * 0.07,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed * 0.6),
			"life": 0.0,
			"span": _rng.randf_range(1.8, 3.6),
			"size": _rng.randf_range(46.0, 130.0),
			"seed": _rng.randf(),
		})
	for _i in SPARK_COUNT:
		var angle := _rng.randf() * TAU
		var speed := _rng.randf_range(0.6, 1.0) * reach * 1.25
		_particles.append({
			"kind": "spark",
			"pos": _centre,
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed * 0.8),
			"life": 0.0,
			"span": _rng.randf_range(0.9, 2.0),
			"size": _rng.randf_range(3.0, 6.0),
			"seed": _rng.randf(),
		})


func _advance_particles(delta: float) -> void:
	for particle in _particles:
		particle["life"] = float(particle["life"]) + delta
		var vel: Vector2 = particle["vel"]
		var kind: String = particle["kind"]
		if kind == "fire":
			vel.y -= FIRE_GRAVITY * delta
			vel *= maxf(0.0, 1.0 - FIRE_DRAG * delta)
		elif kind == "smoke":
			vel.y += SMOKE_RISE * delta
			vel *= maxf(0.0, 1.0 - 0.55 * delta)
		else:
			vel.y -= FIRE_GRAVITY * 1.7 * delta
			vel *= maxf(0.0, 1.0 - 0.85 * delta)
		particle["vel"] = vel
		particle["pos"] = (particle["pos"] as Vector2) + vel * delta


# ---------------------------------------------------------------------- draw

func _draw() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport), Design.BG)
	if _particles.is_empty():
		return
	_draw_smoke()
	_draw_fire()
	_draw_sparks()
	_draw_shockwave(viewport)
	_draw_flash(viewport)
	_draw_title()
	_draw_subtitle(viewport)


func _draw_smoke() -> void:
	var since := _elapsed - TIME_EXPLOSION
	for particle in _particles:
		if particle["kind"] != "smoke":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		# Smoke grows as it thins, and is held faint so the type stays the
		# brightest thing on screen.
		var size := float(particle["size"]) * (1.0 + t * 1.9)
		# Fade in fast, linger, then fade out — a puff that appears and
		# vanishes at the same rate looks mechanical.
		var alpha := sin(t * PI) * 0.26
		var drift := sin(since * 1.15 + float(particle["seed"]) * 6.28) * 22.0 * t
		var pos: Vector2 = particle["pos"]
		# Cooler and darker as it rises and cools.
		var tone := Color(0.42, 0.47, 0.56).lerp(Color(0.16, 0.20, 0.28), t)
		draw_texture_rect(_puff,
			Rect2(pos.x - size * 0.5 + drift, pos.y - size * 0.5, size, size),
			false, Color(tone.r, tone.g, tone.b, alpha))


func _draw_fire() -> void:
	for particle in _particles:
		if particle["kind"] != "fire":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		var pos: Vector2 = particle["pos"]
		var size := float(particle["size"]) * (1.0 - t * 0.5)
		# White-hot core, then gold, then ember, then out.
		var colour := _fire_ramp(t)
		var alpha := (1.0 - t) * (1.0 - t) * 0.95
		draw_texture_rect(_puff,
			Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size),
			false, Color(colour.r, colour.g, colour.b, alpha))


func _fire_ramp(t: float) -> Color:
	if t < 0.18:
		return Design.TEXT.lerp(Design.ACCENT_HI, t / 0.18)
	if t < 0.45:
		return Design.ACCENT_HI.lerp(Design.ACCENT, (t - 0.18) / 0.27)
	if t < 0.75:
		return Design.ACCENT.lerp(Design.ACCENT_DEEP, (t - 0.45) / 0.30)
	return Design.ACCENT_DEEP.lerp(Design.DANGER, (t - 0.75) / 0.25)


func _draw_sparks() -> void:
	for particle in _particles:
		if particle["kind"] != "spark":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		var pos: Vector2 = particle["pos"]
		var size := float(particle["size"])
		var alpha := (1.0 - t) * 0.9
		var colour := Design.ACCENT_HI if float(particle["seed"]) > 0.5 else Design.TEAL
		draw_rect(Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size),
			Color(colour.r, colour.g, colour.b, alpha))


func _draw_shockwave(viewport: Vector2) -> void:
	var since := _elapsed - TIME_EXPLOSION
	if since < 0.0 or since > SHOCKWAVE_DURATION:
		return
	var t := since / SHOCKWAVE_DURATION
	var radius := t * viewport.y * SHOCKWAVE_REACH
	var alpha := (1.0 - t) * (1.0 - t) * 0.5
	draw_arc(_centre, radius, 0.0, TAU, 64,
		Color(Design.ACCENT_HI.r, Design.ACCENT_HI.g, Design.ACCENT_HI.b, alpha),
		maxf(2.0, 14.0 * (1.0 - t)), true)


func _draw_flash(viewport: Vector2) -> void:
	var since := _elapsed - TIME_EXPLOSION
	if since < 0.0 or since > 0.30:
		return
	var alpha := (1.0 - since / 0.30) * 0.55
	draw_rect(Rect2(Vector2.ZERO, viewport),
		Color(Design.TEXT.r, Design.TEXT.g, Design.TEXT.b, alpha))


# ---------------------------------------------------------------------- type

func _draw_title() -> void:
	var since := _elapsed - TIME_TITLE
	if since < 0.0:
		return
	var advance := float(PixelFont.GLYPH_W + TITLE_TRACKING) * _title_scale
	for index in TITLE_TEXT.length():
		var start := float(index) * LETTER_STAGGER
		var t := (since - start) / LETTER_DURATION
		if t <= 0.0:
			continue
		var p := clampf(t, 0.0, 1.0)
		# Back-out ease: each letter overshoots and settles, which is what
		# makes the word feel punched in rather than faded up.
		var overshoot := 1.0 + 2.2 * pow(1.0 - p, 2.0) * sin(p * PI * 1.5)
		var letter_scale := _title_scale * (0.3 + 0.7 * p) * overshoot
		var colour := _title_colour(index, TITLE_TEXT.length())
		# Recentre the letter inside its cell as it scales, so it grows out of
		# its own middle instead of drifting right.
		var cell_w := float(PixelFont.GLYPH_W) * _title_scale
		var grown_w := float(PixelFont.GLYPH_W) * letter_scale
		var cell_h := float(PixelFont.GLYPH_H) * _title_scale
		var grown_h := float(PixelFont.GLYPH_H) * letter_scale
		var origin := Vector2(
			_title_origin.x + float(index) * advance + (cell_w - grown_w) * 0.5,
			_title_origin.y + (cell_h - grown_h) * 0.5)
		PixelFont.draw_character_shadowed(self, TITLE_TEXT.substr(index, 1), origin,
			letter_scale, colour, Design.LINE_STRONG, clampf(p * 1.4, 0.0, 1.0),
			TITLE_SHADOW_CELLS)


## Three-stop ramp across the wordmark: gold leads, cyan carries, violet
## closes. One hue per region is what keeps thirteen letters from turning
## into confetti.
func _title_colour(index: int, total: int) -> Color:
	var t := float(index) / float(maxi(1, total - 1))
	if t < 0.5:
		return Design.ACCENT.lerp(Design.TEAL, t / 0.5)
	return Design.TEAL.lerp(Design.VIOLET, (t - 0.5) / 0.5)


func _draw_subtitle(viewport: Vector2) -> void:
	var since := _elapsed - TIME_SUBTITLE
	if since < 0.0:
		return
	var font := Design.font_display
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	# Measure the running prefix rather than summing single-character widths.
	# A font's advance for a character in context is not the same as its width
	# in isolation; the difference accumulates and the glyphs end up drawn on
	# top of each other. Measuring prefixes is how text layout actually works.
	var offsets: Array[float] = []
	for index in SUBTITLE_TEXT.length() + 1:
		offsets.append(font.get_string_size(SUBTITLE_TEXT.substr(0, index), _subtitle_size).x)
	var total_width: float = offsets[SUBTITLE_TEXT.length()]

	# `draw_string` places text by its baseline, so the visual top has to be
	# derived from the font's ascent — otherwise the subtitle creeps up into
	# the wordmark on fonts with a tall ascender.
	var top := _centre.y + float(PixelFont.GLYPH_H) * _title_scale * 0.5 \
		+ viewport.y * SUBTITLE_GAP
	var baseline := top + font.get_ascent(_subtitle_size)
	var x := viewport.x * 0.5 - total_width * 0.5
	for index in SUBTITLE_TEXT.length():
		var start := float(index) * SUBTITLE_STAGGER
		var t := (since - start) / SUBTITLE_CHAR_DURATION
		if t <= 0.0:
			continue
		var p := clampf(t, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - p, 3.0)
		var colour := _subtitle_colour(index, SUBTITLE_TEXT.length())
		# A different entrance from the wordmark: each character drifts up into
		# place rather than being punched in.
		var pos := Vector2(x + offsets[index], baseline + (1.0 - eased) * SUBTITLE_RISE)
		draw_string(font, pos, SUBTITLE_TEXT.substr(index, 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, _subtitle_size,
			Color(colour.r, colour.g, colour.b, eased))


func _subtitle_colour(index: int, total: int) -> Color:
	var t := float(index) / float(maxi(1, total - 1))
	return Design.TEXT_MUTED.lerp(Design.TEAL, t * 0.85)
