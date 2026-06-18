# CLAUDE.md — THE LONG RETREAT
*Last updated: June 2026 — Session 4 closeout. Reflects actual codebase state.*
*Source of truth: CURRENT_STATE.md in repo root*

## WHAT THIS PROJECT IS

Top-down 2D tactical space combat. Turn-based planning → animated resolution.
Player controls ALL friendly ships (up to 6). Single-player vs HOTAC statcard AI.
Mission-deck campaign with persistent pilots, XP, injury, permadeath, and the
HOLLOWING MECHANIC — dead named pilots replaced by AI drones (skill −1, no
abilities, never improve, designation not callsign).

**Project name:** The Long Retreat
**Repo:** C:\Users\kyler\JaggedBuild — project: DogfightProto
**Branch:** claude/new-session-77fgpr
**Godot:** 4.6.2.stable.mono
**Renderer:** 2D Forward+, viewport 1600×900

This is NOT Unity, NOT Stillwater, NOT a dice game, NOT real-time.

---

## SCENE STRUCTURE

```
res://scenes/
  MainMenu.tscn        Launch scene — roster, mission card, DEPLOY, SKIRMISH/TEST
  MissionSelectMenu.tscn  Dev tool — jump to any mission, sets test_mode=true
  LoadoutScreen.tscn   Pre-battle pilot/class/weapon/upgrade selection
  SkirmishSetup.tscn   Skirmish configuration screen
  Main.tscn            Battle arena — ships, camera, planning, HUD, minimap
  Ship.tscn            Shared node all ships; runtime stats set by Main
  GhostShip.tscn       Maneuver preview; one per friendly, managed by PlanningStrip
  PlanningStrip.tscn   Bottom bar — ShipCard row + CONFIRM ALL + ManeuverSelector
  ShipCard.tscn        Per-ship card: name, maneuver, actions, formation LOCK
  ManeuverSelector.tscn  Popup dial grid, screen-space anchored above card
  HUD.tscn             Top-right CanvasLayer — phase labels + status bars
```

---

## AUTOLOADS (9 — all registered in project.godot)

```
UIConstants     → scripts/UIConstants.gd
EffectSystem    → scripts/EffectSystem.gd
ManeuverSystem  → scripts/ManeuverSystem.gd
RoundManager    → scripts/RoundManager.gd
CollisionHandler→ scripts/CollisionHandler.gd
CombatSystem    → scripts/CombatSystem.gd
ActionSystem    → scripts/ActionSystem.gd
CampaignManager → scripts/CampaignManager.gd
AudioManager    → scripts/AudioManager.gd
```

Per-battle mutable state MUST reset when a new battle starts.
State leaking between battles is the highest-risk bug category.

---

## ROUND LOOP

```
PLANNING → RESOLUTION → ACTION → COMBAT → EVALUATION
```

RoundManager signals: planning_phase_started, resolution_phase_started,
action_phase_started, combat_phase_started, evaluation_phase_started, game_ended.

---

## SHIP NODE

```
Ship (Node2D) [class_name Ship]
├── Body (Sprite2D)   scale=Vector2(0.2,0.2) fallback
│                     runtime: small=0.2, large=0.33 (500px source → ~100/165px)
│                     rotation_degrees=0 (new sprites face up natively)
│                     filter=LINEAR
├── FiringArc (Polygon2D)
├── RearArc (Polygon2D)   Large hull only
└── HitLabel (Label)
```

Key Ship.gd fields: attack, defence, shields, hull, stress, ion_tokens,
disabled_systems, active_crits, in_formation, focus_token, evade_token,
target_lock, selected_maneuver, selected_action, ability_used, heavy_cooldown,
turret_facing, is_destroyed, is_capital, is_targetable, is_objective, is_drone,
size_class, collision_radius, firing_arc_degrees, rear_arc_degrees,
formation_role, formation.

---

## ARENA & CAMERA

Arena size is PER-MISSION DATA. RoundManager.arena_size: Vector2.

```
Mission          W      H      Notes
T1/T2/T3      1600    900    Tutorial default
M1-M3, M5-M10 2400   1800    Standard Open
M4            1600    900    Advancing map ← NOTE: still 1600×900 in code
M11, M12      1600    900    Advancing maps ← NOTE: still 1600×900 in code
M3            2400   1800    Top edge = ESCAPE
```

NOTE: Corridor archetype (8000×1200) is designed but advancing map missions
(M4/M11/M12) are currently using 1600×900. Update when map redesign session runs.

