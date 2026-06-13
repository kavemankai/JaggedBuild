class_name Weapon
extends Resource

enum Type { CANNONS, BURST, HEAVY, MISSILES, ION }

@export var weapon_type: Weapon.Type = Weapon.Type.CANNONS
@export var display_name: String = "Cannons"
