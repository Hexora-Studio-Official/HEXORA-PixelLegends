class_name RoomsPage
extends MenuPage
## Custom lobbies: host one, join one, browse what is out there.
##
## The hotspot path is the interesting one and it is real end to end: creating
## a room opens an ENet server on this device, starts broadcasting a UDP beacon,
## and shows the address a friend can type. Joining fills the roster with actual
## connected players. Nothing on this page needs an account or a router.
##
## The online path talks to the backend and, with no backend configured, says so
## instead of listing invented rooms. A browser with nothing in it is a truthful
## browser.

enum Tab { HOST, JOIN, BROWSE }

const MAX_LOCAL := RoomService.MAX_LAN_PLAYERS

var tab: int = Tab.HOST

# Half-typed form state, kept across rebuilds: a language change must never
# wipe a room name the player just typed on a phone keyboard.
var _room_name: String = ""
var _host_mode: StringName = &"tdm"
var _host_max: int = 6
var _host_visibility: int = GameTypes.RoomVisibility.PRIVATE
var _host_password: String = ""
var _join_code: String = ""
var _join_password: String = ""
var _manual_address: String = ""
var _manual_port: String = ""
## Codes seen at the last rebuild of the browser, so beacons do not rebuild the
## page (and fight the player's thumb) unless the set actually changed.
var _last_room_codes: String = ""


func build() -> void:
	body.add_child(header(&"rooms.title", &"rooms.subtitle", _build_tabs()))
	if Rooms.is_in_room():
		_build_lobby()
		return
	match tab:
		Tab.HOST: _build_host_tab()
		Tab.JOIN: _build_join_tab()
		_: _build_browse_tab()


func _build_tabs() -> Control:
	var row := UiKit.hbox(Design.SPACE_SM)
	var keys: Array[StringName] = [&"rooms.tab.host", &"rooms.tab.join", &"rooms.tab.browse"]
	for index in keys.size():
		var chip := UiKit.chip(Loc.t(keys[index]), index == tab)
		UiKit.on_press(chip, _on_tab_pressed.bind(index))
		row.add_child(chip)
	return row


func _on_tab_pressed(index: int) -> void:
	tab = index
	rebuild()


# ------------------------------------------------------------------ host tab

