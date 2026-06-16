# CLAUDE.md — DOGFIGHT PROJECT
*Last updated: 2026-06-16 — reflects all 31 built gates + full design through Gate 46*

## WHAT THIS PROJECT IS

Top-down 2D tactical space combat in Godot 4.6, GDScript only.
Turn-based secret planning phase → real-time animated resolution.
Player controls ALL friendly ships (up to 6). Single-player vs AI.
Mission-deck campaign with persistent pilots, XP, injury, and permadeath.
The campaign's emotional core is the HOLLOWING MECHANIC — dead named pilots
are replaced by AI drones (skill −1, no abilities, never improve, designation
not callsign). A bad campaign ends with a human commanding silent ghosts.

**Repo:** C:\Users\kyler\JaggedBuild — Godot project: DogfightProto
**Resolution:** 1600×900 viewport. Arena size is PER-MISSION DATA, not fixed.

This is NOT:
- A Star Wars product (X-Wing is a mechanical reference only)
- A real-time game
- A Unity/C# project (ignore all Unity patterns)
- The Stillwater project (discard any Stillwater context entirely)
- A dice-based game (probability model with shown percentages — never revert to dice)

---

## TECH STACK

- Godot 4.6, GDScript only, 2D Forward+ renderer
- Desktop target (Windows primary)
- Git repo — branch: claude/new-session-77fgpr

---

## SCENE STRUCTURE

```
res://
├── scenes/
│   ├── MainMenu.tscn          ← launch scene (roster + mission select)
│   ├── MissionSelectMenu.tscn ← dev test tool — jump to any mission directly
│   ├── LoadoutScreen.tscn     ← pilot/class/weapon/upgrade selection per slot
│   ├── Main.tscn              ← battle arena
│   ├── Ship.tscn              ← shared by player and AI ships (all classes)
│   ├── GhostShip.tscn         ← maneuver preview (one per friendly ship)
│   ├── PlanningStrip.tscn     ← bottom bar, N ShipCards + confirm
│   ├── ShipCard.tscn          ← per-ship card: maneuver + action + formation UI
│   ├── ManeuverSelector.tscn  ← overlay maneuver grid, screen-space anchored
│   └── HUD.tscn               ← round/phase labels + per-ship status bars
└── scripts/
    ├── [AUTOLOADS — 6 total, all registered in Project Settings]
    │   ├── ManeuverSystem.gd   ← arc computation, end-state, dial validation
    │   ├── RoundManager.gd     ← phase state machine + signals
    │   ├── CollisionHandler.gd ← HOTAC Swerve collision (Gate 37, not yet built)
    │   ├── CombatSystem.gd     ← hit chance, simultaneous shots, damage, crits
    │   ├── ActionSystem.gd     ← Focus/Evade/Lock/Boost/Pivot token resolution
    │   └── CampaignManager.gd  ← mission deck, XP, pilot progression, save/load
    ├── Ship.gd                 class_name Ship
    ├── Pilot.gd                class_name Pilot (Resource)
    ├── Weapon.gd               class_name Weapon (Resource)
    ├── Maneuver.gd             class_name Maneuver (RefCounted)
    ├── DialData.gd             class_name DialData (Resource) — per-ship maneuver table
    ├── ShipClassData.gd        class_name ShipClassData (Resource)
    ├── AIStatcard.gd           class_name AIStatcard (Resource) — HOTAC AI (Gate 36)
    ├── TacticalPattern.gd      ← OBSOLETE — replaced by AIStatcard. Do not use.
    ├── GhostShip.gd
    ├── AIController.gd         ← Node in Main.tscn (NOT autoload)
    ├── PlanningStrip.gd
    ├── ShipCard.gd
    ├── ManeuverSelector.gd
    ├── HUD.gd
    ├── MainMenu.gd
    ├── MissionSelectMenu.gd
    ├── LoadoutScreen.gd
    └── Main.gd
```

---

## AUTOLOADS (6 — all must be registered)