Camera: ZOOM_MIN=0.4, ZOOM_MAX=1.5, ZOOM_STEP=1.1×, FOCUS_ZOOM=1.0
Free pan (drag), zoom to cursor (scroll), focus-ship (ShipCard click),
FRAME ALL button. Minimap: ship dots + viewport rect + click-to-jump.

---

## DIAL SYSTEM

DialData: dial[bearing][speed] = "GREEN"|"WHITE"|"RED"
Bearings: STRAIGHT, BANK_LEFT, BANK_RIGHT, TURN_LEFT, TURN_RIGHT, K_TURN, PIVOT
PIVOT = speed 0, zero displacement, rotate 90° L/R. Gunship + Large hull only.
ManeuverSystem.compute_end_state() handles PIVOT (zero displacement case).
ShipDials.gd: static factory returning DialData instances (no .tres files).

---

## SHIP CLASSES

### Player (4)
| Class | ≈X-Wing | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|
| Wraith Fighter | X-Wing | 2 | 2 | 2 | 3 | 90° | 4 |
| Bastion Heavy | Y-Wing | 3 | 1 | 3 | 4 | 70° | 3 |
| Razor Interceptor | A-Wing | 1 | 3 | 1 | 2 | 110° | 5 |
| Anchor Gunship | B-Wing | 2 | 2 | 3 | 4 | 90°+60° | 3 |

### Enemy (3)
| Class | ≈X-Wing | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|
| Enemy Fighter | TIE Fighter | 2 | 2 | 2 | 3 | 90° | 4 |
| Enemy Scout | TIE Interceptor | 1 | 2 | 1 | 2 | 100° | 4 |
| Enemy Assault | TIE Bomber | 3 | 1 | 2 | 3 | 70° | 3 |

### Large Hull (3 instances, dial_large — lumbering, no turns, no K-turn, PIVOT)
| Instance | ≈X-Wing | ATK | DEF | SHD | HUL | ARC | SPD |
|---|---|---|---|---|---|---|---|
| Hauler (player) | YT-1300 | 2-3 | 1 | 4 | 6 | 90°+90° | 3 |
| Bulk Cruiser (enemy) | Firespray | 3 | 1 | 4 | 6 | 90°+90° | 3 |
| Convoy Hull (objective) | Lambda | — | 1 | 3 | 5 | — | 3 |

Large: collision_radius=75px, size_class="LARGE", dual firing arcs,
turret facing selectable each round. Convoy: is_objective=true.
ShipClasses.gd: static factory for_id(id) → ShipClassData (no .tres files).

---

## WEAPONS (7 types — Weapon.Type enum)

| Type | Ammo | Dmg | Special | Crit table |
|---|---|---|---|---|
| CANNONS | ∞ | 1 | — | Direct Hit / Hull Breach |
| BURST | ∞ | 1×2 | 2 shots ×0.6 ATK | Rattled / Console Fire |
| HEAVY | ∞ | 3 | 2-round cooldown | Hull Breach / Structural Damage / Direct Hit |
| ION | ∞ | 0 | +1 ion on hit | Sensors Fried / Power Regulator |
| TURRET | ∞ | 2 | Shield bypass, 2cd, selectable facing | Weapons Failure / Damaged Engine |
| MISSILES | 2 | 4 | Requires lock, ignores 1 def die | Direct Hit / Fuel Leak |
| TORPEDOES | 1 | 5 | Requires lock, guaranteed crit if shields=0 | Full table draw |

---

## COMBAT PROBABILITY

```
BASE_HIT_CHANCE=0.625  BASE_EVADE_CHANCE=0.375
```

Modifier order (apply in sequence):
1. Range: CLOSE(<182px) +1 eff ATK; LONG(>369px) +1 eff DEF
2. Facing: rear arc −1 eff DEF
3. Formation (unstressed, within 190px): +1 eff DEF
4. Pilot skill delta: ±0.05/pt capped ±0.20
5. Convert to probability
6. Tokens: Focus atk +0.15, Evade −0.15, Focus def −0.10,
   Lock = recalculate take higher, Overcharge +2 eff ATK
7. Passives: MARKSMAN +0.08, EVASIVE −0.08
8. Clamp [0.05, 0.95] — LAST, nothing after

CRIT_CHANCE_BASE=0.35. Crits only on unshielded hull hits.
TORPEDOES: guaranteed crit (skips roll) if shields=0.
Fuel Leak persists to campaign; all other crits clear at mission end.

SIMULTANEOUS RESOLUTION — NON-NEGOTIABLE:
Pass 1: resolve all hit flags (including chain fire).
Pass 2: apply all damage. Never interleave.

