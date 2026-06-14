# DogfightProto — Full Game State
*Branch: `claude/new-session-77fgpr` | Godot 4.6 GDScript | Last updated: 2026-06-14*

---

## Project Overview

Turn-based space dogfight prototype. Two player ships vs. 1–4 enemy ships over a 1600×900 arena. Each round: PLANNING → RESOLUTION → ACTION → COMBAT → EVALUATION. All shots are built simultaneously before any damage is applied (non-negotiable invariant). Persistent campaign with XP, pilot injury/death, class/weapon/upgrade selection per mission.

---

## Architecture

### 6 Autoloads (registered in project.godot)

| Autoload | Script | Role |
|---|---|---|
| ManeuverSystem | `scripts/ManeuverSystem.gd` | Arena geometry, arc maths, bezier arc points |
| RoundManager | `scripts/RoundManager.gd` | Phase sequencing, stress, ion ticks |
| CollisionHandler | `scripts/CollisionHandler.gd` | Bump detection and resolution |
| CombatSystem | `scripts/CombatSystem.gd` | Hit chance, shot building, damage, formation |
| ActionSystem | `scripts/ActionSystem.gd` | Focus/Evade/Lock/Boost/Ability execution |
| CampaignManager | `scripts/CampaignManager.gd` | Roster, XP/levelling, injury, missions, skirmish |

### Round Loop

```
begin_round()
  → PLANNING (player selects maneuver + action per ship; AI plans)
  → RESOLUTION (resolve_maneuvers in skill-ascending order; stress; bumps)
  → ACTION (execute_actions — FOCUS/EVADE/LOCK/BOOST/ABILITY)
  → COMBAT (run_combat — build all shots → draw → apply all damage)
  → EVALUATION (ion tick, out-of-bounds, win/lose check)
  → begin_round() or game_ended signal
```

### Main Scene Entry Flow

```
MainMenu.tscn  →  LoadoutScreen.tscn  →  Main.tscn
                     ↑
SkirmishSetup.tscn  ─┘
```

---

## Key Files

```
scripts/
  Ship.gd              class_name Ship — live ship node
  ShipDials.gd         class_name ShipDials — static dial factory
  ShipClassData.gd     class_name ShipClassData extends Resource — class stats container
  ShipClasses.gd       class_name ShipClasses — static player class factory
  DialData.gd          class_name DialData extends Resource — bearing→speed→color dict
  Pilot.gd             class_name Pilot extends Resource — pilot stats
  Weapon.gd            class_name Weapon extends Resource — weapon type + display name
  Maneuver.gd          class_name Maneuver extends Resource — bearing + speed
  ManeuverSystem.gd    (autoload)
  RoundManager.gd      (autoload)
  CollisionHandler.gd  (autoload)
  CombatSystem.gd      (autoload)
  ActionSystem.gd      (autoload)
  CampaignManager.gd   (autoload)
  Main.gd              mission scene controller
  MainMenu.gd          title/roster/mission/skirmish screen
  LoadoutScreen.gd     class/weapon/upgrade selector
  SkirmishSetup.gd     skirmish enemy composer
  HUD.gd               health bars + round/phase display
  PlanningStrip.gd     bottom strip with ShipCard panels
  ShipCard.gd          per-ship maneuver + action panel
  ManeuverSelector.gd  overlay grid for picking bearing+speed
  AIController.gd      enemy maneuver + action selection
  GhostShip.gd         arc/position preview overlay

scenes/
  Main.tscn            Ships/PlayerShip, Ships/WingShip, Ghosts, UI/PlanningStrip, HUD, AIController
  MainMenu.tscn        loads MainMenu.gd
  LoadoutScreen.tscn   loads LoadoutScreen.gd
  SkirmishSetup.tscn   loads SkirmishSetup.gd
  Ship.tscn            Body(Sprite2D) + FiringArc(Polygon2D) + HitLabel(Label)
  GhostShip.tscn       ghost preview node

assets/ships/
  ship_ai.png          enemy ship texture
```

---

## Arena & Ranges

