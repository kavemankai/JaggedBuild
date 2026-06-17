class_name Ship
extends Node2D

const DialData := preload("res://scripts/DialData.gd")

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
@export var is_capital: bool = false
@export var is_targetable: bool = true
@export var firing_arc_degrees: float = 90.0
@export var firing_range_mult: float = 1.0

var dial_data: DialData = null
var selected_maneuver: Maneuver = null
var heavy_cooldown: int = 0
var is_destroyed: bool = false
var was_bumped: bool = false
var stress: int = 0
var ion_tokens: int = 0
var disabled_systems: Dictionary = {}  # system name -> rounds remaining
var in_formation: bool = false
var focus_token: bool = false
var evade_token: bool = false
var target_lock: Ship = null
var selected_action: String = ""
var ability_used: bool = false
var overcharged: bool = false
var kills: int = 0
var missiles_ammo: int = 2
var torpedoes_ammo: int = 0  # 1 when weapon is TORPEDOES, set in apply_spec
var upgrade: String = ""
var veteran_stress_blocked: bool = false
var escaped: bool = false

# Large ship class
var collision_radius: float = 40.0
var rear_arc_degrees: float = 0.0      # 0 = no rear turret arc
var has_rear_turret: bool = false
var rear_cooldown: int = 0             # rear turret's own cooldown (separate from heavy_cooldown)
var is_objective: bool = false         # escort/convoy hull — destruction fails the mission
var active_crits: Array[String] = []   # persists all battle; Fuel Leak survives to next mission
var attack_base: int = -1              # set on deploy; Structural Damage modifies attack directly

# Formation lock (player). formation is a Formation (RefCounted) or null.
var formation = null
var formation_role: String = "NONE"    # "NONE" / "LEAD" / "WING"

var _arc_pts: Array = []

const CAPITAL_DRIFT_SPEED: float = 35.0
const CAPITAL_DRIFT_MARGIN: float = 280.0
var _capital_drift: bool = false
var _drift_dir: float = 1.0
var _draw_as_hull: bool = false

@onready var _body: Sprite2D = $Body
@onready var _firing_arc: Polygon2D = $FiringArc
@onready var _hit_label: Label = $HitLabel
var _rear_arc: Polygon2D = null
var _arc_close_band: Polygon2D = null
var _arc_medium_band: Polygon2D = null


func _ready() -> void:
	if ship_texture:
		_body.texture = ship_texture
	_build_arc_polygon()
	_hit_label.add_theme_color_override("font_color", accent_color)


func enable_capital_drift() -> void:
	_capital_drift = true


func _process(delta: float) -> void:
	if not _capital_drift:
		return
	# Slow translation along the arena's long edge; reverses at the margins,
	# shifting which player ships sit inside each turret's arc.
	position.x += _drift_dir * CAPITAL_DRIFT_SPEED * delta
	if position.x > ManeuverSystem.arena_size.x - CAPITAL_DRIFT_MARGIN:
		_drift_dir = -1.0
	elif position.x < CAPITAL_DRIFT_MARGIN:
		_drift_dir = 1.0


func _build_arc_polygon() -> void:
	var half: float = deg_to_rad(firing_arc_degrees * 0.5)
	var reach: float = ManeuverSystem.MAX_RANGE * firing_range_mult
	var close: float = ManeuverSystem.RANGE_CLOSE * firing_range_mult
	var medium: float = ManeuverSystem.RANGE_MEDIUM * firing_range_mult

	# Outer (LONG) band: RANGE_MEDIUM → MAX_RANGE
	_firing_arc.polygon = _arc_band_pts(medium, reach, half)
	_firing_arc.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.06)
	_firing_arc.visible = false

	# Medium band: RANGE_CLOSE → RANGE_MEDIUM
	if _arc_medium_band == null:
		_arc_medium_band = Polygon2D.new()
		_arc_medium_band.name = "ArcMedium"
		add_child(_arc_medium_band)
	_arc_medium_band.polygon = _arc_band_pts(close, medium, half)
	_arc_medium_band.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
	_arc_medium_band.visible = false

	# Close band: 0 → RANGE_CLOSE
	if _arc_close_band == null:
		_arc_close_band = Polygon2D.new()
		_arc_close_band.name = "ArcClose"
		add_child(_arc_close_band)
	_arc_close_band.polygon = _arc_sector_pts(close, half)
	_arc_close_band.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.20)
	_arc_close_band.visible = false


func _arc_sector_pts(radius: float, half: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(13):
		var t: float = float(i) / 12.0
		var angle: float = lerp(-half, half, t)
		pts.append(Vector2(0.0, -1.0).rotated(angle) * radius)
	return pts


func _arc_band_pts(inner: float, outer: float, half: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(13):
		var t: float = float(i) / 12.0
		var angle: float = lerp(-half, half, t)
		pts.append(Vector2(0.0, -1.0).rotated(angle) * outer)
	for i in range(12, -1, -1):
		var t: float = float(i) / 12.0
		var angle: float = lerp(-half, half, t)
		pts.append(Vector2(0.0, -1.0).rotated(angle) * inner)
	return pts


func show_combat_ui(in_arc: bool, hit_chance: float, status: String = "") -> void:
	var close_alpha: float = 0.40 if in_arc else 0.20
	var med_alpha: float   = 0.24 if in_arc else 0.12
	var long_alpha: float  = 0.12 if in_arc else 0.06
	if _arc_close_band != null:
		_arc_close_band.color = Color(accent_color.r, accent_color.g, accent_color.b, close_alpha)
		_arc_close_band.visible = true
	if _arc_medium_band != null:
		_arc_medium_band.color = Color(accent_color.r, accent_color.g, accent_color.b, med_alpha)
		_arc_medium_band.visible = true
	_firing_arc.color = Color(accent_color.r, accent_color.g, accent_color.b, long_alpha)
	_firing_arc.visible = true
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
	if _arc_close_band != null:
		_arc_close_band.visible = false
	if _arc_medium_band != null:
		_arc_medium_band.visible = false
	_hit_label.visible = false
	_hit_label.add_theme_color_override("font_color", accent_color)
	if _rear_arc != null:
		_rear_arc.visible = false


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


# Applies one-time setup perks. Call after pilot AND upgrade are assigned, AFTER class stats.
func has_crit(crit_id: String) -> bool:
	return crit_id in active_crits


func add_crit(crit_id: String) -> void:
	active_crits.append(crit_id)
	_flash_crit()


func _flash_crit() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(1.0, 0.8, 0.0, 1.0), 0.05)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.2)
	tween.tween_property(_body, "modulate", Color(1.0, 0.8, 0.0, 1.0), 0.05)
	tween.tween_property(_body, "modulate", Color.WHITE, 0.2)


