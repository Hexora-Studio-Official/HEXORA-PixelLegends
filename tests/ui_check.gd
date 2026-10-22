extends Control
##
## Does the Settings panel actually fit on the screen it is opened on?
##
## This repository cannot run GDScript locally, so claims like "the Settings
## button works" and "the panel fits" are otherwise unfalsifiable — they get
## asserted, shipped and believed. This is where they are checked: it builds
## the real entrance scene, presses the real button, and measures what came
## up.
##
## It runs at several viewport sizes, and that is the point of it. The first
## version measured one size — the one where everything happened to fit —
## and reported success while the player's phone cut the footer off. A panel
## that fits at 1080 tall and not at 720 does not fit.
##
## Traps already fallen into, recorded so they are not repeated:
##
##   - _ready() runs BEFORE the first layout pass. Measuring there reports
##     every widget at its minimum size.
##   - Headless ignores --resolution, so the window keeps its default; the
##     size has to be set here.
##   - The root control of a headless main scene is sized 0x0, so anchoring
##     it to its parent measures nothing.
##
## Run by CI on every push, as a scene rather than a --script, because a
## --script run does not register the project's autoloads as identifiers and
## every screen here is compiled against them:
##
##     godot --headless --path . res://tests/ui_check.tscn
##
## Quits non-zero if anything about that path is broken.

const SCREEN_PATH := "res://src/ui/screens/boot_screen.tscn"
const MENU_SCREEN_PATH := "res://src/ui/screens/main_menu_screen.tscn"
const BUTTON_NAME := "EntranceSettingsButton"

## The sizes a landscape phone actually reports. The short ones are why this
## loops: a panel that only fits on a tall screen does not fit.
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2340, 1080),
	Vector2i(1600, 720),
	Vector2i(1280, 600),
]

