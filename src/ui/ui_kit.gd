class_name UiKit
extends RefCounted
## Widget factory used by every screen.
##
## Screens describe *what* they need ("a muted caption", "a primary button with
## a play icon") and this file decides how that looks. The result is that a
## change to spacing or emphasis is one edit here rather than a hunt through
## eight screens, and it is the reason no screen in this project contains a
## StyleBoxFlat.
##
## Everything returns a live node. Callers that need to update text later keep
## the reference, or reach for `set_label_text()` so a button's inner label
## stays an implementation detail.

const META_LABEL := &"hex_label"
const META_ICON := &"hex_icon"


# ------------------------------------------------------------------- labels

static func label(text: String, variation: StringName = &"BodyLabel") -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.layout_direction = Loc.layout_direction()
	return node


static func display(text: String) -> Label:
	return label(text, &"DisplayLabel")


static func heading(text: String) -> Label:
	return label(text, &"HeadingLabel")


static func subheading(text: String) -> Label:
	return label(text, &"SubheadingLabel")


static func muted(text: String) -> Label:
	return label(text, &"BodyMutedLabel")


static func caption(text: String) -> Label:
	return label(text, &"CaptionLabel")


static func micro(text: String) -> Label:
	return label(text, &"MicroLabel")


## Wrapping body text with a sane maximum width, for descriptions and warnings.
static func paragraph(text: String, max_width: float = 520.0,
		variation: StringName = &"BodyMutedLabel") -> Label:
	var node := label(text, variation)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(0, 0)
	node.max_lines_visible = -1
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.set_meta("max_width", max_width)
	return node


static func label_text(node: Control) -> Label:
	return node.get_meta(META_LABEL, null) as Label


static func set_label_text(node: Control, text: String) -> void:
	var inner := label_text(node)
	if inner != null:
		inner.text = text
	elif node is Label:
		(node as Label).text = text


# --------------------------------------------------------------- containers

static func vbox(separation: int = Design.SPACE_MD) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = Design.SPACE_SM) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func grid(columns: int, separation: int = Design.SPACE_MD) -> GridContainer:
	var box := GridContainer.new()
	box.columns = maxi(1, columns)
	box.add_theme_constant_override("h_separation", separation)
	box.add_theme_constant_override("v_separation", separation)
	return box


static func scroll(follow_focus: bool = false) -> ScrollContainer:
	var container := ScrollContainer.new()
	container.theme_type_variation = &"HexScrollContainer"
	container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	container.follow_focus = follow_focus
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return container


## Horizontal breathing room inside a scroll container.
static func spacer(expand: bool = true, minimum: float = 0.0) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(minimum, 0)
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func vertical_spacer(height: float) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(0, height)
	return node


static func divider(color: Color = Design.LINE, thickness: int = 1) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, thickness)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# ------------------------------------------------------------------ surfaces

static func panel(variation: StringName = &"CardPanel") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	return node


## Big rounded container with a hairline border — the standard page section.
static func card(title_key: StringName = &"", body: Control = null) -> PanelContainer:
	var container := panel(&"CardPanel")
	var column := vbox(Design.SPACE_MD)
	container.add_child(column)
	if title_key != &"":
		var header := hbox(Design.SPACE_SM)
		header.add_child(micro(Loc.t(title_key).to_upper()))
		header.add_child(divider(Design.LINE, 1))
		column.add_child(header)
	if body != null:
		column.add_child(body)
	return container


static func section_header(title: String, trailing: Control = null) -> HBoxContainer:
	var row := hbox(Design.SPACE_MD)
	row.add_child(label(title, &"SectionLabel"))
	var line := divider(Design.LINE, 1)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	if trailing != null:
		row.add_child(trailing)
	return row


# ------------------------------------------------------------------- inputs

