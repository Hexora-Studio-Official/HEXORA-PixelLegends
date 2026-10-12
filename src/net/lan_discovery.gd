class_name LanDiscovery
extends Node
## Finds HEXORA rooms on the local network — a Wi-Fi router or a phone hotspot.
##
## This is the part of "play with friends without internet" that people
## actually get stuck on, so it is deliberately dumb and redundant:
##
##   * the host shouts a small JSON beacon at every plausible broadcast address
##     (the /24 broadcast of each of its own interfaces, plus the limited
##     broadcast 255.255.255.255) on a fixed UDP port;
##   * a searcher binds that same port and listens, learns the host's real IP
##     from the packet header — never from the payload, which would be trivially
##     spoofable and, more often, simply wrong behind a hotspot NAT;
##   * anything that stops shouting for `ROOM_TTL` seconds disappears from the
##     list, so a friend who closes the game stops cluttering the browser.
##
## If the hotspot blocks broadcast (some Android builds do), the player can
## still type the host's address by hand — `RoomService.local_addresses()` is
## what the host screen shows for exactly that reason.
##
## Known limits, stated rather than hidden: UDP broadcast is not routable across
## subnets, so both devices must be on the same network; and Android may drop
## broadcast packets while the screen is off. Both are fine for the intended use
## (two phones, one hotspot, both games in the foreground).

signal rooms_changed(rooms: Array)
signal state_changed(state: int, message: String)

## The port every beacon goes to and every searcher listens on. Fixed, because
## a discovery protocol that needs a port lookup is not a discovery protocol.
const DISCOVERY_PORT := 45710

## Second listen port, beacons go here too. Two instances of the game on the
## same machine cannot both bind one UDP port without SO_REUSEADDR, and
## "run two copies and see if they find each other" is the first thing anyone
## testing this feature does — so the searcher falls back to this port and the
## host shouts at both. Costs one extra packet per beacon.
const DISCOVERY_FALLBACK_PORT := DISCOVERY_PORT + 1

## Payload marker so unrelated UDP packets are rejected after the bounded JSON
## parse. Bump only if the beacon format breaks.
const MAGIC := "HEXORA/1"

const BEACON_INTERVAL_SEC := 0.8
## Four missed beacons before a room is considered gone. Long enough to ride out
## a stutter, short enough that a closed game disappears while you watch.
const ROOM_TTL_SEC := 3.6

var _tx: PacketPeerUDP
var _rx: PacketPeerUDP
var _targets: PackedStringArray = PackedStringArray()
var _receive_port: int = DISCOVERY_PORT
var _beacon: String = ""
var _ignore_code: String = ""
var _advertising: bool = false
var _scanning: bool = false
var _beacon_timer: float = 0.0
var _seen: Dictionary = {}     ## room code -> {room: RoomInfo, age: float}
var _state: int = GameTypes.DiscoveryState.STOPPED


func _ready() -> void:
	_tx = PacketPeerUDP.new()
	_rx = PacketPeerUDP.new()
	set_process(false)


func _exit_tree() -> void:
	stop()


# ------------------------------------------------------------------ advertising

## Start shouting `room` out on the local network.
func start_advertising(room: RoomInfo) -> bool:
	stop_advertising()
	_ignore_code = room.code
	if not _prepare_sender():
		_set_state(GameTypes.DiscoveryState.ERROR, "sender")
		return false
	_beacon = _encode(room)
	if _beacon.is_empty():
		_set_state(GameTypes.DiscoveryState.ERROR, "encode")
		return false
	_advertising = true
	_beacon_timer = 0.0        # shout immediately, then on the interval
	_refresh_process()
	_set_state(GameTypes.DiscoveryState.ADVERTISING, room.code)
	return true


func stop_advertising() -> void:
	if not _advertising:
		return
	_advertising = false
	_beacon = ""
	_ignore_code = ""
	_refresh_process()
	if not _scanning:
		_set_state(GameTypes.DiscoveryState.STOPPED, "")


func is_advertising() -> bool:
	return _advertising


# --------------------------------------------------------------------- scanning

## Listen for beacons. Safe to call while advertising (the host can also browse).
func start_scanning() -> bool:
	if _scanning:
		return true
	_rx = PacketPeerUDP.new()
	var error := _rx.bind(DISCOVERY_PORT, "*")
	_receive_port = DISCOVERY_PORT
	if error != OK:
		# Most likely another local instance already owns the primary port.
		# Falling back keeps a second copy of the game on the same machine —
		# the obvious way to test this — able to see the first one.
		error = _rx.bind(DISCOVERY_FALLBACK_PORT, "*")
		_receive_port = DISCOVERY_FALLBACK_PORT
	if error != OK:
		push_warning("LanDiscovery: could not bind UDP %d or %d (%d)." % [
			DISCOVERY_PORT, DISCOVERY_FALLBACK_PORT, error])
		_set_state(GameTypes.DiscoveryState.ERROR, "bind")
		return false
	# Broadcasts are addressed to a broadcast IP, which most stacks filter out
	# unless the socket explicitly opts in.
	_rx.set_broadcast_enabled(true)
	_scanning = true
	_seen.clear()
	_refresh_process()
	_set_state(GameTypes.DiscoveryState.SCANNING, "")
	return true


