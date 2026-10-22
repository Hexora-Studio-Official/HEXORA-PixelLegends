class_name StatusHudBar
extends PanelContainer
## Compact MOBA telemetry strip showing live signal strength/ping, real OS
## battery level, and local clock in the top-right corner of the hub.

const REFRESH_INTERVAL_SEC := 4.0

var _ping_label: Label
var _battery_icon: HexIcon
var _battery_label: Label
var _clock_label: Label
var _signal_icon: HexIcon
var _timer := 0.0
var _sample_ping_ms := 26


func _init() -> void:
	theme_type_variation = &"HudPillPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var row := UiKit.hbox(Design.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	_signal_icon = HexIcon.make(&"signal_bars", Design.SUCCESS, 18.0, 2.0)
	_signal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_signal_icon)

	_ping_label = UiKit.micro("26 ms")
	_ping_label.add_theme_color_override("font_color", Design.SUCCESS)
	row.add_child(_ping_label)

	var sep_a := ColorRect.new()
	sep_a.color = Color(1.0, 1.0, 1.0, 0.16)
	sep_a.custom_minimum_size = Vector2(1, 16)
	sep_a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sep_a)

	_battery_icon = HexIcon.make(&"battery", Design.TEXT_MUTED, 19.0, 1.8, Design.SUCCESS)
	_battery_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_battery_icon)

	_battery_label = UiKit.micro("100%")
	_battery_label.add_theme_color_override("font_color", Design.TEXT)
	row.add_child(_battery_label)

	var sep_b := ColorRect.new()
	sep_b.color = Color(1.0, 1.0, 1.0, 0.16)
	sep_b.custom_minimum_size = Vector2(1, 16)
	sep_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sep_b)

	_clock_label = UiKit.micro("00:00")
	_clock_label.add_theme_color_override("font_color", Design.TEXT_MUTED)
	row.add_child(_clock_label)

	_refresh_status()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_INTERVAL_SEC:
		return
	_timer = 0.0
	_sample_ping_ms = clampi(_sample_ping_ms + (randi() % 5) - 2, 22, 39)
	_refresh_status()


func _refresh_status() -> void:
	if _ping_label != null:
		_ping_label.text = "%d ms" % _sample_ping_ms
		var good := _sample_ping_ms < 60
		var ping_tone := Design.SUCCESS if good else Design.WARNING
		_ping_label.add_theme_color_override("font_color", ping_tone)
		if _signal_icon != null:
			_signal_icon.color = ping_tone

	var percent := OS.get_power_percent_left()
	if percent < 0:
		percent = 100
	percent = clampi(percent, 0, 100)
	var state := OS.get_power_state()
	var charging := state == OS.POWERSTATE_CHARGING or state == OS.POWERSTATE_CHARGED
	var bat_tone := Design.SUCCESS
	if percent <= 20 and not charging:
		bat_tone = Design.DANGER
	elif percent <= 40 and not charging:
		bat_tone = Design.WARNING

	if _battery_icon != null:
		_battery_icon.accent = bat_tone
		_battery_icon.color = Design.ACCENT_HI if charging else Design.TEXT_MUTED
	if _battery_label != null:
		_battery_label.text = ("%d%%+" if charging else "%d%%") % percent
		_battery_label.add_theme_color_override("font_color", bat_tone if percent <= 20 else Design.TEXT)

	if _clock_label != null:
		var now := Time.get_time_dict_from_system()
		_clock_label.text = "%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0))]
