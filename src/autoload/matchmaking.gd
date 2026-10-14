extends Node
## Legacy matchmaking prototype retained from the earlier shooter project.
## It is not connected to the current PixelLegends menu and is not the MOBA
## matchmaking architecture. Do not expose its simulated/offline queue or
## connect it to a placeholder. Future match services must follow
## docs/PROJECT_SPEC.txt and be implemented only in the approved phase.

const TICK_INTERVAL_SEC := 0.5
## Roughly how long each mode takes to fill at peak hours, in seconds. Used for
## the estimate and, when offline, as the basis for the local search.
const BASE_WAIT_SEC := {
	&"tdm": 12.0,
	&"snd": 16.0,
	&"ffa": 13.0,
	&"gunfight": 10.0,
	&"br30": 20.0,
	&"br50": 27.0,
	&"br100": 38.0,
	&"training": 6.0,
}
## How far the real wait may drift from the estimate, as a fraction.
const SPREAD := 0.45
## Local searches never take longer than this. A demo that makes you wait 90
## seconds to see a lobby is a demo nobody watches.
const LOCAL_WAIT_CAP_SEC := 18.0
const READY_WINDOW_SEC := 12.0
const POOL_PER_SECOND := 2.4

var state: int = GameTypes.MatchmakingState.IDLE
var selected_modes: Array[StringName] = []
var region: int = GameTypes.Region.AUTO
var ranked: bool = false

## The live ticket while searching, and the lobby once found.
## {id, simulated, mode_id, map_id, region, ranked, transport, players[],
##  found_at, elapsed, estimated_wait, pool_size, expanding}
var ticket: Dictionary = {}

var _elapsed: float = 0.0
var _tick_accum: float = 0.0
var _found_at: float = -1.0
var _ready_deadline: float = 0.0
var _target_wait: float = 12.0
var _expanding: bool = false
var _poll_accum: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)


# ------------------------------------------------------------------- queries

func is_searching() -> bool:
	return state == GameTypes.MatchmakingState.SEARCHING


func is_ready_check() -> bool:
	return state == GameTypes.MatchmakingState.FOUND


func elapsed() -> float:
	return _elapsed


func estimated_wait_seconds() -> float:
	if _elapsed > 0.5 and state == GameTypes.MatchmakingState.SEARCHING:
		# The estimate improves as the search runs: it converges on the actual
		# wait instead of sitting at a static guess for a minute.
		var remaining := maxf(2.0, _target_wait - _elapsed)
		return remaining
	return _target_wait


## "~12s" / "~2m" — short enough for the queue button, honest about the fact
## that it is an estimate.
func estimated_wait_label() -> String:
	var seconds := estimated_wait_seconds()
	if seconds < 45.0:
		return "~%ds" % maxi(3, int(round(seconds / 5.0)) * 5)
	return "~%dm" % maxi(1, int(round(seconds / 60.0)))


func pool_size() -> int:
	return int(ticket.get("pool_size", 0)) * (8 if selected_modes.size() > 2 else 4)


func ready_time_left() -> float:
	if state != GameTypes.MatchmakingState.FOUND:
		return 0.0
	return maxf(0.0, _ready_deadline - Time.get_ticks_msec() / 1000.0)


func mode_summary() -> PackedStringArray:
	var names := PackedStringArray()
	var pool := selected_modes if not selected_modes.is_empty() \
		else _ids_of(GameCatalog.matchmaking_pool())
	for mode_id in pool:
		names.append(Loc.t(GameCatalog.resolve(mode_id).short_key))
	return names


