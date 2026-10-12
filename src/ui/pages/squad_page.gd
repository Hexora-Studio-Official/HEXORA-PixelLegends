class_name SquadPage
extends MenuPage
## Squad: friends, requests, and the party you queue with.
##
## Everything here is honest about its scope. Friend rows that come from the
## sample seeder are labelled "SAMPLE" rather than looking like real accounts,
## and the page states plainly that cross-device lists need the phase-2 backend.

enum Tab { FRIENDS, REQUESTS, ADD }

var tab: int = Tab.FRIENDS


func build() -> void:
	body.add_child(header(&"friends.title", &"friends.subtitle", _build_tabs()))
	body.add_child(_build_party_card())
	body.add_child(UiKit.divider())

	match tab:
		Tab.FRIENDS: _build_friends()
		Tab.REQUESTS: _build_requests()
		Tab.ADD: _build_add()


func _build_tabs() -> Control:
	var row := UiKit.hbox(Design.SPACE_SM)
	var keys: Array[StringName] = [&"friends.tab.friends", &"friends.tab.requests", &"friends.tab.search"]
	for index in 3:
		var label := Loc.t(keys[index])
		if index == Tab.REQUESTS and not Friends.requests.is_empty():
			label += " (%d)" % Friends.requests.size()
		var chip := UiKit.chip(label, index == tab)
		var captured := index
		UiKit.on_press(chip, func() -> void:
			tab = captured
			rebuild()
		)
		row.add_child(chip)
	return row


# ------------------------------------------------------------------ party

func _build_party_card() -> Control:
	var column := card(&"friends.party")
	Friends.ensure_party()

	if Friends.party_size() <= 1:
		column.add_child(UiKit.paragraph(Loc.t(&"friends.party.empty"), 720.0, &"CaptionLabel"))
	else:
		var row := UiKit.hbox(Design.SPACE_SM)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		for member: Dictionary in Friends.party:
			row.add_child(_build_party_chip(member))
		column.add_child(row)

	var actions := UiKit.hbox(Design.SPACE_SM)
	if Rooms.is_in_room() and not Friends.party.is_empty():
		var invite_all := UiKit.button(Loc.t(&"friends.invite.room"), &"TealButton", &"share")
		UiKit.on_press(invite_all, func() -> void:
			UiKit.copy_to_clipboard(Rooms.invite_text(), Loc.t(&"common.invite"))
		)
		actions.add_child(invite_all)
	if Friends.party_size() > 1:
		var leave := UiKit.button(Loc.t(&"friends.party.leave"), &"GhostButton")
		UiKit.on_press(leave, func() -> void:
			Friends.leave_party()
			rebuild()
		, "back")
		actions.add_child(leave)
	if actions.get_child_count() > 0:
		column.add_child(actions)
	return column


func _build_party_chip(member: Dictionary) -> Control:
	var pill := UiKit.panel(&"InsetPanel")
	var row := UiKit.hbox(Design.SPACE_SM)
	pill.add_child(row)

	var name_label := UiKit.label(String(member.get("name", "?")), &"BodyLabel")
	row.add_child(name_label)
	if bool(member.get("is_leader", false)):
		row.add_child(UiKit.pill(Loc.t(&"friends.party.leader"), Design.ACCENT))
	if bool(member.get("is_local", false)):
		row.add_child(UiKit.pill(Loc.t(&"common.you"), Design.TEAL, &"TealChipPanel"))
	return pill


# ---------------------------------------------------------------- friends

func _build_friends() -> Control:
	var column := card(&"friends.tab.friends")

	if Friends.friends.is_empty():
		column.add_child(UiKit.paragraph(Loc.t(&"friends.empty"), 720.0))
		column.add_child(UiKit.paragraph(Loc.t(&"friends.empty_hint"), 720.0, &"CaptionLabel"))
		return column

	if not Api.is_configured():
		column.add_child(UiKit.paragraph(Loc.t(&"friends.note"), 720.0, &"CaptionLabel"))

	var online := Friends.friends.duplicate()
	online.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order := {"online": 0, "in_lobby": 1, "in_match": 2, "offline": 3}
		return int(order.get(String(a.get("status", "offline")), 3)) \
			< int(order.get(String(b.get("status", "offline")), 3))
	)
	for friend: Dictionary in online:
		column.add_child(_build_friend_row(friend))
	return column


