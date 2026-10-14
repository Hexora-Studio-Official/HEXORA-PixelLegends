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

const TIME_EXPLOSION := 0.90
const TIME_TITLE := 1.05
const TIME_SUBTITLE := 2.20
const TIME_HOLD_END := 4.30
const FADE_DURATION := 0.70

const LETTER_STAGGER := 0.05
const LETTER_DURATION := 0.32

# ------------------------------------------------------------------- layout

## The wordmark is sized to a fraction of the *width*, so it reads the same on
## a phone and on a desktop window.
const TITLE_WIDTH_FRACTION := 0.86
## ...but never taller than this fraction of the height.
const TITLE_MAX_HEIGHT_FRACTION := 0.26
## Tracking and drop shadow, in ART PIXELS. The face is 92 art pixels tall at
## the cap, so these are fine adjustments rather than whole letter widths.
const TITLE_TRACKING := 4
const TITLE_SHADOW := 4

## Gap between the wordmark and the subtitle, as a fraction of screen height.
const SUBTITLE_GAP := 0.08

## The line is sized by its CAP HEIGHT, in the same art pixels the face was
## rasterised on, so the two faces stay in proportion whatever the viewport
## reports. 0.085 of the height puts the caps at about 92 design pixels —
## which is what the approved version measured.
const SUBTITLE_CAP_FRACTION := 0.085
const SUBTITLE_CAP_MIN := 30.0
const SUBTITLE_CAP_MAX := 150.0
## Tracking between subtitle letters, in art pixels.
const SUBTITLE_TRACKING := 18
## Never let the tracked line run past this fraction of the screen width.
const SUBTITLE_WIDTH_FRACTION := 0.88

## The arc. The middle of the line sits this fraction of the cap height
## HIGHER than its ends, which makes the curve a hill rather than a valley.
## Gentle on purpose: enough to read as a curve, not enough to look bent.
const SUBTITLE_ARC := 0.20

## Entrance: letters rise into place left to right, then a rule sweeps out.
const SUBTITLE_DURATION := 0.62
const SUBTITLE_STAGGER := 0.035
const SUBTITLE_CHAR_DURATION := 0.34
const SUBTITLE_RISE := 18.0
## Drop ink behind the type, and rule thickness, as fractions of cap height.
const SUBTITLE_INK := 0.035
const SUBTITLE_RULE := 0.05

const SUBTITLE_TEXT := "Pixel Legends"
const TITLE_TEXT := "HEXORA-STUDIO"

# ---------------------------------------------------------------- particles

const FIRE_COUNT := 280
const SMOKE_COUNT := 110
const SPARK_COUNT := 80
## Slow embers that outlive the burst and drift up through the whole sting.
## Without them the explosion is over in a second and the rest is static.
const EMBER_COUNT := 70
## Flat pixel squares thrown clear of the blast, tumbling as they go. They are
## what makes the burst read as shattering something rather than as a puff of
## light, and they carry the pixel language into the effect itself.
const SHARD_COUNT := 44
## Four-point sparkles that twinkle across the whole screen. Pure decoration,
## and the cheapest way to make the frame feel expensive.
const GLINT_COUNT := 34

const FIRE_GRAVITY := -120.0
const FIRE_DRAG := 1.35
const SMOKE_RISE := -30.0
const SHOCKWAVE_DURATION := 0.85
const SHOCKWAVE_REACH := 0.62
## A second, slower ring. One ring reads as a graphic; two read as a blast.
const SHOCKWAVE_2_DELAY := 0.16
const SHOCKWAVE_2_DURATION := 1.25
const SHOCKWAVE_2_REACH := 0.95

## Warm bloom flaring out of the detonation, behind the wordmark. This is what
## gives the type something to sit against in the first second.
const BLOOM_DURATION := 1.5
const BLOOM_REACH := 1.5

## Resolution of the procedurally generated soft puff used for smoke and fire.
const PUFF_SIZE := 64

