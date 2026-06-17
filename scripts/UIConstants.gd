extends Node

# ─── Color Palette ───────────────────────────────────────────────────────────
const COLOR_BG_PRIMARY   := Color(0.039, 0.039, 0.059)
const COLOR_BG_PANEL     := Color(0.051, 0.067, 0.090)
const COLOR_BG_SECONDARY := Color(0.102, 0.102, 0.180)
const COLOR_BORDER       := Color(0.176, 0.216, 0.282)
const COLOR_INACTIVE     := Color(0.290, 0.333, 0.408)
const COLOR_SILVER       := Color(0.627, 0.682, 0.753)
const COLOR_WHITE        := Color(1.0, 1.0, 1.0)
const COLOR_CYAN         := Color(0.0, 1.0, 1.0)
const COLOR_MAGENTA      := Color(1.0, 0.0, 0.502)
const COLOR_AMBER        := Color(1.0, 0.722, 0.0)
const COLOR_SHIELD       := Color(0.259, 0.600, 0.882)
const COLOR_HULL         := Color(0.929, 0.537, 0.212)
const COLOR_HULL_CRIT    := Color(0.898, 0.243, 0.243)
const COLOR_ION          := Color(0.624, 0.478, 0.918)
const COLOR_CRIT         := Color(0.773, 0.188, 0.188)
const COLOR_GREEN_DIAL   := Color(0.0, 1.0, 0.533)
const COLOR_RED_DIAL     := Color(1.0, 0.267, 0.267)

# ─── Icon Strip Textures ─────────────────────────────────────────────────────
const ICONS_ACTIONS    := preload("res://Demo_assets/Action Tokens.png")
const ICONS_STATUS     := preload("res://Demo_assets/Ship Status.png")
const ICONS_DISRUPTION := preload("res://Demo_assets/System Disruption.png")
const ICONS_CRITS      := preload("res://Demo_assets/Crit Effects.png")
const ICONS_WEAPONS    := preload("res://Demo_assets/Weapon Types.png")

const ICON_SIZE := Vector2(32, 32)

# ─── AtlasTexture helpers — Action Tokens (2172×724, cell=362) ───────────────
static func icon_focus() -> AtlasTexture:        return _atlas(ICONS_ACTIONS, 0, 362, 724)
static func icon_evade() -> AtlasTexture:        return _atlas(ICONS_ACTIONS, 1, 362, 724)
static func icon_target_lock() -> AtlasTexture:  return _atlas(ICONS_ACTIONS, 2, 362, 724)
static func icon_boost() -> AtlasTexture:        return _atlas(ICONS_ACTIONS, 3, 362, 724)
static func icon_overcharge() -> AtlasTexture:   return _atlas(ICONS_ACTIONS, 4, 362, 724)
static func icon_barrel_roll() -> AtlasTexture:  return _atlas(ICONS_ACTIONS, 5, 362, 724)

# Ship Status (2172×724, cell=362)
static func icon_shields() -> AtlasTexture:      return _atlas(ICONS_STATUS, 0, 362, 724)
static func icon_hull() -> AtlasTexture:         return _atlas(ICONS_STATUS, 1, 362, 724)
static func icon_stress() -> AtlasTexture:       return _atlas(ICONS_STATUS, 2, 362, 724)
static func icon_ion() -> AtlasTexture:          return _atlas(ICONS_STATUS, 3, 362, 724)
static func icon_formation() -> AtlasTexture:    return _atlas(ICONS_STATUS, 4, 362, 724)
static func icon_crit_status() -> AtlasTexture:  return _atlas(ICONS_STATUS, 5, 362, 724)

# System Disruption (1983×793, cell=496)
static func icon_engines_disabled() -> AtlasTexture:   return _atlas(ICONS_DISRUPTION, 0, 496, 793)
static func icon_weapons_disabled() -> AtlasTexture:   return _atlas(ICONS_DISRUPTION, 1, 496, 793)
static func icon_sensors_disabled() -> AtlasTexture:   return _atlas(ICONS_DISRUPTION, 2, 496, 793)
static func icon_shields_disrupted() -> AtlasTexture:  return _atlas(ICONS_DISRUPTION, 3, 496, 793)

# Crit Effects (2172×724, cell=362)
static func icon_direct_hit() -> AtlasTexture:        return _atlas(ICONS_CRITS, 0, 362, 724)
static func icon_hull_breach() -> AtlasTexture:       return _atlas(ICONS_CRITS, 1, 362, 724)
static func icon_structural_damage() -> AtlasTexture: return _atlas(ICONS_CRITS, 2, 362, 724)
static func icon_weapons_failure() -> AtlasTexture:   return _atlas(ICONS_CRITS, 3, 362, 724)
static func icon_damaged_engine() -> AtlasTexture:    return _atlas(ICONS_CRITS, 4, 362, 724)
static func icon_fuel_leak() -> AtlasTexture:         return _atlas(ICONS_CRITS, 5, 362, 724)

# Weapon Types (1915×821, cell=273)
static func icon_cannons() -> AtlasTexture:     return _atlas(ICONS_WEAPONS, 0, 273, 821)
static func icon_burst() -> AtlasTexture:       return _atlas(ICONS_WEAPONS, 1, 273, 821)
static func icon_heavy() -> AtlasTexture:       return _atlas(ICONS_WEAPONS, 2, 273, 821)
static func icon_ion_weapon() -> AtlasTexture:  return _atlas(ICONS_WEAPONS, 3, 273, 821)
static func icon_turret() -> AtlasTexture:      return _atlas(ICONS_WEAPONS, 4, 273, 821)
static func icon_missiles() -> AtlasTexture:    return _atlas(ICONS_WEAPONS, 5, 273, 821)
static func icon_torpedoes() -> AtlasTexture:   return _atlas(ICONS_WEAPONS, 6, 273, 821)


static func _atlas(tex: Texture2D, index: int, cell_w: int, cell_h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(float(index * cell_w), 0.0, float(cell_w), float(cell_h))
	return a
