extends Node

# Persistent meta-layer: roster, XP/leveling, injury/death/drone, mission progression,
# the Distance pursuit value, and role-based mission comms. Pilots/ships are plain
# Dictionaries so the whole campaign serializes to JSON. Main.gd turns specs into Ships.
#
# Campaign structure (THE LONG RETREAT): 3 tutorials + 12 missions, linear. The Threshing
# Engine pursues; Distance tracks the gap. Dead veterans hollow into silent AI drones.

const SAVE_PATH: String = "user://campaign.json"
const SAVE_VERSION: int = 2          # bumped for THE LONG RETREAT campaign structure

const KILL_XP: int = 2
const SURVIVE_XP: int = 1
const WIN_XP: int = 3
const MAX_SKILL: int = 6
const STAT_PER_LEVEL: float = 0.05
const SKILL_STEP_THRESHOLDS: Array = [5, 15, 30, 50, 75]

# --- Distance (the pursuit) ---
const DISTANCE_MAX: float = 100.0
const DISTANCE_START: float = 50.0
const ENGINE_THRESHOLD: float = 30.0     # below this, the Engine forces itself into the next mission
const DIST_WIN_CLEAN: float = 12.0       # objective met, no losses
const DIST_WIN_BLED: float = 4.0         # objective met, took losses
const DIST_LOSE: float = -15.0           # objective failed

const TUTORIAL_COUNT: int = 3            # mission_index 0..2 are tutorials

var roster: Array = []
var mission_index: int = 0
var distance: float = DISTANCE_START
var fallen: Array = []                   # callsigns of dead veterans (for the memorial)
var last_summary: Array = []
var selected_deployment: Array = []      # pilot names chosen for the next mission (transient)

var skirmish_mode: bool = false
var skirmish_enemies: Array = []
var skirmish_record: Dictionary = {"w": 0, "l": 0}
var squad_size: int = 2          # how many player ships deploy (campaign 2; skirmish picks)

const MAX_SQUAD: int = 6


func _ready() -> void:
	if not load_campaign():
		reset_campaign()


# ---------------------------------------------------------------- roster setup
func _init_default_roster() -> void:
	roster = [
		_veteran("WARDEN", 4, "", "OVERCHARGE", "fighter", "HEAVY", [0.95, 0.85, 0.3],
			"Squadron commander. The one who has to bring them home.", true),
		_veteran("LEAD", 5, "STEADY", "OVERCHARGE", "fighter", "HEAVY", [1.0, 0.3, 0.2],
			"Done this before. Knows how it ends. Calm, fatalistic, reliable."),
		_veteran("HAWK", 4, "MARKSMAN", "OVERCHARGE", "interceptor", "BURST", [0.3, 0.8, 1.0],
			"The shooter. Cocky, lethal, wants to turn and fight the Engine."),
		_veteran("VIPER", 3, "EVASIVE", "BARREL_ROLL", "interceptor", "ION", [0.5, 1.0, 0.4],
			"Has outlived three squadrons. Cautious, slippery, alive."),
		_veteran("ASH", 3, "STALWART", "BARREL_ROLL", "heavy_fighter", "CANNONS", [0.7, 0.7, 0.8],
			"The spine. Quiet, takes the hits so others don't."),
		_veteran("WREN", 2, "MARKSMAN", "OVERCHARGE", "fighter", "BURST", [1.0, 0.6, 0.2],
			"Better than a rookie should be. Eager, untested."),
		_veteran("DUST", 2, "STEADY", "BARREL_ROLL", "gunship", "ION", [0.8, 0.5, 0.9],
			"Keeps the ships flying. Practical, gallows humour."),
	]
	mission_index = 0
	distance = DISTANCE_START
	fallen = []
	selected_deployment = []


