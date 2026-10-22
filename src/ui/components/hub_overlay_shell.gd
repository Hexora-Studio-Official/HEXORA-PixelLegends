class_name HubOverlayShell
extends Control
## Shared full-screen translucent overlay window for every main-menu section.
##
## Keeps every feature window consistent: dark backdrop blur/dim, gold-cyan
## header with icon + title + optional tab bar + close button, and a full-area
## body container that adapts cleanly to phone and desktop resolutions.

signal closed

var body: VBoxContainer

var _tabs_row: HFlowContainer
var _tab_buttons: Array[Button] = []
var _active_tab: int = 0
var _on_tab_selected: Callable
var _tween: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


static func open(
	host: Control,
	title_text: String,
	icon_kind: StringName = &"crown",
	subtitle_text: String = "",
	preview_tag: bool = true
) -> HubOverlayShell:
	var shell := HubOverlayShell.new()
	shell._build_chrome(title_text, icon_kind, subtitle_text, preview_tag)
	host.add_child(shell)
	Audio.play_ui("whoosh", 1.12, -4.0)
	shell.modulate.a = 0.0
	shell._tween = shell.create_tween()
	shell._tween.tween_property(shell, "modulate:a", 1.0, 0.16)
	return shell


func set_tabs(labels: Array[String], initial_index: int, callback: Callable) -> void:
	_on_tab_selected = callback
	_active_tab = clampi(initial_index, 0, maxi(0, labels.size() - 1))
	_tabs_row.visible = not labels.is_empty()
	for child in _tabs_row.get_children():
		child.queue_free()
	_tab_buttons.clear()
	for idx in labels.size():
		var btn := UiKit.chip(labels[idx], idx == _active_tab)
		btn.custom_minimum_size.y = 44.0
		var target := idx
		UiKit.on_press(btn, func() -> void: select_tab(target))
		_tabs_row.add_child(btn)
		_tab_buttons.append(btn)


func select_tab(index: int) -> void:
	if index < 0 or index >= _tab_buttons.size():
		return
	_active_tab = index
	for idx in _tab_buttons.size():
		UiKit.set_chip_active(_tab_buttons[idx], idx == _active_tab)
	if _on_tab_selected.is_valid():
		_on_tab_selected.call(_active_tab)


func clear_body() -> void:
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func dismiss() -> void:
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	Audio.play_ui("back", 1.0, -4.0)
	closed.emit()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.13)
	_tween.tween_callback(queue_free)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _build_chrome(
	title_text: String, icon_kind: StringName, subtitle_text: String, preview_tag: bool
) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.028, 0.058, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", Design.SPACE_LG)
	margin.add_theme_constant_override("margin_right", Design.SPACE_LG)
	margin.add_theme_constant_override("margin_top", Design.SPACE_MD)
	margin.add_theme_constant_override("margin_bottom", Design.SPACE_MD)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var window := UiKit.panel(&"HudWindowPanel")
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(window)

	var root_col := UiKit.vbox(Design.SPACE_SM)
	root_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.add_child(root_col)

	var header := UiKit.hbox(Design.SPACE_MD)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root_col.add_child(header)

	var badge_icon := HexIcon.make(icon_kind, Design.ACCENT_HI, 28.0, 2.2, Design.TEAL)
	badge_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(badge_icon)

	var title_box := UiKit.vbox(2)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := UiKit.subheading(title_text)
	heading.add_theme_color_override("font_color", Design.TEXT)
	title_box.add_child(heading)
	if not subtitle_text.is_empty():
		var sub := UiKit.caption(subtitle_text)
		sub.add_theme_color_override("font_color", Design.TEXT_DIM)
		title_box.add_child(sub)
	header.add_child(title_box)

	if preview_tag:
		var badge := UiKit.pill(Loc.t(&"hub.server_preview"), Design.TEAL, &"TealChipPanel")
		header.add_child(badge)

	var back_btn := UiKit.button(Loc.t(&"common.close"), &"GlassButton", &"close")
	back_btn.custom_minimum_size = Vector2(126, 46)
	UiKit.on_hover(back_btn)
	UiKit.on_press(back_btn, dismiss, "back")
	header.add_child(back_btn)

	_tabs_row = HFlowContainer.new()
	_tabs_row.add_theme_constant_override("h_separation", Design.SPACE_XS)
	_tabs_row.add_theme_constant_override("v_separation", Design.SPACE_XS)
	_tabs_row.visible = false
	root_col.add_child(_tabs_row)

	root_col.add_child(UiKit.divider(Color(0.42, 0.72, 1.0, 0.28), 1))

	var scroller := UiKit.scroll(true)
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_col.add_child(scroller)

	body = UiKit.vbox(Design.SPACE_MD)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroller.add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		dismiss()
