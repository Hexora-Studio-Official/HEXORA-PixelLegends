extends Node
## PixelLegends design system — "Imperial Citadel" theme.
##
## Deep obsidian-sapphire translucent HUD surfaces paired with sovereign gold
## action accents, arcane cyan telemetry highlights, and crisp micro-pixel
## drop edges engineered specifically for high contrast over the fantasy castle
## key art (`Pixel Legends_ 5v5 Fantasy Showdown.png`).

# ------------------------------------------------------------------- palette

const BG: Color = Color("060b16")
const BG_RAISED: Color = Color("0c1628")
const SURFACE: Color = Color("101e34")
const SURFACE_ALT: Color = Color("172a46")
const SURFACE_HI: Color = Color("213a5e")
const SURFACE_SUNKEN: Color = Color("080f1d")

const LINE: Color = Color("2c4a73")
const LINE_STRONG: Color = Color("04070e")
const DROP_EDGE: Color = Color(0.01, 0.02, 0.05, 0.62)

const TEXT: Color = Color("f5f9ff")
const TEXT_MUTED: Color = Color("bccce3")
const TEXT_DIM: Color = Color("7e95b5")
const TEXT_INVERSE: Color = Color("08101c")

const ACCENT: Color = Color("f6c445")
const ACCENT_HI: Color = Color("ffe699")
const ACCENT_DEEP: Color = Color("d49217")
const TEAL: Color = Color("36d6ff")
const TEAL_DEEP: Color = Color("1398c7")

const SUCCESS: Color = Color("3be38a")
const WARNING: Color = Color("ff9f43")
const DANGER: Color = Color("ff5263")
const GOLD: Color = Color("ffd46b")
const VIOLET: Color = Color("b270ff")

const TEAM_ALPHA: Color = Color("36d6ff")
const TEAM_BRAVO: Color = Color("ff5c6c")

const ACCENT_TINT: Color = Color(0.965, 0.769, 0.271, 0.17)
const TEAL_TINT: Color = Color(0.212, 0.839, 1.0, 0.16)
const DANGER_TINT: Color = Color(1.0, 0.322, 0.388, 0.17)
const VIOLET_TINT: Color = Color(0.698, 0.439, 1.0, 0.17)
const SUCCESS_TINT: Color = Color(0.231, 0.890, 0.541, 0.16)

# Translucent HUD surfaces over key art
const GLASS_FILL: Color = Color(0.055, 0.100, 0.178, 0.88)
const GLASS_HOVER: Color = Color(0.105, 0.185, 0.305, 0.94)
const GLASS_PRESSED: Color = Color(0.040, 0.072, 0.130, 0.96)
const GLASS_EDGE: Color = Color(0.38, 0.66, 0.96, 0.52)
const GLASS_EDGE_HI: Color = Color(0.62, 0.88, 1.0, 0.92)

const GLASS_GOLD: Color = Color(0.85, 0.58, 0.11, 0.95)
const GLASS_GOLD_EDGE: Color = Color(1.0, 0.91, 0.58, 1.0)
const GLASS_GOLD_HOVER: Color = Color(0.94, 0.68, 0.18, 0.98)
const GLASS_GOLD_HOVER_EDGE: Color = Color(1.0, 0.96, 0.78, 1.0)
const GLASS_GOLD_PRESSED: Color = Color(0.66, 0.42, 0.07, 0.98)

const GLASS_PANEL: Color = Color(0.032, 0.058, 0.108, 0.86)
const GLASS_PANEL_EDGE: Color = Color(0.42, 0.70, 0.98, 0.62)
const GLASS_MODAL: Color = Color(0.028, 0.048, 0.092, 0.95)
const GLASS_MODAL_EDGE: Color = Color(0.55, 0.80, 1.0, 0.78)

const GLASS_NAV: Color = Color(0.048, 0.088, 0.156, 0.86)
const GLASS_NAV_HOVER: Color = Color(0.115, 0.245, 0.395, 0.94)
const GLASS_NAV_HOVER_EDGE: Color = Color(0.48, 0.84, 1.0, 0.90)
const GLASS_NAV_PRESSED: Color = Color(0.062, 0.148, 0.256, 0.96)

const GLASS_QUIET: Color = Color(0.052, 0.092, 0.162, 0.82)
const GLASS_QUIET_EDGE: Color = Color(0.42, 0.68, 0.96, 0.45)
const GLASS_DISABLED: Color = Color(0.045, 0.070, 0.118, 0.52)
const GLASS_DISABLED_EDGE: Color = Color(0.45, 0.62, 0.82, 0.24)

