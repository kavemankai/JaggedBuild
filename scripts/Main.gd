extends Node2D

@onready var player_ship: Ship = $Ships/PlayerShip
@onready var ghost_ship: Node2D = $GhostShip
@onready var selection_panel: Control = $UI/SelectionPanel


func _ready() -> void:
	selection_panel.setup(player_ship, ghost_ship)
	selection_panel.maneuver_confirmed.connect(_on_maneuver_confirmed)


func _on_maneuver_confirmed(maneuver: Maneuver) -> void:
	pass