var _elapsed := 0.0
var _finishing := false
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _centre := Vector2.ZERO
var _title_scale := 12.0
var _title_origin := Vector2.ZERO
## The subtitle is baked exactly like the wordmark: one image, one region per
## letter. Baking is what lets the line be set on a curve — a baked bitmap
## carries advances computed from the font at build time, so placing letters
## along an arc involves no measurement the device can disagree with.
var _subtitle_scale := 1.0
var _subtitle_texture: ImageTexture
var _subtitle_rects: Array[Rect2i] = []
var _subtitle_positions: Array[Vector2] = []
var _subtitle_line_size := Vector2i.ZERO
## The wordmark is baked once per layout, then drawn as one region per letter.
var _title_layer: Control
var _title_texture: ImageTexture
var _title_rects: Array[Rect2i] = []
var _title_positions: Array[Vector2] = []
var _title_line_size := Vector2i.ZERO
## Where the ink sits inside the line box, in art pixels. The line box carries
## the font's descent, so centring on the box rather than on the ink would push
## the wordmark visibly high.
var _title_ink_top := 0.0
var _title_ink_height := 0.0
var _puff: Texture2D
## The sting is synthesised, not loaded — the project ships no audio files —
## and a three-second cue costs enough to synthesise that doing it inline
## would stall the first frame. Building it on a worker thread keeps the
## splash smooth; if it is not ready the moment the explosion lands, the
## sound comes in a frame or two later rather than freezing the animation to
## wait for it.
var _sting: AudioStreamWAV
var _sting_thread: Thread
var _sting_started := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 0x1CE0
	_puff = _make_puff()


func _ready() -> void:
	# The subtitle face is the display face with extra tracking. The tracking
	# has to live in the font, not in the draw loop: positioning letters by
	# hand is exactly what made them collide.
	# The wordmark gets its own layer so it can use nearest-neighbour
	# filtering: an art-pixel grid has to stay hard-edged or it stops reading
	# as pixels at all. The smoke and fire behind it keep the smooth filtering
	# they need, which is why this cannot simply be set on the root.
	_title_layer = Control.new()
	_title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_layer.draw.connect(_draw_title)
	add_child(_title_layer)

	_sting_thread = Thread.new()
	_sting_thread.start(_build_sting)
	_layout()
	resized.connect(_layout)


func _exit_tree() -> void:
	if _sting_thread != null and _sting_thread.is_alive():
		_sting_thread.wait_to_finish()


func _build_sting() -> void:
	_sting = ToneSynth.sting()


func _layout() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		return
	var units := PixelFont.measure_units(TITLE_TEXT, TITLE_TRACKING)
	var by_width := viewport.x * TITLE_WIDTH_FRACTION / float(units.x)
	var by_height := viewport.y * TITLE_MAX_HEIGHT_FRACTION / float(units.y)
	_title_scale = minf(by_width, by_height)
	_bake_title()
	_subtitle_scale = _fit_subtitle_scale(viewport)
	_bake_subtitle()

	# Centre the pair as one block: wordmark ink, gap, then subtitle. The block
	# is measured on the INK rather than on the line box, because the box
	# carries the font's descent and would push the wordmark visibly high.
	var ink_height := _title_ink_height * _title_scale
	var gap := viewport.y * SUBTITLE_GAP
	var block_height := ink_height + gap + float(PixelFont.CAP_H) * _subtitle_scale \
		* (1.0 + SUBTITLE_ARC) + float(PixelFont.CAP_H) * _subtitle_scale * 0.35
	var top := (viewport.y - block_height) * 0.5

	# The wordmark's shadow is drawn offset to the right, so its ink reaches
	# past its measured width by exactly that much. Centre the ink, not the
	# glyph origin, or the visible block sits half a shadow right of centre.
	var shadow := float(TITLE_SHADOW) * _title_scale
	var line_width := float(_title_line_size.x) * _title_scale
	_title_origin = Vector2(viewport.x * 0.5 - (line_width + shadow) * 0.5, top)
	_centre = Vector2(viewport.x * 0.5,
		top + (_title_ink_top + _title_ink_height * 0.5) * _title_scale)