func stop_scanning() -> void:
	if not _scanning:
		return
	_scanning = false
	_rx.close()
	_seen.clear()
	_refresh_process()
	if not _advertising:
		_set_state(GameTypes.DiscoveryState.STOPPED, "")
	rooms_changed.emit([])


func is_scanning() -> bool:
	return _scanning


## Rooms currently in range, freshest first.
func rooms() -> Array[RoomInfo]:
	var result: Array[RoomInfo] = []
	for code in _seen.keys():
		result.append(_seen[code]["room"] as RoomInfo)
	result.sort_custom(func(a: RoomInfo, b: RoomInfo) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return result


func state() -> int:
	return _state


## The port this instance is actually listening on. The UI only uses it for the
## diagnostics line on the browse tab.
func receive_port() -> int:
	return _receive_port if _scanning else 0


func stop() -> void:
	stop_advertising()
	stop_scanning()
	_tx = PacketPeerUDP.new()


# ----------------------------------------------------------------------- ticks

func _refresh_process() -> void:
	set_process(_advertising or _scanning)


func _process(delta: float) -> void:
	if _advertising:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = BEACON_INTERVAL_SEC
			_send_beacon()
	if _scanning:
		_drain_socket()
		if _expire_rooms():
			rooms_changed.emit(rooms())


func _send_beacon() -> void:
	var payload := _beacon.to_utf8_buffer()
	for target in _targets:
		_tx.set_dest_address(target, DISCOVERY_PORT)
		_tx.put_packet(payload)
		_tx.set_dest_address(target, DISCOVERY_FALLBACK_PORT)
		_tx.put_packet(payload)


func _drain_socket() -> void:
	var found_any := false
	var guard := 64                     # never spin forever on a flood
	while _rx.get_available_packet_count() > 0 and guard > 0:
		guard -= 1
		var packet := _rx.get_packet()
		var sender_ip := _rx.get_packet_ip()
		var sender_port := _rx.get_packet_port()
		var room := _decode(packet, sender_ip, sender_port)
		if room == null:
			continue
		if room.code == _ignore_code:
			continue                    # our own beacon, reflected back
		var known: Dictionary = _seen.get(room.code, {})
		var is_new := known.is_empty()
		_seen[room.code] = {"room": room, "age": 0.0}
		if is_new:
			found_any = true
		elif (known["room"] as RoomInfo).occupancy_label() != room.occupancy_label():
			found_any = true            # a room filling up should update live
	if found_any:
		rooms_changed.emit(rooms())


## Age out rooms that stopped shouting. Returns true if the list changed.
func _expire_rooms() -> bool:
	var expired: Array[String] = []
	for code in _seen.keys():
		_seen[code]["age"] = float(_seen[code]["age"]) + get_process_delta_time()
		if float(_seen[code]["age"]) > ROOM_TTL_SEC:
			expired.append(code)
	for code in expired:
		_seen.erase(code)
	return not expired.is_empty()


# ------------------------------------------------------------------ transport

func _prepare_sender() -> bool:
	_tx = PacketPeerUDP.new()
	# Binding to an ephemeral port is what makes Windows and some Android builds
	# route the broadcast out of the right interface.
	var error := _tx.bind(0, "*")
	if error != OK and error != ERR_ALREADY_IN_USE:
		push_warning("LanDiscovery: sender bind failed (%d)." % error)
		return false
	_tx.set_broadcast_enabled(true)
	_targets = _broadcast_targets()
	return not _targets.is_empty()


## Every address worth shouting at: each interface's subnet broadcast, then the
## limited broadcast as a fallback. Returns at least one target on any device
## that has an IPv4 address at all.
func _broadcast_targets() -> PackedStringArray:
	var targets := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue                     # IPv6: not supported by this beacon
		if address.begins_with("127."):
			continue                     # loopback, only talks to itself
		var octets := address.split(".")
		if octets.size() != 4:
			continue
		# /24 is what phone hotspots and home routers actually use. Shouting at
		# a wrong netmask is harmless: nothing answers.
		targets.append("%s.%s.%s.255" % [octets[0], octets[1], octets[2]])
	targets.append("255.255.255.255")
	return targets


func _encode(room: RoomInfo) -> String:
	var data := room.to_beacon()
	data["magic"] = MAGIC
	return JSON.stringify(data)


## Returns a RoomInfo with the *sender's* address filled in, or null when the
## packet is not ours / not parseable.
func _decode(packet: PackedByteArray, sender_ip: String, sender_port: int) -> RoomInfo:
	if packet.size() > 1400:
		return null                      # bigger than a beacon can be
	var text := packet.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var data: Dictionary = json.data
	if String(data.get("magic", "")) != MAGIC or not data.has("code"):
		return null
	var room := RoomInfo.from_beacon(data)
	if room == null:
		return null
	# Trust the packet header for the address, the payload for everything else.
	room.address = sender_ip
	room.transport = GameTypes.Transport.LAN_HOTSPOT
	room.is_lan = true
	if room.port <= 0 or room.port > 65535:
		room.port = sender_port if sender_port > 0 else 0
	return room


func _set_state(new_state: int, message: String) -> void:
	if _state == new_state and message.is_empty():
		return
	_state = new_state
	state_changed.emit(new_state, message)
