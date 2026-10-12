extends Node
## The HEXORA design system: one palette, one type scale, one Theme.
##
## Everything visual that more than one screen needs lives here. Screens ask
## for *semantic* type variations ("PrimaryButton", "CardPanel") instead of
## assembling their own StyleBoxFlats, which is what keeps the UI coherent as
## more screens land.
##
## Art direction (agreed for the project): clean semi-realistic 3D, not pixel
## art and not photoreal — think "graphite and machined aluminium, lit by
## sodium orange and instrument teal". The interface follows the same rule:
## dark, low-saturation surfaces, one warm accent for actions, one cold accent
## for information, and thin hairline borders instead of heavy chrome.

# ------------------------------------------------------------------- palette

const BG: Color = Color("070b11")            ## App background, deepest layer.
const BG_RAISED: Color = Color("0b1119")
const SURFACE: Color = Color("0c1219")       ## Cards, panels.
const SURFACE_ALT: Color = Color("111a24")
const SURFACE_HI: Color = Color("17222e")    ## Hover / selected surface.
const SURFACE_SUNKEN: Color = Color("080d13")## Inset fields, tracks.

const LINE: Color = Color("1e2c3a")          ## Hairline borders.
const LINE_STRONG: Color = Color("2b3d4f")

const TEXT: Color = Color("e8eef5")
const TEXT_MUTED: Color = Color("8fa0b3")
const TEXT_DIM: Color = Color("5c6b7d")
const TEXT_INVERSE: Color = Color("070b11")

const ACCENT: Color = Color("ff7a1a")        ## Warm: the player acts.
const ACCENT_HI: Color = Color("ffa53d")
const ACCENT_DEEP: Color = Color("c9530a")
const TEAL: Color = Color("18e0c8")          ## Cold: the game informs.
const TEAL_DEEP: Color = Color("0d8f80")

const SUCCESS: Color = Color("38e07b")
const WARNING: Color = Color("ffb020")
const DANGER: Color = Color("ff4d6d")
const GOLD: Color = Color("ffd166")

const TEAM_ALPHA: Color = Color("4da3ff")
const TEAM_BRAVO: Color = Color("ff6b3d")

## Soft tints, used for chips and highlighted rows.
const ACCENT_TINT: Color = Color(1.0, 0.478, 0.102, 0.14)
const TEAL_TINT: Color = Color(0.094, 0.878, 0.784, 0.12)
const DANGER_TINT: Color = Color(1.0, 0.302, 0.427, 0.14)

## Currency / rarity ramp, reused by the store and reward popups later.
const RARITY: Array[Color] = [
	Color("8fa0b3"),  # common
	Color("38e07b"),  # uncommon
	Color("4da3ff"),  # rare
	Color("b48cff"),  # epic
	Color("ffb020"),  # legendary
]

# ------------------------------------------------------------------- metrics
#
# A 4px base grid. Screens should use these instead of magic numbers so that
# spacing stays consistent when a designer asks for "a bit more air".

const SPACE_XXS: int = 2
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 16
const SPACE_XL: int = 24
const SPACE_XXL: int = 32
const SPACE_HUGE: int = 48

const RADIUS_SM: int = 4
const RADIUS_MD: int = 8
const RADIUS_LG: int = 14
const RADIUS_PILL: int = 999

const BORDER_THIN: int = 1
const BORDER_ACCENT: int = 2
const BORDER_STRIPE: int = 3    ## The accent stripe on primary buttons.

const FONT_MICRO: int = 12
const FONT_SMALL: int = 14
const FONT_BODY: int = 16
const FONT_LEAD: int = 19
const FONT_SUBHEAD: int = 22
const FONT_H3: int = 26
const FONT_H2: int = 34
const FONT_H1: int = 46
const FONT_DISPLAY: int = 64

const TOUCH_TARGET_MIN: int = 48  ## Android accessibility minimum, in px.

# --------------------------------------------------------------------- fonts