| Constant | Value | Notes |
|---|---|---|
| ARENA_WIDTH | 1600 px | |
| ARENA_HEIGHT | 900 px | |
| BASE_SPEED_UNIT | 80 px/speed | 1 speed = 80 px |
| MAX_RANGE | 500 px | Hard cap — no shot outside this |
| RANGE_CLOSE | 167 px | +1 eff ATK die |
| RANGE_MEDIUM | 333 px | beyond → +1 eff DEF die |
| COLLISION_RADIUS | 40 px | overlap = 80 px between centres |

---

## Ship Classes (Player)

| Class ID | Display | ATK | DEF | SHD | HULL | ARC | Dial | Weapon Options |
|---|---|---|---|---|---|---|---|---|
| `fighter` | Fighter | 2 | 2 | 2 | 3 | 90° | fighter() | Cannons, Burst, Heavy, Ion |
| `heavy_fighter` | Heavy Fighter | 3 | 1 | 3 | 4 | 70° | heavy() | Heavy, Cannons, Missiles |
| `interceptor` | Interceptor | 1 | 3 | 1 | 2 | 110° | interceptor() | Burst, Cannons, Ion |
| `gunship` | Gunship | 2 | 2 | 3 | 4 | 90° | gunship() | Cannons, Heavy, Ion |

### Enemy Classes (no loadout screen — stats from spec dict)

| Class ID | ATK | DEF | SHD | HULL | Dial |
|---|---|---|---|---|---|
| `enemy_fighter` | 2 | 2 | 2 | 3 | enemy_fighter() |
| `enemy_scout` | 1 | 3 | 1 | 2 | enemy_scout() |
| `enemy_assault` | 3 | 1 | 2 | 3 | enemy_assault() |

---

## Dial System (DialData)

Each ship has `dial_data: DialData` (or null for legacy). Dial is `Dictionary: bearing → {speed: color}`.

Colors: `"GREEN"` (removes 1 stress), `"WHITE"` (neutral), `"RED"` (may add 1 stress).

Absent keys = maneuver not on the dial at all. ManeuverSelector shows a spacer gap for absent cells.

### Player Dials Summary

| Bearing | Fighter | Heavy | Interceptor | Gunship |
|---|---|---|---|---|
| STRAIGHT | 1-3 W, 4 R | 1 G, 2-3 W | 1-4 W, 5 R | 1 G, 2-3 W |
| BANK_L/R | 1 G, 2-3 W | 1 G, 2 W, 3 R | 1 G, 2-3 W, 4 R | 1-3 W |
| TURN_L/R | 1 G, 2 W, 3 R | 1-2 W, 3 R | 1-2 W, 3 R | 1 G, 2 W (no 3) |
| K_TURN | 4 R | — | 3 R | — |

### Stress rules (RoundManager.resolve_maneuvers)
- RED maneuver: roll `randf() >= ship.get_nerve()` → stress +1 (unless Veteran Reflexes blocks first instance)
- GREEN maneuver: if stress > 0 → stress -1
- Stressed ship: RED maneuvers disabled in selector and AI; all actions except ABILITY disabled

---

## Weapons (Weapon.Type enum)

| Type | Shots | Damage | Notes |
|---|---|---|---|
| CANNONS | 1 | 1 | Default; benefits from focus/lock/overcharge |
| BURST | 2 | 1 each | ATK = floor(attack × 0.6), min 1; both shots same chance |
| HEAVY | 1 | 3 | HEAVY_COOLDOWN_TURNS = 2 after firing |
| ION | 1 | 0 hull | +1 ion token on hit |
| MISSILES | 1 | 4 | Requires target_lock == current_target; consumes 1 ammo (max 2/mission); ignores 1 eff DEF die |
| TURRET | 1 | 2 | Capital emplacement; bypasses shields; CAPITAL_TURRET_COOLDOWN = 2 |

### Overcharge (OVERCHARGE active ability)
Adds OVERCHARGE_ATK = 2 to effective ATK for CANNONS/BURST/HEAVY/ION this round. Applied via `attacker.overcharged = true`.

---

## Upgrade Cards (ship.upgrade: String)

Selected per pilot in LoadoutScreen. Applied at `apply_setup_passives()` (after class stats are set):

