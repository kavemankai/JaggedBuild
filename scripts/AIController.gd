extends Node

# HOTAC statcard AI — 4-step activation per ship.
# Falls back to heuristic scorer for ships without a statcard (legacy / capital turrets).

const AIStatcards := preload("res://scripts/AIStatcards.gd")
const AIStatcard := preload("res://scripts/AIStatcard.gd")

# Range / bearing thresholds matching ManeuverSystem constants.
# Reference the autoload consts directly so these can never drift again
# (they had stale 167/333/500 values while ManeuverSystem shipped 182/369/552).
const RANGE_CLOSE: float = ManeuverSystem.RANGE_CLOSE
const RANGE_MEDIUM: float = ManeuverSystem.RANGE_MEDIUM
const RANGE_MAX: float = ManeuverSystem.MAX_RANGE

# Heuristic fallback constants (kept for turrets / legacy ships).
const PREFERRED_DISTANCE: float = 300.0
const SPREAD_RADIUS: float = 160.0
const SPREAD_PENALTY: float = 8.0


# ─────────────────────────────────── public ──────────────────────────────────

func select_maneuver(ai_ship: Ship, ships: Array, avoid_points: Array = []) -> Maneuver:
	# Ionized: forced 1-straight.
	if ai_ship.is_ionized():
		var m := Maneuver.new()
		m.bearing = "STRAIGHT"
		m.speed = 1
		return m

	var sc: AIStatcard = _statcard_for(ai_ship)
	if sc != null:
		return _hotac_maneuver(ai_ship, sc, ships)
	return _heuristic_maneuver(ai_ship, ships, avoid_points)


func select_action(ai_ship: Ship, ships: Array) -> String:
	var sc: AIStatcard = _statcard_for(ai_ship)

	# Ionized: Focus only.
	if ai_ship.is_ionized():
		return "FOCUS" if ai_ship.stress == 0 else ""

	# Crit repair is top priority (Fuel Leak is the repairable one in-battle).
	# Between missions, repair happens at campaign level — skip mid-battle.

	if sc != null:
		return _hotac_action(ai_ship, sc, ships)
	return _heuristic_action(ai_ship, ships)


# ──────────────────────────────── HOTAC steps ────────────────────────────────

func _statcard_for(ai_ship: Ship) -> AIStatcard:
	# Fetch statcard from the ship spec's class id stored as a hint.
	if ai_ship.has_meta("statcard_class"):
		return AIStatcards.for_class(ai_ship.get_meta("statcard_class"))
	# Infer from dial data presence / ship class hints.
	if ai_ship.dial_data != null:
		# Try to detect class by dial options count (rough heuristic).
		var opts: Array = ai_ship.dial_data.get_all_options()
		if opts.size() <= 3:
			return AIStatcards.bulk_cruiser()
	return null


# Step 1: target selection per statcard priority list.
func _hotac_target(ai_ship: Ship, sc: AIStatcard, ships: Array) -> Ship:
	var candidates: Array = ships.filter(func(s: Ship):
		return not s.is_destroyed and s.team != ai_ship.team and s.is_targetable)

	if candidates.is_empty():
		return null

	match sc.target_mode:
		"FLEE":
			return null  # no target — just flee
		"STRIKE", "ESCORT":
			# Pursue the objective hull first.
			for s in candidates:
				if (s as Ship).is_objective:
					return s as Ship

	for rule in sc.target_priority:
		match rule:
			"nearest_enemy":
				var best: Ship = null
				var bd: float = INF
				for s in candidates:
					var d: float = ai_ship.global_position.distance_to((s as Ship).global_position)
					if d < bd:
						bd = d
						best = s as Ship
				if best != null:
					return best
			"lowest_hull":
				var best: Ship = null
				var bh: int = 999
				for s in candidates:
					if (s as Ship).hull < bh:
						bh = (s as Ship).hull
						best = s as Ship
				if best != null:
					return best
			"locked_target":
				if ai_ship.target_lock != null and not ai_ship.target_lock.is_destroyed:
					return ai_ship.target_lock
			"objective":
				for s in candidates:
					if (s as Ship).is_objective:
						return s as Ship
	return candidates[0] as Ship


