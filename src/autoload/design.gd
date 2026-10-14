extends Node
## The PixelLegends design system: one palette, one type scale, one Theme.
##
## Everything visual that more than one screen needs lives here. Screens ask
## for *semantic* type variations ("PrimaryButton", "CardPanel") instead of
## assembling their own StyleBoxFlats, which is what keeps the UI coherent as
## more screens land.
##
## Art direction: an original pixel-art fantasy arena. Near-black abyss panels,
## a single electric-cyan information colour, one warm gold for player action,
## and violet reserved for the rare and the premium — all framed by ink-dark
## outlines and hard drop edges so every surface reads crisply over full-bleed
## key art. Square corners and stepped accents echo the supplied MOBA art.
##
## The palette is deliberately narrow: three hues do the work (cyan informs,
## gold acts, violet rewards), everything else is a value step of the abyss.
## That is what keeps a screen legible at phone scale and in bright sunlight.

# ------------------------------------------------------------------- palette

const BG: Color = Color("050a14")            ## Abyss: the canvas beneath all.
const BG_RAISED: Color = Color("0b1526")
const SURFACE: Color = Color("122033")       ## Cards, panels.
const SURFACE_ALT: Color = Color("1a2c46")
const SURFACE_HI: Color = Color("253c5e")    ## Hover / selected surface.
const SURFACE_SUNKEN: Color = Color("070d18")## Inset fields, tracks.

const LINE: Color = Color("2c4568")          ## Panel rule.
const LINE_STRONG: Color = Color("03060d")   ## Ink outline, near-black.
## Colour of the hard drop edge cast by raised surfaces.
const DROP_EDGE: Color = Color(0.01, 0.02, 0.05, 0.55)

const TEXT: Color = Color("f4f8ff")
const TEXT_MUTED: Color = Color("b6c6de")
const TEXT_DIM: Color = Color("7c90ad")
const TEXT_INVERSE: Color = Color("060a12")

const ACCENT: Color = Color("ffc93c")        ## Gold: the player acts.
const ACCENT_HI: Color = Color("ffe89a")
const ACCENT_DEEP: Color = Color("e0870f")
const TEAL: Color = Color("38e0ff")          ## Cyan: the field informs.
const TEAL_DEEP: Color = Color("159ed6")

const SUCCESS: Color = Color("4ade80")       ## Verdigris green.
const WARNING: Color = Color("ff9f43")       ## Ember orange.
const DANGER: Color = Color("ff4d5e")        ## Signal red.
const GOLD: Color = Color("ffd166")
const VIOLET: Color = Color("b06bff")        ## Epic / premium tier.

const TEAM_ALPHA: Color = Color("2fd4ff")
const TEAM_BRAVO: Color = Color("ff5a5f")

## Soft tints, used for chips and highlighted rows.
const ACCENT_TINT: Color = Color(1.0, 0.788, 0.235, 0.16)
const TEAL_TINT: Color = Color(0.22, 0.878, 1.0, 0.15)
const DANGER_TINT: Color = Color(1.0, 0.302, 0.369, 0.16)
const VIOLET_TINT: Color = Color(0.69, 0.42, 1.0, 0.16)

# Surfaces for the entrance and main hub.
#
# Every one of these used to sit at roughly 0.4 alpha so the supplied arena
# art showed through it. The consequence was that all of them read as the same
# washed-out blue film, and no amount of re-tuning the hue could ever be seen:
# two fills that differ by a tenth of alpha, composited over art, differ by
# less than one level out of 255. That is why an earlier pass could change
# these numbers and produce a screen that looked byte-for-byte the same.
#
# So the surfaces are now assertive. Panels and buttons are near-solid slate
# with a bright hairline edge; what separates one surface from another at
# phone scale is opacity and edge, not hue. The artwork still shows, but
# through the gaps between surfaces rather than through every surface.
const GLASS_FILL: Color = Color(0.075, 0.105, 0.165, 0.86)
const GLASS_HOVER: Color = Color(0.12, 0.20, 0.30, 0.92)
const GLASS_PRESSED: Color = Color(0.045, 0.07, 0.12, 0.95)
const GLASS_EDGE: Color = Color(0.52, 0.74, 1.0, 0.58)
const GLASS_EDGE_HI: Color = Color(0.68, 0.90, 1.0, 0.92)

## The player's action: the one saturated surface on any screen.
const GLASS_GOLD: Color = Color(0.80, 0.52, 0.09, 0.92)
const GLASS_GOLD_EDGE: Color = Color(1.0, 0.92, 0.62, 1.0)
const GLASS_GOLD_HOVER: Color = Color(0.90, 0.64, 0.16, 0.96)
const GLASS_GOLD_HOVER_EDGE: Color = Color(1.0, 0.97, 0.78, 1.0)
const GLASS_GOLD_PRESSED: Color = Color(0.58, 0.36, 0.05, 0.97)

# Panels are the darkest, flattest surfaces in the set, so the controls lying
# on top of them read forward instead of competing with the artwork behind.
const GLASS_PANEL: Color = Color(0.035, 0.05, 0.085, 0.76)
const GLASS_PANEL_EDGE: Color = Color(0.58, 0.80, 1.0, 0.72)
## Modals sit above everything, so they are the most opaque of the set.
const GLASS_MODAL: Color = Color(0.025, 0.038, 0.068, 0.88)
const GLASS_MODAL_EDGE: Color = Color(0.66, 0.86, 1.0, 0.82)

