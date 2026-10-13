class_name RoomService
extends Node
## Legacy custom-room/LAN prototype retained from the earlier project.
## It is not exposed by the current PixelLegends menu and is not the approved
## MOBA lobby or dedicated-server design. Do not reactivate it through a
## placeholder. Future account, lobby, matchmaking, and match-server work must
## follow docs/PROJECT_SPEC.txt and its phase gates.

const LAN_PORT_MIN := 45720
const LAN_PORT_MAX := 45740
const MAX_LAN_PLAYERS := 8

## Sentinel used in RPC payloads; a real uid is never the empty string.
const HOST_PEER_ID := 1

var discovery: LanDiscovery

## The room this device is in, or null. Never a half-built object: it is only
## assigned once the host accepted us or our own server came up.
var room: RoomInfo = null

var _peer: ENetMultiplayerPeer = null
var _is_host: bool = false
var _pending_password: String = ""
var _pending_room: RoomInfo = null
var _roster: Dictionary = {}          ## peer_id -> player Dictionary
var _ports: Array[int] = []
var _join_timeout: float = 0.0
var _ping_timer: float = 0.0


func _ready() -> void:
	discovery = LanDiscovery.new()
	discovery.name = "LanDiscovery"
	add_child(discovery)
	discovery.rooms_changed.connect(_on_discovery_changed)
	discovery.state_changed.connect(_on_discovery_state_changed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)


# ------------------------------------------------------------------- queries

func is_in_room() -> bool:
	return room != null


func is_host() -> bool:
	return room != null and _is_host


func is_lan() -> bool:
	return room != null and room.is_lan


func roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if room == null:
		return result
	var entries: Array = room.players.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("is_host", false)) != bool(b.get("is_host", false)):
			return bool(a.get("is_host", false))
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	for entry in entries:
		result.append(entry)
	return result


## Addresses a friend could type to reach this device. Empty when we are not
## hosting or the device has no IPv4 address (no hotspot, no Wi-Fi).
func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	if not _is_host:
		return result
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127."):
			continue
		if address.split(".").size() == 4:
			result.append(address)
	return result


func advertised_port() -> int:
	return room.port if room != null else 0


## Text for the "copy invite" button. Deliberately human readable: it is going
## to arrive in a chat app next to a photo of somebody's lunch.
func invite_text() -> String:
	if room == null:
		return ""
	var mode := GameCatalog.resolve(room.mode_id)
	var lines := PackedStringArray()
	lines.append("%s — %s" % [Loc.t(&"app.name"), Loc.t(&"rooms.code") + ": " + room.code])
	lines.append(Loc.t(mode.title_key))
	if room.is_lan:
		var addresses := local_addresses()
		if not addresses.is_empty():
			lines.append("%s: %s:%d" % [Loc.t(&"rooms.hotspot.host_ip"), addresses[0], room.port])
		lines.append(Loc.t(&"rooms.hotspot.step2"))
	if room.password_protected:
		lines.append(Loc.t(&"rooms.password"))
	return "\n".join(lines)


func lan_rooms() -> Array[RoomInfo]:
	return discovery.rooms()


func is_scanning() -> bool:
	return discovery.is_scanning()


func start_scanning() -> void:
	discovery.start_scanning()


func stop_scanning() -> void:
	discovery.stop_scanning()


# ------------------------------------------------------------------- hosting

## Bring up a room. `config` is a plain Dictionary so the caller (and the
## network layer later) never has to construct a RoomInfo by hand.
func host_room(config: Dictionary) -> RoomInfo:
	if is_in_room():
		leave_room()

	var mode := GameCatalog.resolve(StringName(config.get("mode_id", &"tdm")))
	var capacity := int(config.get("max_players", min(mode.lobby_capacity(), MAX_LAN_PLAYERS)))
	capacity = clampi(capacity, 2, MAX_LAN_PLAYERS)

	var created := RoomInfo.new()
	created.code = RoomInfo.generate_code()
	created.name = String(config.get("name", "")).strip_edges()
	if created.name.is_empty():
		created.name = "%s · %s" % [Session.display_name(), Loc.t(mode.short_key)]
	created.host_name = Session.display_name()
	created.mode_id = mode.id
	created.map_id = StringName(mode.map_pool()[0])
	created.region = Settings.get_int("game/region")
	created.visibility = int(config.get("visibility", GameTypes.RoomVisibility.PRIVATE))
	created.max_players = capacity
	created.squad_size = mode.squad_size
	created.is_lan = bool(config.get("local_only", true))
	# A local friend room is always casual/unranked, regardless of a caller's
	# configuration. Competitive results must come from the dedicated server.
	created.ranked = bool(config.get("ranked", false)) and mode.ranked and not created.is_lan
	created.transport = GameTypes.Transport.LAN_HOTSPOT if created.is_lan \
		else GameTypes.Transport.P2P_HOST
	created.state = GameTypes.RoomState.FORMING
	created.created_at = int(Time.get_unix_time_from_system())

	var password := String(config.get("password", "")).strip_edges()
	created.password_protected = not password.is_empty()
	created.password_hash = RoomInfo.hash_password(password)

	var port := _open_server(created)
	if port <= 0:
		EventBus.toast_requested.emit(Loc.t(&"toast.host_failed"), &"error")
		return null

	room = created
	_is_host = true
	_roster.clear()
	_roster[HOST_PEER_ID] = _local_entry(true)
	_sync_room_from_roster()
	discovery.start_advertising(room)
	set_process(true)
	_join_timeout = 0.0

	EventBus.room_created.emit(room)
	EventBus.room_updated.emit(room)
	EventBus.toast_requested.emit(
		Loc.t(&"toast.room_created", {"code": room.code}), &"success")
	return room


