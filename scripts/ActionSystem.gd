extends Node


func execute_actions(ships: Array) -> void:
	for ship in ships:
		var s: Ship = ship as Ship
		# Stressed ships may still trigger an active ability, but no other action.
		if s.is_destroyed or (s.stress > 0 and s.selected_action != "ABILITY"):
			s.selected_action = ""
			continue
		match s.selected_action:
			"FOCUS":
				s.focus_token = true
			"EVADE":
				s.evade_token = true
			"TARGET_LOCK":
				# Disabled sensors cannot acquire a lock.
				if not s.sensors_disabled():
					s.target_lock = _nearest_enemy(s, ships)
			"BOOST":
				# Disabled engines cannot boost.
				if not s.engines_disabled():
					await _execute_boost(s)
			"ABILITY":
				_execute_ability(s)
		s.selected_action = ""


func _nearest_enemy(ship: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for other in ships:
		var t: Ship = other as Ship
		if t == ship or t.is_destroyed or t.team == ship.team or not t.is_targetable:
			continue
		var d: float = ship.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


func _execute_ability(ship: Ship) -> void:
	if ship.ability_used:
		return
	match ship.get_active_ability():
		"OVERCHARGE":
			ship.overcharged = true
		"BARREL_ROLL":
			ship.evade_token = true
			if ship.stress > 0:
				ship.stress -= 1
	ship.ability_used = true


func _execute_boost(ship: Ship) -> void:
	var boost_m := Maneuver.new()
	boost_m.bearing = "STRAIGHT"
	boost_m.speed = 1
	ship.selected_maneuver = boost_m
	await ship.execute_maneuver()
