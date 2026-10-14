extends Control
##
## Does the Settings button on the entrance actually open the panel?
##
## This repository cannot run GDScript locally, so a claim like "the Settings
## button works" is otherwise unfalsifiable — it gets asserted, shipped and
## believed. This is where it is checked instead: it builds the real entrance
## scene, finds the real button, presses it, and reports what came up.
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
	var problems: PackedStringArray = []

	print("CHECK viewport=%s" % get_viewport_rect().size)

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
	# _ready() runs synchronously inside add_child, so the screen has already
	# built itself by the next line and every widget it owns exists.
	add_child(screen)

	_dump_children(screen)

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

	# A sibling added later is hit-tested first. If one of them covers the
	# button, the player's tap never reaches it however correct the wiring.
	var covering := _covering_sibling(button)
	if covering != "":
		problems.append("the button is covered by a later sibling: " + covering)

	var before := _count_descendants(screen)
	button.pressed.emit()
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
		if dialog.get_child_count() == 0:
			problems.append("the panel opened but built nothing inside")
		print("CHECK panel nodes=%d area=%s" % [_count_descendants(dialog), area.size])

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
## visible in the log instead of being inferred from a failure.
func _dump_children(screen: Node) -> void:
	print("CHECK tree ----")
	for child in screen.get_children():
		var control := child as Control
		if control == null:
			print("CHECK   %s [%s]" % [child.name, child.get_class()])
			continue
		print("CHECK   %s [%s] visible=%s %s"
			% [control.name, control.get_class(), control.visible, control.get_global_rect()])
		for grandchild in child.get_children():
			var inner := grandchild as Control
			if inner == null:
				continue
			print("CHECK     %s [%s] visible=%s %s"
				% [inner.name, inner.get_class(), inner.visible, inner.get_global_rect()])
	print("CHECK tree ----")


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
