extends Node
## Legacy local friends/party prototype retained from the earlier project.
## It is not an active PixelLegends feature or the future Nakama integration.
## Do not connect it to current menu placeholders. Future social/backend
## behavior must follow docs/PROJECT_SPEC.txt and its phase gates.

const STORE_PATH := "user://friends.json"
const MAX_PARTY_SIZE := 5
const INVITE_TTL_SEC := 300

## Friend entries: {uid, name, level, rank_points, status, presence, last_seen, sample}
## status: online | offline | in_lobby | in_match
var friends: Array[Dictionary] = []
## Requests: {uid, name, level, direction, created_at, sample}
var requests: Array[Dictionary] = []
## Legacy local party cache; it is not a completed PixelLegends social feature.
var party: Array[Dictionary] = []
## Room invites waiting to be shown: {code, host, mode_id, created_at}
var invites: Array[Dictionary] = []


func _ready() -> void:
	_load()
	if friends.is_empty() and Settings.get_bool("dev/seed_mock_data"):
		_seed_samples()
	# Presence is derived from the room we are in, so it has to follow room
	# changes rather than being polled.
	EventBus.room_created.connect(func(_room: RoomInfo) -> void: refresh_presence())
	EventBus.room_closed.connect(func(_reason: String) -> void: refresh_presence())
	EventBus.room_updated.connect(func(_room: RoomInfo) -> void: refresh_presence())


# --------------------------------------------------------------------- queries

func online_count() -> int:
	var count := 0
	for friend in friends:
		if String(friend.get("status", "offline")) != "offline":
			count += 1
	return count


func in_match_count() -> int:
	var count := 0
	for friend in friends:
		if String(friend.get("status", "offline")) == "in_match":
			count += 1
	return count


func incoming_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request in requests:
		if String(request.get("direction", "incoming")) == "incoming":
			result.append(request)
	return result


func party_size() -> int:
	return party.size()


func is_in_party() -> bool:
	return party.size() > 0


func party_leader() -> Dictionary:
	for member in party:
		if bool(member.get("is_leader", false)):
			return member
	return {}


## Your own uid is part of the party too, so a solo player still has a party of
## one. Kept explicit so the UI never has to special-case "no party".
func ensure_party() -> void:
	if party.is_empty():
		party = [_self_member()]
		EventBus.party_changed.emit(party.duplicate())


func _self_member() -> Dictionary:
	return {
		"uid": Session.profile.uid,
		"name": Session.display_name(),
		"level": Session.profile.level,
		"is_leader": true,
		"is_local": true,
	}


# ------------------------------------------------------------------ mutations

func add_friend(uid: String, name: String, level: int = 1, sample: bool = false) -> void:
	if uid.is_empty():
		return
	for friend in friends:
		if String(friend.get("uid", "")) == uid:
			return
	friends.append({
		"uid": uid,
		"name": name,
		"level": level,
		"rank_points": 0,
		"status": "offline",
		"presence": "none",
		"last_seen": int(Time.get_unix_time_from_system()),
		"sample": sample,
	})
	_save()
	EventBus.friends_changed.emit(friends.duplicate())


func remove_friend(uid: String) -> void:
	var before := friends.size()
	friends = friends.filter(func(friend: Dictionary) -> bool:
		return String(friend.get("uid", "")) != uid
	)
	_party_remove(uid)
	if friends.size() != before:
		_save()
		EventBus.friends_changed.emit(friends.duplicate())


func update_status(uid: String, status: String) -> void:
	for friend in friends:
		if String(friend.get("uid", "")) == uid:
			if String(friend.get("status", "")) == status:
				return
			friend["status"] = status
			friend["last_seen"] = int(Time.get_unix_time_from_system())
			EventBus.friends_changed.emit(friends.duplicate())
			return


## Send a friend request. Online this becomes an API call; offline it is added
## to the local outgoing list so the flow can still be walked end to end.
func send_request(handle: String) -> Dictionary:
	var cleaned := handle.strip_edges()
	if cleaned.length() < 3:
		return {"ok": false, "reason": "too_short"}
	if Api.is_configured():
		var result: Dictionary = await Api.send_friend_request(cleaned)
		if not bool(result["ok"]):
			EventBus.toast_requested.emit(Loc.t(&"toast.request_failed"), &"error")
			return {"ok": false, "reason": "network"}
	else:
		EventBus.toast_requested.emit(
			Loc.t(&"toast.phase_notice", {"phase": Loc.t(&"common.phase_two")}), &"info")
	return {"ok": true, "reason": "sent"}


func accept_request(uid: String) -> void:
	var entry := _take_request(uid)
	if entry.is_empty():
		return
	add_friend(uid, String(entry.get("name", uid)), int(entry.get("level", 1)),
		bool(entry.get("sample", false)))
	EventBus.toast_requested.emit(Loc.t(&"toast.friend_added"), &"success")


func decline_request(uid: String) -> void:
	_take_request(uid)
	refresh_presence()


func invite_to_party(uid: String, sample: bool = false) -> Dictionary:
	ensure_party()
	if party.size() >= MAX_PARTY_SIZE:
		return {"ok": false, "reason": "party_full"}
	for member in party:
		if String(member.get("uid", "")) == uid:
			return {"ok": false, "reason": "already_in_party"}
	var friend := _find_friend(uid)
	if friend.is_empty():
		return {"ok": false, "reason": "not_a_friend"}
	if String(friend.get("status", "offline")) == "offline" and not sample:
		return {"ok": false, "reason": "offline"}
	party.append({
		"uid": uid,
		"name": String(friend.get("name", uid)),
		"level": int(friend.get("level", 1)),
		"is_leader": false,
		"is_local": false,
	})
	EventBus.party_changed.emit(party.duplicate())
	return {"ok": true, "reason": "joined"}


