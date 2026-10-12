extends HexScreen
## The hub: top bar, nav rail, page area, and the matchmaking overlay.
##
## One screen with swap-able pages, not seven scenes. The reasons:
##   * switching must be instant — a competitive shooter's menu should never
##     spend 300 ms fading between Play and Squad;
##   * the top bar (level, currencies, presence) stays live no matter which
##     page is open, so it must not be rebuilt;
##   * the nav rail is the app's spine and looking at a different page must not
##     reset which tab is selected.
##
## Pages are `MenuPage` subclasses instantiated from the registry below. Adding
## a page is one entry plus one script.

const NAV_ENTRIES := [
	{"id": &"play", "icon": &"play", "title": &"menu.play", "section": &"menu.section.combat",
		"script": preload("res://src/ui/pages/play_page.gd")},
	{"id": &"rooms", "icon": &"rooms", "title": &"menu.rooms", "section": &"menu.section.combat",
		"script": preload("res://src/ui/pages/rooms_page.gd")},
	{"id": &"squad", "icon": &"friends", "title": &"menu.friends", "section": &"menu.section.social",
		"script": preload("res://src/ui/pages/squad_page.gd")},
	{"id": &"loadout", "icon": &"arsenal", "title": &"menu.arsenal",
		"section": &"menu.section.progression", "placeholder": true},
	{"id": &"ranked", "icon": &"rank", "title": &"menu.rank",
		"section": &"menu.section.progression", "placeholder": true},
	{"id": &"store", "icon": &"store", "title": &"menu.store",
		"section": &"menu.section.progression", "placeholder": true},
	{"id": &"profile", "icon": &"profile", "title": &"menu.profile", "section": &"menu.section.system",
		"script": preload("res://src/ui/pages/profile_page.gd")},
	{"id": &"settings", "icon": &"settings", "title": &"menu.settings", "section": &"menu.section.system",
		"script": preload("res://src/ui/pages/settings_page.gd")},
]

const NAV_RAIL_WIDTH := 232
const MOBILE_NAV_IDS: Array[StringName] = [&"play", &"rooms", &"squad", &"profile", &"settings"]

var active_page_id: StringName = &"play"

var _pages: Dictionary = {}          ## id -> MenuPage
var _nav_buttons: Dictionary = {}    ## id -> Button
var _page_host: Control
var _queue_overlay: QueueOverlay

var _name_label: Label
var _avatar: AvatarView
var _level_label: Label
var _xp_bar: ProgressBar
var _currency_credits: Control
var _currency_cores: Control
var _squad_badge: Label
var _status_row: HBoxContainer


func build() -> void:
	var root := UiKit.vbox(Design.SPACE_MD)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)

	if OS.has_feature("mobile"):
		root.add_child(_build_mobile_top_bar())
		_page_host = Control.new()
		_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_page_host.clip_contents = false
		root.add_child(_page_host)
		root.add_child(_build_mobile_nav())
	else:
		root.add_child(_build_top_bar())

		var middle := UiKit.hbox(Design.SPACE_LG)
		middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(middle)

		middle.add_child(_build_nav_rail())

		_page_host = Control.new()
		_page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_page_host.clip_contents = false
		middle.add_child(_page_host)

		root.add_child(_build_bottom_bar())

	# The overlay is a sibling of the page host, not a child of it, so `rebuild()`
	# does not free it: without this the second build stacks another overlay on
	# top of the first, and the old one keeps its matchmaking subscriptions.
	if _queue_overlay != null and is_instance_valid(_queue_overlay):
		remove_child(_queue_overlay)
		_queue_overlay.queue_free()
	_queue_overlay = QueueOverlay.new()
	add_child(_queue_overlay)

	# Idempotent: `build()` runs again whenever the language changes.
	UiKit.listen(EventBus.profile_changed, _on_profile_changed)
	UiKit.listen(EventBus.friends_changed, _on_friends_changed)
	UiKit.listen(EventBus.room_invite_received, _on_invite_received)

	_show_page(active_page_id)


func _ready() -> void:
	super._ready()
	Audio.play_music(Audio.TRACK_MENU)
	if Session.is_guest():
		EventBus.toast_requested.emit(Loc.t(&"toast.guest_banner"), &"info")


# ------------------------------------------------------------------- top bar

