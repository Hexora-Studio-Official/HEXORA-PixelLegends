extends Node
## Input and touch-feedback service for the PixelLegends client shell.
##
## Why this still exists after the legacy cleanup: pressing a button should
## *feel* like pressing a button. `haptic()` is the one input concern the
## current shell genuinely owns, and three call sites already route through
## it (`UiKit.on_press`, `Audio.feedback`, and the settings rows), so it stays
## a real service instead of being copied into each of them.
##
## What was removed (2026-10-14): the first-person input map (WASD, sprint,
## crouch, jump, fire, aim, reload, melee, grenade) and the look/ADS
## sensitivity helpers. Those belonged to a different game, and they were
## silently registering sixteen InputMap actions at boot that nothing in a
## MOBA would ever fire.
##
## The MOBA touch controls — virtual joystick, basic-attack button, ability
## buttons, ultimate, recall — are specified in docs/PROJECT_SPEC.txt
## section 21. They are NOT implemented here and must not be guessed at
## before that gameplay phase is approved.

const DEFAULT_HAPTIC_MS := 12


## Short haptic pulse, respecting the player's setting. `duration_ms` is the
## vibration length on Android; 0 stops any ongoing vibration.
##
## No-ops on desktop, where `Input.vibrate_handheld()` has nothing to vibrate.
func haptic(duration_ms: int = DEFAULT_HAPTIC_MS) -> void:
	if duration_ms <= 0:
		return
	if not OS.has_feature("mobile"):
		return
	if not Settings.get_bool("game/vibration", true):
		return
	Input.vibrate_handheld(duration_ms)