## Nav rail buttons carry a cyan stripe on their leading edge, so the rail
## reads as a column of destinations rather than as labels floating on art.
const GLASS_NAV: Color = Color(0.05, 0.075, 0.125, 0.62)
const GLASS_NAV_HOVER: Color = Color(0.13, 0.34, 0.50, 0.90)
const GLASS_NAV_HOVER_EDGE: Color = Color(0.50, 0.86, 1.0, 0.85)
const GLASS_NAV_PRESSED: Color = Color(0.07, 0.20, 0.32, 0.95)

## Quiet resting state for icon-only controls, and the off state everything
## disabled shares.
const GLASS_QUIET: Color = Color(0.06, 0.085, 0.135, 0.55)
const GLASS_QUIET_EDGE: Color = Color(0.55, 0.76, 1.0, 0.40)
const GLASS_DISABLED: Color = Color(0.05, 0.07, 0.11, 0.45)
const GLASS_DISABLED_EDGE: Color = Color(0.55, 0.70, 0.85, 0.22)

## Currency / rarity ramp, reused by the store and reward popups later.
const RARITY: Array[Color] = [
	Color("8fa3bd"),  # common
	Color("4ade80"),  # uncommon
	Color("38e0ff"),  # rare
	Color("b06bff"),  # epic
	Color("ffc93c"),  # legendary
]

# ------------------------------------------------------------------- metrics
#
# A 4px base grid. Screens should use these instead of magic numbers so that
# spacing stays consistent when a designer asks for "a bit more air".

const SPACE_XXS: int = 4
const SPACE_XS: int = 8
const SPACE_SM: int = 12
const SPACE_MD: int = 16
const SPACE_LG: int = 20
const SPACE_XL: int = 28
const SPACE_XXL: int = 36
const SPACE_HUGE: int = 48

const RADIUS_SM: int = 0
const RADIUS_MD: int = 0
const RADIUS_LG: int = 0
const RADIUS_PILL: int = 0

const BORDER_THIN: int = 2
const BORDER_ACCENT: int = 3
const BORDER_STRIPE: int = 5    ## The accent stripe on primary buttons.
## Hard drop edge under every raised surface, in pixels. A blurred drop shadow
## would fight the pixel-art language; a short crisp edge reads as depth while
## staying square and clean at any resolution.
const BORDER_DROP: int = 4
## Panels carry a heavier rule than buttons: they are the largest surfaces on
## screen and a hairline disappears against full-bleed artwork.
const BORDER_PANEL: int = 3
## Corner radius for the large floating panels.
const RADIUS_PANEL: int = 16
## Width of the leading-edge stripe on nav buttons.
const NAV_STRIPE: int = 5

# Type scale. Steps are spaced by roughly 1.2-1.35x so each rank is instantly
# distinguishable from the next; the two smallest steps tighten and the largest
# ones open up, which is what stops a phone-sized screen from looking flat.
const FONT_MICRO: int = 13
const FONT_SMALL: int = 15
const FONT_BODY: int = 18
const FONT_LEAD: int = 22
const FONT_SUBHEAD: int = 26
const FONT_H3: int = 31
const FONT_H2: int = 42
const FONT_H1: int = 56
const FONT_DISPLAY: int = 78

# Tracking, in pixels, per step. Large type is tightened (negative) so words
# read as shapes; small caps type is opened up (positive) so short uppercase
# labels do not clump together at phone scale.
const TRACK_DISPLAY: int = -2
const TRACK_H1: int = -2
const TRACK_H2: int = -1
const TRACK_H3: int = 0
const TRACK_SECTION: int = 2
const TRACK_BODY: int = 0
const TRACK_SMALL: int = 1

# Headings sit directly on full-bleed artwork, so they carry a hard ink outline.
# A drop shadow would blur at this scale; an outline stays crisp and keeps the
# pixel-art language intact.
const OUTLINE_HEADING: int = 6
const OUTLINE_SUB: int = 4

const TOUCH_TARGET_MIN: int = 56  ## Comfortable mobile tap target, in px.

# --------------------------------------------------------------------- fonts

const FONT_DIR := "res://assets/fonts/"
## Latin display face. Warmer and more "instrument panel" than a generic sans.
const FONT_DISPLAY_FILES := [
	"ChakraPetch-Bold.woff2",
	"ChakraPetch-SemiBold.woff2",
	"ChakraPetch-Medium.woff2",
]
## Body face. The client UI ships English text and uses the Latin subset.
const FONT_UI_LATIN_FILES := [
	"Vazirmatn-Latin-400.woff2",
	"Vazirmatn-Latin-500.woff2",
	"Vazirmatn-Latin-600.woff2",
	"Vazirmatn-Latin-700.woff2",
]

var theme: Theme

var font_ui: Font                 ## Latin UI glyphs.
var font_display: Font            ## Chakra Petch Bold, falls back to font_ui.
var font_heading: Font            ## Chakra Petch SemiBold → font_ui.
var font_label: Font              ## Chakra Petch Medium → font_ui.
var font_mono: Font               ## Tabular numerals for timers and scores.

## Multiplier on every type size in the theme, driven by the accessibility
## "Text Size" preference. A global multiplier rather than per-screen
## overrides: one number applied in one place, and every screen inherits it.
var text_scale := 1.0


func _ready() -> void:
	_load_fonts()
	theme = _build_theme()
	var root_window := get_tree().root
	if OS.has_feature("mobile"):
		# The design grid is authored in desktop pixels; phone controls need
		# substantially more physical space and readable type. Scrollable mobile
		# screens handle the extra height instead of shrinking the controls.
		root_window.content_scale_factor = clampf(DisplayServer.screen_get_scale(), 1.6, 1.8)
	# Assigning on the root Window makes every Control in the game inherit it,
	# including Controls created later at runtime.
	root_window.theme = theme
	# No `theme_type_variation` on the root Window on purpose: a named
	# variation that nothing defines is dead configuration, and Godot already
	# falls back to its built-in theme (and default font) for every item we do
	# not override, which keeps a forgotten property readable instead of blank.


