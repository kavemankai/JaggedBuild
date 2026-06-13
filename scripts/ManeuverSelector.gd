extends PanelContainer

signal maneuver_picked(ship: Ship, maneuver: Maneuver)
signal closed

@onready var _grid: GridContainer = $Margin/Grid

var _ship: Ship = null
var _ghost: Node2D = null


func open_for(ship: Ship, ghost: Node2D) -> void:
	_ship = ship
	_ghost = ghost
	visible = true
	_populate()


func close() -> void:
	if not visible:
		return
	visible = false
	_ship = null
	_ghost = null
	closed.emit()


func _populate() -> void:
	for child in _grid.get_children():
		child.queue_free()

	_grid.columns = _ship.bearing_options.size()
	var stressed: bool = _ship.stress > 0

	for spd: int in _ship.speed_options:
		for bearing: String in _ship.bearing_options:
			var btn := Button.new()
			btn.text = bearing.replace("_", " ") + " " + str(spd)
			btn.custom_minimum_size = Vector2(120, 32)

			var move_color: String = _ship.get_maneuver_color(bearing)
			_apply_color(btn, move_color)

			var is_red: bool = move_color == "RED"
			if stressed and is_red:
				btn.disabled = true
				btn.tooltip_text = "STRESSED — red maneuvers unavailable"

			if _is_selected(bearing, spd):
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 1.0))
				btn.text = "● " + btn.text

			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = spd
			btn.mouse_entered.connect(_on_hover.bind(m))
			btn.pressed.connect(_on_pick.bind(m))
			_grid.add_child(btn)


func _is_selected(bearing: String, spd: int) -> bool:
	var m: Maneuver = _ship.selected_maneuver
	return m != null and m.bearing == bearing and m.speed == spd


func _on_hover(maneuver: Maneuver) -> void:
	if _ghost != null:
		_ghost.update_preview(_ship, maneuver, true)


func _on_pick(maneuver: Maneuver) -> void:
	_ship.selected_maneuver = maneuver
	if _ghost != null:
		_ghost.update_preview(_ship, maneuver, false)
	maneuver_picked.emit(_ship, maneuver)
	close()


func _apply_color(btn: Button, move_color: String) -> void:
	match move_color:
		"RED":
			btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55, 1.0))
			btn.add_theme_color_override("font_disabled_color", Color(1.0, 0.3, 0.3, 0.4))
		"GREEN":
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.55, 1.0, 0.65, 1.0))
		_:
			pass