func _build_host_tab() -> void:
	var column := card(&"rooms.create")

	column.add_child(UiKit.label(Loc.t(&"rooms.name"), &"SectionLabel"))
	var name_field := LineEdit.new()
	name_field.theme_type_variation = &"HexLineEdit"
	name_field.text = _room_name
	name_field.placeholder_text = Loc.t(&"rooms.name_hint")
	name_field.max_length = 28
	# The room name is the one field that follows the UI language, because it is
	# the player's own words; everything else here is an identifier.
	name_field.layout_direction = Loc.layout_direction()
	name_field.text_changed.connect(func(text: String) -> void: _room_name = text)
	column.add_child(name_field)

	column.add_child(UiKit.label(Loc.t(&"rooms.mode"), &"SectionLabel"))
	var mode_grid := UiKit.grid(3, Design.SPACE_SM)
	var chips: Array[Button] = []
	for mode in GameCatalog.hotspot_pool():
		var chip := UiKit.chip(Loc.t(mode.short_key), mode.id == _host_mode, mode.icon_kind)
		UiKit.on_press(chip, _select_host_mode.bind(mode.id, chips))
		chips.append(chip)
		mode_grid.add_child(chip)
	column.add_child(mode_grid)

	var mode := GameCatalog.resolve(_host_mode)
	column.add_child(UiKit.paragraph(
		"%s — %s" % [Loc.t(mode.title_key), Loc.t(mode.rules_key)], 720.0, &"CaptionLabel"))

	var capacity := mini(mode.lobby_capacity(), MAX_LOCAL)
	_host_max = clampi(_host_max, 2, maxi(2, capacity))
	var slider_row := UiKit.hbox(Design.SPACE_MD)
	slider_row.add_child(UiKit.label(Loc.t(&"rooms.max_players"), &"BodyLabel"))
	var value := UiKit.label(str(_host_max), &"NumericLabel")
	value.custom_minimum_size = Vector2(40, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider_row.add_child(UiKit.spacer())
	slider_row.add_child(value)

	var slider := HSlider.new()
	slider.theme_type_variation = &"HexSlider"
	slider.min_value = 2
	slider.max_value = maxi(2, capacity)
	slider.step = 1
	slider.value = _host_max
	slider.custom_minimum_size = Vector2(220, Design.TOUCH_TARGET_MIN)
	slider.value_changed.connect(func(amount: float) -> void:
		_host_max = int(amount)
		value.text = str(_host_max)
	)
	slider_row.add_child(slider)
	column.add_child(slider_row)
	column.add_child(UiKit.paragraph(
		Loc.t(&"rooms.hotspot.max_note", {"count": MAX_LOCAL}), 720.0, &"CaptionLabel"))

	column.add_child(UiKit.label(Loc.t(&"rooms.visibility"), &"SectionLabel"))
	var visibility := UiKit.grid(3, Design.SPACE_SM)
	var visibility_chips: Array[Button] = []
	var values := [
		GameTypes.RoomVisibility.PRIVATE,
		GameTypes.RoomVisibility.FRIENDS,
		GameTypes.RoomVisibility.PUBLIC,
	]
	var visibility_keys: Array[StringName] = [
		&"rooms.visibility.private", &"rooms.visibility.friends", &"rooms.visibility.public",
	]
	for index in values.size():
		var chip := UiKit.chip(Loc.t(visibility_keys[index]), values[index] == _host_visibility)
		UiKit.on_press(chip, _select_visibility.bind(index, visibility_chips, values))
		visibility_chips.append(chip)
		visibility.add_child(chip)
	column.add_child(visibility)

	var password_row := UiKit.hbox(Design.SPACE_MD)
	password_row.add_child(UiKit.label(Loc.t(&"rooms.password"), &"BodyLabel"))
	password_row.add_child(UiKit.spacer())
	var password := LineEdit.new()
	password.theme_type_variation = &"HexLineEdit"
	password.secret = true
	password.text = _host_password
	password.placeholder_text = Loc.t(&"rooms.password_hint")
	password.custom_minimum_size = Vector2(260, Design.TOUCH_TARGET_MIN)
	password.layout_direction = Control.LAYOUT_DIRECTION_LTR
	password.text_changed.connect(func(text: String) -> void: _host_password = text)
	password_row.add_child(password)
	column.add_child(password_row)

	var create := UiKit.button(Loc.t(&"rooms.create"), &"PrimaryButton", &"plus")
	create.custom_minimum_size = Vector2(0, 56)
	UiKit.on_press(create, _create_room, "confirm")
	column.add_child(create)

	_build_hotspot_guide()


## The four steps players actually get wrong, in the order they get them wrong.
func _build_hotspot_guide() -> void:
	var column := card(&"rooms.hotspot.title")
	column.add_child(UiKit.paragraph(Loc.t(&"rooms.hotspot.desc"), 720.0, &"CaptionLabel"))
	for key in [&"rooms.hotspot.step1", &"rooms.hotspot.step2",
			&"rooms.hotspot.step3", &"rooms.hotspot.step4"]:
		var row := UiKit.hbox(Design.SPACE_SM)
		var chevron := HexIcon.make(&"chevron", Design.TEAL, 14.0, 1.8)
		chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chevron)
		var text := UiKit.caption(Loc.t(key))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		column.add_child(row)
	column.add_child(UiKit.paragraph(Loc.t(&"rooms.hotspot.guide"), 720.0, &"CaptionLabel"))


# ------------------------------------------------------------------ join tab