func _build_top_bar() -> Control:
	var bar := UiKit.panel(&"TopBarPanel")
	var row := UiKit.hbox(Design.SPACE_LG)
	bar.add_child(row)

	_avatar = AvatarView.make(Session.profile, 52.0)
	row.add_child(_avatar)

	var identity := UiKit.vbox(Design.SPACE_XXS)
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = UiKit.label(Session.display_name(), &"SubheadingLabel")
	identity.add_child(_name_label)

	var level_row := UiKit.hbox(Design.SPACE_SM)
	_level_label = UiKit.micro(Loc.t(&"common.level_short", {"level": Session.profile.level}))
	level_row.add_child(_level_label)
	_xp_bar = UiKit.progress(&"XpBar", Session.profile.xp_progress(), 6)
	_xp_bar.custom_minimum_size = Vector2(160, 6)
	level_row.add_child(_xp_bar)
	identity.add_child(level_row)
	row.add_child(identity)

	row.add_child(UiKit.spacer())

	_currency_credits = UiKit.stat_tile(Loc.t(&"store.currency.credits"),
		_format_number(Session.profile.credits), Design.GOLD)
	_currency_cores = UiKit.stat_tile(Loc.t(&"store.currency.cores"),
		_format_number(Session.profile.cores), Design.TEAL)
	row.add_child(_currency_credits)
	row.add_child(_currency_cores)

	var squad_button := UiKit.icon_button(&"friends", Design.TEXT_MUTED, 24.0)
	_squad_badge = UiKit.micro("")
	_squad_badge.add_theme_color_override("font_color", Design.ACCENT)
	squad_button.add_child(_squad_badge)
	_squad_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_squad_badge.position = Vector2(-8, 4)
	UiKit.on_press(squad_button, func() -> void: _show_page(&"squad"))
	row.add_child(squad_button)

	var settings_button := UiKit.icon_button(&"settings", Design.TEXT_MUTED, 24.0)
	UiKit.on_press(settings_button, func() -> void: _show_page(&"settings"))
	row.add_child(settings_button)

	_refresh_squad_badge()
	return bar


func _build_mobile_top_bar() -> Control:
	var bar := UiKit.panel(&"TopBarPanel")
	var content_column := UiKit.vbox(Design.SPACE_SM)
	bar.add_child(content_column)

	var identity_row := UiKit.hbox(Design.SPACE_MD)
	content_column.add_child(identity_row)
	_avatar = AvatarView.make(Session.profile, 48.0)
	identity_row.add_child(_avatar)

	var identity := UiKit.vbox(Design.SPACE_XXS)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_label = UiKit.label(Session.display_name(), &"SubheadingLabel")
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_name_label)
	_level_label = UiKit.micro(Loc.t(&"common.level_short", {"level": Session.profile.level}))
	identity.add_child(_level_label)
	identity_row.add_child(identity)

	_status_row = UiKit.hbox(Design.SPACE_MD)
	content_column.add_child(_status_row)
	_refresh_status()
	return bar


func _build_mobile_nav() -> Control:
	var panel := UiKit.panel(&"RaisedPanel")
	var row := UiKit.hbox(Design.SPACE_XS)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(row)
	_nav_buttons.clear()

	for entry: Dictionary in NAV_ENTRIES:
		if not MOBILE_NAV_IDS.has(entry["id"]):
			continue
		var button := _build_mobile_nav_button(entry)
		row.add_child(button)
		_nav_buttons[entry["id"]] = button
	return panel


func _build_mobile_nav_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"NavButton"
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE

	var column := UiKit.vbox(Design.SPACE_XXS)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(column)

	var icon := HexIcon.make(entry["icon"], Design.TEXT_MUTED, 20.0, 1.8)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)

	var text := UiKit.label(Loc.t(entry["title"]), &"CaptionLabel")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", Design.font_label)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(text)

	button.set_meta(&"icon", icon)
	button.set_meta(&"label", text)
	button.set_meta(&"id", entry["id"])
	UiKit.on_press(button, func() -> void: _show_page(entry["id"]))
	return button


func _format_number(value: int) -> String:
	# Thousands separators without locale data: group manually so a 12,500
	# credit balance is readable.
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-" if value < 0 else "") + grouped


# ------------------------------------------------------------------ nav rail