# Step 2: maneuver selection.
func _hotac_maneuver(ai_ship: Ship, sc: AIStatcard, ships: Array) -> Maneuver:
	var target: Ship = _hotac_target(ai_ship, sc, ships)
	var use_stress_table: bool = ai_ship.stress > 0

	# FLEE mode: pick the maneuver that moves fastest toward the flee edge.
	if sc.target_mode == "FLEE":
		return _flee_maneuver(ai_ship, sc.flee_edge)

	var band: String = "OUT"
	var zone: String = "FRONT"

	if target != null:
		band = _range_band(ai_ship, target)
		zone = _bearing_zone(ai_ship, target)

		# If target is FLEEING (AI behind target's front line), shift band outward.
		var target_facing: Vector2 = Vector2(0.0, -1.0).rotated(target.rotation)
		var to_ai: Vector2 = (ai_ship.global_position - target.global_position).normalized()
		if target_facing.dot(to_ai) > 0.5:  # AI is in target's rear hemisphere
			band = _shift_band_outward(band)

	var table: Dictionary = sc.stress_maneuver_table if use_stress_table else sc.maneuver_table
	var options: Array = []
	if table.has(band) and (table[band] as Dictionary).has(zone):
		options = (table[band] as Dictionary)[zone]

	if options.is_empty():
		# Fallback: pick any valid non-red bearing.
		options = _fallback_bearings(ai_ship)

	# Build a candidate maneuver for each table bearing, then keep only those whose
	# end-state stays inside the arena and out of the advancing danger zone. HOTAC
	# tables reason about the target, not walls — without this filter a ship that
	# turns away from its target flies straight into a wall and self-destructs.
	var toward: Array = []   # in-bounds candidates that keep facing the target
	var away: Array = []     # in-bounds candidates that turn away from the target
	for bearing in options:
		var mv := _best_maneuver_for_bearing(ai_ship, bearing)
		var es := ManeuverSystem.compute_end_state(ai_ship.global_position, ai_ship.rotation, mv)
		if ManeuverSystem.is_out_of_bounds(es["position"]) or ManeuverSystem.is_in_danger(es["position"]):
			continue
		var face_dot: float = -2.0
		if target != null:
			var fwd: Vector2 = Vector2(0.0, -1.0).rotated(es["rotation"])
			face_dot = fwd.dot((target.global_position - (es["position"] as Vector2)).normalized())
		var entry := {"mv": mv, "face": face_dot}
		if face_dot >= 0.0:
			toward.append(entry)
		else:
			away.append(entry)
	var pool: Array = toward if not toward.is_empty() else away
	if pool.is_empty():
		# Every table option sends us out of bounds — we're cornered. Re-orient
		# back toward the arena centre instead of flying into the wall.
		return _evade_edge_maneuver(ai_ship)
	# Random pick among the surviving in-bounds candidates (the table already
	# encoded the right bearing for this band/zone; variety keeps it from being
	# deterministic). Prefer candidates that keep the target in the forward hemisphere.
	return (pool[randi() % pool.size()]["mv"]) as Maneuver


