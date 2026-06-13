extends Node

# Persistent meta-layer: roster, XP/leveling, injury/death, mission progression.
# Pilots and ships are stored as plain Dictionaries so the whole campaign
# serializes to JSON cleanly. Main.gd turns these specs into live Ship nodes.

const SAVE_PATH: String = "user://campaign.json"

const KILL_XP: int = 3
const SURVIVE_XP: int = 1
const WIN_XP: int = 2
const LEVEL_XP: int = 6        # XP per skill level gained
const MAX_SKILL: int = 6
const DEATH_CHANCE: float = 0.25

var roster: Array = []          # player pilot/ship specs
var mission_index: int = 0
var last_summary: Array = []     # human-readable result lines for the end screen


func _ready() -> void:
	if not load_campaign():
		_init_default_roster()
		save()


# ---------------------------------------------------------------- roster setup
func _init_default_roster() -> void:
	roster = [
		{
			"name": "ACE", "base_skill": 5, "skill": 5,
			"accuracy": 1.1, "agility": 1.0, "nerve": 0.3,
			"passive": "", "active": "OVERCHARGE", "weapon": "HEAVY",
			"attack": 3, "defence": 2, "shields": 2, "hull": 3,
			"accent": [1.0, 0.3, 0.2],
			"xp": 0, "kills": 0, "status": "healthy",
		},
		{
			"name": "HAWK", "base_skill": 4, "skill": 4,
			"accuracy": 1.0, "agility": 1.0, "nerve": 0.2,
			"passive": "EVASIVE", "active": "BARREL_ROLL", "weapon": "BURST",
			"attack": 3, "defence": 2, "shields": 2, "hull": 3,
			"accent": [0.3, 0.8, 1.0],
			"xp": 0, "kills": 0, "status": "healthy",
		},
	]
	mission_index = 0


# ------------------------------------------------------------------- deploying
# Player pilots that can fly this battle (dead pilots sit out permanently).
func deployable_pilots() -> Array:
	var out: Array = []
	for entry in roster:
		if entry.get("status", "healthy") != "dead":
			out.append(entry)
	# Emergency: a full wipe revives the squad so the campaign can continue.
	if out.is_empty():
		_init_default_roster()
		save()
		return roster.duplicate()
	return out


func current_mission() -> Dictionary:
	var missions := get_missions()
	var idx: int = clampi(mission_index, 0, missions.size() - 1)
	return missions[idx]


func is_campaign_complete() -> bool:
	return mission_index >= get_missions().size()


func get_missions() -> Array:
	return [
		{
			"name": "PATROL SKIRMISH",
			"capital": false,
			"enemies": [_enemy("VIPER", 3, "MARKSMAN", "ION", 2, 3, 3, 2, [0.3, 0.3, 0.4])],
		},
		{
			"name": "INTERCEPT",
			"capital": false,
			"enemies": [
				_enemy("VIPER", 3, "MARKSMAN", "ION", 2, 3, 3, 2, [0.3, 0.3, 0.4]),
				_enemy("FANG", 2, "", "BURST", 3, 2, 2, 2, [0.5, 0.2, 0.4]),
			],
		},
		{
			"name": "DREADNOUGHT ASSAULT",
			"capital": true,
			"enemies": [
				_enemy("ESCORT", 2, "", "CANNONS", 2, 3, 2, 2, [0.4, 0.3, 0.5]),
			],
		},
	]


func _enemy(p_name: String, skill: int, passive: String, weapon: String,
		atk: int, dfn: int, shd: int, hp: int, accent: Array) -> Dictionary:
	return {
		"name": p_name, "base_skill": skill, "skill": skill,
		"accuracy": 1.0, "agility": 1.1, "nerve": 0.1,
		"passive": passive, "active": "", "weapon": weapon,
		"attack": atk, "defence": dfn, "shields": shd, "hull": hp,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
	}


# --------------------------------------------------------------- post-battle
func record_battle(player_ships: Array, won: bool) -> void:
	last_summary.clear()
	# Map deployed ships back to roster entries by pilot name.
	for s in player_ships:
		var ship: Ship = s as Ship
		var entry: Dictionary = _roster_entry(ship.get_pilot_name())
		if entry.is_empty():
			continue

		var gained: int = ship.kills * KILL_XP
		if not ship.is_destroyed:
			gained += SURVIVE_XP
		if won:
			gained += WIN_XP
		entry["xp"] = int(entry.get("xp", 0)) + gained
		entry["kills"] = int(entry.get("kills", 0)) + ship.kills

		var line: String = "%s  +%d XP" % [entry["name"], gained]
		var levels: int = _apply_levels(entry)
		if levels > 0:
			line += "   LEVEL UP -> skill %d" % entry["skill"]

		if ship.is_destroyed:
			if randf() < DEATH_CHANCE:
				entry["status"] = "dead"
				line += "   [KIA]"
			else:
				entry["status"] = "injured"
				line += "   [injured]"
		elif entry.get("status", "healthy") == "injured":
			entry["status"] = "healthy"
			line += "   [recovered]"

		last_summary.append(line)

	if won:
		mission_index += 1
	save()


func _roster_entry(pilot_name: String) -> Dictionary:
	for entry in roster:
		if entry.get("name", "") == pilot_name:
			return entry
	return {}


# Raises skill toward base_skill + xp/LEVEL_XP. Returns levels gained.
func _apply_levels(entry: Dictionary) -> int:
	var base_skill: int = int(entry.get("base_skill", entry.get("skill", 3)))
	@warning_ignore("integer_division")
	var levels_from_xp: int = int(entry.get("xp", 0)) / LEVEL_XP
	var target: int = mini(MAX_SKILL, base_skill + levels_from_xp)
	var current: int = int(entry.get("skill", base_skill))
	if target > current:
		entry["skill"] = target
		return target - current
	return 0


# ------------------------------------------------------------------- save/load
func save() -> void:
	var data := {
		"roster": roster,
		"mission_index": mission_index,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_campaign() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	roster = data.get("roster", [])
	mission_index = int(data.get("mission_index", 0))
	return not roster.is_empty()


func reset_campaign() -> void:
	_init_default_roster()
	save()
