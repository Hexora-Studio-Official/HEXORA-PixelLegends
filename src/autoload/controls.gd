extends Node
## Input map and control-scheme state.
##
## Every action in `GameTypes.GameAction` is registered here at boot, so the
## project file does not have to carry an enormous `[input]` section and the
## defaults can be generated for three schemes (touch, gamepad, keyboard)
## from one table.
##
## Why register at runtime rather than in project.godot? Because the mapping
## depends on the player's preset, and because a missing action in an exported
## build is a silent input failure that is very hard to debug. A table plus a
## boot-time assertion is far more reliable.
##
## Phase 2 adds the on-screen touch controls; this service is already the
## single place they will read their layout and sensitivity from.

const ACTION_PREFIX := "hex_"

## Keyboard + mouse defaults, used on desktop for testing and by players who
## pair a mouse with their phone.
const KEYBOARD_BINDINGS := {
	"move_forward": [[KEY_W, false], [KEY_UP, false]],
	"move_back": [[KEY_S, false], [KEY_DOWN, false]],
	"move_left": [[KEY_A, false], [KEY_LEFT, false]],
	"move_right": [[KEY_D, false], [KEY_RIGHT, false]],
	"sprint": [[KEY_SHIFT, false]],
	"crouch": [[KEY_CTRL, false], [KEY_C, false]],
	"jump": [[KEY_SPACE, false]],
	"fire": [],
	"aim": [],
	"reload": [[KEY_R, false]],
	"melee": [[KEY_V, false]],
	"grenade": [[KEY_G, false]],
	"interact": [[KEY_F, false]],
	"scoreboard": [[KEY_TAB, false]],
	"map": [[KEY_M, false]],
	"ping": [[KEY_Z, false]],
}

## Gamepad / controller defaults. Left stick is bound as an axis pair.
const GAMEPAD_BUTTONS := {
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"crouch": [JOY_BUTTON_B],
	"jump": [JOY_BUTTON_A],
	"fire": [JOY_BUTTON_RIGHT_SHOULDER],
	"aim": [JOY_BUTTON_LEFT_SHOULDER],
	"reload": [JOY_BUTTON_X],
	"melee": [JOY_BUTTON_RIGHT_STICK],
	"grenade": [JOY_BUTTON_Y],
	"interact": [JOY_BUTTON_X],
	"scoreboard": [JOY_BUTTON_BACK],
	"map": [JOY_BUTTON_BACK],
	"ping": [JOY_BUTTON_DPAD_UP],
}

const GAMEPAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"aim": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


## Gamepad stick dead zone, kept here so the touch layer and the gamepad layer
## agree on when a stick counts as "moved". Written from the controls settings.
var _deadzone: float = 0.18


func _ready() -> void:
	register_actions()
	apply_preset(Settings.get_int("controls/preset"))
	EventBus.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(section: StringName) -> void:
	if section == &"controls" or section == &"game":
		apply_input_defaults()


# ------------------------------------------------------------ registration

## Create every action with the prefix applied. Safe to call twice.
func register_actions() -> void:
	for action in _action_names():
		var name := ACTION_PREFIX + action
		if not InputMap.has_action(name):
			InputMap.add_action(name, 0.2)
	_apply_keyboard()
	_apply_gamepad()


func _action_names() -> Array[String]:
	var names: Array[String] = []
	for slug in GameTypes.action_slugs():
		names.append(String(slug))
	return names


## GameTypes.GameAction -> the snake_case part of the action name.
func _action_string(action: int) -> String:
	return String(GameTypes.action_slug(action))


func action_name(action: int) -> StringName:
	return StringName(ACTION_PREFIX + _action_string(action))


## True while the *logical* action is held, whatever device produced it.
func is_pressed(action: int) -> bool:
	return Input.is_action_pressed(action_name(action))


func strength(action: int) -> float:
	return Input.get_action_strength(action_name(action))


