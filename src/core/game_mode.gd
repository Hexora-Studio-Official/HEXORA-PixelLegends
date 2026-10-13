class_name GameMode
extends Resource
## Legacy shooter-era mode/ruleset schema retained in the source tree.
## Its Battle Royale, FFA, round, and loadout fields are not the data model for
## the PixelLegends MOBA. Do not connect these resources to the current menu or
## use their old phase labels as the roadmap. Create approved MOBA data models
## from docs/PROJECT_SPEC.txt only when their development phase is authorized.

@export var id: StringName = &""
@export var category: StringName = &"core"   ## core | battle_royale | training

@export_group("Localisation")
## Loc keys. Never store display strings in a resource — the player may
## switch language without a restart.
@export var title_key: StringName = &""
@export var short_key: StringName = &""
@export var description_key: StringName = &""
@export var rules_key: StringName = &""

@export_group("Presentation")
@export var icon_kind: StringName = &"mode_tdm"
@export var accent: Color = Color("ffd22a")
@export var sort_index: int = 0

@export_group("Lobby")
@export var min_players: int = 2
@export var max_players: int = 12
@export var teams: int = 0            ## 0 = free for all
@export var team_size: int = 0        ## players per team, 0 when teams == 0
@export var supports_bots: bool = true

@export_group("Rules")
@export var score_limit: int = 50
@export var time_limit_sec: float = 600.0
@export var round_based: bool = false
@export var rounds_to_win: int = 7
@export var round_time_sec: float = 120.0
@export var respawn_enabled: bool = true
@export var respawn_delay: float = 5.0
@export var friendly_fire: bool = false
@export var warmup_sec: float = 20.0
@export var revive_enabled: bool = false
@export var loadout_editable_ingame: bool = false

@export_group("Battle Royale")
@export var is_battle_royale: bool = false
@export var squad_size: int = 1
@export var zone_phases: int = 0
@export var loot_tier: int = 1        ## 1..3, raises loot density and quality
@export var drop_from_plane: bool = false

@export_group("Availability")
@export var in_matchmaking: bool = true   ## appears in the random queue pool
@export var ranked: bool = true           ## awards / consumes rank points
@export var supports_lan: bool = true     ## playable in a hotspot room
@export var max_squad: int = 1            ## party size allowed at queue time


## Total bodies in the lobby when every seat is filled.
func lobby_capacity() -> int:
	if teams > 0 and team_size > 0:
		return teams * team_size
	return max_players


## "6v6", "Solo(100)", "2v2" — a compact tag for mode chips.
func format_tag() -> String:
	if is_battle_royale:
		if squad_size <= 1:
			return "SOLO %d" % max_players
		return "SQUAD %d" % max_players
	if teams > 0 and team_size > 0:
		return "%dv%d" % [team_size, team_size]
	return "FFA %d" % max_players


## Legacy map rotation for the earlier mode/lobby prototype; not a PixelLegends
## MOBA map definition.
func map_pool() -> PackedStringArray:
	if is_battle_royale:
		return PackedStringArray(["island_kestrel", "island_vortex"])
	if round_based:
		return PackedStringArray(["foundry", "switchyard", "meridian"])
	return PackedStringArray(["foundry", "meridian", "switchyard", "atrium"])


## Ruleset handed to the authoritative match. A Dictionary rather than a
## Resource because it is going to cross the network as JSON.
func to_rules() -> Dictionary:
	return {
		"mode_id": id,
		"score_limit": score_limit,
		"time_limit_sec": time_limit_sec,
		"round_based": round_based,
		"rounds_to_win": rounds_to_win,
		"round_time_sec": round_time_sec,
		"respawn_enabled": respawn_enabled,
		"respawn_delay": respawn_delay,
		"friendly_fire": friendly_fire,
		"warmup_sec": warmup_sec,
		"revive_enabled": revive_enabled,
		"teams": teams,
		"team_size": team_size,
		"is_battle_royale": is_battle_royale,
		"squad_size": squad_size,
		"zone_phases": zone_phases,
		"loot_tier": loot_tier,
		"drop_from_plane": drop_from_plane,
	}
