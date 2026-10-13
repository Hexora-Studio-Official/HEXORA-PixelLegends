extends Node
## The signed-in player: profile, local statistics and their persistence.
##
## Scope split, which matters as the backend lands:
##   * `Session` owns *local truth* — who is signed in on this device, what
##     their career numbers are, what has been unlocked locally.
##   * `Api` owns *remote truth* — what the server says.
## When they disagree, the server wins, but the game must stay playable while
## offline, so every read goes through Session's local copy.
##
## File: `user://profile.json` — deliberately JSON rather than a Resource so
## that a future backend can diff it field by field and a support engineer can
## read it in a text editor.

const PROFILE_PATH := "user://profile.json"

var profile: PlayerProfile


func _ready() -> void:
	profile = PlayerProfile.new()
	_load_local()


func has_profile() -> bool:
	return profile != null and not profile.uid.is_empty() and profile.provider != GameTypes.AuthProvider.NONE


func is_guest() -> bool:
	return profile != null and profile.is_guest


func display_name() -> String:
	if profile == null:
		return Loc.t(&"common.unknown")
	if Settings.get_bool("game/streamer_mode", false):
		# Streamer mode hides the saved player name without changing the profile.
		return "Legend-%03d" % (absi(profile.uid.hash()) % 1000)
	return profile.display_name


## Adopt a profile (after sign-in or guest creation) and persist it.
func set_profile(new_profile: PlayerProfile) -> void:
	profile = new_profile
	profile.last_login_at = int(Time.get_unix_time_from_system())
	_save_local()
	EventBus.profile_changed.emit(profile)


## Update display fields and notify the UI.
func update_profile(changes: Dictionary) -> void:
	if profile == null:
		return
	for key: String in changes:
		if profile._has_property(key):
			profile.set(key, changes[key])
	_save_local()
	EventBus.profile_changed.emit(profile)


## Wipe the local account. Used by "Delete local profile" in Settings and by a
## hard sign-out; the caller decides where to navigate afterwards.
func clear_profile() -> void:
	profile = PlayerProfile.new()
	profile.provider = GameTypes.AuthProvider.NONE
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	EventBus.profile_changed.emit(profile)


## Merge the local career numbers with a server copy, keeping the best of each
## counter. A player who grinded offline should not lose that progress when
## they finally sign in.
func merge_from_remote(remote: Dictionary) -> void:
	if profile == null:
		return
	profile.matches_played = maxi(profile.matches_played, int(remote.get("matches_played", 0)))
	profile.matches_won = maxi(profile.matches_won, int(remote.get("matches_won", 0)))
	profile.kills = maxi(profile.kills, int(remote.get("kills", 0)))
	profile.deaths = maxi(profile.deaths, int(remote.get("deaths", 0)))
	profile.xp = maxi(profile.xp, int(remote.get("xp", 0)))
	profile.level = maxi(profile.level, int(remote.get("level", 1)))
	profile.rank_points = maxi(profile.rank_points, int(remote.get("rank_points", 0)))
	profile.clan_tag = String(remote.get("clan_tag", profile.clan_tag))
	_save_local()
	EventBus.profile_changed.emit(profile)


# ------------------------------------------------------------------ progress

## Award experience and roll the level up as many times as needed.
## Returns the number of levels gained so the UI can celebrate.
func add_xp(amount: int) -> int:
	if profile == null or amount <= 0:
		return 0
	profile.xp += amount
	var gained := 0
	while profile.xp >= profile.xp_to_next_level():
		profile.xp -= profile.xp_to_next_level()
		profile.level += 1
		gained += 1
	_save_local()
	EventBus.profile_changed.emit(profile)
	return gained


func add_currency(credits: int = 0, cores: int = 0) -> void:
	if profile == null:
		return
	profile.credits = maxi(0, profile.credits + credits)
	profile.cores = maxi(0, profile.cores + cores)
	_save_local()
	EventBus.profile_changed.emit(profile)


## Legacy match-result aggregation. No current PixelLegends MOBA match scene
## calls this; fields such as headshots belong to the earlier prototype. Future
## MOBA results must use server-authoritative data per docs/PROJECT_SPEC.txt.
func record_match(summary: Dictionary) -> void:
	if profile == null:
		return
	var won := bool(summary.get("won", false))
	profile.matches_played += 1
	if won:
		profile.matches_won += 1
		profile.current_win_streak += 1
		profile.longest_win_streak = maxi(profile.longest_win_streak, profile.current_win_streak)
	else:
		profile.current_win_streak = 0
	profile.kills += int(summary.get("kills", 0))
	profile.deaths += int(summary.get("deaths", 0))
	profile.headshots += int(summary.get("headshots", 0))
	profile.damage_dealt += int(summary.get("damage", 0))
	profile.playtime_seconds += int(summary.get("duration", 0))

	var ranked := bool(summary.get("ranked", false))
	if ranked:
		var delta := int(summary.get("rank_delta", 0))
		profile.rank_points = maxi(0, profile.rank_points + delta)

	_save_local()
	EventBus.profile_changed.emit(profile)


# --------------------------------------------------------------- persistence

func _save_local() -> void:
	if profile == null:
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Session: could not write %s." % PROFILE_PATH)
		return
	file.store_string(JSON.stringify(profile.to_dict(), "\t"))
	file.close()
	EventBus.profile_persisted.emit()


func _load_local() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("Session: %s is not readable JSON, starting fresh." % PROFILE_PATH)
		return
	profile = PlayerProfile.from_dict(parsed as Dictionary)


func profile_path_for_support() -> String:
	return ProjectSettings.globalize_path(PROFILE_PATH)