| Upgrade | Effect | Timing |
|---|---|---|
| `""` (None) | — | — |
| `"Reinforced Plating"` | hull +1 | Setup passive |
| `"Shield Capacitor"` | shields +1 | Setup passive |
| `"Targeting Computer"` | eff ATK +1 at RANGE_CLOSE | Per-shot in calculate_hit_chance() |
| `"Veteran Reflexes"` | Absorb first stress gain per mission | RoundManager stress roll intercept; `veteran_stress_blocked` flag on Ship |

---

## Pilot Passive Abilities (Pilot.passive: String)

| Passive | Effect |
|---|---|
| `""` | None |
| `"STALWART"` | hull +1 at setup |
| `"EVASIVE"` | Defender gets -EVASIVE_BONUS (0.08) to final hit chance |
| `"MARKSMAN"` | Attacker gets +MARKSMAN_BONUS (0.08) to final hit chance |
| `"STEADY"` | nerve += 0.25 (capped at 1.0) |

## Pilot Active Abilities (Pilot.active_ability: String)

| Active | Effect |
|---|---|
| `"OVERCHARGE"` | ship.overcharged = true; +2 eff ATK this combat |
| `"BARREL_ROLL"` | evade_token = true; if stressed → stress -1 |

`ability_used` is set `true` after use (once per mission). AI uses OVERCHARGE when in arc + unstressed; BARREL_ROLL when stressed.

---

## Hit Chance Formula (CombatSystem.calculate_hit_chance)

```
base_atk = atk_override if >= 0 else attacker.attack
eff_atk = clamp(round(base_atk × accuracy), 0, 6)
eff_def = clamp(round(defence × agility), 0, 6)

# Range modifiers
if dist < RANGE_CLOSE:  eff_atk += 1
if dist > RANGE_MEDIUM: eff_def += 1

# Targeting Computer upgrade
if upgrade == "Targeting Computer" and dist < RANGE_CLOSE: eff_atk += 1

# Rear arc
if target in rear arc of defender: eff_def -= 1

# Formation
if defender.in_formation: eff_def += 1

# Missiles ignore 1 def die
eff_def -= ignore_def (default 0; missiles passes 1)

eff_atk = clamp(eff_atk, 0, 6)
eff_def = clamp(eff_def, 0, 6)

p_hit     = 1 - (1 - 0.625)^eff_atk
p_survive = (1 - 0.375)^eff_def
final     = p_hit × p_survive

# Skill delta modifier (±5% per point, capped ±20%)
final += clamp((attacker.skill - defender.skill) × 0.05, -0.20, 0.20)

# Token modifiers
if attacker.focus_token:  final += 0.15
if attacker.target_lock == defender: final = 1 - (1 - final)^2  (reroll)
if defender.evade_token:  final -= 0.15
if defender.focus_token:  final -= 0.10

# Passive perks
if attacker MARKSMAN: final += 0.08
if defender EVASIVE:  final -= 0.08

return clamp(final, 0.05, 0.95)
```

---

## Combat Resolution Order (run_combat)

1. Tick heavy_cooldown on all alive ships
2. Recompute formation state (FORMATION_RANGE = 190 px, both ships unstressed)
3. Each targetable, alive ship picks nearest in-arc enemy → `_build_shots()`
4. Show combat UI on all ships (hit %, NO SHOT, or RELOADING)
5. **await 1.2s**
6. Resolve all shots (roll randf vs chance) — store results
7. Draw all shot lines simultaneously
8. **await shot_anim + 0.1s**
9. Apply all damage simultaneously (shields first unless bypassed or disrupted)
10. Set cooldowns for HEAVY/TURRET that fired
11. Hide combat UI
12. **await 0.4s**
13. Consume per-round tokens (focus, evade, overcharge)
14. Consume used target locks (lock was used if `used_lock = in_arc and target_lock == target`)
15. Clear locks on destroyed targets

### Simultaneous shots invariant
All shots must be built and stored before ANY damage is applied. Destroying a ship in the resolve loop does NOT prevent that ship's shot from landing.

---

## Ion System