func _veteran(p_name: String, skill: int, passive: String, active: String,
		ship_class: String, weapon: String, accent: Array, bio: String,
		commander: bool = false) -> Dictionary:
	return {
		"name": p_name, "base_skill": skill, "skill": skill,
		"accuracy": 1.0, "agility": 1.0, "nerve": 0.2,
		"passive": passive, "active": active, "weapon": weapon,
		"attack": 3, "defence": 2, "shields": 2, "hull": 3,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"ship_class": ship_class, "upgrade": "",
		"bio": bio, "commander": commander, "is_drone": false,
	}


# ------------------------------------------------------------------- deploying
# Pilots who can fly: healthy ones (drones count — they fly). Injured rest, dead are gone.
func deployable_pilots() -> Array:
	var out: Array = []
	for entry in roster:
		if entry.get("status", "healthy") == "healthy":
			out.append(entry)
	if out.is_empty():
		# Emergency: revive the least-broken so the squad can always launch.
		for entry in roster:
			if entry.get("status", "") != "dead":
				entry["status"] = "healthy"
				out.append(entry)
	if out.is_empty():
		reset_campaign()
		return deployable_pilots()
	return out


# Up to `squad_size` pilots for the next mission: the player's selection if valid,
# else the top of the deployable pool.
func pilots_for_deployment() -> Array:
	var n: int = clampi(squad_size, 1, MAX_SQUAD)
	var pool: Array = deployable_pilots()
	if not selected_deployment.is_empty():
		var chosen: Array = []
		for pname in selected_deployment:
			for entry in pool:
				if entry.get("name", "") == pname and not chosen.has(entry):
					chosen.append(entry)
		if not chosen.is_empty():
			return chosen.slice(0, n)
	return pool.slice(0, n)


func current_mission() -> Dictionary:
	var missions := get_missions()
	var idx: int = clampi(mission_index, 0, missions.size() - 1)
	return missions[idx]


func is_campaign_complete() -> bool:
	return mission_index >= get_missions().size()


# The Engine is on the map this mission if the mission is a set-piece, or if Distance
# has fallen far enough that the pursuit forces itself into an ordinary mission.
func engine_present() -> bool:
	var m: Dictionary = current_mission()
	if m.get("tutorial", false):
		return m.get("engine", false)   # tutorials only show it when scripted (T3)
	return m.get("engine", false) or distance < ENGINE_THRESHOLD


# Full enemy list for the current mission, including the Threshing Engine when present.
func current_enemies() -> Array:
	var m: Dictionary = current_mission()
	var enemies: Array = (m.get("enemies", []) as Array).duplicate()
	if engine_present():
		var turrets: int = int(m.get("engine_turrets", 2))
		enemies = _engine_specs(turrets) + enemies
	return enemies


func current_protected() -> Dictionary:
	return current_mission().get("protected", {})