const RARITY: Array[Color] = [
	Color("8fa3bd"),
	Color("3be38a"),
	Color("36d6ff"),
	Color("b270ff"),
	Color("f6c445"),
]

# ------------------------------------------------------------------- metrics

const SPACE_XXS: int = 4
const SPACE_XS: int = 8
const SPACE_SM: int = 12
const SPACE_MD: int = 16
const SPACE_LG: int = 20
const SPACE_XL: int = 28
const SPACE_XXL: int = 36
const SPACE_HUGE: int = 48

const RADIUS_SM: int = 6
const RADIUS_MD: int = 8
const RADIUS_LG: int = 10
const RADIUS_PILL: int = 6
const TAB_RADIUS: int = 10
const RADIUS_PANEL: int = 12

const BORDER_THIN: int = 2
const BORDER_ACCENT: int = 3
const BORDER_STRIPE: int = 4
const BORDER_DROP: int = 3
const BORDER_PANEL: int = 2
const NAV_STRIPE: int = 4

const FONT_MICRO: int = 13
const FONT_SMALL: int = 15
const FONT_BODY: int = 18
const FONT_LEAD: int = 22
const FONT_SUBHEAD: int = 26
const FONT_H3: int = 31
const FONT_H2: int = 40
const FONT_H1: int = 54
const FONT_DISPLAY: int = 74

const TRACK_DISPLAY: int = -2
const TRACK_H1: int = -2
const TRACK_H2: int = -1
const TRACK_H3: int = 0
const TRACK_SECTION: int = 2
const TRACK_BODY: int = 0
const TRACK_SMALL: int = 1

const OUTLINE_HEADING: int = 5
const OUTLINE_SUB: int = 3

const TOUCH_TARGET_MIN: int = 52

# --------------------------------------------------------------------- fonts

const FONT_DIR := "res://assets/fonts/"
const FONT_DISPLAY_FILES := [
	"ChakraPetch-Bold.woff2",
	"ChakraPetch-SemiBold.woff2",
	"ChakraPetch-Medium.woff2",
]
const FONT_UI_LATIN_FILES := [
	"Vazirmatn-Latin-400.woff2",
	"Vazirmatn-Latin-500.woff2",
	"Vazirmatn-Latin-600.woff2",
	"Vazirmatn-Latin-700.woff2",
]

var theme: Theme

var font_ui: Font
var font_display: Font
var font_heading: Font
var font_label: Font
var font_mono: Font

var text_scale := 1.0


func _ready() -> void:
	_load_fonts()
	theme = _build_theme()
	var root_window := get_tree().root
	if OS.has_feature("mobile"):
		root_window.content_scale_factor = clampf(DisplayServer.screen_get_scale(), 1.6, 1.8)
	root_window.theme = theme


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


func _variation(base: FontFile, fallback: Font) -> Font:
	if base == null:
		return fallback
	var variation := FontVariation.new()
	variation.base_font = base
	if fallback != null and fallback != base:
		variation.fallbacks = [fallback]
	return variation


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


func _scaled(size: int) -> int:
	return int(round(float(size) * text_scale))


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