const FONT_DIR := "res://assets/fonts/"
## Latin display face. Warmer and more "instrument panel" than a generic sans.
const FONT_DISPLAY_FILES := [
	"ChakraPetch-Bold.woff2",
	"ChakraPetch-SemiBold.woff2",
	"ChakraPetch-Medium.woff2",
]
## Body face. Vazirmatn carries Persian natively and has a matching Latin cut,
## so mixed-script lines stay on one baseline and one weight ramp.
const FONT_UI_LATIN_FILES := [
	"Vazirmatn-Latin-400.woff2",
	"Vazirmatn-Latin-500.woff2",
	"Vazirmatn-Latin-600.woff2",
	"Vazirmatn-Latin-700.woff2",
]
const FONT_UI_ARABIC_FILES := [
	"Vazirmatn-Arabic-400.woff2",
	"Vazirmatn-Arabic-500.woff2",
	"Vazirmatn-Arabic-600.woff2",
	"Vazirmatn-Arabic-700.woff2",
]

var theme: Theme

var font_ui: Font                 ## Vazirmatn, Persian + Latin glyphs.
var font_display: Font            ## Chakra Petch Bold, falls back to font_ui.
var font_heading: Font            ## Chakra Petch SemiBold → font_ui.
var font_label: Font              ## Chakra Petch Medium → font_ui.
var font_mono: Font               ## Tabular numerals for timers and scores.


func _ready() -> void:
	_load_fonts()
	theme = _build_theme()
	# Assigning on the root Window makes every Control in the game inherit it,
	# including Controls created later at runtime.
	get_tree().root.theme = theme
	# No `theme_type_variation` on the root Window on purpose: a named
	# variation that nothing defines is dead configuration, and Godot already
	# falls back to its built-in theme (and default font) for every item we do
	# not override, which keeps a forgotten property readable instead of blank.


# ------------------------------------------------------------- font loading

## Build a Font whose `fallbacks` chain covers Latin, Persian/Arabic and the
## engine's own default. Returns the fallback font if nothing was importable,
## which keeps the UI readable even if the asset folder is stripped.
func _load_fonts() -> void:
	var latin := _first_available(FONT_UI_LATIN_FILES)
	var arabic := _first_available(FONT_UI_ARABIC_FILES)
	if latin != null:
		# Persian text can contain Latin fragments and vice versa, so chain
		# the two subsets into one font stack: a Label never shows tofu.
		latin.fallbacks = [arabic] if arabic != null else []
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


## Wrap a display face so that any glyph it lacks (Persian, for example) is
## drawn by the UI font instead of being dropped.
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
func _add_labels(built: Theme) -> void:
	var steps := [
		{"name": &"DisplayLabel", "font": font_display, "size": FONT_DISPLAY, "color": TEXT, "spacing": -1},
		{"name": &"TitleLabel", "font": font_display, "size": FONT_H1, "color": TEXT, "spacing": -1},
		{"name": &"HeadingLabel", "font": font_heading, "size": FONT_H2, "color": TEXT, "spacing": 0},
		{"name": &"SubheadingLabel", "font": font_heading, "size": FONT_H3, "color": TEXT, "spacing": 0},
		{"name": &"SectionLabel", "font": font_label, "size": FONT_LEAD, "color": TEXT_MUTED, "spacing": 1},
		{"name": &"BodyLabel", "font": font_ui, "size": FONT_BODY, "color": TEXT, "spacing": 0},
		{"name": &"BodyMutedLabel", "font": font_ui, "size": FONT_BODY, "color": TEXT_MUTED, "spacing": 0},
		{"name": &"CaptionLabel", "font": font_ui, "size": FONT_SMALL, "color": TEXT_MUTED, "spacing": 0},
		{"name": &"MicroLabel", "font": font_label, "size": FONT_MICRO, "color": TEXT_DIM, "spacing": 0.5},
		{"name": &"ValueLabel", "font": font_display, "size": FONT_SUBHEAD, "color": TEXT, "spacing": 0},
		{"name": &"NumericLabel", "font": font_mono, "size": FONT_LEAD, "color": TEXT, "spacing": 0},
		{"name": &"AccentLabel", "font": font_label, "size": FONT_SMALL, "color": ACCENT, "spacing": 0.5},
		{"name": &"TealLabel", "font": font_label, "size": FONT_SMALL, "color": TEAL, "spacing": 0.5},
		{"name": &"DangerLabel", "font": font_label, "size": FONT_SMALL, "color": DANGER, "spacing": 0.5},
		{"name": &"SuccessLabel", "font": font_label, "size": FONT_SMALL, "color": SUCCESS, "spacing": 0.5},
		{"name": &"WarningLabel", "font": font_label, "size": FONT_SMALL, "color": WARNING, "spacing": 0.5},
	]
	for step in steps:
		var variation: StringName = step["name"]
		built.set_type_variation(variation, &"Label")
		if step["font"] != null:
			built.set_font(&"font", variation, step["font"])
		built.set_font_size(&"font_size", variation, int(step["size"]))
		built.set_color(&"font_color", variation, step["color"])
		built.set_constant(&"line_spacing", variation, int(step["spacing"]))
		built.set_constant(&"outline_size", variation, 0)