# Cornered against a wall with no in-bounds table option: turn toward the arena
# centre at the slowest valid speed to re-orient back into play instead of
# flying into the wall. Falls back to a bank, then a straight-1, if turns are off
# the dial.
func _evade_edge_maneuver(ai_ship: Ship) -> Maneuver:
	# Cornered: every table option leaves the arena. Re-orient back in without
	# flying into the wall. Try the centre-facing turn at the SLOWEST speed first
	# (less overshoot), then the opposite turn, then a bank, then straight-1 —
	# return the first whose end-state actually stays in bounds.
	var centre: Vector2 = ManeuverSystem.arena_size * 0.5
	var to_centre: Vector2 = (centre - ai_ship.global_position).normalized()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(ai_ship.rotation)
	var cross: float = facing.x * to_centre.y - facing.y * to_centre.x
	var toward_bearing: String = "TURN_LEFT" if cross >= 0.0 else "TURN_RIGHT"
	var away_bearing: String = "TURN_RIGHT" if cross >= 0.0 else "TURN_LEFT"
	for bearing in [toward_bearing, away_bearing,
				 "BANK_LEFT" if cross >= 0.0 else "BANK_RIGHT", "STRAIGHT"]:
		var mv := _slowest_valid_maneuver(ai_ship, bearing)
		if mv == null:
			continue
		var es := ManeuverSystem.compute_end_state(ai_ship.global_position, ai_ship.rotation, mv)
		if not ManeuverSystem.is_out_of_bounds(es["position"]) and not ManeuverSystem.is_in_danger(es["position"]):
			return mv
	# Truly stuck — straight-1 is the only option (may clip the wall, but unavoidable).
	var fallback := Maneuver.new()
	fallback.bearing = "STRAIGHT"
	fallback.speed = 1
	return fallback


# Step 3: action selection via priority cascade.
func _hotac_action(ai_ship: Ship, sc: AIStatcard, ships: Array) -> String:
	if ai_ship.stress > 0:
		return ""  # red maneuver ships skip action; stress blocks normal actions

	var target: Ship = _hotac_target(ai_ship, sc, ships)
	var in_arc: bool = target != null and ManeuverSystem.is_in_firing_arc(ai_ship, target)

	for action_name in sc.action_priority:
		match action_name:
			"TARGET_LOCK":
				if in_arc and not ai_ship.sensors_disabled() and ai_ship.target_lock == null:
					return "TARGET_LOCK"
			"FOCUS":
				return "FOCUS"
			"EVADE":
				return "EVADE"
			"BARREL_ROLL":
				if ai_ship.get_active_ability() == "BARREL_ROLL" and not ai_ship.ability_used:
					return "ABILITY"
			"OVERCHARGE":
				if ai_ship.get_active_ability() == "OVERCHARGE" and in_arc and not ai_ship.ability_used:
					return "ABILITY"
	return "FOCUS"


# ───────────────────────────────── helpers ───────────────────────────────────

func _range_band(a: Ship, b: Ship) -> String:
	var d: float = a.global_position.distance_to(b.global_position)
	if d < RANGE_CLOSE:   return "CLOSE"
	if d < RANGE_MEDIUM:  return "MEDIUM"
	if d < RANGE_MAX:     return "LONG"
	return "OUT"


func _bearing_zone(ai_ship: Ship, target: Ship) -> String:
	var to_target: Vector2 = (target.global_position - ai_ship.global_position).normalized()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(ai_ship.rotation)
	var dot: float = facing.dot(to_target)
	# Zone is symmetric (left/right share a table cell), so only the forward dot matters.
	if dot > 0.92:   return "BULLSEYE"
	if dot > 0.5:    return "FRONT"
	if dot > -0.17:  return "FRONT_SIDE"
	if dot > -0.64:  return "REAR_SIDE"
	return "REAR"


func _shift_band_outward(band: String) -> String:
	match band:
		"CLOSE":  return "MEDIUM"
		"MEDIUM": return "LONG"
		"LONG":   return "OUT"
		_:        return "OUT"


