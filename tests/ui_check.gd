extends Control
##
## Does the Settings button on the entrance actually open the panel?
##
## This repository cannot run GDScript locally, so a claim like "the Settings
## button works" is otherwise unfalsifiable — it gets asserted, shipped and
## believed. This is where it is checked instead: it builds the real entrance
## scene, finds the real button, presses it, and reports what came up.
##
## Two traps shaped this file, both of which produced confident nonsense
## before they were understood:
##
##   - _ready() runs BEFORE the first layout pass. Measuring there reports
##     every widget as its minimum size, which is why the first version of
##     this check saw a 40x40 screen and an "overlap" that meant nothing.
##     The entrance defers its own re-measure for exactly the same reason.
##   - Headless ignores --resolution, so the window stays at its square
##     default. A phone is not square and the entrance positions its dock
##     from the viewport height, so the size is set here instead.
##
## Run by CI on every push, as a scene rather than a --script, because a
## --script run does not register the project's autoloads as identifiers and
## every screen in this project is compiled against them:
##
##     godot --headless --path . res://tests/ui_check.tscn
##
## Quits non-zero if anything about that path is broken.

const SCREEN_PATH := "res://src/ui/screens/boot_screen.tscn"
const BUTTON_NAME := "EntranceSettingsButton"


func _ready() -> void:
	# The root control of a headless main scene is given no size at all, so
	# stretching to the parent measures 0x0 and the whole tree collapses onto
	# its minimums — every rectangle below would be fiction. Anchor to nothing
	# and set the size by hand.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_window().size = Vector2i(1920, 1080)
	size = Vector2(1920, 1080)

	var packed := load(SCREEN_PATH) as PackedScene
	if packed == null:
		print("CHECK result=FAIL cannot load " + SCREEN_PATH)
		get_tree().quit(1)
		return
	var screen := packed.instantiate() as Control
	if screen == null:
		print("CHECK result=FAIL " + SCREEN_PATH + " is not a Control")
		get_tree().quit(1)
		return
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Wait for layout. Nothing measured before this point means anything.
	await get_tree().process_frame
	await get_tree().process_frame

	print("CHECK viewport=%s host=%s screen=%s"
		% [get_viewport_rect().size, get_global_rect().size, screen.get_global_rect().size])
	_dump_children(screen)

	var problems: PackedStringArray = []

	var button := screen.find_child(BUTTON_NAME, true, false) as Button
	if button == null:
		print("CHECK result=FAIL the entrance has no child named " + BUTTON_NAME)
		get_tree().quit(1)
		return

	if not button.is_inside_tree():
		problems.append("the button is not in the scene tree")
	if not button.visible:
		problems.append("the button is not visible")
	if button.disabled:
		problems.append("the button is disabled")
	var rect := button.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		problems.append("the button has no area: %s" % rect)
	if not get_viewport_rect().encloses(rect):
		problems.append("the button sits outside the screen: %s" % rect)

	# A sibling added later is hit-tested first. If one of them covers the
	# button, the player's tap never reaches it however correct the wiring.
	var covering := _covering_sibling(button)
	if covering != "":
		problems.append("the button is covered by a later sibling: " + covering)

	var before := _count_descendants(screen)
	button.pressed.emit()
	await get_tree().process_frame
	var dialog := _find_dialog(screen)

	if dialog == null:
		problems.append("pressing it opened no panel (nodes %d -> %d)"
			% [before, _count_descendants(screen)])
	else:
		if not dialog.visible:
			problems.append("the panel is not visible")
		var area := dialog.get_global_rect()
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			problems.append("the panel has no area: %s" % area)
		if not get_viewport_rect().encloses(area):
			problems.append("the panel does not fit on the screen: %s" % area)
		if dialog.get_child_count() == 0:
			problems.append("the panel opened but built nothing inside")
		# The panel's own rectangle can look perfect while a clipping ancestor
		# leaves the player looking at nothing, so measure what survives.
		var shown_area := _visible_area(dialog)
		if shown_area.size.x <= 0.0 or shown_area.size.y <= 0.0:
			problems.append("the panel is clipped away and draws nothing: %s" % shown_area)
		elif shown_area.size.y < area.size.y - 1.0 or shown_area.size.x < area.size.x - 1.0:
			problems.append("the panel is partly clipped: %s of %s" % [shown_area.size, area.size])
		print("CHECK panel nodes=%d area=%s visible_area=%s"
			% [_count_descendants(dialog), area.size, shown_area.size])
		var inner := _find_scroll(dialog)
		if inner != null:
			await _report_categories(dialog, inner)

	print("CHECK button area=%s visible=%s disabled=%s covered_by='%s'"
		% [rect.size, button.visible, button.disabled, covering])

	if not problems.is_empty():
		for problem in problems:
			print("CHECK result=FAIL " + problem)
		get_tree().quit(1)
		return
	print("CHECK result=PASS the entrance Settings button opens the panel")
	get_tree().quit(0)


## Print the entrance's widget tree with rectangles, so a layout mistake is
## visible in the log instead of being inferred from a failure. The entrance
## nests its dock three levels down, which is why this walks the tree.
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
## intersected with every ancestor that clips. A panel can have a perfect
## rectangle and still be clipped to nothing by a zero-height scroll.
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


## Walk every category and report the height its rows need against the height
## the panel can show. "Pointless scrolling" is a number, not an opinion, and
## this is what stops it returning: padding added anywhere shows up here as
## overflow that did not exist before.
func _report_categories(dialog: Control, inner: ScrollContainer) -> void:
	var rail := _find_rail(dialog)
	if rail == null:
		print("CHECK categories could not find the strip")
		return
	var room := inner.get_global_rect().size.y
	var total_overflow := 0.0
	var worst: Button = null
	var worst_need := -1.0
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
		# times what it occupies once it has been given a width — the first
		# version of this report was inflated by exactly that.
		var needed := rows.size.y
		var overflow := maxf(0.0, needed - room)
		if needed > worst_need:
			worst_need = needed
			worst = tab
		total_overflow += overflow
		print("CHECK category %-22s rows=%4.0f  room=%4.0f  scroll=%4.0f"
			% [tab.text, needed, room, overflow])
	print("CHECK categories total_scroll=%.0f" % total_overflow)
	# The totals say a row is too tall; only the tree says which one.
	if worst != null:
		worst.pressed.emit()
		await get_tree().process_frame
		print("CHECK tallest %s needs %.0f" % [worst.text, worst_need])
		_dump(_rows_of(inner), 0)


## The scrolling list inside the panel, as opposed to the one wrapping it.
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


## The name of any sibling added after `button` whose rectangle covers it.
func _covering_sibling(button: Button) -> String:
	var parent := button.get_parent()
	var area := button.get_global_rect()
	for child in parent.get_children():
		if not (child is Control) or child.get_index() <= button.get_index():
			continue
		var other := (child as Control).get_global_rect()
		if other.intersects(area):
			return child.name
	return ""


func _count_descendants(from: Node) -> int:
	var total := 0
	for child in from.get_children():
		total += 1 + _count_descendants(child)
	return total


func _find_dialog(from: Node) -> Control:
	if from is SettingsDialog:
		return from as Control
	for child in from.get_children():
		var found := _find_dialog(child)
		if found != null:
			return found
	return null
