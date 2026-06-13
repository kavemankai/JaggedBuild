extends Node

const PREFERRED_DISTANCE: float = 300.0


func select_maneuver(ai_ship: Ship, player_ship: Ship) -> Maneuver:
	var best_maneuver: Maneuver = null
	var best_score: float = -INF

	for bearing in ai_ship.bearing_options:
		for speed in ai_ship.speed_options:
			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = speed

			var end_state := ManeuverSystem.compute_end_state(
				ai_ship.global_position, ai_ship.rotation, m)
			var score := _score_state(end_state, player_ship)

			if score > best_score:
				best_score = score
				best_maneuver = m

	return best_maneuver


func select_action(ai_ship: Ship, player_ship: Ship) -> String:
	if ManeuverSystem.is_in_firing_arc(ai_ship, player_ship):
		return "TARGET_LOCK" if ai_ship.target_lock == null else "FOCUS"
	return "FOCUS"


func _score_state(end_state: Dictionary, player_ship: Ship) -> float:
	var end_pos: Vector2 = end_state["position"]
	var end_rot: float = end_state["rotation"]
	var score: float = 0.0

	var to_player: Vector2 = (player_ship.global_position - end_pos).normalized()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(end_rot)
	score += facing.dot(to_player) * 10.0

	var dist: float = end_pos.distance_to(player_ship.global_position)
	var dist_score: float = 1.0 - abs(dist - PREFERRED_DISTANCE) / PREFERRED_DISTANCE
	score += dist_score * 5.0

	if ManeuverSystem.is_out_of_bounds(end_pos):
		score -= 100.0

	return score