func _best_maneuver_for_bearing(ai_ship: Ship, bearing: String) -> Maneuver:
	# Find all valid (non-stressed-red) speeds for this bearing on the ship's dial.
	# When stressed, prefer a GREEN speed (clears stress next resolution) over the
	# fastest one — otherwise the ship locks itself into the stress table forever
	# (fastest bank/straight is WHITE, never GREEN, so stress never clears and red
	# K_TURNs can never fire again).
	var best: Maneuver = null
	var best_speed: int = -1
	var best_green: Maneuver = null
	var best_green_speed: int = -1
	if ai_ship.dial_data != null:
		for opt: Dictionary in ai_ship.dial_data.get_all_options():
			if opt["bearing"] != bearing:
				continue
			var color: String = opt["color"]
			if ai_ship.stress > 0 and color == "RED":
				continue
			if ai_ship.engines_disabled() and color != "WHITE":
				continue
			var spd: int = int(opt["speed"])
			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = spd
			if color == "GREEN" and spd > best_green_speed:
				best_green_speed = spd
				best_green = m
			if spd > best_speed:
				best_speed = spd
				best = m
	if ai_ship.stress > 0 and best_green != null:
		return best_green
	else:
		# Legacy: use bearing_options + speed_options.
		if bearing in ai_ship.bearing_options:
			var color: String = ai_ship.get_maneuver_color(bearing)
			if not (ai_ship.stress > 0 and color == "RED"):
				var spd: int = ai_ship.speed_options.max() if not ai_ship.speed_options.is_empty() else 2
				var m := Maneuver.new()
				m.bearing = bearing
				m.speed = spd
				best = m
	if best == null:
		# Bearing not available — fallback to straight.
		var m := Maneuver.new()
		m.bearing = "STRAIGHT"
		m.speed = 1 if ai_ship.speed_options.is_empty() else ai_ship.speed_options[0]
		return m
	return best


func _fallback_bearings(ai_ship: Ship) -> Array:
	var valid: Array = []
	if ai_ship.dial_data != null:
		for opt: Dictionary in ai_ship.dial_data.get_all_options():
			var color: String = opt["color"]
			if ai_ship.stress > 0 and color == "RED":
				continue
			if not (opt["bearing"] as String) in valid:
				valid.append(opt["bearing"])
	else:
		for b in ai_ship.bearing_options:
			if not (ai_ship.stress > 0 and ai_ship.get_maneuver_color(b) == "RED"):
				valid.append(b)
	return valid if not valid.is_empty() else ["STRAIGHT"]


func _flee_maneuver(ai_ship: Ship, _edge: String) -> Maneuver:
	# Pick the fastest straight maneuver toward the flee edge.
	var m := Maneuver.new()
	m.bearing = "STRAIGHT"
	m.speed = 1
	if ai_ship.dial_data != null:
		for opt: Dictionary in ai_ship.dial_data.get_all_options():
			if opt["bearing"] == "STRAIGHT" and int(opt["speed"]) > m.speed:
				if ai_ship.stress == 0 or opt["color"] != "RED":
					m.speed = int(opt["speed"])
	return m


# Slowest valid (non-stressed-red, non-engines-disabled-non-white) speed for a
# bearing — used by edge evasion to minimise overshoot when cornered.
func _slowest_valid_maneuver(ai_ship: Ship, bearing: String) -> Maneuver:
	if ai_ship.dial_data != null:
		var best: Maneuver = null
		var best_speed: int = 999
		for opt: Dictionary in ai_ship.dial_data.get_all_options():
			if opt["bearing"] != bearing:
				continue
			var color: String = opt["color"]
			if ai_ship.stress > 0 and color == "RED":
				continue
			if ai_ship.engines_disabled() and color != "WHITE":
				continue
			var spd: int = int(opt["speed"])
			if spd < best_speed:
				best_speed = spd
				var m := Maneuver.new()
				m.bearing = bearing
				m.speed = spd
				best = m
		return best
	# Legacy (no dial_data): use bearing/speed options.
	if bearing in ai_ship.bearing_options and not ai_ship.speed_options.is_empty():
		var m2 := Maneuver.new()
		m2.bearing = bearing
		m2.speed = ai_ship.speed_options.min()
		return m2
	return null


# ──────────────────────────── heuristic fallback ─────────────────────────────