static func _ids_of(modes: Array[GameMode]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for mode in modes:
		ids.append(mode.id)
	return ids


# ---------------------------------------------------------------- queue entry

## Start searching. Empty `modes` means "anything in the random pool", which is
## what the Play button on the main menu uses.
func start_queue(modes: Array[StringName], queue_region: int, is_ranked: bool) -> Dictionary:
	if state == GameTypes.MatchmakingState.SEARCHING \
			or state == GameTypes.MatchmakingState.FOUND:
		return {"ok": false, "reason": "already_searching"}

	selected_modes = modes.duplicate()
	_drop_unknown_modes()
	region = queue_region if queue_region != GameTypes.Region.AUTO else _best_region()
	ranked = is_ranked and Api.is_configured()

	if selected_modes.is_empty():
		selected_modes = _ids_of(GameCatalog.matchmaking_pool())
	var playable := _filter_playable(selected_modes)
	if playable.is_empty():
		return {"ok": false, "reason": "no_modes"}
	selected_modes = playable

	var party_size := maxi(1, Friends.party_size())
	var largest_squad := 1
	for mode_id in selected_modes:
		largest_squad = maxi(largest_squad, GameCatalog.resolve(mode_id).max_squad)
	if party_size > largest_squad:
		return {"ok": false, "reason": "party_too_large", "max_squad": largest_squad}

	_target_wait = _roll_wait(selected_modes)
	_elapsed = 0.0
	_tick_accum = 0.0
	_found_at = -1.0
	_expanding = false
	_poll_accum = 0.0
	ticket = {
		"id": "",
		"simulated": not Api.is_configured(),
		"mode_id": String(selected_modes[0]),
		"map_id": "",
		"region": region,
		"ranked": ranked,
		"transport": GameTypes.Transport.DEDICATED if Api.is_configured() \
			else GameTypes.Transport.P2P_HOST,
		"players": [],
		"found_at": 0,
		"elapsed": 0.0,
		"estimated_wait": _target_wait,
		"pool_size": 0,
	}
	_set_state(GameTypes.MatchmakingState.SEARCHING)
	set_process(true)
	EventBus.toast_requested.emit(Loc.t(&"toast.queued"), &"info")

	if Api.is_configured():
		_enqueue_remote()
	return {"ok": true, "reason": "searching", "estimated_wait": _target_wait}


## Keeps `selected_modes` honest when a mode disappeared (an update, or a
## hand-edited save) while the player sat on the Play page.
func _drop_unknown_modes() -> void:
	var cleaned: Array[StringName] = []
	for mode_id in selected_modes:
		if GameCatalog.by_id(mode_id) != null:
			cleaned.append(mode_id)
	selected_modes = cleaned


func cancel_queue() -> void:
	if state == GameTypes.MatchmakingState.IDLE:
		return
	if Api.is_configured() and not String(ticket.get("id", "")).is_empty():
		Api.cancel_ticket(String(ticket["id"]))
	_set_state(GameTypes.MatchmakingState.IDLE)
	ticket.clear()
	_elapsed = 0.0
	_found_at = -1.0
	set_process(false)
	EventBus.matchmaking_cancelled.emit()
	EventBus.toast_requested.emit(Loc.t(&"toast.queue_cancelled"), &"info")


## Legacy queue-acceptance stub. It does not start a PixelLegends MOBA match
## and is not exposed by the current menu; do not wire it to a placeholder.
func accept_match() -> void:
	if state != GameTypes.MatchmakingState.FOUND:
		return
	if Api.is_configured():
		Api.accept_match(String(ticket.get("id", "")))
	_set_state(GameTypes.MatchmakingState.CONNECTING)
	EventBus.toast_requested.emit(
		Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")}), &"info")
	_elapsed = 0.0


func decline_match() -> void:
	if state != GameTypes.MatchmakingState.FOUND:
		return
	if Api.is_configured():
		Api.decline_match(String(ticket.get("id", "")))
	_set_state(GameTypes.MatchmakingState.IDLE)
	ticket.clear()
	set_process(false)
	EventBus.matchmaking_cancelled.emit()


# ------------------------------------------------------------------ internals

func _filter_playable(modes: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	var lan_only := not Api.is_configured()
	for mode_id in modes:
		var mode := GameCatalog.by_id(mode_id)
		if mode == null or not mode.in_matchmaking:
			continue
		if lan_only and mode.max_players > RoomService.MAX_LAN_PLAYERS and mode.is_battle_royale:
			# A 100-player battle royale cannot be filled on one hotspot. Rather
			# than silently queueing for something that can never start, the mode
			# is dropped from the local pool and the UI keeps showing it as
			# "online only".
			continue
		result.append(mode_id)
	if result.is_empty() and lan_only:
		result.append(&"tdm")
	return result


func _roll_wait(modes: Array[StringName]) -> float:
	var total := 0.0
	for mode_id in modes:
		total += float(BASE_WAIT_SEC.get(mode_id, 14.0))
	var base := total / float(maxi(1, modes.size()))
	if not Api.is_configured():
		# Local search: shorter and predictable, because there is no pool to
		# wait for — the point is to exercise the flow, not to imitate a queue.
		return clampf(base * 0.55, 6.0, LOCAL_WAIT_CAP_SEC)
	var queue_penalty := 1.0 + 0.08 * float(maxi(0, Friends.party_size() - 1))
	return base * queue_penalty * _rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD)


func _best_region() -> int:
	# Legacy region preference from the earlier queue prototype. The current UI
	# has no region selector; do not use this as PixelLegends server routing.
	return Settings.get_int("game/region")


func _enqueue_remote() -> void:
	var result: Dictionary = await Api.enqueue(selected_modes, region, ranked,
		Friends.party_size())
	if not bool(result["ok"]):
		_fail_local_fallback()
		return
	var data: Dictionary = result["data"]
	ticket["id"] = String(data.get("ticket_id", data.get("id", "")))
	ticket["pool_size"] = int(data.get("pool_size", 0))
	if data.has("estimated_wait"):
		_target_wait = float(data["estimated_wait"])


## The backend is configured but unreachable (no connectivity, server down).
## Fall back to a local search rather than leaving the player in a queue that
## can never resolve, and say so.
func _fail_local_fallback() -> void:
	if state != GameTypes.MatchmakingState.SEARCHING:
		return
	ticket["simulated"] = true
	# Local simulation and LAN play are friendly-only. Never award rank for a
	# queue that fell back after the online service became unreachable.
	ranked = false
	ticket["ranked"] = false
	_target_wait = clampf(_target_wait * 0.6, 5.0, LOCAL_WAIT_CAP_SEC)
	ticket["estimated_wait"] = _target_wait
	EventBus.toast_requested.emit(Loc.t(&"toast.no_network"), &"warning")


func _process(delta: float) -> void:
	match state:
		GameTypes.MatchmakingState.SEARCHING:
			_tick_search(delta)
		GameTypes.MatchmakingState.FOUND:
			if ready_time_left() <= 0.0:
				decline_match()
				EventBus.toast_requested.emit(Loc.t(&"toast.queue_timeout"), &"warning")
		GameTypes.MatchmakingState.CONNECTING:
			pass        # awaiting the phase-2 match scene
		_:
			set_process(false)


func _tick_search(delta: float) -> void:
	_elapsed += delta
	_tick_accum += delta
	if _tick_accum < TICK_INTERVAL_SEC:
		return
	_tick_accum = 0.0
	ticket["elapsed"] = _elapsed
	ticket["pool_size"] = int(_elapsed * POOL_PER_SECOND)
	if not _expanding and _elapsed > _target_wait * 0.6:
		_expanding = true
	EventBus.matchmaking_tick.emit(_elapsed, _target_wait,
		mini(pool_size(), 999), _expanding)

	if Api.is_configured() and not String(ticket.get("id", "")).is_empty():
		_poll_remote()
		return
	if _elapsed >= _target_wait:
		_emit_local_match()


func _poll_remote() -> void:
	_poll_accum += TICK_INTERVAL_SEC
	if _poll_accum < 2.0:
		return
	_poll_accum = 0.0
	var result: Dictionary = await Api.poll_ticket(String(ticket["id"]))
	if not bool(result["ok"]):
		_fail_local_fallback()
		return
	var data: Dictionary = result["data"]
	ticket["pool_size"] = int(data.get("pool_size", ticket["pool_size"]))
	if String(data.get("state", "")) == "found" and data.has("lobby"):
		_adopt_lobby(data["lobby"] as Dictionary, false)


## Build a lobby locally. The composition is real — your party, then enough
## fills to reach the mode's team size — and every fill is flagged simulated.
func _emit_local_match() -> void:
	var mode := GameCatalog.resolve(_primary_mode())
	var players: Array = []
	for member in Friends.party:
		players.append({
			"name": String(member.get("name", "?")),
			"level": int(member.get("level", 1)),
			"is_local": bool(member.get("is_local", false)),
			"simulated": false,
			"ready": true,
		})
	if players.is_empty():
		players.append({
			"name": Session.display_name(),
			"level": Session.profile.level,
			"is_local": true,
			"simulated": false,
			"ready": true,
		})
	var target := _lobby_target(mode)
	while players.size() < target:
		players.append({
			"name": _fake_callsign(),
			"level": _rng.randi_range(3, 60),
			"is_local": false,
			"simulated": true,
			"ready": false,
		})
	ticket["players"] = players
	ticket["mode_id"] = String(mode.id)
	ticket["map_id"] = String(mode.map_pool()[_rng.randi() % mode.map_pool().size()])
	ticket["found_at"] = int(Time.get_unix_time_from_system())
	_adopt_lobby({}, true)


func _adopt_lobby(lobby: Dictionary, simulated: bool) -> void:
	_ready_deadline = Time.get_ticks_msec() / 1000.0 + READY_WINDOW_SEC
	if not lobby.is_empty():
		ticket["players"] = lobby.get("players", ticket["players"])
		ticket["mode_id"] = String(lobby.get("mode_id", ticket["mode_id"]))
		ticket["map_id"] = String(lobby.get("map_id", ticket["map_id"]))
	ticket["simulated"] = simulated
	_found_at = _elapsed
	_set_state(GameTypes.MatchmakingState.FOUND)
	set_process(true)
	if Audio.has_method("play_ui"):
		Audio.play_ui("confirm")
	EventBus.matchmaking_found.emit(ticket.duplicate(true))
	EventBus.toast_requested.emit(Loc.t(&"toast.match_ready"), &"success")


## How many bodies the lobby should show. A 100-player BR on a hotspot is not a
## thing, so the local pool is capped at what `RoomService` can actually host;
## the queue overlay says "simulated" either way.
func _lobby_target(mode: GameMode) -> int:
	if mode.teams > 0 and mode.team_size > 0:
		return mode.teams * mode.team_size
	if mode.is_battle_royale:
		return 30 if mode.max_players >= 30 else mode.max_players
	return mini(mode.max_players, 12)


func _primary_mode() -> StringName:
	# The mode that fills first is the one with the shortest expected wait.
	var best: StringName = selected_modes[0]
	var best_wait := INF
	for mode_id in selected_modes:
		var wait := float(BASE_WAIT_SEC.get(mode_id, 14.0))
		if wait < best_wait:
			best_wait = wait
			best = mode_id
	return best


func _fake_callsign() -> String:
	const PREFIX := ["Vex", "Kilo", "Ozone", "Rift", "Halcyon", "Draco", "Zenith", "Mako",
		"Quill", "Ferro", "Nyx", "Sable"]
	const SUFFIX := ["", "_77", "-IR", "X", "2K", "_09", "Prime", "Hz"]
	var name := "%s%s" % [PREFIX[_rng.randi() % PREFIX.size()],
		SUFFIX[_rng.randi() % SUFFIX.size()]]
	# Duplicate names inside one lobby look like a bug, so they are resolved
	# rather than shown twice.
	var taken := {}
	for player in ticket.get("players", []):
		taken[String(player.get("name", ""))] = true
	var attempt := 0
	while taken.has(name) and attempt < 12:
		name = "%s%d" % [name, _rng.randi_range(10, 99)]
		attempt += 1
	return name


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.matchmaking_state_changed.emit(new_state)