```
ManeuverSystem   → res://scripts/ManeuverSystem.gd
RoundManager     → res://scripts/RoundManager.gd
CollisionHandler → res://scripts/CollisionHandler.gd
CombatSystem     → res://scripts/CombatSystem.gd
ActionSystem     → res://scripts/ActionSystem.gd
CampaignManager  → res://scripts/CampaignManager.gd
```

All per-battle mutable state MUST be reset when a new battle starts.
State leaking between battles is the highest-risk bug category. Check resets first.

---

## ROUND LOOP

```
PLANNING → RESOLUTION → ACTION → COMBAT → EVALUATION
```

1. PLANNING — player picks maneuver + action for every living friendly ship via
   PlanningStrip. AI plans all enemy ships simultaneously (hidden, statcard-based).
2. RESOLUTION — ALL ships (friendly + enemy) animate to end positions, sorted by
   pilot_skill ASCENDING (low skill moves first). Collision: HOTAC Swerve rule.
3. ACTION — tokens resolve: Focus, Evade, Target Lock, Boost, Pivot, Abilities.
4. COMBAT — _build_shots() collects ALL shots (including chain fire). ALL hit flags
   resolved in pass 1. ALL damage applied in pass 2. NEVER interleave these.
5. EVALUATION — ion decay, system-disruption countdown, crit ticks (Console Fire /
   Fuel Leak), Danger Zone advance (advancing maps), destruction check, win/loss.

RoundManager signals: planning_phase_started, resolution_phase_started,
action_phase_started, combat_phase_started, evaluation_phase_started, game_ended.

---

## SHIP NODE

```
Ship (Node2D)  [class_name Ship]
├── Body (Sprite2D)      rotation_degrees=-90, scale=(3,3), filter=Nearest (placeholders)
├── FiringArc (Polygon2D)
├── RearArc (Polygon2D)  ← Large hull class only (turret arc)
└── HitLabel (Label)
```

Key Ship.gd fields:
- attack, defence, shields, hull, stress, ion_tokens
- disabled_systems: Dictionary, active_crits: Array[String]
- in_formation, focus_token, evade_token, target_lock
- selected_maneuver, selected_action, ability_used
- heavy_cooldown, turret_facing: String (Large hulls)
- is_destroyed, is_capital, is_targetable, is_objective
- firing_arc_degrees, rear_arc_degrees (0 = no rear arc)
- size_class: String ("SMALL" or "LARGE")
- collision_radius: float (40.0 small, 75.0 large)
- formation_role: String ("NONE", "LEAD", "WING_1", "WING_2")
- formation: Formation (null if not locked)

Pilot helpers: get_skill(), get_accuracy(), get_agility(), get_nerve(),
get_pilot_name(), get_passive(), get_active_ability()
System helpers: is_ionized(), shields_disrupted(), engines_disabled(),
weapons_disabled(), sensors_disabled(), has_crit(id)

---

## ARENA & CAMERA

Arena size is PER-MISSION DATA — not fixed constants.
RoundManager.arena_size: Vector2 is the single source of truth, set at battle start.

```
Default arena archetypes:
  Skirmish (tutorials): 1600×900px
  Open (standard):      2400×1800px  ← corrected to X-Wing 90cm mat feel
  Large (6v6):          4800×2700px
  Corridor (pursuit):   8000×1200px
  Trench run:           800×6000px   ← narrow + advancing map
```

Camera2D with free pan (drag) and zoom (scroll to cursor, 0.4–1.5).
Clicking a ShipCard focuses camera on that ship (smooth lerp).
FRAME ALL button auto-fits all ships in view.
Minimap: ship dots + viewport rect + click-to-jump. Bottom-right corner.

Edge behaviours per mission: WALL (destroy), BLOCK (stop), ESCAPE (ship survives/flees).
Advancing Map missions add a Danger Zone that advances scroll_speed_px per EVALUATION.

---

## DIAL SYSTEM

Each ship class has a DialData resource. Maneuver colours: GREEN (clears stress),
WHITE (standard), RED (adds stress / stressed ships cannot execute).

```gdscript
# DialData.gd
dial[bearing][speed] = "GREEN" | "WHITE" | "RED"
# Absence = maneuver not available on this dial
```

