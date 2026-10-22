class_name SplashScreen
extends Control
## Plays the official 8-second Pixel Legends · HEXORA STUDIO video splash in full,
## then transitions cleanly to the boot entrance screen.

const VIDEO_PATH := "res://assets/video/splash_screen.ogv"
const VIDEO_ASPECT := 1920.0 / 848.0
const SAFETY_TIMEOUT_SEC := 9.2
const FADE_DURATION := 0.45

var _player: VideoStreamPlayer
var _elapsed := 0.0
var _finishing := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var frame := AspectRatioContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.ratio = VIDEO_ASPECT
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_player = VideoStreamPlayer.new()
	_player.expand = true
	_player.bus = &"Master"
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_on_video_finished)
	frame.add_child(_player)

	var stream := load(VIDEO_PATH) as VideoStream
	if stream != null:
		_player.stream = stream
		_player.play()
	else:
		_go_to_entrance()


func _process(delta: float) -> void:
	if _finishing:
		return
	_elapsed += delta
	if _elapsed >= SAFETY_TIMEOUT_SEC:
		_go_to_entrance()


func _on_video_finished() -> void:
	if _finishing:
		return
	_go_to_entrance()


func _go_to_entrance() -> void:
	if _finishing:
		return
	_finishing = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	await fade.finished
	if Router.has_route(&"boot"):
		Router.goto(&"boot")
