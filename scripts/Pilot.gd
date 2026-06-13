class_name Pilot
extends Resource

@export var pilot_name: String = "Unknown"
@export var skill: int = 3        # 1-6, initiative order + hit modifier
@export var accuracy: float = 1.0 # multiplier on effective attack dice
@export var agility: float = 1.0  # multiplier on effective defence dice
@export var nerve: float = 0.0    # 0-1, chance to ignore stress on red maneuver
@export var xp: int = 0
@export var status: String = "healthy"  # "healthy", "injured", "dead"