func _add_buttons(built: Theme) -> void:
	var kinds := [
		{
			"name": &"PrimaryButton", "fill": ACCENT, "border": ACCENT_HI,
			"text": TEXT_INVERSE, "stripe": Color.TRANSPARENT,
			"hover": ACCENT_HI, "pressed": ACCENT_DEEP,
		},
		{
			"name": &"SecondaryButton", "fill": SURFACE_ALT, "border": LINE,
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
			_button_box(kind["fill"], kind["border"], kind["stripe"], radius, 2))
		built.set_stylebox(&"hover", variation,
			_button_box(kind["hover"], kind["border"], kind["stripe"], radius, 2))
		built.set_stylebox(&"pressed", variation,
			_button_box(kind["pressed"], kind["border"], kind["stripe"], radius, 2))
		built.set_stylebox(&"disabled", variation,
			_button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, radius, 1))
		built.set_stylebox(&"focus", variation,
			_button_box(kind["fill"], TEAL, Color.TRANSPARENT, radius, BORDER_ACCENT))

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
	_register_glass_button(
		built, &"HudNavButton",
		Color(0.048, 0.092, 0.168, 0.90), Color(0.36, 0.66, 0.98, 0.55),
		Color(0.115, 0.220, 0.365, 0.96), ACCENT_HI,
		Color(0.038, 0.072, 0.132, 0.98), TEXT
	)
	_register_glass_button(
		built, &"HudCompactButton",
		Color(0.048, 0.092, 0.168, 0.90), Color(0.36, 0.66, 0.98, 0.55),
		Color(0.115, 0.220, 0.365, 0.96), ACCENT_HI,
		Color(0.038, 0.072, 0.132, 0.98), TEXT
	)
	_register_glass_button(
		built, &"HudLobbyButton",
		Color(0.055, 0.195, 0.305, 0.94), TEAL,
		Color(0.085, 0.275, 0.415, 0.98), Color("9beeff"),
		Color(0.040, 0.135, 0.215, 0.98), TEXT
	)
	_register_glass_button(
		built, &"HudPlayButton",
		Color(0.88, 0.60, 0.10, 0.97), ACCENT_HI,
		Color(0.96, 0.70, 0.18, 1.0), Color("fff4c2"),
		Color(0.70, 0.45, 0.06, 0.99), TEXT_INVERSE
	)
	_register_glass_button(
		built, &"DangerPillButton",
		DANGER_TINT, DANGER,
		DANGER, DANGER, Color("d92b40"), DANGER
	)

	for tab in [{"name": &"SettingsTab", "active": false},
			{"name": &"SettingsTabActive", "active": true}]:
		var tab_name: StringName = tab["name"]
		var tab_on: bool = tab["active"]
		var tab_fill := ACCENT_TINT if tab_on else GLASS_FILL
		var tab_edge := ACCENT if tab_on else GLASS_EDGE
		var tab_text := ACCENT_HI if tab_on else TEXT_MUTED
		built.set_type_variation(tab_name, &"Button")
		built.set_stylebox(&"normal", tab_name,
			_glass_box(tab_fill, tab_edge, TAB_RADIUS, 16, 8, 0))
		built.set_stylebox(&"hover", tab_name,
			_glass_box(GLASS_HOVER, GLASS_EDGE_HI, TAB_RADIUS, 16, 8, 6))
		built.set_stylebox(&"pressed", tab_name,
			_glass_box(GLASS_PRESSED, tab_edge, TAB_RADIUS, 16, 8, 2))
		built.set_stylebox(&"focus", tab_name,
			_glass_box(tab_fill, TEAL, TAB_RADIUS, 16, 8, 6))
		built.set_stylebox(&"disabled", tab_name,
			_glass_box(GLASS_DISABLED, GLASS_DISABLED_EDGE, TAB_RADIUS, 16, 8, 0))
		built.set_color(&"font_color", tab_name, tab_text)
		built.set_color(&"font_hover_color", tab_name, ACCENT_HI)
		built.set_color(&"font_pressed_color", tab_name, TEXT)
		built.set_color(&"font_focus_color", tab_name, tab_text)
		built.set_color(&"font_disabled_color", tab_name, TEXT_DIM)
		built.set_font(&"font", tab_name, font_label)
		built.set_font_size(&"font_size", tab_name, _scaled(FONT_SMALL))
		built.set_constant(&"h_separation", tab_name, SPACE_SM)
		built.set_constant(&"outline_size", tab_name, 0)

	built.set_type_variation(&"GlassNavButton", &"Button")
	built.set_stylebox(&"normal", &"GlassNavButton",
		_glass_box(GLASS_NAV, Color.TRANSPARENT, 10, 16, 12, 4, TEAL))
	built.set_stylebox(&"hover", &"GlassNavButton",
		_glass_box(GLASS_NAV_HOVER, Color.TRANSPARENT, 10, 16, 12, 8, ACCENT))
	built.set_stylebox(&"pressed", &"GlassNavButton",
		_glass_box(GLASS_NAV_PRESSED, Color.TRANSPARENT, 10, 16, 12, 2, ACCENT_HI))
	built.set_stylebox(&"focus", &"GlassNavButton",
		_glass_box(GLASS_NAV_HOVER, Color.TRANSPARENT, 10, 16, 12, 6, ACCENT_HI))
	built.set_stylebox(&"disabled", &"GlassNavButton",
		_glass_box(GLASS_DISABLED, Color.TRANSPARENT, 10, 16, 12, 0, Color.TRANSPARENT))
	built.set_color(&"font_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_hover_color", &"GlassNavButton", ACCENT_HI)
	built.set_color(&"font_pressed_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_focus_color", &"GlassNavButton", TEXT)
	built.set_color(&"font_disabled_color", &"GlassNavButton", TEXT_DIM)
	built.set_font(&"font", &"GlassNavButton", font_label)
	built.set_font_size(&"font_size", &"GlassNavButton", _scaled(FONT_SMALL))
	built.set_constant(&"h_separation", &"GlassNavButton", SPACE_SM)
	built.set_constant(&"outline_size", &"GlassNavButton", 0)

	for state in [{"name": &"ChipButton", "active": false}, {"name": &"ChipButtonActive", "active": true}]:
		var variation: StringName = state["name"]
		built.set_type_variation(variation, &"Button")
		var active: bool = state["active"]
		var fill := ACCENT_TINT if active else SURFACE_ALT
		var border := ACCENT if active else LINE
		built.set_stylebox(&"normal", variation, _button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, 2, 12, 6))
		built.set_stylebox(&"hover", variation,
			_button_box(ACCENT_TINT if not active else fill, ACCENT_HI,
				Color.TRANSPARENT, RADIUS_SM, 2, 12, 6))
		built.set_stylebox(&"pressed", variation, _button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, 2, 12, 6))
		built.set_stylebox(&"focus", variation, _button_box(fill, TEAL, Color.TRANSPARENT, RADIUS_SM, BORDER_ACCENT, 12, 6))
		built.set_stylebox(&"disabled", variation, _button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, RADIUS_SM, 1, 12, 6))
		built.set_color(&"font_color", variation, ACCENT_HI if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, ACCENT_HI)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, _scaled(FONT_SMALL))
		built.set_constant(&"h_separation", variation, SPACE_XS)

	for state in [{"name": &"RegionChipButton", "active": false},
			{"name": &"RegionChipButtonActive", "active": true}]:
		var variation: StringName = state["name"]
		var active: bool = state["active"]
		var fill := ACCENT_TINT if active else SURFACE_ALT
		var border := ACCENT if active else LINE
		built.set_type_variation(variation, &"Button")
		built.set_stylebox(&"normal", variation,
			_button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 6, 4))
		built.set_stylebox(&"hover", variation,
			_button_box(ACCENT_TINT if not active else fill, ACCENT_HI,
				Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 6, 4))
		built.set_stylebox(&"pressed", variation,
			_button_box(fill, border, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, 6, 4))
		built.set_stylebox(&"focus", variation,
			_button_box(fill, TEAL, Color.TRANSPARENT, RADIUS_SM, BORDER_ACCENT, 6, 4))
		built.set_stylebox(&"disabled", variation,
			_button_box(Color(1, 1, 1, 0.03), LINE, Color.TRANSPARENT, RADIUS_SM, 1, 6, 4))
		built.set_color(&"font_color", variation, ACCENT_HI if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, ACCENT_HI)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_color(&"font_disabled_color", variation, TEXT_DIM)
		built.set_font(&"font", variation, font_ui)
		built.set_font_size(&"font_size", variation, _scaled(FONT_MICRO))

	for state in [{"name": &"CardButton", "active": false},
			{"name": &"CardButtonActive", "active": true}]:
		var card_variation: StringName = state["name"]
		built.set_type_variation(card_variation, &"Button")
		var card_active: bool = state["active"]
		var card_fill: Color = ACCENT_TINT if card_active else SURFACE
		var card_border: Color = ACCENT if card_active else LINE
		built.set_stylebox(&"normal", card_variation,
			_button_box(card_fill, card_border, Color.TRANSPARENT, RADIUS_LG, 2, 16, 14))
		built.set_stylebox(&"hover", card_variation, _button_box(
			ACCENT_TINT if card_active else SURFACE_ALT,
			ACCENT_HI, Color.TRANSPARENT, RADIUS_LG, 2, 16, 14))
		built.set_stylebox(&"pressed", card_variation,
			_button_box(SURFACE_HI, card_border, Color.TRANSPARENT, RADIUS_LG, 2, 16, 14))
		built.set_stylebox(&"focus", card_variation,
			_button_box(card_fill, TEAL, Color.TRANSPARENT, RADIUS_LG, BORDER_ACCENT, 16, 14))
		built.set_stylebox(&"disabled", card_variation,
			_button_box(Color(1, 1, 1, 0.02), LINE, Color.TRANSPARENT, RADIUS_LG, 1, 16, 14))

	for variant in [{"name": &"NavButton", "active": false}, {"name": &"NavButtonActive", "active": true}]:
		var variation: StringName = variant["name"]
		built.set_type_variation(variation, &"Button")
		var active: bool = variant["active"]
		var fill := SURFACE_ALT if active else Color(0, 0, 0, 0)
		var stripe := ACCENT if active else Color.TRANSPARENT
		built.set_stylebox(&"normal", variation, _button_box(fill, Color(0, 0, 0, 0), stripe, RADIUS_SM, 0, 14, 10, 2))
		built.set_stylebox(&"hover", variation, _button_box(SURFACE_ALT, Color(0, 0, 0, 0), ACCENT_HI, RADIUS_SM, 0, 14, 10, 2))
		built.set_stylebox(&"pressed", variation, _button_box(SURFACE_HI, Color(0, 0, 0, 0), stripe, RADIUS_SM, 0, 14, 10, 2))
		built.set_stylebox(&"focus", variation, _button_box(fill, TEAL, Color.TRANSPARENT, RADIUS_SM, 2, 14, 10, 2))
		built.set_color(&"font_color", variation, TEXT if active else TEXT_MUTED)
		built.set_color(&"font_hover_color", variation, TEXT)
		built.set_color(&"font_pressed_color", variation, TEXT)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
		built.set_constant(&"h_separation", variation, SPACE_MD)

	built.set_type_variation(&"IconButton", &"Button")
	built.set_stylebox(&"normal", &"IconButton",
		_glass_box(GLASS_QUIET, GLASS_QUIET_EDGE, 10, 8, 8, 4))
	built.set_stylebox(&"hover", &"IconButton",
		_glass_box(GLASS_HOVER, GLASS_EDGE_HI, 10, 8, 8, 8))
	built.set_stylebox(&"pressed", &"IconButton",
		_glass_box(GLASS_PRESSED, GLASS_EDGE_HI, 10, 8, 8, 2))
	built.set_stylebox(&"focus", &"IconButton",
		_glass_box(GLASS_QUIET, GLASS_EDGE_HI, 10, 8, 8, 6))
	built.set_stylebox(&"disabled", &"IconButton",
		_glass_box(GLASS_DISABLED, GLASS_DISABLED_EDGE, 10, 8, 8, 0))
	built.set_color(&"font_color", &"IconButton", TEXT_MUTED)
	built.set_color(&"font_hover_color", &"IconButton", TEXT)
	built.set_color(&"font_pressed_color", &"IconButton", TEXT)
	built.set_color(&"font_disabled_color", &"IconButton", TEXT_DIM)


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
	box.anti_aliasing = true
	return box


