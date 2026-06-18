# CLAUDE_SESSION_HANDOFF.md
*Created: June 2026 — Session handoff for Claude Code / future AI agents*

> **Purpose:** This document communicates what was done in the most recent
> development session on The Long Retreat. Read this alongside CLAUDE.md
> and CURRENT_STATE.md (which remain the source of truth for the project).
> This file is a **session changelog + context note**, not a design doc.

---

## Session Summary

Branch: `claude/new-session-77fgpr`
Commit: `ed842b8` (pushed to origin)
Files changed: 22 (+907 lines, −34 lines)

### What was built this session

#### 1. Missile Secondary Weapon System
- Missiles are a **secondary weapon**, not a primary weapon replacement
- Ships fire **missiles OR cannons, not both** in the same round
- When the player toggles MSL ON (and has an active lock + ammo), the combat
  system **skips primary weapon fire entirely** and fires missiles instead
- Missile stats: 4 damage, ignores 1 defence die, consumes 1 ammo + the lock
- Ammo: 6 per ship (configurable via `ship.missiles_ammo`)
- Missile sprite scale increased to `0.12` (nearly 3x bigger) for visibility

**Key files:**
- `scripts/CombatSystem.gd` — `_build_missile_shots()`, `firing_missiles` logic in `run_combat()`
- `scripts/Ship.gd` — `fire_missiles`, `missiles_ammo` fields
- `scripts/ShipCard.gd` — `_build_missile_button()`, `_on_missile_toggled()`

#### 2. Target Lock Overhaul
Target lock was redesigned to be **exclusively for launched secondary weapons**
(missiles, torpedoes). Primary cannons no longer use it.

**Changes:**
- **Click-to-lock**: Player selects TARGET_LOCK action → clicks an enemy ship in
  the arena to set the lock target (instead of auto-nearest)
- **Range limit**: Locks only work within `MAX_RANGE` (552px). Out-of-range
  clicks show a hint and play an error sound
- **Takes a full round**: Lock acquired this round → activates next round
  - `pending_lock_target` set during planning → becomes `target_lock` in ACTION phase
  - If pending target is destroyed/out of range before action phase, it clears cleanly
- **No cannon bonus**: Removed the `target_lock == defender` hit-chance reroll
  from `calculate_hit_chance()`. Cannons don't consume the lock either.
- **Lock consumption**: Only missile/torpedo engagements set `used_lock = true`,
  which clears the lock after combat resolution

**Key files:**
- `scripts/ActionSystem.gd` — pending→active lock promotion logic
- `scripts/CombatSystem.gd` — removed lock bonus, lock consumption rules
- `scripts/PlanningStrip.gd` — `_handle_target_click()`, targeting mode via `_input()`
- `scripts/Ship.gd` — `pending_lock_target` field
- `scripts/ShipCard.gd` — `targeting_started` signal, missile button disabled state

#### 3. Lock Visuals (Main.gd `_draw()`)
- **Active lock**: Thick red line (4px, 70% alpha) + large red X (22px arms, 3.5px, 95% alpha)
- **Pending lock** (acquiring this round): Amber line (2.5px, 45% alpha) + amber X (18px arms, 2px, 65% alpha)
- Drawn every frame in `Main._draw()` via `queue_redraw()`

#### 4. UI Polish
- **Action buttons** (FOCUS, LOCK, EVADE, BOOST, ABILITY): Highlight **cyan** with
  border + tinted background when selected (pressed StyleBoxFlat override)
- **Maneuver menu**: Selected maneuver highlights cyan (border + background + font color)
- **Hover tooltips** on ALL ship card icons/buttons:
  - Token row: Focus, Evade, Target Lock, Overcharge, Formation
  - Action buttons: Focus, Lock, Evade, Boost, Ability
  - Missile toggle, Formation LOCK button
  - Crit icons: Direct Hit, Hull Breach, Structural Damage, Weapons Failure, Damaged Engine, Fuel Leak
  - System disruption icons: Engines/Weapons/Sensors/Shields disabled
- **Target-lock token badge**: Small launcher-style tile (dark amber background +
  missile icon) overlaid on the lock token, with "Launcher lock" tooltip
- **Missile button**: Separate ammo counter label (bold amber number) beside the MSL button
- **Missile button disabled state**: 55% opacity when no active lock or no ammo
- **Range hints**: PlanningStrip shows temporary hint labels:
  - "Click an enemy within 552px to queue a lock" (on targeting start)
  - "Lock queued — activates next round" (on successful click)
  - "Target out of range — locks work within 552px" (on failed click)
- **Token state colors**: Target-lock token shows red when active, amber when pending,
  dim when inactive

#### 5. Demo Slice
- **DemoSlice → Title → Loadout → Battle** loop for rapid playtesting
- `DemoBattle.tscn` wraps `Main.tscn` as a Node2D; `test_mode` bypasses campaign
- Demo loadout uses fixed defaults (no loadout screen choices needed)
- `DemoConfig.gd` holds demo weapon/ammo defaults