Ion tokens accumulate on the ion track (non-capital ships only).

| Threshold | Effect |
|---|---|
| ion ≥ 2 | Shields disrupted (damage goes direct to hull) |
| ion ≥ 4 | 1 random system disabled from [ENGINES, WEAPONS, SENSORS] for 1-2 rounds |
| ion ≥ 6 | 2 random systems disabled |

System disable effects:
- ENGINES: no BOOST action; ManeuverSelector limits to WHITE maneuvers only
- WEAPONS: `_build_shots()` returns [] (no fire)
- SENSORS: no TARGET_LOCK action; combat UI shows "SENSORS DOWN" with 0% chance

Ion tokens persist for the whole mission (not cleared between rounds).

---

## Formation Bonus

Ships on the same team within FORMATION_RANGE = 190 px of each other gain +1 eff DEF die, provided both ships are unstressed. Formation breaks under stress on either ship.

---

## Campaign System (CampaignManager)

### Roster structure (per entry)
```json
{
  "name": "ACE",
  "base_skill": 5, "skill": 5,
  "accuracy": 1.1, "agility": 1.0, "nerve": 0.3,
  "passive": "", "active": "OVERCHARGE",
  "weapon": "HEAVY",
  "attack": 3, "defence": 2, "shields": 2, "hull": 3,
  "accent": [1.0, 0.3, 0.2],
  "xp": 0, "kills": 0, "status": "healthy",
  "ship_class": "fighter",
  "upgrade": ""
}
```

`status` values: `"healthy"` | `"injured"` | `"dead"`

### XP & levelling
- KILL_XP = 2 per ship destroyed
- SURVIVE_XP = 1 for surviving (not destroyed)
- WIN_XP = 3 for winning the mission
- SKILL_STEP_THRESHOLDS = [5, 15, 30, 50, 75] cumulative XP → each grants +1 skill above base_skill
- MAX_SKILL = 6
- Each skill level also raises the lower of accuracy/agility by STAT_PER_LEVEL = 0.05

### Injury / Death / Drone (THE LONG RETREAT — the hollowing)
- Pilot destroyed + mission **won** → `status = "injured"` (sits out next mission, then recovers)
- Pilot destroyed + mission **lost** → **veteran** is KIA: callsign added to `fallen`, slot
  hollowed into an AI **drone** (skill−1 min 1, no passive/active, no XP growth, designation
  `AUTO-N` not a callsign). This replaces the old permanent-death/auto-revive.
- The **commander** (WARDEN, `commander: true`) is protected: a lost-mission downing only
  injures them (emergency craft), never KIA/drone.
- A **drone** lost just rests (injured) — it's a machine, rebuilt.
- Tutorials apply no XP/injury/death.
- Emergency `_ensure_deployable()`: if no healthy pilots, the lightest-injured is revived.

### Campaign structure — 3 tutorials + 12 missions (index 0–14)
| idx | id | name | act | objective | engine |
|---|---|---|---|---|---|
| 0 | T1 | FIRST LIGHT | tut | destroy all (1 bandit) | – |
| 1 | T2 | TEETH | tut | destroy all (2 bandits) | – |
| 2 | T3 | THE SHADOW | tut | destroy 2 turrets | ✓ (passive) |
| 3 | M1 | REARGUARD | 1 | survive 5 | – |
| 4 | M2 | STRAGGLERS | 1 | protect transport | – |
| 5 | M3 | THE NET | 1 | reach far edge | – |
| 6 | M4 | THRESHING | 1 | survive 5 | ✓ set-piece |
| 7 | M5 | A WAY OUT | 2 | protect scout | – |
| 8 | M6 | BUYING TIME | 2 | hold 5 | – |
| 9 | M7 | THE GAUNTLET | 2 | reach far edge | – |
| 10 | M8 | RECKONING | 2 | survive 5 | ✓ set-piece |
| 11 | M9 | BREATHING ROOM | 2 | destroy all | – |
| 12 | M10 | NO TURNING BACK | 3 | destroy all | – |
| 13 | M11 | THE CORRIDOR | 3 | survive 6 | ✓ (3 turrets) |
| 14 | M12 | THE LONG RETREAT | 3 | survive 6 | ✓ finale (3 turrets) |

