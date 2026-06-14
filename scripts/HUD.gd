extends CanvasLayer

const Objective := preload("res://scripts/Objective.gd")

@onready var _mission_label: Label = $Info/Mission
@onready var _round_label: Label = $Info/Round
@onready var _phase_label: Label = $Info/Phase
@onready var _health_bars: VBoxContainer = $HealthBars
@onready var _result: Label = $Result

var _ships: Array = []
var _rows: Array = []  # parallel to _ships: { shields, hull, tokens, status, weapon, hull_low }
var _objective: Objective = null
var _objective_label: Label = null


func _ready() -> void:
	# Method references (not lambdas) so Godot auto-disconnects them when this HUD is
	# freed on scene change. Lambdas connected to a persistent autoload would otherwise
	# stack across battles and fire on freed instances.
	RoundManager.planning_phase_started.connect(_on_planning)
	RoundManager.resolution_phase_started.connect(_on_resolution)
	RoundManager.action_phase_started.connect(_on_action)
	RoundManager.combat_phase_started.connect(_on_combat)
	RoundManager.evaluation_phase_started.connect(_on_evaluation)


func _on_planning() -> void:
	_round_label.text = "Round %d" % RoundManager.round_number
	_phase_label.text = "PLANNING"


func _on_resolution() -> void:
	_phase_label.text = "RESOLVING"


func _on_action() -> void:
	_phase_label.text = "ACTIONS"


func _on_combat() -> void:
	_phase_label.text = "COMBAT"


func _on_evaluation() -> void:
	_phase_label.text = ""


func set_mission_label(text: String) -> void:
	_mission_label.text = text


func set_objective(obj: Objective) -> void:
	_objective = obj
	if _objective_label == null:
		_objective_label = Label.new()
		_objective_label.modulate = Color(0.55, 0.95, 0.65, 1.0)
		_objective_label.add_theme_font_size_override("font_size", 13)
		$Info.add_child(_objective_label)
		$Info.move_child(_objective_label, 1)   # just under the mission name


func setup_ships(ships: Array) -> void:
	_ships = ships
	for child in _health_bars.get_children():
		child.queue_free()
	_rows.clear()

	for s in ships:
		var ship: Ship = s as Ship
		var row := HBoxContainer.new()
		_health_bars.add_child(row)

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(80, 0)
		name_label.text = ship.get_pilot_name() + " [%d]" % ship.get_skill()
		name_label.modulate = ship.accent_color
		row.add_child(name_label)

		var shields := ProgressBar.new()
		shields.custom_minimum_size = Vector2(70, 16)
		shields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shields.max_value = maxi(1, ship.shields)
		shields.value = ship.shields
		shields.show_percentage = false
		_style_bar(shields, Color(0.2, 0.4, 0.9))
		row.add_child(shields)

		var gap := Label.new()
		gap.text = " "
		row.add_child(gap)

		var hull := ProgressBar.new()
		hull.custom_minimum_size = Vector2(70, 16)
		hull.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hull.max_value = maxi(1, ship.hull)
		hull.value = ship.hull
		hull.show_percentage = false
		_style_bar(hull, Color(0.9, 0.5, 0.1))
		row.add_child(hull)

		var tokens := Label.new()
		tokens.custom_minimum_size = Vector2(40, 0)
		tokens.modulate = Color(0.95, 0.85, 0.2, 1.0)
		row.add_child(tokens)

		var status := Label.new()
		status.custom_minimum_size = Vector2(48, 0)
		status.modulate = Color(1.0, 0.3, 0.3, 1.0)
		row.add_child(status)

		var weapon := Label.new()
		weapon.custom_minimum_size = Vector2(110, 0)
		weapon.modulate = Color(0.7, 0.7, 0.9, 1.0)
		row.add_child(weapon)

		_rows.append({
			"shields": shields,
			"hull": hull,
			"tokens": tokens,
			"status": status,
			"weapon": weapon,
			"hull_low": false,
		})


func _process(_delta: float) -> void:
	if _objective_label != null and _objective != null:
		_objective_label.text = _objective.progress_text(_ships, RoundManager.round_number)

	for i in range(_ships.size()):
		var ship: Ship = _ships[i] as Ship
		var row: Dictionary = _rows[i]

		row.shields.value = ship.shields
		row.hull.value = ship.hull
		row.tokens.text = _token_text(ship)
		row.status.text = _status_text(ship)
		row.weapon.text = _weapon_text(ship)

		var low: bool = ship.hull <= row.hull.max_value * 0.5
		if low != row.hull_low:
			row.hull_low = low
			_style_bar(row.hull, Color(0.9, 0.15, 0.1) if low else Color(0.9, 0.5, 0.1))


func show_result(message: String, color: Color, summary: Array) -> void:
	var text: String = message
	if not summary.is_empty():
		text += "\n"
		for line in summary:
			text += "\n" + str(line)
	text += "\n\nPRESS ANY KEY"
	_result.text = text
	_result.modulate = color
	# Scale the font down so long campaign-end / memorial summaries fit the screen.
	var lines: int = text.count("\n") + 1
	var size: int = 40
	if lines > 18:
		size = 18
	elif lines > 10:
		size = 24
	elif lines > 5:
		size = 30
	_result.add_theme_font_size_override("font_size", size)
	_result.visible = true


func _weapon_text(ship: Ship) -> String:
	var w: Weapon = ship.weapon as Weapon
	if w == null:
		return "Cannons"
	match w.weapon_type:
		Weapon.Type.BURST:
			return "Burst ×2"
		Weapon.Type.HEAVY:
			if ship.heavy_cooldown > 0:
				return "Heavy [cd:%d]" % ship.heavy_cooldown
			return "Heavy READY"
		Weapon.Type.MISSILES:
			if ship.missiles_ammo <= 0:
				return "Missiles [EMPTY]"
			return "Missiles x%d" % ship.missiles_ammo
		Weapon.Type.ION:
			return "Ion"
		Weapon.Type.TURRET:
			if ship.heavy_cooldown > 0:
				return "Turret [cd:%d]" % ship.heavy_cooldown
			return "Turret"
	return "Cannons"


func _status_text(ship: Ship) -> String:
	if ship.is_destroyed:
		return "DOWN"
	var parts: Array = []
	if ship.stress > 0:
		parts.append("S%d" % ship.stress)
	if ship.ion_tokens > 0:
		parts.append("I%d" % ship.ion_tokens)
	if ship.engines_disabled():
		parts.append("ENG")
	if ship.weapons_disabled():
		parts.append("WPN")
	if ship.sensors_disabled():
		parts.append("SEN")
	return " ".join(parts)


func _token_text(ship: Ship) -> String:
	var parts: Array = []
	if ship.focus_token:
		parts.append("F")
	if ship.evade_token:
		parts.append("E")
	if ship.target_lock != null:
		parts.append("TL")
	if ship.overcharged:
		parts.append("OC")
	if ship.in_formation:
		parts.append("⬡")
	return " ".join(parts)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar.add_theme_stylebox_override("background", bg)