func close_room(reason: String = "host_closed") -> void:
	if room == null:
		return
	discovery.stop_advertising()
	_teardown_peer()
	var closed_code := room.code
	room = null
	_is_host = false
	_roster.clear()
	EventBus.room_closed.emit(reason)
	EventBus.toast_requested.emit(
		Loc.t(&"toast.room_closed", {"code": closed_code}), &"info")


func leave_room() -> void:
	if room == null:
		return
	if _is_host:
		close_room("host_left")
		return
	_teardown_peer()
	room = null
	_is_host = false
	_roster.clear()
	EventBus.room_closed.emit("left")
	EventBus.toast_requested.emit(Loc.t(&"toast.room_left"), &"info")


## Host-side kick. The removed peer is told why before the socket closes, so
## their UI can say "the host removed you" instead of "connection lost".
func kick_peer(peer_id: int) -> void:
	if not _is_host or peer_id == HOST_PEER_ID:
		return
	if _roster.has(peer_id):
		_rpc_kicked.rpc_id(peer_id, "kicked")
	_peer.disconnect_peer(peer_id)
	_roster.erase(peer_id)
	_broadcast_roster()


# -------------------------------------------------------------------- joining

## Join a room seen on the local network.
func join_lan(target: RoomInfo, password: String = "") -> bool:
	if target == null or target.address.is_empty() or target.port <= 0:
		return false
	if target.is_full() and not _is_host:
		EventBus.toast_requested.emit(Loc.t(&"toast.room_full"), &"warning")
		return false
	_pending_room = target
	_pending_password = password
	if not _connect_to(target.address, target.port):
		EventBus.toast_requested.emit(Loc.t(&"toast.join_failed"), &"error")
		return false
	EventBus.toast_requested.emit(Loc.t(&"toast.connecting"), &"info")
	return true


## Join by typing an address — the escape hatch when the hotspot blocks UDP
## broadcast and discovery therefore finds nothing.
func join_address(address: String, port: int, password: String = "") -> bool:
	var target := RoomInfo.new()
	target.address = address
	target.port = port
	target.is_lan = true
	target.transport = GameTypes.Transport.LAN_HOTSPOT
	target.max_players = MAX_LAN_PLAYERS
	return join_lan(target, password)


## Join by six-character code. On a hotspot this means "find the beacon with
## that code, then connect to it"; online it is a backend lookup.
func join_by_code(code: String, password: String = "") -> bool:
	var normalised := RoomInfo.normalise_code(code)
	if not RoomInfo.is_valid_code(normalised):
		EventBus.toast_requested.emit(Loc.t(&"toast.code_invalid"), &"warning")
		return false
	for candidate in discovery.rooms():
		if candidate.code == normalised:
			return join_lan(candidate, password)
	if Api.is_configured():
		_join_online(normalised, password)
		return true
	EventBus.toast_requested.emit(Loc.t(&"toast.code_not_found"), &"warning")
	return false


## The UDP port local discovery is listening on, or 0 when it is not scanning.
## Surfaced in the browser because a second copy of the game on the same machine
## quietly moves to the fallback port, and one line of text answers "why does
## this instance not see that one?" before it becomes a bug report.
func listen_port() -> int:
	return discovery.receive_port() if discovery != null else 0


# ------------------------------------------------------------------ match start

