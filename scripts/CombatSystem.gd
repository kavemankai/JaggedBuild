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

const CAPITAL_TURRET_DAMAGE: int = 2
const CAPITAL_TURRET_HULL: int = 3
const CAPITAL_TURRET_COOLDOWN: int = 2

const FORMATION_RANGE: float = 190.0

const ION_THRESHOLD_SHIELDS: int = 2
const ION_THRESHOLD_SYSTEM1: int = 4
const ION_THRESHOLD_SYSTEM2: int = 6
# Systems eligible for the >=4 / >=6 random disable. Shields are already handled
# by the >=2 threshold via Ship.shields_disrupted().
const ION_DISABLE_POOL: Array = ["ENGINES", "WEAPONS", "SENSORS"]
const ION_DISABLE_MIN_ROUNDS: int = 1
const ION_DISABLE_MAX_ROUNDS: int = 2

const MARKSMAN_BONUS: float = 0.08
const EVASIVE_BONUS: float = 0.08
const OVERCHARGE_ATK: int = 2
const MISSILES_DAMAGE: int = 4
const TORPEDOES_DAMAGE: int = 5
const TORPEDOES_AMMO: int = 1
const CRIT_CHANCE_BASE: float = 0.35

# Weapon-typed crit tables. TORPEDOES draws from ALL_CRITS.
const CRITS_CANNONS:  Array = ["DIRECT_HIT", "HULL_BREACH"]
const CRITS_BURST:    Array = ["RATTLED", "CONSOLE_FIRE"]
const CRITS_HEAVY:    Array = ["HULL_BREACH", "STRUCTURAL_DAMAGE", "DIRECT_HIT"]
const CRITS_ION:      Array = ["SENSORS_FRIED", "POWER_REGULATOR"]
const CRITS_TURRET:   Array = ["WEAPONS_FAILURE", "DAMAGED_ENGINE"]
const CRITS_MISSILES: Array = ["DIRECT_HIT", "FUEL_LEAK"]
const ALL_CRITS:      Array = ["DIRECT_HIT", "HULL_BREACH", "RATTLED", "CONSOLE_FIRE",
                               "STRUCTURAL_DAMAGE", "SENSORS_FRIED", "POWER_REGULATOR",
                               "WEAPONS_FAILURE", "DAMAGED_ENGINE", "FUEL_LEAK"]


func calculate_hit_chance(attacker: Ship, defender: Ship, atk_override: int = -1, ignore_def: int = 0) -> float:
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

	# Targeting Computer: +1 atk die at close range
	if attacker.upgrade == "Targeting Computer" and dist < ManeuverSystem.RANGE_CLOSE:
		eff_atk += 1

	# Rear arc
	if ManeuverSystem.is_in_rear_arc(attacker, defender):
		eff_def = max(0, eff_def - 1)

	# Formation grants +1 effective defence die (mutual defensive coverage).
	if defender.in_formation:
		eff_def += 1

	# Missiles ignore 1 effective defence die.
	eff_def = max(0, eff_def - ignore_def)

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

	# Passive perks
	if attacker.get_passive() == "MARKSMAN":
		final_chance += MARKSMAN_BONUS
	if defender.get_passive() == "EVASIVE":
		final_chance -= EVASIVE_BONUS

	return clampf(final_chance, HIT_CHANCE_MIN, HIT_CHANCE_MAX)


func resolve_shot(hit_chance: float) -> bool:
	return randf() < hit_chance


func apply_damage(ship: Ship, amount: int, bypass_shields: bool = false) -> void:
	# Disrupted shields (ion >= 2) cannot absorb; capital-grade weapons bypass outright.
	if ship.shields > 0 and not bypass_shields and not ship.shields_disrupted():
		ship.shields -= amount
		ship.flash_shield()
	else:
		ship.hull -= amount
		ship.flash_hull()
	if ship.hull <= 0:
		ship.is_destroyed = true
		ship.destroy_ship()


