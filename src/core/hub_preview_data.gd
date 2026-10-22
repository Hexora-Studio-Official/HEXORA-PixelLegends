class_name HubPreviewData
extends RefCounted
## Centralised preview state and original sample data for the PixelLegends
## main menu shell while the Nakama backend and match servers remain offline.
##
## Keeping all sample rosters, items, builds, social lists, chat logs, mail,
## events and rankings in one data module lets every panel read and mutate
## shared session state cleanly — and gives a single seam to wire backend RPCs
## into later without rewriting UI layouts.

signal changed

var coins: int = 14850
var gems: int = 460
var selected_mode_id: String = "league"
var ai_difficulty: int = 1
var room_privacy: int = 0
var queue_active: bool = false
var queue_seconds: float = 0.0
var downloads_paused: bool = false
var featured_hero_id: String = "valen"
var equipped_cosmetics: Dictionary = {
	"skin": "valen_royal",
	"recall": "astral_beam",
	"elim": "golden_shatter",
	"frame": "citadel_crest",
	"emote": "crown_salute",
}

## Slots 1..4 represent invited teammates (slot 0 is always the local player).
var lobby_teammates: Array[Dictionary] = [{}, {}, {}, {}]
var lobby_messages: Array[String] = [
	"[System] Party lobby ready. Invite up to 4 allies.",
]

var modes: Array[Dictionary] = []
var heroes: Array[Dictionary] = []
var items: Array[Dictionary] = []
var hero_builds: Dictionary = {}
var inventory: Array[Dictionary] = []
var collections: Dictionary = {}
var shop_offers: Array[Dictionary] = []
var download_packs: Array[Dictionary] = []
var mails: Array[Dictionary] = []
var chats: Dictionary = {}
var login_rewards: Array[Dictionary] = []
var quests: Array[Dictionary] = []
var friends: Array[Dictionary] = []
var followers: Array[Dictionary] = []
var following: Array[Dictionary] = []
var squad_info: Dictionary = {}
var squad_directory: Array[Dictionary] = []
var personal_mode_stats: Array[Dictionary] = []
var regional_leaders: Array[Dictionary] = []
var global_leaders: Array[Dictionary] = []


func _init() -> void:
	_seed_modes()
	_seed_heroes_and_items()
	_seed_inventory_and_collections()
	_seed_shop_and_events()
	_seed_comms_and_downloads()
	_seed_social_and_rankings()


func mode_by_id(mode_id: String) -> Dictionary:
	for entry in modes:
		if String(entry["id"]) == mode_id:
			return entry
	return modes[0]


func select_mode(mode_id: String) -> void:
	selected_mode_id = mode_id
	changed.emit()


func hero_by_id(hero_id: String) -> Dictionary:
	for hero in heroes:
		if String(hero["id"]) == hero_id:
			return hero
	return heroes[0]


func item_by_id(item_id: String) -> Dictionary:
	for item in items:
		if String(item["id"]) == item_id:
			return item
	return items[0]


func unread_mail_count() -> int:
	var count := 0
	for mail in mails:
		if not bool(mail["claimed"]):
			count += 1
	return count


func claim_mail(index: int) -> bool:
	if index < 0 or index >= mails.size():
		return false
	if bool(mails[index]["claimed"]):
		return false
	mails[index]["claimed"] = true
	coins += int(mails[index].get("coins", 0))
	gems += int(mails[index].get("gems", 0))
	changed.emit()
	return true


func claim_all_mail() -> int:
	var claimed_total := 0
	for idx in mails.size():
		if not bool(mails[idx]["claimed"]):
			mails[idx]["claimed"] = true
			coins += int(mails[idx].get("coins", 0))
			gems += int(mails[idx].get("gems", 0))
			claimed_total += 1
	if claimed_total > 0:
		changed.emit()
	return claimed_total


func claim_login_day(index: int) -> bool:
	if index < 0 or index >= login_rewards.size():
		return false
	if not bool(login_rewards[index]["ready"]) or bool(login_rewards[index]["claimed"]):
		return false
	login_rewards[index]["claimed"] = true
	coins += int(login_rewards[index].get("coins", 0))
	gems += int(login_rewards[index].get("gems", 0))
	changed.emit()
	return true


func claim_quest(index: int) -> bool:
	if index < 0 or index >= quests.size():
		return false
	if not bool(quests[index]["done"]) or bool(quests[index]["claimed"]):
		return false
	quests[index]["claimed"] = true
	coins += int(quests[index].get("coins", 0))
	changed.emit()
	return true


