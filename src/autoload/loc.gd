extends Node
## English-only string-table façade. Keeping the tiny interpolation API lets
## screens share one source for labels without exposing a language selector.

const FALLBACK_LOCALE := "en"
const LOCALES: Array[Dictionary] = [
	{"code": "en", "endonym": "English", "english": "English", "rtl": false},
]

var _table: Dictionary = {}
var _current_locale := FALLBACK_LOCALE


func _ready() -> void:
	_table = preload("res://src/i18n/strings_en.gd").TABLE
	set_locale(Settings.get_string("game/language", FALLBACK_LOCALE), true)
	TranslationServer.set_locale(FALLBACK_LOCALE)


## Translate a key and replace named interpolation values.
func t(key: StringName, args: Variant = null) -> String:
	var string_key := String(key)
	var value: Variant = _table.get(string_key, null)
	if value == null:
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


func tn(key: StringName, name: String, value: Variant) -> String:
	return t(key, {name: value})


func locale() -> String:
	return _current_locale


func layout_direction() -> Control.LayoutDirection:
	return Control.LAYOUT_DIRECTION_LTR


## Kept for settings/config compatibility; all unsupported locale values fall
## back to English. No other locale is loaded or exposed in the interface.
func set_locale(code: String, persist: bool = true) -> void:
	if code != FALLBACK_LOCALE:
		push_warning("Loc: unsupported locale '%s'; PixelLegends uses English." % code)
	if persist:
		Settings.set_value("game/language", FALLBACK_LOCALE)
	if _current_locale == FALLBACK_LOCALE:
		return
	_current_locale = FALLBACK_LOCALE
	TranslationServer.set_locale(FALLBACK_LOCALE)
	EventBus.language_changed.emit(FALLBACK_LOCALE)


func locale_name(code: String) -> String:
	return "English" if code == FALLBACK_LOCALE else code


func has_key(key: StringName) -> bool:
	return _table.has(String(key))


func key_count(_code: String = "") -> int:
	return _table.size()
