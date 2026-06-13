class_name Ship
extends Node2D

@export var pilot_skill: int = 4
@export var speed_options: Array = [1, 2, 3, 4]
@export var bearing_options: Array = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
@export var accent_color: Color = Color(1.0, 0.3, 0.2, 1.0):
	set(v):
		accent_color = v

@export var ship_texture: Texture2D

@export var attack: int = 3
@export var defence: int = 2
@export var shields: int = 2
@export var hull: int = 3

var selected_maneuver: Maneuver = null
var is_destroyed: bool = false
var was_bumped: bool = false
var _arc_pts: Array = []

@onready var _body: Sprite2D = $Body
@onready var _firing_arc: Polygon2D = $FiringArc
@onready var _hit_label: Label = $HitLabel


func _ready() -> void:
	if ship_texture:
		_body.texture = ship_texture
	_build_arc_polygon()
	_hit_label.add_theme_color_override("font_color", accent_color)


func _build_arc_polygon() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(11):
		var t := float(i) / 10.0
		var angle: float = lerp(deg_to_rad(-45.0), deg_to_rad(45.0), t)
		pts.append(Vector2(0.0, -1.0).rotated(angle) * ManeuverSystem.MAX_RANGE)
	_firing_arc.polygon = pts
	_firing_arc.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	_firing_arc.visible = false


func show_combat_ui(in_arc: bool, hit_chance: float) -> void:
	_firing_arc.visible = true
	_firing_arc.color = Color(accent_color.r, accent_color.g, accent_color.b,
								0.28 if in_arc else 0.08)
	_hit_label.visible = true
	if in_arc:
		_hit_label.add_theme_color_override("font_color", accent_color)
		_hit_label.text = "%d%% HIT" % int(hit_chance * 100.0)
	else:
		_hit_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_hit_label.text = "NO SHOT"


func hide_combat_ui() -> void:
	_firing_arc.visible = false
	_hit_label.visible = false
	_hit_label.add_theme_color_override("font_color", accent_color)


func flash_shield() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(0.5, 0.8, 1.0, 1.0), 0.05)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.15)


func flash_hull() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color.RED, 0.05)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.2)


func get_arc_position(t: float) -> Vector2:
	if _arc_pts.is_empty():
		return global_position
	var n: int = _arc_pts.size() - 1
	var fi: float = clampf(t, 0.0, 1.0) * float(n)
	var i: int = int(fi)
	var frac: float = fi - float(i)
	if i >= n:
		return _arc_pts[n]
	var p0: Vector2 = _arc_pts[i]
	var p1: Vector2 = _arc_pts[i + 1]
	return p0.lerp(p1, frac)


func execute_maneuver() -> void:
	if selected_maneuver == null or is_destroyed:
		return

	var start_pos := global_position
	var start_rot := rotation
	var end_state := ManeuverSystem.compute_end_state(start_pos, start_rot, selected_maneuver)
	_arc_pts = ManeuverSystem.generate_arc_points(start_pos, start_rot, selected_maneuver)
	var arc_pts: Array = _arc_pts
	var n: int = arc_pts.size() - 1
	var duration: float = 0.5
	var elapsed: float = 0.0

	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		var fi: float = t * float(n)
		var i: int = int(fi)
		var frac: float = fi - float(i)
		if i >= n:
			global_position = arc_pts[n]
		else:
			var p0: Vector2 = arc_pts[i]
			var p1: Vector2 = arc_pts[i + 1]
			global_position = p0.lerp(p1, frac)
		rotation = start_rot + (end_state["rotation"] - start_rot) * t

	global_position = end_state["position"]
	rotation = end_state["rotation"]
	selected_maneuver = null
	was_bumped = false
