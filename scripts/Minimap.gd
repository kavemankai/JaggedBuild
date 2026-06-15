extends Control

# Corner overview of the whole arena. Draws simplified markers (not real ships) from
# world coords scaled into the minimap rect: ship dots, the capital hull bar, the live
# camera viewport rectangle, and objective hints. Click/drag to jump the camera.
# Redraws on phase changes + camera movement (not per-frame) — cheap.

const Objective := preload("res://scripts/Objective.gd")

const PLAYER_COL := Color(0.3, 0.8, 1.0)
const ENEMY_COL := Color(1.0, 0.35, 0.8)
const DEAD_COL := Color(0.35, 0.35, 0.4)
const PAD := 6.0

var _ships: Array = []
var _camera: Node = null
var _objective: Objective = null
var arena: Vector2 = Vector2(1600, 900)

var _last_cam: Vector2 = Vector2.ZERO
var _last_zoom: float = 1.0


func setup(ships: Array, camera: Node, objective: Objective, arena_size: Vector2) -> void:
	_ships = ships
	_camera = camera
	_objective = objective
	arena = arena_size
	# Method references (auto-disconnected when this node frees) — redraw each phase.
	RoundManager.planning_phase_started.connect(queue_redraw)
	RoundManager.resolution_phase_started.connect(queue_redraw)
	RoundManager.action_phase_started.connect(queue_redraw)
	RoundManager.combat_phase_started.connect(queue_redraw)
	RoundManager.evaluation_phase_started.connect(queue_redraw)
	queue_redraw()


func _process(_delta: float) -> void:
	# Keep the viewport rectangle live as the camera pans/zooms.
	if _camera != null and (_camera.position != _last_cam or _camera.zoom.x != _last_zoom):
		_last_cam = _camera.position
		_last_zoom = _camera.zoom.x
		queue_redraw()


func _inner() -> Rect2:
	return Rect2(PAD, PAD, size.x - 2.0 * PAD, size.y - 2.0 * PAD)


func _map_scale() -> float:
	var inner: Rect2 = _inner()
	return minf(inner.size.x / arena.x, inner.size.y / arena.y)


func _map_origin() -> Vector2:
	var inner: Rect2 = _inner()
	var mapped: Vector2 = arena * _map_scale()
	return inner.position + (inner.size - mapped) * 0.5


func _w2m(p: Vector2) -> Vector2:
	return _map_origin() + p * _map_scale()


func _draw() -> void:
	var s: float = _map_scale()
	var o: Vector2 = _map_origin()

	# Frame + arena field.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.4, 0.5, 0.8), false, 1.0)
	draw_rect(Rect2(o, arena * s), Color(0.10, 0.10, 0.16, 1.0))

	# Objective hint: the escape/far edge for REACH_EDGE missions.
	if _objective != null and _objective.type == Objective.Type.REACH_EDGE:
		var y: float = o.y + _objective.edge_y * s
		draw_line(Vector2(o.x, y), Vector2(o.x + arena.x * s, y), Color(0.4, 1.0, 0.5, 0.8), 1.5)

	# Ships.
	for sh in _ships:
		var ship: Ship = sh as Ship
		if not is_instance_valid(ship):
			continue
		if ship.is_capital:
			# Hull bar spanning the arena width at its world y.
			var by: float = o.y + ship.global_position.y * s
			draw_rect(Rect2(o.x, by, arena.x * s, 3.0), Color(0.7, 0.28, 0.24, 1.0))
			continue
		var col: Color
		if ship.is_destroyed:
			col = DEAD_COL
		elif ship.team == "PLAYER":
			col = PLAYER_COL
		else:
			col = ENEMY_COL
		draw_circle(_w2m(ship.global_position), 3.0, col)

	# Live camera viewport rectangle.
	if _camera != null:
		var half: Vector2 = (get_viewport_rect().size * 0.5) / _camera.zoom
		var tl: Vector2 = _w2m(_camera.position - half)
		var br: Vector2 = _w2m(_camera.position + half)
		draw_rect(Rect2(tl, br - tl), Color(1.0, 1.0, 1.0, 0.9), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_jump_to(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_jump_to(event.position)


func _jump_to(local: Vector2) -> void:
	if _camera == null:
		return
	var world: Vector2 = (local - _map_origin()) / _map_scale()
	_camera.focus_on(world, false)
