class_name ProfilePage
extends MenuPage
## Career page: who you are, what you have done, and how to leave.
##
## Numbers come straight from `Session.profile`. When the backend lands this
## page does not change: the service merges remote stats into the same object.

func build() -> void:
	var profile := Session.profile
	body.add_child(header(&"profile.title", &"profile.subtitle", _build_rank_badge()))

	body.add_child(_build_identity_card(profile))
	body.add_child(_build_progression_card(profile))
	body.add_child(_build_career_card(profile))
	body.add_child(_build_account_card(profile))


func _build_rank_badge() -> Control:
	var profile := Session.profile
	var row := UiKit.hbox(Design.SPACE_SM)
	row.add_child(UiKit.pill(Loc.t(profile.rank_tier_key()), Design.ACCENT, &"AccentChipPanel"))
	row.add_child(UiKit.pill(Loc.t(&"rank.points") + " " + str(profile.rank_points), Design.TEAL,
		&"TealChipPanel"))
	return row


func _build_identity_card(profile: PlayerProfile) -> Control:
	var card_node := UiKit.panel(&"CardPanel")
	var row := UiKit.hbox(Design.SPACE_LG)
	card_node.add_child(row)

	var avatar := AvatarView.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.size = Vector2(96, 96)
	avatar.palette_index = absi(profile.uid.hash()) % AvatarView.PALETTE.size()
	avatar.initials = profile.initials()
	avatar.show_level = true
	avatar.level = profile.level
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	var column := UiKit.vbox(Design.SPACE_XXS)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(UiKit.heading(Session.display_name()))

	var badges := UiKit.hbox(Design.SPACE_SM)
	if profile.is_guest:
		badges.add_child(UiKit.pill(Loc.t(&"auth.guest.badge"), Design.WARNING))
	else:
		badges.add_child(UiKit.pill(Loc.t(&"common.online"), Design.SUCCESS, &"TealChipPanel"))
	if not profile.clan_tag.is_empty():
		badges.add_child(UiKit.pill(profile.clan_tag, Design.TEAL))
	column.add_child(badges)

	column.add_child(UiKit.caption(profile.email if not profile.email.is_empty()
		else Loc.t(&"auth.guest.upgrade")))
	column.add_child(UiKit.micro("%s: %s" % [Loc.t(&"profile.uid"), profile.uid]))
	row.add_child(column)
	return card_node


func _build_progression_card(profile: PlayerProfile) -> Control:
	var column := card(&"menu.section.progression")

	var level_row := UiKit.hbox(Design.SPACE_MD)
	level_row.add_child(UiKit.label(Loc.t(&"common.level_short", {"level": profile.level}),
		&"ValueLabel"))
	level_row.add_child(UiKit.spacer())
	level_row.add_child(UiKit.caption("%d / %d" % [profile.xp, profile.xp_to_next_level()]))
	column.add_child(level_row)
	column.add_child(UiKit.progress(&"XpBar", profile.xp_progress(), 10))

	var bounds := profile.rank_tier_bounds()
	var rank_row := UiKit.hbox(Design.SPACE_MD)
	rank_row.add_child(UiKit.label(Loc.t(profile.rank_tier_key()), &"ValueLabel"))
	rank_row.add_child(UiKit.spacer())
	rank_row.add_child(UiKit.caption(Loc.t(&"rank.tier_progress", {
		"current": profile.rank_points, "next": bounds.y,
	})))
	column.add_child(rank_row)
	column.add_child(UiKit.progress(&"RankBar", profile.rank_tier_progress(), 10))
	return column


func _build_career_card(profile: PlayerProfile) -> Control:
	var column := card(&"profile.career")

	var grid := UiKit.grid(4, Design.SPACE_SM)
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.matches"), str(profile.matches_played)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.wins"), str(profile.matches_won),
		Design.SUCCESS))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.kills"), str(profile.kills)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.deaths"), str(profile.deaths)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.kd"), "%.2f" % profile.kill_death_ratio()))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.win_rate"),
		"%d%%" % int(round(profile.win_rate() * 100.0))))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.headshots"), str(profile.headshots)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.damage"), _short_number(profile.damage_dealt)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.streak"), str(profile.current_win_streak),
		Design.ACCENT))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.best_streak"),
		str(profile.longest_win_streak), Design.GOLD))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.playtime"), _format_duration(profile.playtime_seconds)))
	grid.add_child(UiKit.stat_tile(Loc.t(&"profile.created"), _format_date(profile.created_at)))
	column.add_child(grid)

	column.add_child(UiKit.paragraph(Loc.t(&"profile.stats_local"), 720.0, &"CaptionLabel"))
	return column