# -------------------------------------------------------------------- missions
func get_missions() -> Array:
	return [
		# ----- TUTORIALS (no stakes, no permadeath) -----
		{
			"id": "T1", "name": "FIRST LIGHT", "act": 0, "tutorial": true,
			"objective": {"type": "DESTROY_ALL"}, "engine": false,
			"enemies": [_enemy("BANDIT", 2, "", "CANNONS", 2, 2, 1, 2, [0.4, 0.4, 0.5])],
			"beat": {"role": "LEAD", "text": "Stay on the plan. Pick your move, commit, fly it. We'll ease you in."},
		},
		{
			"id": "T2", "name": "TEETH", "act": 0, "tutorial": true,
			"objective": {"type": "DESTROY_ALL"}, "engine": false,
			"enemies": [
				_enemy("BANDIT", 2, "", "CANNONS", 2, 2, 2, 2, [0.4, 0.4, 0.5]),
				_enemy("BANDIT", 2, "", "CANNONS", 2, 2, 2, 2, [0.4, 0.4, 0.5]),
			],
			"beat": {"role": "WING", "text": "Two of them, two of us. Watch your arcs and we walk away from this."},
		},
		{
			"id": "T3", "name": "THE SHADOW", "act": 0, "tutorial": true,
			"objective": {"type": "DESTROY_ALL"}, "engine": true, "engine_turrets": 2,
			"enemies": [],
			"beat": {"role": "LEAD", "text": "That thing is the Threshing Engine. It doesn't stop. Remember that."},
		},

		# ----- ACT 1 — DESPERATE -----
		{
			"id": "M1", "name": "REARGUARD", "act": 1,
			"objective": {"type": "SURVIVE_ROUNDS", "rounds": 5}, "engine": false,
			"enemies": [
				_enemy("BANDIT", 3, "", "CANNONS", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("BANDIT", 3, "", "CANNONS", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("BANDIT", 2, "", "BURST", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
			],
			"beat": {"role": "LEAD", "text": "We're the rearguard. Cover the withdrawal, hold five rounds, then we run. We don't win this — we last."},
		},
		{
			"id": "M2", "name": "STRAGGLERS", "act": 1,
			"objective": {"type": "PROTECT"}, "engine": false,
			"protected": _transport("TRANSPORT GULL"),
			"enemies": [
				_enemy("BANDIT", 3, "", "CANNONS", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("BANDIT", 3, "", "BURST", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("VIPER", 3, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
			],
			"beat": {"role": "WING", "text": "They're faster than yesterday. The enemy's adapting — keep them off the transport."},
		},
		{
			"id": "M3", "name": "THE NET", "act": 1,
			"objective": {"type": "REACH_EDGE", "edge_y": 120.0}, "engine": false,
			"edges": {"top": "ESCAPE"},
			"enemies": [
				_enemy("BANDIT", 3, "", "CANNONS", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("BANDIT", 3, "", "BURST", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("VIPER", 3, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 3, "EVASIVE", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
			],
			"beat": {"role": "SQUADRON", "text": "This isn't a chase. It's a net. They're herding us — break through the line and don't look back."},
		},
		{
			"id": "M4", "name": "THRESHING", "act": 1,
			"objective": {"type": "SURVIVE_ROUNDS", "rounds": 5}, "engine": true, "engine_turrets": 2,
			"enemies": [
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "LEAD", "text": "It caught up. The Engine's on us. Survive its guns, keep formation, and pray the jump point's real."},
		},

		# ----- ACT 2 — THE TURN -----
		{
			"id": "M5", "name": "A WAY OUT", "act": 2,
			"objective": {"type": "PROTECT"}, "engine": false,
			"protected": _transport("SCOUT WREN-7"),
			"enemies": [
				_enemy("VIPER", 3, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 3, "EVASIVE", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 4, "MARKSMAN", "BURST", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
			],
			"beat": {"role": "LEAD", "text": "That scout found a jump route. A way out. Protect it and we stop running blind."},
		},
		{
			"id": "M6", "name": "BUYING TIME", "act": 2,
			"objective": {"type": "HOLD_POSITION", "rounds": 5}, "engine": false,
			"enemies": [
				_enemy("BANDIT", 3, "", "CANNONS", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("BANDIT", 3, "", "BURST", 2, 2, 2, 3, [0.4, 0.3, 0.45]),
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "LEAD", "text": "Hold here. Every round we buy gets the route prepped. Maybe — maybe this actually works."},
		},
		{
			"id": "M7", "name": "THE GAUNTLET", "act": 2,
			"objective": {"type": "REACH_EDGE", "edge_y": 120.0}, "engine": false,
			"edges": {"top": "ESCAPE"},
			"enemies": [
				_enemy("VIPER", 4, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 4, "EVASIVE", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "WING", "text": "Debris field ahead. Thread it to the far edge — whatever squadron we've got left, this is the push."},
		},
		{
			"id": "M8", "name": "RECKONING", "act": 2,
			"objective": {"type": "SURVIVE_ROUNDS", "rounds": 5}, "engine": true, "engine_turrets": 2,
			"enemies": [
				_enemy("FANG", 4, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "SQUADRON", "text": "It nearly has us. But the jump point's close now. Survive this and the turn is real."},
		},
		{
			"id": "M9", "name": "BREATHING ROOM", "act": 2,
			"objective": {"type": "DESTROY_ALL"}, "engine": false,
			"enemies": [
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 3, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 4, "MARKSMAN", "HEAVY", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "SQUADRON", "text": "First time we're ahead. Clear the path. ...It's quiet up here. Too many empty channels."},
		},

		# ----- ACT 3 — THE RUN -----
		{
			"id": "M10", "name": "NO TURNING BACK", "act": 3,
			"objective": {"type": "DESTROY_ALL"}, "engine": false,
			"enemies": [
				_enemy("VIPER", 4, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 4, "EVASIVE", "BURST", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("FANG", 4, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 4, "MARKSMAN", "HEAVY", 3, 2, 3, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "LEAD", "text": "The corridor's ahead. Everything we have, right now. No turning back."},
		},
		{
			"id": "M11", "name": "THE CORRIDOR", "act": 3,
			"objective": {"type": "SURVIVE_ROUNDS", "rounds": 6}, "engine": true, "engine_turrets": 3,
			"enemies": [
				_enemy("FANG", 4, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 4, "MARKSMAN", "BURST", 3, 2, 3, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "LEAD", "text": "It's right on top of us. Jump point's one run away. Hold together — whoever's still flying, hold together."},
		},
		{
			"id": "M12", "name": "THE LONG RETREAT", "act": 3, "finale": true,
			"objective": {"type": "SURVIVE_ROUNDS", "rounds": 6}, "engine": true, "engine_turrets": 3,
			"enemies": [
				_enemy("VIPER", 4, "MARKSMAN", "ION", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("VIPER", 4, "EVASIVE", "BURST", 2, 3, 2, 2, [0.3, 0.5, 0.5], "enemy_scout"),
				_enemy("FANG", 5, "MARKSMAN", "HEAVY", 3, 2, 3, 3, [0.5, 0.2, 0.35], "enemy_assault"),
				_enemy("FANG", 4, "", "BURST", 3, 2, 2, 3, [0.5, 0.2, 0.35], "enemy_assault"),
			],
			"beat": {"role": "LEAD", "text": "This is it. Make the jump. Not a victory over that thing — a victory of getting out. Bring them through."},
		},
	]


# ----------------------------------------------------------------- spec builders
# The Threshing Engine: non-targetable drifting hull + N destroyable turrets.
func _engine_specs(turret_count: int) -> Array:
	var specs: Array = [_capital_body("THRESHING ENGINE", [0.45, 0.14, 0.16])]
	var offsets: Array = _turret_offsets(turret_count)
	for i in range(turret_count):
		specs.append(_turret("ENGINE TURRET %d" % (i + 1), offsets[i], [0.7, 0.28, 0.24]))
	return specs


func _turret_offsets(n: int) -> Array:
	match n:
		1: return [800.0]
		2: return [500.0, 1100.0]
		3: return [380.0, 800.0, 1220.0]
		_: return [300.0, 650.0, 950.0, 1300.0]


func _capital_body(p_name: String, accent: Array) -> Dictionary:
	return {
		"name": p_name, "base_skill": 1, "skill": 1,
		"accuracy": 1.0, "agility": 1.0, "nerve": 1.0,
		"passive": "", "active": "", "weapon": "CANNONS",
		"attack": 0, "defence": 0, "shields": 0, "hull": 99,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"is_capital_body": true,
	}


func _turret(p_name: String, x_offset: float, accent: Array) -> Dictionary:
	return {
		"name": p_name, "base_skill": 2, "skill": 2,
		"accuracy": 1.0, "agility": 1.0, "nerve": 1.0,
		"passive": "", "active": "", "weapon": "TURRET",
		"attack": 3, "defence": 1, "shields": 0, "hull": 3,
		"accent": accent, "xp": 0, "kills": 0, "status": "healthy",
		"is_turret": true, "x_offset": x_offset,
	}


# A protected friendly transport: tanky, sluggish, player must keep it alive.
func _transport(p_name: String) -> Dictionary:
	return {
		"name": p_name, "base_skill": 2, "skill": 2,
		"accuracy": 0.8, "agility": 1.2, "nerve": 1.0,
		"passive": "", "active": "", "weapon": "CANNONS",
		"attack": 1, "defence": 3, "shields": 3, "hull": 8,
		"accent": [0.6, 0.85, 0.7], "xp": 0, "kills": 0, "status": "healthy",
		"ship_class": "gunship", "is_protected": true,
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


# ------------------------------------------------------------------ comms (roles)
# Resolve a mission beat's ROLE to a living named pilot's callsign, or to an
# impersonal speaker (COMMAND / SQUADRON) when no human holds that role.
func resolve_beat(mission: Dictionary) -> Dictionary:
	var beat: Dictionary = mission.get("beat", {})
	if beat.is_empty():
		return {}
	return {"speaker": _role_speaker(beat.get("role", "SQUADRON")), "text": beat.get("text", "")}


func _role_speaker(role: String) -> String:
	var named: Array = _living_named_sorted()
	match role:
		"LEAD":
			return named[0] if named.size() >= 1 else "COMMAND"
		"WING":
			return named[1] if named.size() >= 2 else "SQUADRON"
		"COMMAND":
			return "COMMAND"
		_:
			return "SQUADRON"


# Living, non-drone callsigns sorted by skill descending (the humans who can speak).
func _living_named_sorted() -> Array:
	var named: Array = []
	for entry in roster:
		if entry.get("is_drone", false):
			continue
		if entry.get("status", "healthy") == "dead":
			continue
		named.append(entry)
	named.sort_custom(func(a, b): return int(a.get("skill", 0)) > int(b.get("skill", 0)))
	var out: Array = []
	for entry in named:
		out.append(entry.get("name", "?"))
	return out


func start_skirmish(enemies: Array, player_squad: int = 2) -> void:
	skirmish_mode = true
	skirmish_enemies = enemies
	squad_size = clampi(player_squad, 1, MAX_SQUAD)


# --------------------------------------------------------------- post-battle
func record_battle(player_ships: Array, won: bool) -> void:
	if skirmish_mode:
		_record_skirmish(won)
		return

	last_summary.clear()
	var is_tutorial: bool = current_mission().get("tutorial", false)
	var deployed: Dictionary = {}
	var losses: int = 0
	var kia_names: Array = []

	for s in player_ships:
		var ship: Ship = s as Ship
		# The protected transport is not a roster pilot — skip persistence for it.
		if ship.team != "PLAYER" or _roster_entry(ship.get_pilot_name()).is_empty():
			continue
		deployed[ship.get_pilot_name()] = true
		var entry: Dictionary = _roster_entry(ship.get_pilot_name())

		if is_tutorial:
			last_summary.append("%s  flew the drill" % entry["name"])
			continue

		var gained: int = ship.kills * KILL_XP
		if not ship.is_destroyed:
			gained += SURVIVE_XP
		if won:
			gained += WIN_XP

		# Drones never grow.
		if not entry.get("is_drone", false):
			entry["xp"] = int(entry.get("xp", 0)) + gained
			entry["kills"] = int(entry.get("kills", 0)) + ship.kills

		var line: String = "%s  +%d XP" % [entry["name"], gained if not entry.get("is_drone", false) else 0]
		if not entry.get("is_drone", false):
			var levels: int = _apply_levels(entry)
			if levels > 0:
				line += "   LEVEL UP -> skill %d" % entry["skill"]

		if ship.is_destroyed:
			losses += 1
			# Capture true-KIA callsigns (pre-rename) for the survivor reaction.
			var kia_now: bool = not won and not entry.get("commander", false) and not entry.get("is_drone", false)
			var lost_name: String = entry.get("name", "?")
			line += _handle_casualty(entry, won)
			if kia_now:
				kia_names.append(lost_name)

		last_summary.append(line)

	# A survivor reacts to the dead (lines attach to whoever's still flying and human).
	if not kia_names.is_empty():
		var reaction: String = _survivor_reaction(kia_names)
		if reaction != "":
			last_summary.append("")
			last_summary.append(reaction)

	# Pilots who sat out recover from injury.
	for entry in roster:
		if not deployed.has(entry.get("name", "")) and entry.get("status", "healthy") == "injured":
			entry["status"] = "healthy"
			last_summary.append("%s  recovered from injury" % entry["name"])

	_ensure_deployable()

	if not is_tutorial:
		_adjust_distance(won, losses)

	selected_deployment = []

	if won:
		mission_index += 1
		if is_campaign_complete():
			_append_ending()

	save()


# A living, human squadmate (not one of the dead) reacts to the losses. If only drones
# and the dead remain, the loss passes in silence — which is its own kind of line.
func _survivor_reaction(kia_names: Array) -> String:
	var speaker: String = ""
	for callsign in _living_named_sorted():
		if not kia_names.has(callsign):
			speaker = callsign
			break
	var dead: String = kia_names[0]
	if speaker == "":
		return "No one answers on the channel. Just the drones, holding formation."
	var lines: Array = [
		"%s: \"%s is gone. Mark it. Keep flying.\"" % [speaker, dead],
		"%s: \"...That was %s. We don't have time to stop.\"" % [speaker, dead],
		"%s: \"%s. Another empty seat. Another ghost in the formation.\"" % [speaker, dead],
		"%s: \"We lost %s. The Engine doesn't care. Form up.\"" % [speaker, dead],
	]
	return lines[randi() % lines.size()]


# Returns the result-line suffix and mutates the entry (injured / drone conversion).
func _handle_casualty(entry: Dictionary, won: bool) -> String:
	if won:
		entry["status"] = "injured"
		return "   [injured]"
	# Lost the mission. Commander is protected (emergency craft); veterans hollow into drones.
	if entry.get("commander", false):
		entry["status"] = "injured"
		return "   [downed — recovered by SAR]"
	if entry.get("is_drone", false):
		entry["status"] = "injured"      # a drone lost is just a machine; rebuilt, rests a mission
		return "   [drone lost]"
	var callsign: String = entry.get("name", "?")
	fallen.append(callsign)
	_convert_to_drone(entry)
	return "   [KIA] — slot filled by %s" % entry["name"]


# A dead veteran's slot becomes a silent AI drone: skill-1, no abilities, never grows.
func _convert_to_drone(entry: Dictionary) -> void:
	var old_skill: int = int(entry.get("skill", 2))
	var designation: String = "AUTO-%d" % (_drone_count() + 1)
	entry["name"] = designation
	entry["base_skill"] = maxi(1, old_skill - 1)
	entry["skill"] = maxi(1, old_skill - 1)
	entry["passive"] = ""
	entry["active"] = ""
	entry["accuracy"] = 1.0
	entry["agility"] = 1.0
	entry["nerve"] = 0.0
	entry["xp"] = 0
	entry["status"] = "healthy"
	entry["is_drone"] = true
	entry["commander"] = false
	entry["bio"] = "Autonomous drone. Flies the slot. Holds the line. Says nothing."
	entry["accent"] = [0.45, 0.45, 0.5]
	entry["upgrade"] = ""


func _drone_count() -> int:
	var n: int = 0
	for entry in roster:
		if entry.get("is_drone", false):
			n += 1
	return n


func _record_skirmish(won: bool) -> void:
	skirmish_mode = false
	if won:
		skirmish_record["w"] = int(skirmish_record.get("w", 0)) + 1
		last_summary = ["SKIRMISH WON  W:%d L:%d" % [skirmish_record["w"], skirmish_record.get("l", 0)]]
	else:
		skirmish_record["l"] = int(skirmish_record.get("l", 0)) + 1
		last_summary = ["SKIRMISH LOST  W:%d L:%d" % [skirmish_record.get("w", 0), skirmish_record["l"]]]
	selected_deployment = []
	save()


func _adjust_distance(won: bool, losses: int) -> void:
	var delta: float
	if won:
		delta = DIST_WIN_CLEAN if losses == 0 else DIST_WIN_BLED
	else:
		delta = DIST_LOSE
	distance = clampf(distance + delta, 0.0, DISTANCE_MAX)
	var pfx: String = "+" if delta >= 0 else ""
	last_summary.append("THE ENGINE: distance %s%d  (now %d)" % [pfx, int(delta), int(distance)])
	if distance < ENGINE_THRESHOLD:
		last_summary.append("WARNING — the Engine is closing. It will be on you next sortie.")


# ------------------------------------------------------------------ endings
func _append_ending() -> void:
	var living_humans: Array = []
	var drones: Array = []
	for entry in roster:
		if entry.get("is_drone", false):
			drones.append(entry.get("name", "?"))
		elif entry.get("status", "healthy") != "dead":
			living_humans.append(entry.get("name", "?"))

	var vet_humans: int = 0   # surviving named veterans (exclude commander)
	for entry in roster:
		if not entry.get("is_drone", false) and not entry.get("commander", false) \
				and entry.get("status", "healthy") != "dead":
			vet_humans += 1

	last_summary.append("")
	last_summary.append("=== THE LONG RETREAT ===")
	if drones.is_empty():
		last_summary.append("The squadron made the jump whole. Six callsigns, all still answering.")
		last_summary.append("The rarest ending. You got everyone out.")
	elif vet_humans >= 2:
		last_summary.append("You made the jump. Not all of you — some of those flying out are ghosts.")
		last_summary.append("The expected ending. You got out, but you carry the empty seats.")
	else:
		last_summary.append("You escaped. The formation that jumps out is mostly silent machines")
		last_summary.append("flying dead friends' diminished skill. The loneliest ending.")

	if not fallen.is_empty():
		last_summary.append("")
		last_summary.append("THE DEAD: " + ", ".join(fallen))
	if not drones.is_empty():
		last_summary.append("THE DRONES: " + ", ".join(drones))
	last_summary.append("STILL FLYING: " + ", ".join(living_humans))
	last_summary.append("")
	last_summary.append("The war is behind you. The Engine is still out there.")


# Guarantee the squad can always field at least one pilot.
func _ensure_deployable() -> void:
	for entry in roster:
		if entry.get("status", "healthy") == "healthy":
			return
	for entry in roster:
		if entry.get("status", "") != "dead":
			entry["status"] = "healthy"
			return


func _roster_entry(pilot_name: String) -> Dictionary:
	for entry in roster:
		if entry.get("name", "") == pilot_name:
			return entry
	return {}


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
		"version": SAVE_VERSION,
		"roster": roster,
		"mission_index": mission_index,
		"distance": distance,
		"fallen": fallen,
		"skirmish_record": skirmish_record,
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
	# Older saves predate the campaign rewrite — discard and reset cleanly.
	if int(data.get("version", 1)) < SAVE_VERSION:
		return false
	roster = data.get("roster", [])
	mission_index = int(data.get("mission_index", 0))
	distance = float(data.get("distance", DISTANCE_START))
	fallen = data.get("fallen", [])
	skirmish_record = data.get("skirmish_record", {"w": 0, "l": 0})
	return not roster.is_empty()


func reset_campaign() -> void:
	_init_default_roster()
	skirmish_record = {"w": 0, "l": 0}
	save()
