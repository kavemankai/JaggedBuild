extends RefCounted

# Player formation: 1 Lead + up to 2 Wings. The lead picks a maneuver; wings mirror
# its bearing + speed (clamped to each wing's own dial). No class_name — consumers
# preload it (avoids the class-registry reload race), same pattern as Objective.gd.

const MAX_WINGS: int = 2

var lead: Ship = null
var wings: Array = []        # Array[Ship], up to MAX_WINGS


func members() -> Array:
	var out: Array = [lead]
	for w in wings:
		out.append(w)
	return out


func has(ship: Ship) -> bool:
	return ship == lead or ship in wings


# Valid while the lead and at least one wing are alive and the wings stay within
# lock range of the lead. A lone lead (all wings lost/strayed) dissolves.
func is_valid() -> bool:
	if lead == null or lead.is_destroyed or lead.escaped:
		return false
	var live_wings: int = 0
	for w in wings:
		var wing: Ship = w as Ship
		if wing == null or wing.is_destroyed or wing.escaped:
			continue
		if lead.global_position.distance_to(wing.global_position) > CombatSystem.FORMATION_RANGE:
			continue
		live_wings += 1
	return live_wings > 0
