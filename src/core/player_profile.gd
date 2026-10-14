class_name PlayerProfile
extends Resource
## Everything the client knows about the signed-in player.
##
## This is intentionally a plain data object: no networking, no UI, no file
## IO. `Session` owns persistence and `Api` owns the server copy. When the
## backend lands, `from_remote()` is the single place that has to learn the
## new wire format.
##
## Progression model (mirrors what the design doc describes):
##   * `xp` / `level`    — account progression, reserved for future rewards.
##   * `rank_points`     — future competitive progression data.
##   * `credits` / `cores` — legacy profile fields not exposed in this UI phase.

## Ladder tiers, lowest first. The key resolves through Loc; the matching
## entry of RANK_TIER_FLOORS is the rank points required to enter that tier.
## Both arrays are indexed by the same tier index and must stay the same length.
const RANK_TIER_KEYS: Array[StringName] = [
	&"rank.bronze", &"rank.silver", &"rank.gold", &"rank.platinum",
	&"rank.diamond", &"rank.ascendant", &"rank.hexcore",
]
const RANK_TIER_FLOORS: Array[int] = [0, 400, 800, 1250, 1800, 2500, 3300]
const RANK_TIER_CEIL: int = 5000

@export var uid: String = ""
@export var display_name: String = "Recruit"
@export var email: String = ""
@export var avatar_url: String = ""
@export var avatar_color: int = -1
@export var provider: int = GameTypes.AuthProvider.NONE
@export var clan_tag: String = ""

@export_group("Progression")
@export var level: int = 1
@export var xp: int = 0
@export var rank_points: int = 0
@export var credits: int = 2500
@export var cores: int = 120

@export_group("Career")
@export var matches_played: int = 0
@export var matches_won: int = 0
@export var kills: int = 0
@export var deaths: int = 0
@export var damage_dealt: int = 0
@export var longest_win_streak: int = 0
@export var current_win_streak: int = 0
@export var playtime_seconds: int = 0

@export_group("Account")
@export var is_guest: bool = true
@export var created_at: int = 0
@export var last_login_at: int = 0
@export var tutorial_complete: bool = false
@export var accepted_terms_version: int = 0


## XP required to leave the current level.
## Deliberately cheap early (hooked in the first hour) and steeper later.
static func xp_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 1
	# ~1.35^level growth, rounded to the nearest 50 for a tidy HUD number.
	var raw: float = 800.0 * pow(1.35, float(target_level - 2))
	return int(round(raw / 50.0) * 50)


func xp_to_next_level() -> int:
	return xp_for_level(level + 1)


## 0..1 progress through the current level.
func xp_progress() -> float:
	var needed := xp_to_next_level()
	if needed <= 0:
		return 0.0
	return clampf(float(xp) / float(needed), 0.0, 1.0)


## 0-based tier index for the current rank points.
func rank_tier_index() -> int:
	for index in range(RANK_TIER_FLOORS.size() - 1, -1, -1):
		if rank_points >= RANK_TIER_FLOORS[index]:
			return index
	return 0


## Ladder tier name for the current rank points. Keys resolve through Loc.
func rank_tier_key() -> StringName:
	return RANK_TIER_KEYS[rank_tier_index()]


## Point range of the current tier, for the progress bar under the badge.
func rank_tier_bounds() -> Vector2i:
	var index := rank_tier_index()
	var low := RANK_TIER_FLOORS[index]
	var high := RANK_TIER_FLOORS[index + 1] if index + 1 < RANK_TIER_FLOORS.size() else RANK_TIER_CEIL
	return Vector2i(low, high)


## 0..1 progress inside the current tier.
func rank_tier_progress() -> float:
	var bounds := rank_tier_bounds()
	var span := maxi(1, bounds.y - bounds.x)
	return clampf(float(rank_points - bounds.x) / float(span), 0.0, 1.0)


func kill_death_ratio() -> float:
	if deaths <= 0:
		return float(kills)
	return float(kills) / float(deaths)


func win_rate() -> float:
	if matches_played <= 0:
		return 0.0
	return float(matches_won) / float(matches_played)


## Two letter initials for the procedurally drawn avatar. Handles empty and
## single-word names, and never returns an empty string.
func initials() -> String:
	var cleaned := display_name.strip_edges()
	if cleaned.is_empty():
		return "??"
	var parts := cleaned.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	if cleaned.length() >= 2:
		return cleaned.substr(0, 2).to_upper()
	return (cleaned + "?").substr(0, 2).to_upper()


func to_dict() -> Dictionary:
	var data := {}
	for property in get_script().get_script_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			data[property["name"]] = get(property["name"])
	return data


static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile._apply_dict(data)
	return profile


## Tolerant of missing keys and of older save formats: unknown fields are
## ignored, absent fields keep their default. Never throws.
func _apply_dict(data: Dictionary) -> void:
	for key in data.keys():
		var name := String(key)
		if _has_property(name):
			var current: Variant = get(name)
			var incoming: Variant = data[key]
			# JSON round-trips turn ints into floats; coerce back.
			if current is int and incoming is float:
				incoming = int(incoming)
			if current is bool and incoming is int:
				incoming = incoming != 0
			set(name, incoming)
	# Defensive: a broken save must not produce a nameless account.
	if display_name.strip_edges().is_empty():
		display_name = "Recruit"
	if uid.is_empty():
		uid = generate_uid()


func _has_property(property_name: String) -> bool:
	for property in get_script().get_script_property_list():
		if property["name"] == property_name:
			return true
	return false


## Local-only identifier. Real accounts get their uid from the backend; this
## is what a guest profile uses so that local stats still have a key.
static func generate_uid() -> String:
	var bytes := PackedByteArray()
	bytes.resize(16)
	for index in 16:
		bytes[index] = randi() % 256
	var hex := bytes.hex_encode()
	return "local-" + hex.substr(0, 8) + "-" + hex.substr(8, 4) + "-" + hex.substr(12, 4)


static func create_guest(display_name_hint: String = "") -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.uid = generate_uid()
	profile.provider = GameTypes.AuthProvider.DEV
	profile.is_guest = true
	profile.created_at = int(Time.get_unix_time_from_system())
	profile.last_login_at = profile.created_at
	profile.display_name = display_name_hint if not display_name_hint.is_empty() else _random_player_name()
	return profile


static func _random_player_name() -> String:
	const ADJECTIVES := ["Arcane", "Crimson", "Moonlit", "Storm", "Dawn", "Frost", "Wild", "Golden"]
	const NOUNS := ["Warden", "Seer", "Ranger", "Oracle", "Phoenix", "Rider", "Mystic", "Knight"]
	return "%s%s%02d" % [
		ADJECTIVES[randi() % ADJECTIVES.size()],
		NOUNS[randi() % NOUNS.size()],
		randi() % 100,
	]
