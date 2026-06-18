# CURRENT_STATE.md — The Long Retreat
*Generated: 2026-06-18 — Session 4 closeout*

---

## Build Info

- **Godot version:** 4.6.2.stable.mono (confirmed booting clean this session)
- **Branch:** `claude/new-session-77fgpr`
- **Renderer:** 2D Forward+
- **Viewport:** 1600×900, non-resizable, canvas_items stretch

---

## Scenes (`res://scenes/`)

| File | Purpose |
|---|---|
| `MainMenu.tscn` | Launch scene — roster display, mission card, DEPLOY button, SKIRMISH/TEST shortcuts |
| `MissionSelectMenu.tscn` | Dev tool — jump to any mission directly, sets test_mode=true |
| `LoadoutScreen.tscn` | Pre-battle pilot/class/weapon/upgrade selection per squad slot |
| `Main.tscn` | Battle arena — spawns ships, camera, planning strip, HUD, minimap, AIController |
| `Ship.tscn` | Shared node for all ships (player + AI + large hulls); runtime stats set by Main |
| `GhostShip.tscn` | Maneuver preview ghost; one per friendly ship, managed by PlanningStrip |
| `PlanningStrip.tscn` | Bottom HUD bar — ShipCard row + CONFIRM ALL button + ManeuverSelector overlay |
| `ShipCard.tscn` | Per-ship card: name, maneuver label, action buttons, formation LOCK button |
| `ManeuverSelector.tscn` | Popup maneuver dial grid, screen-space anchored above the card |
| `HUD.tscn` | Top-right CanvasLayer — round/phase labels + per-ship status bars (RightPanel) |
| `SkirmishSetup.tscn` | Skirmish configuration screen (squad size, enemy count, weapon picks) |

---

## Autoloads (`project.godot` [autoload] section)