# ------------------------------------------------------------- font loading

## Load the Latin UI face and display variants. If an asset is missing, use
## Godot's built-in fallback so the English interface remains readable.
func _load_fonts() -> void:
	var latin := _first_available(FONT_UI_LATIN_FILES)
	if latin != null:
		font_ui = latin
	else:
		push_warning("Design: falling back to the engine font for UI text.")
		font_ui = ThemeDB.fallback_font

	font_display = _variation(_first_available([FONT_DISPLAY_FILES[0]]), font_ui)
	font_heading = _variation(_first_available([FONT_DISPLAY_FILES[1]]), font_ui)
	font_label = _variation(_first_available([FONT_DISPLAY_FILES[2]]), font_ui)
	font_mono = font_heading


func _first_available(files: Array) -> FontFile:
	for file in files:
		var path := FONT_DIR + String(file)
		if ResourceLoader.exists(path):
			var resource := ResourceLoader.load(path)
			if resource is FontFile:
				return resource
	push_warning("Design: no usable font found among %s" % [files])
	return null


## Wrap a display face so glyphs it lacks are drawn by the Latin UI face.
func _variation(base: FontFile, fallback: Font) -> Font:
	if base == null:
		return fallback
	var variation := FontVariation.new()
	variation.base_font = base
	if fallback != null and fallback != base:
		variation.fallbacks = [fallback]
	return variation


# ------------------------------------------------------------------- theme

func _build_theme() -> Theme:
	var built := Theme.new()
	built.default_font = font_ui
	built.default_font_size = FONT_BODY

	_add_labels(built)
	_add_buttons(built)
	_add_panels(built)
	_add_inputs(built)
	_add_bars(built)
	_add_scrollbars(built)
	_add_misc(built)
	return built


## Labels — one variation per step of the type scale.
## A type size after the accessibility multiplier. Rounded, because a
## fractional font size makes glyph rasterisation inconsistent between runs.
func _scaled(size: int) -> int:
	return int(round(float(size) * text_scale))


## Rebuild the theme at a new text scale and hand it back to the root window.
## Rebuilding rather than patching keeps one source of truth for the type
## ramp, at the cost of a brief hitch — acceptable for a setting a player
## changes once.
func set_text_scale(value: float) -> void:
	var next := clampf(value, 0.85, 1.35)
	if absf(next - text_scale) < 0.001:
		return
	text_scale = next
	theme = _build_theme()
	var root_window := get_tree().root
	if root_window != null:
		root_window.theme = theme


func _add_labels(built: Theme) -> void:
	var steps := [
		{"name": &"DisplayLabel", "font": font_display, "size": FONT_DISPLAY, "color": TEXT, "spacing": TRACK_DISPLAY, "outline": OUTLINE_HEADING},
		{"name": &"TitleLabel", "font": font_display, "size": FONT_H1, "color": TEXT, "spacing": TRACK_H1, "outline": OUTLINE_HEADING},
		{"name": &"HeadingLabel", "font": font_heading, "size": FONT_H2, "color": TEXT, "spacing": TRACK_H2, "outline": OUTLINE_SUB},
		{"name": &"SubheadingLabel", "font": font_heading, "size": FONT_H3, "color": TEXT, "spacing": TRACK_H3, "outline": OUTLINE_SUB},
		{"name": &"SectionLabel", "font": font_label, "size": FONT_LEAD, "color": TEXT_MUTED, "spacing": TRACK_SECTION, "outline": 0},
		{"name": &"BodyLabel", "font": font_ui, "size": FONT_BODY, "color": TEXT, "spacing": TRACK_BODY, "outline": 0},
		{"name": &"BodyMutedLabel", "font": font_ui, "size": FONT_BODY, "color": TEXT_MUTED, "spacing": TRACK_BODY, "outline": 0},
		{"name": &"CaptionLabel", "font": font_ui, "size": FONT_SMALL, "color": TEXT_MUTED, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"MicroLabel", "font": font_label, "size": FONT_MICRO, "color": TEXT_DIM, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"ValueLabel", "font": font_display, "size": FONT_SUBHEAD, "color": TEXT, "spacing": TRACK_BODY, "outline": OUTLINE_SUB},
		{"name": &"NumericLabel", "font": font_mono, "size": FONT_LEAD, "color": TEXT, "spacing": TRACK_BODY, "outline": 0},
		{"name": &"AccentLabel", "font": font_label, "size": FONT_SMALL, "color": ACCENT, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"TealLabel", "font": font_label, "size": FONT_SMALL, "color": TEAL, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"DangerLabel", "font": font_label, "size": FONT_SMALL, "color": DANGER, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"SuccessLabel", "font": font_label, "size": FONT_SMALL, "color": SUCCESS, "spacing": TRACK_SMALL, "outline": 0},
		{"name": &"WarningLabel", "font": font_label, "size": FONT_SMALL, "color": WARNING, "spacing": TRACK_SMALL, "outline": 0},
	]
	for step in steps:
		var variation: StringName = step["name"]
		built.set_type_variation(variation, &"Label")
		if step["font"] != null:
			built.set_font(&"font", variation, step["font"])
		built.set_font_size(&"font_size", variation, _scaled(step["size"]))
		built.set_color(&"font_color", variation, step["color"])
		built.set_constant(&"line_spacing", variation, int(step["spacing"]))
		var outline := int(step["outline"])
		built.set_constant(&"outline_size", variation, outline)
		if outline > 0:
			built.set_color(&"font_outline_color", variation, LINE_STRONG)


