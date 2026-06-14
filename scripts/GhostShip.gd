extends Node2D

@onready var ghost_body: Sprite2D = $GhostBody
@onready var arc_line: Line2D = $ArcLine
@onready var _stress_label: Label = $GhostBody/StressLabel

# Default opacities; callers override per ship so overlapping paths stay readable.
var base_arc_alpha: float = 0.6
var base_body_alpha: float = 0.4


func update_preview(ship: Ship, maneuver: Maneuver, active: bool = false) -> void:
	if maneuver == null:
		visible = false
		return

	visible = true

	var arc_alpha: float = 0.95 if active else base_arc_alpha
	var body_alpha: float = 0.55 if active else base_body_alpha

	var end_state: Dictionary = ManeuverSystem.compute_end_state(ship.global_position, ship.rotation, maneuver)
	ghost_body.global_position = end_state["position"]
	ghost_body.rotation = end_state["rotation"] + deg_to_rad(-90.0)

	# Pass speed so dial-based ships report the true cell color (the bearing-only
	# overload falls back to the legacy red/green arrays and mislabels dial maneuvers).
	var move_color: String = ship.get_maneuver_color(maneuver.bearing, maneuver.speed)
	match move_color:
		"RED":
			ghost_body.modulate = Color(1.0, 0.45, 0.45, body_alpha)
			_stress_label.text = "+STRESS"
			_stress_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		"GREEN":
			ghost_body.modulate = Color(0.45, 1.0, 0.55, body_alpha)
			_stress_label.text = "-STRESS"
			_stress_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45, 1.0))
		_:
			ghost_body.modulate = Color(1.0, 1.0, 1.0, body_alpha)
			_stress_label.text = ""

	arc_line.default_color = Color(ship.accent_color.r, ship.accent_color.g, ship.accent_color.b, arc_alpha)

	var world_pts: Array = ManeuverSystem.generate_arc_points(ship.global_position, ship.rotation, maneuver)
	var local_pts := PackedVector2Array()
	for pt: Vector2 in world_pts:
		local_pts.append(to_local(pt))
	arc_line.points = local_pts


func clear_preview() -> void:
	visible = false
	ghost_body.modulate = Color(1.0, 1.0, 1.0, base_body_alpha)
	_stress_label.text = ""