func _build_account_card(profile: PlayerProfile) -> Control:
	var column := card(&"profile.account")

	var actions := UiKit.hbox(Design.SPACE_MD)

	if profile.is_guest:
		# Linking a Google account upgrades the guest in place: same uid, same
		# stats, plus a cloud copy.
		var upgrade := UiKit.button(Loc.t(&"auth.login.google"), &"PrimaryButton", &"google")
		UiKit.on_press(upgrade, func() -> void: Auth.upgrade_guest())
		actions.add_child(upgrade)

	var sign_out := UiKit.button(Loc.t(&"auth.signout"), &"OutlineButton", &"exit")
	UiKit.on_press(sign_out, func() -> void:
		Auth.sign_out()
		Router.clear_history()
		Router.goto(&"login")
	, "back")
	actions.add_child(sign_out)

	var delete_profile := UiKit.button(Loc.t(&"profile.reset"), &"DangerButton", &"close")
	UiKit.on_press(delete_profile, func() -> void: _confirm_delete())
	actions.add_child(delete_profile)

	column.add_child(actions)
	column.add_child(UiKit.key_value(Loc.t(&"profile.uid"), profile.uid, Design.TEXT_MUTED))
	column.add_child(UiKit.key_value(Loc.t(&"settings.dev.api_base"),
		Api.base_url if Api.is_configured() else "—", Design.TEXT_MUTED))
	column.add_child(UiKit.key_value(Loc.t(&"app.version_label", {
		"version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
	}), Settings.device_tier_label(), Design.TEXT_MUTED))
	return column


func _confirm_delete() -> void:
	# A confirmation panel rather than a blocking OS dialog: consistent on
	# Android and desktop, and it looks like the rest of the game.
	var wrapper := UiKit.panel(&"WarnPanel")
	var column := UiKit.vbox(Design.SPACE_MD)
	wrapper.add_child(column)
	column.add_child(UiKit.subheading(Loc.t(&"profile.reset")))
	column.add_child(UiKit.paragraph(Loc.t(&"profile.reset.confirm"), 520.0))

	var actions := UiKit.hbox(Design.SPACE_MD)
	var confirm := UiKit.button(Loc.t(&"common.confirm"), &"DangerButton")
	var cancel := UiKit.button(Loc.t(&"common.cancel"), &"OutlineButton")
	actions.add_child(confirm)
	actions.add_child(cancel)
	column.add_child(actions)

	var layer := UiKit.show_modal(self, wrapper, 560.0)
	UiKit.on_press(cancel, func() -> void: UiKit.close_modal(layer), "back")
	UiKit.on_press(confirm, func() -> void:
		Session.clear_profile()
		Friends.leave_party()
		Settings.set_value("game/first_run_complete", false)
		UiKit.close_modal(layer)
		EventBus.toast_requested.emit(Loc.t(&"profile.reset.done"), &"success")
		Router.clear_history()
		Router.goto(&"login")
	)


# ------------------------------------------------------------------ helpers

## "12.4k" for large damage totals; the exact figure is not useful in a tile.
func _short_number(value: int) -> String:
	if value < 10000:
		return str(value)
	return "%.1fk" % (float(value) / 1000.0)


func _format_duration(seconds: int) -> String:
	if seconds < 3600:
		return Loc.t(&"common.minutes_short", {"value": maxi(1, seconds / 60)})
	var hours := seconds / 3600
	if hours < 100:
		return "%dh %dm" % [hours, (seconds % 3600) / 60]
	return "%dh" % hours


func _format_date(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return Loc.t(&"common.never")
	var date := Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]
