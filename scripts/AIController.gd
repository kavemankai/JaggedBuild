extends Node

const PREFERRED_DISTANCE: float = 300.0
const FORMATION_DISTANCE: float = 150.0


func select_maneuver(ai_ship: Ship, ships: Array) -> Maneuver:
	if ai_ship.is_ionized():
		var forced := Maneuver.new()
		forced.bearing = "STRAIGHT"
		forced.speed = 1
		return forced

	var goal := _goal_for(ai_ship, ships)
	var best_maneuver: Maneuver = null
	var best_score: float = -INF

	for bearing in ai_ship.bearing_options:
		if ai_ship.stress > 0 and ai_ship.get_maneuver_color(bearing) == "RED":
			continue
		for speed in ai_ship.speed_options:
			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = speed

			var end_state := ManeuverSystem.compute_end_state(
				ai_ship.global_position, ai_ship.rotation, m)
			var score := _score_state(end_state, goal)

			if score > best_score:
				best_score = score
				best_maneuver = m

	return best_maneuver


func select_action(ai_ship: Ship, ships: Array) -> String:
	var enemy := _nearest_enemy(ai_ship, ships)
	var in_arc: bool = enemy != null and ManeuverSystem.is_in_firing_arc(ai_ship, enemy)

	# Active ability (may be used while stressed)
	if ai_ship.has_active_ability() and not ai_ship.ability_used:
		var ab: String = ai_ship.get_active_ability()
		if ab == "BARREL_ROLL" and ai_ship.stress > 0:
			return "ABILITY"
		if ab == "OVERCHARGE" and in_arc and ai_ship.stress == 0:
			return "ABILITY"

	if ai_ship.stress > 0 or ai_ship.is_ionized():
		return ""
	if ai_ship.order == "EVADE":
		return "EVADE"
	if in_arc:
		return "TARGET_LOCK" if ai_ship.target_lock == null else "FOCUS"
	return "FOCUS"


# Resolves the ship's order into a movement goal { mode, point }.
func _goal_for(ai_ship: Ship, ships: Array) -> Dictionary:
	if ai_ship.order == "FORM_UP":
		var leader := _team_leader(ai_ship, ships)
		if leader != null:
			return {"mode": "follow", "point": leader.global_position}

	var enemy := _nearest_enemy(ai_ship, ships)
	if enemy == null:
		return {"mode": "idle", "point": ai_ship.global_position}
	if ai_ship.order == "EVADE":
		return {"mode": "flee", "point": enemy.global_position}
	return {"mode": "pursue", "point": enemy.global_position}


func _nearest_enemy(ai_ship: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for s in ships:
		var t: Ship = s as Ship
		if t.is_destroyed or t.team == ai_ship.team:
			continue
		var d: float = ai_ship.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


func _team_leader(ai_ship: Ship, ships: Array) -> Ship:
	for s in ships:
		var t: Ship = s as Ship
		if t != ai_ship and t.team == ai_ship.team and not t.is_destroyed:
			return t
	return null


func _score_state(end_state: Dictionary, goal: Dictionary) -> float:
	var end_pos: Vector2 = end_state["position"]
	var end_rot: float = end_state["rotation"]

	if ManeuverSystem.is_out_of_bounds(end_pos):
		return -1000.0

	var mode: String = goal["mode"]
	var point: Vector2 = goal["point"]
	var to_point: Vector2 = point - end_pos
	var dist: float = to_point.length()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(end_rot)
	var score: float = 0.0

	match mode:
		"pursue":
			score += facing.dot(to_point.normalized()) * 10.0
			score += (1.0 - abs(dist - PREFERRED_DISTANCE) / PREFERRED_DISTANCE) * 5.0
		"follow":
			score += (1.0 - clampf(abs(dist - FORMATION_DISTANCE) / FORMATION_DISTANCE, 0.0, 1.0)) * 10.0
			score += facing.dot(to_point.normalized()) * 3.0
		"flee":
			score += clampf(dist / ManeuverSystem.MAX_RANGE, 0.0, 1.0) * 10.0
			score += facing.dot(-to_point.normalized()) * 4.0
		_:
			pass

	return score
