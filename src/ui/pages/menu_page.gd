class_name MenuPage
extends Control
## Base class for the panels inside the main menu.
##
## The menu is one screen with swap-able pages rather than separate scenes:
## switching tabs must be instant, must keep the top bar and nav rail alive,
## and must not re-trigger a fade. Pages are plain Controls that the shell
## mounts into its content area.
##
## A page owns its content, rebuilds itself when the language changes, and
## refreshes on `on_shown()` (because the top bar and the services can change
## state while a different page is visible).

var scroll: ScrollContainer
var body: VBoxContainer

var _built: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	layout_direction = Loc.layout_direction()
	_build_frame()
	build()
	_built = true
	EventBus.language_changed.connect(_on_language_changed)


func _build_frame() -> void:
	scroll = UiKit.scroll(true)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_bottom", Design.SPACE_XXL)
	margin.add_theme_constant_override("margin_top", Design.SPACE_XS)
	scroll.add_child(margin)

	body = UiKit.vbox(Design.SPACE_LG)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)


## Override: fill `body`.
func build() -> void:
	pass


## Override when the page can cheaply update instead of rebuilding.
func retranslate() -> void:
	rebuild()


## Called every time the shell shows this page.
func on_shown() -> void:
	pass


func rebuild() -> void:
	if not _built:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	layout_direction = Loc.layout_direction()
	build()


func _on_language_changed(_locale: String) -> void:
	retranslate()


# ------------------------------------------------------------ page helpers

## Standard page header: title, optional subtitle, optional trailing controls.
func header(title_key: StringName, subtitle_key: StringName = &"",
		trailing: Control = null) -> VBoxContainer:
	var column := UiKit.vbox(Design.SPACE_XS)
	var titles := UiKit.vbox(Design.SPACE_XXS)
	var title := UiKit.heading(Loc.t(title_key))
	titles.add_child(title)
	if subtitle_key != &"":
		titles.add_child(UiKit.muted(Loc.t(subtitle_key)))

	if OS.has_feature("mobile"):
		# Keep page titles and trailing controls on separate rows so long Persian
		# headings never compete for the same narrow horizontal space.
		column.add_child(titles)
		if trailing != null:
			column.add_child(trailing)
		return column

	var row := UiKit.hbox(Design.SPACE_MD)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(titles)
	row.add_child(UiKit.spacer())
	if trailing != null:
		row.add_child(trailing)
	column.add_child(row)
	return column


## A card with a title and a column inside, ready for rows.
func card(title_key: StringName = &"") -> VBoxContainer:
	var holder := UiKit.panel(&"CardPanel")
	var column := UiKit.vbox(Design.SPACE_MD)
	holder.add_child(column)
	body.add_child(holder)
	if title_key != &"":
		var row := UiKit.hbox(Design.SPACE_MD)
		row.add_child(UiKit.micro(Loc.t(title_key).to_upper()))
		var line := UiKit.divider()
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(line)
		column.add_child(row)
	return column


## Card plus a short explanatory line under the title.
func card_with_hint(title_key: StringName, hint_key: StringName) -> VBoxContainer:
	var column := card(title_key)
	column.add_child(UiKit.paragraph(Loc.t(hint_key), 720.0))
	return column