Bearings: STRAIGHT, BANK_LEFT, BANK_RIGHT, TURN_LEFT, TURN_RIGHT, K_TURN, PIVOT
PIVOT = speed 0, zero displacement, rotate facing 90° L/R. Gunship + Large hull only.
compute_end_state() must handle speed-0 (zero displacement) for PIVOT.

Dial resources in res://resources/dials/:
- dial_fighter.tres, dial_heavy.tres, dial_interceptor.tres
- dial_gunship.tres (includes PIVOT at speed 0, green)
- dial_large.tres (Hauler/Bulk Cruiser/Convoy — lumbering, no turns, no K-turn, PIVOT)
- dial_enemy_scout.tres, dial_enemy_assault.tres

---

## SHIP CLASSES

### Player (4 classes)
| Class | ≈X-Wing | Sprite | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|---|
| Wraith Fighter | X-Wing | ship_player_fighter.png | 2 | 2 | 2 | 3 | 90° | 4 |
| Bastion Heavy | Y-Wing | ship_player_heavy.png | 3 | 1 | 3 | 4 | 70° | 3 |
| Razor Interceptor | A-Wing | ship_player_interceptor.png | 1 | 3 | 1 | 2 | 110° | 5 |
| Anchor Gunship | B-Wing | ship_player_gunship.png | 2 | 2 | 3 | 4 | 90°+60° | 3 |

### Enemy (3 classes)
| Class | ≈X-Wing | Sprite | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|---|
| Enemy Fighter | TIE Fighter | ship_enemy_fighter.png | 2 | 2 | 2 | 3 | 90° | 4 |
| Enemy Scout | TIE Interceptor | ship_enemy_scout.png | 1 | 2 | 1 | 2 | 100° | 4 |
| Enemy Assault | TIE Bomber | ship_enemy_assault.png | 3 | 1 | 2 | 3 | 70° | 3 |

### Large Hull (3 instances, same dial_large.tres)
| Instance | ≈X-Wing | Sprite | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|---|
| Hauler-class (player) | YT-1300 | ship_large_hull.png | 2-3 | 1 | 4 | 6 | 90°+90° | 3 |
| Bulk Cruiser (enemy) | Firespray | ship_large_hull.png | 3 | 1 | 4 | 6 | 90°+90° | 3 |
| Convoy Hull (objective) | Lambda | ship_large_hull.png | — | 1 | 3 | 5 | — | 3 |

Large hulls: collision_radius = 75px, sprite_scale = 5.0, dual firing arcs,
PIVOT at speed 0, turret facing selectable each round (FRONT/REAR/LEFT/RIGHT).
Convoy Hull: is_objective = true. If destroyed → mission FAILS.

---

## WEAPONS (7 types)

| Type | Ammo | Dmg | Special | Crit table |
|---|---|---|---|---|
| CANNONS | ∞ | 1 | — | Direct Hit / Hull Breach |
| BURST | ∞ | 1×2 | 2 shots at ×0.6 ATK | Rattled / Console Fire |
| HEAVY | ∞ | 3 | 2-round cooldown | Hull Breach / Structural Damage / Direct Hit |
| ION | ∞ | 0 | +1 ion token on hit | Sensors Fried / Power Regulator |
| TURRET | ∞ | 2 | Shield bypass, 2cd, selectable facing | Weapons Failure / Damaged Engine |
| MISSILES | 2 | 4 | Requires lock (spent), ignores 1 def die | Direct Hit / Fuel Leak |
| TORPEDOES | 1 | 5 | Requires lock (spent), GUARANTEES crit if shields=0 | Full table draw |

TORPEDOES draw from the FULL 10-effect crit table (not weapon-specific).
Fuel Leak persists to next campaign mission (all other crits clear at mission end).

---

## COMBAT PROBABILITY MODEL

```
BASE_HIT_CHANCE   = 0.625
BASE_EVADE_CHANCE = 0.375
```

