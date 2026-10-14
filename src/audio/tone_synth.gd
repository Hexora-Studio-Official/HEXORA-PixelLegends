class_name ToneSynth
extends RefCounted
## Tiny procedural synthesiser for interface sounds.
##
## Why generate audio instead of shipping .wav files?
##   * A menu that clicks and blips feels finished; a silent one feels broken.
##     Phase 1 has no audio budget, so we synthesise instead of cutting corners.
##   * Zero bytes in the repository, zero import settings to get wrong, and the
##     sounds are perfectly loopable and device-independent.
##   * When real sound design arrives, AudioService can swap `.ogg` files in
##     behind the same `Audio.play_ui("click")` call with no call-site change.
##
## Everything here is offline and deterministic: same build, same waveform.

## Oscillator shapes available to a Voice. NOISE ignores frequency and uses
## the phase as a random source, which keeps the sample loop uniform.
enum Wave { SINE, SQUARE, TRIANGLE, SAW, NOISE }

const MIX_RATE := 44100
const PEAK := 32000.0        ## Headroom below int16 full scale.


## One component of a sound: a swept oscillator plus optional noise, with
## attack/decay envelopes. Mix several of these with `mix()` to build a cue.
class Voice extends RefCounted:
	var wave: int = Wave.SINE
	var freq_start: float = 440.0
	var freq_end: float = 440.0
	var duration: float = 0.1
	var delay: float = 0.0
	var gain: float = 0.4
	var attack: float = 0.002
	var decay: float = 0.06         ## Exponential decay time constant.
	var noise_amount: float = 0.0   ## 0..1, mixed on top of the oscillator.
	var noise_smoothing: float = 0.5 ## 0 = white, 1 = very muffled.
	var sweep_curve: float = 1.0    ## >1 = fast initial sweep, <1 = late sweep.

	## One-pole low-pass state for the noise component. A Voice is rendered
	## exactly once, so carrying the state on the instance is safe and avoids
	## allocating a filter object per sample.
	var _noise_low_pass: float = 0.0

	func _init(config: Dictionary = {}) -> void:
		for key: String in config:
			set(key, config[key])

	## Sample at absolute time `t` (seconds from the start of the whole cue).
	## Returns 0 outside this voice's own window.
	func sample(t: float, rng: RandomNumberGenerator) -> float:
		var local := t - delay
		if local < 0.0 or local > duration:
			return 0.0
		var progress := local / duration
		var frequency := lerpf(freq_start, freq_end, pow(progress, sweep_curve))
		var phase := fmod(local * frequency, 1.0)
		var tone := _wave_at(phase)
		if noise_amount > 0.0:
			# One-pole low pass over white noise. Rolling the noise off is what
			# keeps a 40 ms blip sounding like metal rather than static.
			var white := rng.randf_range(-1.0, 1.0)
			var coefficient := 1.0 - clampf(noise_smoothing, 0.0, 0.95)
			_noise_low_pass += (white - _noise_low_pass) * coefficient
			tone = lerpf(tone, _noise_low_pass, clampf(noise_amount, 0.0, 1.0))
		return tone * gain * _envelope(local)

	func _envelope(local: float) -> float:
		var attack := maxf(attack, 0.0005)
		if local < attack:
			return local / attack
		return exp(-(local - attack) / maxf(decay, 0.005))

	func _wave_at(phase: float) -> float:
		match wave:
			Wave.SQUARE: return 1.0 if phase < 0.5 else -1.0
			Wave.TRIANGLE: return 4.0 * absf(phase - 0.5) - 1.0
			Wave.SAW: return 2.0 * phase - 1.0
			Wave.NOISE: return phase * 2.0 - 1.0
			_: return sin(phase * TAU)


## Mix voices into one AudioStreamWAV. The stream is mono 16-bit PCM, which
## plays on every supported platform without a decoder.
static func mix(voices: Array, total_duration: float = -1.0, seed_value: int = 0) -> AudioStreamWAV:
	var span := total_duration
	if span <= 0.0:
		for voice: Voice in voices:
			span = maxf(span, voice.delay + voice.duration)

	var frames := maxi(1, int(span * float(MIX_RATE)))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for frame in frames:
		var t := float(frame) / float(MIX_RATE)
		var sample := 0.0
		for voice: Voice in voices:
			sample += voice.sample(t, rng)
		# Soft clip rather than hard clip: a hard limit on a summed cue adds
		# broadband crackle that is audible on phone speakers.
		sample = _soft_clip(sample)
		data.encode_s16(frame * 2, int(clampf(sample, -1.0, 1.0) * PEAK))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Keep a summed cue inside full scale without the broadband crackle a hard