### Distance (the pursuit)
- `distance: float` 0–100, starts 50. WIN+no losses +12, WIN+losses +4, LOSE −15.
- `engine_present()` = mission is a set-piece OR `distance < ENGINE_THRESHOLD (30)`. When the
  Engine is present, `current_enemies()` prepends the Threshing Engine hull + N turrets.
- Shown on MainMenu as a bar; warns when closing.

### Objectives (`scripts/Objective.gd`, no class_name — preloaded by consumers)
`Objective.new()` + `configure(dict)`; `RoundManager.set_objective()` then `evaluate(ships,
round)` each EVALUATION returns `"WIN"|"LOSE"|"MUTUAL"|""`. `game_ended(msg, color, won)`
carries the verdict so non-destroy objectives score correctly.
- DESTROY_ALL, SURVIVE_ROUNDS, HOLD_POSITION (survive-in-place), REACH_EDGE (a friendly
  crossing `edge_y`≈120 — top-edge escape isn't culled as out-of-bounds), PROTECT (keep the
  transport alive AND clear all enemies; transport is a tanky team-PLAYER ship spawned by Main,
  not in the planning strip).

### Comms (role-based) & endings
- Mission `beat: {role, text}`; `resolve_beat()` maps LEAD/WING to the highest-/2nd-highest-skill
  living non-drone pilot, else COMMAND/SQUADRON. Shown on LoadoutScreen as a TRANSMISSION.
- KIA triggers a survivor reaction line on the result screen (silence if only drones remain).
- M12 win appends one of three endings (whole / mixed / loneliest) by surviving-veteran count,
  plus a memorial naming the dead, the drones, and the still-flying.

### The squadron (roster, 7 entries)
WARDEN ★commander (s4), LEAD (s5 STEADY/OVERCHARGE), HAWK (s4 MARKSMAN/OVERCHARGE),
VIPER (s3 EVASIVE/BARREL_ROLL), ASH (s3 STALWART/BARREL_ROLL), WREN (s2 MARKSMAN/OVERCHARGE),
DUST (s2 STEADY/BARREL_ROLL). 2 deploy per mission; chosen in LoadoutScreen (no duplicates),
stored in transient `selected_deployment`. Save is `version: 2`; older saves reset cleanly.

### Skirmish mode
- `skirmish_mode: bool` — set by `start_skirmish(enemies)`, cleared on MainMenu load
- `skirmish_enemies: Array` — enemy specs for the skirmish
- `skirmish_record: Dictionary` {"w": int, "l": int} — persisted in campaign.json
- `record_battle()` short-circuits when skirmish_mode: no XP/injury, just increments W or L

---

## Stat Application Order (player ships only)

```
_apply_spec(ship, pilot_dict, skip_passives=true)
  └─ sets: pilot resource, basic stats (attack/defence/shields/hull), upgrade, weapon, accent

ShipClasses.for_id(ship_class)        # NOTE: for_id, not get_class (reserved on Object)
  └─ overrides: attack, defence, shields, hull, firing_arc_degrees, dial_data

ship.rebuild_arc()            ← rebuilds FiringArc polygon with new arc degrees

ship.apply_setup_passives()   ← STALWART +hull, Reinforced Plating +hull, Shield Capacitor +shields
```

Enemy ships: `_apply_spec(ship, spec)` with default `skip_passives=false` → passives called at end of _apply_spec. Class stats come from the spec dict (not ShipClasses).

---

## UI Screens

### MainMenu
- Pilot roster with status colors (grey=dead, orange=injured, white=healthy)
- Shows class and upgrade per pilot
- 3 campaign mission buttons (◄ CURRENT marker on active mission)
- Skirmish W/L record + PLAY SKIRMISH button → SkirmishSetup
- RESET CAMPAIGN button
- On `_ready()`: `CampaignManager.skirmish_mode = false` (cleanup after returning from battle)
- Mission buttons route to **LoadoutScreen** (not directly to Main)

