extends Node

# Tuning constants — adjust without touching logic
const BASE_SPEED_UNIT: float = 80.0
# Arena dimensions are per-mission data now (not a fixed screen). These are the
# defaults (skirmish / legacy 1600x900); the live size lives in `arena_size`,
# set by Main at battle start. Every world-space bounds check reads arena_size.
const DEFAULT_ARENA_WIDTH: float = 1600.0
const DEFAULT_ARENA_HEIGHT: float = 900.0
var arena_size: Vector2 = Vector2(DEFAULT_ARENA_WIDTH, DEFAULT_ARENA_HEIGHT)

# Per-edge behaviour: "WALL" (destroy), "BLOCK" (clamp), "ESCAPE" (exit battle).
# Set per-battle by Main from mission data; defaults to all WALL (legacy box).
var edges: Dictionary = {"top": "WALL", "bottom": "WALL", "left": "WALL", "right": "WALL"}

# --- Advancing Map / Danger Zone (Gate 42-43) ---
# A leading edge (perpendicular to danger_axis) sweeps forward each EVALUATION; ships
# whose projection falls behind it are caught. danger_axis is the direction the squad
# flees toward (default up). All world-space danger checks read these per-battle fields.
var danger_active: bool = false
var danger_axis: Vector2 = Vector2(0.0, -1.0)
var danger_speed: float = 0.0          # px the leading edge advances per EVALUATION
var danger_pos: float = -INF           # leading-edge projection onto danger_axis

const MAX_RANGE: float = 500.0
const RANGE_CLOSE: float = 167.0
const RANGE_MEDIUM: float = 333.0

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
		"PIVOT":
			# Stationary 180° rotation — no translation, pure facing reversal.
			end_pos = ship_pos
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
		"PIVOT":      return deg_to_rad(180.0)
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


# Set by Main at battle start from mission data (per-battle, so size never leaks
# between missions). Defaults restore 1600x900 when a mission omits dimensions.
# Also clears any prior Danger Zone so a non-advancing mission starts clean.
func set_arena(size: Vector2) -> void:
	arena_size = size
	danger_active = false
	danger_pos = -INF


# Advancing Map setup (per-battle). axis = direction the squad flees toward.
func configure_danger(active: bool, axis: Vector2, speed: float) -> void:
	danger_active = active
	danger_axis = axis.normalized() if axis.length() > 0.0 else Vector2(0.0, -1.0)
	danger_speed = speed
	# Start the edge just behind the trailing arena corner so nothing's caught at spawn.
	danger_pos = _trailing_projection() - 1.0


# Minimum projection of the four arena corners onto danger_axis (the trailing side).
func _trailing_projection() -> float:
	var corners: Array = [Vector2(0, 0), Vector2(arena_size.x, 0),
						   Vector2(0, arena_size.y), arena_size]
	var lo: float = INF
	for c in corners:
		lo = minf(lo, (c as Vector2).dot(danger_axis))
	return lo


# Advance the Danger Zone edge one step (called each EVALUATION on advancing maps).
func advance_danger() -> void:
	if danger_active:
		danger_pos += danger_speed


# True if a position has fallen behind the advancing leading edge.
func is_in_danger(pos: Vector2) -> bool:
	return danger_active and pos.dot(danger_axis) < danger_pos


# Two endpoints of the leading edge line, for drawing. Handles the common
# axis-aligned cases (vertical sweep = horizontal line, horizontal sweep = vertical).
func danger_line_points() -> Array:
	if not danger_active:
		return []
	if absf(danger_axis.y) >= absf(danger_axis.x):
		# Vertical sweep: edge is a horizontal line at y = danger_pos / axis.y.
		var y: float = danger_pos / danger_axis.y
		return [Vector2(0.0, y), Vector2(arena_size.x, y)]
	else:
		var x: float = danger_pos / danger_axis.x
		return [Vector2(x, 0.0), Vector2(x, arena_size.y)]


# Reset to all-WALL, then apply mission overrides (per-battle, so no leak).
func set_edges(overrides: Dictionary) -> void:
	edges = {"top": "WALL", "bottom": "WALL", "left": "WALL", "right": "WALL"}
	for key in overrides.keys():
		edges[key] = overrides[key]


func is_out_of_bounds(pos: Vector2) -> bool:
	return pos.x < 0.0 or pos.x > arena_size.x or pos.y < 0.0 or pos.y > arena_size.y


# Behaviour of the edge(s) a position is beyond: ESCAPE > WALL > BLOCK > "IN".
func edge_mode(pos: Vector2) -> String:
	var modes: Array = []
	if pos.y < 0.0:
		modes.append(edges.get("top", "WALL"))
	if pos.y > arena_size.y:
		modes.append(edges.get("bottom", "WALL"))
	if pos.x < 0.0:
		modes.append(edges.get("left", "WALL"))
	if pos.x > arena_size.x:
		modes.append(edges.get("right", "WALL"))
	if modes.is_empty():
		return "IN"
	if "ESCAPE" in modes:
		return "ESCAPE"
	if "WALL" in modes:
		return "WALL"
	return "BLOCK"


func clamp_to_arena(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 0.0, arena_size.x), clampf(pos.y, 0.0, arena_size.y))


func is_in_firing_arc(attacker: Ship, target: Ship) -> bool:
	var to_target: Vector2 = target.global_position - attacker.global_position
	var max_range: float = MAX_RANGE * attacker.firing_range_mult
	if to_target.length() > max_range:
		return false
	var facing: Vector2 = Vector2(0.0, -1.0).rotated(attacker.rotation)
	var half_angle: float = attacker.firing_arc_degrees * 0.5
	return facing.dot(to_target.normalized()) > cos(deg_to_rad(half_angle))


# A Large ship's rear turret arc: directly behind, within rear_arc_degrees. 0 = no arc.
func is_in_rear_firing_arc(attacker: Ship, target: Ship) -> bool:
	if attacker.rear_arc_degrees <= 0.0:
		return false
	var to_target: Vector2 = target.global_position - attacker.global_position
	var max_range: float = MAX_RANGE * attacker.firing_range_mult
	if to_target.length() > max_range:
		return false
	var back: Vector2 = Vector2(0.0, 1.0).rotated(attacker.rotation)
	var half_angle: float = attacker.rear_arc_degrees * 0.5
	return back.dot(to_target.normalized()) > cos(deg_to_rad(half_angle))


func is_in_rear_arc(attacker: Ship, target: Ship) -> bool:
	var to_attacker: Vector2 = (attacker.global_position - target.global_position).normalized()
	var target_back: Vector2 = Vector2(0.0, 1.0).rotated(target.rotation)
	return target_back.dot(to_attacker) > cos(deg_to_rad(45.0))
