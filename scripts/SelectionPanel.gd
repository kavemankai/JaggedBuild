extends Control

signal maneuver_confirmed(maneuver: Maneuver)

@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var ready_label: Label = $Panel/VBox/Ready
@onready var _action_row: HBoxContainer = $Panel/VBox/ActionRow

var ship: Ship = null
var ghost_ship: Node2D = null
var confirmed: bool = false


func setup(ship_node: Ship, ghost_node: Node2D) -> void:
	ship = ship_node
	ghost_ship = ghost_node
	grid.columns = ship.bearing_options.size()
	_populate_grid()
	_populate_actions()


func _populate_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	for spd: int in ship.speed_options:
		for bearing: String in ship.bearing_options:
			var btn := Button.new()
			btn.text = bearing.replace("_", " ") + " " + str(spd)
			btn.custom_minimum_size = Vector2(148, 38)

			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = spd

			var move_color := ship.get_maneuver_color(bearing)
			btn.set_meta("bearing", bearing)
			btn.set_meta("move_color", move_color)
			_apply_maneuver_color(btn, move_color)
			btn.mouse_entered.connect(_on_hover.bind(m))
			btn.pressed.connect(_on_select.bind(m))
			grid.add_child(btn)


func _populate_actions() -> void:
	for child in _action_row.get_children():
		child.queue_free()

	var actions := [["FOCUS", "FOCUS"], ["TARGET LOCK", "TARGET_LOCK"], ["EVADE", "EVADE"], ["BOOST", "BOOST"]]
	for entry in actions:
		var label: String = entry[0]
		var key: String = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(148, 38)
		btn.toggle_mode = true
		btn.set_meta("action_key", key)
		btn.toggled.connect(_on_action_toggled.bind(key))
		_action_row.add_child(btn)


func _on_hover(maneuver: Maneuver) -> void:
	if confirmed:
		return
	ghost_ship.update_preview(ship, maneuver)


func _on_select(maneuver: Maneuver) -> void:
	if confirmed:
		return
	confirmed = true
	ship.selected_maneuver = maneuver
	ghost_ship.update_preview(ship, maneuver)
	ready_label.text = "READY"
	_lock_buttons()
	maneuver_confirmed.emit(maneuver)


func _on_action_toggled(button_pressed: bool, action: String) -> void:
	if confirmed:
		return
	if button_pressed:
		ship.selected_action = action
		for btn in _action_row.get_children():
			if btn is Button and btn.get_meta("action_key", "") != action:
				btn.button_pressed = false
	else:
		ship.selected_action = ""


func _apply_maneuver_color(btn: Button, move_color: String) -> void:
	match move_color:
		"RED":
			btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55, 1.0))
			btn.add_theme_color_override("font_disabled_color", Color(1.0, 0.3, 0.3, 0.4))
		"GREEN":
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.55, 1.0, 0.65, 1.0))
			btn.add_theme_color_override("font_disabled_color", Color(0.3, 1.0, 0.45, 0.4))
		_:
			pass  # white default


func _lock_buttons() -> void:
	for child in grid.get_children():
		if child is Button:
			child.disabled = true
	for child in _action_row.get_children():
		if child is Button:
			child.disabled = true


func reset() -> void:
	confirmed = false
	ready_label.text = ""
	ghost_ship.clear_preview()
	if ship != null:
		ship.selected_action = ""
	var stressed: bool = ship != null and ship.stress > 0
	for child in grid.get_children():
		if child is Button:
			var is_red: bool = child.get_meta("move_color", "WHITE") == "RED"
			child.disabled = stressed and is_red
			child.modulate = Color(1.0, 1.0, 1.0, 0.45) if (stressed and is_red) else Color.WHITE
	for child in _action_row.get_children():
		if child is Button:
			child.disabled = stressed
			child.button_pressed = false
