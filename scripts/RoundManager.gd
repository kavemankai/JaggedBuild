extends Node

enum Phase { PLANNING, RESOLUTION, ACTION, COMBAT, EVALUATION }

signal planning_phase_started
signal resolution_phase_started
signal action_phase_started
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
	resolution_order.sort_custom(func(a, b): return (a as Ship).get_skill() < (b as Ship).get_skill())

	for ship in resolution_order:
		if ship.is_destroyed:
			continue
		var bearing: String = ship.selected_maneuver.bearing if ship.selected_maneuver else ""
		await ship.execute_maneuver()
		var s: Ship = ship as Ship
		var move_color: String = s.get_maneuver_color(bearing)
		if move_color == "RED":
			if randf() >= s.get_nerve():
				s.stress += 1
				s.pulse_stress()
		elif move_color == "GREEN" and s.stress > 0:
			s.stress -= 1
		for other in ships:
			if other == ship or other.is_destroyed:
				continue
			if CollisionHandler.ships_overlap(ship, other):
				CollisionHandler.resolve_bump(ship, other)

	_run_actions()


func _run_actions() -> void:
	current_phase = Phase.ACTION
	action_phase_started.emit()
	await ActionSystem.execute_actions(ships)
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

	for ship in ships:
		var s: Ship = ship as Ship
		if s.ion_tokens > 0:
			s.ion_tokens -= 1

	var player_alive: bool = _team_alive("PLAYER")
	var enemy_alive: bool = _team_alive("ENEMY")

	if not player_alive and not enemy_alive:
		_end_game("MUTUAL DESTRUCTION", Color.WHITE)
	elif not player_alive:
		_end_game("SQUADRON LOST", Color(1.0, 0.2, 0.2, 1.0))
	elif not enemy_alive:
		_end_game("ENEMIES DESTROYED", Color(0.2, 1.0, 0.2, 1.0))
	else:
		begin_round()


func _team_alive(team_name: String) -> bool:
	for ship in ships:
		var s: Ship = ship as Ship
		if s.team == team_name and not s.is_destroyed:
			return true
	return false


func _end_game(message: String, color: Color) -> void:
	current_phase = Phase.EVALUATION
	game_ended.emit(message, color)
