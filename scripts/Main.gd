extends Node2D

@onready var player_ship: Ship = $Ships/PlayerShip
@onready var ai_ship: Ship = $Ships/AIShip
@onready var ghost_ship: Node2D = $GhostShip
@onready var selection_panel: Control = $UI/SelectionPanel
@onready var ai_controller: Node = $AIController


func _ready() -> void:
	ai_ship.speed_options = [1, 2, 3]
	ai_ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT"]
	ai_ship.attack = 2
	ai_ship.defence = 3
	ai_ship.shields = 3
	ai_ship.hull = 2

	selection_panel.setup(player_ship, ghost_ship)
	selection_panel.maneuver_confirmed.connect(_on_maneuver_confirmed)

	$HUD.setup_health(player_ship, ai_ship)

	RoundManager.register_ships([player_ship, ai_ship])
	RoundManager.planning_phase_started.connect(_on_planning_started)
	RoundManager.resolution_phase_started.connect(_on_resolution_started)
	RoundManager.begin_round()


func _on_planning_started() -> void:
	selection_panel.visible = true
	selection_panel.reset()
	ai_ship.selected_maneuver = ai_controller.select_maneuver(ai_ship, player_ship)
	ai_ship.selected_action = ai_controller.select_action(ai_ship, player_ship)


func _on_resolution_started() -> void:
	selection_panel.visible = false


func _on_maneuver_confirmed(_maneuver: Maneuver) -> void:
	RoundManager.resolve_maneuvers()
