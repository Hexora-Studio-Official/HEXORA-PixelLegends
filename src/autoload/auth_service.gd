extends Node
## Legacy account/session scaffolding retained from the earlier client.
## The current UI exposes only local Guest entry; this is not a Nakama-backed
## account system. The future Google/Guest architecture, backend authority, and
## account-linking requirements are defined in docs/PROJECT_SPEC.txt. Do not
## activate the old direct-Google/API paths before the approved authentication
## phase. Local credentials are stored under user:// and are not cloud accounts.

const STORE_PATH := "user://auth.cfg"
const STORE_VERSION := 1

var state: int = GameTypes.AuthState.UNKNOWN
## Localised, ready to display. Empty when there is nothing wrong.
var last_error: String = ""
## True when the current session came from Google but was *not* verified by a
## backend. The UI shows a subtle warning; nothing else may assume trust.
var unverified_remote: bool = false

var _google: GoogleSignIn
var _credential: Dictionary = {}
var _in_flight: bool = false


func _ready() -> void:
	_google = GoogleSignIn.new()
	_google.name = "GoogleSignIn"
	add_child(_google)
	_google.progress.connect(_on_google_progress)
	_google.succeeded.connect(_on_google_succeeded)
	_google.failed.connect(_on_google_failed)
	_load_credential()


## Called by the boot screen once the UI exists, so the first state change is
## not emitted into a scene tree that has nobody listening yet.
func restore_session() -> void:
	if _in_flight:
		return
	_in_flight = true
	_set_state(GameTypes.AuthState.RESTORING)

	if _credential.is_empty():
		_in_flight = false
		_set_state(GameTypes.AuthState.SIGNED_OUT)
		return

	# A stored credential with a live profile on disk: trust it for local play
	# immediately, then refresh from the backend if one exists.
	if Session.has_profile():
		if Api.is_configured():
			Api.auth_token = String(_credential.get("access_token", ""))
			var result := await Api.fetch_profile()
			if bool(result["ok"]) and result["data"] is Dictionary:
				Session.merge_from_remote(result["data"])
			elif result["error"] == &"offline":
				_last_error_is_network(true)
		_in_flight = false
		_set_state(GameTypes.AuthState.SIGNED_IN)
		return

	_in_flight = false
	# Credential present but no profile (the file was deleted): force a fresh
	# sign-in rather than inventing an identity.
	if Api.is_configured():
		Api.auth_token = String(_credential.get("access_token", ""))
		var result := await Api.fetch_profile()
		if bool(result["ok"]) and result["data"] is Dictionary:
			Session.set_profile(PlayerProfile.from_dict(result["data"]))
			_set_state(GameTypes.AuthState.SIGNED_IN)
			return
	_set_state(GameTypes.AuthState.SIGNED_OUT)


func is_signed_in() -> bool:
	return state == GameTypes.AuthState.SIGNED_IN


func is_busy() -> bool:
	return state == GameTypes.AuthState.SIGNING_IN or _in_flight


func provider() -> int:
	return Session.profile.provider if Session.profile != null else GameTypes.AuthProvider.NONE


## True when the redirect URI should be shown to the developer, i.e. sign-in
## cannot even start because nothing is configured.
func google_is_configured() -> bool:
	return not Settings.get_string("dev/google_client_id").strip_edges().is_empty()


static func expected_redirect_uri() -> String:
	return GoogleSignIn.default_redirect_uri()


# -------------------------------------------------------------- Google flow

func sign_in_with_google() -> void:
	if state == GameTypes.AuthState.SIGNING_IN:
		return
	if not google_is_configured():
		_fail(&"auth.error.not_configured")
		return
	last_error = ""
	_set_state(GameTypes.AuthState.SIGNING_IN)
	_google.client_id = Settings.get_string("dev/google_client_id").strip_edges()
	_google.client_secret = Settings.get_string("dev/google_client_secret").strip_edges()
	_google.start()


## Abort a sign-in the player walked away from.
func cancel_google_sign_in() -> void:
	if _google.is_running():
		_google.cancel()


func _on_google_progress(message_key: StringName) -> void:
	EventBus.toast_requested.emit(Loc.t(message_key), &"info")