## Bake the whole wordmark into a single image, once per layout, with each
## letter already tinted by its place in the gradient.
func _bake_title() -> void:
	var colours: Array[Color] = []
	for index in TITLE_TEXT.length():
		colours.append(_title_colour(index, TITLE_TEXT.length()))
	var baked := PixelFont.bake(TITLE_TEXT, TITLE_TRACKING, colours)
	_title_rects = baked["rects"]
	_title_positions = baked["positions"]
	_title_line_size = baked["size"]
	_title_texture = ImageTexture.create_from_image(baked["image"])
	# Bounds of the actual ink inside the line box.
	_title_ink_top = float(_title_line_size.y)
	_title_ink_height = 0.0
	for rect in _title_rects:
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		_title_ink_top = minf(_title_ink_top, float(rect.position.y))
		_title_ink_height = maxf(_title_ink_height, float(rect.position.y + rect.size.y))
	_title_ink_height = maxf(0.0, _title_ink_height - _title_ink_top)


## Largest subtitle scale that fits both limits: the cap-height fraction, and
## the width the tracked line may occupy.
func _fit_subtitle_scale(viewport: Vector2) -> float:
	var units := PixelFont.measure_subtitle_units(SUBTITLE_TEXT.to_upper(), SUBTITLE_TRACKING)
	var by_height := clampf(viewport.y * SUBTITLE_CAP_FRACTION,
		SUBTITLE_CAP_MIN, SUBTITLE_CAP_MAX) / float(PixelFont.CAP_H)
	var by_width := viewport.x * SUBTITLE_WIDTH_FRACTION / float(units.x)
	return maxf(0.05, minf(by_height, by_width))