## Buttons — five levels of emphasis, each with the full interaction set.
func _add_buttons(built: Theme) -> void:
	var kinds := [
		{
			"name": &"PrimaryButton", "fill": ACCENT, "border": BG,
			"text": TEXT_INVERSE, "stripe": Color.TRANSPARENT,
			"hover": ACCENT_HI, "pressed": ACCENT_DEEP,
		},
		{
			"name": &"SecondaryButton", "fill": SURFACE_ALT, "border": LINE_STRONG,
			"text": TEXT, "stripe": ACCENT, "hover": SURFACE_HI, "pressed": SURFACE,
		},
		{
			"name": &"GhostButton", "fill": Color(0, 0, 0, 0), "border": Color(0, 0, 0, 0),
			"text": TEXT_MUTED, "stripe": Color.TRANSPARENT,
			"hover": SURFACE_ALT, "pressed": SURFACE,
		},
		{
			"name": &"OutlineButton", "fill": Color(0, 0, 0, 0), "border": LINE,
			"text": TEXT, "stripe": Color.TRANSPARENT,
			"hover": SURFACE_ALT, "pressed": SURFACE_HI,
		},
		{
			"name": &"DangerButton", "fill": DANGER_TINT, "border": DANGER,
			"text": DANGER, "stripe": Color.TRANSPARENT,
			"hover": DANGER, "pressed": Color("d92b40"),
		},
		{
			"name": &"TealButton", "fill": TEAL_TINT, "border": TEAL,
			"text": TEAL, "stripe": Color.TRANSPARENT,
			"hover": TEAL, "pressed": TEAL_DEEP,
		},
	]
	for kind in kinds:
		var variation: StringName = kind["name"]
		built.set_type_variation(variation, &"Button")
		var radius := RADIUS_MD if variation == &"PrimaryButton" else RADIUS_SM
		built.set_stylebox(&"normal", variation,
			_button_box(kind["fill"], kind["border"], kind["stripe"], radius, 1))
		built.set_stylebox(&"hover", variation,
			_button_box(kind["hover"], kind["border"], kind["stripe"], radius, 1))
		built.set_stylebox(&"pressed", variation,
			_button_box(kind["pressed"], kind["border"], kind["stripe"], radius, 1))
		built.set_stylebox(&"disabled", variation,
			_button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, radius, 0))
		built.set_stylebox(&"focus", variation,
			_button_box(Color(0, 0, 0, 0), TEAL, Color.TRANSPARENT, radius, BORDER_ACCENT))

		var is_solid := variation == &"PrimaryButton"
		built.set_color(&"font_color", variation, kind["text"])
		built.set_color(&"font_hover_color", variation, TEXT_INVERSE if is_solid else TEXT)
		built.set_color(&"font_pressed_color", variation, TEXT_INVERSE if is_solid else TEXT_MUTED)
		built.set_color(&"font_focus_color", variation, kind["text"])
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
		built.set_constant(&"h_separation", variation, SPACE_SM)
		built.set_constant(&"outline_size", variation, 0)

	# New entrance and hub controls use translucent surfaces rather than solid
	# slabs, with a warm glass accent reserved for the active action.
	_register_glass_button(
		built, &"GlassButton", GLASS_FILL, GLASS_EDGE,
		GLASS_HOVER, GLASS_EDGE_HI, GLASS_PRESSED, TEXT
	)
	_register_glass_button(
		built, &"GlassPrimaryButton",
		GLASS_GOLD, GLASS_GOLD_EDGE,
		GLASS_GOLD_HOVER, GLASS_GOLD_HOVER_EDGE,
		GLASS_GOLD_PRESSED, TEXT
	)
	# Nav rail entries are registered by hand rather than through
	# _register_glass_button, because they carry a stripe on the leading edge
	# and that helper has no parameter slot left for one. The stripe is what
	# turns the rail from loose labels into a column of destinations.
	built.set_type_variation(&"GlassNavButton", &"Button")
	built.set_stylebox(&"normal", &"GlassNavButton",
		_glass_box(GLASS_NAV, Color.TRANSPARENT, 12, 18, 14, 0, TEAL))
	built.set_stylebox(&"hover", &"GlassNavButton",
		_glass_box(GLASS_NAV_HOVER, Color.TRANSPARENT, 12, 18, 14, 6, TEAL))
	built.set_stylebox(&"pressed", &"GlassNavButton",
		_glass_box(GLASS_NAV_PRESSED, Color.TRANSPARENT, 12, 18, 14, 2, ACCENT_HI))
	built.set_stylebox(&"focus", &"GlassNavButton",
		_glass_box(GLASS_NAV_HOVER, Color.TRANSPARENT, 12, 18, 14, 6, ACCENT_HI))
	built.set_stylebox(&"disabled", &"GlassNavButton",
		_glass_box(GLASS_DISABLED, Color.TRANSPARENT, 12, 18, 14, 0, Color.TRANSPARENT))
	built.set_color(&"font_color", &"GlassNavButton", TEXT_MUTED)
	built.set_color(&"font_hover_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_pressed_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_focus_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_disabled_color", &"GlassNavButton", TEXT_DIM)
	built.set_font(&"font", &"GlassNavButton", font_label)
	built.set_font_size(&"font_size", &"GlassNavButton", FONT_BODY)
	built.set_constant(&"h_separation", &"GlassNavButton", SPACE_SM)
	built.set_constant(&"outline_size", &"GlassNavButton", 0)

	# Chips: compact toggle-ish buttons used for mode and region selection.
	for state in [{"name": &"ChipButton", "active": false}, {"name": &"ChipButtonActive", "active": true}]:
		var variation: StringName = state["name"]
		built.set_type_variation(variation, &"Button")
		var active: bool = state["active"]
		var fill := ACCENT_TINT if active else SURFACE_ALT
		var border := ACCENT if active else LINE
		built.set_stylebox(&"normal", variation, _button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, 1, 10, 6))
		built.set_stylebox(&"hover", variation,
			_button_box(ACCENT_TINT if not active else fill, ACCENT if active else LINE_STRONG,
				Color.TRANSPARENT, RADIUS_SM, 1, 10, 6))
		built.set_stylebox(&"pressed", variation, _button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, 1, 10, 6))
		built.set_stylebox(&"focus", variation, _button_box(Color(0, 0, 0, 0), TEAL, Color.TRANSPARENT, RADIUS_SM, BORDER_ACCENT, 10, 6))
		built.set_stylebox(&"disabled", variation, _button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, RADIUS_SM, 0, 10, 6))
		built.set_color(&"font_color", variation, ACCENT_HI if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, ACCENT_HI if not active else ACCENT_HI)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, FONT_SMALL)
		built.set_constant(&"h_separation", variation, SPACE_XS)

	# Region chips keep the same state language with tighter padding and a
	# smaller UI face so all seven choices remain readable in a 3-column grid.
	for state in [{"name": &"RegionChipButton", "active": false},
			{"name": &"RegionChipButtonActive", "active": true}]:
		var variation: StringName = state["name"]
		var active: bool = state["active"]
		var fill := ACCENT_TINT if active else SURFACE_ALT
		var border := ACCENT if active else LINE
		built.set_type_variation(variation, &"Button")
		built.set_stylebox(&"normal", variation,
			_button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 4, 4))
		built.set_stylebox(&"hover", variation,
			_button_box(ACCENT_TINT if not active else fill, ACCENT if active else LINE_STRONG,
				Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 4, 4))
		built.set_stylebox(&"pressed", variation,
			_button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 4, 4))
		built.set_stylebox(&"focus", variation,
			_button_box(Color(0, 0, 0, 0), TEAL, Color.TRANSPARENT, RADIUS_SM,
				BORDER_ACCENT, 4, 4))
		built.set_stylebox(&"disabled", variation,
			_button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, RADIUS_SM, 0, 4, 4))
		built.set_color(&"font_color", variation, ACCENT_HI if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, ACCENT_HI)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_font(&"font", variation, font_ui)
		built.set_font_size(&"font_size", variation, FONT_MICRO)

	# Cards: large selectable tiles (mode picker, room browser). Same
	# interaction model as a chip, with room for a title, a rule summary and a
	# tag row instead of one word.
	for state in [{"name": &"CardButton", "active": false},
			{"name": &"CardButtonActive", "active": true}]:
		var card_variation: StringName = state["name"]
		built.set_type_variation(card_variation, &"Button")
		var card_active: bool = state["active"]
		var card_fill: Color = ACCENT_TINT if card_active else SURFACE
		var card_border: Color = ACCENT if card_active else LINE
		built.set_stylebox(&"normal", card_variation,
			_button_box(card_fill, card_border, Color.TRANSPARENT, RADIUS_LG, 1, 16, 14))
		built.set_stylebox(&"hover", card_variation, _button_box(
			ACCENT_TINT if card_active else SURFACE_ALT,
			ACCENT_HI if card_active else LINE_STRONG, Color.TRANSPARENT, RADIUS_LG, 1, 16, 14))
		built.set_stylebox(&"pressed", card_variation,
			_button_box(SURFACE_HI, card_border, Color.TRANSPARENT, RADIUS_LG, 1, 16, 14))
		built.set_stylebox(&"focus", card_variation,
			_button_box(card_fill, TEAL, Color.TRANSPARENT, RADIUS_LG, BORDER_ACCENT, 16, 14))
		built.set_stylebox(&"disabled", card_variation,
			_button_box(Color(1, 1, 1, 0.02), LINE, Color.TRANSPARENT, RADIUS_LG, 1, 16, 14))

	# Nav rail entries: big, flat, left-striped when active.
	for variant in [{"name": &"NavButton", "active": false}, {"name": &"NavButtonActive", "active": true}]:
		var variation: StringName = variant["name"]
		built.set_type_variation(variation, &"Button")
		var active: bool = variant["active"]
		var fill := SURFACE_ALT if active else Color(0, 0, 0, 0)
		var stripe := ACCENT if active else Color.TRANSPARENT
		built.set_stylebox(&"normal", variation, _button_box(fill, Color(0, 0, 0, 0), stripe, RADIUS_SM, 0, 14, 12, 3))
		built.set_stylebox(&"hover", variation, _button_box(SURFACE_ALT, Color(0, 0, 0, 0), ACCENT if active else LINE_STRONG, RADIUS_SM, 0, 14, 12, 3))
		built.set_stylebox(&"pressed", variation, _button_box(SURFACE_HI, Color(0, 0, 0, 0), stripe, RADIUS_SM, 0, 14, 12, 3))
		built.set_stylebox(&"focus", variation, _button_box(Color(0, 0, 0, 0), TEAL, Color.TRANSPARENT, RADIUS_SM, 1, 14, 12, 3))
		built.set_color(&"font_color", variation, TEXT if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, TEXT)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
		built.set_constant(&"h_separation", variation, SPACE_MD)

	# Icon-only controls get the same quiet glass treatment and a bright focus ring.
	built.set_type_variation(&"IconButton", &"Button")
	built.set_stylebox(&"normal", &"IconButton",
		_glass_box(GLASS_QUIET, GLASS_QUIET_EDGE, 18, 8, 8, 4))
	built.set_stylebox(&"hover", &"IconButton",
		_glass_box(GLASS_HOVER, GLASS_EDGE_HI, 18, 8, 8, 10))
	built.set_stylebox(&"pressed", &"IconButton",
		_glass_box(GLASS_PRESSED, GLASS_EDGE_HI, 18, 8, 8, 4))
	built.set_stylebox(&"focus", &"IconButton",
		_glass_box(GLASS_QUIET, GLASS_EDGE_HI, 18, 8, 8, 8))
	built.set_stylebox(&"disabled", &"IconButton",
		_glass_box(GLASS_DISABLED, GLASS_DISABLED_EDGE, 18, 8, 8, 0))
	built.set_color(&"font_color", &"IconButton", TEXT_MUTED)
	built.set_color(&"font_hover_color", &"IconButton", TEXT)
	built.set_color(&"font_pressed_color", &"IconButton", TEXT)
	built.set_color(&"font_disabled_color", &"IconButton", TEXT_DIM)