func _build_friend_row(friend: Dictionary) -> Control:
	var row := UiKit.panel(&"InsetPanel")
	var inner := UiKit.hbox(Design.SPACE_MD)
	row.add_child(inner)

	var avatar := AvatarView.new()
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.size = Vector2(44, 44)
	avatar.palette_index = absi(String(friend.get("uid", "x")).hash())
	avatar.initials = String(friend.get("name", "??")).substr(0, 2).to_upper()
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(avatar)

	var text_block := UiKit.vbox(Design.SPACE_XXS)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UiKit.hbox(Design.SPACE_SM)
	name_row.add_child(UiKit.label(String(friend.get("name", "?")), &"BodyLabel"))
	if bool(friend.get("sample", false)):
		name_row.add_child(UiKit.pill(Loc.t(&"common.phase_two"), Design.WARNING))
	text_block.add_child(name_row)

	var status := String(friend.get("status", "offline"))
	var status_key := &"friends.status.%s" % status
	var tone := Design.TEXT_DIM
	match status:
		"online": tone = Design.SUCCESS
		"in_lobby": tone = Design.ACCENT
		"in_match": tone = Design.DANGER
	text_block.add_child(UiKit.status_dot(Loc.t(status_key), tone))
	inner.add_child(text_block)

	inner.add_child(UiKit.micro(Loc.t(&"common.level_short",
		{"level": int(friend.get("level", 1))})))

	var party_button := UiKit.button(Loc.t(&"friends.party.invite"), &"GhostButton", &"plus")
	party_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(party_button, func() -> void:
		var outcome := Friends.invite_to_party(String(friend.get("uid", "")))
		if bool(outcome.get("ok", false)):
			EventBus.toast_requested.emit(Loc.t(&"friends.invite.sent"), &"success")
		else:
			Audio.play_ui("error")
			EventBus.toast_requested.emit(Loc.t(&"friends.status.offline"), &"warning")
		rebuild()
	)
	party_button.disabled = status == "offline"
	inner.add_child(party_button)

	if Rooms.is_host():
		var room_button := UiKit.icon_button(&"share", Design.TEAL, 18.0)
		UiKit.on_press(room_button, func() -> void:
			Friends.invite_to_room(String(friend.get("uid", "")))
		)
		inner.add_child(room_button)

	var remove := UiKit.icon_button(&"close", Design.TEXT_DIM, 16.0)
	UiKit.on_press(remove, func() -> void:
		Friends.remove_friend(String(friend.get("uid", "")))
		rebuild()
	, "back")
	inner.add_child(remove)
	return row


# --------------------------------------------------------------- requests

func _build_requests() -> Control:
	var column := card(&"friends.tab.requests")

	if Friends.requests.is_empty():
		column.add_child(UiKit.paragraph(Loc.t(&"friends.requests.empty"), 720.0))
		return column

	for request: Dictionary in Friends.requests:
		column.add_child(_build_request_row(request))
	return column


func _build_request_row(request: Dictionary) -> Control:
	var row := UiKit.panel(&"InsetPanel")
	var inner := UiKit.hbox(Design.SPACE_MD)
	row.add_child(inner)

	var text_block := UiKit.vbox(Design.SPACE_XXS)
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UiKit.hbox(Design.SPACE_SM)
	name_row.add_child(UiKit.label(String(request.get("name", "?")), &"BodyLabel"))
	if bool(request.get("sample", false)):
		name_row.add_child(UiKit.pill(Loc.t(&"common.phase_two"), Design.WARNING))
	text_block.add_child(name_row)

	var incoming := String(request.get("direction", "incoming")) == "incoming"
	text_block.add_child(UiKit.caption(
		Loc.t(&"common.level_short", {"level": int(request.get("level", 1))})))
	inner.add_child(text_block)

	if incoming:
		var accept := UiKit.button(Loc.t(&"friends.request.accept"), &"SecondaryButton")
		accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiKit.on_press(accept, func() -> void:
			Friends.accept_request(String(request.get("uid", "")))
			rebuild()
		, "confirm")
		inner.add_child(accept)

	var decline := UiKit.button(Loc.t(&"friends.request.decline"), &"GhostButton")
	decline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.on_press(decline, func() -> void:
		Friends.decline_request(String(request.get("uid", "")))
		rebuild()
	, "back")
	inner.add_child(decline)
	return row


# -------------------------------------------------------------------- add

func _build_add() -> Control:
	var column := card(&"friends.add")
	column.add_child(UiKit.paragraph(Loc.t(&"friends.note"), 720.0, &"CaptionLabel"))

	var row := UiKit.hbox(Design.SPACE_MD)
	var field := LineEdit.new()
	field.theme_type_variation = &"HexLineEdit"
	field.placeholder_text = Loc.t(&"friends.add.placeholder")
	field.custom_minimum_size = Vector2(280, Design.TOUCH_TARGET_MIN)
	field.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_child(field)

	var send := UiKit.button(Loc.t(&"friends.add"), &"PrimaryButton", &"plus")
	send.custom_minimum_size = Vector2(160, Design.TOUCH_TARGET_MIN)
	var submit := func() -> void:
		var handle := field.text.strip_edges()
		if handle.length() < 3:
			EventBus.toast_requested.emit(Loc.t(&"common.required"), &"warning")
			Audio.play_ui("error")
			return
		var outcome := await Friends.send_request(handle)
		if bool(outcome.get("ok", false)):
			field.text = ""
			tab = Tab.REQUESTS
		else:
			Audio.play_ui("error")
		if is_inside_tree():
			rebuild()
	UiKit.on_press(send, submit)
	field.text_submitted.connect(func(_text: String) -> void: submit.call())
	row.add_child(send)
	column.add_child(row)
	return column


func on_shown() -> void:
	Friends.refresh_presence()


func _ready() -> void:
	super._ready()
	EventBus.friends_changed.connect(_on_changed)
	EventBus.friend_requests_changed.connect(_on_changed)
	EventBus.party_changed.connect(_on_party_changed)


func _on_changed(_data: Array) -> void:
	if is_visible_in_tree():
		rebuild()


func _on_party_changed(_party: Array) -> void:
	if is_visible_in_tree():
		rebuild()