## Bake the subtitle with each letter already tinted by its place in the ramp.
## Cold on purpose: the wordmark above is warm gold.
func _bake_subtitle() -> void:
	var text := SUBTITLE_TEXT.to_upper()
	var colours: Array[Color] = []
	for index in text.length():
		var t := float(index) / float(maxi(1, text.length() - 1))
		colours.append(Design.TEAL.lerp(Design.VIOLET, t))
	var baked := PixelFont.bake_subtitle(text, SUBTITLE_TRACKING, colours)
	_subtitle_rects = baked["rects"]
	_subtitle_positions = baked["positions"]
	_subtitle_line_size = baked["size"]
	_subtitle_texture = ImageTexture.create_from_image(baked["image"])


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIME_EXPLOSION and _particles.is_empty():
		_spawn_blast()
	_advance_particles(delta)
	if not _finishing and _elapsed >= TIME_HOLD_END:
		_finishing = true
		_go_to_entrance()
	# Fire the sting with the detonation, but only once the worker has
	# finished: joining a finished thread returns immediately, so this never
	# blocks the frame.
	if not _sting_started and _elapsed >= TIME_EXPLOSION \
			and _sting_thread != null and not _sting_thread.is_alive():
		_sting_started = true
		_sting_thread.wait_to_finish()
		if _sting != null and Audio != null:
			Audio.play_sfx(_sting, 1.0, -3.0)

	queue_redraw()
	# The wordmark lives on its own layer, so it needs redrawing too.
	if _title_layer != null:
		_title_layer.queue_redraw()


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
			"hue": _rng.randf(),
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
			"hue": _rng.randf(),
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
			"size": _rng.randf_range(3.0, 7.0),
			"seed": _rng.randf(),
			"hue": _rng.randf(),
		})
	for _i in EMBER_COUNT:
		_particles.append({
			"kind": "ember",
			"pos": _centre + Vector2(_rng.randf_range(-1.0, 1.0) * reach * 0.55,
				_rng.randf_range(-0.35, 0.35) * reach),
			"vel": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-70.0, -26.0)),
			"life": 0.0,
			"span": _rng.randf_range(2.4, 4.2),
			"size": _rng.randf_range(2.5, 5.5),
			"seed": _rng.randf(),
			"hue": _rng.randf(),
		})
	for _i in SHARD_COUNT:
		var shard_angle := _rng.randf() * TAU
		var shard_speed := _rng.randf_range(0.5, 1.0) * reach * 0.8
		_particles.append({
			"kind": "shard",
			"pos": _centre + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3)) * reach * 0.05,
			"vel": Vector2(cos(shard_angle) * shard_speed, sin(shard_angle) * shard_speed * 0.7),
			"life": 0.0,
			"span": _rng.randf_range(1.1, 2.4),
			"size": _rng.randf_range(7.0, 19.0),
			"seed": _rng.randf(),
			"hue": _rng.randf(),
			"angle": _rng.randf() * TAU,
			"spin": _rng.randf_range(-7.0, 7.0),
		})
	for _i in GLINT_COUNT:
		_particles.append({
			"kind": "glint",
			"pos": _centre + Vector2(_rng.randf_range(-1.0, 1.0) * reach * 0.85,
				_rng.randf_range(-0.55, 0.55) * reach),
			"vel": Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-26.0, -6.0)),
			"life": 0.0,
			"span": _rng.randf_range(1.8, 4.0),
			"size": _rng.randf_range(10.0, 30.0),
			"seed": _rng.randf(),
			"hue": _rng.randf(),
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
		elif kind == "ember":
			# Embers keep rising for the whole sting, swaying gently. Their
			# sideways drift is what stops the tail of the animation from
			# looking frozen.
			var sway := sin(_elapsed * 1.7 + float(particle["seed"]) * 6.28) * 16.0
			vel.x = lerpf(vel.x, sway, minf(1.0, delta * 1.4))
			vel.y += SMOKE_RISE * 0.85 * delta
			vel *= maxf(0.0, 1.0 - 0.18 * delta)
		elif kind == "shard":
			# Shards tumble and fall: they are debris, not light.
			vel.y -= FIRE_GRAVITY * 1.25 * delta
			vel *= maxf(0.0, 1.0 - 0.62 * delta)
			particle["angle"] = float(particle["angle"]) + float(particle["spin"]) * delta
		elif kind == "glint":
			vel.y += SMOKE_RISE * 0.35 * delta
			vel *= maxf(0.0, 1.0 - 0.30 * delta)
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
	_draw_bloom(viewport)
	_draw_fire()
	_draw_shards()
	_draw_sparks()
	_draw_embers()
	_draw_glints()
	_draw_shockwave(viewport)
	_draw_flash(viewport)
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
		# Tinted, not grey: the cloud should look lit by the fire behind it.
		# Half the puffs cool through teal, half through violet, so the smoke
		# carries colour of its own instead of flattening into fog.
		var cool := Design.TEAL if float(particle["hue"]) > 0.5 else Design.VIOLET
		tone = tone.lerp(cool, 0.26 * (1.0 - t))
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
		var colour := _fire_ramp(t, float(particle["hue"]))
		var alpha := (1.0 - t) * (1.0 - t) * 0.95
		draw_texture_rect(_puff,
			Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size),
			false, Color(colour.r, colour.g, colour.b, alpha))


func _fire_ramp(t: float, hue: float) -> Color:
	if t < 0.18:
		return Design.TEXT.lerp(Design.ACCENT_HI, t / 0.18)
	if t < 0.45:
		return Design.ACCENT_HI.lerp(Design.ACCENT, (t - 0.18) / 0.27)
	if t < 0.75:
		var warm := Design.ACCENT.lerp(Design.ACCENT_DEEP, (t - 0.45) / 0.30)
		# A minority of the burst cools through violet rather than red, so the
		# fire is not one flat orange across two hundred particles.
		if hue > 0.62:
			return warm.lerp(Design.VIOLET, (hue - 0.62) / 0.38 * 0.6)
		return warm
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
		var hue := float(particle["hue"])
		var colour := Design.TEAL
		if hue > 0.66:
			colour = Design.ACCENT_HI
		elif hue > 0.33:
			colour = Design.VIOLET
		draw_rect(Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size),
			Color(colour.r, colour.g, colour.b, alpha))