## Build a button stylebox.
##
## `stripe` and `border` are mutually exclusive on purpose: a StyleBoxFlat has
## a single border colour, so a differently-coloured edge is only achievable by
## drawing *just* that edge. When a stripe is requested the other three edges
## are suppressed, which is exactly the "accent bar on the leading side" look
## used by the nav rail.
func _button_box(
	fill: Color, border: Color, stripe: Color, radius: int,
	border_width: int, pad_x: int = 16, pad_y: int = 12,
	drop: int = BORDER_DROP
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(float(SPACE_SM))
	box.content_margin_left = float(pad_x)
	box.content_margin_right = float(pad_x)
	box.content_margin_top = float(pad_y)
	box.content_margin_bottom = float(pad_y)
	if stripe.a > 0.0:
		box.border_color = stripe
		box.set_border_width_all(0)
		box.border_width_left = BORDER_STRIPE
	elif border_width > 0 and border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(border_width)
	_apply_drop_edge(box, drop)
	box.anti_aliasing = false
	return box


## A short, crisp edge beneath a raised surface. `shadow_size` is held at one
## pixel: zero would draw nothing at all, and anything larger would blur into a
## soft shadow that fights the pixel-art language.
func _apply_drop_edge(box: StyleBoxFlat, thickness: int) -> void:
	if thickness <= 0:
		return
	box.shadow_color = DROP_EDGE
	box.shadow_size = 1
	box.shadow_offset = Vector2(0.0, float(thickness))


## Soft translucent surface used by the entrance and hub controls.
func _glass_box(
	fill: Color, edge: Color, radius: int, pad_x: int = 18, pad_y: int = 14,
	shadow_size: int = 8, stripe: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(float(SPACE_SM))
	box.content_margin_left = float(pad_x)
	box.content_margin_right = float(pad_x)
	box.content_margin_top = float(pad_y)
	box.content_margin_bottom = float(pad_y)
	if stripe.a > 0.0:
		# A bar on the leading edge only. Three edges are suppressed because a
		# StyleBoxFlat has one border colour for all four sides, so the only way
		# to show a differently-coloured edge is to draw just that one.
		box.border_color = stripe
		box.set_border_width_all(0)
		box.border_width_left = NAV_STRIPE
	elif edge.a > 0.0:
		box.border_color = edge
		box.set_border_width_all(BORDER_THIN)
	box.anti_aliasing = true
	if shadow_size > 0:
		box.shadow_color = DROP_EDGE
		box.shadow_size = shadow_size
		box.shadow_offset = Vector2(0.0, 4.0)
	return box


func _register_glass_button(
	built: Theme, variation: StringName, fill: Color, edge: Color,
	hover_fill: Color, hover_edge: Color, pressed_fill: Color,
	text_color: Color
) -> void:
	var radius := 18
	built.set_type_variation(variation, &"Button")
	built.set_stylebox(&"normal", variation,
		_glass_box(fill, edge, radius, 20, 14, 8))
	built.set_stylebox(&"hover", variation,
		_glass_box(hover_fill, hover_edge, radius, 20, 14, 12))
	built.set_stylebox(&"pressed", variation,
		_glass_box(pressed_fill, hover_edge, radius, 20, 14, 4))
	built.set_stylebox(&"focus", variation,
		_glass_box(fill, GLASS_EDGE_HI, radius, 20, 14, 8))
	built.set_stylebox(&"disabled", variation,
		_glass_box(GLASS_DISABLED, GLASS_DISABLED_EDGE, radius, 20, 14, 0))
	built.set_color(&"font_color", variation, text_color)
	built.set_color(&"font_hover_color", variation, TEXT)
	built.set_color(&"font_pressed_color", variation, TEXT)
	built.set_color(&"font_focus_color", variation, TEXT)
	built.set_color(&"font_disabled_color", variation,
		Color(TEXT.r, TEXT.g, TEXT.b, 0.58))
	built.set_font(&"font", variation, font_label)
	built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
	built.set_constant(&"h_separation", variation, SPACE_SM)
	built.set_constant(&"outline_size", variation, 0)


## Panels — the surfaces everything else is placed on.
func _add_panels(built: Theme) -> void:
	var panels := [
		{"name": &"CardPanel", "fill": SURFACE, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_XL},
		{"name": &"SetupCardPanel", "fill": SURFACE, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_SM},
		{"name": &"FlatPanel", "fill": Color(0, 0, 0, 0), "border": Color(0, 0, 0, 0), "radius": 0, "pad": 0},
		{"name": &"InsetPanel", "fill": SURFACE_SUNKEN, "border": LINE, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"RaisedPanel", "fill": SURFACE_ALT, "border": LINE_STRONG, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"TopBarPanel", "fill": BG_RAISED, "border": LINE, "radius": 0, "pad": SPACE_LG},
		{"name": &"ActionDockPanel", "fill": BG_RAISED, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_SM},
		{
			"name": &"EntranceDockPanel",
			"fill": GLASS_PANEL, "border": GLASS_PANEL_EDGE,
			"radius": RADIUS_PANEL, "pad": SPACE_MD,
		},
		{
			"name": &"GlassModalPanel",
			"fill": GLASS_MODAL, "border": GLASS_MODAL_EDGE,
			"radius": RADIUS_PANEL, "pad": SPACE_XL,
		},
		{"name": &"BannerPanel", "fill": ACCENT_TINT, "border": ACCENT, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"InfoPanel", "fill": TEAL_TINT, "border": TEAL, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"WarnPanel", "fill": DANGER_TINT, "border": DANGER, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"ChipPanel", "fill": SURFACE_ALT, "border": LINE, "radius": RADIUS_SM, "pad": SPACE_SM},
		{"name": &"AccentChipPanel", "fill": ACCENT_TINT, "border": ACCENT, "radius": RADIUS_SM, "pad": SPACE_SM},
		{"name": &"TealChipPanel", "fill": TEAL_TINT, "border": TEAL, "radius": RADIUS_SM, "pad": SPACE_SM},
	]
	for panel in panels:
		var variation: StringName = panel["name"]
		built.set_type_variation(variation, &"PanelContainer")
		var box := StyleBoxFlat.new()
		box.bg_color = panel["fill"]
		box.set_corner_radius_all(int(panel["radius"]))
		box.set_content_margin_all(float(panel["pad"]))
		box.anti_aliasing = false
		var fill: Color = panel["fill"]
		if (panel["border"] as Color).a > 0.0:
			box.border_color = panel["border"]
			box.set_border_width_all(BORDER_PANEL)
		if variation == &"EntranceDockPanel" or variation == &"GlassModalPanel":
			# These float above the artwork, so they get a soft lift rather
			# than a hard edge; a crisp edge here would read as a sticker.
			box.anti_aliasing = true
			box.shadow_color = DROP_EDGE
			box.shadow_size = 16 if variation == &"EntranceDockPanel" else 22
			box.shadow_offset = Vector2(0.0, 7.0)
		elif fill.a > 0.0:
			# Panels resting on the canvas take the same crisp drop edge as
			# buttons, so every raised surface in the app shares one language.
			_apply_drop_edge(box, BORDER_DROP)
		built.set_stylebox(&"panel", variation, box)


func _add_inputs(built: Theme) -> void:
	var box := func(fill: Color, border: Color, width: int) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(RADIUS_SM)
		style.set_content_margin_all(float(SPACE_SM))
		style.content_margin_left = float(SPACE_MD)
		style.content_margin_right = float(SPACE_MD)
		style.content_margin_top = float(SPACE_MD)
		style.content_margin_bottom = float(SPACE_MD)
		if width > 0:
			style.border_color = border
			style.set_border_width_all(width)
		style.anti_aliasing = false
		return style

	for variation in [&"LineEdit", &"HexLineEdit"]:
		built.set_stylebox(&"normal", variation, box.call(SURFACE_SUNKEN, LINE, BORDER_THIN))
		built.set_stylebox(&"focus", variation, box.call(SURFACE_SUNKEN, ACCENT, BORDER_ACCENT))
		built.set_stylebox(&"read_only", variation, box.call(Color(1, 1, 1, 0.02), LINE, BORDER_THIN))
		built.set_stylebox(&"disabled", variation, box.call(Color(1, 1, 1, 0.02), LINE, 0))
		built.set_font(&"font", variation, font_ui)
		built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
		built.set_color(&"font_color", variation, TEXT)
		built.set_color(&"font_placeholder_color", variation, TEXT_DIM)
		built.set_color(&"font_selected_color", variation, TEXT_INVERSE)
		built.set_color(&"caret_color", variation, ACCENT)
		built.set_color(&"selection_color", variation, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
		built.set_constant(&"caret_width", variation, 2)
		built.set_constant(&"minimum_character_width", variation, 4)

	built.set_type_variation(&"HexLineEdit", &"LineEdit")
	built.set_type_variation(&"HexTextEdit", &"TextEdit")
	built.set_font(&"font", &"HexTextEdit", font_ui)
	built.set_font_size(&"font_size", &"HexTextEdit", FONT_BODY)
	built.set_color(&"font_color", &"HexTextEdit", TEXT)

	# Check boxes / toggles: keep Godot's icons, restyle the text and spacing.
	for variation in [&"CheckBox", &"CheckButton"]:
		built.set_font(&"font", variation, font_ui)
		built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
		built.set_color(&"font_color", variation, TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, TEXT)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_color(&"font_focus_color", variation, TEXT)
		built.set_constant(&"h_separation", variation, SPACE_MD)
		built.set_constant(&"check_v_offset", variation, 0)

	# Sliders: style the track, let the grabber come from the fallback theme
	# until we ship custom art.
	built.set_type_variation(&"HexSlider", &"HSlider")
	for state in [{"name": &"slider", "fill": SURFACE_SUNKEN}, {"name": &"grabber_area", "fill": ACCENT},
			{"name": &"grabber_area_highlight", "fill": ACCENT_HI}]:
		var style := StyleBoxFlat.new()
		style.bg_color = state["fill"]
		style.set_corner_radius_all(RADIUS_PILL)
		style.anti_aliasing = false
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		built.set_stylebox(StringName(state["name"]), &"HexSlider", style)
	built.set_constant(&"center_grabber", &"HexSlider", 0)
	built.set_constant(&"grabber_offset", &"HexSlider", 0)


func _add_bars(built: Theme) -> void:
	var bars := [
		{"name": &"XpBar", "fill": ACCENT, "height": 8},
		{"name": &"RankBar", "fill": TEAL, "height": 8},
		{"name": &"ThinBar", "fill": ACCENT, "height": 4},
		{"name": &"HealthBar", "fill": SUCCESS, "height": 14},
	]
	for bar in bars:
		var variation: StringName = bar["name"]
		built.set_type_variation(variation, &"ProgressBar")
		var background := StyleBoxFlat.new()
		background.bg_color = SURFACE_SUNKEN
		background.set_corner_radius_all(RADIUS_PILL)
		background.anti_aliasing = false
		background.content_margin_top = 0.0
		background.content_margin_bottom = 0.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar["fill"]
		fill.set_corner_radius_all(RADIUS_PILL)
		fill.anti_aliasing = false
		built.set_stylebox(&"background", variation, background)
		built.set_stylebox(&"fill", variation, fill)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, FONT_MICRO)
		built.set_color(&"font_color", variation, TEXT)
		built.set_color(&"font_outline_color", variation, BG)
		built.set_constant(&"outline_size", variation, 3)
		# ProgressBar height is driven by `custom_minimum_size` at the call
		# site; a theme constant would be silently ignored.
		built.set_constant(&"indeterminate_height", variation, int(bar["height"]))


func _add_scrollbars(built: Theme) -> void:
	for axis in [&"VScrollBar", &"HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.03)
		track.set_corner_radius_all(RADIUS_PILL)
		track.anti_aliasing = false
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = LINE_STRONG
		grabber.set_corner_radius_all(RADIUS_PILL)
		grabber.anti_aliasing = false
		var grabber_hl := StyleBoxFlat.new()
		grabber_hl.bg_color = ACCENT
		grabber_hl.set_corner_radius_all(RADIUS_PILL)
		grabber_hl.anti_aliasing = false
		built.set_stylebox(&"scroll", axis, track)
		built.set_stylebox(&"grabber", axis, grabber)
		built.set_stylebox(&"grabber_highlight", axis, grabber_hl)
		built.set_stylebox(&"grabber_pressed", axis, grabber_hl)
	built.set_type_variation(&"HexScrollContainer", &"ScrollContainer")
	built.set_stylebox(&"panel", &"HexScrollContainer", StyleBoxEmpty.new())

	# Containers: consistent gutters everywhere. BoxContainer uses a single
	# `separation`, the grid/flow containers use `h_separation`/`v_separation`.
	for container in [&"VBoxContainer", &"HBoxContainer"]:
		built.set_constant(&"separation", container, SPACE_MD)
	for container in [&"GridContainer", &"FlowContainer"]:
		built.set_constant(&"h_separation", container, SPACE_MD)
		built.set_constant(&"v_separation", container, SPACE_MD)

	built.set_type_variation(&"CardBody", &"VBoxContainer")
	built.set_constant(&"separation", &"CardBody", SPACE_SM)

	built.set_type_variation(&"PillRow", &"HBoxContainer")
	built.set_constant(&"separation", &"PillRow", SPACE_SM)


func _add_misc(built: Theme) -> void:
	# Popups keep the dark treatment instead of Godot's light default. We set
	# the base types directly (not a variation) so every popup in the game —
	# including the ones Godot opens itself — picks it up.
	for popup in [&"PopupMenu", &"PopupPanel"]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = SURFACE_ALT
		panel.set_corner_radius_all(RADIUS_MD)
		panel.set_content_margin_all(float(SPACE_XS))
		panel.border_color = LINE_STRONG
		panel.set_border_width_all(BORDER_THIN)
		panel.anti_aliasing = false
		built.set_stylebox(&"panel", popup, panel)
		built.set_font(&"font", popup, font_ui)
		built.set_font_size(&"font_size", popup, FONT_BODY)
		built.set_color(&"font_color", popup, TEXT)
		built.set_color(&"font_hover_color", popup, TEXT_INVERSE)

	# Tooltips and the built-in dialogs should not look like a different app.
	built.set_stylebox(&"panel", &"TooltipPanel", _button_box(SURFACE_HI, LINE_STRONG, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, SPACE_MD, SPACE_SM))
	built.set_font(&"font", &"TooltipLabel", font_ui)
	built.set_font_size(&"font_size", &"TooltipLabel", FONT_SMALL)
	built.set_color(&"font_color", &"TooltipLabel", TEXT)


# ------------------------------------------------------------------ helpers

func rarity_color(tier: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)]


## A hairline separator ColorRect, styled and sized.
func separator(color: Color = LINE, height: int = 1) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, height)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Standard margin wrapper. Keeps screens from inventing their own padding.
func padded(child: Control, margin: int = SPACE_XL, top: int = -1) -> MarginContainer:
	var wrapper := MarginContainer.new()
	var top_margin := margin if top < 0 else top
	wrapper.add_theme_constant_override("margin_left", margin)
	wrapper.add_theme_constant_override("margin_right", margin)
	wrapper.add_theme_constant_override("margin_top", top_margin)
	wrapper.add_theme_constant_override("margin_bottom", margin)
	wrapper.add_child(child)
	return wrapper


## True on the form factors the UI should compress itself for. Phones in
## landscape are roughly 2400x1080 at most, so we branch on logical height.
func is_compact() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	var min_side := minf(size.x, size.y)
	return min_side < 720.0 or OS.has_feature("mobile")


## Safe-area aware content rect (notches, rounded corners). Phones in
## landscape have insets on the left/right edges, which is exactly where a nav
## rail would like to sit.
func safe_area() -> Rect2i:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2i()
	return DisplayServer.get_display_safe_area()
