extends Node

const COLLISION_RADIUS: float = 40.0   # SMALL default (Ship.collision_radius seeds from this)

# Swerve bearing candidates in preference order (45° adjustments).
const SWERVE_LEFT: Array  = ["BANK_LEFT", "TURN_LEFT", "K_TURN"]
const SWERVE_RIGHT: Array = ["BANK_RIGHT", "TURN_RIGHT", "K_TURN"]


# Overlap uses each ship's own radius so mixed Small/Large sizes collide correctly.
func ships_overlap(a: Ship, b: Ship) -> bool:
	return a.global_position.distance_to(b.global_position) < (a.collision_radius + b.collision_radius)


# HOTAC Swerve: try adjusting bearing 45° left then right before accepting a collision.
# Collision cost regardless: moving_ship skips its action this round (was_bumped flag).
func resolve_bump(moving_ship: Ship, blocking_ship: Ship) -> void:
	# Try swerving left then right.
	for candidates in [SWERVE_LEFT, SWERVE_RIGHT]:
		for bearing in candidates:
			if moving_ship.dial_data == null:
				break
			# Find the same speed on the new bearing.
			var orig_spd: int = moving_ship.selected_maneuver.speed if moving_ship.selected_maneuver else 1
			var swerve_m := Maneuver.new()
			swerve_m.bearing = bearing
			swerve_m.speed = orig_spd
			# Check bearing is on this ship's dial (and colour is valid under stress).
			var col: String = moving_ship.get_maneuver_color(bearing, orig_spd)
			if col == "":
				continue  # not on dial
			if moving_ship.stress > 0 and col == "RED":
				continue
			# Compute end state for the swerve maneuver.
			var end_state: Dictionary = ManeuverSystem.compute_end_state(
				moving_ship.global_position, moving_ship.rotation, swerve_m)
			var candidate_pos: Vector2 = end_state["position"]
			# Check if swerve avoids the blocker AND stays in bounds.
			if ManeuverSystem.is_out_of_bounds(candidate_pos):
				continue
			var after_dist: float = candidate_pos.distance_to(blocking_ship.global_position)
			if after_dist >= (moving_ship.collision_radius + blocking_ship.collision_radius):
				# Swerve succeeds — move to swerve end position.
				moving_ship.global_position = candidate_pos
				moving_ship.rotation = end_state["rotation"]
				moving_ship.was_bumped = true
				return

	# No swerve found — execute original but accept collision (truncate to last safe point).
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