| Name | Script | Purpose |
|---|---|---|
| `UIConstants` | `scripts/UIConstants.gd` | Color palette, fonts, sizes, icon atlas helpers |
| `EffectSystem` | `scripts/EffectSystem.gd` | Spawns projectile/explosion/hit VFX nodes |
| `ManeuverSystem` | `scripts/ManeuverSystem.gd` | Arc math, end-state computation, arena bounds, danger zone |
| `RoundManager` | `scripts/RoundManager.gd` | Phase state machine + signals (planning/resolution/action/combat/evaluation/game_ended) |
| `CollisionHandler` | `scripts/CollisionHandler.gd` | HOTAC Swerve collision resolution |
| `CombatSystem` | `scripts/CombatSystem.gd` | Hit probability, simultaneous shot resolution, damage, crits |
| `ActionSystem` | `scripts/ActionSystem.gd` | Focus/Evade/Lock/Boost/Overcharge token resolution |
| `CampaignManager` | `scripts/CampaignManager.gd` | Mission deck, pilot roster, XP, save/load (user://campaign.json) |
| `AudioManager` | `scripts/AudioManager.gd` | Music crossfade, SFX pool (8 players), phase-triggered audio |

---

## Scripts Not Attached to a Scene

| File | Purpose |
|---|---|
| `Ship.gd` | class_name Ship — all ship state, pilot helpers, system helpers |
| `Pilot.gd` | class_name Pilot (Resource) — pilot stats and passive/active ability definitions |
| `Weapon.gd` | class_name Weapon (Resource) — weapon type enum + ammo |
| `Maneuver.gd` | class_name Maneuver (RefCounted) — bearing + speed value object |
| `DialData.gd` | class_name DialData (Resource) — per-ship maneuver color table |
| `ShipClassData.gd` | class_name ShipClassData (Resource) — hull/attack/def stats + sprite scale |
| `ShipClasses.gd` | Static factory: `for_id(id)` → ShipClassData; no .tres files |
| `ShipDials.gd` | Static factory: returns DialData instances; no .tres files |
| `AIStatcard.gd` | Resource, NO class_name (preloaded) — HOTAC 4-step AI statcard data |
| `AIStatcards.gd` | Static factory: `for_class(id)` → AIStatcard |
| `Formation.gd` | RefCounted, NO class_name (preloaded) — player wing-lock (Lead + up to 2 Wings) |
| `Objective.gd` | RefCounted, NO class_name (preloaded) — win/lose condition types |
| `AIController.gd` | Node in Main.tscn (NOT autoload) — HOTAC statcard AI with heuristic fallback |
| `GhostShip.gd` | Attached to GhostShip.tscn — draws maneuver preview |
| `HUD.gd` | Attached to HUD.tscn — updates phase labels, RightPanel ship status bars |
| `Main.gd` | Attached to Main.tscn — battle setup, round orchestration, ship spawning |
| `MainMenu.gd` | Attached to MainMenu.tscn — roster, mission card, UI build |
| `MissionSelectMenu.gd` | Attached to MissionSelectMenu.tscn — test-mode mission jump |
| `LoadoutScreen.gd` | Attached to LoadoutScreen.tscn — loadout selection UI |
| `SkirmishSetup.gd` | Attached to SkirmishSetup.tscn — skirmish configuration |
| `PlanningStrip.gd` | Attached to PlanningStrip.tscn — CONFIRM ALL logic, formation lock, ghost refresh |
| `ShipCard.gd` | Attached to ShipCard.tscn — card setup, action toggles, formation UI, audio |
| `ManeuverSelector.gd` | Attached to ManeuverSelector.tscn — dial grid, stressed button gating |
| `CameraRig.gd` | Camera2D — pan/zoom/focus/frame-all/minimap integration |
| `Minimap.gd` | Minimap panel — ship dots, viewport rect, click-to-jump |
| `TacticalPattern.gd` | OBSOLETE — do not use; superseded by AIStatcard |

---

## UIConstants (verbatim)

```gdscript
# Colors
COLOR_BG_PRIMARY   := Color(0.039, 0.039, 0.059)
COLOR_BG_PANEL     := Color(0.051, 0.067, 0.090)
COLOR_BG_SECONDARY := Color(0.102, 0.102, 0.180)
COLOR_BORDER       := Color(0.176, 0.216, 0.282)
COLOR_INACTIVE     := Color(0.290, 0.333, 0.408)
COLOR_SILVER       := Color(0.627, 0.682, 0.753)
COLOR_WHITE        := Color(1.0, 1.0, 1.0)
COLOR_CYAN         := Color(0.0, 1.0, 1.0)
COLOR_MAGENTA      := Color(1.0, 0.0, 0.502)
COLOR_AMBER        := Color(1.0, 0.722, 0.0)
COLOR_SHIELD       := Color(0.259, 0.600, 0.882)
COLOR_HULL         := Color(0.929, 0.537, 0.212)
COLOR_HULL_CRIT    := Color(0.898, 0.243, 0.243)
COLOR_ION          := Color(0.624, 0.478, 0.918)
COLOR_CRIT         := Color(0.773, 0.188, 0.188)
COLOR_GREEN_DIAL   := Color(0.0, 1.0, 0.533)
COLOR_RED_DIAL     := Color(1.0, 0.267, 0.267)

# Font sizes
SIZE_TITLE   := 28
SIZE_HEADING := 16
SIZE_BODY    := 13
SIZE_LABEL   := 11
SIZE_TINY    := 9

# Layout
PANEL_PAD    := 10
BORDER_W     := 1
BORDER_W_PRI := 2
ICON_SIZE    := Vector2(24, 24)
```

---

## CombatSystem Constants (actual shipped values)

```gdscript
BASE_HIT_CHANCE        = 0.625      # matches CLAUDE.md
BASE_EVADE_CHANCE      = 0.375      # matches CLAUDE.md
SKILL_MOD_PER_POINT    = 0.05       # matches CLAUDE.md
SKILL_MOD_CAP          = 0.20       # matches CLAUDE.md
FOCUS_HIT_BONUS        = 0.15       # matches CLAUDE.md
EVADE_TOKEN_REDUCTION  = 0.15       # matches CLAUDE.md
FOCUS_EVADE_BONUS      = 0.10       # matches CLAUDE.md
HIT_CHANCE_MIN         = 0.05       # matches CLAUDE.md
HIT_CHANCE_MAX         = 0.95       # matches CLAUDE.md
CRIT_CHANCE_BASE       = 0.35       # matches CLAUDE.md
BURST_ATK_RATIO        = 0.6
HEAVY_DAMAGE           = 3
HEAVY_COOLDOWN_TURNS   = 2
CAPITAL_TURRET_DAMAGE  = 2          # matches CLAUDE.md
CAPITAL_TURRET_HULL    = 3          # matches CLAUDE.md
CAPITAL_TURRET_COOLDOWN = 2
FORMATION_RANGE        = 190.0      # matches CLAUDE.md
ION_THRESHOLD_SHIELDS  = 2          # matches CLAUDE.md
ION_THRESHOLD_SYSTEM1  = 4          # matches CLAUDE.md
ION_THRESHOLD_SYSTEM2  = 6          # matches CLAUDE.md
MARKSMAN_BONUS         = 0.08       # matches CLAUDE.md
EVASIVE_BONUS          = 0.08       # matches CLAUDE.md
OVERCHARGE_ATK         = 2
MISSILES_DAMAGE        = 4
TORPEDOES_DAMAGE       = 5
TORPEDOES_AMMO         = 1
SHOT_ANIM_DURATION     = 0.15
```

## ManeuverSystem Constants (actual shipped values — FLAG: RANGE VALUES DIFFER FROM CLAUDE.md)

```gdscript
BASE_SPEED_UNIT        = 80.0       # matches CLAUDE.md
DEFAULT_ARENA_WIDTH    = 1600.0
DEFAULT_ARENA_HEIGHT   = 900.0
MAX_RANGE              = 552.0      # ⚠ CLAUDE.md says RANGE_MAX=500 — code is 552
RANGE_CLOSE            = 182.0      # ⚠ CLAUDE.md says 167 — code is 182
RANGE_MEDIUM           = 369.0      # ⚠ CLAUDE.md says 333 — code is 369
BANK_LATERAL           = 0.4
BANK_FORWARD           = 0.9
TURN_LATERAL           = 0.7
TURN_FORWARD           = 0.7
```

---

## Arena Sizes Per Mission (from CampaignManager.gd mission data)

| Mission | arena_width | arena_height | Notes |
|---|---|---|---|
| T1, T2, T3 | 1600 | 900 | Tutorials — viewport size (no `arena_width` key → default) |
| M1 REARGUARD | 2400 | 1800 | Standard open |
| M2 STRAGGLERS | 2400 | 1800 | Standard open |
| M3 THE NET | 2400 | 1800 | Top edge = ESCAPE |
| M4 ENGINE ADVANCE | advancing map | — | Uses ManeuverSystem danger zone, `arena_width` not set → 1600×900 default |
| M5–M10 | 2400 | 1800 | (standard unless otherwise specified in mission dict) |
| M11, M12 | advancing | — | Advancing maps |

---

## Ship.tscn Sprite Scale

Body Sprite2D: `scale = Vector2(0.2, 0.2)` (fallback; overridden at runtime by `Ship.set_size()`)

Runtime scale source: `ShipClassData.sprite_scale`
- Small ships: `0.2` (default in ShipClassData.gd)
- Large hulls: `0.33` (overridden in ShipClasses.gd large hull block)

Source images are 500×500px → display ~100px at 0.2, ~165px at 0.33.

---

## CameraRig Default Zoom

```gdscript
ZOOM_MIN   = 0.4
ZOOM_MAX   = 1.5
ZOOM_STEP  = 1.1   # multiplicative per scroll notch
FOCUS_ZOOM = 1.0   # zoom level on card-click focus-jump
```
Initial zoom = fit entire arena in viewport (clamped to ZOOM_MIN/ZOOM_MAX).

---

## Gate Completion Status

All gates verified BUILT by clean compile + MainMenu boot + M4 advancing-mission boot.

| Gates | Status | Notes |
|---|---|---|
| 1–5 | BUILT | Movement, round loop, collision, AI, combat probability model |
| 5.5 | BUILT | Squad planning UI (N ships, multi-ghost, confirm all) |
| 6–10 | BUILT | Actions, stress, 5 weapon types, pilot stats, ion system |
| 11–15 | BUILT | Squad AI, formation defence bonus, pilot abilities, campaign layer, capital set-piece |
| 16–20 | BUILT | DialData, 4 player + 3 enemy ship classes, weapon/upgrade slots, LoadoutScreen, Skirmish mode |
| 21–27 | BUILT | Arena-size-as-data, Camera2D pan/zoom, variable maps, minimap, WALL/BLOCK/ESCAPE, 6v6 |
| 28–31 | BUILT | Large hull class — dual arcs, lumbering dial, Hauler + Bulk Cruiser + Convoy Hull |
| 32–35 | BUILT | Critical hit system — 10 effects, 7 weapon tables, TORPEDOES, crit ticks |
| 36–39 | BUILT | HOTAC AIStatcard AI (4-step), HOTAC Swerve collision, STRIKE/FLEE/ESCORT modes |
| 40–41 | BUILT | Mission-deck engine (default OFF/linear), eject roll, KIA hollowing, _elite pilots |
| 42–43 | BUILT | Advancing Map Danger Zone, Forward Wall ESCAPE, AI avoids edge |
| 44–45 | BUILT | Formation Lock (1 Lead + 2 Wings), chain fire in simultaneous volley |
| 46 | BUILT | M4/M11/M12 wired to advancing map; verified boot into M4 |
| Audio | BUILT | AudioManager autoload, 3-track music crossfade, combat SFX, UI SFX (Session 4) |

---

## Known Issues / TODOs Found in Code

| File | Line | Note |
|---|---|---|
| `AudioManager.gd` | 62 | `sfx_missile` → PLACEHOLDER (thrusterFire_000.ogg) |
| `AudioManager.gd` | 63 | `sfx_torpedo` → PLACEHOLDER (spaceEngineLarge_000.ogg) |
| `AudioManager.gd` | 69 | `sfx_kia` → PLACEHOLDER (lowFrequency_explosion_000.ogg) |
| `AudioManager.gd` | 78 | `sfx_win` → PLACEHOLDER (sfx_twoTone.ogg) |
| `Main.gd` | 225 | Comment: "fixed placeholders are freed so squad size isn't capped at two" |

**Warnings on clean open (non-fatal):**
- `WARNING: The constant "DialData" has the same name as a global class defined in "DialData.gd"` — in Ship.gd:4. Pre-existing, harmless.

---

## Demo_assets Usage Map

### Root-level images
| File | Used for |
|---|---|
| `Action Tokens.png` | UIConstants.ICONS_ACTIONS — atlas for focus/evade/lock/boost/overcharge/barrel-roll icons |
| `Ship Status.png` | UIConstants.ICONS_STATUS — atlas for shield/hull/stress/ion/formation/crit-status icons |
| `System Disruption.png` | UIConstants.ICONS_DISRUPTION — atlas for engines/weapons/sensors/shields disabled icons |
| `Crit Effects.png` | UIConstants.ICONS_CRITS — atlas for direct-hit/hull-breach/structural/weapons-fail/engine/fuel-leak icons |
| `Weapon Types.png` | UIConstants.ICONS_WEAPONS — atlas for 7 weapon type icons |
| `tittle.jpg` | MainMenu background key art |
| `Cannon-removebg-preview.png` | Source for `assets/effects/fx_cannon.png` (projectile sprite) |
| `Missile-removebg-preview.png` | Source for `assets/effects/fx_missile.png` (missile sprite) |
| `ship_destroy-removebg-preview.png` | Source for `assets/effects/fx_explosion.png` |
| `ship_Shield_hit-removebg-preview.png` | Source for `assets/effects/fx_shield_hit.png` |
| `ship_Hull_hit-removebg-preview.png` | Source for `assets/effects/fx_hull_hit.png` |
| `FORWARD ARC_PLAYER.png` | Firing arc texture (player ships) |
| `FORWARD ARC_npc.png` | Firing arc texture (enemy ships) |
| `BULLSEYE ZONE.png` | Bullseye arc zone overlay |
| `arc_style_cyan.png.png` | Arc style — player faction |
| `arc_style_magenta.png.png` | Arc style — enemy faction |
| `map_blank.png` | Arena background (blank) |
| `map_nebular.png` | Arena background (nebula variant) |
| `Cannon.png`, `Missile.png` | Original (with background) versions — replaced by -removebg versions |
| `Ship_player.png`, `Ship_enemy_1.png`, etc. | Original ship art (with background) — not used in game |
| `Ship_player-removebg-preview.png`, `Ship_enemy_1-removebg-preview.png` | Background-removed ship art — not yet wired |

### Demo_assets/Audio/ (Kenny space shooter pack)
Used as SFX sources in AudioManager:
- `laserLarge_000.ogg` → `sfx_heavy`
- `impactMetal_000.ogg` → `sfx_hull_hit`
- `explosionCrunch_000.ogg` → `sfx_explosion`
- `lowFrequency_explosion_000.ogg` → `sfx_kia` (PLACEHOLDER)
- `thrusterFire_000.ogg` → `sfx_missile` (PLACEHOLDER)
- `spaceEngineLarge_000.ogg` → `sfx_torpedo` (PLACEHOLDER)

### Demo_assets/Bonus/
- `sfx_laser1.ogg` → `sfx_cannon`
- `sfx_laser2.ogg` → `sfx_burst`
- `sfx_zap.ogg` → `sfx_ion` + `sfx_ion_hit`
- `sfx_shieldDown.ogg` → `sfx_shield_hit`
- `sfx_twoTone.ogg` → `sfx_crit` + `sfx_win` (PLACEHOLDER)
- `sfx_lose.ogg` → `sfx_lose`
- `kenvector_future.ttf`, `kenvector_future_thin.ttf` — not used (using Orbitron/Cinzel)

### Demo_assets/music/
- `Tittle.mp3` → `music_title` (main menu, looping)
- `Menu.mp3` → `music_planning` (planning/evaluation phases, looping)
- `main_battle.mp3` → `music_combat` (battle, plays non-stop from first combat phase until game_ended)

### Demo_assets/uisfx/ (JDSherbert Ultimate UI SFX Pack)
- `Select - 1.wav` → `sfx_click`
- `Cursor - 1.wav` → `sfx_hover`
- `Popup Open - 1.wav` → `sfx_confirm`
- `Cancel - 1.wav` → `sfx_cancel`
- `Swipe - 1.wav` → `sfx_phase`
- `Error - 1.wav` → `sfx_error`
