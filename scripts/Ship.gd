class_name Ship
extends Node2D

@export var pilot_skill: int = 4
@export var speed_options: Array = [1, 2, 3, 4]
@export var bearing_options: Array = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
@export var accent_color: Color = Color(1.0, 0.3, 0.2, 1.0):
	set(v):
		accent_color = v

@export var ship_texture: Texture2D

@export var red_bearings: Array[String] = ["TURN_LEFT", "TURN_RIGHT", "K_TURN"]
@export var green_bearings: Array[String] = ["STRAIGHT"]

@export var attack: int = 3
@export var defence: int = 2
@export var shields: int = 2
@export var hull: int = 3
@export var weapon: Resource = null
@export var pilot: Resource = null
@export var team: String = "PLAYER"

var selected_maneuver: Maneuver = null
var heavy_cooldown: int = 0
var is_destroyed: bool = false
var was_bumped: bool = false
var stress: int = 0
var ion_tokens: int = 0
var in_formation: bool = false
var focus_token: bool = false
var evade_token: bool = false
var target_lock: Ship = null
var selected_action: String = ""
var order: String = "ENGAGE"
var ability_used: bool = false
var overcharged: bool = false
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


func show_combat_ui(in_arc: bool, hit_chance: float, status: String = "") -> void:
	_firing_arc.visible = true
	_firing_arc.color = Color(accent_color.r, accent_color.g, accent_color.b,
								0.28 if in_arc else 0.08)
	_hit_label.visible = true
	if status != "":
		_hit_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.2, 1.0))
		_hit_label.text = status
	elif in_arc:
		_hit_label.add_theme_color_override("font_color", accent_color)
		_hit_label.text = "%d%% HIT" % int(hit_chance * 100.0)
	else:
		_hit_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_hit_label.text = "NO SHOT"


func hide_combat_ui() -> void:
	_firing_arc.visible = false
	_hit_label.visible = false
	_hit_label.add_theme_color_override("font_color", accent_color)


func get_skill() -> int:
	var p: Pilot = pilot as Pilot
	return p.skill if p != null else pilot_skill


func get_accuracy() -> float:
	var p: Pilot = pilot as Pilot
	return p.accuracy if p != null else 1.0


func get_agility() -> float:
	var p: Pilot = pilot as Pilot
	return p.agility if p != null else 1.0


func get_nerve() -> float:
	var p: Pilot = pilot as Pilot
	var base: float = p.nerve if p != null else 0.0
	if get_passive() == "STEADY":
		base += 0.25
	return clampf(base, 0.0, 1.0)


func get_pilot_name() -> String:
	var p: Pilot = pilot as Pilot
	return p.pilot_name if p != null else "Unknown"


func get_passive() -> String:
	var p: Pilot = pilot as Pilot
	return p.passive if p != null else ""


func get_active_ability() -> String:
	var p: Pilot = pilot as Pilot
	return p.active_ability if p != null else ""


func has_active_ability() -> bool:
	return get_active_ability() != ""


# Applies one-time setup perks (e.g. bonus hull). Call after pilot is assigned.
func apply_setup_passives() -> void:
	match get_passive():
		"STALWART":
			hull += 1


func is_ionized() -> bool:
	return ion_tokens > 0


func get_maneuver_color(bearing: String) -> String:
	if bearing in red_bearings:
		return "RED"
	if bearing in green_bearings:
		return "GREEN"
	return "WHITE"


func pulse_stress() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.15)
	tween.tween_property(_body, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.15)


func destroy_ship() -> void:
	_firing_arc.visible = false
	_hit_label.visible = false
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(1.0, 0.4, 0.0, 0.0), 0.35)
	tween.parallel().tween_property(_body, "scale", Vector2(6.0, 6.0), 0.35)


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
