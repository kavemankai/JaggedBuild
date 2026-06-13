extends Node


func execute_actions(ships: Array) -> void:
	for ship in ships:
		var s: Ship = ship as Ship
		if s.is_destroyed or s.stress > 0:
			s.selected_action = ""
			continue
		match s.selected_action:
			"FOCUS":
				s.focus_token = true
			"EVADE":
				s.evade_token = true
			"TARGET_LOCK":
				s.target_lock = _nearest_enemy(s, ships)
			"BOOST":
				await _execute_boost(s)
		s.selected_action = ""


func _nearest_enemy(ship: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for other in ships:
		var t: Ship = other as Ship
		if t == ship or t.is_destroyed or t.team == ship.team:
			continue
		var d: float = ship.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


func _execute_boost(ship: Ship) -> void:
	var boost_m := Maneuver.new()
	boost_m.bearing = "STRAIGHT"
	boost_m.speed = 1
	ship.selected_maneuver = boost_m
	await ship.execute_maneuver()