Modifier order (apply in this exact sequence):
1. Range: close (<167px) +1 eff ATK die; long (>333px) +1 eff DEF die
2. Facing: rear arc hit −1 eff DEF die
3. Formation (unstressed, within 190px): +1 eff DEF die
4. Pilot skill delta: ±0.05/pt capped ±0.20
5. Convert to probability: p = 1−(1−BASE_HIT)^eff_atk × (1−BASE_EVADE)^eff_def
6. Token modifiers: Focus atk +0.15, Evade def −0.15, Focus def −0.10,
   Lock = recalculate and take higher, Overcharge +2 eff ATK dice
7. Passives: MARKSMAN +0.08, EVASIVE −0.08
8. Clamp [0.05, 0.95] — LAST STEP, nothing modifies after clamp

### CRITICAL HIT SYSTEM
Crits only land on UNSHIELDED hulls (shields = crit insulation).
CRIT_CHANCE_BASE = 0.35 (35% of unshielded hull hits).
Weapon-typed crit tables (see Weapons section above).
Crits persist all battle. Repair between missions only.
TORPEDOES skip the crit roll — guaranteed draw from full table if shields = 0.

### SIMULTANEOUS RESOLUTION — NON-NEGOTIABLE
```gdscript
# _build_shots() — ALWAYS this structure
var shots = []
# Pass 1: calculate all hits (including chain fire from formation)
for ship in firing_ships:
    shots.append(calculate_shot(...))
    if ship.formation_role == "WING" and ship.formation.lead.last_shot_hit:
        shots.append(build_chain_fire_shot(...))  # formation chain fire
# Pass 2: apply all damage
for shot in shots:
    if shot.hit:
        apply_damage(shot.target, shot.damage)
```
Sequential damage = broken dying-blow mechanic. Never do it.

---

## AI SYSTEM — HOTAC STATCARD MODEL

**Replaces:** the old heuristic weighted-scoring AIController.
**Source:** Heroes of the Aturi Cluster (adapted for continuous geometry).

AI ships do NOT plan secretly. They activate in order and read the board.
Each enemy ship type has an AIStatcard resource with 4 steps:

**Step 1 — Select Target:** walk target_priority list, first valid wins.
"Nearest" = physically nearest in shortest range band.