func _build_join_tab() -> void:
	var column := card(&"rooms.join_by_code")
	column.add_child(UiKit.paragraph(Loc.t(&"rooms.code_hint"), 720.0))

	var row := UiKit.hbox(Design.SPACE_MD)
	var code := LineEdit.new()
	code.theme_type_variation = &"HexLineEdit"
	code.text = _join_code
	code.placeholder_text = "K7QP2M"
	code.max_length = RoomInfo.CODE_LENGTH
	code.custom_minimum_size = Vector2(220, Design.TOUCH_TARGET_MIN)
	code.layout_direction = Control.LAYOUT_DIRECTION_LTR
	# Codes are read aloud and typed with one thumb: normalise as they type, so
	# "k7qp-2m" becomes a code instead of an error message.
	code.text_changed.connect(func(text: String) -> void:
		var normalised := RoomInfo.normalise_code(text)
		if normalised != text:
			code.text = normalised
			code.caret_column = normalised.length()
		_join_code = normalised
	)
	code.text_submitted.connect(func(_text: String) -> void: _join_by_code())
	row.add_child(code)

	var join := UiKit.button(Loc.t(&"rooms.join"), &"PrimaryButton", &"play")
	join.custom_minimum_size = Vector2(160, Design.TOUCH_TARGET_MIN)
	UiKit.on_press(join, _join_by_code, "confirm")
	row.add_child(join)
	column.add_child(row)

	var password := LineEdit.new()
	password.theme_type_variation = &"HexLineEdit"
	password.secret = true
	password.placeholder_text = Loc.t(&"rooms.password")
	password.custom_minimum_size = Vector2(0, Design.TOUCH_TARGET_MIN)
	password.layout_direction = Control.LAYOUT_DIRECTION_LTR
	password.text_changed.connect(func(text: String) -> void: _join_password = text)
	column.add_child(password)

	_build_manual_join()


## Typing an address is the escape hatch for hotspots that drop UDP broadcast
## and therefore never show up in the browser. It is four lines of UI, it works
## on every network, and it is what the host's own screen shows.
func _build_manual_join() -> void:
	var column := card(&"rooms.hotspot.join_manual")
	column.add_child(UiKit.paragraph(Loc.t(&"rooms.hotspot.join_manual.hint"), 720.0,
		&"CaptionLabel"))

	var row := UiKit.hbox(Design.SPACE_MD)
	var address := LineEdit.new()
	address.theme_type_variation = &"HexLineEdit"
	address.text = _manual_address
	address.placeholder_text = Loc.t(&"rooms.hotspot.manual_hint")
	address.custom_minimum_size = Vector2(240, Design.TOUCH_TARGET_MIN)
	address.layout_direction = Control.LAYOUT_DIRECTION_LTR
	address.text_changed.connect(func(text: String) -> void: _manual_address = text)
	row.add_child(address)

	var port := LineEdit.new()
	port.theme_type_variation = &"HexLineEdit"
	port.text = _manual_port if not _manual_port.is_empty() else str(RoomService.LAN_PORT_MIN)
	port.custom_minimum_size = Vector2(110, Design.TOUCH_TARGET_MIN)
	port.layout_direction = Control.LAYOUT_DIRECTION_LTR
	port.text_changed.connect(func(text: String) -> void: _manual_port = text)
	row.add_child(port)

	var connect := UiKit.button(Loc.t(&"common.join"), &"OutlineButton", &"wifi")
	UiKit.on_press(connect, func() -> void: _join_manual(address.text, port.text))
	row.add_child(connect)
	column.add_child(row)


# ---------------------------------------------------------------- browse tab

func _build_browse_tab() -> void:
	var scanning := Rooms.is_scanning()
	var column := card(&"rooms.hotspot.title")

	var controls := UiKit.hbox(Design.SPACE_MD)
	var discover := UiKit.button(
		Loc.t(&"rooms.hotspot.discovering") if scanning else Loc.t(&"rooms.hotspot.discover"),
		&"TealButton" if scanning else &"OutlineButton", &"wifi")
	UiKit.on_press(discover, func() -> void:
		if Rooms.is_scanning():
			Rooms.stop_scanning()
		else:
			Rooms.start_scanning()
		rebuild()
	)
	controls.add_child(discover)

	var refresh := UiKit.icon_button(&"refresh", Design.TEXT_MUTED, 20.0,
		Loc.t(&"rooms.hotspot.refresh"))
	UiKit.on_press(refresh, func() -> void: rebuild(), "back")
	controls.add_child(refresh)
	column.add_child(controls)

	var port := Rooms.listen_port()
	if port > 0:
		column.add_child(UiKit.micro(
			Loc.t(&"rooms.hotspot.listen_port", {"port": str(port)})))

	var local := Rooms.lan_rooms()
	if local.is_empty():
		column.add_child(UiKit.paragraph(
			Loc.t(&"rooms.hotspot.scanning") if scanning else Loc.t(&"rooms.hotspot.empty"),
			720.0, &"CaptionLabel"))
	else:
		column.add_child(UiKit.micro(
			Loc.t(&"rooms.hotspot.found", {"count": local.size()})))
		var grid := UiKit.grid(2, Design.SPACE_MD)
		for entry in local:
			grid.add_child(_build_lan_card(entry))
		column.add_child(grid)

	_build_online_section()


