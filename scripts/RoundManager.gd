extends Node

enum Phase { PLANNING, RESOLUTION, COMBAT, EVALUATION }

signal planning_phase_started
signal resolution_phase_started
signal combat_phase_started
signal evaluation_phase_started
signal game_ended(message: String, color: Color)

var current_phase: Phase = Phase.PLANNING
var round_number: int = 0
var ships: Array = []


func register_ships(ship_array: Array) -> void:
	ships = ship_array


func begin_round() -> void:
	round_number += 1
	current_phase = Phase.PLANNING
	planning_phase_started.emit()


func resolve_maneuvers() -> void:
	current_phase = Phase.RESOLUTION
	resolution_phase_started.emit()

	var resolution_order: Array = ships.duplicate()
	resolution_order.sort_custom(func(a, b): return a.pilot_skill < b.pilot_skill)

	for ship in resolution_order:
		if ship.is_destroyed:
			continue
		await ship.execute_maneuver()
		for other in ships:
			if other == ship or other.is_destroyed:
				continue
			if CollisionHandler.ships_overlap(ship, other):
				CollisionHandler.resolve_bump(ship, other)

	_run_combat()


func _run_combat() -> void:
	current_phase = Phase.COMBAT
	combat_phase_started.emit()
	await CombatSystem.run_combat(ships)
	_evaluate()


func _evaluate() -> void:
	current_phase = Phase.EVALUATION
	evaluation_phase_started.emit()

	for ship in ships:
		if ManeuverSystem.is_out_of_bounds(ship.global_position):
			ship.is_destroyed = true

	await get_tree().create_timer(0.3).timeout

	var player_dead := ships.size() > 0 and ships[0].is_destroyed
	var ai_dead := ships.size() > 1 and ships[1].is_destroyed

	if player_dead and ai_dead:
		_end_game("MUTUAL DESTRUCTION", Color.WHITE)
	elif player_dead:
		_end_game("SHIP DESTROYED", Color(1.0, 0.2, 0.2, 1.0))
	elif ai_dead:
		_end_game("ENEMY DESTROYED", Color(0.2, 1.0, 0.2, 1.0))
	else:
		begin_round()


func _end_game(message: String, color: Color) -> void:
	current_phase = Phase.EVALUATION
	game_ended.emit(message, color)
