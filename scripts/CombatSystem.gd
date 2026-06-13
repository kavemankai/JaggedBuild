extends Node

const Weapon := preload("res://scripts/Weapon.gd")

const SKILL_MOD_PER_POINT: float = 0.05
const SKILL_MOD_CAP: float = 0.20

const BASE_HIT_CHANCE: float = 0.625
const BASE_EVADE_CHANCE: float = 0.375
const SHOT_ANIM_DURATION: float = 0.15
const FOCUS_HIT_BONUS: float = 0.15
const EVADE_TOKEN_REDUCTION: float = 0.15
const FOCUS_EVADE_BONUS: float = 0.10
const HIT_CHANCE_MIN: float = 0.05
const HIT_CHANCE_MAX: float = 0.95

const BURST_ATK_RATIO: float = 0.6
const HEAVY_DAMAGE: int = 3
const HEAVY_COOLDOWN_TURNS: int = 2


func calculate_hit_chance(attacker: Ship, defender: Ship, atk_override: int = -1) -> float:
	# Base attack/defence scaled by pilot accuracy/agility
	var base_atk: int = atk_override if atk_override >= 0 else attacker.attack
	var eff_atk: int = clampi(roundi(float(base_atk) * attacker.get_accuracy()), 0, 6)
	var eff_def: int = clampi(roundi(float(defender.defence) * defender.get_agility()), 0, 6)

	# Range bands
	var dist: float = attacker.global_position.distance_to(defender.global_position)
	if dist < ManeuverSystem.RANGE_CLOSE:
		eff_atk += 1
	elif dist > ManeuverSystem.RANGE_MEDIUM:
		eff_def += 1

	# Rear arc
	if ManeuverSystem.is_in_rear_arc(attacker, defender):
		eff_def = max(0, eff_def - 1)

	eff_atk = clampi(eff_atk, 0, 6)
	eff_def = clampi(eff_def, 0, 6)

	var p_hit: float = 1.0 - pow(1.0 - BASE_HIT_CHANCE, float(eff_atk))
	var p_survive: float = pow(1.0 - BASE_EVADE_CHANCE, float(eff_def))
	var final_chance: float = p_hit * p_survive

	# Pilot skill delta modifier
	var skill_delta: int = attacker.get_skill() - defender.get_skill()
	var skill_mod: float = clampf(float(skill_delta) * SKILL_MOD_PER_POINT, -SKILL_MOD_CAP, SKILL_MOD_CAP)
	final_chance += skill_mod

	# Token modifiers
	if attacker.focus_token:
		final_chance += FOCUS_HIT_BONUS
	if attacker.target_lock == defender:
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


# Returns Array of {chance, damage, hit} dicts. hit is false until resolved.
func _build_shots(attacker: Ship, defender: Ship, in_arc: bool) -> Array:
	if not in_arc:
		return []
	var w: Weapon = attacker.weapon as Weapon
	var wtype: Weapon.Type = w.weapon_type if w != null else Weapon.Type.CANNONS
	match wtype:
		Weapon.Type.BURST:
			var burst_atk: int = maxi(1, floori(float(attacker.attack) * BURST_ATK_RATIO))
			var chance: float = calculate_hit_chance(attacker, defender, burst_atk)
			return [
				{"chance": chance, "damage": 1, "hit": false},
				{"chance": chance, "damage": 1, "hit": false},
			]
		Weapon.Type.HEAVY:
			if attacker.heavy_cooldown > 0:
				return []
			return [{"chance": calculate_hit_chance(attacker, defender), "damage": HEAVY_DAMAGE, "hit": false}]
		_:  # CANNONS default
			return [{"chance": calculate_hit_chance(attacker, defender), "damage": 1, "hit": false}]


func _display_chance(shots: Array) -> float:
	if shots.is_empty():
		return 0.0
	var p: float = shots[0].chance
	if shots.size() == 1:
		return p
	# P(at least 1 hit across n shots)
	return 1.0 - pow(1.0 - p, float(shots.size()))


func _combat_status(ship: Ship, in_arc: bool, shots: Array) -> String:
	if not in_arc or not shots.is_empty():
		return ""
	return "RELOADING [%d]" % ship.heavy_cooldown


func run_combat(ships: Array) -> void:
	var alive: Array = ships.filter(func(s: Ship): return not s.is_destroyed)
	if alive.size() < 2:
		return

	var ship_a: Ship = alive[0]
	var ship_b: Ship = alive[1]

	# Tick heavy weapon cooldowns
	if ship_a.heavy_cooldown > 0:
		ship_a.heavy_cooldown -= 1
	if ship_b.heavy_cooldown > 0:
		ship_b.heavy_cooldown -= 1

	var a_in_arc: bool = ManeuverSystem.is_in_firing_arc(ship_a, ship_b)
	var b_in_arc: bool = ManeuverSystem.is_in_firing_arc(ship_b, ship_a)
	var a_used_lock: bool = a_in_arc and ship_a.target_lock == ship_b
	var b_used_lock: bool = b_in_arc and ship_b.target_lock == ship_a

	var a_shots: Array = _build_shots(ship_a, ship_b, a_in_arc)
	var b_shots: Array = _build_shots(ship_b, ship_a, b_in_arc)

	ship_a.show_combat_ui(a_in_arc, _display_chance(a_shots), _combat_status(ship_a, a_in_arc, a_shots))
	ship_b.show_combat_ui(b_in_arc, _display_chance(b_shots), _combat_status(ship_b, b_in_arc, b_shots))

	await get_tree().create_timer(1.2).timeout

	# Resolve all shots — store results before applying any
	for shot in a_shots:
		shot.hit = resolve_shot(shot.chance)
	for shot in b_shots:
		shot.hit = resolve_shot(shot.chance)

	# Draw shots simultaneously
	for shot in a_shots:
		_draw_shot(ship_a.global_position, ship_b.global_position, ship_a.accent_color, shot.hit)
	for shot in b_shots:
		_draw_shot(ship_b.global_position, ship_a.global_position, ship_b.accent_color, shot.hit)

	await get_tree().create_timer(SHOT_ANIM_DURATION + 0.1).timeout

	# Apply all damage simultaneously
	for shot in a_shots:
		if shot.hit:
			apply_damage(ship_b, shot.damage)
	for shot in b_shots:
		if shot.hit:
			apply_damage(ship_a, shot.damage)

	# Set heavy cooldown for weapons that just fired
	var wa: Weapon = ship_a.weapon as Weapon
	var wb: Weapon = ship_b.weapon as Weapon
	if not a_shots.is_empty() and wa != null and wa.weapon_type == Weapon.Type.HEAVY:
		ship_a.heavy_cooldown = HEAVY_COOLDOWN_TURNS
	if not b_shots.is_empty() and wb != null and wb.weapon_type == Weapon.Type.HEAVY:
		ship_b.heavy_cooldown = HEAVY_COOLDOWN_TURNS

	ship_a.hide_combat_ui()
	ship_b.hide_combat_ui()

	await get_tree().create_timer(0.4).timeout

	# Consume per-round tokens
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