func _heuristic_maneuver(ai_ship: Ship, ships: Array, avoid_points: Array) -> Maneuver:
	var engines_out: bool = ai_ship.engines_disabled()
	var target: Ship = _highest_threat(ai_ship, ships)
	var best_maneuver: Maneuver = null
	var best_score: float = -INF

	if ai_ship.dial_data != null:
		for option: Dictionary in ai_ship.dial_data.get_all_options():
			var bearing: String = option["bearing"] as String
			var speed: int = int(option["speed"])
			var color: String = option["color"] as String
			if ai_ship.stress > 0 and color == "RED":
				continue
			if engines_out and color != "WHITE":
				continue
			var mv := Maneuver.new()
			mv.bearing = bearing
			mv.speed = speed
			var end_state := ManeuverSystem.compute_end_state(ai_ship.global_position, ai_ship.rotation, mv)
			var score := _score_state(end_state, target, avoid_points)
			if score > best_score:
				best_score = score
				best_maneuver = mv
	else:
		for bearing in ai_ship.bearing_options:
			var color: String = ai_ship.get_maneuver_color(bearing)
			if ai_ship.stress > 0 and color == "RED":
				continue
			if engines_out and color != "WHITE":
				continue
			for speed in ai_ship.speed_options:
				var mv := Maneuver.new()
				mv.bearing = bearing
				mv.speed = speed
				var end_state := ManeuverSystem.compute_end_state(ai_ship.global_position, ai_ship.rotation, mv)
				var score := _score_state(end_state, target, avoid_points)
				if score > best_score:
					best_score = score
					best_maneuver = mv

	return best_maneuver


func _heuristic_action(ai_ship: Ship, ships: Array) -> String:
	var target: Ship = _highest_threat(ai_ship, ships)
	var in_arc: bool = target != null and ManeuverSystem.is_in_firing_arc(ai_ship, target)

	if ai_ship.has_active_ability() and not ai_ship.ability_used:
		var ab: String = ai_ship.get_active_ability()
		if ab == "BARREL_ROLL" and ai_ship.stress > 0:
			return "ABILITY"
		if ab == "OVERCHARGE" and in_arc and ai_ship.stress == 0:
			return "ABILITY"

	if ai_ship.stress > 0:
		return ""
	if in_arc and not ai_ship.sensors_disabled():
		return "TARGET_LOCK" if ai_ship.target_lock == null else "FOCUS"
	return "FOCUS"


func _highest_threat(ai_ship: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_score: float = -INF
	for s in ships:
		var t: Ship = s as Ship
		if t.is_destroyed or t.team == ai_ship.team or not t.is_targetable:
			continue
		var d: float = ai_ship.global_position.distance_to(t.global_position)
		var score: float = float(t.attack) * 100.0 - d
		if t.is_objective:
			score += 400.0
		if score > best_score:
			best_score = score
			best = t
	return best


func _score_state(end_state: Dictionary, target: Ship, avoid_points: Array) -> float:
	var end_pos: Vector2 = end_state["position"]
	var end_rot: float = end_state["rotation"]
	if ManeuverSystem.is_out_of_bounds(end_pos):
		return -1000.0
	# Advancing Map: the leading edge is a board edge — never end behind it.
	if ManeuverSystem.is_in_danger(end_pos):
		return -800.0
	if target == null:
		return 0.0
	var to_target: Vector2 = target.global_position - end_pos
	var dist: float = to_target.length()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(end_rot)
	var score: float = 0.0
	score += facing.dot(to_target.normalized()) * 10.0
	score += (1.0 - abs(dist - PREFERRED_DISTANCE) / PREFERRED_DISTANCE) * 5.0
	for p in avoid_points:
		var pv: Vector2 = p
		var d: float = end_pos.distance_to(pv)
		if d < SPREAD_RADIUS:
			score -= (1.0 - d / SPREAD_RADIUS) * SPREAD_PENALTY
	if _in_forward_arc(target, end_pos):
		score -= 6.0
	if _in_rear_arc(target, end_pos):
		score += 4.0
	return score


func _in_forward_arc(observer: Ship, point: Vector2) -> bool:
	var to_pt: Vector2 = point - observer.global_position
	if to_pt.length() > ManeuverSystem.MAX_RANGE:
		return false
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(observer.rotation)
	return facing.dot(to_pt.normalized()) > cos(deg_to_rad(45.0))


func _in_rear_arc(observer: Ship, point: Vector2) -> bool:
	var to_pt: Vector2 = (point - observer.global_position).normalized()
	var back: Vector2 = Vector2(0.0, 1.0).rotated(observer.rotation)
	return back.dot(to_pt) > cos(deg_to_rad(45.0))
