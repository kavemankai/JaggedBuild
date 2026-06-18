class_name ShipClassData
extends Resource

const DialData := preload("res://scripts/DialData.gd")

@export var class_name_display: String = ""
@export var faction: String = "player"          # "player" or "enemy"
@export var attack: int = 2
@export var defence: int = 2
@export var shields: int = 2
@export var hull: int = 3
@export var firing_arc_degrees: float = 90.0
@export var turret_arc_degrees: float = 0.0     # rear arc; 0 = no rear turret
@export var dial: DialData = null
@export var primary_weapon_options: Array = []  # Array of Weapon.Type values
@export var secondary_weapon_options: Array = []
@export var upgrade_slots: int = 1

# Size class (Large ship system). SMALL is the default fighter footprint.
@export var size_class: String = "SMALL"        # "SMALL" | "LARGE"
@export var collision_radius: float = 40.0      # LARGE overrides to 75
@export var sprite_scale: float = 0.2           # LARGE overrides to 0.33
@export var has_rear_turret: bool = false       # Large hulls fire a fixed rear TURRET
@export var is_objective: bool = false          # escort/convoy hull; destroyed = mission fail
@export var objective_armed: bool = false       # false = unarmed, true = rear turret only