---

## AI — HOTAC STATCARD

AIStatcards.gd: static factory for_class(id) → AIStatcard.
4-step activation: Select Target → Select Maneuver → Select Action → Attack.
Range bands: CLOSE<182px, MEDIUM 182-369px, LONG 369-552px, OUT>552px.
Bearing zones: BULLSEYE(±10°), FRONT(±45°), FRONT_SIDE(±90°),
               REAR_SIDE(±135°), REAR(±180°).
Closing/Fleeing: dot product of target facing vs AI-to-target vector.
Fleeing target: shift one range band outward.

Collision: HOTAC Swerve (adjust 45°, same speed, K-turn→bank, else accept).
Collision cost: skip action this round.
Breaking Formation: range, facing, or player-collision triggers.

Alternate target modes (per mission): ATTACK, STRIKE, FLEE, ESCORT.
TacticalPattern.gd: OBSOLETE — do not use or extend.

---

## FORMATION LOCK (Player)

Snap on proximity (190px). Max: 1 Lead + 2 Wings.
Lead sets maneuver. Wings follow same bearing+speed from offset (160px perp).
Formation dial = intersection of all members' dials, slowest-member speed cap.
CHAIN FIRE: if lead hits, each wing in arc gets free attack on same target.
Chain fire appended to _build_shots() array — simultaneous resolution preserved.
Breaking: manual BREAK, member destroyed, separation >190px, stress prevents red.

---

## ADVANCING MAP

DangerZone advances scroll_speed_px per EVALUATION phase.
Ships behind leading edge: 1 hull damage (shield bypass) then destroyed.
Forward Wall = ESCAPE edge at exit.
Enemy AI treats leading edge as board edge.

Mission data: scroll_axis, scroll_speed_px, danger_zone_width_px.
Spawn positions relative to danger_zone_leading_edge.

---

## CAMPAIGN — MISSION DECK

Mission cards form a deck. Draw N, pick one, play it.
Victory/defeat text modifies deck: +[ID], DISCARD, RESHUFFLE, +VP:N.
Campaign VP = escape points. Threshold = campaign length (Short 2, Medium 3).
Distance tracks Engine pursuit. Low Distance → Engine set-piece missions.

Hollowing: KIA → AI drone (skill−1, no abilities, no growth, designation not callsign).
Drone ships: is_drone=true, use drone sprite, gunmetal border, 80% alpha, no tokens.

CampaignManager.test_mode=true: skips XP, deck changes, injury, hollowing.
Returns to MissionSelectMenu after battle if test_mode.
Reset in MainMenu._ready().

Save: user://campaign.json

---

## AUDIO

AudioManager autoload. 8-player SFX pool. Two music players (A/B crossfade).
Music buses: Master > Music > SFX.

Key mappings:
  music_title, music_planning, music_combat
  sfx_cannon, sfx_burst, sfx_heavy, sfx_ion, sfx_missile†, sfx_torpedo†
  sfx_shield_hit, sfx_hull_hit, sfx_explosion, sfx_ion_hit, sfx_crit
  sfx_kia† (plays 0.3s after explosion, named pilots only — NOT drones)
  sfx_click, sfx_hover, sfx_confirm, sfx_cancel, sfx_phase, sfx_error
  sfx_win†, sfx_lose

† = PLACEHOLDER — needs proper audio file

---

## UI SYSTEM

UIConstants.gd autoload. All colours/fonts/sizes/icons from here.
Never hardcode colours or font paths anywhere else.

Key colours (use constant names, not hex):
  COLOR_CYAN=#00FFFF, COLOR_MAGENTA=#FF0080, COLOR_AMBER=#FFB800
  COLOR_SHIELD=#4299E1, COLOR_HULL=#ED8936, COLOR_HULL_CRIT=#E53E3E
  COLOR_ION=#9F7AEA, COLOR_CRIT=#C53030
  COLOR_GREEN_DIAL=#00FF88, COLOR_RED_DIAL=#FF4444
  COLOR_BG_PANEL=#0D1117, COLOR_INACTIVE=#4A5568, COLOR_SILVER=#A0AEC0

