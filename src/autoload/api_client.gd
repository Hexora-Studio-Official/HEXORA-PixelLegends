extends Node
## The only place in the client that speaks HTTP.
##
## Design rules, in order of importance:
##
##  1. **Nothing else touches HTTPRequest.** Auth, friends, rooms and
##     matchmaking all go through `request()`, so timeouts, auth headers,
##     retries and error shaping exist exactly once.
##  2. **A missing backend is not an error.** With no `dev/api_base_url` the
##     whole game runs offline; every call returns `{ok = false, error =
##     "not_configured"}` and the callers degrade to local behaviour instead of
##     showing a spinner forever.
##  3. **Never block the frame.** Everything is `await`-friendly and returns a
##     plain Dictionary; services decide what a failure means for them.
##
## Requests are sent as JSON with a bearer token once `auth_token` is set. The
## token is the backend's own session token — never the Google `id_token`, which
## is short-lived and must be verified exactly once, at sign-in.

## Every response has this shape. `data` is only meaningful when `ok` is true.
##   {ok: bool, status: int, data: Variant, error: String}
const TIMEOUT_SEC := 12.0
const MAX_RETRIES := 1

var base_url: String = ""
var auth_token: String = ""

var _in_flight: int = 0
var _last_error: String = ""
var _online: bool = false
var _probe_timer: float = 0.0


func _ready() -> void:
	base_url = Settings.get_string("dev/api_base_url").strip_edges()
	EventBus.settings_changed.connect(_on_settings_changed)
	if is_configured():
		# First probe is deferred so it never competes with the boot splash for
		# the first frame, and so a dead backend cannot delay the menu.
		_probe_timer = 1.0
		set_process(true)


func _process(delta: float) -> void:
	_probe_timer -= delta
	if _probe_timer > 0.0:
		return
	_probe_timer = 30.0
	await _refresh_online()


func _on_settings_changed(section: StringName) -> void:
	if section != &"dev":
		return
	base_url = Settings.get_string("dev/api_base_url").strip_edges()
	_online = false
	_probe_timer = 0.5 if is_configured() else 0.0
	set_process(is_configured())


# ------------------------------------------------------------------- queries

func is_configured() -> bool:
	return not base_url.strip_edges().is_empty()


func is_busy() -> bool:
	return _in_flight > 0


## True only once a probe has actually succeeded. Screens use this to decide
## between "servers online" and "offline — local play still works", so it must
## never be optimistic: an unreachable backend is not an online backend.
func is_online() -> bool:
	return is_configured() and _online


func last_error() -> String:
	return _last_error


# --------------------------------------------------------------------- verbs

func get_json(path: String, query: Dictionary = {}) -> Dictionary:
	return await request("GET", path, null, query)


func post_json(path: String, body: Variant = null) -> Dictionary:
	return await request("POST", path, body)


func put_json(path: String, body: Variant = null) -> Dictionary:
	return await request("PUT", path, body)


## `body` is serialised as JSON unless it is already a String (form posts).
func request(method: String, path: String, body: Variant = null,
		query: Dictionary = {}) -> Dictionary:
	if not is_configured():
		return _failure(0, "not_configured")

	var url := _url(path, query)
	var headers := PackedStringArray(["Accept: application/json"])
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)
	var payload := ""
	if body is Dictionary or body is Array:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	elif body is String:
		headers.append("Content-Type: application/x-www-form-urlencoded")
		payload = body

	var attempts := MAX_RETRIES + 1
	for attempt in attempts:
		var result := await _send(method, url, headers, payload)
		# Retry on transport failure only, never on an HTTP error: retrying a
		# rejected request just makes the server reject it again, faster.
		if bool(result["ok"]) or int(result["status"]) > 0 or attempt == attempts - 1:
			return result
	return _failure(0, "unreachable")


## Cheap liveness probe. Used by the login and menu screens to decide whether
## to say "servers online", and by nothing else — the game works without it.
func probe() -> bool:
	if not is_configured():
		return false
	var result := await get_json("/health")
	return bool(result["ok"])


func _refresh_online() -> void:
	var was := _online
	_online = await probe()
	if _online != was:
		EventBus.network_availability_changed.emit(_online)


# ------------------------------------------------------------------ endpoints

## Exchange a verified-by-the-server Google `id_token` for a session.
##
## `callsign` and `region` are *suggestions* for a first-time account (the name
## Google gave us, and where the player says they are); the backend may ignore
## both, and must ignore the name if it collides.
func authenticate_google(id_token: String, callsign: String = "",
		region: int = -1) -> Dictionary:
	var body := {"id_token": id_token}
	if not callsign.is_empty():
		body["callsign"] = callsign
	if region >= 0:
		body["region"] = region
	return await post_json("/v1/auth/google", body)


func authenticate_guest(device_id: String, callsign: String) -> Dictionary:
	return await post_json("/v1/auth/guest", {"device_id": device_id, "callsign": callsign})


func fetch_profile() -> Dictionary:
	return await get_json("/v1/profile")


func push_profile(profile: Dictionary) -> Dictionary:
	return await put_json("/v1/profile", profile)