func invite_friend_to_lobby(friend_entry: Dictionary) -> bool:
	var uid := String(friend_entry.get("id", ""))
	for slot in lobby_teammates:
		if not slot.is_empty() and String(slot.get("id", "")) == uid:
			return false
	for idx in lobby_teammates.size():
		if lobby_teammates[idx].is_empty():
			lobby_teammates[idx] = friend_entry.duplicate(true)
			lobby_messages.append("[Lobby] %s joined your party." % String(friend_entry["name"]))
			changed.emit()
			return true
	return false


func remove_lobby_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= lobby_teammates.size():
		return
	if not lobby_teammates[slot_index].is_empty():
		var removed_name := String(lobby_teammates[slot_index].get("name", "Player"))
		lobby_teammates[slot_index] = {}
		lobby_messages.append("[Lobby] %s left the party." % removed_name)
		changed.emit()


func is_in_lobby(friend_id: String) -> bool:
	for slot in lobby_teammates:
		if not slot.is_empty() and String(slot.get("id", "")) == friend_id:
			return true
	return false


func send_chat(channel: String, sender: String, text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	if not chats.has(channel):
		chats[channel] = []
	var list: Array = chats[channel]
	list.append({"sender": sender, "tag": "YOU", "text": clean})
	changed.emit()


func latest_world_message() -> String:
	var list: Array = chats.get("world", [])
	if list.is_empty():
		return "Welcome to PixelLegends!"
	var last: Dictionary = list[list.size() - 1]
	return "[%s]: %s" % [String(last["sender"]), String(last["text"])]


func toggle_follow_user(entry: Dictionary) -> void:
	var target_name := String(entry.get("name", ""))
	for idx in following.size():
		if String(following[idx]["name"]) == target_name:
			following.remove_at(idx)
			entry["is_following"] = false
			changed.emit()
			return
	entry["is_following"] = true
	following.append({
		"id": String(entry.get("id", "pl_" + str(following.size() + 50))),
		"name": target_name,
		"rank": String(entry.get("rank", "Gold II")),
		"status": String(entry.get("status", "Online")),
		"online": bool(entry.get("online", true)),
		"is_following": true,
	})
	changed.emit()


func _seed_modes() -> void:
	modes = [
		{
			"id": "classic",
			"name": "CLASSIC",
			"subtitle": "5v5 Three-Lane Standard Arena",
			"badge": "CASUAL 5V5",
			"icon": &"swords",
			"accent": Color("36d6ff"),
			"lanes": "3 Lanes + Jungle",
			"duration": "12–18 min",
			"summary": "Full three-lane 5v5 battle with towers, jungle buffs, and base siege without League rank risk.",
		},
		{
			"id": "league",
			"name": "LEAGUE",
			"subtitle": "Competitive Ranked Season 1",
			"badge": "RANKED TIER · GOLD II",
			"icon": &"crown",
			"accent": Color("f6c445"),
			"lanes": "3 Lanes · Draft Rules",
			"duration": "15–22 min",
			"summary": "Climb regional and global tiers from Bronze to Hexcore Elite in official 5v5 competitive matches.",
		},
		{
			"id": "dead_field",
			"name": "DEAD FIELD",
			"subtitle": "Single-Lane Relentless Team Clash",
			"badge": "FAST BRAWL 5V5",
			"icon": &"skull",
			"accent": Color("ff5263"),
			"lanes": "1 Bridge Lane · Random Roll",
			"duration": "6–10 min",
			"summary": "Non-stop 5v5 single-lane showdown with accelerated gold, dual random hero picks, and instant teamfights.",
		},
		{
			"id": "vs_ai",
			"name": "VS AI",
			"subtitle": "5v5 Tactical Bot Training",
			"badge": "CO-OP TRAINING",
			"icon": &"bot",
			"accent": Color("3be38a"),
			"lanes": "3 Lanes · Custom AI Tier",
			"duration": "10–15 min",
			"summary": "Master new heroes, test 6-slot item builds, and practise lane rotations against configurable AI opponents.",
		},
	]


func _seed_heroes_and_items() -> void:
	heroes = [
		{
			"id": "valen", "name": "Valen Dawnshield", "role": "Tank",
			"specialty": "Initiator / Crowd Control", "lane": "Roam / Exp",
			"owned": true, "cost_coins": 0, "tier_color": Color("36d6ff"),
			"hp": 3420, "atk": 118, "def": 68, "speed": 260,
			"passive": "Citadel Aegis — Nearby allies gain +12 armor whenever Valen blocks a projectile.",
			"skill_1": "Radiant Charge — Dashes forward, stunning the first enemy hero hit for 0.9s.",
			"skill_2": "Bastion Ring — Slams shield to slow enemies in a 4m radius by 40%.",
			"ultimate": "Sovereign Sanctuary — Summons a golden prism dome reducing team damage taken by 35%.",
		},
		{
			"id": "kael", "name": "Kael Emberblade", "role": "Fighter",
			"specialty": "Burst / Duelist", "lane": "Exp Lane",
			"owned": true, "cost_coins": 0, "tier_color": Color("ff9f43"),
			"hp": 2890, "atk": 146, "def": 46, "speed": 268,
			"passive": "Cinder Marks — Every 3rd basic strike ignites target for bonus true damage.",
			"skill_1": " Crimson Slash — Cleaves in an arc and restores 8% missing HP on hero hit.",
			"skill_2": " Molten Step — Blinks behind a target and grants +25% attack speed.",
			"ultimate": "Infernal Judgment — Leaps to an area, dealing heavy AoE physical burst.",
		},
		{
			"id": "lyra", "name": "Lyra Starweaver", "role": "Mage",
			"specialty": "Poke / Control", "lane": "Mid Lane",
			"owned": true, "cost_coins": 0, "tier_color": Color("b270ff"),
			"hp": 2380, "atk": 112, "def": 28, "speed": 252,
			"passive": "Astral Resonance — Spell hits grant +4% movement speed stacking 3 times.",
			"skill_1": "Comet Lance — Fires a piercing starlight bolt through all units in line.",
			"skill_2": "Gravity Well — Pulls enemies toward the centre after a brief delay.",
			"ultimate": "Celestial Tempest — Calls 5 starfall waves across a wide target zone.",
		},
		{
			"id": "rowan", "name": "Rowan Swiftarrow", "role": "Marksman",
			"specialty": "Crit DPS / Siege", "lane": "Gold Lane",
			"owned": true, "cost_coins": 0, "tier_color": Color("f6c445"),
			"hp": 2310, "atk": 154, "def": 25, "speed": 255,
			"passive": "Windfocus — Consecutive attacks extend range up to +15%.",
			"skill_1": "Volley Fan — Fires 5 arrows in a cone that apply slow.",
			"skill_2": "Gale Vault — Backflips away from danger while firing a crit bolt.",
			"ultimate": "Sunpiercer Arrow — Global snipe arrow whose damage scales with distance.",
		},
		{
			"id": "nyx", "name": "Nyx Shadowfang", "role": "Assassin",
			"specialty": "Reap / Mobility", "lane": "Jungle",
			"owned": false, "cost_coins": 12000, "tier_color": Color("ff5263"),
			"hp": 2440, "atk": 162, "def": 30, "speed": 275,
			"passive": "Dusk Ambush — Leaving brush empowers the next strike with +35% penetration.",
			"skill_1": "Twin Daggers — Throws two blades that return to Nyx's position.",
			"skill_2": "Phantom Blink — Short dash that resets on hero takedown.",
			"ultimate": "Eclipse Execution — Marks an enemy and strikes untargetably 4 times.",
		},
		{
			"id": "sylva", "name": "Sylva Verdant", "role": "Support",
			"specialty": "Healer / Guard", "lane": "Roam",
			"owned": false, "cost_coins": 8000, "tier_color": Color("3be38a"),
			"hp": 2620, "atk": 104, "def": 38, "speed": 258,
			"passive": "Living Dew — Nearby lowest-HP ally regenerates health steadily.",
			"skill_1": "Bloom Pulse — Heals an ally and damages adjacent enemies.",
			"skill_2": "Vine Snare — Roots the first enemy champion struck for 1.2s.",
			"ultimate": "Canopy Blessing — Grants global shield and cleanse to all teammates.",
		},
	]

	items = [
		{
			"id": "sunblade", "name": "Sunforged Blade", "cat": "Attack", "cost": 2150,
			"stats": "+75 Physical ATK · +15% Lifesteal",
			"passive": "Basic attacks grant +4% movement speed.",
		},
		{
			"id": "stormbow", "name": "Tempest Recurve", "cat": "Attack", "cost": 2020,
			"stats": "+40% Attack Speed · +20% Crit Rate",
			"passive": "Every 3rd hit chains lightning for 110 magic dmg.",
		},
		{
			"id": "voidedge", "name": "Obsidian Reaver", "cat": "Attack", "cost": 2380,
			"stats": "+85 Physical ATK · +35% Armor Pen",
			"passive": "Deals up to 12% extra damage against high-HP tanks.",
		},
		{
			"id": "starprism", "name": "Starlight Prism", "cat": "Magic", "cost": 2100,
			"stats": "+105 Magic Power · +10% Cooldown",
			"passive": "Abilities burn targets for 3% max HP over 3s.",
		},
		{
			"id": "chrono_orb", "name": "Chrono Scepter", "cat": "Magic", "cost": 1950,
			"stats": "+75 Magic Power · +400 HP · +15% CDR",
			"passive": "Restores 12% max Mana on hero assist or kill.",
		},
		{
			"id": "citadel_plate", "name": "Citadel Cuirass", "cat": "Defense", "cost": 2120,
			"stats": "+920 HP · +58 Physical Defense",
			"passive": "Reduces attacker's attack speed by 15% when hit.",
		},
		{
			"id": "aegis_cloak", "name": "Astral Cloak", "cat": "Defense", "cost": 2060,
			"stats": "+850 HP · +54 Magic Defense",
			"passive": "Grants an absorbing magic shield every 25s.",
		},
		{
			"id": "swift_greaves", "name": "Vanguard Boots", "cat": "Movement", "cost": 720,
			"stats": "+40 Move Speed · +22 Physical Defense",
			"passive": "Reduces incoming basic attack damage by 8%.",
		},
		{
			"id": "arcane_boots", "name": "Arcane Treads", "cat": "Movement", "cost": 710,
			"stats": "+40 Move Speed · +12 Magic Pen",
			"passive": "Enhances early-lane spell penetration.",
		},
		{
			"id": "roam_crest", "name": "Herald Emblem", "cat": "Roam", "cost": 650,
			"stats": "+300 HP · +8% Team Move Speed",
			"passive": "Devotion: grants gold and XP while assisting lane partner.",
		},
	]

	hero_builds = {
		"valen": [
			{"title": "Citadel Main Tank", "slots": ["swift_greaves", "roam_crest", "citadel_plate", "aegis_cloak", "chrono_orb", "sunblade"]},
			{"title": "Aggressive Initiator", "slots": ["swift_greaves", "citadel_plate", "sunblade", "aegis_cloak", "voidedge", "roam_crest"]},
		],
		"kael": [
			{"title": "Burst Duelist", "slots": ["swift_greaves", "sunblade", "voidedge", "citadel_plate", "aegis_cloak", "stormbow"]},
			{"title": "Sustained Bruiser", "slots": ["swift_greaves", "sunblade", "citadel_plate", "aegis_cloak", "voidedge", "chrono_orb"]},
		],
		"lyra": [
			{"title": "Arcane Burst Mid", "slots": ["arcane_boots", "starprism", "chrono_orb", "aegis_cloak", "starprism", "citadel_plate"]},
		],
		"rowan": [
			{"title": "Hyper Crit Carry", "slots": ["swift_greaves", "stormbow", "sunblade", "voidedge", "stormbow", "aegis_cloak"]},
		],
		"nyx": [
			{"title": "Jungle Assassin", "slots": ["swift_greaves", "voidedge", "sunblade", "stormbow", "aegis_cloak", "citadel_plate"]},
		],
		"sylva": [
			{"title": "Aura Protector", "slots": ["arcane_boots", "roam_crest", "chrono_orb", "aegis_cloak", "citadel_plate", "starprism"]},
		],
	}


func _seed_inventory_and_collections() -> void:
	inventory = [
		{
			"name": "Double Battle Coins Card (3-Match)", "cat": "Consumables", "qty": 4,
			"desc": "Increases Battle Coins earned after match completion by 100%.",
		},
		{
			"name": "League Star Protection Shard", "cat": "Consumables", "qty": 2,
			"desc": "Prevents one star loss when defeated in a League match.",
		},
		{
			"name": "Nyx Shadowfang (3-Day Trial)", "cat": "Trials", "qty": 1,
			"desc": "Unlocks Assassin hero Nyx in Classic and VS AI modes for 72 hours.",
		},
		{
			"name": "Sovereign Skin Trial Pack", "cat": "Trials", "qty": 3,
			"desc": "Grants temporary access to an Epic-tier Citadel skin.",
		},
		{
			"name": "Season 1 Founder Chest", "cat": "Chests", "qty": 2,
			"desc": "Contains Battle Coins, Hero Fragments, or an Avatar Frame.",
		},
		{
			"name": "Hero Emblem Fragment", "cat": "Chests", "qty": 38,
			"desc": "Collect 50 fragments to exchange for an owned hero upgrade.",
		},
	]

	collections = {
		"skin": [
			{"id": "valen_royal", "name": "Valen — Imperial Vanguard", "rarity": "EPIC", "owned": true},
			{"id": "kael_ash", "name": "Kael — Volcanic Sovereign", "rarity": "RARE", "owned": true},
			{"id": "lyra_eclipse", "name": "Lyra — Nebula Empress", "rarity": "LEGENDARY", "owned": false},
		],
		"recall": [
			{"id": "astral_beam", "name": "Astral Spire Recall", "rarity": "EPIC", "owned": true},
			{"id": "emerald_ring", "name": "Verdant Rune Recall", "rarity": "RARE", "owned": true},
			{"id": "solar_flare", "name": "Solar Crown Recall", "rarity": "LEGENDARY", "owned": false},
		],
		"elim": [
			{"id": "golden_shatter", "name": "Golden Pixel Burst", "rarity": "EPIC", "owned": true},
			{"id": "cyan_nova", "name": "Arcane Shockwave", "rarity": "RARE", "owned": true},
		],
		"frame": [
			{"id": "citadel_crest", "name": "Citadel Pioneer Border", "rarity": "EPIC", "owned": true},
			{"id": "league_gold", "name": "Season 1 Gold Border", "rarity": "RARE", "owned": true},
		],
		"emote": [
			{"id": "crown_salute", "name": "GG Well Played!", "rarity": "COMMON", "owned": true},
			{"id": "focus_tower", "name": "Push Nexus!", "rarity": "RARE", "owned": true},
		],
	}


func _seed_shop_and_events() -> void:
	shop_offers = [
		{
			"id": "offer_starter", "tab": "Featured", "name": "Citadel Founder Bundle",
			"desc": "Includes 2 Heroes + Imperial Recall FX + 2,000 Coins.",
			"currency": "gems", "price": 180, "bought": false,
		},
		{
			"id": "offer_chest", "tab": "Featured", "name": "Arcane Supply Crate ×5",
			"desc": "Guaranteed Rare cosmetic or 1,500 Battle Coins.",
			"currency": "coins", "price": 2400, "bought": false,
		},
		{
			"id": "offer_nyx", "tab": "Heroes", "name": "Hero: Nyx Shadowfang",
			"desc": "High-mobility Jungle Assassin hero license.",
			"currency": "coins", "price": 12000, "bought": false,
		},
		{
			"id": "offer_sylva", "tab": "Heroes", "name": "Hero: Sylva Verdant",
			"desc": "Team-wide shield and healing Roam Support hero.",
			"currency": "coins", "price": 8000, "bought": false,
		},
		{
			"id": "offer_skin_lyra", "tab": "Skins", "name": "Lyra — Nebula Empress",
			"desc": "Full starlight VFX overhaul and custom voice lines.",
			"currency": "gems", "price": 299, "bought": false,
		},
		{
			"id": "offer_skin_kael", "tab": "Skins", "name": "Kael — Crimson Shogun",
			"desc": "Micro-pixel molten blade trail and custom recall stance.",
			"currency": "gems", "price": 199, "bought": false,
		},
	]

	login_rewards = [
		{"day": "Day 1", "reward": "800 Coins", "coins": 800, "gems": 0, "ready": true, "claimed": true},
		{"day": "Day 2", "reward": "40 Gems", "coins": 0, "gems": 40, "ready": true, "claimed": false},
		{"day": "Day 3", "reward": "1,200 Coins", "coins": 1200, "gems": 0, "ready": true, "claimed": false},
		{"day": "Day 4", "reward": "Hero Trial Pack", "coins": 500, "gems": 0, "ready": false, "claimed": false},
		{"day": "Day 5", "reward": "60 Gems", "coins": 0, "gems": 60, "ready": false, "claimed": false},
		{"day": "Day 6", "reward": "2,000 Coins", "coins": 2000, "gems": 0, "ready": false, "claimed": false},
		{"day": "Day 7", "reward": "Epic Skin Chest", "coins": 0, "gems": 120, "ready": false, "claimed": false},
	]

	quests = [
		{"title": "Sign in to PixelLegends Hub", "progress": "1 / 1", "coins": 500, "done": true, "claimed": false},
		{"title": "Customize a 6-Item Hero Build", "progress": "1 / 1", "coins": 650, "done": true, "claimed": false},
		{"title": "Complete 1 Classic or League Match", "progress": "0 / 1 (Server Offline)", "coins": 1000, "done": false, "claimed": false},
		{"title": "Team up in a 5v5 Squad Lobby", "progress": "1 / 1", "coins": 450, "done": true, "claimed": false},
	]


func _seed_comms_and_downloads() -> void:
	download_packs = [
		{"name": "Core UI & Micro-Pixel Shaders", "size": "184 MB / 184 MB", "progress": 1.0, "status": "Installed"},
		{"name": "3D Hero High-Res Textures Pack", "size": "412 MB / 520 MB", "progress": 0.79, "status": "Downloading"},
		{"name": "5v5 Three-Lane Citadel Arena Assets", "size": "205 MB / 380 MB", "progress": 0.54, "status": "Queued"},
		{"name": "Hero Voiceovers & Announcer Pack", "size": "96 MB / 160 MB", "progress": 0.60, "status": "Queued"},
	]

	mails = [
		{
			"title": "Welcome to PixelLegends Pre-Alpha!",
			"sender": "HEXORA STUDIO",
			"date": "Today",
			"body": "Thank you for testing the new PixelLegends MOBA client shell. Claim your starter Battle Coins & Arcane Gems below!",
			"coins": 1500,
			"gems": 80,
			"claimed": false,
		},
		{
			"title": "Season 1 League Rules Overview",
			"sender": "League Operations",
			"date": "Yesterday",
			"body": "League mode replaces Ranked tiers, and Dead Field brings fast 5v5 single-lane brawls once dedicated servers go live.",
			"coins": 600,
			"gems": 20,
			"claimed": false,
		},
		{
			"title": "Server Maintenance & Phase Roadmap",
			"sender": "System Notice",
			"date": "2d ago",
			"body": "Dedicated Godot authoritative match servers and Nakama authentication are scheduled for upcoming milestones.",
			"coins": 400,
			"gems": 0,
			"claimed": true,
		},
	]

	chats = {
		"world": [
			{"sender": "AetherKnight", "tag": "GOLD I", "text": "Need 1 Tank/Roam for 5v5 League lobby!"},
			{"sender": "NovaArrow", "tag": "PLAT IV", "text": "Dead Field single-lane mode is going to be intense."},
			{"sender": "KaelMain99", "tag": "GOLD II", "text": "Anyone testing Valen tank builds tonight?"},
		],
		"region": [
			{"sender": "ZephyrEU", "tag": "DIAMOND", "text": "Looking for active squad members — daily quests!"},
			{"sender": "Runeblade", "tag": "SILVER I", "text": "Drop an invite for VS AI build testing."},
		],
		"squad": [
			{"sender": "AstraCaptain", "tag": "LEADER", "text": "Welcome to Hexora Vanguard! Check weekly squad tasks."},
		],
		"friends": [
			{"sender": "MiraStar", "tag": "FRIEND", "text": "Ping me when you open a 5v5 lobby!"},
		],
	}


func _seed_social_and_rankings() -> void:
	friends = [
		{"id": "f_mira", "name": "MiraStar", "rank": "Platinum IV", "role": "Mage", "status": "Online · In Hub", "online": true, "is_following": true},
		{"id": "f_aether", "name": "AetherKnight", "rank": "Gold I", "role": "Tank", "status": "Online · Ready", "online": true, "is_following": true},
		{"id": "f_nova", "name": "NovaArrow", "rank": "Diamond III", "role": "Marksman", "status": "Online · In Hub", "online": true, "is_following": true},
		{"id": "f_vex", "name": "VexShadow", "rank": "Gold II", "role": "Assassin", "status": "In VS AI Match", "online": true, "is_following": false},
		{"id": "f_sol", "name": "SolGuardian", "rank": "Silver I", "role": "Support", "status": "Offline · 3h ago", "online": false, "is_following": true},
	]

	followers = [
		{"id": "fl_1", "name": "MiraStar", "rank": "Platinum IV", "status": "Online", "online": true, "is_following": true},
		{"id": "fl_2", "name": "CrimsonVow", "rank": "Gold III", "status": "Online", "online": true, "is_following": false},
		{"id": "fl_3", "name": "Pixel Warden", "rank": "Diamond II", "status": "Offline", "online": false, "is_following": false},
		{"id": "fl_4", "name": "AetherKnight", "rank": "Gold I", "status": "Online", "online": true, "is_following": true},
	]

	following = [
		{"id": "f_mira", "name": "MiraStar", "rank": "Platinum IV", "status": "Online", "online": true, "is_following": true},
		{"id": "f_aether", "name": "AetherKnight", "rank": "Gold I", "status": "Online", "online": true, "is_following": true},
		{"id": "f_nova", "name": "NovaArrow", "rank": "Diamond III", "status": "Online", "online": true, "is_following": true},
		{"id": "f_sol", "name": "SolGuardian", "rank": "Silver I", "status": "Offline", "online": false, "is_following": true},
	]

	squad_info = {
		"name": "Hexora Vanguard",
		"tag": "HXR",
		"level": 5,
		"members_count": "18 / 30",
		"weekly_activity": "4,620 / 5,000",
		"motto": "Coordinated 5v5 League & Dead Field squad. Active daily!",
		"members": [
			{"name": "AstraCaptain", "role": "Leader", "rank": "Ascendant II", "points": 980},
			{"name": "MiraStar", "role": "Officer", "rank": "Platinum IV", "points": 840},
			{"name": "AetherKnight", "role": "Elite", "rank": "Gold I", "points": 720},
			{"name": "NovaArrow", "role": "Member", "rank": "Diamond III", "points": 690},
		],
	}

	squad_directory = [
		{"name": "Citadel Titans", "tag": "CTN", "members": "27 / 30", "req": "Gold+"},
		{"name": "Astral Wolves", "tag": "AWV", "members": "22 / 30", "req": "Open"},
		{"name": "Obsidian Crown", "tag": "OBC", "members": "29 / 30", "req": "Diamond+"},
	]

	personal_mode_stats = [
		{"mode": "All Modes", "matches": 48, "win_rate": "62.5%", "kda": "4.28", "mvp": 14},
		{"mode": "League", "matches": 24, "win_rate": "66.7%", "kda": "4.65", "mvp": 8},
		{"mode": "Classic", "matches": 14, "win_rate": "57.1%", "kda": "3.80", "mvp": 4},
		{"mode": "Dead Field", "matches": 7, "win_rate": "57.1%", "kda": "5.10", "mvp": 2},
		{"mode": "VS AI", "matches": 3, "win_rate": "100%", "kda": "9.40", "mvp": 3},
	]

	regional_leaders = [
		{"place": 1, "name": "ZephyrEU", "squad": "[HXR]", "tier": "Hexcore Elite", "points": "1,840 pts", "win": "68%"},
		{"place": 2, "name": "ValkyriePrime", "squad": "[OBC]", "tier": "Ascendant I", "points": "1,690 pts", "win": "64%"},
		{"place": 3, "name": "AstraCaptain", "squad": "[HXR]", "tier": "Ascendant II", "points": "1,540 pts", "win": "63%"},
		{"place": 4, "name": "NovaArrow", "squad": "[HXR]", "tier": "Diamond III", "points": "1,290 pts", "win": "61%"},
		{"place": 5, "name": "MiraStar", "squad": "[HXR]", "tier": "Platinum IV", "points": "1,080 pts", "win": "59%"},
	]

	global_leaders = [
		{"place": 1, "name": "SovereignZero", "squad": "[KOR]", "tier": "Hexcore Elite", "points": "2,640 pts", "win": "74%"},
		{"place": 2, "name": "CelestialBlade", "squad": "[APEX]", "tier": "Hexcore Elite", "points": "2,510 pts", "win": "71%"},
		{"place": 3, "name": "MythicRowan", "squad": "[NOVA]", "tier": "Hexcore Elite", "points": "2,435 pts", "win": "69%"},
		{"place": 4, "name": "Nyx Unseen", "squad": "[SHDW]", "tier": "Hexcore Elite", "points": "2,390 pts", "win": "68%"},
		{"place": 5, "name": "ZephyrEU", "squad": "[HXR]", "tier": "Hexcore Elite", "points": "1,840 pts", "win": "68%"},
	]
