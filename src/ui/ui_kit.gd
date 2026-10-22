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
const META_CHIP_INACTIVE := &"hex_chip_inactive"
const META_CHIP_ACTIVE := &"hex_chip_active"


# ------------------------------------------------------------------- labels

static func label(text: String, variation: StringName = &"BodyLabel") -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.layout_direction = Loc.layout_direction()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation: int = Design.SPACE_SM) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", separation)
	return box


static func grid(columns: int, separation: int = Design.SPACE_MD) -> GridContainer:
	var box := GridContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
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
	container.scroll_deadzone = 8
	container.clip_contents = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return container


## Let touch drags started on buttons/labels bubble to the nearest scroll view.
## Without this, a full-width grid can only be dragged from its tiny gaps.
static func prepare_scroll_content(root: Control) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in root.get_children():
		if child is ScrollContainer:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
			prepare_scroll_content(child as Control)


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
	node.mouse_filter = Control.MOUSE_FILTER_PASS
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
	node.mouse_filter = Control.MOUSE_FILTER_PASS
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
	# Reserve the width the words need. Without it the button collapses to
	# its icon slot in any layout that gives a child only what it asks for,
	# which is how "Reset to Defaults" came to show only "res".
	node.custom_minimum_size.x = text_width(text) + float(Design.SPACE_XL * 2) \
		+ (float(Design.SPACE_SM + 20) if icon_kind != &"" else 0.0)
	return node


## How wide `text` is in the UI face at the size `base` is drawn at.
##
## A Button is sized from its own `text` property, and the buttons made here
## keep their words in a child label instead — so on their own they report
## the width of an empty string and collapse to the icon slot, wrapping the
## label into a narrow column. Anything that needs to know how wide a button
## wants to be has to ask this.
static func text_width(text: String, base: int = Design.FONT_BODY) -> float:
	if Design.font_label == null:
		return float(text.length()) * float(base) * 0.6
	return Design.font_label.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		int(round(float(base) * Design.text_scale))).x


static func _button_text_color(variation: StringName) -> Color:
	match variation:
		&"PrimaryButton": return Design.TEXT_INVERSE
		&"HudPlayButton": return Design.TEXT_INVERSE
		&"GlassButton": return Design.TEXT
		&"GlassPrimaryButton": return Design.TEXT
		&"HudNavButton": return Design.TEXT
		&"HudCompactButton": return Design.TEXT
		&"HudLobbyButton": return Design.TEAL
		&"GlassNavButton": return Design.TEXT
		&"DangerButton": return Design.DANGER
		&"DangerPillButton": return Design.DANGER
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


static func chip(
		text: String, active: bool = false, icon_kind: StringName = &"", compact: bool = false
) -> Button:
	var inactive_variation: StringName = &"RegionChipButton" if compact else &"ChipButton"
	var active_variation: StringName = \
		&"RegionChipButtonActive" if compact else &"ChipButtonActive"
	var variation: StringName = active_variation if active else inactive_variation
	var node: Button
	if icon_kind == &"":
		# Plain text buttons are more reliable than nested labels in tight grids:
		# the button owns the text width, wrapping and clipping itself.
		node = Button.new()
		node.theme_type_variation = variation
		node.text = text
		node.alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		node.clip_text = true
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		node = button(text, variation, icon_kind)
	node.set_meta(META_CHIP_INACTIVE, inactive_variation)
	node.set_meta(META_CHIP_ACTIVE, active_variation)
	# Compact chips sit in tight grids that give them their width, so they are
	# left alone; the rest are sized to their words for the same reason the
	# buttons above are.
	node.custom_minimum_size = Vector2(
		0.0 if compact else text_width(text, Design.FONT_SMALL) + float(Design.SPACE_XL * 2), 56)
	return node


static func set_chip_active(node: Button, active: bool) -> void:
	var inactive_variation := StringName(
		node.get_meta(META_CHIP_INACTIVE, &"ChipButton"))
	var active_variation := StringName(
		node.get_meta(META_CHIP_ACTIVE, &"ChipButtonActive"))
	node.theme_type_variation = active_variation if active else inactive_variation
	var inner := label_text(node)
	if inner != null:
		inner.add_theme_color_override("font_color",
			Design.ACCENT_HI if active else Design.TEXT_MUTED)
	else:
		node.add_theme_color_override("font_color", Design.ACCENT_HI if active else Design.TEXT_MUTED)
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
	style.anti_aliasing = false
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
	dim.color = Color(Design.BG.r, Design.BG.g, Design.BG.b, 0.52)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)

	var scroll := scroll()
	centre.add_child(scroll)
	scroll.add_child(content)
	host.add_child(layer)

	# A ScrollContainer is only as tall as it is told to be, and a
	# CenterContainer hands a child exactly its minimum size. Left at zero,
	# the panel kept a healthy rectangle and was still clipped to nothing:
	# it opened, built all its rows, and drew nothing at all, which is
	# indistinguishable from a button that does not work. Give the scroll the
	# height the content asked for, and no more than the screen has.
	# The panel has to fit the screen it is opened on, which is the host's own
	# rectangle rather than the window's. On a phone those are the same, but
	# measuring the window is what let a panel sized for a tall window sit
	# inside a shorter screen with its footer hanging past the bottom.
	var host_size := host.size
	if host_size.y <= 1.0:
		host_size = host.get_viewport_rect().size
	var room := maxf(host_size.y - Design.SPACE_XL * 2.0, 240.0)
	var wanted := content.get_combined_minimum_size().y
	scroll.custom_minimum_size = Vector2(width, minf(maxf(wanted, 240.0), room))

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
## Screens and pages rebuild themselves when their text changes, and `build()`
## is where their widgets are wired up — so a plain `.connect()` inside `build()`
## could connect a second time on a rebuild. Godot treats duplicate connections
## as errors, so long-lived signals use this idempotent helper.
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


