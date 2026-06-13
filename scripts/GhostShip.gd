extends Node2D

@onready var ghost_body: Sprite2D = $GhostBody
@onready var arc_line: Line2D = $ArcLine
@onready var _stress_label: Label = $GhostBody/StressLabel


func update_preview(ship: Ship, maneuver: Maneuver) -> void:
	if maneuver == null:
		visible = false
		return

	visible = true

	var end_state: Dictionary = ManeuverSystem.compute_end_state(ship.global_position, ship.rotation, maneuver)
	ghost_body.global_position = end_state["position"]
	ghost_body.rotation = end_state["rotation"] + deg_to_rad(-90.0)

	var move_color: String = ship.get_maneuver_color(maneuver.bearing)
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

	arc_line.default_color = Color(ship.accent_color.r, ship.accent_color.g, ship.accent_color.b, 0.6)

	var world_pts: Array = ManeuverSystem.generate_arc_points(ship.global_position, ship.rotation, maneuver)
	var local_pts := PackedVector2Array()
	for pt: Vector2 in world_pts:
		local_pts.append(to_local(pt))
	arc_line.points = local_pts


func clear_preview() -> void:
	visible = false
	ghost_body.modulate = Color(1.0, 1.0, 1.0, 0.4)
	_stress_label.text = ""