## Shards: flat pixel squares thrown clear of the blast, tumbling as they go.
## A hard edge and no glow, so they read as debris rather than as more light —
## which is what gives the burst something solid in it.
func _draw_shards() -> void:
	for particle in _particles:
		if particle["kind"] != "shard":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		var pos: Vector2 = particle["pos"]
		var size := float(particle["size"]) * (1.0 - t * 0.25)
		var alpha := (1.0 - t) * (1.0 - t) * 0.9
		var hue := float(particle["hue"])
		var colour := Design.TEAL
		if hue > 0.60:
			colour = Design.ACCENT
		elif hue < 0.25:
			colour = Design.VIOLET
		draw_set_transform(pos, float(particle["angle"]), Vector2.ONE)
		draw_rect(Rect2(-size * 0.5, -size * 0.5, size, size),
			Color(colour.r, colour.g, colour.b, alpha))
	draw_set_transform(Vector2.ZERO)


## Glints: four-point sparkles — a soft halo with a bright cross — each
## twinkling on its own phase, so the frame keeps moving long after the fire
## has gone.
func _draw_glints() -> void:
	for particle in _particles:
		if particle["kind"] != "glint":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		var pos: Vector2 = particle["pos"]
		var size := float(particle["size"])
		var twinkle := absf(sin(_elapsed * 2.6 + float(particle["seed"]) * TAU))
		var alpha := sin(t * PI) * twinkle * 0.9
		if alpha <= 0.01:
			continue
		var hue := float(particle["hue"])
		var colour := Design.TEXT
		if hue > 0.66:
			colour = Design.ACCENT_HI
		elif hue > 0.33:
			colour = Design.TEAL
		var halo := size * 2.2
		draw_texture_rect(_puff,
			Rect2(pos.x - halo * 0.5, pos.y - halo * 0.5, halo, halo),
			false, Color(colour.r, colour.g, colour.b, alpha * 0.35))
		var arm := size * 0.5
		var bar := maxf(1.5, size * 0.09)
		draw_rect(Rect2(pos.x - arm * 0.5, pos.y - bar * 0.5, arm, bar),
			Color(colour.r, colour.g, colour.b, alpha))
		draw_rect(Rect2(pos.x - bar * 0.5, pos.y - arm * 0.5, bar, arm),
			Color(colour.r, colour.g, colour.b, alpha))


## Warm bloom out of the detonation, sitting behind the type. Without it the
## first second is a few particles on black; with it there is light for the
## wordmark to emerge from.
func _draw_bloom(viewport: Vector2) -> void:
	var since := _elapsed - TIME_EXPLOSION
	if since < 0.0 or since > BLOOM_DURATION:
		return
	var t := since / BLOOM_DURATION
	# Snaps to full, then decays — the shape of an actual flash.
	var alpha := (1.0 - t) * (1.0 - t) * 0.85
	var size := viewport.y * BLOOM_REACH * (0.45 + t * 0.85)
	var hot := Design.ACCENT_HI.lerp(Design.DANGER, t * 0.55)
	draw_texture_rect(_puff,
		Rect2(_centre.x - size * 0.5, _centre.y - size * 0.5, size, size),
		false, Color(hot.r, hot.g, hot.b, alpha))


## Embers: a crisp core with a soft halo, so they read as burning rather than
## as moving dots.
func _draw_embers() -> void:
	for particle in _particles:
		if particle["kind"] != "ember":
			continue
		var t := float(particle["life"]) / float(particle["span"])
		if t >= 1.0:
			continue
		var pos: Vector2 = particle["pos"]
		var size := float(particle["size"])
		# Fade in quickly, hold, then fade out over the last third.
		var alpha := sin(t * PI) * 0.85
		var warm := float(particle["seed"]) > 0.35
		var colour := Design.ACCENT if warm else Design.TEAL
		var halo := size * 7.0
		draw_texture_rect(_puff,
			Rect2(pos.x - halo * 0.5, pos.y - halo * 0.5, halo, halo),
			false, Color(colour.r, colour.g, colour.b, alpha * 0.22))
		draw_rect(Rect2(pos.x - size * 0.5, pos.y - size * 0.5, size, size),
			Color(colour.r, colour.g, colour.b, alpha))


