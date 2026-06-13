extends Node

const PREFERRED_DISTANCE: float = 300.0
const SPREAD_RADIUS: float = 160.0
const SPREAD_PENALTY: float = 8.0


# avoid_points: end positions already chosen by other AI ships this round, so this
# ship can spread out instead of clustering into a single crossfire.
func select_maneuver(ai_ship: Ship, ships: Array, avoid_points: Array = []) -> Maneuver:
	var engines_out: bool = ai_ship.engines_disabled()
	var target: Ship = _highest_threat(ai_ship, ships)
	var best_maneuver: Maneuver = null
	var best_score: float = -INF

	for bearing in ai_ship.bearing_options:
		var color: String = ai_ship.get_maneuver_color(bearing)
		if ai_ship.stress > 0 and color == "RED":
			continue
		# Disabled engines: only white (neutral) maneuvers remain available.
		if engines_out and color != "WHITE":
			continue
		for speed in ai_ship.speed_options:
			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = speed

			var end_state := ManeuverSystem.compute_end_state(
				ai_ship.global_position, ai_ship.rotation, m)
			var score := _score_state(end_state, target, avoid_points)

			if score > best_score:
				best_score = score
				best_maneuver = m

	return best_maneuver


func select_action(ai_ship: Ship, ships: Array) -> String:
	var target: Ship = _highest_threat(ai_ship, ships)
	var in_arc: bool = target != null and ManeuverSystem.is_in_firing_arc(ai_ship, target)

	# Active ability (may be used while stressed)
	if ai_ship.has_active_ability() and not ai_ship.ability_used:
		var ab: String = ai_ship.get_active_ability()
		if ab == "BARREL_ROLL" and ai_ship.stress > 0:
			return "ABILITY"
		if ab == "OVERCHARGE" and in_arc and ai_ship.stress == 0:
			return "ABILITY"

	if ai_ship.stress > 0:
		return ""
	# Disabled sensors prevent acquiring a target lock.
	if in_arc and not ai_ship.sensors_disabled():
		# Focus fire is valid coordination — several AI ships locking the same threat is fine.
		return "TARGET_LOCK" if ai_ship.target_lock == null else "FOCUS"
	return "FOCUS"


# Highest-threat enemy: highest attack value, nearer ships break ties.
func _highest_threat(ai_ship: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_score: float = -INF
	for s in ships:
		var t: Ship = s as Ship
		if t.is_destroyed or t.team == ai_ship.team or not t.is_targetable:
			continue
		var d: float = ai_ship.global_position.distance_to(t.global_position)
		var score: float = float(t.attack) * 100.0 - d
		if score > best_score:
			best_score = score
			best = t
	return best


func _score_state(end_state: Dictionary, target: Ship, avoid_points: Array) -> float:
	var end_pos: Vector2 = end_state["position"]
	var end_rot: float = end_state["rotation"]

	if ManeuverSystem.is_out_of_bounds(end_pos):
		return -1000.0
	if target == null:
		return 0.0

	var to_target: Vector2 = target.global_position - end_pos
	var dist: float = to_target.length()
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(end_rot)
	var score: float = 0.0

	# Pursue: face the threat, hold preferred distance.
	score += facing.dot(to_target.normalized()) * 10.0
	score += (1.0 - abs(dist - PREFERRED_DISTANCE) / PREFERRED_DISTANCE) * 5.0

	# Spread: avoid clustering with other AI ships' chosen end positions.
	for p in avoid_points:
		var pv: Vector2 = p
		var d: float = end_pos.distance_to(pv)
		if d < SPREAD_RADIUS:
			score -= (1.0 - d / SPREAD_RADIUS) * SPREAD_PENALTY

	# Threat assessment: break the target's firing arc, prefer its rear.
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