func _build_lan_card(entry: RoomInfo) -> Control:
	var panel := UiKit.panel(&"RaisedPanel")
	var column := UiKit.vbox(Design.SPACE_SM)
	panel.add_child(column)

	var mode := GameCatalog.resolve(entry.mode_id)
	var title_row := UiKit.hbox(Design.SPACE_SM)
	var icon := HexIcon.make(mode.icon_kind, mode.accent, 20.0, 1.8)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(icon)
	var title := UiKit.label(entry.name, &"BodyLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	column.add_child(title_row)

	var meta := UiKit.hbox(Design.SPACE_XS)
	meta.add_child(UiKit.pill(Loc.t(mode.short_key), mode.accent))
	meta.add_child(UiKit.pill(entry.occupancy_label(), Design.TEXT_MUTED))
	meta.add_child(UiKit.pill(Loc.t(&"rooms.hotspot.lan_badge"), Design.TEAL, &"TealChipPanel"))
	if entry.password_protected:
		meta.add_child(UiKit.pill(Loc.t(&"rooms.password"), Design.WARNING))
	column.add_child(meta)

	var footer := UiKit.hbox(Design.SPACE_SM)
	footer.add_child(UiKit.caption("%s: %s" % [Loc.t(&"rooms.host"), entry.host_name]))
	footer.add_child(UiKit.spacer())
	footer.add_child(UiKit.micro(entry.address))
	column.add_child(footer)

	var join := UiKit.button(Loc.t(&"common.join"), &"SecondaryButton")
	UiKit.on_press(join, func() -> void: _join_discovered(entry), "confirm")
	column.add_child(join)
	return panel


func _join_discovered(entry: RoomInfo) -> void:
	if entry.password_protected and _join_password.is_empty():
		# Send them to Join, with the code pre-filled, instead of failing with
		# "wrong password" for a password they never had a field for.
		tab = Tab.JOIN
		_join_code = entry.code
		rebuild()
		EventBus.toast_requested.emit(Loc.t(&"rooms.password"), &"info")
		return
	Rooms.join_lan(entry, _join_password)


func _build_online_section() -> void:
	var column := card(&"rooms.tab.browse")
	if not Api.is_configured():
		column.add_child(UiKit.paragraph(Loc.t(&"rooms.online_offline"), 720.0, &"WarningLabel"))
		column.add_child(UiKit.paragraph(Loc.t(&"rooms.online_offline.hint"), 720.0,
			&"CaptionLabel"))
		return
	column.add_child(UiKit.caption(Loc.t(&"common.loading")))
	_request_online(column)


func _request_online(column: VBoxContainer) -> void:
	var result: Dictionary = await Api.list_rooms({"region": Settings.get_int("game/region")})
	if not is_inside_tree():
		return
	for child in column.get_children():
		if child is Label:
			child.queue_free()
	if not bool(result["ok"]):
		column.add_child(UiKit.paragraph(Loc.t(&"rooms.empty"), 720.0))
		return
	var data: Dictionary = result["data"]
	var entries: Array = data.get("rooms", [])
	if entries.is_empty():
		column.add_child(UiKit.paragraph(Loc.t(&"rooms.empty"), 720.0))
		return
	var grid := UiKit.grid(2, Design.SPACE_MD)
	for entry in entries:
		if entry is Dictionary:
			grid.add_child(_build_lan_card(RoomInfo.from_dict(entry)))
	column.add_child(grid)


# --------------------------------------------------------------------- lobby

func _build_lobby() -> void:
	var room := Rooms.room
	var mode := GameCatalog.resolve(room.mode_id)

	var code_card := card(&"rooms.code")
	var banner := UiKit.panel(&"BannerPanel")
	var banner_row := UiKit.hbox(Design.SPACE_LG)
	banner.add_child(banner_row)

	var block := UiKit.vbox(Design.SPACE_XXS)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var code := UiKit.display(room.code)
	code.add_theme_color_override("font_color", Design.ACCENT_HI)
	block.add_child(code)
	block.add_child(UiKit.micro(Loc.t(&"rooms.code_hint")))
	banner_row.add_child(block)

	var copy := UiKit.button(Loc.t(&"common.copy"), &"OutlineButton", &"copy")
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(copy, func() -> void:
		UiKit.copy_to_clipboard(room.code, Loc.t(&"rooms.code"))
	, "confirm")
	banner_row.add_child(copy)

	var invite := UiKit.button(Loc.t(&"common.invite"), &"PrimaryButton", &"share")
	invite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(invite, func() -> void:
		UiKit.copy_to_clipboard(Rooms.invite_text(), Loc.t(&"common.invite"))
	, "confirm")
	banner_row.add_child(invite)
	code_card.add_child(banner)

	var meta := UiKit.grid(2, Design.SPACE_SM)
	meta.add_child(UiKit.key_value(Loc.t(&"common.mode"), Loc.t(mode.title_key)))
	meta.add_child(UiKit.key_value(Loc.t(&"common.players"), room.occupancy_label()))
	meta.add_child(UiKit.key_value(Loc.t(&"rooms.host"), room.host_name))
	if room.is_lan and not Rooms.local_addresses().is_empty():
		meta.add_child(UiKit.key_value(Loc.t(&"rooms.hotspot.host_ip"),
			"%s:%d" % [Rooms.local_addresses()[0], room.port], Design.TEAL))
	code_card.add_child(meta)

	var roster_card := card(&"common.players")
	for player in Rooms.roster():
		roster_card.add_child(_build_player_row(player))

	var actions := UiKit.hbox(Design.SPACE_MD)
	if Rooms.is_host():
		var start := UiKit.button(Loc.t(&"rooms.start_match"), &"PrimaryButton", &"play")
		start.custom_minimum_size = Vector2(0, 56)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.on_press(start, func() -> void:
			var outcome := Rooms.start_match()
			if not bool(outcome["ok"]):
				Audio.play_ui("error")
				EventBus.toast_requested.emit(Loc.t(&"rooms.need_players", {
					"count": int(outcome.get("need", 2)),
				}), &"warning")
		, "confirm")
		actions.add_child(start)
		var close := UiKit.button(Loc.t(&"common.close"), &"DangerButton", &"close")
		close.custom_minimum_size = Vector2(0, 56)
		UiKit.on_press(close, func() -> void:
			Rooms.close_room()
			rebuild()
		)
		actions.add_child(close)
	else:
		var leave := UiKit.button(Loc.t(&"common.leave"), &"DangerButton", &"exit")
		leave.custom_minimum_size = Vector2(0, 56)
		UiKit.on_press(leave, func() -> void:
			Rooms.leave_room()
			rebuild()
		)
		actions.add_child(leave)
	body.add_child(actions)


func _build_player_row(player: Dictionary) -> Control:
	var panel := UiKit.panel(&"InsetPanel")
	var row := UiKit.hbox(Design.SPACE_MD)
	panel.add_child(row)

	var avatar := AvatarView.make(Session.profile, 40.0)
	avatar.show_level = false
	avatar.palette_index = int(player.get("avatar_color", 0))
	avatar.initials = String(player.get("name", "??")).substr(0, 2)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	var block := UiKit.vbox(Design.SPACE_XXS)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UiKit.hbox(Design.SPACE_SM)
	name_row.add_child(UiKit.label(String(player.get("name", "?")), &"BodyLabel"))
	if bool(player.get("is_host", false)):
		name_row.add_child(UiKit.pill(Loc.t(&"rooms.host"), Design.ACCENT, &"AccentChipPanel"))
	if bool(player.get("is_local", false)):
		name_row.add_child(UiKit.pill(Loc.t(&"common.you"), Design.TEAL, &"TealChipPanel"))
	block.add_child(name_row)
	block.add_child(UiKit.micro(Loc.t(&"common.level_short", {
		"level": int(player.get("level", 1)),
	})))
	row.add_child(block)

	var ping := int(player.get("ping_ms", 0))
	row.add_child(UiKit.status_dot(Loc.t(&"common.ping_ms", {"ms": ping}),
		GameTypes.ping_color(GameTypes.ping_quality(ping))))
	row.add_child(UiKit.status_dot(
		Loc.t(&"rooms.ready") if bool(player.get("ready", false)) else Loc.t(&"rooms.not_ready"),
		Design.SUCCESS if bool(player.get("ready", false)) else Design.TEXT_DIM))

	if Rooms.is_host() and not bool(player.get("is_local", false)):
		var kick := UiKit.icon_button(&"close", Design.TEXT_MUTED, 14.0, Loc.t(&"rooms.kick"))
		UiKit.on_press(kick, func() -> void:
			Rooms.kick_peer(int(player.get("peer_id", 0)))
		)
		row.add_child(kick)
	return panel


# ------------------------------------------------------------------- actions

func _select_host_mode(mode_id: StringName, chips: Array[Button]) -> void:
	_host_mode = mode_id
	var pool := GameCatalog.hotspot_pool()
	for index in chips.size():
		UiKit.set_chip_active(chips[index], pool[index].id == mode_id)
	_host_max = mini(_host_max, mini(GameCatalog.resolve(mode_id).lobby_capacity(), MAX_LOCAL))
	Audio.play_ui("toggle_on")
	rebuild()


func _select_visibility(index: int, chips: Array[Button], values: Array) -> void:
	_host_visibility = values[index]
	for other in chips.size():
		UiKit.set_chip_active(chips[other], other == index)
	Audio.play_ui("toggle_on")


func _create_room() -> void:
	var created := Rooms.host_room({
		"name": _room_name,
		"mode_id": _host_mode,
		"max_players": _host_max,
		"visibility": _host_visibility,
		"password": _host_password,
		"ranked": false,
		"local_only": true,
	})
	if created == null:
		Audio.play_ui("error")
		return
	tab = Tab.HOST
	rebuild()


func _join_by_code() -> void:
	var code := RoomInfo.normalise_code(_join_code)
	if not RoomInfo.is_valid_code(code):
		Audio.play_ui("error")
		EventBus.toast_requested.emit(Loc.t(&"rooms.code_invalid"), &"error")
		return
	Rooms.join_by_code(code, _join_password)


func _join_manual(address_text: String, port_text: String) -> void:
	var address := address_text.strip_edges()
	var port := int(port_text.strip_edges())
	if port <= 0 or port > 65535:
		port = RoomService.LAN_PORT_MIN
	if not _is_ipv4(address):
		Audio.play_ui("error")
		EventBus.toast_requested.emit(Loc.t(&"rooms.hotspot.bad_addr"), &"error")
		return
	Rooms.join_address(address, port, _join_password)


func _is_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var value := int(part)
		if value < 0 or value > 255:
			return false
	return true


# ------------------------------------------------------------------- signals

func _ready() -> void:
	super._ready()
	EventBus.room_updated.connect(_on_room_changed)
	EventBus.room_closed.connect(_on_room_closed)
	EventBus.room_list_changed.connect(_on_room_list_changed)


func _on_room_changed(_room: RoomInfo) -> void:
	if is_visible_in_tree():
		rebuild()


func _on_room_closed(_reason: String) -> void:
	if is_visible_in_tree():
		rebuild()


## The browser has to follow discovery, but rebuilding the page on every beacon
## would fight the player's thumb: only the Browse tab refreshes, and only when
## the *set* of rooms changed rather than each count.
func _on_room_list_changed(entries: Array) -> void:
	if not is_visible_in_tree() or tab != Tab.BROWSE:
		return
	var codes := PackedStringArray()
	for entry in entries:
		if entry is RoomInfo:
			codes.append((entry as RoomInfo).code)
	var codes_signature := "|".join(codes)
	if codes_signature != _last_room_codes:
		_last_room_codes = codes_signature
		rebuild()


func on_shown() -> void:
	# Room state changes while the player is on another page.
	rebuild()