## Buttons — five levels of emphasis, each with the full interaction set.
func _add_buttons(built: Theme) -> void:
	var kinds := [
		{
			"name": &"PrimaryButton", "fill": ACCENT, "border": ACCENT_HI,
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
			"name": &"OutlineButton", "fill": Color(0, 0, 0, 0), "border": LINE_STRONG,
			"text": TEXT, "stripe": Color.TRANSPARENT,
			"hover": SURFACE_ALT, "pressed": SURFACE_HI,
		},
		{
			"name": &"DangerButton", "fill": DANGER_TINT, "border": DANGER,
			"text": DANGER, "stripe": Color.TRANSPARENT,
			"hover": DANGER, "pressed": Color("d93a58"),
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
		built.set_font_size(&"font_size", variation, FONT_BODY)
		built.set_constant(&"h_separation", variation, SPACE_SM)
		built.set_constant(&"outline_size", variation, 0)

	# Card buttons: the large selectable tiles used by the mode picker and the
	# room browser. Same interaction model as a chip, far more room for content.
	for variant in [{"name": &"CardButton", "active": false},
			{"name": &"CardButtonActive", "active": true}]:
		var card_variation: StringName = variant["name"]
		var card_active: bool = variant["active"]
		var card_fill := ACCENT_TINT if card_active else SURFACE
		var card_border := ACCENT if card_active else LINE
		built.set_type_variation(card_variation, &"Button")
		built.set_stylebox(&"normal", card_variation,
			_button_box(card_fill, card_border, Color.TRANSPARENT, RADIUS_LG, BORDER_THIN, 18, 16))
		built.set_stylebox(&"hover", card_variation,
			_button_box(card_fill, ACCENT_HI if card_active else LINE_STRONG,
				Color.TRANSPARENT, RADIUS_LG, BORDER_THIN, 18, 16))
		built.set_stylebox(&"pressed", card_variation,
			_button_box(SURFACE_HI, card_border, Color.TRANSPARENT, RADIUS_LG, BORDER_THIN, 18, 16))
		built.set_stylebox(&"focus", card_variation,
			_button_box(card_fill, TEAL, Color.TRANSPARENT, RADIUS_LG, BORDER_ACCENT, 18, 16))
		built.set_stylebox(&"disabled", card_variation,
			_button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, RADIUS_LG, BORDER_THIN, 18, 16))

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
		built.set_font_size(&"font_size", variation, FONT_BODY)
		built.set_constant(&"h_separation", variation, SPACE_MD)

	# Plain icon button: a square tap target with no chrome until hovered.
	built.set_type_variation(&"IconButton", &"Button")
	built.set_stylebox(&"normal", &"IconButton", _button_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.TRANSPARENT, RADIUS_SM, 0, 8))
	built.set_stylebox(&"hover", &"IconButton", _button_box(SURFACE_ALT, LINE, Color.TRANSPARENT, RADIUS_SM, 1, 8))
	built.set_stylebox(&"pressed", &"IconButton", _button_box(SURFACE_HI, LINE_STRONG, Color.TRANSPARENT, RADIUS_SM, 1, 8))
	built.set_stylebox(&"focus", &"IconButton", _button_box(Color(0, 0, 0, 0), TEAL, Color.TRANSPARENT, RADIUS_SM, 1, 8))
	built.set_color(&"font_color", &"IconButton", TEXT_MUTED)
	built.set_color(&"font_hover_color", &"IconButton", TEXT)