## Legacy room-start stub. It does not create a PixelLegends MOBA match and is
## not exposed by the current hub. Any future match start must follow the
## server-authoritative design and phase gates in docs/PROJECT_SPEC.txt.
func start_match() -> Dictionary:
	if not is_in_room() or not _is_host:
		return {"ok": false, "reason": "not_host"}
	var mode := GameCatalog.resolve(room.mode_id)
	var humans := _human_count()
	var needed := maxi(mode.min_players, 2)
	if humans < needed and not Settings.get_bool("net/allow_bots"):
		return {"ok": false, "reason": "need_players", "need": needed, "have": humans}
	EventBus.toast_requested.emit(
		Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")}), &"info")
	_rpc_start.rpc(0.0)
	return {"ok": true, "reason": "queued_for_phase_two"}


func _human_count() -> int:
	var count := 0
	for peer_id in _roster.keys():
		if not bool((_roster[peer_id] as Dictionary).get("is_bot", false)):
			count += 1
	return count


# --------------------------------------------------------------- peer plumbing

func _open_server(created: RoomInfo) -> int:
	_peer = ENetMultiplayerPeer.new()
	for offset in (LAN_PORT_MAX - LAN_PORT_MIN + 1):
		var port := LAN_PORT_MIN + offset
		if _peer.create_server(port, MAX_LAN_PLAYERS - 1) == OK:
			multiplayer.multiplayer_peer = _peer
			_ports = [port]
			created.port = port
			return port
	push_error("RoomService: no free LAN port in %d..%d." % [LAN_PORT_MIN, LAN_PORT_MAX])
	_peer = null
	return 0


func _connect_to(address: String, port: int) -> bool:
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, port)
	if error != OK:
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	_join_timeout = 12.0
	set_process(true)
	return true


func _teardown_peer() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	_join_timeout = 0.0
	set_process(discovery.is_advertising() or discovery.is_scanning())


func _local_entry(is_host: bool) -> Dictionary:
	var profile := Session.profile
	return {
		"peer_id": HOST_PEER_ID if is_host else multiplayer.get_unique_id(),
		"uid": profile.uid,
		"name": Session.display_name(),
		"level": profile.level,
		"rank_points": profile.rank_points,
		"avatar_color": posmod(profile.avatar_color, 8) if profile.avatar_color >= 0 else absi(profile.uid.hash()) % 8,
		"is_host": is_host,
		"is_local": true,
		"is_bot": false,
		"ready": is_host,
		"team": GameTypes.Team.NONE,
		"ping_ms": 0,
	}


func _on_peer_connected(peer_id: int) -> void:
	if not _is_host:
		return
	# The newcomer introduces itself over RPC; until then we show a placeholder
	# so the host sees the connection land immediately.
	_roster[peer_id] = {
		"peer_id": peer_id, "uid": "", "name": Loc.t(&"rooms.connecting"),
		"level": 1, "rank_points": 0, "avatar_color": 0,
		"is_host": false, "is_local": false, "is_bot": false,
		"ready": false, "team": GameTypes.Team.NONE, "ping_ms": 0,
	}
	_broadcast_roster()


func _on_peer_disconnected(peer_id: int) -> void:
	if not _roster.has(peer_id):
		return
	var gone: Dictionary = _roster[peer_id]
	_roster.erase(peer_id)
	if _is_host:
		_broadcast_roster()
		EventBus.toast_requested.emit(
			Loc.t(&"toast.player_left", {"name": String(gone.get("name", "?"))}), &"info")


func _on_connected_to_server() -> void:
	_join_timeout = 0.0
	_submit_hello.rpc_id(HOST_PEER_ID, _hello_payload())


func _on_connection_failed() -> void:
	_teardown_peer()
	room = null
	EventBus.toast_requested.emit(Loc.t(&"toast.join_failed"), &"error")


func _on_server_disconnected() -> void:
	# The host quit, or the hotspot dropped. Either way there is no room now.
	var had_room := room != null
	_teardown_peer()
	room = null
	_is_host = false
	_roster.clear()
	if had_room:
		EventBus.room_closed.emit("host_left")
		EventBus.toast_requested.emit(Loc.t(&"toast.host_left"), &"warning")


## What a joiner tells the host about itself. The password is sent as the same
## digest the beacon carried, so the host compares digests and never sees the
## password itself. (It is a "keep honest people out" check, not security — the
## host runs the match, so the host is the trust boundary either way.)
func _hello_payload() -> Dictionary:
	var entry := _local_entry(false)
	entry["password_hash"] = RoomInfo.hash_password(_pending_password)
	entry["net_version"] = RoomInfo.NET_VERSION
	return entry


# ------------------------------------------------------------------ RPC surface
#
# These live on the autoload, so the node path (`/root/Rooms`) is identical on
# both peers and RPCs resolve without any scene plumbing.

@rpc("any_peer", "call_remote", "reliable")
func _submit_hello(payload: Dictionary) -> void:
	if not _is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if room.password_protected and String(payload.get("password_hash", "")) != room.password_hash:
		_rpc_kicked.rpc_id(sender, "bad_password")
		return
	if _roster.size() >= room.max_players:
		_rpc_kicked.rpc_id(sender, "room_full")
		return
	var entry := payload.duplicate()
	entry["peer_id"] = sender
	entry["is_host"] = false
	entry["is_local"] = false
	entry["is_bot"] = false
	entry["ready"] = false
	entry.erase("password_hash")
	entry.erase("net_version")
	_roster[sender] = entry
	_broadcast_roster()
	EventBus.toast_requested.emit(
		Loc.t(&"toast.player_joined", {"name": String(entry.get("name", "?"))}), &"success")


