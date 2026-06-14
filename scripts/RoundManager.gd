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

	# Resolve by pilot skill ascending. Ties keep registration order (friendly ships
	# are registered first, in the player's chosen order), so the sort must be stable —
	# decorate with the original index and use it as the tiebreaker.
	var decorated: Array = []
	for i in range(ships.size()):
		decorated.append({"ship": ships[i], "skill": (ships[i] as Ship).get_skill(), "idx": i})
	decorated.sort_custom(func(a, b):
		if a.skill == b.skill:
			return a.idx < b.idx
		return a.skill < b.skill)
	var resolution_order: Array = []
	for entry in decorated:
		resolution_order.append(entry.ship)

	for ship in resolution_order:
		if ship.is_destroyed:
			continue
		var bearing: String = ship.selected_maneuver.bearing if ship.selected_maneuver else ""
		var speed: int = ship.selected_maneuver.speed if ship.selected_maneuver else 0
		await ship.execute_maneuver()
		var s: Ship = ship as Ship
		var move_color: String = s.get_maneuver_color(bearing, speed)
		if move_color == "RED":
			if randf() >= s.get_nerve():
				if s.upgrade == "Veteran Reflexes" and not s.veteran_stress_blocked:
					s.veteran_stress_blocked = true
				else:
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
		var s0: Ship = ship as Ship
		if s0.is_targetable and ManeuverSystem.is_out_of_bounds(s0.global_position):
			s0.is_destroyed = true

	await get_tree().create_timer(0.3).timeout

	# Ion: tick disabled-system durations, then (re)apply threshold disables.
	# Ion tokens persist for the whole engagement (reset on mission end via reload).
	for ship in ships:
		_process_ion(ship as Ship)

	var player_alive: bool = is_team_alive("PLAYER")
	var enemy_alive: bool = is_team_alive("ENEMY")

	if not player_alive and not enemy_alive:
		_end_game("MUTUAL DESTRUCTION", Color.WHITE)
	elif not player_alive:
		_end_game("SQUADRON LOST", Color(1.0, 0.2, 0.2, 1.0))
	elif not enemy_alive:
		_end_game("ENEMIES DESTROYED", Color(0.2, 1.0, 0.2, 1.0))
	else:
		begin_round()


func _process_ion(s: Ship) -> void:
	if s.is_capital:
		return
	# Count down active disables, clearing expired ones.
	for key in s.disabled_systems.keys():
		s.disabled_systems[key] = int(s.disabled_systems[key]) - 1
		if int(s.disabled_systems[key]) <= 0:
			s.disabled_systems.erase(key)

	var want: int = 0
	if s.ion_tokens >= CombatSystem.ION_THRESHOLD_SYSTEM2:
		want = 2
	elif s.ion_tokens >= CombatSystem.ION_THRESHOLD_SYSTEM1:
		want = 1

	var active: int = 0
	for key in s.disabled_systems.keys():
		if key in CombatSystem.ION_DISABLE_POOL:
			active += 1

	while active < want:
		var avail: Array = []
		for sys_name in CombatSystem.ION_DISABLE_POOL:
			if not s.disabled_systems.has(sys_name):
				avail.append(sys_name)
		if avail.is_empty():
			break
		var pick: String = avail[randi() % avail.size()]
		s.disabled_systems[pick] = randi_range(
			CombatSystem.ION_DISABLE_MIN_ROUNDS, CombatSystem.ION_DISABLE_MAX_ROUNDS)
		active += 1


# Only targetable ships count toward a team's survival (capital hulls are scenery).
func is_team_alive(team_name: String) -> bool:
	for ship in ships:
		var s: Ship = ship as Ship
		if s.team == team_name and s.is_targetable and not s.is_destroyed:
			return true
	return false


func _end_game(message: String, color: Color) -> void:
	current_phase = Phase.EVALUATION
	game_ended.emit(message, color)
