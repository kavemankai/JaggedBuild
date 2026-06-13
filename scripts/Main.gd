extends Node2D

@onready var player_ship: Ship = $Ships/PlayerShip
@onready var ai_ship: Ship = $Ships/AIShip
@onready var ghost_ship: Node2D = $GhostShip
@onready var selection_panel: Control = $UI/SelectionPanel
@onready var ai_controller: Node = $AIController

var _game_over: bool = false


func _ready() -> void:
	ai_ship.speed_options = [1, 2, 3]
	ai_ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT"]
	ai_ship.attack = 2
	ai_ship.defence = 3
	ai_ship.shields = 3
	ai_ship.hull = 2

	var heavy := Weapon.new()
	heavy.weapon_type = Weapon.Type.HEAVY
	heavy.display_name = "Heavy Cannon"
	player_ship.weapon = heavy

	var burst := Weapon.new()
	burst.weapon_type = Weapon.Type.BURST
	burst.display_name = "Burst Fire"
	ai_ship.weapon = burst

	var player_pilot := Pilot.new()
	player_pilot.pilot_name = "ACE"
	player_pilot.skill = 5
	player_pilot.accuracy = 1.1
	player_pilot.agility = 1.0
	player_pilot.nerve = 0.3
	player_ship.pilot = player_pilot

	var ai_pilot := Pilot.new()
	ai_pilot.pilot_name = "VIPER"
	ai_pilot.skill = 3
	ai_pilot.accuracy = 1.0
	ai_pilot.agility = 1.1
	ai_pilot.nerve = 0.1
	ai_ship.pilot = ai_pilot

	selection_panel.setup(player_ship, ghost_ship)
	selection_panel.maneuver_confirmed.connect(_on_maneuver_confirmed)

	$HUD.setup_ships(player_ship, ai_ship)

	RoundManager.register_ships([player_ship, ai_ship])
	RoundManager.planning_phase_started.connect(_on_planning_started)
	RoundManager.resolution_phase_started.connect(_on_resolution_started)
	RoundManager.game_ended.connect(func(_m, _c): _game_over = true)
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


func _input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and not event.echo:
		get_tree().reload_current_scene()
