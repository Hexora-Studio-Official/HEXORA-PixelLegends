extends HexScreen
## PixelLegends Main Menu Hub ("Imperial Citadel" layout).
##
## Structured cleanly into three non-overlapping bands over the preserved full-
## bleed fantasy castle key art:
##   1. Top HUD Bar    — Profile pill, Coins/Gems balances, Signal + Battery
##                       telemetry, Downloads, Mail (with unread counter), Settings
##   2. Side Wings     — Left: Shop, Events, Stats/Rankings · Centre: open vista
##                       for the key art · Right: Squad, Social (Followers /
##                       Following) & quick Online Friends Invite strip
##   3. Bottom Dock    — Live World Chat preview box, MOBA preparation bar
##                       (Heroes, Builds, Items, Inventory, Collections), and
##                       the 5v5 Party Lobby + Game Mode Start cluster

const BACKGROUND_PATH := "res://assets/Pixel Legends_ 5v5 Fantasy Showdown.png"
const QUICK_INVITE_LIMIT := 3

var _hub_data: HubPreviewData
var _background: TextureRect
var _background_shade: ColorRect
var _atmosphere: Atmosphere

var _avatar: AvatarView
var _name_label: Label
var _sub_profile_label: Label
var _coins_btn: Button
var _gems_btn: Button
var _mail_btn: Button
var _chat_preview_btn: Button
var _lobby_btn: Button
var _play_btn: Button
var _quick_friends_box: VBoxContainer
var _active_overlay: HubOverlayShell
var _settings_layer: Control
var _settings_dialog: SettingsDialog


func _init() -> void:
	backdrop_enabled = false
	safe_padding = Design.SPACE_MD
	_hub_data = HubPreviewData.new()


func _ready() -> void:
	super._ready()
	_hub_data.changed.connect(_refresh_hud)


func build() -> void:
	_ensure_backdrop_layers()

	var root_band := UiKit.vbox(Design.SPACE_SM)
	root_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_band.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(root_band)

	root_band.add_child(_build_top_bar())
	root_band.add_child(_build_middle_stage())
	root_band.add_child(_build_bottom_bar())

	UiKit.listen(EventBus.profile_changed, _on_profile_changed)
	_refresh_hud()
	_layout_responsive_bars()
	call_deferred("_layout_responsive_bars")


func on_screen_resized() -> void:
	_layout_responsive_bars()


func _layout_responsive_bars() -> void:
	var vp := size if size.x > 1.0 else get_viewport_rect().size
	var narrow := vp.x < 1540.0
	if _chat_preview_btn != null:
		_chat_preview_btn.custom_minimum_size = Vector2(184.0 if narrow else 276.0, 58.0)
	if _lobby_btn != null:
		_lobby_btn.custom_minimum_size = Vector2(148.0 if narrow else 178.0, 60.0)
	if _play_btn != null:
		_play_btn.custom_minimum_size = Vector2(184.0 if narrow else 224.0, 64.0)


func _ensure_backdrop_layers() -> void:
	if _background == null or not is_instance_valid(_background):
		_background = TextureRect.new()
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.texture = load(BACKGROUND_PATH) as Texture2D
		_background.z_index = -2
		add_child(_background)

	if _background_shade == null or not is_instance_valid(_background_shade):
		_background_shade = ColorRect.new()
		_background_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_background_shade.color = Color(0.015, 0.032, 0.068, 0.16)
		_background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background_shade.z_index = -1
		add_child(_background_shade)

	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "Atmosphere"
		_atmosphere.z_index = -1
		add_child(_atmosphere)


# ----------------------------------------------------------------- 1. top bar

func _build_top_bar() -> HBoxContainer:
	var bar := UiKit.hbox(Design.SPACE_SM)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER

	bar.add_child(_build_profile_pill())
	bar.add_child(UiKit.spacer())

	# Currency strip (tapping opens Storefront)
	_coins_btn = UiKit.button("14,850", &"GlassButton", &"coin")
	_coins_btn.custom_minimum_size = Vector2(142, 48)
	UiKit.on_hover(_coins_btn)
	UiKit.on_press(_coins_btn, func() -> void: _open_shop(0))
	bar.add_child(_coins_btn)

	_gems_btn = UiKit.button("460", &"GlassButton", &"crystal")
	_gems_btn.custom_minimum_size = Vector2(120, 48)
	UiKit.on_hover(_gems_btn)
	UiKit.on_press(_gems_btn, func() -> void: _open_shop(0))
	bar.add_child(_gems_btn)

	# Signal strength + Ping + Real Device Battery + Local Clock
	var status_bar := StatusHudBar.new()
	status_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(status_bar)

	# Downloads, Mail, Settings
	var dl_btn := UiKit.icon_button(&"download", Design.TEAL, 22.0, Loc.t(&"hub.nav.downloads"))
	dl_btn.custom_minimum_size = Vector2(50, 48)
	UiKit.on_hover(dl_btn)
	UiKit.on_press(dl_btn, func() -> void: _open_comms(2))
	bar.add_child(dl_btn)

	_mail_btn = UiKit.button(Loc.t(&"hub.nav.mail"), &"GlassButton", &"mail")
	_mail_btn.custom_minimum_size = Vector2(118, 48)
	UiKit.on_hover(_mail_btn)
	UiKit.on_press(_mail_btn, func() -> void: _open_comms(1))
	bar.add_child(_mail_btn)

	var settings_btn := UiKit.icon_button(&"settings", Design.ACCENT_HI, 22.0, Loc.t(&"menu.settings"))
	settings_btn.custom_minimum_size = Vector2(52, 48)
	UiKit.on_hover(settings_btn)
	UiKit.on_press(settings_btn, _open_settings)
	bar.add_child(settings_btn)

	return bar


