class_name AIStatcard
extends Resource

# HOTAC-derived statcard for one enemy ship type.
# Step 1: target_priority — list of rules, first valid wins.
#   "nearest_enemy", "locked_target", "lowest_hull", "objective"
@export var target_priority: Array[String] = ["nearest_enemy"]

# Step 2: maneuver_table[range_band][bearing_zone] = Array[String] of bearings.
# Range bands: "CLOSE" (<167), "MEDIUM" (167-333), "LONG" (333-500), "OUT" (>500)
# Bearing zones: "BULLSEYE", "FRONT", "FRONT_SIDE", "REAR_SIDE", "REAR"
@export var maneuver_table: Dictionary = {}

# Step 2b: stressed variant (avoids RED maneuvers).
@export var stress_maneuver_table: Dictionary = {}

# Step 3: action_priority — ordered list; first condition-met wins.
#   "TARGET_LOCK", "FOCUS", "EVADE", "BARREL_ROLL", "OVERCHARGE"
@export var action_priority: Array[String] = ["TARGET_LOCK", "FOCUS"]

# Step 4: alternate target mode.
# "ATTACK" (default), "STRIKE" (pursue objective), "FLEE" (nearest edge), "ESCORT"
@export var target_mode: String = "ATTACK"

# Flee destination edge (used when target_mode == "FLEE").
@export var flee_edge: String = "top"

# Which ship class dial this statcard uses (for maneuver validation).
@export var ship_class_id: String = "enemy_fighter"
