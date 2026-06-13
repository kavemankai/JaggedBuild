extends Node2D

@onready var ghost_body: Sprite2D = $GhostBody
@onready var arc_line: Line2D = $ArcLine


func update_preview(ship_pos: Vector2, ship_rot: float, maneuver: Maneuver, accent: Color = Color(0.2, 0.5, 1.0, 1.0)) -> void:
	if maneuver == null:
		visible = false
		return

	visible = true

	var end_state: Dictionary = ManeuverSystem.compute_end_state(ship_pos, ship_rot, maneuver)
	ghost_body.global_position = end_state["position"]
	ghost_body.rotation = end_state["rotation"] + deg_to_rad(90.0)

	arc_line.default_color = Color(accent.r, accent.g, accent.b, 0.6)

	var world_pts: Array = ManeuverSystem.generate_arc_points(ship_pos, ship_rot, maneuver)
	var local_pts := PackedVector2Array()
	for pt: Vector2 in world_pts:
		local_pts.append(to_local(pt))
	arc_line.points = local_pts


func clear_preview() -> void:
	visible = false