func _apply_drop_edge(box: StyleBoxFlat, thickness: int) -> void:
	if thickness <= 0:
		return
	box.shadow_color = DROP_EDGE
	box.shadow_size = 2
	box.shadow_offset = Vector2(0.0, float(thickness))


func _glass_box(
	fill: Color, edge: Color, radius: int, pad_x: int = 16, pad_y: int = 12,
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
	var radius := 10
	built.set_type_variation(variation, &"Button")
	built.set_stylebox(&"normal", variation,
		_glass_box(fill, edge, radius, 16, 12, 8))
	built.set_stylebox(&"hover", variation,
		_glass_box(hover_fill, hover_edge, radius, 16, 12, 12))
	built.set_stylebox(&"pressed", variation,
		_glass_box(pressed_fill, hover_edge, radius, 16, 12, 4))
	built.set_stylebox(&"focus", variation,
		_glass_box(fill, GLASS_EDGE_HI, radius, 16, 12, 8))
	built.set_stylebox(&"disabled", variation,
		_glass_box(GLASS_DISABLED, GLASS_DISABLED_EDGE, radius, 16, 12, 0))
	built.set_color(&"font_color", variation, text_color)
	built.set_color(&"font_hover_color", variation, text_color if text_color == TEXT_INVERSE else TEXT)
	built.set_color(&"font_pressed_color", variation, text_color)
	built.set_color(&"font_focus_color", variation, text_color)
	built.set_color(&"font_disabled_color", variation, Color(TEXT.r, TEXT.g, TEXT.b, 0.52))
	built.set_font(&"font", variation, font_label)
	built.set_font_size(&"font_size", variation, _scaled(FONT_BODY))
	built.set_constant(&"h_separation", variation, SPACE_SM)
	built.set_constant(&"outline_size", variation, 0)


func _add_panels(built: Theme) -> void:
	var panels := [
		{"name": &"CardPanel", "fill": SURFACE, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_LG},
		{"name": &"SetupCardPanel", "fill": SURFACE, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_SM},
		{"name": &"FlatPanel", "fill": Color(0, 0, 0, 0), "border": Color(0, 0, 0, 0), "radius": 0, "pad": 0},
		{"name": &"InsetPanel", "fill": SURFACE_SUNKEN, "border": LINE, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"RaisedPanel", "fill": SURFACE_ALT, "border": LINE, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"TopBarPanel", "fill": BG_RAISED, "border": LINE, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"ActionDockPanel", "fill": BG_RAISED, "border": LINE, "radius": RADIUS_LG, "pad": SPACE_SM},
		{
			"name": &"EntranceDockPanel",
			"fill": GLASS_PANEL, "border": GLASS_PANEL_EDGE,
			"radius": RADIUS_PANEL, "pad": SPACE_MD,
		},
		{
			"name": &"HudBarPanel",
			"fill": Color(0.030, 0.056, 0.104, 0.90), "border": Color(0.42, 0.72, 1.0, 0.58),
			"radius": RADIUS_LG, "pad": SPACE_SM,
		},
		{
			"name": &"HudPillPanel",
			"fill": Color(0.036, 0.068, 0.126, 0.88), "border": Color(0.42, 0.72, 1.0, 0.48),
			"radius": RADIUS_MD, "pad": SPACE_XS,
		},
		{
			"name": &"HudWindowPanel",
			"fill": Color(0.026, 0.048, 0.092, 0.96), "border": Color(0.56, 0.82, 1.0, 0.76),
			"radius": RADIUS_PANEL, "pad": SPACE_LG,
		},
		{
			"name": &"HudCardPanel",
			"fill": Color(0.068, 0.122, 0.212, 0.94), "border": Color(0.28, 0.48, 0.74, 0.65),
			"radius": RADIUS_MD, "pad": SPACE_MD,
		},
		{
			"name": &"HudCardActivePanel",
			"fill": Color(0.145, 0.168, 0.215, 0.96), "border": ACCENT,
			"radius": RADIUS_MD, "pad": SPACE_MD,
		},
		{
			"name": &"GlassModalPanel",
			"fill": GLASS_MODAL, "border": GLASS_MODAL_EDGE,
			"radius": RADIUS_PANEL, "pad": SPACE_XL,
		},
		{"name": &"BannerPanel", "fill": ACCENT_TINT, "border": ACCENT, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"InfoPanel", "fill": TEAL_TINT, "border": TEAL, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"WarnPanel", "fill": DANGER_TINT, "border": DANGER, "radius": RADIUS_MD, "pad": SPACE_MD},
		{"name": &"ChipPanel", "fill": SURFACE_ALT, "border": LINE, "radius": RADIUS_SM, "pad": SPACE_XS},
		{"name": &"AccentChipPanel", "fill": ACCENT_TINT, "border": ACCENT, "radius": RADIUS_SM, "pad": SPACE_XS},
		{"name": &"TealChipPanel", "fill": TEAL_TINT, "border": TEAL, "radius": RADIUS_SM, "pad": SPACE_XS},
		{"name": &"VioletChipPanel", "fill": VIOLET_TINT, "border": VIOLET, "radius": RADIUS_SM, "pad": SPACE_XS},
		{"name": &"SuccessChipPanel", "fill": SUCCESS_TINT, "border": SUCCESS, "radius": RADIUS_SM, "pad": SPACE_XS},
	]
	for panel in panels:
		var variation: StringName = panel["name"]
		built.set_type_variation(variation, &"PanelContainer")
		var box := StyleBoxFlat.new()
		box.bg_color = panel["fill"]
		box.set_corner_radius_all(int(panel["radius"]))
		box.set_content_margin_all(float(panel["pad"]))
		box.anti_aliasing = true
		var fill: Color = panel["fill"]
		if (panel["border"] as Color).a > 0.0:
			box.border_color = panel["border"]
			box.set_border_width_all(BORDER_PANEL)
		if variation in [&"EntranceDockPanel", &"GlassModalPanel", &"HudWindowPanel", &"HudBarPanel"]:
			box.shadow_color = DROP_EDGE
			box.shadow_size = 18
			box.shadow_offset = Vector2(0.0, 6.0)
		elif fill.a > 0.0:
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
		style.content_margin_top = float(SPACE_SM)
		style.content_margin_bottom = float(SPACE_SM)
		if width > 0:
			style.border_color = border
			style.set_border_width_all(width)
		style.anti_aliasing = true
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

	built.set_type_variation(&"HexSlider", &"HSlider")
	for state in [{"name": &"slider", "fill": SURFACE_SUNKEN}, {"name": &"grabber_area", "fill": ACCENT},
			{"name": &"grabber_area_highlight", "fill": ACCENT_HI}]:
		var style := StyleBoxFlat.new()
		style.bg_color = state["fill"]
		style.set_corner_radius_all(RADIUS_PILL)
		style.anti_aliasing = true
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
		background.anti_aliasing = true
		background.content_margin_top = 0.0
		background.content_margin_bottom = 0.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = bar["fill"]
		fill.set_corner_radius_all(RADIUS_PILL)
		fill.anti_aliasing = true
		built.set_stylebox(&"background", variation, background)
		built.set_stylebox(&"fill", variation, fill)
		built.set_font(&"font", variation, font_label)
		built.set_font_size(&"font_size", variation, FONT_MICRO)
		built.set_color(&"font_color", variation, TEXT)
		built.set_color(&"font_outline_color", variation, BG)
		built.set_constant(&"outline_size", variation, 3)
		built.set_constant(&"indeterminate_height", variation, int(bar["height"]))


func _add_scrollbars(built: Theme) -> void:
	for axis in [&"VScrollBar", &"HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.04)
		track.set_corner_radius_all(RADIUS_PILL)
		track.anti_aliasing = true
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.45)
		grabber.set_corner_radius_all(RADIUS_PILL)
		grabber.anti_aliasing = true
		var grabber_hl := StyleBoxFlat.new()
		grabber_hl.bg_color = ACCENT
		grabber_hl.set_corner_radius_all(RADIUS_PILL)
		grabber_hl.anti_aliasing = true
		built.set_stylebox(&"scroll", axis, track)
		built.set_stylebox(&"grabber", axis, grabber)
		built.set_stylebox(&"grabber_highlight", axis, grabber_hl)
		built.set_stylebox(&"grabber_pressed", axis, grabber_hl)
	built.set_type_variation(&"HexScrollContainer", &"ScrollContainer")
	built.set_stylebox(&"panel", &"HexScrollContainer", StyleBoxEmpty.new())

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
	for popup in [&"PopupMenu", &"PopupPanel"]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = SURFACE_ALT
		panel.set_corner_radius_all(RADIUS_MD)
		panel.set_content_margin_all(float(SPACE_XS))
		panel.border_color = LINE_STRONG
		panel.set_border_width_all(BORDER_THIN)
		panel.anti_aliasing = true
		built.set_stylebox(&"panel", popup, panel)
		built.set_font(&"font", popup, font_ui)
		built.set_font_size(&"font_size", popup, FONT_BODY)
		built.set_color(&"font_color", popup, TEXT)
		built.set_color(&"font_hover_color", popup, TEXT_INVERSE)

	built.set_stylebox(&"panel", &"TooltipPanel",
		_button_box(SURFACE_HI, LINE, Color.TRANSPARENT, RADIUS_SM, BORDER_THIN, SPACE_MD, SPACE_SM))
	built.set_font(&"font", &"TooltipLabel", font_ui)
	built.set_font_size(&"font_size", &"TooltipLabel", FONT_SMALL)
	built.set_color(&"font_color", &"TooltipLabel", TEXT)


func rarity_color(tier: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)]


func separator(color: Color = LINE, height: int = 1) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, height)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func padded(child: Control, margin: int = SPACE_XL, top: int = -1) -> MarginContainer:
	var wrapper := MarginContainer.new()
	var top_margin := margin if top < 0 else top
	wrapper.add_theme_constant_override("margin_left", margin)
	wrapper.add_theme_constant_override("margin_right", margin)
	wrapper.add_theme_constant_override("margin_top", top_margin)
	wrapper.add_theme_constant_override("margin_bottom", margin)
	wrapper.add_child(child)
	return wrapper


func is_compact() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	var min_side := minf(size.x, size.y)
	return min_side < 720.0 or OS.has_feature("mobile")


func safe_area() -> Rect2i:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2i()
	return DisplayServer.get_display_safe_area()
