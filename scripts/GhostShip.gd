extends Node2D

@onready var ghost_body: Sprite2D = $GhostBody
@onready var arc_line: Line2D = $ArcLine
@onready var _stress_label: Label = $GhostBody/StressLabel


func update_preview(ship_pos: Vector2, ship_rot: float, maneuver: Maneuver, accent: Color = Color(0.2, 0.5, 1.0, 1.0)) -> void:
	if maneuver == null:
		visible = false
		return

	visible = true

	var end_state: Dictionary = ManeuverSystem.compute_end_state(ship_pos, ship_rot, maneuver)
	ghost_body.global_position = end_state["position"]
	ghost_body.rotation = end_state["rotation"] + deg_to_rad(-90.0)

	var move_color: String = ManeuverSystem.get_maneuver_color(maneuver.bearing)
	match move_color:
		"RED":
			ghost_body.modulate = Color(1.0, 0.45, 0.45, 0.5)
			_stress_label.text = "+STRESS"
			_stress_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		"GREEN":
			ghost_body.modulate = Color(0.45, 1.0, 0.55, 0.5)
			_stress_label.text = "-STRESS"
			_stress_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
		_:
			ghost_body.modulate = Color(1.0, 1.0, 1.0, 0.4)
			_stress_label.text = ""

	arc_line.default_color = Color(accent.r, accent.g, accent.b, 0.6)

	var world_pts: Array = ManeuverSystem.generate_arc_points(ship_pos, ship_rot, maneuver)
	var local_pts := PackedVector2Array()
	for pt: Vector2 in world_pts:
		local_pts.append(to_local(pt))
	arc_line.points = local_pts


func clear_preview() -> void:
	visible = false
	ghost_body.modulate = Color(1.0, 1.0, 1.0, 0.4)
	_stress_label.text = ""