## Buttons that must be reachable on every screen, because they are the ones
## a player reaches for last — and the ones a short screen hides first.
const FOOTER_BUTTONS: Array[String] = ["ResetToDefaults", "CancelChanges", "ApplyChanges"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	var problems: PackedStringArray = []
	for index in VIEWPORTS.size():
		problems.append_array(await _check_at(VIEWPORTS[index], index == 0))
		problems.append_array(await _check_main_menu_at(VIEWPORTS[index]))
	if not problems.is_empty():
		for problem in problems:
			print("CHECK result=FAIL " + problem)
		get_tree().quit(1)
		return
	print("CHECK result=PASS the panel fits and its footer is reachable at every size")
	get_tree().quit(0)


func _check_at(size: Vector2i, report: bool) -> PackedStringArray:
	var problems: PackedStringArray = []
	# The window cannot be made short here — headless clamps its height and
	# scales the width to match, so four "sizes" all came back 1080 tall. The
	# screen is resized instead, and since the panel now takes its size from
	# its host, that is the real relationship being measured.
	self.size = Vector2(size)
	await get_tree().process_frame
	await get_tree().process_frame

	var packed := load(SCREEN_PATH) as PackedScene
	if packed == null:
		problems.append("cannot load " + SCREEN_PATH)
		return problems
	var screen := packed.instantiate() as Control
	if screen == null:
		problems.append(SCREEN_PATH + " is not a Control")
		return problems
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport := screen.size
	print("CHECK at %s" % viewport)
	if absf(viewport.y - float(size.y)) > 1.0:
		problems.append("the screen refused the size it was given: %s not %s" % [viewport, size])

	if report:
		_dump_children(screen)

	var button := screen.find_child(BUTTON_NAME, true, false) as Button
	if button == null:
		problems.append("the entrance has no child named " + BUTTON_NAME)
		return problems
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var dialog := _find_dialog(screen)
	if dialog == null:
		problems.append("at %s pressing it opened no panel" % viewport)
		screen.queue_free()
		await get_tree().process_frame
		return problems

	var area := dialog.get_global_rect()
	var shown := _visible_area(dialog)
	var tag := "at %s" % viewport

	if shown.size.x <= 0.0 or shown.size.y <= 0.0:
		problems.append("%s the panel is clipped away and draws nothing" % tag)
	if not _encloses(viewport, area):
		problems.append("%s the panel falls outside the screen: %s" % [tag, area])
	elif not _encloses(viewport, shown):
		problems.append("%s part of the panel is cut off: %s of %s"
			% [tag, shown.size, area.size])

	# The complaint that started this: the footer buttons were the part the
	# screen ate. Every one of them has to be wholly on screen and inside the
	# panel, at every size.
	for name in FOOTER_BUTTONS:
		var footer := dialog.find_child(name, true, false) as Control
		if footer == null:
			problems.append("%s the panel has no %s button" % [tag, name])
			continue
		var box := footer.get_global_rect()
		print("CHECK   %-18s %s" % [name, box])
		if not _encloses(viewport, box):
			problems.append("%s the %s button is off the screen: %s" % [tag, name, box])
		elif not area.encloses(box):
			problems.append("%s the %s button hangs out of the panel: %s" % [tag, name, box])

	print("CHECK   panel %s area=%s visible=%s" % [tag, area.size, shown.size])

	if report:
		var inner := _find_scroll(dialog)
		if inner != null:
			await _report_categories(dialog, inner)
	# Measured at every size: a strip that wraps on a narrow screen is
	# exactly the thing that was reported.
	var strip := _find_rail(dialog)
	if strip != null:
		print("CHECK tabs %s height=%.0f width=%.0f"
			% [tag, strip.size.y, strip.size.x])
		# Wrapped means a tab sits on a different line than the first. The
		# container's own height is not a reliable signal — it measured 78
		# for one row, which is neither one row nor two.
		var first_y := -1.0
		for tab in strip.get_children():
			if not (tab is Button):
				continue
			var label := (tab as Button).text
			var box := (tab as Button).get_global_rect()
			if report:
				print("CHECK   tab %-22s w=%4.0f h=%4.0f y=%5.0f"
					% [label, box.size.x, box.size.y, box.position.y])
			if first_y < 0.0:
				first_y = box.position.y
			elif absf(box.position.y - first_y) > 4.0:
				problems.append("%s tab '%s' wrapped onto a second row" % [tag, label])
			# Wrapped text cannot be told from a simply tall button by
			# height alone. The reliable test is whether the tab is wide
			# enough for the words it carries.
			var wanted := UiKit.text_width(label, Design.FONT_SMALL)
			if box.size.x < wanted - 1.0:
				problems.append("%s tab '%s' is too narrow for its text: %.0f < %.0f"
					% [tag, label, box.size.x, wanted])

	screen.queue_free()
	await get_tree().process_frame
	return problems


## True when `box` sits wholly inside a rectangle of `outer` size.
func _encloses(outer: Vector2, box: Rect2) -> bool:
	return box.position.x >= -0.5 and box.position.y >= -0.5 \
		and box.end.x <= outer.x + 0.5 and box.end.y <= outer.y + 0.5


## Walk every category and report the height its rows need against the height
## the panel can show. "Pointless scrolling" is a number, not an opinion, and
## this is what stops it returning.
func _report_categories(dialog: Control, inner: ScrollContainer) -> void:
	var rail := _find_rail(dialog)
	if rail == null:
		print("CHECK categories could not find the strip")
		return
	var room := inner.get_global_rect().size.y
	var total_overflow := 0.0
	for chip in rail.get_children():
		if not (chip is Button):
			continue
		var tab := chip as Button
		tab.pressed.emit()
		await get_tree().process_frame
		var rows := _rows_of(inner)
		if rows == null:
			continue
		# Laid-out height, not the combined minimum. A wrapping label reports
		# the height it would need at its narrowest, which can be several
		# times what it occupies once it has been given a width.
		var needed := rows.size.y
		var overflow := maxf(0.0, needed - room)
		total_overflow += overflow
		print("CHECK category %-22s rows=%4.0f  room=%4.0f  scroll=%4.0f"
			% [tab.text, needed, room, overflow])
	print("CHECK categories total_scroll=%.0f" % total_overflow)


## Print the entrance's widget tree, so a layout mistake is visible in the
## log instead of being inferred from a failure.
func _dump_children(screen: Node) -> void:
	print("CHECK tree ----")
	_dump(screen, 0)
	print("CHECK tree ----")


func _dump(from: Node, depth: int) -> void:
	if depth > 4:
		return
	for child in from.get_children():
		var control := child as Control
		var pad := "  ".repeat(depth)
		if control == null:
			print("CHECK %s%s [%s]" % [pad, child.name, child.get_class()])
		else:
			print("CHECK %s%s [%s] visible=%s %s"
				% [pad, control.name, control.get_class(), control.visible, control.get_global_rect()])
		_dump(child, depth + 1)


## How much of a control the player can actually see: its own rectangle
## intersected with every ancestor that clips.
func _visible_area(control: Control) -> Rect2:
	var area := control.get_global_rect()
	var node := control.get_parent()
	while node != null:
		if node is Control:
			var ancestor := node as Control
			if ancestor.clip_contents:
				area = area.intersection(ancestor.get_global_rect())
		node = node.get_parent()
	return area


func _find_scroll(from: Node) -> ScrollContainer:
	for child in from.get_children():
		if child is ScrollContainer:
			return child as ScrollContainer
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


func _find_rail(from: Node) -> HFlowContainer:
	for child in from.get_children():
		if child is HFlowContainer:
			return child as HFlowContainer
		var found := _find_rail(child)
		if found != null:
			return found
	return null


func _rows_of(inner: ScrollContainer) -> Control:
	for child in inner.get_children():
		if child is Control:
			return child
	return null


func _find_dialog(from: Node) -> Control:
	if from is SettingsDialog:
		return from as Control
	for child in from.get_children():
		var found := _find_dialog(child)
		if found != null:
			return found
	return null


func _check_main_menu_at(size: Vector2i) -> PackedStringArray:
	var problems: PackedStringArray = []
	self.size = Vector2(size)
	await get_tree().process_frame
	await get_tree().process_frame

	var packed := load(MENU_SCREEN_PATH) as PackedScene
	if packed == null:
		problems.append("cannot load " + MENU_SCREEN_PATH)
		return problems
	var menu := packed.instantiate() as Control
	if menu == null:
		problems.append(MENU_SCREEN_PATH + " is not a Control")
		return problems
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport := menu.size
	for child in menu.find_children("*", "Button", true, false):
		var btn := child as Button
		if btn == null or not btn.is_visible_in_tree():
			continue
		var box := btn.get_global_rect()
		if not _encloses(viewport, box):
			problems.append("menu button '%s' overflows %s: %s" % [btn.name, viewport, box])

	menu.queue_free()
	await get_tree().process_frame
	return problems
