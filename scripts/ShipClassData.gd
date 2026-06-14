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
@export var turret_arc_degrees: float = 0.0     # 0 = no rear turret
@export var dial: DialData = null
@export var primary_weapon_options: Array = []  # Array of Weapon.Type values
@export var secondary_weapon_options: Array = []
@export var upgrade_slots: int = 1
