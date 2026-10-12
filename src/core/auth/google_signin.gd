class_name GoogleSignIn
extends Node
## Google Sign-In for a native app, implemented with the OAuth 2.0 loopback
## redirect flow (RFC 8252, "appAuth" pattern) plus PKCE.
##
## How it works
##   1. We bind a loopback TCP socket on this device (127.0.0.1:PORT).
##   2. We open the system browser on Google's consent screen, with
##      `redirect_uri = http://127.0.0.1:PORT/` and a PKCE code challenge.
##   3. Google redirects the browser back to our own socket. Nothing leaves
##      the device, and no secret is embedded in the app (PKCE replaces it).
##   4. We exchange the one-time code for tokens, then ask Google who the user
##      is, and hand the account to AuthService.
##
## Security notes that matter before shipping:
##   * The `id_token` we obtain MUST be verified server-side (signature, `aud`,
##     `iss`, `exp`) before any account is trusted. This class does not and
##     cannot verify it — the client is not a trustworthy verifier.
##   * PKCE means the app holds no client secret, which is correct for a public
##     client. Do not "fix" this by embedding a secret in the APK.
##   * Google's current guidance for *Android* apps is the native
##     GoogleSignIn plugin with an "Android app" client (package name + SHA-1).
##     This loopback flow needs a "Desktop app" client, works on Android today,
##     and is the only flow that also works on desktop and in tests. See
##     docs/AUTH_SETUP.md; the native plugin can replace this later without
##     touching any screen, because screens only talk to AuthService.

signal progress(message_key: StringName)
## account: {sub, email, name, picture, id_token, access_token, expires_in}
signal succeeded(account: Dictionary)
signal failed(message_key: StringName, detail: String)

const AUTH_ENDPOINT := "https://accounts.google.com/o/oauth2/v2/auth"
const TOKEN_ENDPOINT := "https://oauth2.googleapis.com/token"
const USERINFO_ENDPOINT := "https://openidconnect.googleapis.com/v1/userinfo"
const SCOPE := "openid email profile"

## Fixed by default so that the redirect URI is stable and can be registered in
## the Google Cloud Console exactly once. If the port is busy we walk upwards
## and report the real URI, because Google rejects an unregistered port
## redirect with `redirect_uri_mismatch`.
const DEFAULT_PORT := 8712
const PORT_ATTEMPTS := 12
const BIND_ADDRESS := "127.0.0.1"

## Give up after this long. Long enough to type a password and finish 2FA,
## short enough that a stuck tab does not leave the UI spinning forever.
const TIMEOUT_SEC := 240.0
const MAX_REQUEST_BYTES := 16384

var client_id: String = ""

## Optional. Google's installed-app token exchange historically requires the
## client secret even with PKCE. Leave empty for a client that does not (a
## web/loopback client), fill it in when Google answers `invalid_request`.
var client_secret: String = ""

var _server: TCPServer
var _peer: StreamPeerTCP
var _buffer: PackedByteArray = PackedByteArray()
var _port: int = DEFAULT_PORT
var _verifier: String = ""
var _expected_state: String = ""
var _elapsed: float = 0.0
var _running: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)


## The redirect URI we would use on a default install. Shown in Developer
## settings so the value can be copy-pasted into the Cloud Console.
static func default_redirect_uri() -> String:
	return "http://%s:%d/" % [BIND_ADDRESS, DEFAULT_PORT]


func redirect_uri() -> String:
	return "http://%s:%d/" % [BIND_ADDRESS, _port]


func is_running() -> bool:
	return _running


func start() -> void:
	if _running:
		return
	if client_id.strip_edges().is_empty():
		failed.emit(&"auth.error.not_configured", "No Google client ID configured.")
		return

	if not _bind_server():
		failed.emit(&"auth.error.port", "No free loopback port in range %d..%d." % [
			DEFAULT_PORT, DEFAULT_PORT + PORT_ATTEMPTS - 1,
		])
		return

	_verifier = _make_code_verifier()
	_expected_state = _random_token(24)
	_elapsed = 0.0
	_buffer = PackedByteArray()
	_peer = null
	_running = true

	progress.emit(&"auth.login.google_busy")
	var url := _build_auth_url(_code_challenge(_verifier))
	var open_error := OS.shell_open(url)
	if open_error != OK:
		_shutdown()
		failed.emit(&"auth.error.generic", "OS.shell_open failed with %d." % open_error)
		return
	set_process(true)


## Abort an in-flight sign-in (user tapped Back, app is quitting, ...).
func cancel() -> void:
	if not _running:
		return
	_shutdown()
	failed.emit(&"auth.error.cancelled", "Cancelled by the user.")


func _bind_server() -> bool:
	_server = TCPServer.new()
	for offset in PORT_ATTEMPTS:
		var candidate := DEFAULT_PORT + offset
		var error := _server.listen(candidate, BIND_ADDRESS)
		if error == OK:
			_port = candidate
			return true
	_server = null
	return false


func _shutdown() -> void:
	_running = false
	set_process(false)
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
	if _server != null:
		_server.stop()
		_server = null
	_buffer = PackedByteArray()
	_verifier = ""
	_expected_state = ""


