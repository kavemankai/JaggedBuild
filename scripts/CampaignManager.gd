extends Node

# Persistent meta-layer: roster, XP/leveling, injury/death, mission progression.
# Pilots and ships are stored as plain Dictionaries so the whole campaign
# serializes to JSON cleanly. Main.gd turns these specs into live Ship nodes.

const SAVE_PATH: String = "user://campaign.json"

const KILL_XP: int = 2          # per ship destroyed
const SURVIVE_XP: int = 1       # for surviving the mission
const WIN_XP: int = 3           # mission objective completed
const MAX_SKILL: int = 6
const STAT_PER_LEVEL: float = 0.05
# Cumulative XP milestones that each grant +1 skill above the pilot's base skill.
const SKILL_STEP_THRESHOLDS: Array = [5, 15, 30, 50, 75]

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
# Pilots who can fly this mission: only healthy ones (injured rest, dead are gone).
func deployable_pilots() -> Array:
	var out: Array = []
	for entry in roster:
		if entry.get("status", "healthy") == "healthy":
			out.append(entry)
	# Emergency: never let the squad be unable to deploy.
	if out.is_empty():
		for entry in roster:
			if entry.get("status", "") != "dead":
				entry["status"] = "healthy"
				out.append(entry)
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
				_enemy("FANG", 2, "", "BURST", 3, 2, 2, 2, [0.5, 0.2, 0.4], "enemy_assault"),
			],
		},
		{
			"name": "DREADNOUGHT ASSAULT",
			"capital": true,
			"enemies": [
				_capital_body("DREADNOUGHT", [0.5, 0.16, 0.18]),
				_turret("TURRET A", 500.0, [0.75, 0.3, 0.25]),
				_turret("TURRET B", 1100.0, [0.75, 0.3, 0.25]),
				_enemy("ESCORT", 2, "", "BURST", 3, 2, 2, 2, [0.4, 0.3, 0.5], "enemy_assault"),
			],
		},
	]


# Non-targetable capital hull: large scenery that mounts turrets and drifts L/R.
func _capital_body(p_name: String, accent: Array) -> Dictionary:
	return {
		"name": p_name, "base_skill": 1, "skill": 1,
		"accuracy": 1.0, "agility": 1.0, "nerve": 1.0,
		"passive": "", "active": "", "weapon": "CANNONS",
		"attack": 0, "defence": 0, "shields": 0, "hull": 99,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"is_capital_body": true,
	}


# A destroyable turret emplacement mounted on the capital hull at x-offset.
func _turret(p_name: String, x_offset: float, accent: Array) -> Dictionary:
	return {
		"name": p_name, "base_skill": 2, "skill": 2,
		"accuracy": 1.0, "agility": 1.0, "nerve": 1.0,
		"passive": "", "active": "", "weapon": "TURRET",
		"attack": 3, "defence": 1, "shields": 0, "hull": 3,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"is_turret": true, "x_offset": x_offset,
	}


func _enemy(p_name: String, skill: int, passive: String, weapon: String,
		atk: int, dfn: int, shd: int, hp: int, accent: Array,
		ship_class: String = "enemy_fighter") -> Dictionary:
	return {
		"name": p_name, "base_skill": skill, "skill": skill,
		"accuracy": 1.0, "agility": 1.1, "nerve": 0.1,
		"passive": passive, "active": "", "weapon": weapon,
		"attack": atk, "defence": dfn, "shields": shd, "hull": hp,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"ship_class": ship_class,
	}


# --------------------------------------------------------------- post-battle
# Injury/death (spec 8.5): a destroyed pilot is injured if the mission was won
# (rests one mission, then recovers) or killed if the mission was lost.
func record_battle(player_ships: Array, won: bool) -> void:
	last_summary.clear()
	var deployed: Dictionary = {}

	for s in player_ships:
		var ship: Ship = s as Ship
		deployed[ship.get_pilot_name()] = true
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
			if won:
				entry["status"] = "injured"
				line += "   [injured]"
			else:
				entry["status"] = "dead"
				line += "   [KIA]"

		last_summary.append(line)

	# Pilots who sat this mission out recover from injury.
	for entry in roster:
		if not deployed.has(entry.get("name", "")) and entry.get("status", "healthy") == "injured":
			entry["status"] = "healthy"
			last_summary.append("%s  recovered from injury" % entry["name"])

	_ensure_deployable()

	if won:
		mission_index += 1
	save()


# Guarantee the squad can always field at least one pilot next mission.
func _ensure_deployable() -> void:
	for entry in roster:
		if entry.get("status", "healthy") == "healthy":
			return
	var revived: bool = false
	for entry in roster:
		if entry.get("status", "") != "dead":
			entry["status"] = "healthy"
			revived = true
	if not revived:
		_init_default_roster()


func _roster_entry(pilot_name: String) -> Dictionary:
	for entry in roster:
		if entry.get("name", "") == pilot_name:
			return entry
	return {}


# Skill = base_skill + number of XP milestones crossed (capped at MAX_SKILL).
# Each level gained raises the pilot's lower stat multiplier by STAT_PER_LEVEL.
func _apply_levels(entry: Dictionary) -> int:
	var xp: int = int(entry.get("xp", 0))
	var earned: int = 0
	for thr in SKILL_STEP_THRESHOLDS:
		if xp >= int(thr):
			earned += 1
	var base_skill: int = int(entry.get("base_skill", entry.get("skill", 3)))
	var target: int = mini(MAX_SKILL, base_skill + earned)
	var current: int = int(entry.get("skill", base_skill))
	if target <= current:
		return 0
	for _n in range(target - current):
		if float(entry.get("accuracy", 1.0)) <= float(entry.get("agility", 1.0)):
			entry["accuracy"] = float(entry.get("accuracy", 1.0)) + STAT_PER_LEVEL
		else:
			entry["agility"] = float(entry.get("agility", 1.0)) + STAT_PER_LEVEL
	entry["skill"] = target
	return target - current


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
