class_name PlaceholderPage
extends MenuPage
## Honest "not built yet" page.
##
## Loadout, Store and Ranked are planned, not implemented. Hiding them would
## make players wonder what happened to the buttons; faking them would be
## worse. So each one states what it will contain, which phase brings it, and
## what already works today — the data layer behind all three is real, and
## this page shows the real numbers rather than lorem ipsum.

var title_key: StringName = &"menu.arsenal"
var icon_kind: StringName = &"arsenal"
var phase_key: StringName = &"common.phase_two"

## Which slice of the game this page stands in for. Drives the preview rows, so
## each placeholder is specific instead of generic filler.
var flavour: StringName = &"loadout"


func configure(title_value: StringName, icon_value: StringName) -> void:
	title_key = title_value
	icon_kind = icon_value
	match title_key:
		&"menu.store":
			flavour = &"store"
		&"menu.rank":
			flavour = &"ranked"
		_:
			flavour = &"loadout"


func build() -> void:
	body.add_child(header(title_key))

	var panel := UiKit.panel(&"CardPanel")
	var column := UiKit.vbox(Design.SPACE_LG)
	panel.add_child(column)
	body.add_child(panel)

	var row := UiKit.hbox(Design.SPACE_LG)
	var icon := HexIcon.make(icon_kind, Design.ACCENT, 44.0, 2.0, Design.TEAL)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var titles := UiKit.vbox(Design.SPACE_XXS)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UiKit.subheading(Loc.t(_headline_key())))
	titles.add_child(UiKit.paragraph(Loc.t(_body_key()), 720.0))
	row.add_child(titles)
	column.add_child(row)

	column.add_child(UiKit.pill(Loc.t(phase_key), Design.WARNING))

	match flavour:
		&"store":
			column.add_child(_build_store_preview())
		&"ranked":
			column.add_child(_build_rank_preview())
		_:
			column.add_child(_build_loadout_preview())


func _headline_key() -> StringName:
	match flavour:
		&"store": return &"store.soon.title"
		&"ranked": return &"rank.soon.title"
		_: return &"arsenal.soon.title"


func _body_key() -> StringName:
	match flavour:
		&"store": return &"store.soon.body"
		&"ranked": return &"rank.soon.body"
		_: return &"arsenal.soon.body"


## Eight empty slots: the shape of the screen that will exist, drawn from the
## same slot list the loadout editor will read. Locked, and labelled as such.
func _build_loadout_preview() -> Control:
	var grid := UiKit.grid(4, Design.SPACE_SM)
	var slots: Array[StringName] = [
		&"arsenal.slot.primary", &"arsenal.slot.secondary", &"arsenal.slot.lethal",
		&"arsenal.slot.tactical", &"arsenal.slot.perk1", &"arsenal.slot.perk2",
		&"arsenal.slot.perk3", &"arsenal.slot.perk4",
	]
	for slot in slots:
		var tile := UiKit.panel(&"InsetPanel")
		var inner := UiKit.vbox(Design.SPACE_XS)
		inner.add_child(UiKit.micro(Loc.t(slot).to_upper()))
		inner.add_child(HexIcon.make(&"lock", Design.TEXT_DIM, 22.0, 1.8))
		inner.add_child(UiKit.caption(Loc.t(&"common.locked")))
		tile.add_child(inner)
		grid.add_child(tile)
	return grid


func _build_store_preview() -> Control:
	var profile := Session.profile
	var row := UiKit.hbox(Design.SPACE_LG)
	row.add_child(UiKit.stat_tile(Loc.t(&"store.currency.credits"),
		str(profile.credits), Design.GOLD))
	row.add_child(UiKit.stat_tile(Loc.t(&"store.currency.cores"),
		str(profile.cores), Design.TEAL))
	row.add_child(UiKit.stat_tile(Loc.t(&"store.earned"), str(profile.matches_won),
		Design.TEXT))
	return row


func _build_rank_preview() -> Control:
	var profile := Session.profile
	var bounds := profile.rank_tier_bounds()
	var row := UiKit.hbox(Design.SPACE_LG)
	row.add_child(UiKit.stat_tile(Loc.t(&"rank.points"), str(profile.rank_points), Design.TEAL))
	row.add_child(UiKit.stat_tile(Loc.t(profile.rank_tier_key()),
		Loc.t(&"rank.tier_short"), Design.ACCENT))
	row.add_child(UiKit.stat_tile(Loc.t(&"rank.next_tier"),
		"%d / %d" % [profile.rank_points, bounds.y], Design.TEXT))
	return row
