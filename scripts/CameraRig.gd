extends Camera2D

# World camera for bigger-than-screen arenas. Pan (left/middle drag on empty space —
# UI Controls consume their own events so dragging over the strip won't pan), zoom to
# cursor (scroll), clamped to arena bounds + margin. focus_on() smoothly centres a ship.
#
# Zoom semantics (Godot 4): larger zoom = more zoomed IN. 0.4 = wide, 1.5 = close.

const ZOOM_MIN: float = 0.4
const ZOOM_MAX: float = 1.5
const ZOOM_STEP: float = 1.1          # multiplicative per wheel notch
const PAN_MARGIN: float = 200.0       # how far past the arena edge the view may show
const LERP_SPEED: float = 8.0         # focus-jump smoothing
const FOCUS_ZOOM: float = 1.0         # zoom level a focus-jump settles to

var arena: Vector2 = Vector2(1600, 900)

var _panning: bool = false
var _focusing: bool = false
var _target_pos: Vector2 = Vector2.ZERO


func setup(arena_size: Vector2) -> void:
	arena = arena_size
	# Start centred, zoomed to fit the whole map (clamped to the zoom range).
	var vp: Vector2 = get_viewport_rect().size
	var fit: float = clampf(minf(vp.x / arena.x, vp.y / arena.y), ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(fit, fit)
	position = arena * 0.5
	_target_pos = position
	make_current()
	_clamp_position()


# Smoothly centre the camera on a world position (used by the focus-ship button).
func focus_on(world_pos: Vector2, do_zoom: bool = true) -> void:
	_target_pos = world_pos
	_focusing = true
	if do_zoom:
		var z: float = clampf(FOCUS_ZOOM, ZOOM_MIN, ZOOM_MAX)
		zoom = Vector2(z, z)
		_clamp_position()


func frame_all(points: Array) -> void:
	if points.is_empty():
		return
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points:
		rect = rect.expand(p)
	rect = rect.grow(160.0)
	var vp: Vector2 = get_viewport_rect().size
	var z: float = clampf(minf(vp.x / maxf(rect.size.x, 1.0), vp.y / maxf(rect.size.y, 1.0)), ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	_target_pos = rect.get_center()
	_focusing = true
	_clamp_position()


func _process(delta: float) -> void:
	if _focusing:
		position = position.lerp(_target_pos, clampf(LERP_SPEED * delta, 0.0, 1.0))
		_clamp_position()
		if position.distance_to(_target_pos) < 1.0:
			position = _target_pos
			_focusing = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				if mb.pressed:
					_focusing = false   # manual control cancels a focus-jump
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_to_cursor(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_to_cursor(1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and _panning:
		# Move in world units (screen delta divided by zoom).
		var motion := (event as InputEventMouseMotion).relative
		position -= motion / zoom
		_focusing = false
		_clamp_position()


# Zoom keeping the world point under the cursor fixed (RTS feel).
func _zoom_to_cursor(factor: float) -> void:
	var before: Vector2 = get_global_mouse_position()
	var z: float = clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	var after: Vector2 = get_global_mouse_position()
	position += before - after
	_focusing = false
	_clamp_position()


# Keep the visible rect inside arena + margin; centre on a small map that under-fills.
func _clamp_position() -> void:
	var half: Vector2 = (get_viewport_rect().size * 0.5) / zoom
	var min_x: float = half.x - PAN_MARGIN
	var max_x: float = arena.x - half.x + PAN_MARGIN
	var min_y: float = half.y - PAN_MARGIN
	var max_y: float = arena.y - half.y + PAN_MARGIN
	position.x = arena.x * 0.5 if min_x > max_x else clampf(position.x, min_x, max_x)
	position.y = arena.y * 0.5 if min_y > max_y else clampf(position.y, min_y, max_y)
