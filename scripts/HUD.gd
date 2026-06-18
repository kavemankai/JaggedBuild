extends CanvasLayer

const Objective  := preload("res://scripts/Objective.gd")
const SHIP_CARD  := preload("res://scenes/ShipCard.tscn")

@onready var _mission_label: Label   = $TopBar/TopMargin/TopHBox/Mission
@onready var _round_label: Label     = $TopBar/TopMargin/TopHBox/Round
@onready var _phase_label: Label     = $TopBar/TopMargin/TopHBox/Phase
@onready var _health_bars: VBoxContainer = $RightPanel/RightScroll/HealthBars
@onready var _result: Label          = $Result

var _ships: Array = []
var _cards: Array = []
var _objective: Objective = null
var _objective_label: Label = null


func _ready() -> void:
	_apply_hud_style()
	RoundManager.planning_phase_started.connect(_on_planning)
	RoundManager.resolution_phase_started.connect(_on_resolution)
	RoundManager.action_phase_started.connect(_on_action)
	RoundManager.combat_phase_started.connect(_on_combat)
	RoundManager.evaluation_phase_started.connect(_on_evaluation)


func _apply_hud_style() -> void:
	# Top bar
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = UIConstants.COLOR_BG_PANEL
	top_style.border_color = UIConstants.COLOR_BORDER
	top_style.border_width_bottom = UIConstants.BORDER_W
	$TopBar.add_theme_stylebox_override("panel", top_style)

	_mission_label.add_theme_font_override("font", UIConstants.FONT_NARR)
	_mission_label.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	_mission_label.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)

	_round_label.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	_round_label.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
	_round_label.add_theme_color_override("font_color", UIConstants.COLOR_WHITE)

	_phase_label.add_theme_font_override("font", UIConstants.FONT_UI)
	_phase_label.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)

	# Right panel
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = UIConstants.COLOR_BG_PANEL
	right_style.border_color = UIConstants.COLOR_BORDER
	right_style.border_width_left = UIConstants.BORDER_W
	$RightPanel.add_theme_stylebox_override("panel", right_style)

	# Result label
	_result.add_theme_font_override("font", UIConstants.FONT_NARR_BOLD)


func _on_planning() -> void:
	_round_label.text = "ROUND %02d" % RoundManager.round_number
	_phase_label.text = "PLANNING"
	_phase_label.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)


func _on_resolution() -> void:
	_phase_label.text = "RESOLVING"
	_phase_label.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)


func _on_action() -> void:
	_phase_label.text = "ACTIONS"
	_phase_label.add_theme_color_override("font_color", UIConstants.COLOR_WHITE)


func _on_combat() -> void:
	_phase_label.text = "COMBAT"
	_phase_label.add_theme_color_override("font_color", UIConstants.COLOR_MAGENTA)


func _on_evaluation() -> void:
	_phase_label.text = "EVALUATION"
	_phase_label.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)


func set_mission_label(text: String) -> void:
	_mission_label.text = text


func set_objective(obj: Objective) -> void:
	_objective = obj
	if _objective_label == null:
		_objective_label = Label.new()
		_objective_label.add_theme_font_override("font", UIConstants.FONT_UI)
		_objective_label.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
		_objective_label.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
		$TopBar/TopMargin/TopHBox.add_child(_objective_label)


func setup_ships(ships: Array) -> void:
	_ships = ships
	for child in _health_bars.get_children():
		child.queue_free()
	_cards.clear()

	var player_ships: Array = ships.filter(func(s): return (s as Ship).team == "PLAYER")
	var enemy_ships: Array  = ships.filter(func(s): return (s as Ship).team != "PLAYER")

	for s in player_ships:
		var card = SHIP_CARD.instantiate()
		_health_bars.add_child(card)
		card.setup(s as Ship, true)
		_cards.append(card)

	if not player_ships.is_empty() and not enemy_ships.is_empty():
		var sep := HSeparator.new()
		var sep_style := StyleBoxFlat.new()
		sep_style.bg_color = UIConstants.COLOR_BORDER
		sep.add_theme_stylebox_override("separator", sep_style)
		_health_bars.add_child(sep)

	for s in enemy_ships:
		var card = SHIP_CARD.instantiate()
		_health_bars.add_child(card)
		card.setup(s as Ship, true)
		_cards.append(card)


func _process(_delta: float) -> void:
	if _objective_label != null and _objective != null:
		_objective_label.text = _objective.progress_text(_ships, RoundManager.round_number)
	for card in _cards:
		if is_instance_valid(card):
			card.refresh()


func show_result(message: String, color: Color, summary: Array) -> void:
	var text: String = message
	if not summary.is_empty():
		text += "\n"
		for line in summary:
			text += "\n" + str(line)
	text += "\n\nPRESS ANY KEY"
	_result.text = text
	_result.modulate = color
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