func _build_nav_rail() -> Control:
	var rail := UiKit.panel(&"RaisedPanel")
	rail.custom_minimum_size = Vector2(NAV_RAIL_WIDTH, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var rail_scroll := UiKit.scroll()
	rail.add_child(rail_scroll)
	var column := UiKit.vbox(Design.SPACE_XS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_scroll.add_child(column)

	_nav_buttons.clear()
	var last_section: StringName = &""
	for entry: Dictionary in NAV_ENTRIES:
		# Locked progression screens add clutter on a phone without being usable.
		if OS.has_feature("mobile") and bool(entry.get("placeholder", false)):
			continue
		var section: StringName = entry["section"]
		if section != last_section:
			last_section = section
			var caption := UiKit.micro(Loc.t(section).to_upper())
			caption.add_theme_color_override("font_color", Design.TEXT_DIM)
			var wrapper := MarginContainer.new()
			wrapper.add_theme_constant_override("margin_top", Design.SPACE_SM)
			wrapper.add_theme_constant_override("margin_bottom", Design.SPACE_XS)
			wrapper.add_child(caption)
			column.add_child(wrapper)

		var button := _build_nav_button(entry)
		column.add_child(button)
		_nav_buttons[entry["id"]] = button

	column.add_child(UiKit.spacer())
	column.add_child(UiKit.divider())

	var party := _build_party_block()
	column.add_child(party)

	var quit_button := UiKit.button(Loc.t(&"menu.exit"), &"GhostButton", &"exit")
	UiKit.on_press(quit_button, func() -> void: Router.quit_game(), "back")
	column.add_child(quit_button)
	return rail


func _build_nav_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"NavButton"
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE

	var row := UiKit.hbox(Design.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(row)

	var is_placeholder := bool(entry.get("placeholder", false))
	var icon := HexIcon.make(entry["icon"], Design.TEXT_MUTED, 22.0, 2.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var text := UiKit.label(Loc.t(entry["title"]), &"BodyLabel")
	text.add_theme_font_override("font", Design.font_label)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	if is_placeholder:
		var lock := HexIcon.make(&"lock", Design.TEXT_DIM, 14.0, 1.6)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)

	button.set_meta(&"icon", icon)
	button.set_meta(&"label", text)
	button.set_meta(&"id", entry["id"])
	UiKit.on_press(button, func() -> void: _show_page(entry["id"]))
	UiKit.on_hover(button)
	return button


func _build_party_block() -> Control:
	var block := UiKit.vbox(Design.SPACE_XS)
	var label := UiKit.micro("")
	label.add_theme_color_override("font_color", Design.TEXT_DIM)
	block.add_child(label)
	block.set_meta(&"party_label", label)

	var invite := UiKit.button(Loc.t(&"friends.party.invite"), &"GhostButton", &"plus")
	invite.custom_minimum_size = Vector2(0, 40)
	UiKit.on_press(invite, func() -> void: _show_page(&"squad"))
	block.add_child(invite)
	_refresh_party_block(block)
	return block


func _refresh_party_block(block: Control) -> void:
	var label := block.get_meta(&"party_label", null) as Label
	if label == null:
		return
	var size_now := Friends.party_size()
	if size_now <= 1:
		label.text = Loc.t(&"menu.party.none")
	else:
		label.text = Loc.t(&"menu.party.size", {
			"size": size_now, "max": Friends.MAX_PARTY_SIZE,
		})


# ---------------------------------------------------------------- bottom bar

func _build_bottom_bar() -> Control:
	var row := UiKit.hbox(Design.SPACE_LG)
	row.add_child(UiKit.micro(Loc.t(&"app.version_label", {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
	})))

	row.add_child(UiKit.spacer())

	_status_row = UiKit.hbox(Design.SPACE_LG)
	row.add_child(_status_row)
	_refresh_status()
	return row


func _refresh_status() -> void:
	if _status_row == null:
		return
	for child in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()

	var region := Settings.get_int("game/region")
	var region_text := Loc.t(GameTypes.region_key(region))
	_status_row.add_child(UiKit.status_dot(region_text, Design.TEAL))

	if Api.is_configured():
		var online := Api.is_online()
		_status_row.add_child(UiKit.status_dot(
			Loc.t(&"common.online") if online else Loc.t(&"common.offline"),
			Design.SUCCESS if online else Design.WARNING))
	else:
		_status_row.add_child(UiKit.status_dot(Loc.t(&"common.offline"), Design.TEXT_MUTED))

	if Rooms.is_in_room():
		_status_row.add_child(UiKit.status_dot(Rooms.room.code, Design.ACCENT))


# -------------------------------------------------------------------- pages

## Swap the visible page, reusing the instance so its scroll position and
## internal state survive.
func _show_page(page_id: StringName) -> void:
	active_page_id = page_id
	var page := _resolve_page(page_id)
	if page == null:
		return

	for child in _page_host.get_children():
		if child != page:
			child.visible = false
	if page.get_parent() != _page_host:
		var old_parent := page.get_parent()
		if old_parent != null:
			old_parent.remove_child(page)
		_page_host.add_child(page)
	page.visible = true
	page.on_shown()

	for id: StringName in _nav_buttons:
		var button: Button = _nav_buttons[id]
		var active := id == page_id
		button.theme_type_variation = &"NavButtonActive" if active else &"NavButton"
		var icon := button.get_meta(&"icon", null) as HexIcon
		if icon != null:
			icon.color = Design.ACCENT if active else Design.TEXT_MUTED
		var label := button.get_meta(&"label", null) as Label
		if label != null:
			label.add_theme_color_override("font_color", Design.TEXT if active else Design.TEXT_MUTED)

	_refresh_squad_badge()
	_refresh_status()


## Public entry point for anything inside a page that needs to move the player
## somewhere else (Play ▸ "Host a room", an invite toast, a deep link later).
## Pages must not reach into `_show_page` directly: it is the shell's job to
## decide whether a page may be swapped while a queue is running.
func open_page(page_id: StringName) -> void:
	_show_page(page_id)


## The live instance of a page, or null if it has never been opened. Used by
## one page to hand a parameter to another (Play ▸ Rooms opens Host or Browse
## depending on which button was pressed).
func page(page_id: StringName) -> MenuPage:
	return _pages.get(page_id, null) as MenuPage


func _resolve_page(page_id: StringName) -> MenuPage:
	if _pages.has(page_id):
		return _pages[page_id]
	for entry: Dictionary in NAV_ENTRIES:
		if entry["id"] != page_id:
			continue
		var page: MenuPage
		if bool(entry.get("placeholder", false)):
			page = PlaceholderPage.new()
			(page as PlaceholderPage).configure(entry["title"], entry["icon"])
		else:
			var script: GDScript = entry["script"]
			page = script.new() as MenuPage
		page.name = String(page_id)
		_pages[page_id] = page
		return page
	# Unknown page: fall back to the first real one rather than showing a blank
	# panel, which would look like a crash.
	push_warning("MainMenu: unknown page '%s'." % page_id)
	return _resolve_page(&"play")


# --------------------------------------------------------------- live updates

func _on_profile_changed(profile: PlayerProfile) -> void:
	if _name_label != null:
		_name_label.text = Session.display_name()
	if _level_label != null:
		_level_label.text = Loc.t(&"common.level_short", {"level": profile.level})
	if _xp_bar != null:
		_xp_bar.value = profile.xp_progress()
	if _avatar != null:
		_avatar.level = profile.level
	if _currency_credits != null:
		UiKit.set_stat_value(_currency_credits, _format_number(profile.credits))
	if _currency_cores != null:
		UiKit.set_stat_value(_currency_cores, _format_number(profile.cores))


func _on_friends_changed(_friends: Array) -> void:
	_refresh_squad_badge()


func _on_invite_received(invite: Dictionary) -> void:
	EventBus.toast_requested.emit(
		Loc.t(&"friends.invite.received", {"name": invite.get("from_name", "?")}), &"info")


func _refresh_squad_badge() -> void:
	if _squad_badge != null:
		var online := Friends.online_count()
		_squad_badge.text = str(online) if online > 0 else ""

	var party_block := _build_party_lookup()
	if party_block.has_meta(&"party_label"):
		_refresh_party_block(party_block)
	_refresh_status()


## The party block lives inside the rail; find it by walking the tree once
## rather than keeping another reference alive across a language rebuild.
func _build_party_lookup() -> Control:
	for node in _find_nodes_with_meta(self, &"party_label"):
		return node.get_parent()
	return Control.new()


func _find_nodes_with_meta(root: Node, meta_key: StringName) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child.has_meta(meta_key):
			found.append(child)
		found.append_array(_find_nodes_with_meta(child, meta_key))
	return found


# --------------------------------------------------------------------- input

func on_back_requested() -> void:
	if _queue_overlay != null and _queue_overlay.is_open():
		Matchmaking.cancel_queue()
		return
	if active_page_id != &"play":
		_show_page(&"play")
		return
	Router.quit_game()