### LoadoutScreen
- Per pilot slot: class selector, weapon selector (auto-updates on class change), upgrade selector
- Live stats preview (ATK/DEF/SHD/HULL/ARC/passives)
- Slot with no available pilot shows "No pilot available" placeholder
- LAUNCH: writes ship_class/weapon/upgrade back to roster entries, `CampaignManager.save()`, → Main
- BACK → MainMenu
- Reads `CampaignManager.skirmish_mode` for header label

### SkirmishSetup
- RANDOM: `randf() < 0.6 → 2 enemies` else 3; each class random from [enemy_fighter, enemy_scout, enemy_assault]; skill 2–3
- MANUAL: 3 OptionButtons (None / Fighter / Scout / Assault); at least 1 must be non-None
- Both paths call `CampaignManager.start_skirmish(specs)` → LoadoutScreen

### Main (battle scene)
- Player ships: PlayerShip, WingShip (pre-placed nodes); pilots from `pilots_for_deployment()`
- Enemy ships: from `current_enemies()` (includes Engine hull + turrets when present)
- Builds the `Objective`, spawns the protected transport (PROTECT), sets `RoundManager.set_objective()`
- Capital + turrets handled separately (no maneuver slots); transport is team PLAYER but not planned
- Planning strip shows only non-destroyed player ships
- Game over: `game_ended(msg, color, won)` → `record_battle(_player_ships, won)`; any key → MainMenu

### PlanningStrip / ShipCard
- ShipCard per player ship: pilot name, selected maneuver label, action toggle row
- Destroyed ships: greyed out (0.38 opacity), maneuver selector blocked, action buttons disabled
- "no orders" ships counted for all-confirmed check; destroyed ships excluded
- CONFIRM button enabled when all non-destroyed player ships have a maneuver

### ManeuverSelector
- Dial-aware path (dial_data != null): builds bearing/speed grid from dial; spacer Controls for absent cells; GREEN/WHITE/RED colour coding
- Legacy path (dial_data == null): bearing_options × speed_options
- Stressed ships: RED buttons disabled; engine-out: only WHITE enabled

### HUD
- Per-ship row: name [skill], shields bar, hull bar (red below 50%), token icons, status (stress/ion/systems), weapon/ammo
- Weapon display: "Missiles x2" / "Missiles x1" / "Missiles [EMPTY]"; "Heavy [cd:N]" / "Heavy READY"; "Burst ×2"; etc.
- Phase label: PLANNING / RESOLVING / ACTIONS / COMBAT / (blank during EVALUATION)
- End screen: result message + campaign summary + "PRESS ANY KEY"

---

## AI Behavior

### Maneuver selection (AIController.select_maneuver)
Scores all valid maneuver options (from dial if available, else bearing_options × speed_options):
- Facing score: dot(forward, to_target) × 10
- Distance score: (1 - |dist - 300| / 300) × 5
- Spread penalty: -8 × (1 - d/160) for each other AI end position within 160 px
- Threat assessment: -6 if inside target forward arc, +4 if in target rear arc
- Skips RED if stressed, skips non-WHITE if engines out
- Out-of-bounds → -1000 (hard reject)

### Action selection (AIController.select_action)
- Active ability first: BARREL_ROLL if stressed; OVERCHARGE if in arc + unstressed
- If stressed (non-ability skipped)
- In arc + sensors OK → TARGET_LOCK (if no lock already) else FOCUS
- Out of arc → FOCUS

---

## GDScript Patterns / Gotchas

**class_name race condition:** Godot's class registry may not have a `class_name` available when another file is parsed. Workaround used throughout: `const X := preload("res://scripts/X.gd")` in any file that types or instantiates X. Files using this pattern:
- `Ship.gd` → `const DialData := preload("res://scripts/DialData.gd")`
- `ShipDials.gd` → `const DialData := preload(...)`
- `ShipClasses.gd` → `const ShipClassData := preload(...); const ShipDials := preload(...)`
- `ShipClassData.gd` → `const DialData := preload(...)`
- `Main.gd` → `const ShipDials := preload(...); const ShipClasses := preload(...); const Objective := preload(...)`
- `ManeuverSelector.gd` → `const DialData := preload(...)`
- `RoundManager.gd` / `HUD.gd` → `const Objective := preload(...)`
- `Objective.gd` carries **no** `class_name` and never self-references (construct via
  `Objective.new()` + `configure()`), so it sidesteps the registry race for self-referencing
  static factories. `ShipClasses.for_id()` (not `get_class` — reserved on Object).