func _draw_shockwave(viewport: Vector2) -> void:
	var since := _elapsed - TIME_EXPLOSION
	# Leading ring: fast, thick, short-lived.
	if since >= 0.0 and since <= SHOCKWAVE_DURATION:
		var t := since / SHOCKWAVE_DURATION
		var radius := t * viewport.y * SHOCKWAVE_REACH
		var alpha := (1.0 - t) * (1.0 - t) * 0.55
		draw_arc(_centre, radius, 0.0, TAU, 64,
			Color(Design.ACCENT_HI.r, Design.ACCENT_HI.g, Design.ACCENT_HI.b, alpha),
			maxf(2.0, 16.0 * (1.0 - t)), true)
	# Trailing ring: slower, thinner, wider. Two rings read as a blast; one
	# reads as a graphic.
	var second := since - SHOCKWAVE_2_DELAY
	if second >= 0.0 and second <= SHOCKWAVE_2_DURATION:
		var t2 := second / SHOCKWAVE_2_DURATION
		var radius2 := t2 * viewport.y * SHOCKWAVE_2_REACH
		var alpha2 := (1.0 - t2) * (1.0 - t2) * 0.30
		draw_arc(_centre, radius2, 0.0, TAU, 72,
			Color(Design.TEAL.r, Design.TEAL.g, Design.TEAL.b, alpha2),
			maxf(1.0, 7.0 * (1.0 - t2)), true)


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
	if since < 0.0 or _title_texture == null:
		return
	var shadow := float(TITLE_SHADOW) * _title_scale
	for index in TITLE_TEXT.length():
		var src: Rect2i = _title_rects[index]
		if src.size.x <= 0 or src.size.y <= 0:
			continue
		var start := float(index) * LETTER_STAGGER
		var t := (since - start) / LETTER_DURATION
		if t <= 0.0:
			continue
		var p := clampf(t, 0.0, 1.0)
		# Back-out ease: each letter overshoots and settles, which is what
		# makes the word feel punched in rather than faded up.
		var overshoot := 1.0 + 2.2 * pow(1.0 - p, 2.0) * sin(p * PI * 1.5)
		var letter_scale := _title_scale * (0.3 + 0.7 * p) * overshoot
		var cell := Vector2(src.size) * _title_scale
		var grown := Vector2(src.size) * letter_scale
		# Recentre the letter in its own cell as it scales, so it grows out of
		# its middle instead of drifting.
		var origin: Vector2 = _title_origin + _title_positions[index] * _title_scale \
			+ (cell - grown) * 0.5
		var ink_alpha := clampf(p * 1.4, 0.0, 1.0)
		_title_layer.draw_texture_rect_region(_title_texture,
			Rect2(origin + Vector2(shadow, shadow), grown), src,
			Color(0.0, 0.0, 0.0, ink_alpha * 0.55))
		_title_layer.draw_texture_rect_region(_title_texture, Rect2(origin, grown),
			src, Color(1.0, 1.0, 1.0, ink_alpha))


## Three-stop ramp across the wordmark: gold leads, cyan carries, violet
## closes. One hue per region is what keeps thirteen letters from turning
## into confetti.
func _title_colour(index: int, total: int) -> Color:
	var t := float(index) / float(maxi(1, total - 1))
	if t < 0.5:
		return Design.ACCENT.lerp(Design.TEAL, t / 0.5)
	return Design.TEAL.lerp(Design.VIOLET, (t - 0.5) / 0.5)

