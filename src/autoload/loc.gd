extends Node
## Localisation façade.
##
## Wraps the string tables in `src/i18n/` and adds the three things raw
## dictionaries cannot do on their own:
##
##   1. fallback         — a missing key in Persian shows English, never "key.x".
##   2. interpolation    — Loc.t("common.level_short", {"level": 12}).
##   3. direction        — `Loc.is_rtl()` drives Control.layout_direction, so
##                         screens flip correctly instead of just having
##                         right-aligned left-to-right text.
##
## Deliberately independent of Godot's TranslationServer: no import step, no
## `.import` files, nothing that can silently produce raw keys in a release
## build. See src/i18n/strings_en.gd for the full rationale.

## Locales offered by Settings ▸ Language, in display order.
## `endonym` is the language's own name, which is what users actually look for.
const LOCALES: Array[Dictionary] = [
	{"code": "fa", "endonym": "فارسی", "english": "Persian", "rtl": true},
	{"code": "en", "endonym": "English", "english": "English", "rtl": false},
]

const FALLBACK_LOCALE := "en"

var _tables: Dictionary = {}          ## locale -> Dictionary[String, String]
var _current_locale: String = FALLBACK_LOCALE
var _rtl: bool = false
var _cache: Dictionary = {}           ## "locale|key|args" -> resolved string


func _ready() -> void:
	_tables["en"] = preload("res://src/i18n/strings_en.gd").TABLE
	_tables["fa"] = preload("res://src/i18n/strings_fa.gd").TABLE
	# Settings is autoloaded before Loc, so this is safe during boot.
	set_locale(Settings.get_string("game/language"), false)


# --------------------------------------------------------------------- public

## Translate `key`. `args` is a Dictionary of placeholder -> value, or an
## Array for positional `%s` style keys (rare; prefer named tokens).
func t(key: StringName, args: Variant = null) -> String:
	var string_key := String(key)
	var table: Dictionary = _tables.get(_current_locale, {})
	var value: Variant = table.get(string_key, null)

	if value == null and _current_locale != FALLBACK_LOCALE:
		# Fall back rather than showing a raw key to a player.
		value = (_tables.get(FALLBACK_LOCALE, {}) as Dictionary).get(string_key, null)

	if value == null:
		# Missing in every locale: a bug, not a translation gap. Surface it in
		# the debugger and in the UI so it gets noticed before a release.
		if OS.is_debug_build():
			push_warning("Loc: missing key '%s'" % string_key)
			return "!%s!" % string_key
		return string_key

	var result := String(value)
	if args is Dictionary and not (args as Dictionary).is_empty():
		for placeholder: String in (args as Dictionary):
			result = result.replace("{%s}" % placeholder, str((args as Dictionary)[placeholder]))
	elif args is Array and not (args as Array).is_empty():
		result = result % (args as Array)
	return result


## Convenience for the very common `{name}` / `{count}` shapes.
func tn(key: StringName, name: String, value: Variant) -> String:
	return t(key, {name: value})


## Locale code currently in effect, e.g. "fa".
func locale() -> String:
	return _current_locale


## True when the active locale must be laid out right-to-left.
func is_rtl() -> bool:
	return _rtl


## Control.layout_direction value matching the active locale.
func layout_direction() -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_RTL if _rtl else Control.LAYOUT_DIRECTION_LTR


## Switch locale. `persist` writes the choice to Settings (skip it during boot
## so we do not rewrite the config file on every launch).
func set_locale(code: String, persist: bool = true) -> void:
	var resolved := code
	if not _tables.has(resolved):
		push_warning("Loc: unsupported locale '%s', using '%s'." % [code, FALLBACK_LOCALE])
		resolved = FALLBACK_LOCALE
	if resolved == _current_locale and _cache.is_empty() == false:
		# Still re-apply direction: the first call during boot lands here.
		_rtl = _locale_is_rtl(resolved)
	if persist:
		Settings.set_value("game/language", resolved)

	_current_locale = resolved
	_rtl = _locale_is_rtl(resolved)
	_cache.clear()

	# Keep Godot's own machinery (file dialogs, OS text input) in sync even
	# though we do not use it for our own strings.
	TranslationServer.set_locale(_godot_locale(resolved))

	EventBus.language_changed.emit(resolved)


func _locale_is_rtl(code: String) -> bool:
	for entry in LOCALES:
		if entry["code"] == code:
			return bool(entry["rtl"])
	return false


## Godot's locale for a UI language. Persian is `fa`; a region-less tag is
## correct here because our strings are not region specific.
func _godot_locale(code: String) -> String:
	match code:
		"fa": return "fa"
		"en": return "en"
		_: return code


## Localised name of a locale, shown in its own script.
func locale_name(code: String) -> String:
	for entry in LOCALES:
		if entry["code"] == code:
			return String(entry["endonym"])
	return code


func has_key(key: StringName) -> bool:
	var string_key := String(key)
	return (_tables.get(_current_locale, {}) as Dictionary).has(string_key) \
		or (_tables.get(FALLBACK_LOCALE, {}) as Dictionary).has(string_key)


## Key count for a locale — used by tools and by the debug overlay.
func key_count(code: String = "") -> int:
	var target := code if not code.is_empty() else _current_locale
	return (_tables.get(target, {}) as Dictionary).size()