func apply_setup_passives() -> void:
	match get_passive():
		"STALWART":
			hull += 1
	match upgrade:
		"Reinforced Plating":
			hull += 1
		"Shield Capacitor":
			shields += 1


func is_ionized() -> bool:
	# Capital ships are too massive to be disrupted by ion fire.
	return ion_tokens > 0 and not is_capital


func _system_down(system_name: String) -> bool:
	return not is_capital and int(disabled_systems.get(system_name, 0)) > 0


func shields_disrupted() -> bool:
	if is_capital:
		return false
	return ion_tokens >= CombatSystem.ION_THRESHOLD_SHIELDS or _system_down("SHIELDS")


func engines_disabled() -> bool:
	return _system_down("ENGINES")


func weapons_disabled() -> bool:
	return _system_down("WEAPONS")


func sensors_disabled() -> bool:
	return _system_down("SENSORS")


# Turns this ship into a hulking capital-ship hull: large, non-targetable scenery
# that mounts turrets. The hull itself does not fire and cannot be destroyed.
func make_capital() -> void:
	is_capital = true
	is_targetable = false
	_body.visible = false
	_firing_arc.visible = false
	_draw_as_hull = true
	queue_redraw()


func _draw() -> void:
	if not _draw_as_hull:
		return
	draw_rect(Rect2(0.0, 0.0, ManeuverSystem.arena_size.x, 80.0), Color(0.22, 0.22, 0.26, 1.0))
	draw_line(Vector2(0.0, 80.0), Vector2(ManeuverSystem.arena_size.x, 80.0),
			Color(0.5, 0.5, 0.55, 0.9), 2.0)


func rebuild_arc() -> void:
	_build_arc_polygon()


# Apply a size class: scale the sprite and set the collision footprint.
func set_size(sprite_scale: float, radius: float) -> void:
	collision_radius = radius
	if _body != null:
		_body.scale = Vector2(sprite_scale, sprite_scale)


# Build the rear-turret arc cone (points backward). Call after rear_arc_degrees is set.
func setup_rear_arc() -> void:
	if not has_rear_turret or rear_arc_degrees <= 0.0:
		return
	_rear_arc = Polygon2D.new()
	add_child(_rear_arc)
	var half: float = deg_to_rad(rear_arc_degrees * 0.5)
	var reach: float = ManeuverSystem.MAX_RANGE * firing_range_mult
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(13):
		var t := float(i) / 12.0
		var angle: float = lerp(-half, half, t)
		pts.append(Vector2(0.0, 1.0).rotated(angle) * reach)   # backward (+Y is rear)
	_rear_arc.polygon = pts
	_rear_arc.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.08)
	_rear_arc.visible = false


# Rear cone shown during combat: low opacity, brighter (and whiter, to distinguish from
# the forward cone) when an enemy is in the rear arc.
func show_rear_arc(in_arc: bool) -> void:
	if _rear_arc == null:
		return
	_rear_arc.visible = true
	if in_arc:
		_rear_arc.color = Color(0.9, 0.9, 1.0, 0.26)
	else:
		_rear_arc.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.08)


# Makes this ship a capital turret: a wide-arc emplacement with its own hull.
func make_turret() -> void:
	firing_arc_degrees = 120.0
	firing_range_mult = 1.1
	_body.scale = Vector2(3.0, 3.0)
	_build_arc_polygon()


func get_maneuver_color(bearing: String, speed: int = 0) -> String:
	if dial_data != null:
		if speed > 0:
			var c: String = dial_data.get_color(bearing, speed)
			return c if c != "" else "WHITE"
		# Bearing-only query: return the least-restrictive color available for this bearing
		# across all speeds, so callers can ask "is this bearing ever green/white?" correctly.
		if dial_data.dial.has(bearing):
			var best: String = "RED"
			for c: String in (dial_data.dial[bearing] as Dictionary).values():
				if c == "GREEN":
					return "GREEN"
				if c == "WHITE":
					best = "WHITE"
			return best
		return "WHITE"
	# Legacy fallback for ships without DialData (capital turrets, etc.).
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
	if _arc_close_band != null:
		_arc_close_band.visible = false
	if _arc_medium_band != null:
		_arc_medium_band.visible = false
	_hit_label.visible = false
	_body.visible = false


# Crossed an ESCAPE edge: jumped out of the battle. Survived, not destroyed, no longer
# a combatant — fades out with a brief jump flare.
func escape_ship() -> void:
	escaped = true
	is_targetable = false
	_firing_arc.visible = false
	_hit_label.visible = false
	var tween := create_tween()
	tween.tween_property(_body, "modulate", Color(0.6, 1.0, 0.8, 0.0), 0.35)
	tween.parallel().tween_property(_body, "scale", Vector2(0.4, 0.4), 0.35)


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