Fonts: FONT_UI=Orbitron, FONT_NARR=Cinzel (both in res://assets/fonts/)
Icon atlases preloaded: ICONS_ACTIONS, ICONS_STATUS, ICONS_DISRUPTION,
                        ICONS_CRITS, ICONS_WEAPONS

Phase label colours: PLANNING=cyan, RESOLVING=amber, ACTION=white,
                     COMBAT=magenta, EVALUATION=silver

---

## CONSTANTS

```
ManeuverSystem (ACTUAL values — differ from old CLAUDE.md):
  BASE_SPEED_UNIT=80.0
  RANGE_CLOSE=182.0      ← updated (was 167)
  RANGE_MEDIUM=369.0     ← updated (was 333)
  MAX_RANGE=552.0        ← updated (was 500)
  BANK_LATERAL=0.4, BANK_FORWARD=0.9
  TURN_LATERAL=0.7, TURN_FORWARD=0.7

CombatSystem (match CLAUDE.md):
  BASE_HIT_CHANCE=0.625, BASE_EVADE_CHANCE=0.375
  CRIT_CHANCE_BASE=0.35
  FORMATION_RANGE=190.0, FORMATION_OFFSET=160.0
  HEAVY_DAMAGE=3, MISSILES_DAMAGE=4, TORPEDOES_DAMAGE=5
  ION_THRESHOLD_SHIELDS=2, ION_THRESHOLD_SYSTEM1=4, ION_THRESHOLD_SYSTEM2=6
  MARKSMAN_BONUS=0.08, EVASIVE_BONUS=0.08
  CAPITAL_TURRET_DAMAGE=2, CAPITAL_TURRET_HULL=3

Camera:
  ZOOM_MIN=0.4, ZOOM_MAX=1.5, ZOOM_STEP=1.1x, FOCUS_ZOOM=1.0
```

---

## GATE STATUS (all BUILT)

```
Gates 1–5:   Movement, round loop, collision, AI, combat probability
Gate 5.5:    Squad planning UI
Gates 6–10:  Actions, stress, weapons, pilot stats, ion
Gates 11–15: Squad AI, formation defence, abilities, campaign, capital ship
Gates 16–20: DialData, ship classes, LoadoutScreen, Skirmish
Gates 21–27: Arena-as-data, camera, minimap, edges, 6v6
Gates 28–31: Large hull, dual arcs, Hauler/Cruiser/Convoy
Gates 32–35: Crit system, 10 effects, TORPEDOES
Gates 36–39: HOTAC AI, swerve, STRIKE/FLEE/ESCORT modes
Gates 40–41: Mission deck, eject, KIA hollowing
Gates 42–43: Advancing map, danger zone
Gates 44–45: Formation lock, chain fire
Gate 46:     M4/M11/M12 wired to advancing map
Audio:       AudioManager, crossfade, SFX pool, phase triggers
Sessions 1-3: Ship sprites, background, effects, UI style, audio
```

---

## KNOWN ISSUES

- 4 audio PLACEHOLDERs: sfx_missile, sfx_torpedo, sfx_kia, sfx_win
- Advancing map missions (M4/M11/M12) using 1600×900 not Corridor 8000×1200
- Non-fatal warning on open: DialData name shadow in Ship.gd:4 (harmless)
- TacticalPattern.gd exists but is OBSOLETE — do not extend or use

---

## ASSETS

All in res://DEMO_ASSETS/. Do not move or rename.

Ships: painted anime-style sprites, nose-up, LINEAR filter, scale 0.2/0.33
Background: nebula.png as TextureRect behind all ships
Effects: cannon bolt, shield hit (4f), hull hit (4f), explosion (6f)
Icons: 5 strip PNGs → UIConstants atlas preloads
Arcs: reference images for firing arc and movement arc styling
Fonts: Orbitron + Cinzel in res://assets/fonts/
Audio: Kenny pack + Bonus folder + JDSherbert UI pack + music folder

---

## WHAT NOT TO DO

- No C# — GDScript only
- No dice — probability model with shown percentages
- No sequential damage — simultaneous resolution only
- No hardcoded colours — UIConstants only
- No hardcoded tuning constants — keep in constants sections
- No TacticalPattern.gd — obsolete, use AIStatcard
- No Stillwater/other project references
- No linear filtering on pixel art (only on painted sprites)
- No shared .tres resource mutation at runtime

---

## REFERENCE

Full design history: DOGFIGHT_MASTER.md (280KB — load one section at a time)
Current actual state: CURRENT_STATE.md (in repo root)

Section → Gate range:
  Large Ship Class      → Gates 28-31
  Critical Hit System   → Gates 32-35
  HOTAC AI & Campaign   → Gates 36-41
  Advancing Map & Formation → Gates 42-46

*CLAUDE.md — The Long Retreat — June 2026 — Session 4 closeout*
