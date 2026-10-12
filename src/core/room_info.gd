class_name RoomInfo
extends RefCounted
## One discoverable lobby: either a studio-hosted room on the internet, or a
## phone acting as host on a hotspot / shared Wi-Fi.
##
## The same structure describes all three transports we support, because the
## lobby UI should not care whether a room lives on our servers or on the
## phone in the next tent. `transport` is the only thing that differs.
##
## Serializable both ways: LAN discovery broadcasts `to_dict()` over UDP and
## the backend will return the same shape as JSON.

const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  ## no I/O/0/1
const CODE_LENGTH := 6
const NET_VERSION := 1

var code: String = ""
var name: String = ""
var host_name: String = ""
var mode_id: StringName = &"tdm"
var map_id: StringName = &"foundry"
var region: int = GameTypes.Region.AUTO
var visibility: int = GameTypes.RoomVisibility.PUBLIC
var state: int = GameTypes.RoomState.FORMING
var transport: int = GameTypes.Transport.NONE

var players: Array[Dictionary] = []
var max_players: int = 12
var squad_size: int = 1

var password_protected: bool = false
var password_hash: String = ""
var ping_ms: int = 0
var is_lan: bool = false
var ranked: bool = false

## How many players the room advertises when we have only seen its discovery
## beacon and therefore have no roster. -1 means "the roster in `players` is
## authoritative". Without this, a discovered 8-player room would display as
## empty, which is exactly the kind of small lie that erodes trust in a browser.
var player_count_hint: int = -1

## Where to reach it. For LAN rooms this is the host's address on the local
## network; for online rooms it is the relay / dedicated endpoint.
var address: String = ""
var port: int = 0
var server_version: int = NET_VERSION
var created_at: int = 0
var heartbeat_at: int = 0


func player_count() -> int:
	if players.is_empty() and player_count_hint >= 0:
		return player_count_hint
	return players.size()


func is_full() -> bool:
	return player_count() >= max_players


func is_joinable() -> bool:
	return state == GameTypes.RoomState.FORMING \
		and not is_full() \
		and server_version == NET_VERSION


func mode() -> GameMode:
	return GameCatalog.resolve(mode_id)


## Seconds since the room's last heartbeat. LAN browsers use this to evict
## rooms whose host closed the app without saying goodbye.
func age_seconds() -> float:
	if heartbeat_at <= 0:
		return 0.0
	return maxf(0.0, Time.get_unix_time_from_system() - float(heartbeat_at))


func local_player() -> Dictionary:
	for player in players:
		if player.get("is_local", false):
			return player
	return {}


func local_team() -> GameTypes.Team:
	return local_player().get("team", GameTypes.Team.NONE) as GameTypes.Team


## A short "3/12" style occupancy string.
func occupancy_label() -> String:
	return "%d/%d" % [player_count(), max_players]


## Six characters the host can read aloud: "K7QP2M". Ambiguous glyphs are
## excluded so a code survives being spoken over a noisy voice channel.
static func generate_code() -> String:
	var result := ""
	for _index in CODE_LENGTH:
		result += CODE_ALPHABET[randi() % CODE_ALPHABET.length()]
	return result


static func normalise_code(raw: String) -> String:
	return raw.strip_edges().to_upper().replace(" ", "").replace("-", "")


static func is_valid_code(raw: String) -> bool:
	var code := normalise_code(raw)
	if code.length() != CODE_LENGTH:
		return false
	for index in code.length():
		if not CODE_ALPHABET.contains(code[index]):
			return false
	return true


## Cheap non-cryptographic digest. Room passwords are a "keep honest people
## out" speed bump, not a security boundary — the authoritative server is.
static func hash_password(raw: String) -> String:
	if raw.is_empty():
		return ""
	return (raw + "::hexora-room-v1").sha256_text().substr(0, 16)


