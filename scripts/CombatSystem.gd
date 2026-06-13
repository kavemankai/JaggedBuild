extends Node

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

const FORMATION_RANGE: float = 190.0
const FORMATION_DEF_BONUS: float = 0.12

const MARKSMAN_BONUS: float = 0.08
const EVASIVE_BONUS: float = 0.08
const OVERCHARGE_ATK: int = 2


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
	if defender.in_formation:
		final_chance -= FORMATION_DEF_BONUS

	# Passive perks
	if attacker.get_passive() == "MARKSMAN":
		final_chance += MARKSMAN_BONUS
	if defender.get_passive() == "EVASIVE":
		final_chance -= EVASIVE_BONUS

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
	var oc: int = OVERCHARGE_ATK if attacker.overcharged else 0
	match wtype:
		Weapon.Type.BURST:
			var burst_atk: int = maxi(1, floori(float(attacker.attack) * BURST_ATK_RATIO)) + oc
			var chance: float = calculate_hit_chance(attacker, defender, burst_atk)
			return [
				{"chance": chance, "damage": 1, "ion": 0, "hit": false},
				{"chance": chance, "damage": 1, "ion": 0, "hit": false},
			]
		Weapon.Type.HEAVY:
			if attacker.heavy_cooldown > 0:
				return []
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": HEAVY_DAMAGE, "ion": 0, "hit": false}]
		Weapon.Type.ION:
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": 1, "ion": 1, "hit": false}]
		_:  # CANNONS default
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": 1, "ion": 0, "hit": false}]


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


func _has_nearby_ally(ship: Ship, ships: Array) -> bool:
	for s in ships:
		var t: Ship = s as Ship
		if t == ship or t.is_destroyed or t.team != ship.team:
			continue
		if ship.global_position.distance_to(t.global_position) <= FORMATION_RANGE:
			return true
	return false


func pick_target(shooter: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for s in ships:
		var t: Ship = s as Ship
		if t == shooter or t.is_destroyed or t.team == shooter.team:
			continue
		if not ManeuverSystem.is_in_firing_arc(shooter, t):
			continue
		var d: float = shooter.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


func run_combat(ships: Array) -> void:
	var alive: Array = ships.filter(func(s: Ship): return not s.is_destroyed)
	if alive.size() < 2:
		return

	# Tick heavy weapon cooldowns and recompute formation state
	for s in alive:
		var sh: Ship = s as Ship
		if sh.heavy_cooldown > 0:
			sh.heavy_cooldown -= 1
		sh.in_formation = _has_nearby_ally(sh, ships)

	# Each shooter picks a target and builds its shots
	var engagements: Array = []  # { shooter, target, shots, used_lock }
	for s in alive:
		var shooter: Ship = s as Ship
		var target: Ship = pick_target(shooter, ships)
		var in_arc: bool = target != null
		var shots: Array = _build_shots(shooter, target, in_arc) if in_arc else []
		engagements.append({
			"shooter": shooter,
			"target": target,
			"shots": shots,
			"used_lock": in_arc and shooter.target_lock == target,
		})
		shooter.show_combat_ui(in_arc, _display_chance(shots), _combat_status(shooter, in_arc, shots))

	await get_tree().create_timer(1.2).timeout

	# Resolve all shots — store results before applying any damage
	for e in engagements:
		for shot in e.shots:
			shot.hit = resolve_shot(shot.chance)

	# Draw shots simultaneously
	for e in engagements:
		if e.target == null:
			continue
		for shot in e.shots:
			_draw_shot(e.shooter.global_position, e.target.global_position, e.shooter.accent_color, shot.hit)

	await get_tree().create_timer(SHOT_ANIM_DURATION + 0.1).timeout

	# Apply all damage simultaneously
	for e in engagements:
		if e.target == null:
			continue
		for shot in e.shots:
			if shot.hit:
				apply_damage(e.target, shot.damage)
				if shot.ion > 0:
					e.target.ion_tokens += shot.ion

	# Set heavy cooldown for weapons that just fired
	for e in engagements:
		var w: Weapon = e.shooter.weapon as Weapon
		if not e.shots.is_empty() and w != null and w.weapon_type == Weapon.Type.HEAVY:
			e.shooter.heavy_cooldown = HEAVY_COOLDOWN_TURNS

	for s in alive:
		(s as Ship).hide_combat_ui()

	await get_tree().create_timer(0.4).timeout

	# Consume per-round tokens
	for s in alive:
		var sh: Ship = s as Ship
		sh.focus_token = false
		sh.evade_token = false
		sh.overcharged = false
	for e in engagements:
		if e.used_lock:
			e.shooter.target_lock = null
	for s in alive:
		var sh: Ship = s as Ship
		if sh.target_lock != null and sh.target_lock.is_destroyed:
			sh.target_lock = null


func _draw_shot(from: Vector2, to: Vector2, color: Color, is_hit: bool) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(color.r, color.g, color.b, 0.9)
	line.add_point(from)
	line.add_point(to if is_hit else from.lerp(to, 0.45))
	get_tree().current_scene.add_child(line)
	await get_tree().create_timer(SHOT_ANIM_DURATION).timeout
	line.queue_free()
