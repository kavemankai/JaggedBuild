# DemoBattle.gd
# Demo battle controller. It does NOT reimplement the battle — it drives the
# existing, UNMODIFIED Main.tscn by configuring CampaignManager for an isolated
# skirmish, then instantiates Main as a child. Main.gd spawns ships exactly as it
# always does; DemoBattle only:
#   1. pushes the player's chosen class/weapon onto the in-memory roster entry
#      (test_mode=true => record_battle returns early, save() is never called, so
#       the persistent roster / campaign save is never touched),
#   2. bumps the arena to the largest defined size (2400x1800) and lays the ships
#      out left/right (spawn configuration only),
#   3. holds combat music for the whole battle (AudioManager.demo_mode),
#   4. loops back to the title on game_ended.
#
# No Main / CampaignManager / combat / AI code is modified by this scene.
extends Node2D

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

# Largest arena currently defined in the codebase (standard open missions).
const ARENA_W: float = 2400.0
const ARENA_H: float = 1800.0

# Forward at rotation 0 = up (0,-1) in this project; facing right = +PI/2, left = -PI/2.
const FACE_RIGHT: float = PI * 0.5
const FACE_LEFT: float = -PI * 0.5

var _main: Node = null
var _battle_over: bool = false


func _ready() -> void:
	# --- Demo audio: combat music from the start, suppress phase crossfades. ---
	AudioManager.demo_mode = true
	AudioManager.play_music("music_combat", 0.5)

	# --- Isolated skirmish: test_mode skips XP / Distance / injury / hollowing / save. ---
	CampaignManager.test_mode = true
	CampaignManager.skirmish_mode = true
	CampaignManager.squad_size = 1
	CampaignManager.selected_deployment = ["WARDEN"]
	CampaignManager.skirmish_enemies = _demo_enemies()

	# Push the player's chosen class/weapon onto the in-memory WARDEN entry so
	# Main._deploy_player_team() (which reads pilots_for_deployment() -> roster)
	# spawns exactly the demo ship. Never persisted (test_mode => no save).
	_override_player_roster_entry()

	# --- Spawn the battle via the existing Main.tscn (unmodified). ---
	_main = MAIN_SCENE.instantiate()
	add_child(_main)  # Main._ready runs here: spawns 1 player + 2 enemies on 1600x900.

	# --- Reconfigure to demo spec: 2400x1800 arena + left/right layout. ---
	_reconfigure_arena(Vector2(ARENA_W, ARENA_H))
	_reposition_ships()
	_set_missile_ammo()

	# --- Loop back to the title when the battle resolves. ---
	RoundManager.game_ended.connect(_on_game_ended)


# ---- player config -----------------------------------------------------------

func _override_player_roster_entry() -> void:
	var entry: Dictionary = _warden_entry()
	entry["name"] = DemoConfig.pilot_name
	entry["skill"] = DemoConfig.pilot_skill
	entry["base_skill"] = DemoConfig.pilot_skill
	entry["passive"] = "MARKSMAN"
	entry["active"] = "OVERCHARGE"
	entry["ship_class"] = DemoConfig.player_class_id
	entry["weapon"] = _weapon_name(DemoConfig.player_weapon)


func _warden_entry() -> Dictionary:
	for e in CampaignManager.roster:
		if e is Dictionary and e.get("name", "") == "WARDEN":
			return e
	# Fallback: first roster slot (still transient, never saved).
	return CampaignManager.roster[0]


# Two lowest-skill enemy fighters with stock stats (Enemy Fighter: 2/2/2/3).
func _demo_enemies() -> Array:
	var base := {
		"skill": 1, "passive": "", "active": "", "weapon": "CANNONS",
		"attack": 2, "defence": 2, "shields": 2, "hull": 3,
		"accuracy": 1.0, "agility": 1.1, "nerve": 0.1,
		"ship_class": "enemy_fighter", "xp": 0, "kills": 0,
		"status": "healthy", "upgrade": "",
	}
	var e1 := base.duplicate()
	e1["name"] = "BANDIT-1"
	e1["accent"] = [0.4, 0.3, 0.45]
	var e2 := base.duplicate()
	e2["name"] = "BANDIT-2"
	e2["accent"] = [0.4, 0.3, 0.45]
	return [e1, e2]


# Weapon.Type enum value -> the string key _apply_spec() matches on.
func _weapon_name(wtype: int) -> String:
	match wtype:
		1: return "BURST"
		2: return "HEAVY"
		3: return "MISSILES"
		4: return "ION"
		5: return "TURRET"
		6: return "TORPEDOES"
		_: return "CANNONS"


# ---- arena + layout reconfigure (spawn configuration only) -------------------

func _reconfigure_arena(size: Vector2) -> void:
	ManeuverSystem.set_arena(size)
	# The arena backdrop ColorRect was sized to the default 1600x900 in Main._ready.
	var arena_rect := _main.get_node_or_null("Arena")
	if arena_rect is ColorRect:
		(arena_rect as ColorRect).size = size
	# Re-fit the world camera to the larger arena.
	var cam := _find_camera()
	if cam != null and cam.has_method("setup"):
		cam.setup(size)
	# Keep the minimap internal scale in sync (avoid double-connecting signals).
	for c in _main.get_node("UI").get_children():
		if c.get("arena") != null:
			c.arena = size
			break


func _find_camera() -> Node:
	for c in _main.get_children():
		if c is Camera2D:
			return c
	return null


func _reposition_ships() -> void:
	var ships_node := _main.get_node_or_null("Ships")
	if ships_node == null:
		return
	# Player on the LEFT, vertically centred, facing right.
	for c in ships_node.get_children():
		var s := c
		if s is Ship and s.team == "PLAYER" and s.is_targetable:
			s.global_position = Vector2(ARENA_W * 0.15, ARENA_H * 0.5)
			s.rotation = FACE_RIGHT
	# Enemies on the RIGHT, facing the player.
	var ei: int = 0
	for c in ships_node.get_children():
		var s := c
		if s is Ship and s.team == "ENEMY":
			var y: float = ARENA_H * (0.40 if ei == 0 else 0.60)
			s.global_position = Vector2(ARENA_W * 0.85, y)
			s.rotation = FACE_LEFT
			ei += 1


# Give the player ship its demo missile count (default 2 is too few; DemoConfig
# bumps it so the player can use missiles throughout the engagement).
func _set_missile_ammo() -> void:
	var ships_node := _main.get_node_or_null("Ships")
	if ships_node == null:
		return
	for c in ships_node.get_children():
		# Skip the scene placeholders Main frees via queue_free() — they're still in
		# the tree during _ready but are about to be deleted.
		if c is Ship and not c.is_queued_for_deletion() and (c as Ship).team == "PLAYER":
			(c as Ship).missiles_ammo = DemoConfig.missiles_ammo
			break


# ---- battle end --------------------------------------------------------------

func _on_game_ended(_message: String, _color: Color, _won: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	# Stop Main.gd from routing the post-battle keypress to the menu dev-tool.
	if _main != null:
		_main.set_process_input(false)
	# Music fade-out is handled by AudioManager._on_game_ended; release the demo guard
	# so future non-demo play is unaffected.
	AudioManager.demo_mode = false
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/DemoTitleScreen.tscn")