## Text button, optionally with a leading vector icon.
##
## A `Button` with an inner `HBoxContainer` rather than `Button.text`, because
## our icons are Controls, not textures. The children are click-transparent so
## the whole surface stays one tap target.
static func button(
	text: String, variation: StringName = &"SecondaryButton",
	icon_kind: StringName = &"", tooltip: String = ""
) -> Button:
	var node := Button.new()
	node.theme_type_variation = variation
	node.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
	if not tooltip.is_empty():
		node.tooltip_text = tooltip

	var row := hbox(Design.SPACE_SM)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(row)

	if icon_kind != &"":
		var icon_color := _button_text_color(variation)
		var icon := HexIcon.make(icon_kind, icon_color, 20.0, 2.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		node.set_meta(META_ICON, icon)

	var inner := label(text, &"BodyLabel")
	inner.add_theme_color_override("font_color", _button_text_color(variation))
	inner.add_theme_font_override("font", Design.font_label)
	inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(inner)
	node.set_meta(META_LABEL, inner)
	return node


static func _button_text_color(variation: StringName) -> Color:
	match variation:
		&"PrimaryButton": return Design.TEXT_INVERSE
		&"DangerButton": return Design.DANGER
		&"TealButton": return Design.TEAL
		&"GhostButton": return Design.TEXT_MUTED
		_: return Design.TEXT


## Small square-ish icon-only button for toolbars.
static func icon_button(kind: StringName, color: Color = Design.TEXT_MUTED,
		pixel_size: float = 24.0, tooltip: String = "") -> Button:
	var node := Button.new()
	node.theme_type_variation = &"IconButton"
	node.custom_minimum_size = Vector2(Design.TOUCH_TARGET_MIN, Design.TOUCH_TARGET_MIN)
	if not tooltip.is_empty():
		node.tooltip_text = tooltip

	var icon := HexIcon.make(kind, color, pixel_size, 2.0)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2.ZERO
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	node.add_child(icon)
	node.set_meta(META_ICON, icon)
	return node


## Large selectable tile describing one game mode. The visual language lives
## here so the mode picker, the room browser and the lobby all agree on what a
## ruleset looks like.
static func mode_card(mode: GameMode, selected: bool = false,
		on_toggle: Callable = Callable()) -> Button:
	var node := Button.new()
	node.theme_type_variation = &"CardButtonActive" if selected else &"CardButton"
	node.custom_minimum_size = Vector2(296, 128)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_NONE

	var row := hbox(Design.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(row)

	var icon := HexIcon.make(mode.icon_kind, mode.accent, 36.0, 2.0, mode.accent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var column := vbox(Design.SPACE_XXS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	var title := label(Loc.t(mode.title_key), &"SubheadingLabel")
	column.add_child(title)
	column.add_child(paragraph(Loc.t(mode.rules_key), 220.0, &"CaptionLabel"))

	var tags := hbox(Design.SPACE_XS)
	tags.add_child(pill(mode.format_tag(), mode.accent))
	if mode.ranked:
		tags.add_child(pill(Loc.t(&"play.ranked"), Design.TEAL))
	if not mode.supports_lan:
		tags.add_child(pill(Loc.t(&"common.online"), Design.TEXT_MUTED))
	column.add_child(tags)

	node.set_meta(META_LABEL, title)
	node.set_meta(META_ICON, icon)
	node.set_meta(&"accent", mode.accent)
	if on_toggle.is_valid():
		node.pressed.connect(func() -> void: on_toggle.call(mode.id))
	return node


## Restyle a mode card in place. Cheaper and less flickery than rebuilding the
## whole grid every time a mode is toggled.
static func set_card_active(node: Button, active: bool) -> void:
	node.theme_type_variation = &"CardButtonActive" if active else &"CardButton"
	var accent := node.get_meta(&"accent", Design.ACCENT) as Color
	var icon := node.get_meta(META_ICON, null) as HexIcon
	if icon != null:
		icon.accent = accent
	var title := label_text(node)
	if title != null:
		title.add_theme_color_override("font_color", Design.ACCENT_HI if active else Design.TEXT)


## Selectable chip, used for modes, regions and filters.
static func chip(text: String, active: bool = false, icon_kind: StringName = &"") -> Button:
	var node := button(text, &"ChipButtonActive" if active else &"ChipButton", icon_kind)
	node.custom_minimum_size = Vector2(0, 40)
	return node


static func set_chip_active(node: Button, active: bool) -> void:
	node.theme_type_variation = &"ChipButtonActive" if active else &"ChipButton"
	var inner := label_text(node)
	if inner != null:
		inner.add_theme_color_override("font_color",
			Design.ACCENT_HI if active else Design.TEXT_MUTED)
	var icon := node.get_meta(META_ICON, null) as HexIcon
	if icon != null:
		icon.color = Design.ACCENT_HI if active else Design.TEXT_MUTED


# ---------------------------------------------------------------- data display

## Caption-over-value block. The workhorse of the profile and lobby screens.
static func stat_tile(caption: String, value: String, tone: Color = Design.TEXT) -> Control:
	var holder := panel(&"ChipPanel")
	var column := vbox(Design.SPACE_XXS)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(column)

	var value_label := label(value, &"ValueLabel")
	value_label.add_theme_color_override("font_color", tone)
	column.add_child(value_label)

	var caption_label := micro(caption.to_upper())
	column.add_child(caption_label)
	holder.set_meta(&"value_label", value_label)
	return holder


static func set_stat_value(tile: Control, value: String) -> void:
	var inner := tile.get_meta(&"value_label", null) as Label
	if inner != null:
		inner.text = value


## Small rounded label for statuses: "HOTSPOT", "RANKED", "SAMPLE".
static func pill(text: String, tone: Color, variation: StringName = &"ChipPanel") -> Control:
	var holder := panel(variation)
	var inner := label(text.to_upper(), &"MicroLabel")
	inner.add_theme_color_override("font_color", tone)
	holder.add_child(inner)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return holder


## Thin progress bar with a themed fill.
static func progress(variation: StringName, value: float, height: int = 8) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


static func key_value(key: String, value: String, value_tone: Color = Design.TEXT) -> HBoxContainer:
	var row := hbox(Design.SPACE_SM)
	row.add_child(muted(key))
	row.add_child(spacer())
	var value_label := label(value, &"NumericLabel")
	value_label.add_theme_color_override("font_color", value_tone)
	row.add_child(value_label)
	return row


## A coloured dot plus a status word — presence, ping, connection.
static func status_dot(text: String, tone: Color) -> HBoxContainer:
	var row := hbox(Design.SPACE_SM)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(9, 9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = tone
	style.set_corner_radius_all(Design.RADIUS_PILL)
	dot.add_theme_stylebox_override("panel", style)
	row.add_child(dot)
	var text_label := label(text, &"CaptionLabel")
	text_label.add_theme_color_override("font_color", tone)
	row.add_child(text_label)
	return row


# ------------------------------------------------------------------- modals

## Dim the screen and show `content` centred. Returns the dim node so the caller
## can free it (typically from a close button's pressed handler).
static func show_modal(host: Control, content: Control, width: float = 640.0) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(Design.BG.r, Design.BG.g, Design.BG.b, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)

	var scroll := scroll()
	scroll.custom_minimum_size = Vector2(width, 0)
	centre.add_child(scroll)
	scroll.add_child(content)

	host.add_child(layer)
	Audio.play_ui("whoosh", 1.15, -4.0)

	layer.modulate.a = 0.0
	var tween := host.create_tween()
	tween.tween_property(layer, "modulate:a", 1.0, 0.16)
	return layer


static func close_modal(layer: Control) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	Audio.play_ui("back", 1.0, -4.0)
	var tween := layer.create_tween()
	tween.tween_property(layer, "modulate:a", 0.0, 0.14)
	tween.tween_callback(layer.queue_free)


# -------------------------------------------------------------------- helpers

## Wire a button to a cue, a haptic tick and a callback in one line.
## Subscribe to a long-lived (usually autoload) signal exactly once.
##
## Screens and pages rebuild themselves from scratch when the language changes,
## and `build()` is where their widgets are wired up — so a plain `.connect()`
## inside `build()` connects a second time on the second pass. Godot treats a
## duplicate connection of the same callable as an error, which means switching
## to Persian would spam the console and fire every handler twice.
##
## Everything that outlives one build goes through here; per-widget signals on
## freshly created nodes can still be connected directly, because the widget
## dies with the build it belongs to.
static func listen(signal_ref: Signal, callback: Callable) -> void:
	if signal_ref.is_connected(callback):
		return
	signal_ref.connect(callback)


static func on_press(node: Button, callback: Callable, cue: String = "click") -> void:
	node.pressed.connect(func() -> void:
		Audio.play_ui(cue)
		if Controls != null:
			Controls.haptic(10)
		callback.call()
	)


## Standard hover feedback for pointer devices. No-op on touch, where mouse
## enter never fires, so it costs nothing on Android.
static func on_hover(node: Control, cue: String = "hover") -> void:
	node.mouse_entered.connect(func() -> void:
		Audio.play_ui(cue, 1.0, -8.0)
	)


static func copy_to_clipboard(text: String, label: String = "") -> void:
	DisplayServer.clipboard_set(text)
	Audio.play_ui("confirm", 1.0, -4.0)
	EventBus.toast_requested.emit(
		Loc.t(&"toast.copied_clipboard", {"label": label if not label.is_empty() else text}),
		&"success"
	)


static func accent_for_mode(mode_id: StringName) -> Color:
	return Design.mode_accent(mode_id)