# Returns Array of {chance, damage, ion, bypass, hit, crit_guaranteed, weapon_type} dicts.
func _build_shots(attacker: Ship, defender: Ship, in_arc: bool) -> Array:
	if not in_arc:
		return []
	# Primary weapon disabled by ion (sensors handled separately — no lock, hidden UI).
	if attacker.weapons_disabled():
		return []
	var w: Weapon = attacker.weapon as Weapon
	var wtype: Weapon.Type = w.weapon_type if w != null else Weapon.Type.CANNONS
	var oc: int = OVERCHARGE_ATK if attacker.overcharged else 0
	match wtype:
		Weapon.Type.BURST:
			var burst_atk: int = maxi(1, floori(float(attacker.attack) * BURST_ATK_RATIO)) + oc
			var chance: float = calculate_hit_chance(attacker, defender, burst_atk)
			return [
				{"chance": chance, "damage": 1, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype},
				{"chance": chance, "damage": 1, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype},
			]
		Weapon.Type.HEAVY:
			if attacker.heavy_cooldown > 0:
				return []
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": HEAVY_DAMAGE, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype}]
		Weapon.Type.ION:
			# Ion weapons deal no hull/shield damage — only ion track. No crits.
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": 0, "ion": 1, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype}]
		Weapon.Type.MISSILES:
			if attacker.target_lock != defender or attacker.missiles_ammo <= 0:
				return []
			attacker.missiles_ammo -= 1
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc, 1), "damage": MISSILES_DAMAGE, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype}]
		Weapon.Type.TORPEDOES:
			# One-shot: requires target lock, 5 dmg, guarantees crit if target shields=0.
			if attacker.target_lock != defender or attacker.torpedoes_ammo <= 0:
				return []
			attacker.torpedoes_ammo -= 1
			var crit_g: bool = defender.shields <= 0
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc, 1), "damage": TORPEDOES_DAMAGE, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": crit_g, "weapon_type": wtype}]
		Weapon.Type.TURRET:
			# Capital-grade emplacement: bypasses shields, cooldown between shots.
			if attacker.heavy_cooldown > 0:
				return []
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack), "damage": CAPITAL_TURRET_DAMAGE, "ion": 0, "bypass": true, "hit": false, "crit_guaranteed": false, "weapon_type": wtype}]
		_:  # CANNONS default
			return [{"chance": calculate_hit_chance(attacker, defender, attacker.attack + oc), "damage": 1, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": wtype}]


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


# Formation requires both ships unstressed (mutual coverage breaks down under stress).
func _has_nearby_ally(ship: Ship, ships: Array) -> bool:
	if ship.stress > 0:
		return false
	for s in ships:
		var t: Ship = s as Ship
		if t == ship or t.is_destroyed or t.team != ship.team or t.stress > 0:
			continue
		if ship.global_position.distance_to(t.global_position) <= FORMATION_RANGE:
			return true
	return false


func pick_target(shooter: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for s in ships:
		var t: Ship = s as Ship
		if t == shooter or t.is_destroyed or t.team == shooter.team or not t.is_targetable:
			continue
		if not ManeuverSystem.is_in_firing_arc(shooter, t):
			continue
		var d: float = shooter.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


# Nearest enemy inside the shooter's REAR turret arc.
func pick_rear_target(shooter: Ship, ships: Array) -> Ship:
	var best: Ship = null
	var best_dist: float = INF
	for s in ships:
		var t: Ship = s as Ship
		if t == shooter or t.is_destroyed or t.team == shooter.team or not t.is_targetable:
			continue
		if not ManeuverSystem.is_in_rear_firing_arc(shooter, t):
			continue
		var d: float = shooter.global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	return best


# Formation chain-fire shot: a coordinated follow-up cannon burst (1 dmg, no ammo or
# cooldown side-effects) so a wing's primary weapon isn't double-spent. Free attack.
func _build_chain_shot(wing: Ship, target: Ship) -> Array:
	if wing.weapons_disabled():
		return []
	return [{"chance": calculate_hit_chance(wing, target, wing.attack), "damage": 1, "ion": 0, "bypass": false, "hit": false, "crit_guaranteed": false, "weapon_type": Weapon.Type.CANNONS}]


# Rear turret shot: fixed TURRET (2 dmg, shield-bypass), on its own cooldown.
func _build_rear_shots(attacker: Ship, target: Ship) -> Array:
	if target == null or attacker.rear_cooldown > 0 or attacker.weapons_disabled():
		return []
	return [{"chance": calculate_hit_chance(attacker, target, attacker.attack), "damage": CAPITAL_TURRET_DAMAGE, "ion": 0, "bypass": true, "hit": false}]


func _crit_table_for(wtype: int) -> Array:
	match wtype:
		Weapon.Type.BURST:    return CRITS_BURST
		Weapon.Type.HEAVY:    return CRITS_HEAVY
		Weapon.Type.ION:      return CRITS_ION
		Weapon.Type.TURRET:   return CRITS_TURRET
		Weapon.Type.MISSILES: return CRITS_MISSILES
		Weapon.Type.TORPEDOES: return ALL_CRITS
		_:                    return CRITS_CANNONS


# Draw a crit from the weapon's table and apply it to the target.
func _apply_crit(target: Ship, wtype: int, guaranteed: bool, hit_hull: bool) -> void:
	# Shields insulate against crits — only land on hull hits.
	if not hit_hull and not guaranteed:
		return
	if not guaranteed and randf() >= CRIT_CHANCE_BASE:
		return
	var table: Array = _crit_table_for(wtype)
	var crit_id: String = table[randi() % table.size()]
	target.add_crit(crit_id)
	# Immediate effects applied now; persistent effects tick in EVALUATION.
	match crit_id:
		"DIRECT_HIT":
			target.hull -= 1
			target.flash_hull()
			if target.hull <= 0:
				target.is_destroyed = true
				target.destroy_ship()
		"STRUCTURAL_DAMAGE":
			target.attack = maxi(0, target.attack - 1)


func run_combat(ships: Array) -> void:
	var alive: Array = ships.filter(func(s: Ship): return not s.is_destroyed)
	if alive.size() < 2:
		return

	# Tick weapon cooldowns and recompute formation state
	for s in alive:
		var sh: Ship = s as Ship
		if sh.heavy_cooldown > 0:
			sh.heavy_cooldown -= 1
		if sh.rear_cooldown > 0:
			sh.rear_cooldown -= 1
		sh.in_formation = _has_nearby_ally(sh, ships)

	# Each shooter picks a target and builds its shots
	var engagements: Array = []  # { shooter, target, shots, used_lock }
	for s in alive:
		var shooter: Ship = s as Ship
		# The capital hull itself is scenery — it does not fire.
		if not shooter.is_targetable:
			continue

		var target: Ship = pick_target(shooter, ships)
		var in_arc: bool = target != null
		var shots: Array = _build_shots(shooter, target, in_arc) if in_arc else []
		engagements.append({
			"shooter": shooter,
			"target": target,
			"shots": shots,
			"used_lock": in_arc and shooter.target_lock == target,
		})
		# Sensors disabled by ion: firing arc/hit chance hidden from the player.
		if shooter.sensors_disabled():
			shooter.show_combat_ui(in_arc, 0.0, "SENSORS DOWN")
		else:
			shooter.show_combat_ui(in_arc, _display_chance(shots), _combat_status(shooter, in_arc, shots))

		# Large ships fire a fixed rear turret at a separate target behind them — a
		# second engagement in the same phase (the simultaneous pipeline handles N shots).
		if shooter.has_rear_turret:
			var rear_target: Ship = pick_rear_target(shooter, ships)
			var rear_shots: Array = _build_rear_shots(shooter, rear_target) if rear_target != null else []
			if not rear_shots.is_empty():
				engagements.append({
					"shooter": shooter,
					"target": rear_target,
					"shots": rear_shots,
					"used_lock": false,
					"is_rear": true,
				})
			shooter.show_rear_arc(rear_target != null)

	await get_tree().create_timer(1.2).timeout

	# Resolve all shots — store results before applying any damage
	for e in engagements:
		for shot in e.shots:
			shot.hit = resolve_shot(shot.chance)

	# Formation CHAIN FIRE: if a lead's forward shot HIT, each wing in arc of the SAME
	# target gets a free follow-up. Resolved here (after pass 1, before damage) so the
	# whole volley still applies simultaneously.
	var chain: Array = []
	for e in engagements:
		if e.get("is_rear", false) or e.get("is_chain", false) or e.target == null:
			continue
		var lead: Ship = e.shooter
		if lead.formation_role != "LEAD" or lead.formation == null:
			continue
		var lead_hit: bool = false
		for shot in e.shots:
			if shot.hit:
				lead_hit = true
		if not lead_hit:
			continue
		for w in lead.formation.wings:
			var wing: Ship = w as Ship
			if wing == null or wing.is_destroyed or not wing.is_targetable:
				continue
			if not ManeuverSystem.is_in_firing_arc(wing, e.target):
				continue
			var cshots: Array = _build_chain_shot(wing, e.target)
			for shot in cshots:
				shot.hit = resolve_shot(shot.chance)
			if not cshots.is_empty():
				chain.append({"shooter": wing, "target": e.target, "shots": cshots, "used_lock": false, "is_chain": true})
	for ce in chain:
		engagements.append(ce)

	# Draw shots simultaneously (projectile sprites via EffectSystem)
	for e in engagements:
		if e.target == null:
			continue
		for shot in e.shots:
			var is_missile: bool = int(shot.get("weapon_type", Weapon.Type.CANNONS)) in [Weapon.Type.MISSILES, Weapon.Type.TORPEDOES]
			EffectSystem.spawn_projectile(e.shooter.global_position, e.target.global_position, shot.hit, is_missile)

	await get_tree().create_timer(SHOT_ANIM_DURATION + 0.1).timeout

	# Apply all damage simultaneously
	for e in engagements:
		if e.target == null:
			continue
		for shot in e.shots:
			if shot.hit:
				var was_alive: bool = not e.target.is_destroyed
				var shields_before: int = e.target.shields
				var shields_was_disrupted: bool = e.target.shields_disrupted()
				var bypassing: bool = shot.get("bypass", false)
				if shot.damage > 0:
					apply_damage(e.target, shot.damage, bypassing)
				if shot.ion > 0:
					e.target.ion_tokens += shot.ion
				if shot.damage > 0 and not bypassing:
					var hit_hull: bool = shields_before <= 0 or e.target.shields_disrupted()
					_apply_crit(e.target, int(shot.get("weapon_type", Weapon.Type.CANNONS)), shot.get("crit_guaranteed", false), hit_hull)
				if was_alive and e.target.is_destroyed:
					e.shooter.kills += 1
					EffectSystem.spawn_explosion(e.target.global_position)
				elif shot.damage > 0:
					if shields_before > 0 and not shields_was_disrupted and not bypassing:
						EffectSystem.spawn_shield_hit(e.target.global_position)
					else:
						EffectSystem.spawn_hull_hit(e.target.global_position)

	# Set cooldown for weapons that just fired. The rear turret has its OWN cooldown so a
	# Hauler's forward Heavy and rear turret don't share/clobber one timer.
	for e in engagements:
		if e.shots.is_empty():
			continue
		if e.get("is_chain", false):
			continue   # free follow-up — no weapon cooldown
		if e.get("is_rear", false):
			e.shooter.rear_cooldown = CAPITAL_TURRET_COOLDOWN
			continue
		var w: Weapon = e.shooter.weapon as Weapon
		if w == null:
			continue
		if w.weapon_type == Weapon.Type.HEAVY:
			e.shooter.heavy_cooldown = HEAVY_COOLDOWN_TURNS
		elif w.weapon_type == Weapon.Type.TURRET:
			e.shooter.heavy_cooldown = CAPITAL_TURRET_COOLDOWN

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