func list_friends() -> Dictionary:
	return await get_json("/v1/friends")


func send_friend_request(handle: String) -> Dictionary:
	return await post_json("/v1/friends/requests", {"handle": handle})


func accept_friend_request(uid: String) -> Dictionary:
	return await post_json("/v1/friends/requests/%s/accept" % uid, {})


func invite_friend(uid: String, room_code: String) -> Dictionary:
	return await post_json("/v1/friends/%s/invite" % uid, {"room_code": room_code})


func list_rooms(filters: Dictionary = {}) -> Dictionary:
	return await get_json("/v1/rooms", filters)


func create_room(config: Dictionary) -> Dictionary:
	return await post_json("/v1/rooms", config)


func join_room(code: String, password: String) -> Dictionary:
	return await post_json("/v1/rooms/%s/join" % code, {"password": password})


func enqueue(modes: Array[StringName], region: int, ranked: bool,
		party_size: int) -> Dictionary:
	var ids: Array[String] = []
	for mode_id in modes:
		ids.append(String(mode_id))
	return await post_json("/v1/matchmaking/tickets", {
		"modes": ids,
		"region": region,
		"ranked": ranked,
		"party_size": party_size,
	})


func cancel_ticket(ticket_id: String) -> Dictionary:
	return await request("DELETE", "/v1/matchmaking/tickets/%s" % ticket_id)


func poll_ticket(ticket_id: String) -> Dictionary:
	return await get_json("/v1/matchmaking/tickets/%s" % ticket_id)


func accept_match(ticket_id: String) -> Dictionary:
	return await post_json("/v1/matchmaking/tickets/%s/accept" % ticket_id, {})


func decline_match(ticket_id: String) -> Dictionary:
	return await post_json("/v1/matchmaking/tickets/%s/decline" % ticket_id, {})


# ------------------------------------------------------------------ internals

func _url(path: String, query: Dictionary) -> String:
	var root := base_url.strip_edges().trim_suffix("/")
	var full := root + (path if path.begins_with("/") else "/" + path)
	if query.is_empty():
		return full
	var parts := PackedStringArray()
	for key in query.keys():
		parts.append("%s=%s" % [String(key).uri_encode(), String(query[key]).uri_encode()])
	return full + "?" + "&".join(parts)


func _send(method: String, url: String, headers: PackedStringArray,
		payload: String) -> Dictionary:
	if not OS.has_feature("web") and get_tree() == null:
		return _failure(0, "no_tree")
	_in_flight += 1
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	http.accept_gzip = true
	add_child(http)

	var error := http.request(url, headers, _http_method(method), payload)
	if error != OK:
		http.queue_free()
		_in_flight -= 1
		_last_error = "request_failed_%d" % error
		return _failure(0, _last_error)

	var response: Array = await http.request_completed
	var result_code := int(response[0])
	var status := int(response[1])
	var raw: PackedByteArray = response[3]
	http.queue_free()
	_in_flight -= 1

	if Settings.get_int("dev/simulated_latency_ms") > 0:
		await _simulate_latency()

	if result_code != HTTPRequest.RESULT_SUCCESS:
		_last_error = "transport_%d" % result_code
		return _failure(0, _last_error)

	var text := raw.get_string_from_utf8()
	var parsed: Variant = null
	if not text.is_empty():
		var json := JSON.new()
		if json.parse(text) == OK:
			parsed = json.data
	if status < 200 or status >= 300:
		_last_error = _error_from(parsed, status)
		if Settings.get_bool("dev/verbose_net_log"):
			push_warning("Api %s %s -> %d %s" % [method, url, status, _last_error])
		return {"ok": false, "status": status, "data": parsed, "error": _last_error}

	if Settings.get_bool("dev/verbose_net_log"):
		print("Api %s %s -> %d" % [method, url, status])
	return {"ok": true, "status": status, "data": parsed, "error": ""}


func _http_method(method: String) -> int:
	match method:
		"POST": return HTTPClient.METHOD_POST
		"PUT": return HTTPClient.METHOD_PUT
		"PATCH": return HTTPClient.METHOD_PATCH
		"DELETE": return HTTPClient.METHOD_DELETE
		_: return HTTPClient.METHOD_GET


## Prefer the backend's own message — it knows why it said no — and fall back
## to something a human can act on.
func _error_from(parsed: Variant, status: int) -> String:
	if parsed is Dictionary:
		var data: Dictionary = parsed
		for key in ["error", "detail", "message"]:
			if data.has(key) and not String(data[key]).is_empty():
				return String(data[key])
	return "http_%d" % status


func _failure(status: int, error: String) -> Dictionary:
	_last_error = error
	return {"ok": false, "status": status, "data": null, "error": error}


## Development aid: makes a localhost backend feel like the real world so that
## loading states and timeouts actually get exercised.
func _simulate_latency() -> void:
	var ms := Settings.get_int("dev/simulated_latency_ms")
	if ms <= 0 or get_tree() == null:
		return
	await get_tree().create_timer(float(ms) / 1000.0).timeout