## clamp produces: linear below the threshold, then an exponential approach to
## 1.0. Continuous and monotonic, so no click at the knee.
static func _soft_clip(value: float) -> float:
	const THRESHOLD := 0.7
	var magnitude := absf(value)
	if magnitude <= THRESHOLD:
		return value
	var over := (magnitude - THRESHOLD) / (1.0 - THRESHOLD)
	var mapped := THRESHOLD + (1.0 - THRESHOLD) * (1.0 - exp(-over))
	return mapped if value > 0.0 else -mapped


## Short, dry "tick" for pointer hover / focus move. Deliberately quiet: it
## fires constantly.
static func hover() -> AudioStreamWAV:
	return mix([Voice.new({
		"wave": Wave.SINE, "freq_start": 2100.0, "freq_end": 1800.0,
		"duration": 0.035, "gain": 0.16, "decay": 0.012,
	})], 0.04, 11)


## The main confirm/click cue: a short noise transient with a low sine thump.
## Reads as "machined metal", which matches the art direction.
static func click() -> AudioStreamWAV:
	return mix([
		Voice.new({
			"wave": Wave.NOISE, "freq_start": 1200.0, "freq_end": 600.0,
			"duration": 0.05, "gain": 0.34, "decay": 0.014,
			"noise_amount": 0.85, "attack": 0.0008,
		}),
		Voice.new({
			"wave": Wave.SINE, "freq_start": 520.0, "freq_end": 300.0,
			"duration": 0.09, "gain": 0.32, "decay": 0.03,
		}),
	], 0.1, 23)


## Rising two-note cue for a successful action (sign-in, room created).
static func confirm() -> AudioStreamWAV:
	return mix([
		Voice.new({"wave": Wave.TRIANGLE, "freq_start": 660.0, "freq_end": 660.0,
			"duration": 0.12, "gain": 0.30, "decay": 0.05}),
		Voice.new({"wave": Wave.TRIANGLE, "freq_start": 990.0, "freq_end": 990.0,
			"duration": 0.22, "delay": 0.075, "gain": 0.28, "decay": 0.09}),
		Voice.new({"wave": Wave.SINE, "freq_start": 1980.0, "freq_end": 1980.0,
			"duration": 0.16, "delay": 0.075, "gain": 0.10, "decay": 0.06}),
	], 0.34, 31)


## Descending cue for "no", "failed" or a locked action.
static func error() -> AudioStreamWAV:
	return mix([
		Voice.new({"wave": Wave.SQUARE, "freq_start": 260.0, "freq_end": 150.0,
			"duration": 0.20, "gain": 0.22, "decay": 0.08}),
		Voice.new({"wave": Wave.SINE, "freq_start": 130.0, "freq_end": 90.0,
			"duration": 0.24, "gain": 0.20, "decay": 0.10}),
	], 0.28, 47)


## Short backward cue for the back/cancel action.
static func back() -> AudioStreamWAV:
	return mix([Voice.new({
		"wave": Wave.TRIANGLE, "freq_start": 620.0, "freq_end": 320.0,
		"duration": 0.09, "gain": 0.26, "decay": 0.035, "sweep_curve": 0.7,
	})], 0.11, 59)


## Toggle-on: a single bright blip.
static func toggle_on() -> AudioStreamWAV:
	return mix([Voice.new({
		"wave": Wave.SINE, "freq_start": 880.0, "freq_end": 1320.0,
		"duration": 0.07, "gain": 0.22, "decay": 0.03,
	})], 0.09, 67)


## Toggle-off: the same gesture inverted.
static func toggle_off() -> AudioStreamWAV:
	return mix([Voice.new({
		"wave": Wave.SINE, "freq_start": 880.0, "freq_end": 520.0,
		"duration": 0.07, "gain": 0.20, "decay": 0.03,
	})], 0.09, 71)


## Airy sweep used when a panel slides in.
static func whoosh() -> AudioStreamWAV:
	return mix([
		Voice.new({
			"wave": Wave.NOISE, "freq_start": 900.0, "freq_end": 200.0,
			"duration": 0.30, "gain": 0.20, "decay": 0.12,
			"noise_amount": 0.9, "attack": 0.02,
		}),
	], 0.32, 83)


