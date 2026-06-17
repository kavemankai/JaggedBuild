class_name GhostShip
extends Node2D

@onready var ghost_body: Sprite2D = $GhostBody
@onready var arc_line: Line2D = $ArcLine
@onready var _stress_label: Label = $GhostBody/StressLabel

var base_arc_alpha: float = 0.6
var base_body_alpha: float = 0.4

var _arc_draw_pts: PackedVector2Array = PackedVector2Array()
var _arc_draw_color: Color = Color.WHITE


func update_preview(ship: Ship, maneuver: Maneuver, active: bool = false) -> void:
	if maneuver == null:
		visible = false
		_arc_draw_pts.clear()
		queue_redraw()
		return

	visible = true

	var arc_alpha: float = 0.95 if active else base_arc_alpha
	var body_alpha: float = 0.55 if active else base_body_alpha

	var end_state: Dictionary = ManeuverSystem.compute_end_state(ship.global_position, ship.rotation, maneuver)
	ghost_body.global_position = end_state["position"]
	ghost_body.rotation = end_state["rotation"]

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

	var is_stressed_red: bool = move_color == "RED" and ship.stress > 0
	var eff_alpha: float = 0.3 if is_stressed_red else arc_alpha
	match move_color:
		"GREEN":
			_arc_draw_color = Color(0.0, 1.0, 0.533, eff_alpha)
		"RED":
			_arc_draw_color = Color(1.0, 0.267, 0.267, eff_alpha)
		_:
			_arc_draw_color = Color(ship.accent_color.r, ship.accent_color.g, ship.accent_color.b, eff_alpha)

	arc_line.default_color = _arc_draw_color
	arc_line.width = 2.0
	arc_line.joint_mode = Line2D.LINE_JOINT_ROUND
	arc_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	var world_pts: Array = ManeuverSystem.generate_arc_points(ship.global_position, ship.rotation, maneuver)
	var local_pts := PackedVector2Array()
	for pt: Vector2 in world_pts:
		local_pts.append(to_local(pt))
	arc_line.points = local_pts

	var tick_steps: int = max(1, maneuver.speed)
	var world_tick_pts: Array = ManeuverSystem.generate_arc_points(ship.global_position, ship.rotation, maneuver, tick_steps)
	_arc_draw_pts.clear()
	for pt: Vector2 in world_tick_pts:
		_arc_draw_pts.append(to_local(pt))
	queue_redraw()


func clear_preview() -> void:
	visible = false
	ghost_body.modulate = Color(1.0, 1.0, 1.0, base_body_alpha)
	_stress_label.text = ""
	_arc_draw_pts.clear()
	queue_redraw()


func _draw() -> void:
	var n: int = _arc_draw_pts.size()
	if n < 2:
		return
	for i in range(1, n - 1):
		var prev: Vector2 = _arc_draw_pts[i - 1]
		var curr: Vector2 = _arc_draw_pts[i]
		var next_pt: Vector2 = _arc_draw_pts[i + 1] if i + 1 < n else curr
		var dir: Vector2 = (next_pt - prev).normalized()
		if dir.is_zero_approx():
			continue
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		draw_line(curr - perp * 4.0, curr + perp * 4.0, _arc_draw_color, 1.5, true)
	var tip: Vector2 = _arc_draw_pts[n - 1]
	var tip_prev: Vector2 = _arc_draw_pts[n - 2]
	var tip_dir: Vector2 = (tip - tip_prev).normalized()
	if not tip_dir.is_zero_approx():
		var perp_tip: Vector2 = Vector2(-tip_dir.y, tip_dir.x)
		draw_line(tip - perp_tip * 9.0, tip + perp_tip * 9.0, _arc_draw_color, 2.5, true)