func _on_google_succeeded(account: Dictionary) -> void:
	var profile := PlayerProfile.new()
	profile.provider = GameTypes.AuthProvider.GOOGLE
	profile.is_guest = false
	profile.email = String(account.get("email", ""))
	profile.avatar_url = String(account.get("picture", ""))
	profile.display_name = _clean_name(String(account.get("name", "")))
	profile.created_at = int(Time.get_unix_time_from_system())
	profile.accepted_terms_version = Settings.get_int("game/terms_version", 1)

	var id_token := String(account.get("id_token", ""))
	var access_token := String(account.get("access_token", ""))

	if Api.is_configured():
		# The backend verifies the token and returns the authoritative profile.
		var result := await Api.authenticate_google(
			id_token, profile.display_name, Settings.get_int("game/region")
		)
		if bool(result["ok"]) and result["data"] is Dictionary:
			var remote: Dictionary = result["data"]
			profile.uid = String(remote.get("uid", "google-%s" % String(account.get("sub", ""))))
			Api.auth_token = String(remote.get("access_token", access_token))
			unverified_remote = false
			Session.merge_from_remote(remote)
		else:
			# Backend refused or was unreachable. Fall back to the local
			# profile and be explicit that it is unverified.
			profile.uid = "google-local-%s" % String(account.get("sub", ""))
			unverified_remote = true
	else:
		# Legacy direct-Google fallback. The current UI does not call this path;
		# a local/unverified profile is not Nakama authentication and must never
		# gate security-sensitive behavior.
		profile.uid = "google-local-%s" % String(account.get("sub", ""))
		unverified_remote = true

	if profile.created_at == 0:
		profile.created_at = int(Time.get_unix_time_from_system())
	Session.set_profile(profile)

	_credential = {
		"version": STORE_VERSION,
		"provider": "google",
		"sub": String(account.get("sub", "")),
		"email": profile.email,
		"access_token": access_token,
		"id_token_issued_at": int(Time.get_unix_time_from_system()),
	}
	_save_credential()

	EventBus.auth_signed_in.emit(profile)
	_set_state(GameTypes.AuthState.SIGNED_IN)
	if unverified_remote:
		# Signed in with Google, but no backend confirmed it. Say exactly that
		# instead of implying the player should link an account they just used.
		EventBus.toast_requested.emit(Loc.t(&"toast.local_account"), &"info")
	else:
		EventBus.toast_requested.emit(Loc.t(&"toast.welcome"), &"success")


func _on_google_failed(message_key: StringName, detail: String) -> void:
	if not detail.is_empty():
		push_warning("Auth: Google sign-in failed — %s" % detail)
	_fail(message_key)


## Google sometimes returns a full name with markup-ish whitespace; normalize
## the display name to a compact player-facing form.
func _clean_name(raw_name: String) -> String:
	var cleaned := raw_name.strip_edges()
	if cleaned.is_empty():
		return PlayerProfile._random_player_name()
	var first := cleaned.split(" ")[0]
	if first.length() > 16:
		first = first.substr(0, 16)
	if first.length() < 3:
		return PlayerProfile._random_player_name()
	return first


# --------------------------------------------------------------- guest flow

func sign_in_as_guest(player_name: String = "") -> void:
	last_error = ""
	_set_state(GameTypes.AuthState.SIGNING_IN)
	var profile := PlayerProfile.create_guest(player_name)
	profile.accepted_terms_version = Settings.get_int("game/terms_version", 1)
	Session.set_profile(profile)
	_credential = {
		"version": STORE_VERSION,
		"provider": "guest",
		"sub": profile.uid,
		"access_token": "",
		"id_token_issued_at": int(Time.get_unix_time_from_system()),
	}
	_save_credential()
	unverified_remote = false
	EventBus.auth_signed_in.emit(profile)
	EventBus.toast_requested.emit(Loc.t(&"toast.guest_banner"), &"info")
	_set_state(GameTypes.AuthState.SIGNED_IN)


## Promote a guest session in place, keeping stats and unlocks.
func upgrade_guest() -> void:
	sign_in_with_google()


# ----------------------------------------------------------------- sign-out

func sign_out() -> void:
	if _google.is_running():
		_google.cancel()
	_set_state(GameTypes.AuthState.SIGNING_OUT)
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE_PATH))
	_credential.clear()
	Api.auth_token = ""
	Session.clear_profile()
	unverified_remote = false
	EventBus.auth_signed_out.emit()
	EventBus.toast_requested.emit(Loc.t(&"toast.signed_out"), &"info")
	_set_state(GameTypes.AuthState.SIGNED_OUT)


# ------------------------------------------------------------- credentials

func _save_credential() -> void:
	var config := ConfigFile.new()
	for key: String in _credential:
		config.set_value("auth", key, _credential[key])
	var error := config.save(STORE_PATH)
	if error != OK:
		push_warning("Auth: could not write %s (error %d)." % [STORE_PATH, error])


func _load_credential() -> void:
	var config := ConfigFile.new()
	if config.load(STORE_PATH) != OK:
		return
	_credential = {}
	for key in config.get_section_keys("auth"):
		_credential[key] = config.get_value("auth", key)
	if int(_credential.get("version", 0)) != STORE_VERSION:
		# Unknown format: drop it and make the player sign in again rather than
		# half-trusting a file we no longer understand.
		_credential.clear()


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.auth_state_changed.emit(state)


func _fail(message_key: StringName) -> void:
	last_error = Loc.t(message_key)
	EventBus.auth_failed.emit(last_error)
	EventBus.toast_requested.emit(last_error, &"error")
	_set_state(GameTypes.AuthState.FAILED)


func _last_error_is_network(is_network: bool) -> void:
	if is_network:
		last_error = Loc.t(&"auth.error.network")