func _build_profile_pill() -> PanelContainer:
	var card := UiKit.panel(&"HudBarPanel")
	card.custom_minimum_size = Vector2(310, 66)

	var row := UiKit.hbox(Design.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(row)

	if Session.profile != null:
		_avatar = AvatarView.make(Session.profile, 48.0)
		row.add_child(_avatar)

	var text_col := UiKit.vbox(2)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label = UiKit.label(Session.display_name(), &"BodyLabel")
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_col.add_child(_name_label)

	_sub_profile_label = UiKit.micro("GOLD II · [HXR]")
	_sub_profile_label.add_theme_color_override("font_color", Design.ACCENT_HI)
	text_col.add_child(_sub_profile_label)
	row.add_child(text_col)

	var open_btn := UiKit.button(Loc.t(&"hub.nav.profile"), &"HudNavButton", &"profile")
	open_btn.custom_minimum_size = Vector2(124, 44)
	UiKit.on_hover(open_btn)
	UiKit.on_press(open_btn, _open_profile)
	row.add_child(open_btn)
	return card


# ------------------------------------------------------------ 2. middle stage

func _build_middle_stage() -> HBoxContainer:
	var stage := UiKit.hbox(Design.SPACE_MD)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_PASS

	stage.add_child(_build_left_wing())

	var open_vista := Control.new()
	open_vista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_vista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(open_vista)

	stage.add_child(_build_right_social_wing())
	return stage


func _build_left_wing() -> VBoxContainer:
	var wing := UiKit.vbox(Design.SPACE_SM)
	wing.custom_minimum_size = Vector2(182, 0)
	wing.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var entries := [
		{"key": &"hub.nav.shop", "icon": &"store", "cb": func() -> void: _open_shop(0)},
		{"key": &"hub.nav.events", "icon": &"star", "cb": func() -> void: _open_shop(1)},
		{"key": &"hub.nav.rankings", "icon": &"chart", "cb": func() -> void: _open_rankings(0)},
	]
	for raw_item in entries:
		var item: Dictionary = raw_item
		var btn := UiKit.button(Loc.t(item["key"]), &"GlassNavButton", item["icon"])
		btn.custom_minimum_size = Vector2(182, 54)
		UiKit.on_hover(btn)
		UiKit.on_press(btn, item["cb"])
		wing.add_child(btn)

	wing.add_child(UiKit.spacer())
	return wing


func _build_right_social_wing() -> VBoxContainer:
	var wing := UiKit.vbox(Design.SPACE_SM)
	wing.custom_minimum_size = Vector2(236, 0)
	wing.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var card := UiKit.panel(&"HudBarPanel")
	wing.add_child(card)
	var col := UiKit.vbox(Design.SPACE_XS)
	card.add_child(col)

	var squad_btn := UiKit.button(Loc.t(&"hub.nav.squad") + " · [HXR]", &"GlassNavButton", &"shield")
	squad_btn.custom_minimum_size = Vector2(0, 46)
	squad_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(squad_btn)
	UiKit.on_press(squad_btn, func() -> void: _open_social(3))
	col.add_child(squad_btn)

	var follow_btn := UiKit.button(Loc.t(&"hub.nav.social"), &"GlassNavButton", &"friends")
	follow_btn.custom_minimum_size = Vector2(0, 46)
	follow_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(follow_btn)
	UiKit.on_press(follow_btn, func() -> void: _open_social(1))
	col.add_child(follow_btn)

	col.add_child(UiKit.divider(Color(0.42, 0.72, 1.0, 0.24), 1))

	var hdr := UiKit.micro("ONLINE FRIENDS")
	hdr.add_theme_color_override("font_color", Design.TEAL)
	col.add_child(hdr)

	_quick_friends_box = UiKit.vbox(Design.SPACE_XXS)
	col.add_child(_quick_friends_box)

	var invite_all_btn := UiKit.button(Loc.t(&"hub.nav.invite"), &"HudLobbyButton", &"invite")
	invite_all_btn.custom_minimum_size = Vector2(0, 44)
	invite_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(invite_all_btn)
	UiKit.on_press(invite_all_btn, func() -> void: _open_social(0))
	col.add_child(invite_all_btn)

	wing.add_child(UiKit.spacer())
	return wing


# -------------------------------------------------------------- 3. bottom bar

func _build_bottom_bar() -> HBoxContainer:
	var bar := UiKit.hbox(Design.SPACE_SM)
	bar.alignment = BoxContainer.ALIGNMENT_END

	# Bottom-left: Live Chat feed preview button
	_chat_preview_btn = UiKit.button(Loc.t(&"hub.nav.chat"), &"HudNavButton", &"chat")
	_chat_preview_btn.custom_minimum_size = Vector2(290, 58)
	var chat_lbl := UiKit.label_text(_chat_preview_btn)
	if chat_lbl != null:
		chat_lbl.clip_text = true
		chat_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.on_hover(_chat_preview_btn)
	UiKit.on_press(_chat_preview_btn, func() -> void: _open_comms(0))
	bar.add_child(_chat_preview_btn)

	# Bottom-centre: Hero / Build / Item / Inventory / Collection dock
	var prep_panel := UiKit.panel(&"HudBarPanel")
	prep_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prep_row := UiKit.hbox(Design.SPACE_XS)
	prep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prep_panel.add_child(prep_row)

	var prep_items := [
		{"key": &"hub.nav.heroes", "icon": &"hero", "cb": func() -> void: _open_heroes(0)},
		{"key": &"hub.nav.builds", "icon": &"hammer", "cb": func() -> void: _open_heroes(1)},
		{"key": &"hub.nav.items", "icon": &"crystal", "cb": func() -> void: _open_heroes(2)},
		{"key": &"hub.nav.inventory", "icon": &"bag", "cb": func() -> void: _open_bag(0)},
		{"key": &"hub.nav.collections", "icon": &"book", "cb": func() -> void: _open_bag(1)},
	]
	for raw_entry in prep_items:
		var entry: Dictionary = raw_entry
		var text := Loc.t(entry["key"])
		var btn := UiKit.button(text, &"HudCompactButton", entry["icon"])
		btn.custom_minimum_size = Vector2(
			UiKit.text_width(text, Design.FONT_SMALL) + 46.0, 46.0
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner_lbl := UiKit.label_text(btn)
		if inner_lbl != null:
			inner_lbl.add_theme_font_size_override("font_size", Design.FONT_SMALL)
		UiKit.on_hover(btn)
		UiKit.on_press(btn, entry["cb"])
		prep_row.add_child(btn)
	bar.add_child(prep_panel)

	# Bottom-right: Create/Open 5v5 Lobby + Mode Selector / Play CTA
	_lobby_btn = UiKit.button("LOBBY (1/5)", &"HudLobbyButton", &"friends")
	_lobby_btn.custom_minimum_size = Vector2(178, 62)
	UiKit.on_hover(_lobby_btn)
	UiKit.on_press(_lobby_btn, func() -> void: _open_modes(true))
	bar.add_child(_lobby_btn)

	_play_btn = UiKit.button("LEAGUE · PLAY", &"HudPlayButton", &"play")
	_play_btn.custom_minimum_size = Vector2(226, 66)
	UiKit.on_hover(_play_btn)
	UiKit.on_press(_play_btn, func() -> void: _open_modes(false), "confirm")
	bar.add_child(_play_btn)

	return bar


# ----------------------------------------------------------- live HUD updates

func _refresh_hud() -> void:
	if _name_label != null:
		_name_label.text = Session.display_name()
	if _sub_profile_label != null:
		_sub_profile_label.text = "GOLD II · [%s] · %d FLW" % [
			String(_hub_data.squad_info["tag"]),
			_hub_data.followers.size(),
		]
	if _coins_btn != null:
		UiKit.set_label_text(_coins_btn, _format_thousands(_hub_data.coins))
	if _gems_btn != null:
		UiKit.set_label_text(_gems_btn, str(_hub_data.gems))
	if _mail_btn != null:
		var unread := _hub_data.unread_mail_count()
		UiKit.set_label_text(
			_mail_btn,
			"%s (%d)" % [Loc.t(&"hub.nav.mail"), unread] if unread > 0 else Loc.t(&"hub.nav.mail")
		)
	if _chat_preview_btn != null:
		UiKit.set_label_text(_chat_preview_btn, _hub_data.latest_world_message())
	if _lobby_btn != null:
		var party := 1
		for slot in _hub_data.lobby_teammates:
			if not slot.is_empty():
				party += 1
		UiKit.set_label_text(_lobby_btn, "LOBBY (%d/5)" % party)
	if _play_btn != null:
		var m := _hub_data.mode_by_id(_hub_data.selected_mode_id)
		UiKit.set_label_text(_play_btn, "%s · PLAY" % String(m["name"]))

	_rebuild_quick_friends()


func _rebuild_quick_friends() -> void:
	if _quick_friends_box == null:
		return
	for child in _quick_friends_box.get_children():
		child.queue_free()

	var shown := 0
	for friend_entry: Dictionary in _hub_data.friends:
		if not bool(friend_entry["online"]):
			continue
		if shown >= QUICK_INVITE_LIMIT:
			break
		shown += 1
		var row := UiKit.hbox(Design.SPACE_XS)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var flbl := UiKit.caption(String(friend_entry["name"]))
		flbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flbl.clip_text = true
		flbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(flbl)

		var in_party := _hub_data.is_in_lobby(String(friend_entry["id"]))
		var quick_btn := UiKit.button("✓" if in_party else "+", &"GlassButton")
		quick_btn.custom_minimum_size = Vector2(40, 34)
		quick_btn.disabled = in_party
		var target_friend := friend_entry
		UiKit.on_press(quick_btn, func() -> void:
			if _hub_data.invite_friend_to_lobby(target_friend):
				EventBus.toast_requested.emit(
					"%s invited to 5v5 Lobby!" % String(target_friend["name"]), &"success"
				)
		, "confirm")
		row.add_child(quick_btn)
		_quick_friends_box.add_child(row)


func _on_profile_changed(profile: PlayerProfile) -> void:
	if _avatar != null and profile != null:
		_avatar.initials = profile.initials()
		_avatar.level = profile.level
	_refresh_hud()


static func _format_thousands(value: int) -> String:
	var raw := str(absi(value))
	var out := ""
	var count := 0
	for idx in range(raw.length() - 1, -1, -1):
		if count == 3:
			out = "," + out
			count = 0
		out = raw.substr(idx, 1) + out
		count += 1
	return ("-" + out) if value < 0 else out


# ----------------------------------------------------------- panel launchers

func _clear_overlay() -> void:
	if _active_overlay != null and is_instance_valid(_active_overlay):
		_active_overlay.queue_free()
	_active_overlay = null
	_close_settings()


func _close_settings() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		UiKit.close_modal(_settings_layer)
	_settings_layer = null
	_settings_dialog = null


func _open_modes(start_in_lobby: bool) -> void:
	_clear_overlay()
	_active_overlay = ModesLobbyPanel.open(
		self, _hub_data, start_in_lobby, func() -> void: _open_social(0)
	)


func _open_profile() -> void:
	_clear_overlay()
	_active_overlay = ProfilePanel.open(
		self,
		_hub_data,
		func(tab: int) -> void: _open_social(tab),
		func(tab: int) -> void: _open_rankings(tab)
	)


func _open_heroes(tab: int) -> void:
	_clear_overlay()
	_active_overlay = HeroesBuildsPanel.open(self, _hub_data, tab)


func _open_bag(tab: int) -> void:
	_clear_overlay()
	_active_overlay = BagCollectionsPanel.open(self, _hub_data, tab)


func _open_shop(tab: int) -> void:
	_clear_overlay()
	_active_overlay = ShopEventsPanel.open(self, _hub_data, tab)


func _open_rankings(tab: int) -> void:
	_clear_overlay()
	_active_overlay = RankingsPanel.open(self, _hub_data, tab)


func _open_social(tab: int) -> void:
	_clear_overlay()
	_active_overlay = SocialSquadPanel.open(
		self, _hub_data, tab, func() -> void: _open_modes(true)
	)


func _open_comms(tab: int) -> void:
	_clear_overlay()
	_active_overlay = CommsSystemPanel.open(self, _hub_data, tab)


func _open_settings() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return
	_clear_overlay()
	_settings_dialog = SettingsDialog.new()
	var viewport := size
	if viewport.x <= 1.0 or viewport.y <= 1.0:
		viewport = get_viewport_rect().size
	var width := 940.0 if viewport.x <= 1.0 else minf(940.0, viewport.x - Design.SPACE_LG * 2.0)
	var height := minf(800.0, maxf(360.0, viewport.y - 96.0))
	_settings_dialog.custom_minimum_size = Vector2(width, height)
	_settings_dialog.close_requested.connect(_close_settings)
	_settings_layer = UiKit.show_modal(self, _settings_dialog, width)


func on_back_requested() -> void:
	if _settings_dialog != null and is_instance_valid(_settings_dialog):
		_settings_dialog.request_close()
		return
	if _active_overlay != null and is_instance_valid(_active_overlay):
		_active_overlay.dismiss()
		return
	Router.quit_game()