**Simultaneous damage invariant:** Never apply damage inside the shot-building loop. Always: build all → store → draw → apply all.

**Roster dictionary references:** `deployable_pilots()` returns references to the actual roster Dictionary objects. Writing to `pilots[i]["ship_class"] = ...` modifies the live roster.

**apply_setup_passives() call order:** Must be called AFTER class stats (attack/defence/shields/hull) are set. For player ships this means after the ShipClasses override block. For enemy ships it's called at the end of `_apply_spec()`.

**Turret parenting:** Turrets are `add_child()`'d to the capital_body ship node, so their positions are relative to the hull. x_offset 500 and 1100, y=40.

---

## Gates Completed (all 20)

| Gate | Description | Status |
|---|---|---|
| 1–11 | Core engine: arena, maneuver arcs, ghosts, planning UI, resolution, collision, round loop, combat, formation, actions | ✅ |
| 12 | Formation +1 def die, mutual unstressed check | ✅ |
| 13 | Pilot abilities: OVERCHARGE, BARREL_ROLL, MARKSMAN, EVASIVE, STALWART, STEADY | ✅ |
| 14 | Campaign layer: XP/levelling, injury/death, mission progression, JSON save | ✅ |
| 15 | Capital ship set piece: grey rect hull, resized turrets, 3-mission campaign | ✅ |
| 16 | DialData per-ship dial architecture; dual path (dial vs legacy); ManeuverSelector + AI dial-aware | ✅ |
| 17 | ShipDials factory (all 7 classes); ShipClassData resource; FANG/ESCORT tagged enemy_assault | ✅ |
| 18 | Missiles (4dmg, lock required, 2 ammo, -1 def die); 4 upgrade cards; Targeting Computer in hit formula; Veteran Reflexes stress intercept; HUD ammo display | ✅ |
| 19 | ShipClasses factory; LoadoutScreen (class/weapon/upgrade per slot); class stats override spec; MainMenu routes through LoadoutScreen | ✅ |
| 20 | SkirmishSetup (random + manual enemy compose); skirmish_mode in CampaignManager; W/L record persisted; no XP/injury in skirmish | ✅ |
| Campaign | THE LONG RETREAT: Objective system, Distance pursuit, AI-drone hollowing, 3 tutorials + 12 missions, role-based comms, 3 endings | ✅ |

---

## Code Audit (2026-06-14) — findings + fixes

Audited per `dogfight_code_audit_framework.md` (13 sections). Foundation verdict:
**sound to build on.** Three real bugs found and fixed; everything else PASS.

- **HIGH** `RoundManager.round_number` leaked across battles (autoload never reset) →
  reset in `register_ships()`.
- **HIGH** `HUD` connected 5 lambdas to the persistent `RoundManager` autoload; freed on
  scene change but left registered, stacking + firing on dead instances → converted to
  method references (auto-disconnected on free).
- **MEDIUM** `GhostShip` stress preview used bearing-only `get_maneuver_color()` (legacy
  red/green) → now passes `maneuver.speed` for the true dial colour.

Clean (spot-checked): simultaneous-shot invariant, hit-chance order + clamp, ion thresholds
in both UI and AI paths, `is_team_alive` filtering non-targetable hulls, `.gitignore` excludes
generated files, Godot-4 idioms throughout.

---

## Save File

`user://campaign.json` — Godot user data directory

```json
{
  "version": 2,
  "roster": [ /* 7 pilot spec dicts incl commander + drones */ ],
  "mission_index": 0,
  "distance": 50.0,
  "fallen": [ /* dead veteran callsigns */ ],
  "skirmish_record": {"w": 0, "l": 0}
}
```

Saves with `version < 2` reset cleanly. Reset via MainMenu RESET CAMPAIGN →
`CampaignManager.reset_campaign()`.
