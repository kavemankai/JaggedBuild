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
				for other in ships:
					var t: Ship = other as Ship
					if t != s and not t.is_destroyed:
						s.target_lock = t
						break
			"BOOST":
				await _execute_boost(s)
		s.selected_action = ""


func _execute_boost(ship: Ship) -> void:
	var boost_m := Maneuver.new()
	boost_m.bearing = "STRAIGHT"
	boost_m.speed = 1
	ship.selected_maneuver = boost_m
	await ship.execute_maneuver()