## Low double pulse that repeats under a matchmaking search. Long enough to be
## a musical element rather than a UI tick.
static func search_pulse() -> AudioStreamWAV:
	return mix([
		Voice.new({"wave": Wave.SINE, "freq_start": 180.0, "freq_end": 150.0,
			"duration": 0.45, "gain": 0.30, "decay": 0.16}),
		Voice.new({"wave": Wave.TRIANGLE, "freq_start": 90.0, "freq_end": 72.0,
			"duration": 0.55, "gain": 0.22, "decay": 0.22}),
		Voice.new({"wave": Wave.SINE, "freq_start": 720.0, "freq_end": 720.0,
			"duration": 0.25, "delay": 0.22, "gain": 0.08, "decay": 0.08}),
	], 0.62, 97)


## Every cue by name, so the Settings "test tone" button and the audio service
## share one table. Names are stable identifiers, not localised text.
## The studio sting: a detonation that blooms into light.
##
## Layered the way a film sting is layered rather than as one synthesised
## blip — a sub-bass body for weight, a noise crack on top for the transient
## that makes it read as an impact, air being pushed outward, a slow chord
## swelling as the light spreads, and a chime when the subtitle lands.
##
## Separation comes from register and envelope: there is no stereo field to
## place voices in, so they are kept apart by frequency instead.
##
## Deliberately NOT in `cue_names()`. Building this takes long enough to
## stall a frame, and the audio service synthesises every named cue at
## startup — one more second there would be felt by everyone, including
## players who never reach the splash. Callers that want it build it
## themselves.
static func sting() -> AudioStreamWAV:
	var voices: Array[Voice] = []
	# Body: the weight of the hit.
	voices.append(Voice.new({
		"wave": Wave.SINE, "freq_start": 120.0, "freq_end": 32.0,
		"duration": 1.2, "decay": 0.34, "gain": 0.78, "attack": 0.002,
		"sweep_curve": 2.0,
	}))
	voices.append(Voice.new({
		"wave": Wave.SINE, "freq_start": 55.0, "freq_end": 27.0,
		"duration": 2.1, "decay": 0.55, "gain": 0.58, "attack": 0.004,
	}))
	# Crack: the transient that makes it an impact rather than a hum.
	voices.append(Voice.new({
		"wave": Wave.SINE, "freq_start": 3200.0, "freq_end": 700.0,
		"duration": 0.22, "decay": 0.05, "gain": 0.28, "attack": 0.001,
		"noise_amount": 0.65, "noise_smoothing": 0.30,
	}))
	# Air pushed out of the blast.
	voices.append(Voice.new({
		"wave": Wave.SINE, "freq_start": 1100.0, "freq_end": 180.0,
		"duration": 1.5, "decay": 0.42, "gain": 0.20, "attack": 0.02,
		"noise_amount": 0.85, "noise_smoothing": 0.78,
	}))
	# Bloom: a slow chord swelling as the light spreads.
	for frequency in [523.25, 659.25, 783.99]:
		voices.append(Voice.new({
			"wave": Wave.SINE, "freq_start": frequency * 0.985,
			"freq_end": frequency, "duration": 2.0, "delay": 0.85,
			"decay": 0.95, "gain": 0.12, "attack": 0.22,
		}))
	# Chime as the subtitle lands.
	voices.append(Voice.new({
		"wave": Wave.SINE, "freq_start": 880.0, "freq_end": 1318.5,
		"duration": 1.1, "delay": 2.25, "decay": 0.50, "gain": 0.16,
		"attack": 0.004,
	}))
	return mix(voices, 3.35, 0x5714)


static func cue(name: String) -> AudioStreamWAV:
	match name:
		"hover": return hover()
		"click": return click()
		"confirm": return confirm()
		"error": return error()
		"back": return back()
		"toggle_on": return toggle_on()
		"toggle_off": return toggle_off()
		"whoosh": return whoosh()
		"search_pulse": return search_pulse()
		"sting": return sting()
		_:
			push_warning("ToneSynth: unknown cue '%s'." % name)
			return click()


static func cue_names() -> PackedStringArray:
	return PackedStringArray([
		"hover", "click", "confirm", "error", "back",
		"toggle_on", "toggle_off", "whoosh", "search_pulse",
	])
