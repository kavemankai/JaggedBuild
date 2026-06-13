extends Node

const BASE_HIT_CHANCE: float = 0.625
const BASE_EVADE_CHANCE: float = 0.375
const HIT_DAMAGE: int = 1
const SHOT_ANIM_DURATION: float = 0.15
const FOCUS_HIT_BONUS: float = 0.15
const EVADE_TOKEN_REDUCTION: float = 0.15
const FOCUS_EVADE_BONUS: float = 0.10
const HIT_CHANCE_MIN: float = 0.05
const HIT_CHANCE_MAX: float = 0.95


func calculate_hit_chance(attacker: Ship, defender: Ship) -> float:
	var eff_atk: int = attacker.attack
	var eff_def: int = defender.defence

	var dist: float = attacker.global_position.distance_to(defender.global_position)
	if dist < ManeuverSystem.RANGE_CLOSE:
		eff_atk += 1
	elif dist > ManeuverSystem.RANGE_MEDIUM:
		eff_def += 1

	if ManeuverSystem.is_in_rear_arc(attacker, defender):
		eff_def = max(0, eff_def - 1)

	eff_atk = clampi(eff_atk, 0, 6)
	eff_def = clampi(eff_def, 0, 6)

	var p_hit: float = 1.0 - pow(1.0 - BASE_HIT_CHANCE, float(eff_atk))
	var p_survive: float = pow(1.0 - BASE_EVADE_CHANCE, float(eff_def))
	var final_chance: float = p_hit * p_survive

	if attacker.focus_token:
		final_chance += FOCUS_HIT_BONUS
	if attacker.target_lock == defender:
		# Reroll on miss: 1 - (1-p)^2
		final_chance = 1.0 - pow(1.0 - final_chance, 2.0)
	if defender.evade_token:
		final_chance -= EVADE_TOKEN_REDUCTION
	if defender.focus_token:
		final_chance -= FOCUS_EVADE_BONUS

	return clampf(final_chance, HIT_CHANCE_MIN, HIT_CHANCE_MAX)


func resolve_shot(hit_chance: float) -> bool:
	return randf() < hit_chance


func apply_damage(ship: Ship, amount: int) -> void:
	if ship.shields > 0:
		ship.shields -= amount
		ship.flash_shield()
	else:
		ship.hull -= amount
		ship.flash_hull()
	if ship.hull <= 0:
		ship.is_destroyed = true
		ship.destroy_ship()


func run_combat(ships: Array) -> void:
	var alive: Array = ships.filter(func(s: Ship): return not s.is_destroyed)
	if alive.size() < 2:
		return

	var ship_a: Ship = alive[0]
	var ship_b: Ship = alive[1]

	var a_in_arc := ManeuverSystem.is_in_firing_arc(ship_a, ship_b)
	var b_in_arc := ManeuverSystem.is_in_firing_arc(ship_b, ship_a)
	var a_chance := calculate_hit_chance(ship_a, ship_b) if a_in_arc else 0.0
	var b_chance := calculate_hit_chance(ship_b, ship_a) if b_in_arc else 0.0
	var a_used_lock: bool = a_in_arc and ship_a.target_lock == ship_b
	var b_used_lock: bool = b_in_arc and ship_b.target_lock == ship_a

	ship_a.show_combat_ui(a_in_arc, a_chance)
	ship_b.show_combat_ui(b_in_arc, b_chance)

	await get_tree().create_timer(1.2).timeout

	# Store both results before applying either
	var a_hits := resolve_shot(a_chance) if a_in_arc else false
	var b_hits := resolve_shot(b_chance) if b_in_arc else false

	# Draw shots simultaneously (fire and forget coroutines)
	if a_in_arc:
		_draw_shot(ship_a.global_position, ship_b.global_position, ship_a.accent_color, a_hits)
	if b_in_arc:
		_draw_shot(ship_b.global_position, ship_a.global_position, ship_b.accent_color, b_hits)

	await get_tree().create_timer(SHOT_ANIM_DURATION + 0.1).timeout

	# Apply both simultaneously
	if a_hits:
		apply_damage(ship_b, HIT_DAMAGE)
	if b_hits:
		apply_damage(ship_a, HIT_DAMAGE)

	ship_a.hide_combat_ui()
	ship_b.hide_combat_ui()

	await get_tree().create_timer(0.4).timeout

	# Consume per-round tokens; target lock consumed only if spent this combat
	ship_a.focus_token = false
	ship_b.focus_token = false
	ship_a.evade_token = false
	ship_b.evade_token = false
	if a_used_lock:
		ship_a.target_lock = null
	if b_used_lock:
		ship_b.target_lock = null
	if ship_a.target_lock != null and ship_a.target_lock.is_destroyed:
		ship_a.target_lock = null
	if ship_b.target_lock != null and ship_b.target_lock.is_destroyed:
		ship_b.target_lock = null


func _draw_shot(from: Vector2, to: Vector2, color: Color, is_hit: bool) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(color.r, color.g, color.b, 0.9)
	line.add_point(from)
	line.add_point(to if is_hit else from.lerp(to, 0.45))
	get_tree().current_scene.add_child(line)
	await get_tree().create_timer(SHOT_ANIM_DURATION).timeout
	line.queue_free()