func to_dict() -> Dictionary:
	return {
		"code": code,
		"name": name,
		"host_name": host_name,
		"mode_id": String(mode_id),
		"map_id": String(map_id),
		"region": region,
		"visibility": visibility,
		"state": state,
		"transport": transport,
		"players": players,
		"max_players": max_players,
		"squad_size": squad_size,
		"password_protected": password_protected,
		"ping_ms": ping_ms,
		"is_lan": is_lan,
		"ranked": ranked,
		"player_count_hint": player_count_hint,
		"address": address,
		"port": port,
		"server_version": server_version,
		"created_at": created_at,
		"heartbeat_at": heartbeat_at,
	}


static func from_dict(data: Dictionary) -> RoomInfo:
	var room := RoomInfo.new()
	room.code = String(data.get("code", ""))
	room.name = String(data.get("name", ""))
	room.host_name = String(data.get("host_name", ""))
	room.mode_id = StringName(data.get("mode_id", "tdm"))
	room.map_id = StringName(data.get("map_id", "foundry"))
	room.region = int(data.get("region", GameTypes.Region.AUTO))
	room.visibility = int(data.get("visibility", GameTypes.RoomVisibility.PUBLIC))
	room.state = int(data.get("state", GameTypes.RoomState.FORMING))
	room.transport = int(data.get("transport", GameTypes.Transport.NONE))
	room.max_players = int(data.get("max_players", 12))
	room.squad_size = int(data.get("squad_size", 1))
	room.password_protected = bool(data.get("password_protected", false))
	room.ping_ms = int(data.get("ping_ms", 0))
	room.is_lan = bool(data.get("is_lan", false))
	room.ranked = bool(data.get("ranked", false))
	room.player_count_hint = int(data.get("player_count_hint", -1))
	room.address = String(data.get("address", ""))
	room.port = int(data.get("port", 0))
	room.server_version = int(data.get("server_version", NET_VERSION))
	room.created_at = int(data.get("created_at", 0))
	room.heartbeat_at = int(data.get("heartbeat_at", 0))

	var raw_players: Variant = data.get("players", [])
	if raw_players is Array:
		for entry in raw_players:
			if entry is Dictionary:
				room.players.append((entry as Dictionary).duplicate(true))
	return room


## Inverse of `to_beacon()`. Returns null for a beacon from a version we do
## not speak, so an old build in the room does not appear as a broken room.
##
## The sender's address is *not* taken from here — the listener fills it in from
## the packet header, because a payload can claim any address it likes and,
## behind a hotspot NAT, frequently would.
static func from_beacon(data: Dictionary) -> RoomInfo:
	if int(data.get("hexora", 0)) != NET_VERSION:
		return null
	var room := RoomInfo.new()
	room.code = String(data.get("code", ""))
	if room.code.is_empty():
		return null
	room.name = String(data.get("name", ""))
	room.host_name = String(data.get("host_name", ""))
	room.mode_id = StringName(data.get("mode_id", "tdm"))
	room.map_id = StringName(data.get("map_id", "foundry"))
	room.region = int(data.get("region", GameTypes.Region.AUTO))
	room.visibility = int(data.get("visibility", GameTypes.RoomVisibility.PUBLIC))
	room.state = int(data.get("state", GameTypes.RoomState.FORMING))
	room.transport = int(data.get("transport", GameTypes.Transport.LAN_HOTSPOT))
	room.max_players = int(data.get("max_players", 12))
	room.squad_size = int(data.get("squad_size", 1))
	room.password_protected = bool(data.get("password_protected", false))
	room.port = int(data.get("port", 0))
	room.ranked = bool(data.get("ranked", false))
	room.is_lan = true
	room.player_count_hint = int(data.get("players", -1))
	room.heartbeat_at = int(Time.get_unix_time_from_system())
	return room


## Payload for the UDP discovery beacon. Deliberately small: some Android
## hotspots have tight MTU and we broadcast this twice a second.
func to_beacon() -> Dictionary:
	return {
		"hexora": NET_VERSION,
		"code": code,
		"name": name,
		"host_name": host_name,
		"mode_id": String(mode_id),
		"map_id": String(map_id),
		"region": region,
		"visibility": visibility,
		"state": state,
		"transport": transport,
		"players": player_count(),
		"max_players": max_players,
		"squad_size": squad_size,
		"password_protected": password_protected,
		"port": port,
		"ranked": ranked,
	}