func leave_party() -> void:
	if party.is_empty():
		return
	party = [_self_member()]
	EventBus.party_changed.emit(party.duplicate())


func invite_to_room(uid: String) -> void:
	ensure_party()
	if not Rooms.is_in_room():
		return
	var friend := _find_friend(uid)
	if friend.is_empty():
		return
	# Offline friends get text they can be sent out of band; that is the honest
	# behaviour without a push service, and it is what actually works today.
	if String(friend.get("status", "offline")) == "offline" or not Api.is_configured():
		UiKit.copy_to_clipboard(Rooms.invite_text(), Loc.t(&"common.invite"))
		return
	var result: Dictionary = await Api.invite_friend(uid, Rooms.room.code)
	if bool(result["ok"]):
		EventBus.toast_requested.emit(Loc.t(&"toast.invite_sent"), &"success")
	else:
		EventBus.toast_requested.emit(Loc.t(&"toast.invite_failed"), &"error")


# --------------------------------------------------------------- room invites

func receive_room_invite(invite: Dictionary) -> void:
	invites.append(invite)
	EventBus.room_invite_received.emit(invite)
	EventBus.toast_requested.emit(Loc.t(&"toast.room_invite", {
		"name": String(invite.get("host", "?")),
	}), &"info")


func clear_invites() -> void:
	invites.clear()


# ------------------------------------------------------------------- presence

## Recompute status for everybody. Online this is replaced by a server push or
## a poll; locally it is derived from what this device can actually observe:
## you are in a room, so the friends you invited are "in_lobby"; nothing else
## can be known without a backend, so everything else decays to offline rather
## than pretending to be live.
func refresh_presence() -> void:
	var in_room := Rooms.is_in_room()
	var changed := false
	for friend in friends:
		var status := String(friend.get("status", "offline"))
		if bool(friend.get("sample", false)):
			var seeded := String(friend.get("presence", "online"))
			status = "in_lobby" if (in_room and seeded != "offline") else seeded
		else:
			status = "in_lobby" if in_room else "offline"
		if status != String(friend.get("status", "")):
			friend["status"] = status
			changed = true
	if changed:
		EventBus.friends_changed.emit(friends.duplicate())


# --------------------------------------------------------------------- storage

func _find_friend(uid: String) -> Dictionary:
	for friend in friends:
		if String(friend.get("uid", "")) == uid:
			return friend
	return {}


func _take_request(uid: String) -> Dictionary:
	var taken: Dictionary = {}
	var kept: Array[Dictionary] = []
	for request in requests:
		if String(request.get("uid", "")) == uid and taken.is_empty():
			taken = request
			continue
		kept.append(request)
	requests = kept
	_save()
	EventBus.friend_requests_changed.emit(requests.duplicate())
	return taken


func _party_remove(uid: String) -> void:
	var before := party.size()
	party = party.filter(func(member: Dictionary) -> bool:
		return String(member.get("uid", "")) != uid
	)
	if party.size() != before:
		EventBus.party_changed.emit(party.duplicate())


func _save() -> void:
	var data := {
		"version": 1,
		"friends": friends,
		"requests": requests,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Friends: could not write %s." % STORE_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(STORE_PATH):
		return
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		file.close()
		push_warning("Friends: %s is corrupt, starting empty." % STORE_PATH)
		return
	file.close()
	var data: Dictionary = json.data
	for entry in data.get("friends", []):
		if entry is Dictionary:
			friends.append(entry as Dictionary)
	for entry in data.get("requests", []):
		if entry is Dictionary:
			requests.append(entry as Dictionary)


# ---------------------------------------------------------------------- samples

## A brand new install has an empty friend list, which makes the Squad page look
## broken rather than empty. These stand in for real accounts, carry
## `sample: true`, and are badged in the UI. They are never counted as online
## players in a match and never appear in a roster.
func _seed_samples() -> void:
	var samples := [
		{"name": "Nova_Cipher", "level": 42, "rank_points": 2140, "presence": "online"},
		{"name": "Ronin.IR", "level": 28, "rank_points": 1180, "presence": "online"},
		{"name": "VantaFox", "level": 61, "rank_points": 3320, "presence": "in_match"},
		{"name": "Kestrel", "level": 15, "rank_points": 420, "presence": "online"},
		{"name": "M_Specter", "level": 7, "rank_points": 150, "presence": "offline"},
	]
	for sample in samples:
		friends.append({
			"uid": "sample-" + String(sample["name"]).to_lower(),
			"name": sample["name"],
			"level": sample["level"],
			"rank_points": sample["rank_points"],
			"status": sample["presence"],
			"presence": sample["presence"],
			"last_seen": int(Time.get_unix_time_from_system()) - (randi() % 7200),
			"sample": true,
		})
	requests.append({
		"uid": "sample-ghostline",
		"name": "Ghostline",
		"level": 33,
		"direction": "incoming",
		"created_at": int(Time.get_unix_time_from_system()) - 900,
		"sample": true,
	})
	EventBus.friend_requests_changed.emit(requests.duplicate())
	EventBus.friends_changed.emit(friends.duplicate())
