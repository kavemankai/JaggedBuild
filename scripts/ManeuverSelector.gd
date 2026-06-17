extends PanelContainer

const DialData := preload("res://scripts/DialData.gd")

signal maneuver_picked(ship: Ship, maneuver: Maneuver)
signal closed

@onready var _grid: GridContainer = $Margin/Grid

var _ship: Ship = null
var _ghost: Node2D = null


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = UIConstants.COLOR_BG_PANEL
	style.border_color = UIConstants.COLOR_CYAN
	style.set_border_width_all(UIConstants.BORDER_W)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)

# Canonical column order for dial display.
const BEARING_ORDER: Array = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN", "PIVOT"]


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

	if _ship.dial_data != null:
		_populate_from_dial()
	else:
		_populate_legacy()


func _populate_from_dial() -> void:
	var dial: DialData = _ship.dial_data
	var stressed: bool = _ship.stress > 0
	var engines_out: bool = _ship.engines_disabled()

	# Build sorted bearing list (only bearings present in the dial, in canonical order).
	var bearings: Array = []
	for b in BEARING_ORDER:
		if dial.dial.has(b):
			bearings.append(b)

	# Build sorted speed list from all speeds present in the dial.
	var speed_set: Array = []
	for b in bearings:
		var speeds_dict: Dictionary = dial.dial[b] as Dictionary
		for spd in speeds_dict.keys():
			if not speed_set.has(int(spd)):
				speed_set.append(int(spd))
	speed_set.sort()

	_grid.columns = bearings.size()

	for spd: int in speed_set:
		for bearing: String in bearings:
			var color: String = dial.get_color(bearing, spd)
			if color == "":
				# Gap in the dial — invisible spacer to preserve grid alignment.
				var spacer := Control.new()
				spacer.custom_minimum_size = Vector2(120, 32)
				_grid.add_child(spacer)
				continue

			var btn := Button.new()
			btn.text = bearing.replace("_", " ") + " " + str(spd)
			btn.custom_minimum_size = Vector2(120, 32)
			btn.add_theme_font_override("font", UIConstants.FONT_UI)
			btn.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
			_apply_color(btn, color)

			if stressed and color == "RED":
				btn.disabled = true
				btn.modulate = Color(1.0, 1.0, 1.0, 0.3)
				btn.tooltip_text = "STRESSED"
			elif engines_out and color != "WHITE":
				btn.disabled = true
				btn.tooltip_text = "ENGINES DISABLED — white maneuvers only"

			if _is_selected(bearing, spd):
				btn.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
				btn.text = "● " + btn.text

			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = spd
			btn.mouse_entered.connect(_on_hover.bind(m))
			btn.pressed.connect(_on_pick.bind(m))
			_grid.add_child(btn)


func _populate_legacy() -> void:
	_grid.columns = _ship.bearing_options.size()
	var stressed: bool = _ship.stress > 0
	var engines_out: bool = _ship.engines_disabled()

	for spd: int in _ship.speed_options:
		for bearing: String in _ship.bearing_options:
			var btn := Button.new()
			btn.text = bearing.replace("_", " ") + " " + str(spd)
			btn.custom_minimum_size = Vector2(120, 32)
			btn.add_theme_font_override("font", UIConstants.FONT_UI)
			btn.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)

			var move_color: String = _ship.get_maneuver_color(bearing)
			_apply_color(btn, move_color)

			if stressed and move_color == "RED":
				btn.disabled = true
				btn.modulate = Color(1.0, 1.0, 1.0, 0.3)
				btn.tooltip_text = "STRESSED"
			elif engines_out and move_color != "WHITE":
				btn.disabled = true
				btn.tooltip_text = "ENGINES DISABLED — white maneuvers only"

			if _is_selected(bearing, spd):
				btn.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
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
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = UIConstants.COLOR_BG_SECONDARY
	cell_style.set_corner_radius_all(2)
	var hover_style := StyleBoxFlat.new()
	hover_style.set_corner_radius_all(2)

	match move_color:
		"RED":
			cell_style.border_color = UIConstants.COLOR_RED_DIAL
			cell_style.set_border_width_all(UIConstants.BORDER_W)
			hover_style.bg_color = Color(UIConstants.COLOR_RED_DIAL, 0.2)
			hover_style.border_color = UIConstants.COLOR_RED_DIAL
			hover_style.set_border_width_all(UIConstants.BORDER_W)
			btn.add_theme_color_override("font_color", UIConstants.COLOR_RED_DIAL)
			btn.add_theme_color_override("font_hover_color", UIConstants.COLOR_WHITE)
			btn.add_theme_color_override("font_disabled_color",
				Color(UIConstants.COLOR_RED_DIAL, 0.4))
		"GREEN":
			cell_style.border_color = UIConstants.COLOR_GREEN_DIAL
			cell_style.set_border_width_all(UIConstants.BORDER_W)
			hover_style.bg_color = Color(UIConstants.COLOR_GREEN_DIAL, 0.2)
			hover_style.border_color = UIConstants.COLOR_GREEN_DIAL
			hover_style.set_border_width_all(UIConstants.BORDER_W)
			btn.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
			btn.add_theme_color_override("font_hover_color", UIConstants.COLOR_WHITE)
		_:
			cell_style.border_color = UIConstants.COLOR_BORDER
			cell_style.set_border_width_all(UIConstants.BORDER_W)
			hover_style.bg_color = Color(UIConstants.COLOR_BORDER, 0.3)
			hover_style.border_color = UIConstants.COLOR_SILVER
			hover_style.set_border_width_all(UIConstants.BORDER_W)
			btn.add_theme_color_override("font_color", UIConstants.COLOR_WHITE)
			btn.add_theme_color_override("font_hover_color", UIConstants.COLOR_CYAN)

	btn.add_theme_stylebox_override("normal", cell_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("focus", cell_style)
