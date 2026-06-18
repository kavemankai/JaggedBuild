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
					# Acquire the lock from the pending target chosen during planning.
					# The lock takes a full round: pick TARGET_LOCK + click enemy this
					# round, the lock activates here (ACTION phase), missiles fire next round.
					if s.pending_lock_target != null and not s.pending_lock_target.is_destroyed \
							and s.global_position.distance_to(s.pending_lock_target.global_position) <= ManeuverSystem.MAX_RANGE:
						s.target_lock = s.pending_lock_target
						s.pending_lock_target = null
					elif s.pending_lock_target != null:
						# The clicked target went invalid before the action phase; clear the pending lock.
						s.pending_lock_target = null
						s.target_lock = null
					else:
						s.target_lock = _nearest_enemy(s, ships)
						# no pending target, so auto-acquire like before
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
		# Target lock has a range limit — can't lock beyond MAX_RANGE.
		if d > ManeuverSystem.MAX_RANGE:
			continue
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
