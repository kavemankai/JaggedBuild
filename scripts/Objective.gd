extends RefCounted

# Reusable mission win/lose conditions. Consumers preload this script (no class_name,
# so the script never self-references during the class-registry reload race) and build
# one via Objective.new() + configure(); RoundManager evaluates it during EVALUATION.
#
# evaluate() returns one of: "WIN", "LOSE", "MUTUAL", or "" (mission ongoing).

enum Type { DESTROY_ALL, SURVIVE_ROUNDS, REACH_EDGE, PROTECT, HOLD_POSITION }

var type: int = Type.DESTROY_ALL
var rounds_required: int = 5          # SURVIVE_ROUNDS / HOLD_POSITION
var edge_y: float = 120.0             # REACH_EDGE: a player ship crossing above this y wins

# Set at runtime by Main after the protected ship spawns (PROTECT only).
var protected_ship: Ship = null


func configure(d: Dictionary) -> void:
	match d.get("type", "DESTROY_ALL"):
		"SURVIVE_ROUNDS": type = Type.SURVIVE_ROUNDS
		"REACH_EDGE":     type = Type.REACH_EDGE
		"PROTECT":        type = Type.PROTECT
		"HOLD_POSITION":  type = Type.HOLD_POSITION
		_:                type = Type.DESTROY_ALL
	rounds_required = int(d.get("rounds", 5))
	edge_y = float(d.get("edge_y", 120.0))


func evaluate(ships: Array, round_number: int) -> String:
	var player_alive: bool = _any_alive(ships, "PLAYER")
	var enemy_alive: bool = _any_alive(ships, "ENEMY")

	match type:
		Type.SURVIVE_ROUNDS, Type.HOLD_POSITION:
			if not player_alive:
				return "LOSE"
			if not enemy_alive:
				return "WIN"                 # wiped them early — also a win
			if round_number >= rounds_required:
				return "WIN"
			return ""

		Type.REACH_EDGE:
			if not _combat_player_alive(ships):
				return "LOSE"
			for s in ships:
				var sh: Ship = s as Ship
				if sh.team == "PLAYER" and sh.is_targetable and not sh.is_destroyed \
						and sh != protected_ship and sh.global_position.y <= edge_y:
					return "WIN"
			return ""

		Type.PROTECT:
			if protected_ship != null and protected_ship.is_destroyed:
				return "LOSE"
			if not _combat_player_alive(ships):
				return "LOSE"
			if not enemy_alive:
				return "WIN"
			return ""

		_:  # DESTROY_ALL
			if not player_alive and not enemy_alive:
				return "MUTUAL"
			if not player_alive:
				return "LOSE"
			if not enemy_alive:
				return "WIN"
			return ""


# Short HUD line describing the current goal and progress.
func progress_text(ships: Array, round_number: int) -> String:
	match type:
		Type.SURVIVE_ROUNDS:
			return "SURVIVE  %d / %d rounds" % [mini(round_number, rounds_required), rounds_required]
		Type.HOLD_POSITION:
			return "HOLD  %d / %d rounds" % [mini(round_number, rounds_required), rounds_required]
		Type.REACH_EDGE:
			return "REACH THE FAR EDGE"
		Type.PROTECT:
			if protected_ship != null and not protected_ship.is_destroyed:
				return "PROTECT  %s  [%d hull]" % [protected_ship.get_pilot_name(), maxi(0, protected_ship.hull)]
			return "PROTECT THE TRANSPORT"
		_:
			var n: int = 0
			for s in ships:
				var sh: Ship = s as Ship
				if sh.team == "ENEMY" and sh.is_targetable and not sh.is_destroyed:
					n += 1
			return "DESTROY ALL  (%d left)" % n


func _any_alive(ships: Array, team: String) -> bool:
	for s in ships:
		var sh: Ship = s as Ship
		if sh.team == team and sh.is_targetable and not sh.is_destroyed:
			return true
	return false


# Player combat ships only (excludes the non-controllable protected transport).
func _combat_player_alive(ships: Array) -> bool:
	for s in ships:
		var sh: Ship = s as Ship
		if sh.team == "PLAYER" and sh.is_targetable and not sh.is_destroyed and sh != protected_ship:
			return true
	return false
