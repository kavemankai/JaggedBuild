extends PanelContainer

signal card_clicked(ship: Ship)
signal selection_changed

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _maneuver_label: Label = $Margin/VBox/ManeuverLabel
@onready var _action_row: HBoxContainer = $Margin/VBox/ActionRow
@onready var _change_btn: Button = $Margin/VBox/ChangeButton

var ship: Ship = null
var _stress_tween: Tween = null


func setup(s: Ship) -> void:
	ship = s
	_name_label.text = ship.get_pilot_name() + " [%d]" % ship.get_skill()
	_name_label.add_theme_color_override("font_color", ship.accent_color)
	if ship.selected_action == "":
		ship.selected_action = "FOCUS"
	_populate_actions()
	_change_btn.pressed.connect(func(): card_clicked.emit(ship))
	refresh()


func _populate_actions() -> void:
	for child in _action_row.get_children():
		child.queue_free()

	var actions := [["FOCUS", "FOCUS"], ["LOCK", "TARGET_LOCK"], ["EVADE", "EVADE"], ["BOOST", "BOOST"]]
	if ship.has_active_ability():
		actions.append([ship.get_active_ability().replace("_", " "), "ABILITY"])

	for entry in actions:
		var label: String = entry[0]
		var key: String = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.set_meta("action_key", key)
		if key == "ABILITY":
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		btn.toggled.connect(_on_action_toggled.bind(key))
		_action_row.add_child(btn)


func _on_action_toggled(pressed: bool, action: String) -> void:
	if not pressed:
		# Keep one action always selected; re-press if user untoggles the active one.
		if ship.selected_action == action:
			for btn in _action_row.get_children():
				if btn is Button and btn.get_meta("action_key", "") == action:
					btn.set_pressed_no_signal(true)
		return
	ship.selected_action = action
	for btn in _action_row.get_children():
		if btn is Button and btn.get_meta("action_key", "") != action:
			btn.set_pressed_no_signal(false)
	selection_changed.emit()


func has_maneuver() -> bool:
	return ship.selected_maneuver != null


func refresh() -> void:
	if ship.escaped:
		_name_label.text = ship.get_pilot_name() + "  [ESCAPED]"
		_name_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
		_maneuver_label.text = "— JUMPED OUT —"
		_maneuver_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.55))
		_change_btn.disabled = true
		if _stress_tween != null:
			_stress_tween.kill()
			_stress_tween = null
		modulate = Color(0.55, 0.8, 0.6, 0.9)
		for btn in _action_row.get_children():
			if btn is Button:
				btn.disabled = true
		return

	if ship.is_destroyed:
		_name_label.text = ship.get_pilot_name() + "  [DOWN]"
		_name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		_maneuver_label.text = "— DESTROYED —"
		_maneuver_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		_change_btn.disabled = true
		if _stress_tween != null:
			_stress_tween.kill()
			_stress_tween = null
		modulate = Color(0.38, 0.38, 0.38, 0.9)
		for btn in _action_row.get_children():
			if btn is Button:
				btn.disabled = true
		return

	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_change_btn.disabled = false

	if ship.selected_maneuver != null:
		var m: Maneuver = ship.selected_maneuver
		_maneuver_label.text = "► " + m.bearing.replace("_", " ") + " " + str(m.speed)
		_maneuver_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	else:
		_maneuver_label.text = "— no orders —"
		_maneuver_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3, 1.0))

	# Ion system-disruption banner (engines restrict to white maneuvers, etc.)
	var ion_note: String = _ion_note()
	if ion_note != "":
		_maneuver_label.text += "   " + ion_note if ship.selected_maneuver != null else ion_note
		_maneuver_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))

	# Reflect the selected action and grey actions out under stress / disruption.
	var stressed: bool = ship.stress > 0
	for btn in _action_row.get_children():
		if btn is Button:
			var key: String = btn.get_meta("action_key", "")
			btn.set_pressed_no_signal(key == ship.selected_action)
			match key:
				"ABILITY":
					btn.disabled = ship.ability_used
				"BOOST":
					btn.disabled = stressed or ship.engines_disabled()
				"TARGET_LOCK":
					btn.disabled = stressed or ship.sensors_disabled()
				_:
					btn.disabled = stressed

	_update_stress_border(stressed or ship.ion_tokens > 0 or not ship.disabled_systems.is_empty())


func _ion_note() -> String:
	var parts: Array = []
	if ship.ion_tokens > 0:
		parts.append("ION%d" % ship.ion_tokens)
	if ship.engines_disabled():
		parts.append("ENG✕")
	if ship.weapons_disabled():
		parts.append("WPN✕")
	if ship.sensors_disabled():
		parts.append("SEN✕")
	if ship.shields_disrupted():
		parts.append("SHLD✕")
	return " ".join(parts)


func _update_stress_border(active: bool) -> void:
	if active and _stress_tween == null:
		_stress_tween = create_tween().set_loops()
		_stress_tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.5, 1.0), 0.5)
		_stress_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	elif not active and _stress_tween != null:
		_stress_tween.kill()
		_stress_tween = null
		modulate = Color(1.0, 1.0, 1.0, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _change_btn.disabled:
			card_clicked.emit(ship)