## The subtitle, set on a gentle upward arc — a hill, not a valley — so the
## line answers the shape of the wordmark instead of sagging away from it.
##
## Every letter is a region of one baked image, placed by advances that were
## computed from the font at build time. That matters: positioning real-font
## characters by hand is what made them overlap, three times over, and a curve
## needs per-letter placement. Baking removes the measurement entirely.
##
## Each letter is also turned to sit square to the curve. Without that the
## ends of an arced line read as loosely-placed rather than as curved.
func _draw_subtitle(viewport: Vector2) -> void:
	var since := _elapsed - TIME_SUBTITLE
	if since < 0.0 or _subtitle_texture == null:
		return
	var count := SUBTITLE_TEXT.length()
	var line_width := float(_subtitle_line_size.x) * _subtitle_scale
	var cap := float(PixelFont.CAP_H) * _subtitle_scale
	var arc := cap * SUBTITLE_ARC
	var left := viewport.x * 0.5 - line_width * 0.5
	var top := _title_origin.y + (_title_ink_top + _title_ink_height) * _title_scale \
		+ viewport.y * SUBTITLE_GAP
	var span := maxf(line_width, 1.0)

	# A cool glow behind the line, so it sits in light rather than on black.
	var settled := clampf(since / SUBTITLE_DURATION, 0.0, 1.0)
	var glow_h := cap * 3.2
	draw_texture_rect(_puff,
		Rect2(viewport.x * 0.5 - line_width * 0.62,
			top + arc * 0.5 - glow_h * 0.32, line_width * 1.24, glow_h),
		false, Color(Design.TEAL.r, Design.TEAL.g, Design.TEAL.b, 0.20 * settled))

	for index in count:
		var src: Rect2i = _subtitle_rects[index]
		if src.size.x <= 0 or src.size.y <= 0:
			continue
		var start := float(index) * SUBTITLE_STAGGER
		var t := (since - start) / SUBTITLE_CHAR_DURATION
		if t <= 0.0:
			continue
		var p := clampf(t, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - p, 3.0)
		# 0 at the ends of the line, 1 at its middle: the middle sits `arc`
		# higher than the ends, which is what makes the curve a hill.
		var centred := (float(index) + 0.5) / float(count) * 2.0 - 1.0
		var rise := arc * centred * centred
		# dy/dx of that parabola, so each letter leans onto the curve.
		var slope := 4.0 * arc * centred / span
		var at: Vector2 = _subtitle_positions[index]
		var source := Vector2(src.size)
		var w := source.x * _subtitle_scale
		var h := source.y * _subtitle_scale
		var cx := left + at.x * _subtitle_scale + w * 0.5
		var cy := top + at.y * _subtitle_scale + h * 0.5 + rise \
			+ (1.0 - eased) * SUBTITLE_RISE
		var ink := cap * SUBTITLE_INK
		var local := Rect2(source * -0.5, source)
		draw_set_transform(Vector2(cx + ink, cy + ink), atan(slope),
			Vector2(_subtitle_scale, _subtitle_scale))
		draw_texture_rect_region(_subtitle_texture, local, src,
			Color(0.0, 0.0, 0.0, 0.55 * eased))
		draw_set_transform(Vector2(cx, cy), atan(slope),
			Vector2(_subtitle_scale, _subtitle_scale))
		draw_texture_rect_region(_subtitle_texture, local, src,
			Color(1.0, 1.0, 1.0, eased))
	draw_set_transform(Vector2.ZERO)

	# Once the line is in, a rule sweeps out from the centre beneath it.
	var rule_t := clampf((since - SUBTITLE_DURATION * 0.4) / 0.5, 0.0, 1.0)
	if rule_t <= 0.0:
		return
	var rule_eased := 1.0 - pow(1.0 - rule_t, 3.0)
	var rule_w := line_width * rule_eased
	var rule_h := maxf(2.0, cap * SUBTITLE_RULE)
	draw_rect(Rect2(viewport.x * 0.5 - rule_w * 0.5,
		top + cap + arc + cap * 0.22, rule_w, rule_h),
		Color(Design.ACCENT.r, Design.ACCENT.g, Design.ACCENT.b, 0.9 * rule_eased))