## Build a button stylebox.
##
## `stripe` and `border` are mutually exclusive on purpose: a StyleBoxFlat has
## a single border colour, so a differently-coloured edge is only achievable by
## drawing *just* that edge. When a stripe is requested the other three edges
## are suppressed, which is exactly the "accent bar on the leading side" look
## used by the nav rail.
func _button_box(
	fill: Color, border: Color, stripe: Color, radius: int,
	border_width: int, pad_x: int = 16, pad_y: int = 12, stripe_width: int = BORDER_STRIPE
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
		box.border_width_left = stripe_width
	elif border_width > 0 and border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(border_width)
	box.anti_aliasing = true
	return box


## Panels — the surfaces everything else is placed on.
func _add_panels(built: Theme) -> void:
	var panels := [
		{"name": &"CardPanel", "fill": SURFACE, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_XL},
		{"name": &"FlatPanel", "fill": Color(0, 0, 0, 0), "border": Color(0, 0, 0, 0), "radius": 0, "pad": 0},
		{"name": &"InsetPanel", "fill": SURFACE_SUNKEN, "border": LINE, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"RaisedPanel", "fill": SURFACE_ALT, "border": LINE_STRONG, "radius": RADIUS_MD, "pad": SPACE_LG},
		{"name": &"TopBarPanel", "fill": BG_RAISED, "border": LINE, "radius": 0, "pad": SPACE_LG},
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
		box.anti_aliasing = true
		if (panel["border"] as Color).a > 0.0:
			box.border_color = panel["border"]
			box.set_border_width_all(BORDER_THIN)
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
		return style

	for variation in [&"LineEdit", &"HexLineEdit"]:
		built.set_stylebox(&"normal", variation, box.call(SURFACE_SUNKEN, LINE, BORDER_THIN))
		built.set_stylebox(&"focus", variation, box.call(SURFACE_SUNKEN, ACCENT, BORDER_ACCENT))
		built.set_stylebox(&"read_only", variation, box.call(Color(1, 1, 1, 0.02), LINE, BORDER_THIN))
		built.set_stylebox(&"disabled", variation, box.call(Color(1, 1, 1, 0.02), LINE, 0))
		built.set_font(&"font", variation, font_ui)
		built.set_font_size(&"font_size", variation, FONT_BODY)
		built.set_color(&"font_color", variation, TEXT)
		built.set_color(&"font_placeholder_color", variation, TEXT_DIM)
		built.set_color(&"font_selected_color", variation, TEXT_INVERSE)
		built.set_color(&"caret_color", variation, ACCENT)
		built.set_color(&"selection_color", variation, Color(1.0, 0.478, 0.102, 0.35))
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
		built.set_font_size(&"font_size", variation, FONT_BODY)
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
		background.content_margin_top = 0.0
		background.content_margin_bottom = 0.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar["fill"]
		fill.set_corner_radius_all(RADIUS_PILL)
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
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = LINE_STRONG
		grabber.set_corner_radius_all(RADIUS_PILL)
		var grabber_hl := StyleBoxFlat.new()
		grabber_hl.bg_color = ACCENT
		grabber_hl.set_corner_radius_all(RADIUS_PILL)
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

## Accent colour for a mode, resolving through the catalog so that a mode's
## colour is defined in exactly one place (its .tres file).
func mode_accent(mode_id: StringName) -> Color:
	var mode := GameCatalog.by_id(mode_id)
	if mode == null:
		return ACCENT
	return mode.accent


func rarity_color(tier: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)]


## Colour for a ping reading, delegating to GameTypes so gameplay code and UI
## agree without either owning the other.
func ping_color(ping_ms: int) -> Color:
	return GameTypes.ping_color(GameTypes.ping_quality(ping_ms))


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
