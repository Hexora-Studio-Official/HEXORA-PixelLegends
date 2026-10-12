class_name GameCatalog
extends RefCounted
## Static index over the `GameMode` resources in `src/core/game_modes/`.
##
## The paths are preloaded explicitly rather than discovered with DirAccess:
## directory listing inside an exported `.pck` is fragile, and an explicit
## list means the build fails loudly (at parse time) if a mode file is
## renamed instead of failing silently at runtime.

const MODES: Array = [
	preload("res://src/core/game_modes/tdm.tres"),
	preload("res://src/core/game_modes/snd.tres"),
	preload("res://src/core/game_modes/ffa.tres"),
	preload("res://src/core/game_modes/gunfight.tres"),
	preload("res://src/core/game_modes/br30.tres"),
	preload("res://src/core/game_modes/br50.tres"),
	preload("res://src/core/game_modes/br100.tres"),
	preload("res://src/core/game_modes/training.tres"),
]

const FALLBACK_ID: StringName = &"tdm"


static func all() -> Array[GameMode]:
	var result: Array[GameMode] = []
	for mode in MODES:
		result.append(mode as GameMode)
	return result


static func by_id(mode_id: StringName) -> GameMode:
	for mode in MODES:
		if (mode as GameMode).id == mode_id:
			return mode
	return null


## Every mode in a category, in `sort_index` order.
static func by_category(category: StringName) -> Array[GameMode]:
	var result: Array[GameMode] = []
	for mode in MODES:
		var typed := mode as GameMode
		if typed.category == category:
			result.append(typed)
	result.sort_custom(func(a: GameMode, b: GameMode) -> bool:
		return a.sort_index < b.sort_index
	)
	return result


## Modes the random queue is allowed to pick from.
static func matchmaking_pool() -> Array[GameMode]:
	var result: Array[GameMode] = []
	for mode in MODES:
		var typed := mode as GameMode
		if typed.in_matchmaking:
			result.append(typed)
	return result


## Modes playable without internet (hotspot / same-Wi-Fi rooms).
static func hotspot_pool() -> Array[GameMode]:
	var result: Array[GameMode] = []
	for mode in MODES:
		var typed := mode as GameMode
		if typed.supports_lan:
			result.append(typed)
	return result


## Category ids in the order the UI should present them.
static func categories() -> Array[StringName]:
	return [&"core", &"battle_royale", &"training"]


static func default_mode() -> GameMode:
	var mode := by_id(FALLBACK_ID)
	if mode != null:
		return mode
	return MODES[0] as GameMode


## Resolve a mode id that came from the network. Anything unknown degrades to
## a sane default instead of hard-failing a match join.
static func resolve(mode_id: StringName) -> GameMode:
	var mode := by_id(mode_id)
	if mode != null:
		return mode
	push_warning("GameCatalog: unknown mode id '%s', falling back to '%s'." % [mode_id, FALLBACK_ID])
	return default_mode()