**Key files:**
- `scripts/DemoSlice.gd`, `scripts/DemoTitleScreen.gd`, `scripts/DemoLoadout.gd`
- `scripts/DemoBattle.gd`, `scripts/DemoConfig.gd`
- `scenes/DemoSlice.tscn`, `scenes/DemoTitleScreen.tscn`, `scenes/DemoLoadout.tscn`, `scenes/DemoBattle.tscn`

#### 6. AI Fixes (from earlier in session)
- HOTAC statcard activation working
- Bounds-aware filtering (AI doesn't fly off-map)
- Stress-clearing behavior
- `K_TURN` added to `enemy_fighter` dial in `ShipDials.gd`

#### 7. Off-Map Grace Counter
- Ships no longer die instantly on WALL edge contact
- They get a **3-round grace window** via a counter before destruction
- Recovery back in bounds resets the counter
- Logic in `RoundManager.gd` (evaluation phase) + `Ship.gd` (counter state)

#### 8. Bugfixes
- `EffectSystem.gd` line 48: fixed space-before-tab indentation (pre-existing)
- `ActionSystem.gd`: invalid pending lock now clears cleanly if target destroyed
  or moved out of range before the action phase

---

## Current Architecture Notes for Claude Code

### How targeting works (round flow)
```
PLANNING:
  1. Player selects TARGET_LOCK action on ship card
  2. ShipCard emits `targeting_started` signal → PlanningStrip enters targeting mode
  3. Player clicks an enemy ship in the arena
  4. PlanningStrip._handle_target_click() validates range (≤552px)
  5. If valid: ship.pending_lock_target = clicked_enemy
  6. Player can toggle MSL button ON (but it's disabled until lock is ACTIVE)

ACTION PHASE (ActionSystem):
  7. If pending_lock_target is valid → ship.target_lock = pending_lock_target
  8. pending_lock_target cleared

COMBAT PHASE (CombatSystem):
  9. If ship.fire_missiles AND ship.target_lock == target AND ammo > 0:
     → Fire missiles (skip primary weapon entirely)
     → used_lock = true → lock consumed after combat
  10. Otherwise: fire primary weapon (cannons), lock NOT consumed
```

### Important: `used_lock` semantics
- Primary weapon engagements: `used_lock = false` (lock survives)
- Missile engagements: `used_lock = true` (lock consumed after combat)
- This means a lock can persist across rounds if you don't fire missiles

### Missile button enable/disable logic
```gdscript
_missile_btn.disabled = ship.missiles_ammo <= 0 or ship.target_lock == null
```
The button is only enabled when there's an **active** lock (not pending). This
enforces the "lock takes a round" rule — you can't fire missiles the same round
you acquire the lock.

### Files modified this session (all committed)
```
M  project.godot
M  scripts/AIController.gd
M  scripts/ActionSystem.gd
M  scripts/AudioManager.gd
M  scripts/CombatSystem.gd
M  scripts/EffectSystem.gd
M  scripts/Main.gd
M  scripts/ManeuverSelector.gd
M  scripts/PlanningStrip.gd
M  scripts/RoundManager.gd
M  scripts/Ship.gd
M  scripts/ShipCard.gd
M  scripts/ShipDials.gd
A  scenes/DemoBattle.tscn
A  scenes/DemoLoadout.tscn
A  scenes/DemoSlice.tscn
A  scenes/DemoTitleScreen.tscn
A  scripts/DemoBattle.gd
A  scripts/DemoConfig.gd
A  scripts/DemoLoadout.gd
A  scripts/DemoSlice.gd
A  scripts/DemoTitleScreen.gd
```

### How to test
1. Launch Godot with the project
2. Run `DemoBattle.tscn` (or `DemoSlice.tscn` for full demo flow)
3. In battle: pick a maneuver (highlights cyan) → select TARGET_LOCK → click an enemy
   → you should see amber pending X/line → next round it turns red → toggle MSL ON
   → CONFIRM ALL → missiles fire instead of cannons

### Known placeholders / TODOs
- `sfx_missile` and `sfx_torpedo` are placeholder audio files
- `sfx_kia` and `sfx_win` are placeholder audio files
- Advancing map missions (M4/M11/M12) still use 1600×900 instead of corridor archetype
- TORPEDOES weapon type exists in CombatSystem but no UI toggle button yet (only missiles have a toggle)

---

## What NOT to do
- Do NOT add target lock bonuses to primary cannons — it's for launched weapons only
- Do NOT let missiles and cannons fire in the same round — one or the other
- Do NOT skip the pending→active lock delay — locks take a full round to acquire
- Do NOT modify the demo routing isolation (DemoConfig / DemoBattle) unless asked
- Do NOT remove the `ships` group from Ship._ready() — PlanningStrip relies on it for click targeting

---

*End of handoff. For full project spec, see CLAUDE.md and CURRENT_STATE.md.*