**Step 2 — Select Maneuver:** bucket continuous position into range band
(CLOSE/MEDIUM/LONG/OUT) × bearing zone (BULLSEYE/FRONT/FRONT_SIDE/REAR_SIDE/REAR).
If target is FLEEING (AI ship is behind the target's front line), shift one range band
outward. Index maneuver_table[band][zone], pick randomly from cell options.
If stressed, use stress_maneuver_table instead.

**Step 3 — Select Action:** priority cascade, top to bottom, first condition met wins.
Not stressed + not red maneuver + not overlapping = eligible for actions.

**Step 4 — Attack:** re-select target. Priority: locked > R1 > R2 > R0 > R3.
Spend tokens to maximise damage on attack, minimise damage on defence.
Digital pre-measuring: evaluate action criteria exactly, not by eyeballing.

**Alternate target modes (per mission):**
- ATTACK (default): standard statcard priority
- STRIKE: relentlessly pursue a specific target (convoy, objective)
- FLEE: target nearest point of a specified board edge, fastest speed
- ESCORT: if escort target within close range, use Protect action on it

**Red maneuvers:** AI executes them but skips its action (no stress token).
**Ion:** ionized AI → forced 1-straight, Focus action only.
**Crit repair:** if ship has a repairable crit (Fuel Leak), repair is first action priority.

### COLLISION — HOTAC SWERVE (Gate 37, not yet built)
Replaces old truncate-before-overlap approach.
If chosen maneuver overlaps: adjust bearing 45° either direction, same speed,
K-turn→bank. If still collides, execute original and accept collision.
Collision cost: skip action this round.
Board edges: every effort to avoid. If unavoidable, ship is destroyed.

### BREAKING FORMATION (AI)
AI ships break formation and act independently when:
1. No longer within close range of any formation member
2. No longer facing same direction as majority (after swerving)
3. A player ship collides with or damages any formation member
(Do NOT break for AI-vs-AI collisions.)

### STATCARD RESOURCES
res://resources/ai_statcards/
- statcard_enemy_fighter.tres   (≈ TIE Fighter — simple, aggressive)
- statcard_enemy_scout.tres     (≈ TIE Interceptor — fast, K-Turn re-engage)
- statcard_enemy_assault.tres   (≈ TIE Bomber — slow brawler)
- statcard_bulk_cruiser.tres    (≈ Firespray — Large, no turns, dual arc)

---

## FORMATION LOCK (Player — Gate 44-45, not yet built)

Proximity snap: ships within 190px offered LOCK button on ShipCard.
Maximum: 1 Lead + 2 Wings (3 ships).
Lead selects maneuver. Wings follow same bearing+speed from offset positions
(160px perpendicular L/R of lead facing).
Formation dial = INTERSECTION of all members' dials, capped at slowest member's speed.
Stress colours = most restrictive across members.

CHAIN FIRE (combat): if lead's shot HITS, each wing in arc of same target gets a
FREE attack on that target. Free attack does NOT consume wing's action.
If lead MISSES: no chain fire. Wings fire normally on own targets.
Chain fire shots added to _build_shots() array — simultaneous resolution preserved.

Breaking formation lock: manual BREAK button, any member destroyed,
separation outside 190px, stress prevents red maneuver execution.

---

## ADVANCING MAP (Gate 42-43, not yet built)

Danger Zone advances along scroll_axis by scroll_speed_px each EVALUATION phase.
Ships behind leading edge take 1 hull damage (shield bypass) → then destroyed.
Enemy AI treats leading edge as a board edge (avoids it).
Forward Wall = ESCAPE edge at mission exit (jump point).

Mission data defines:
- scroll_axis: Vector2 (default Vector2(0,-1) — Engine below, squad flies up)
- scroll_speed_px: float (60 default, 80 for M12 finale)
- danger_zone_width_px: float (120)
- forward_wall_buffer_px: float (80)

Spawn positions defined relative to danger_zone_leading_edge, not fixed world coords.

---

## CAMPAIGN — MISSION DECK ENGINE (Gate 40, not yet built)

Replaces linear 12-mission chain.
Mission cards form a deck. Each round: draw several, player picks one.
Victory/defeat text modifies deck (+Mission, Discard, Reshuffle).
Campaign length: Short (3 starts, ~6-9 missions, 2VP), Medium (5 starts, ~9-15, 3VP).

The Threshing Engine (pursuit capital ship) is tracked via DISTANCE value in
CampaignManager. Good missions gain Distance; failures lose it. When Distance
falls below threshold, next mission becomes an Engine set-piece (Danger Zone active).

Hollowing: shot-down pilot rolls EJECT. Survives → injured (sits out). KIA → permanent.
KIA slot filled by AI drone: skill = dead pilot's skill − 1, no abilities, no growth,
designation not callsign. This is the campaign's emotional core. Do not remove it.

Save: user://campaign.json — persists pilots, XP, skill, status, mission deck state,
distance value, skirmish record.

### TEST MODE
CampaignManager.test_mode = true skips XP, deck changes, injury, hollowing, distance.
Set by MissionSelectMenu. Returns to MissionSelectMenu after battle (not MainMenu).
Reset to false in MainMenu._ready().

---

## CONSTANTS (never hardcode — all in .tres resources)

```
BASE_SPEED_UNIT:          80.0 px     (= X-Wing speed-1 at 4cm scale)
SHIP_COLLISION_RADIUS:    40.0 px     (small) / 75.0 px (large)
SHIP_SPRITE_SCALE:        3.0         (small) / 5.0 (large)
RANGE_CLOSE:              167.0 px
RANGE_MEDIUM:             333.0 px
RANGE_MAX:                500.0 px
BASE_HIT_CHANCE:          0.625
BASE_EVADE_CHANCE:        0.375
SKILL_MOD_PER_POINT:      0.05
SKILL_MOD_CAP:            0.20
FOCUS_HIT_BONUS:          0.15
EVADE_TOKEN_REDUCTION:    0.15
FOCUS_EVADE_BONUS:        0.10
HIT_CHANCE_MIN:           0.05
HIT_CHANCE_MAX:           0.95
CRIT_CHANCE_BASE:         0.35
FORMATION_LOCK_RANGE:     190.0 px
FORMATION_OFFSET:         160.0 px
SCROLL_SPEED_DEFAULT:     60.0 px/round
SCROLL_SPEED_FINALE:      80.0 px/round
ZOOM_MIN:                 0.4
ZOOM_MAX:                 1.5
ION_THRESHOLD_SHIELDS:    2
ION_THRESHOLD_SYSTEM1:    4
ION_THRESHOLD_SYSTEM2:    6
CAPITAL_TURRET_DAMAGE:    2
CAPITAL_TURRET_HULL:      3
FORMATION_BONUS_DICE:     1
```

---

## ASSETS

All pixel-art placeholders. Nearest filter. rotation_degrees = −90 (sprites face left).
Final anime OVA art will face up natively and use Linear filter.

```
res://assets/ships/
  ship_player_fighter.png    Wraith Fighter (red interceptor)
  ship_player_heavy.png      Bastion Heavy (grey boxy)
  ship_player_interceptor.png Razor Interceptor (green angular)
  ship_player_gunship.png    Anchor Gunship (grey wide)
  ship_enemy_fighter.png     Enemy Fighter (dark wedge)
  ship_enemy_scout.png       Enemy Scout (twin-engine)
  ship_enemy_assault.png     Enemy Assault (colourful wide)
  ship_large_hull.png        All Large hull instances (blue compact — rounder)
  ship_alien_reserve.png     Unassigned reserve
  ship_cruiser_reserve.png   Unassigned reserve
```

Accent colours:
- Player faction: Color(0.0, 1.0, 1.0)  — Plasma Cyan
- Enemy faction:  Color(1.0, 0.0, 0.502) — Hot Magenta
- Objective ships: neutral grey accent

---

## GATE STATUS

```
✅ BUILT (Gates 1–31)
Gate 1-5:   Movement, round loop, collision, AI, combat (probability model)
Gate 5.5:   Squad planning UI (N ships, multi-ghost, confirm all)
Gate 6-10:  Actions, stress, weapons (5 types), pilot stats, ion system
Gate 11-15: Squad AI, formation defence bonus, pilot abilities, campaign layer,
            capital ship set piece (grey hull bar, destroyable turrets)
Gate 16-20: DialData per-ship dials, 4 player + 3 enemy ship classes, weapon/upgrade
            slots, LoadoutScreen, Skirmish mode (no XP/injury)
Gate 21-27: Arena-size-as-data, Camera2D pan/zoom, variable map sizes, focus-ship
            button, minimap, per-edge WALL/BLOCK/ESCAPE, fleet expansion to 6/side
Gate 28-31: Large ship class — size_class/collision_radius(75)/sprite_scale(5),
            lumbering dial (no turns/K-turn, speed≤3), dual firing arcs (forward
            weapon + fixed rear TURRET, own cooldown), Hauler (player) + Bulk
            Cruiser (enemy, in M10) + Convoy Hull (is_objective, mission-fails on
            death). Hauler in LoadoutScreen; AI weights is_objective targets +400.

⬜ DESIGNED, NOT YET BUILT (Gates 32–46)
Gate 32-35: Critical hit system (shields insulate, weapon-typed crit tables,
            10 effects, TORPEDOES weapon type, Fuel Leak campaign persistence)
Gate 36-39: HOTAC AIStatcard infrastructure, Swerve collision, alternate target
            modes (Strike/Flee/Escort), token logic, crit-repair priority
Gate 40-41: Mission-deck campaign engine, eject roll → hollowing, elite enemy pilots
Gate 42-43: Advancing Map Danger Zone, spawn system, Forward Wall, trench run variant
Gate 44-45: Formation Lock (proximity snap, lead+wing movement, chain fire)
Gate 46:    Integration + M4/M11/M12 wired to advancing map
```

---

## BUILD REALITY (shipped code vs. this design doc)

This doc is design-forward; the actual build (Gates 1–31) diverges in places. A session
building Gate 32+ should follow the SHIPPED conventions, not invent the doc's targets:

- **Dials & ship classes are GDScript static factories, NOT `.tres`.** `ShipDials.gd`
  (`fighter()/heavy()/interceptor()/gunship()/large()/enemy_*()`) returns `DialData.new()`;
  `ShipClasses.gd` (`for_id()`, `_fighter()…_hauler()`) returns `ShipClassData.new()`. There is
  no `res://resources/dials/` or `ai_statcards/` folder. `ShipClasses.for_id()` — NOT `get_class`.
- **Tuning constants are `const` in autoload scripts** (CombatSystem.gd, ManeuverSystem.gd,
  CampaignManager.gd), not `.tres`. (The "all in .tres" rule below is aspirational.)
- **AIController is the heuristic weighted-scorer** (`select_maneuver`/`_score_state`/
  `_highest_threat`), still in use. HOTAC statcard AI is NOT built (Gate 36+).
- **Collision** is `CollisionHandler.resolve_bump` (truncate-before-overlap), now reading each
  ship's own `collision_radius`. HOTAC Swerve NOT built (Gate 37).
- **No PIVOT.** The large dial (`ShipDials.large`) is STRAIGHT + gentle banks only, no turns/
  K-turn, speed≤3. The rear turret is a FIXED rear arc (`turret_arc_degrees`), not selectable
  FRONT/REAR/LEFT/RIGHT. No `turret_facing` field. Convoy Hull is stationary (no autopilot yet).
- **Objective system** (`Objective.gd`, no class_name — preloaded): DESTROY_ALL / SURVIVE_ROUNDS /
  REACH_EDGE / PROTECT / HOLD_POSITION; `RoundManager.set_objective`; `game_ended(msg,color,won)`.
  Any `is_objective` hull destroyed → LOSE.
- **Campaign is linear "THE LONG RETREAT"** (3 tutorials + 12 missions in `CampaignManager.get_missions`),
  with Distance, AI-drone hollowing, role-based comms, 3 endings. The mission-DECK engine (Gate 40)
  is NOT built. Save is `version: 2`.
- **Assets:** repo has only `ship_player.png` + `ship_ai.png` (+ a couple reserves). The per-class
  sprites and `ship_large_hull.png` listed below do NOT exist yet — all classes reuse those two,
  scaled (3× small, 5× large). `rotation_degrees = -90`.
- **In-repo status doc:** `dogfight_game_state.md` (git-tracked) mirrors this and is kept current.
- NOT built: crits/torpedoes (32-35), HOTAC AI/swerve (36-39), mission deck (40-41), advancing
  map (42-43), formation lock (44-45).

---

## WHAT NOT TO DO

- Do not use C# — GDScript only
- Do not use dice — probability model with shown percentages only
- Do not apply sequential damage — simultaneous resolution is non-negotiable
- Do not hardcode tuning constants — everything in .tres resource files
- Do not reference old AIController heuristic scoring — HOTAC statcard AI replaces it
- Do not reference TacticalPattern.gd — obsolete, superseded by AIStatcard
- Do not reference truncate-before-overlap collision — HOTAC Swerve replaces it
- Do not reference Stillwater, Black Site Breach, or any other project
- Do not build ahead of the current gate without confirmation
- Do not use linear filtering on pixel art placeholder sprites
- Do not mutate shared .tres resources at runtime — copy values to instance fields

---

## REFERENCE DOCUMENT

For full system specs per gate, load the relevant section from DOGFIGHT_MASTER.md.
Do not load the whole master doc — it is 280KB. Load one section per session.

Sections by gate range:
- Gates 28-31 → "Large Ship Class & Escort System"
- Gates 32-35 → "Critical Hit System"
- Gates 36-41 → "HOTAC-Derived AI & Campaign Engine"
- Gates 42-43 → "Advancing Map & Formation Lock" (Part 1)
- Gates 44-46 → "Advancing Map & Formation Lock" (Part 2)

*CLAUDE.md — Dogfight Project — June 2026*
