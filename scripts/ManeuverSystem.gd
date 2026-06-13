extends Node

# Tuning constants — adjust without touching logic
const BASE_SPEED_UNIT: float = 80.0
const ARENA_WIDTH: float = 1600.0
const ARENA_HEIGHT: float = 900.0

const MAX_RANGE: float = 500.0
const RANGE_CLOSE: float = 167.0
const RANGE_MEDIUM: float = 333.0

const RED_BEARINGS: Array = ["TURN_LEFT", "TURN_RIGHT", "K_TURN"]
const GREEN_BEARINGS: Array = ["STRAIGHT"]

const BANK_LATERAL: float = 0.4
const BANK_FORWARD: float = 0.9
const TURN_LATERAL: float = 0.7
const TURN_FORWARD: float = 0.7


func compute_end_state(ship_pos: Vector2, ship_rot: float, maneuver: Maneuver) -> Dictionary:
	var distance: float = maneuver.speed * BASE_SPEED_UNIT
	var end_pos: Vector2
	var end_rot: float

	match maneuver.bearing:
		"STRAIGHT":
			end_pos = ship_pos + Vector2(0.0, -distance).rotated(ship_rot)
			end_rot = ship_rot
		"BANK_LEFT":
			end_pos = ship_pos + Vector2(-distance * BANK_LATERAL, -distance * BANK_FORWARD).rotated(ship_rot)
			end_rot = ship_rot - deg_to_rad(45.0)
		"BANK_RIGHT":
			end_pos = ship_pos + Vector2(distance * BANK_LATERAL, -distance * BANK_FORWARD).rotated(ship_rot)
			end_rot = ship_rot + deg_to_rad(45.0)
		"TURN_LEFT":
			end_pos = ship_pos + Vector2(-distance * TURN_LATERAL, -distance * TURN_FORWARD).rotated(ship_rot)
			end_rot = ship_rot - deg_to_rad(90.0)
		"TURN_RIGHT":
			end_pos = ship_pos + Vector2(distance * TURN_LATERAL, -distance * TURN_FORWARD).rotated(ship_rot)
			end_rot = ship_rot + deg_to_rad(90.0)
		"K_TURN":
			end_pos = ship_pos + Vector2(0.0, -distance).rotated(ship_rot)
			end_rot = ship_rot + deg_to_rad(180.0)
		_:
			end_pos = ship_pos
			end_rot = ship_rot

	return {"position": end_pos, "rotation": end_rot}


func get_rotation_delta(bearing: String) -> float:
	match bearing:
		"STRAIGHT":  return 0.0
		"BANK_LEFT":  return -deg_to_rad(45.0)
		"BANK_RIGHT": return deg_to_rad(45.0)
		"TURN_LEFT":  return -deg_to_rad(90.0)
		"TURN_RIGHT": return deg_to_rad(90.0)
		"K_TURN":     return deg_to_rad(180.0)
	return 0.0


# Cubic Hermite bezier — tangents aligned with ship facing at start and end.
# Produces smooth, flight-path-looking arcs for all bearing types.
func generate_arc_points(ship_pos: Vector2, ship_rot: float, maneuver: Maneuver, steps: int = 10) -> Array:
	var end_state: Dictionary = compute_end_state(ship_pos, ship_rot, maneuver)
	var end_pos: Vector2 = end_state["position"]
	var end_rot: float = end_state["rotation"]

	var total_distance: float = maneuver.speed * BASE_SPEED_UNIT
	var tangent_len: float = total_distance * 0.55

	var fwd_start: Vector2 = Vector2(0.0, -1.0).rotated(ship_rot)
	var fwd_end: Vector2 = Vector2(0.0, -1.0).rotated(end_rot)

	var p0: Vector2 = ship_pos
	var p1: Vector2 = ship_pos + fwd_start * tangent_len
	var p2: Vector2 = end_pos - fwd_end * tangent_len
	var p3: Vector2 = end_pos

	var points: Array = []
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		var pt: Vector2 = u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3
		points.append(pt)

	return points


func get_maneuver_color(bearing: String) -> String:
	if bearing in RED_BEARINGS:
		return "RED"
	if bearing in GREEN_BEARINGS:
		return "GREEN"
	return "WHITE"


func is_out_of_bounds(pos: Vector2) -> bool:
	return pos.x < 0.0 or pos.x > ARENA_WIDTH or pos.y < 0.0 or pos.y > ARENA_HEIGHT


func is_in_firing_arc(attacker: Ship, target: Ship) -> bool:
	var to_target: Vector2 = target.global_position - attacker.global_position
	if to_target.length() > MAX_RANGE:
		return false
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(attacker.rotation)
	return facing.dot(to_target.normalized()) > cos(deg_to_rad(45.0))


func is_in_rear_arc(attacker: Ship, target: Ship) -> bool:
	var to_attacker: Vector2 = (attacker.global_position - target.global_position).normalized()
	var target_back: Vector2 = Vector2(0.0, 1.0).rotated(target.rotation)
	return target_back.dot(to_attacker) > cos(deg_to_rad(45.0))
