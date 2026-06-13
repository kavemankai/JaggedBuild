class_name Ship
extends Node2D

@export var pilot_skill: int = 4
@export var speed_options: Array = [1, 2, 3, 4]
@export var bearing_options: Array = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
@export var accent_color: Color = Color(0.2, 0.5, 1.0, 1.0)

var selected_maneuver: Maneuver = null
var is_destroyed: bool = false
var was_bumped: bool = false
