extends Node
## Local account/session state for the PixelLegends client shell.
##
## What this is: a *local* guest profile that survives an app restart, stored
## under `user://`. It is deliberately small and honest about its scope.
##
## What this is NOT: Nakama authentication. There is no backend call here, no
## token validation, no account linking and no Google sign-in. The hand-rolled
## direct-Google OAuth flow that used to live in this file was removed on
## 2026-10-14: docs/PROJECT_SPEC.txt sections 5, 6 and 31 require Google
## authentication to go through Nakama's supported flow, and an unverified
## browser OAuth token minted inside the game client is not that.
##
## When the authentication phase is approved, the correct replacement is the
## Nakama-backed design in the specification — not a revival of the old path.

const STORE_PATH := "user://auth.cfg"
const STORE_VERSION := 1

var state: int = GameTypes.AuthState.UNKNOWN
## Localised, ready to display. Empty when there is nothing wrong.
var last_error: String = ""

var _credential: Dictionary = {}
var _in_flight: bool = false


func _ready() -> void:
	_load_credential()


## Called by the boot screen once the UI exists, so the first state change is
## not emitted into a scene tree that has nobody listening yet.
func restore_session() -> void:
	if _in_flight:
		return
	_in_flight = true
	_set_state(GameTypes.AuthState.RESTORING)

	# A stored credential plus a readable local profile is the whole notion of
	# "signed in" that this build can actually honour.
	if not _credential.is_empty() and Session.has_profile():
		_in_flight = false
		_set_state(GameTypes.AuthState.SIGNED_IN)
		return

	# No credential, or a credential whose profile file was deleted: ask for a
	# fresh sign-in rather than inventing an identity.
	_in_flight = false
	_set_state(GameTypes.AuthState.SIGNED_OUT)


func is_signed_in() -> bool:
	return state == GameTypes.AuthState.SIGNED_IN


func is_busy() -> bool:
	return state == GameTypes.AuthState.SIGNING_IN or _in_flight


func provider() -> int:
	return Session.profile.provider if Session.profile != null else GameTypes.AuthProvider.NONE


# --------------------------------------------------------------- guest flow

## Create the local guest profile and remember it across restarts.
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
		"id_token_issued_at": int(Time.get_unix_time_from_system()),
	}
	_save_credential()
	EventBus.auth_signed_in.emit(profile)
	EventBus.toast_requested.emit(Loc.t(&"toast.guest_banner"), &"info")
	_set_state(GameTypes.AuthState.SIGNED_IN)


# ----------------------------------------------------------------- sign-out

## Forget the local guest profile. The caller decides where to navigate next.
func sign_out() -> void:
	_set_state(GameTypes.AuthState.SIGNING_OUT)
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE_PATH))
	_credential.clear()
	Session.clear_profile()
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