# ------------------------------------------------------------------ URL build

func _build_auth_url(code_challenge: String) -> String:
	var query := [
		"client_id=" + client_id.uri_encode(),
		"redirect_uri=" + redirect_uri().uri_encode(),
		"response_type=code",
		"scope=" + SCOPE.uri_encode(),
		"code_challenge=" + code_challenge.uri_encode(),
		"code_challenge_method=S256",
		"state=" + _expected_state.uri_encode(),
		# Select the account instead of silently reusing the last one; players
		# often keep a personal and a gaming account on the same device.
		"prompt=select_account",
		"access_type=online",
	]
	return AUTH_ENDPOINT + "?" + "&".join(query)


## PKCE code verifier: 43..128 characters from the unreserved set. We use 64.
func _make_code_verifier() -> String:
	const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
	var out := ""
	for index in 64:
		out += ALPHABET[_rng.randi_range(0, ALPHABET.length() - 1)]
	return out


## S256 challenge: base64url(SHA-256(verifier)) with the padding removed.
func _code_challenge(verifier: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(verifier.to_utf8_buffer())
	return _base64url(context.finish())


func _base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes) \
		.replace("+", "-").replace("/", "_").replace("=", "")


func _random_token(length: int) -> String:
	# Crypto keeps `state` unguessable, which is what protects against a
	# malicious app on the device answering our redirect first.
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(length)
	return _base64url(bytes).substr(0, length)


# ------------------------------------------------------------------- polling

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT_SEC:
		_shutdown()
		failed.emit(&"auth.error.timeout", "No redirect received within %.0fs." % TIMEOUT_SEC)
		return
	_pump_socket()


## Accept the browser's connection and hand the request over once its headers
## have arrived. Split out of `_process` so each step has a name.
func _pump_socket() -> void:
	if _server == null:
		return
	if _peer == null:
		if not _server.is_connection_available():
			return
		_peer = _server.take_connection()
		if _peer == null:
			return
	if not _socket_has_data():
		return

	var available := _peer.get_available_bytes()
	if available > MAX_REQUEST_BYTES:
		_reject_oversized_request()
		return
	var chunk: Array = _peer.get_data(available)
	if int(chunk[0]) == OK:
		_buffer.append_array(chunk[1] as PackedByteArray)
		_maybe_handle_request()


## Poll the socket and report whether it is connected with bytes to read.
## A dead connection is dropped here rather than leaking a half-open peer.
func _socket_has_data() -> bool:
	_peer.poll()
	var status := _peer.get_status()
	if status == StreamPeerTCP.STATUS_ERROR:
		_peer.disconnect_from_host()
		_peer = null
		return false
	if status != StreamPeerTCP.STATUS_CONNECTED:
		return false
	return _peer.get_available_bytes() > 0


## A request is complete once the header block ends with a blank line. We only
## need the first line, but browsers send the whole block.
func _maybe_handle_request() -> void:
	if _buffer.size() > MAX_REQUEST_BYTES:
		_reject_oversized_request()
		return
	var text := _buffer.get_string_from_utf8()
	if text.contains("\r\n"):
		_handle_request(text)


func _reject_oversized_request() -> void:
	_respond("Request too large", "درخواست بسیار بزرگ", false)
	_shutdown()
	failed.emit(&"auth.error.generic", "Oversized request on the loopback socket.")


func _handle_request(raw_request: String) -> void:
	var request_line := raw_request.split("\r\n", false)[0]
	var parts := request_line.split(" ")
	if parts.size() < 2 or not String(parts[0]).begins_with("GET"):
		_respond("Bad request", "PixelField", false)
		return

	var target := String(parts[1])
	var query_index := target.find("?")
	var query := {}
	if query_index >= 0:
		query = _parse_query(target.substr(query_index + 1))

	# Ignore the browser's automatic /favicon.ico probe.
	if query.is_empty() and not target.begins_with("/?") and target != "/":
		_respond("Not found", "PixelField", false)
		return

	if query.has("error"):
		var error_code := String(query["error"])
		_respond("Sign-in cancelled", "ورود لغو شد", false)
		_shutdown()
		if error_code == "access_denied":
			failed.emit(&"auth.error.cancelled", "Google returned access_denied.")
		else:
			failed.emit(&"auth.error.generic", "Google returned '%s'." % error_code)
		return

	if not query.has("code"):
		_respond("Missing authorisation code", "کد مجوز دریافت نشد", false)
		_shutdown()
		failed.emit(&"auth.error.generic", "Redirect carried no code parameter.")
		return

	if String(query.get("state", "")) != _expected_state:
		# A mismatch means somebody else answered our socket first. Never
		# exchange the code in that case.
		_respond("State mismatch", "عدم تطابق وضعیت", false)
		_shutdown()
		failed.emit(&"auth.error.generic", "OAuth state did not match.")
		return

	await _exchange_code(String(query["code"]))


func _parse_query(query: String) -> Dictionary:
	var result := {}
	for pair in query.split("&", false):
		var equals := pair.find("=")
		if equals < 0:
			continue
		var key := pair.substr(0, equals).uri_decode()
		var value := pair.substr(equals + 1).uri_decode()
		result[key] = value
	return result