func just_pressed(action: int) -> bool:
	return Input.is_action_just_pressed(action_name(action))


func _apply_keyboard() -> void:
	for action: String in KEYBOARD_BINDINGS:
		var name := ACTION_PREFIX + action
		for binding: Array in KEYBOARD_BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = int(binding[0])
			_add_if_missing(name, event)

	# Mouse buttons for a desktop-with-mouse setup.
	_add_if_missing(ACTION_PREFIX + "fire", _mouse_button(MOUSE_BUTTON_LEFT))
	_add_if_missing(ACTION_PREFIX + "aim", _mouse_button(MOUSE_BUTTON_RIGHT))
	_add_if_missing(ACTION_PREFIX + "melee", _mouse_button(MOUSE_BUTTON_MIDDLE))


func _apply_gamepad() -> void:
	for action: String in GAMEPAD_BUTTONS:
		var name := ACTION_PREFIX + action
		for button: int in GAMEPAD_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			_add_if_missing(name, event)
	for action: String in GAMEPAD_AXES:
		var name := ACTION_PREFIX + action
		var axis_data: Array = GAMEPAD_AXES[action]
		var event := InputEventJoypadMotion.new()
		event.axis = int(axis_data[0])
		event.axis_value = float(axis_data[1])
		_add_if_missing(name, event)


## Add an event unless an equivalent one is already bound. Keeps the boot path
## idempotent, which matters because Settings can re-apply on language change.
func _add_if_missing(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)


func _mouse_button(button: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


# ------------------------------------------------------------------ schemes

## Preset index matches the Settings order:
## 0 touch (two thumbs) · 1 touch (three fingers) · 2 gamepad · 3 keyboard
func apply_preset(preset: int) -> void:
	var touch_scheme := preset <= 1
	# Touch devices should not fight the emulated mouse for the fire button.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if touch_scheme else Input.MOUSE_MODE_CAPTURED)
	Input.emulate_mouse_from_touch = touch_scheme
	_apply_deadzone(Settings.get_float("controls/gamepad_deadzone", 0.18))


func _apply_deadzone(value: float) -> void:
	# Applied where we read axis values; stored so the touch layer and the
	# gamepad layer agree on when a stick counts as "moved".
	_deadzone = clampf(value, 0.0, 0.6)


func deadzone() -> float:
	return _deadzone


func apply_input_defaults() -> void:
	_apply_deadzone(Settings.get_float("controls/gamepad_deadzone", 0.18))
	apply_preset(Settings.get_int("controls/preset"))


# -------------------------------------------------------------- feel helpers

## Look sensitivity in radians per normalised input unit. The Settings slider
## stores 0..1 where the middle is what most players expect.
func look_sensitivity() -> float:
	return lerpf(0.0008, 0.0065, Settings.get_float("controls/sensitivity", 0.55))


func ads_sensitivity() -> float:
	var multiplier := clampf(Settings.get_float("controls/ads_sensitivity", 0.75), 0.1, 2.0)
	return look_sensitivity() * multiplier


func inverted_y() -> bool:
	return Settings.get_bool("controls/invert_y", false)


## Short haptic pulse, respecting the player's setting. `strength` is
## millisecond duration on Android; 0 stops any ongoing vibration.
func haptic(duration_ms: int = 25) -> void:
	if not OS.has_feature("mobile") or duration_ms <= 0:
		return
	if not Settings.get_bool("game/vibration", true):
		return
	Input.vibrate_handheld(duration_ms)


## Swipe-to-look helper shared by the touch layer and the desktop debug view.
## Returns the rotation delta in radians for a pixel delta.
func look_delta(pixel_delta: Vector2, aiming: bool = false) -> Vector2:
	var sensitivity := ads_sensitivity() if aiming else look_sensitivity()
	var invert := -1.0 if inverted_y() else 1.0
	return Vector2(
		-pixel_delta.x * sensitivity,
		-pixel_delta.y * sensitivity * invert
	)
