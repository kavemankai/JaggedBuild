# DemoConfig.gd
# Demo-slice-only autoload. The single channel through which the demo's three
# scenes pass the player's choices.
extends Node

# Primary weapon: CANNONS. Missiles are a secondary weapon (6 ammo, requires lock).
var player_class_id: String = "fighter"
var player_weapon: int = 0   # Weapon.Type.CANNONS
var pilot_name: String = "WARDEN"
var pilot_skill: int = 4
var missiles_ammo: int = 6


func reset() -> void:
	player_class_id = "fighter"
	player_weapon = 0
	pilot_name = "WARDEN"
	pilot_skill = 4
	missiles_ammo = 6