# ------------------------------------------------------------ token exchange

func _exchange_code(code: String) -> void:
	progress.emit(&"auth.login.google_busy")
	var fields := {
		"client_id": client_id,
		"code": code,
		"code_verifier": _verifier,
		"grant_type": "authorization_code",
		"redirect_uri": redirect_uri(),
	}
	if not client_secret.strip_edges().is_empty():
		fields["client_secret"] = client_secret.strip_edges()
	var form := _form_encode(fields)
	var response := await _post_form(TOKEN_ENDPOINT, form)
	if not bool(response["ok"]):
		_respond("Could not complete sign-in", "تکمیل ورود ممکن نشد", false)
		var detail := String(response["detail"])
		if detail.contains("redirect_uri_mismatch"):
			_shutdown()
			failed.emit(&"auth.error.misconfigured", redirect_uri())
			return
		_shutdown()
		failed.emit(&"auth.error.bad_token", detail)
		return

	var payload: Dictionary = response["data"]
	var access_token := String(payload.get("access_token", ""))
	var id_token := String(payload.get("id_token", ""))
	if access_token.is_empty() or id_token.is_empty():
		_respond("Google returned no token", "گوگل توکنی برنگرداند", false)
		_shutdown()
		failed.emit(&"auth.error.bad_token", "Token response missing id_token/access_token.")
		return

	var account := await _fetch_userinfo(access_token)
	if account.is_empty():
		_respond("Could not read your profile", "خواندن پروفایل ممکن نشد", false)
		_shutdown()
		failed.emit(&"auth.error.bad_token", "Userinfo request failed.")
		return

	account["id_token"] = id_token
	account["access_token"] = access_token
	account["expires_in"] = int(payload.get("expires_in", 0))

	_respond("Signed in — you can close this tab", "ورود موفق — این پنجره را ببند", true)
	_shutdown()
	succeeded.emit(account)


func _fetch_userinfo(access_token: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray([
		"Authorization: Bearer " + access_token,
		"Accept: application/json",
	])
	var error := http.request(USERINFO_ENDPOINT, headers, HTTPClient.METHOD_GET)
	if error != OK:
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		return {}
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	var info := parsed as Dictionary
	return {
		"sub": String(info.get("sub", "")),
		"email": String(info.get("email", "")),
		"email_verified": bool(info.get("email_verified", false)),
		"name": String(info.get("name", "")),
		"given_name": String(info.get("given_name", "")),
		"picture": String(info.get("picture", "")),
		"locale": String(info.get("locale", "")),
	}


func _post_form(url: String, form: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var error := http.request(url, headers, HTTPClient.METHOD_POST, form)
	if error != OK:
		http.queue_free()
		return {"ok": false, "data": {}, "detail": "HTTPRequest error %d." % error}
	var response: Array = await http.request_completed
	http.queue_free()
	var body := (response[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(body)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "data": data, "detail": "Transport result %d." % int(response[0])}
	if int(response[1]) != 200:
		var message := String(data.get("error_description", data.get("error", body.substr(0, 200))))
		return {"ok": false, "data": data, "detail": "HTTP %d: %s" % [int(response[1]), message]}
	return {"ok": true, "data": data, "detail": ""}


func _form_encode(fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in fields:
		parts.append("%s=%s" % [key.uri_encode(), String(fields[key]).uri_encode()])
	return "&".join(parts)


# ------------------------------------------------------------------ response

## Answer the browser tab that Google redirected. The player sees this instead
## of a connection-refused page, which is the difference between "it worked"
## and "the app is broken".
func _respond(title: String, subtitle: String, success: bool) -> void:
	if _peer == null:
		return
	var accent := "#50e3a4" if success else "#ff6480"
	var body := """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PixelField</title></head>
<body style="margin:0;height:100vh;display:flex;align-items:center;justify-content:center;
background:#070b11;color:#e8eef5;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif">
<div style="text-align:center;padding:32px;max-width:420px">
<div style="width:64px;height:64px;margin:0 auto 24px;border-radius:16px;border:3px solid %s;
display:flex;align-items:center;justify-content:center;font-size:26px;font-weight:700;color:%s">H</div>
<h1 style="font-size:20px;margin:0 0 8px;font-weight:600">%s</h1>
<p dir="rtl" style="font-size:15px;margin:0;color:#8fa0b3">%s</p>
</div></body></html>""" % [accent, accent, title, subtitle]

	var payload := body.to_utf8_buffer()
	var header := "HTTP/1.1 200 OK\r\n" \
		+ "Content-Type: text/html; charset=utf-8\r\n" \
		+ "Cache-Control: no-store\r\n" \
		+ "Connection: close\r\n" \
		+ "Content-Length: %d\r\n\r\n" % payload.size()
	_peer.put_data(header.to_utf8_buffer())
	_peer.put_data(payload)
	# Give the kernel a moment to flush before we drop the socket, otherwise
	# some Android browsers render an empty page.
	await get_tree().create_timer(0.25).timeout
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null
