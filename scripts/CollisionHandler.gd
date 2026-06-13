extends Node

const COLLISION_RADIUS: float = 40.0


func ships_overlap(a: Ship, b: Ship) -> bool:
	return a.global_position.distance_to(b.global_position) < (COLLISION_RADIUS * 2.0)


func resolve_bump(moving_ship: Ship, blocking_ship: Ship) -> void:
	var t := 1.0
	while t > 0.0 and ships_overlap(moving_ship, blocking_ship):
		t -= 0.05
		moving_ship.global_position = moving_ship.get_arc_position(t)
	moving_ship.was_bumped = true


func any_overlap(check_ships: Array) -> bool:
	for i in range(check_ships.size()):
		for j in range(i + 1, check_ships.size()):
			var a: Ship = check_ships[i]
			var b: Ship = check_ships[j]
			if not a.is_destroyed and not b.is_destroyed and ships_overlap(a, b):
				return true
	return false
