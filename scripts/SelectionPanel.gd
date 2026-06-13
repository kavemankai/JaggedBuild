extends Control

signal maneuver_confirmed(maneuver: Maneuver)

@onready var grid: GridContainer = $Panel/VBox/Grid
@onready var ready_label: Label = $Panel/VBox/Ready

var ship: Ship = null
var ghost_ship: Node2D = null
var confirmed: bool = false


func setup(ship_node: Ship, ghost_node: Node2D) -> void:
	ship = ship_node
	ghost_ship = ghost_node
	grid.columns = ship.bearing_options.size()
	_populate_grid()


func _populate_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	# Columns = bearings, rows = speeds — each column shows one maneuver type
	for spd: int in ship.speed_options:
		for bearing: String in ship.bearing_options:
			var btn := Button.new()
			btn.text = bearing.replace("_", " ") + " " + str(spd)
			btn.custom_minimum_size = Vector2(148, 38)

			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = spd

			btn.mouse_entered.connect(_on_hover.bind(m))
			btn.pressed.connect(_on_select.bind(m))
			grid.add_child(btn)


func _on_hover(maneuver: Maneuver) -> void:
	if confirmed:
		return
	ghost_ship.update_preview(ship.global_position, ship.rotation, maneuver, ship.accent_color)


func _on_select(maneuver: Maneuver) -> void:
	if confirmed:
		return
	confirmed = true
	ship.selected_maneuver = maneuver
	ghost_ship.update_preview(ship.global_position, ship.rotation, maneuver, ship.accent_color)
	ready_label.text = "READY"
	_lock_buttons()
	maneuver_confirmed.emit(maneuver)


func _lock_buttons() -> void:
	for child in grid.get_children():
		if child is Button:
			child.disabled = true


func reset() -> void:
	confirmed = false
	ready_label.text = ""
	ghost_ship.clear_preview()
	for child in grid.get_children():
		if child is Button:
			child.disabled = false