@rpc("authority", "call_remote", "reliable")
func _rpc_roster(players: Array, meta: Dictionary) -> void:
	if _is_host:
		return                      # the host is the authority; ignore echoes
	if room == null:
		room = RoomInfo.from_dict(meta)
		_is_host = false
		room.is_lan = true
		room.transport = GameTypes.Transport.LAN_HOTSPOT
		room.players.clear()
	else:
		room.max_players = int(meta.get("max_players", room.max_players))
		room.state = int(meta.get("state", room.state))
		room.players.clear()
	var local_id := multiplayer.get_unique_id()
	for entry in players:
		if not (entry is Dictionary):
			continue
		var player: Dictionary = (entry as Dictionary).duplicate()
		player["is_local"] = int(player.get("peer_id", 0)) == local_id
		room.players.append(player)
	_roster.clear()
	for player in room.players:
		_roster[int(player.get("peer_id", 0))] = player
	EventBus.room_updated.emit(room)


@rpc("authority", "call_remote", "reliable")
func _rpc_kicked(reason: String) -> void:
	_teardown_peer()
	room = null
	_is_host = false
	_roster.clear()
	EventBus.room_closed.emit(reason)
	EventBus.toast_requested.emit(Loc.t(&"toast.kicked", {"reason": reason}), &"warning")


@rpc("authority", "call_remote", "reliable")
func _rpc_start(_countdown: float) -> void:
	EventBus.toast_requested.emit(
		Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")}), &"info")


@rpc("any_peer", "call_remote", "reliable")
func _submit_ready(ready: bool) -> void:
	if not _is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if _roster.has(sender):
		(_roster[sender] as Dictionary)["ready"] = ready
		_broadcast_roster()


# ------------------------------------------------------------------- internals

func _broadcast_roster() -> void:
	_sync_room_from_roster()
	if _peer != null and multiplayer.has_multiplayer_peer():
		_rpc_roster.rpc(_roster.values(), room.to_dict())
	EventBus.room_updated.emit(room)


func _sync_room_from_roster() -> void:
	if room == null:
		return
	room.players.clear()
	for peer_id in _roster.keys():
		var entry: Dictionary = (_roster[peer_id] as Dictionary).duplicate()
		entry["is_local"] = peer_id == HOST_PEER_ID
		room.players.append(entry)
	room.heartbeat_at = int(Time.get_unix_time_from_system())


func _join_online(code: String, _password: String) -> void:
	# Legacy online-room placeholder. Api is not the approved Nakama backend;
	# this path must not be presented as an active PixelLegends lobby.
	EventBus.toast_requested.emit(
		Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")}), &"info")
	push_warning("RoomService: online join requested for %s but no backend is wired." % code)


func _on_discovery_changed(rooms: Array) -> void:
	EventBus.room_list_changed.emit(rooms)
	for entry in rooms:
		if entry is RoomInfo:
			EventBus.lan_room_seen.emit(entry)


func _on_discovery_state_changed(state: int, message: String) -> void:
	EventBus.discovery_state_changed.emit(state, message)


## Join a room we discovered but that has since been joined by someone else:
## keep the roster live so the browser shows the real size, not a stale one.
func refresh(room_code: String) -> void:
	for candidate in discovery.rooms():
		if candidate.code == room_code:
			EventBus.room_updated.emit(candidate)
			return


func _process(delta: float) -> void:
	if _join_timeout > 0.0:
		_join_timeout -= delta
		if _join_timeout <= 0.0:
			_on_connection_failed()
			return
	_ping_timer -= delta
	if _ping_timer > 0.0 or _peer == null or room == null:
		return
	_ping_timer = 1.0
	_update_ping()


## Reads round-trip time straight from ENet. Displaying it is not vanity: on a
## hotspot it is the number that tells the host "move closer".
func _update_ping() -> void:
	var changed := false
	var ids: Array = _roster.keys()
	if not _is_host:
		ids = [HOST_PEER_ID]
	for peer_id in ids:
		var enet_peer := _peer.get_peer(int(peer_id))
		if enet_peer == null:
			continue
		var rtt := int(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		if not _roster.has(peer_id):
			continue
		var entry: Dictionary = _roster[peer_id]
		if int(entry.get("ping_ms", 0)) != rtt:
			entry["ping_ms"] = rtt
			changed = true
	if changed:
		if _is_host:
			_broadcast_roster()
		else:
			_sync_room_from_roster()
			room.ping_ms = int((_roster.get(HOST_PEER_ID, {}) as Dictionary).get("ping_ms", 0))
			EventBus.room_updated.emit(room)
