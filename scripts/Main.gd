extends Node2D

const SHIP_SCENE: PackedScene = preload("res://scenes/Ship.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/GhostShip.tscn")
const AI_TEXTURE: Texture2D = preload("res://assets/ships/ship_ai.png")
const ShipDials := preload("res://scripts/ShipDials.gd")
const ShipClasses := preload("res://scripts/ShipClasses.gd")
const Objective := preload("res://scripts/Objective.gd")
const CameraRig := preload("res://scripts/CameraRig.gd")

@onready var player_ship: Ship = $Ships/PlayerShip
@onready var wing_ship: Ship = $Ships/WingShip
@onready var ships_root: Node2D = $Ships
@onready var ghosts_root: Node2D = $Ghosts
@onready var planning_strip: Control = $UI/PlanningStrip
@onready var ai_controller: Node = $AIController
@onready var hud: CanvasLayer = $HUD

var _game_over: bool = false
var _ships: Array = []
var _player_ships: Array = []
var _enemy_ships: Array = []
var _protected_ship: Ship = null
var _ghosts: Dictionary = {}
var _objective: Objective = null
var _camera: Camera2D = null

const SPAWN_SPACING: float = 180.0      # horizontal gap between ships in a spawn line

# Spawn positions are computed per-battle, scaled to the live arena (or from mission
# overrides). Players spawn near the bottom facing up, enemies near the top facing down,
# the transport at top-centre. Each entry is [Vector2 pos, float rotation].
var _player_spawns: Array = []
var _enemy_spawns: Array = []
var _transport_spawn: Array = [Vector2(800, 160), PI]

# Per-ship ghost opacities so overlapping friendly paths stay distinguishable (up to 6).
const GHOST_ARC_ALPHAS: Array = [0.9, 0.6, 0.45, 0.4, 0.35, 0.3]
const GHOST_BODY_ALPHAS: Array = [0.45, 0.4, 0.35, 0.32, 0.3, 0.28]


func _ready() -> void:
	var mission: Dictionary
	var enemy_specs: Array
	_objective = Objective.new()
	if CampaignManager.skirmish_mode:
		mission = {"name": "SKIRMISH", "enemies": CampaignManager.skirmish_enemies}
		enemy_specs = CampaignManager.skirmish_enemies
		# default DESTROY_ALL
	else:
		mission = CampaignManager.current_mission()
		enemy_specs = CampaignManager.current_enemies()
		_objective.configure(mission.get("objective", {}))

	# Arena dimensions are per-mission data (defaults to 1600x900). Set every battle so
	# a large-map mission's size never leaks into the next.
	var aw: float = float(mission.get("arena_width", ManeuverSystem.DEFAULT_ARENA_WIDTH))
	var ah: float = float(mission.get("arena_height", ManeuverSystem.DEFAULT_ARENA_HEIGHT))
	ManeuverSystem.set_arena(Vector2(aw, ah))

	# Background spans the whole arena (not just the legacy 1600x900 screen).
	var arena_rect: ColorRect = $Arena
	arena_rect.size = ManeuverSystem.arena_size

	_make_spawns(mission, enemy_specs)

	# World camera — pan/zoom over the (possibly larger-than-screen) arena.
	_camera = CameraRig.new()
	add_child(_camera)
	_camera.setup(ManeuverSystem.arena_size)

	_player_ships = _deploy_player_team()
	_enemy_ships = _deploy_enemies(enemy_specs)

	# Protected transport (PROTECT missions): a friendly non-controlled ship to defend.
	var protected_spec: Dictionary = mission.get("protected", {})
	if not protected_spec.is_empty():
		_protected_ship = _deploy_transport(protected_spec)
		_objective.protected_ship = _protected_ship

	_ships = _player_ships + _enemy_ships
	if _protected_ship != null:
		_ships.append(_protected_ship)

	_build_ghosts()

	planning_strip.setup(_player_ships, _ghosts)
	planning_strip.set_camera(_camera)
	_build_frame_button()
	planning_strip.all_confirmed.connect(_on_all_confirmed)

	# HUD lists combatants only — the capital hull is non-targetable scenery.
	var hud_ships: Array = _ships.filter(func(s): return (s as Ship).is_targetable)
	hud.setup_ships(hud_ships)
	hud.set_mission_label(mission.get("name", ""))
	hud.set_objective(_objective)

	RoundManager.register_ships(_ships)
	RoundManager.set_objective(_objective)
	RoundManager.planning_phase_started.connect(_on_planning_started)
	RoundManager.resolution_phase_started.connect(_on_resolution_started)
	RoundManager.game_ended.connect(_on_game_ended)
	RoundManager.begin_round()


# Build spawn positions for this battle, scaled to the arena. Mission data may override
# with explicit "player_spawns"/"enemy_spawns"/"transport_spawn" ([x, y, rot] entries).
# A screen-space "FRAME ALL" button (top-centre) that fits every living ship in view —
# offered, never imposed (the camera stays free otherwise).
func _build_frame_button() -> void:
	var btn := Button.new()
	btn.text = "FRAME ALL"
	btn.add_theme_font_size_override("font_size", 13)
	btn.position = Vector2(720, 12)
	btn.custom_minimum_size = Vector2(160, 30)
	btn.focus_mode = Control.FOCUS_NONE   # don't steal keyboard focus
	btn.pressed.connect(_on_frame_all)
	$UI.add_child(btn)


func _on_frame_all() -> void:
	if _camera == null:
		return
	var pts: Array = []
	for s in _ships:
		var sh: Ship = s as Ship
		if not sh.is_destroyed:
			pts.append(sh.global_position)
	_camera.frame_all(pts)


func _make_spawns(mission: Dictionary, enemy_specs: Array) -> void:
	var arena: Vector2 = ManeuverSystem.arena_size
	var player_count: int = mini(2, CampaignManager.pilots_for_deployment().size())
	var enemy_count: int = 0
	for spec in enemy_specs:
		if not spec.get("is_capital_body", false) and not spec.get("is_turret", false):
			enemy_count += 1

	_player_spawns = _override_spawns(mission.get("player_spawns", []))
	if _player_spawns.is_empty():
		_player_spawns = _line_spawns(maxi(1, player_count), arena.y * 0.80, 0.0, arena)

	_enemy_spawns = _override_spawns(mission.get("enemy_spawns", []))
	if _enemy_spawns.is_empty():
		_enemy_spawns = _line_spawns(maxi(1, enemy_count), arena.y * 0.22, PI, arena)

	var t: Array = _override_spawns(mission.get("transport_spawn", []))
	_transport_spawn = t[0] if not t.is_empty() else [Vector2(arena.x * 0.5, arena.y * 0.12), PI]


# A centred horizontal line of `count` spawns at world-y `y`, facing `rot`.
func _line_spawns(count: int, y: float, rot: float, arena: Vector2) -> Array:
	var out: Array = []
	var total: float = float(count - 1) * SPAWN_SPACING
	var start_x: float = arena.x * 0.5 - total * 0.5
	for i in range(count):
		var x: float = clampf(start_x + float(i) * SPAWN_SPACING, 120.0, arena.x - 120.0)
		out.append([Vector2(x, y), rot])
	return out


# Convert mission-data [x, y, rot] arrays into [Vector2, rot] spawn entries.
func _override_spawns(raw: Array) -> Array:
	var out: Array = []
	for e in raw:
		var arr: Array = e as Array
		out.append([Vector2(float(arr[0]), float(arr[1])), float(arr[2]) if arr.size() > 2 else 0.0])
	return out


func _deploy_player_team() -> Array:
	var pilots: Array = CampaignManager.pilots_for_deployment()
	var slots: Array = [player_ship, wing_ship]
	var deployed: Array = []

	for i in range(slots.size()):
		var ship: Ship = slots[i]
		if i < pilots.size():
			ship.team = "PLAYER"
			ship.speed_options = [1, 2, 3, 4]
			ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
			_apply_spec(ship, pilots[i], true)  # skip passives until after class stats
			var cls = ShipClasses.for_id(pilots[i].get("ship_class", "fighter"))
			ship.dial_data = cls.dial
			ship.attack = cls.attack
			ship.defence = cls.defence
			ship.shields = cls.shields
			ship.hull = cls.hull
			ship.firing_arc_degrees = cls.firing_arc_degrees
			ship.rebuild_arc()
			ship.apply_setup_passives()
			var spawn: Array = _player_spawns[i] if i < _player_spawns.size() else [Vector2(800, 650), 0.0]
			ship.position = spawn[0]
			ship.rotation = spawn[1]
			deployed.append(ship)
		else:
			ship.queue_free()

	return deployed


func _deploy_enemies(specs: Array) -> Array:
	var enemies: Array = []
	var capital_body: Ship = null
	var slot_i: int = 0

	for spec in specs:
		var ship: Ship = SHIP_SCENE.instantiate()
		ship.ship_texture = AI_TEXTURE
		ship.team = "ENEMY"

		if spec.get("is_capital_body", false):
			ships_root.add_child(ship)
			ship.speed_options = []
			ship.bearing_options = []
			_apply_spec(ship, spec)
			ship.make_capital()
			ship.position = Vector2(0, 0)
			ship.rotation = 0.0
			capital_body = ship

		elif spec.get("is_turret", false):
			# Mount on the capital hull so turrets move with it. Turrets never manoeuvre.
			if capital_body != null:
				capital_body.add_child(ship)
			else:
				ships_root.add_child(ship)
			ship.speed_options = []
			ship.bearing_options = []
			_apply_spec(ship, spec)
			ship.make_turret()
			if capital_body != null:
				ship.position = Vector2(float(spec.get("x_offset", 0.0)), 40.0)
			else:
				ship.position = Vector2(ManeuverSystem.arena_size.x * 0.5 + float(spec.get("x_offset", 0.0)), 220.0)
			ship.rotation = PI

		else:
			ships_root.add_child(ship)
			ship.speed_options = [1, 2, 3]
			ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT"]
			_apply_spec(ship, spec)
			ship.dial_data = _dial_for_class(spec.get("ship_class", "enemy_fighter"))
			var slot: Array = _enemy_spawns[slot_i % _enemy_spawns.size()] if not _enemy_spawns.is_empty() else [Vector2(800, 250), PI]
			slot_i += 1
			ship.position = slot[0]
			ship.rotation = slot[1]

		enemies.append(ship)
	return enemies


# A friendly, non-controlled transport the player must keep alive (PROTECT missions).
# It sits at the top of the arena and never manoeuvres; enemies converge on it.
func _deploy_transport(spec: Dictionary) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.ship_texture = AI_TEXTURE
	ship.team = "PLAYER"
	ships_root.add_child(ship)
	ship.speed_options = []
	ship.bearing_options = []
	_apply_spec(ship, spec)   # keeps the spec's tanky transport stats (no class override)
	ship.dial_data = null     # never planned, never manoeuvres
	ship.position = _transport_spawn[0]
	ship.rotation = _transport_spawn[1]
	return ship


func _build_ghosts() -> void:
	for i in range(_player_ships.size()):
		var ship: Ship = _player_ships[i]
		var ghost := GHOST_SCENE.instantiate()
		ghosts_root.add_child(ghost)
		ghost.base_arc_alpha = GHOST_ARC_ALPHAS[i % GHOST_ARC_ALPHAS.size()]
		ghost.base_body_alpha = GHOST_BODY_ALPHAS[i % GHOST_BODY_ALPHAS.size()]
		ghost.clear_preview()
		_ghosts[ship] = ghost


func _apply_spec(ship: Ship, spec: Dictionary, skip_passives: bool = false) -> void:
	var p := Pilot.new()
	p.pilot_name = spec.get("name", "?")
	p.skill = int(spec.get("skill", 3))
	p.accuracy = float(spec.get("accuracy", 1.0))
	p.agility = float(spec.get("agility", 1.0))
	p.nerve = float(spec.get("nerve", 0.0))
	p.passive = spec.get("passive", "")
	p.active_ability = spec.get("active", "")
	p.xp = int(spec.get("xp", 0))
	p.status = spec.get("status", "healthy")
	ship.pilot = p

	ship.attack = int(spec.get("attack", 3))
	ship.defence = int(spec.get("defence", 2))
	ship.shields = int(spec.get("shields", 2))
	ship.hull = int(spec.get("hull", 3))
	ship.upgrade = spec.get("upgrade", "")

	var w := Weapon.new()
	w.weapon_type = _weapon_type(spec.get("weapon", "CANNONS"))
	w.display_name = spec.get("weapon", "Cannons").capitalize()
	ship.weapon = w

	if spec.has("accent"):
		var a: Array = spec["accent"]
		ship.accent_color = Color(a[0], a[1], a[2], 1.0)

	if not skip_passives:
		ship.apply_setup_passives()


func _dial_for_class(class_id: String):
	match class_id:
		"enemy_scout":   return ShipDials.enemy_scout()
		"enemy_assault": return ShipDials.enemy_assault()
		_:               return ShipDials.enemy_fighter()


func _weapon_type(weapon_name: String) -> Weapon.Type:
	match weapon_name:
		"BURST": return Weapon.Type.BURST
		"HEAVY": return Weapon.Type.HEAVY
		"ION": return Weapon.Type.ION
		"MISSILES": return Weapon.Type.MISSILES
		"TURRET": return Weapon.Type.TURRET
		_: return Weapon.Type.CANNONS


func _on_planning_started() -> void:
	planning_strip.visible = true
	planning_strip.reset()

	# Player controls all friendly ships; the AI plans only enemy ships, spreading
	# out from each other's chosen end positions.
	var avoid_points: Array = []
	for s in _enemy_ships:
		var ship: Ship = s as Ship
		if ship.is_destroyed:
			continue
		# Capital hull is scenery; turrets are fixed emplacements — neither manoeuvres.
		if not ship.is_targetable or ship.bearing_options.is_empty():
			ship.selected_action = ai_controller.select_action(ship, _ships)
			continue
		var m: Maneuver = ai_controller.select_maneuver(ship, _ships, avoid_points)
		ship.selected_maneuver = m
		ship.selected_action = ai_controller.select_action(ship, _ships)
		if m != null:
			var es := ManeuverSystem.compute_end_state(ship.global_position, ship.rotation, m)
			avoid_points.append(es["position"])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i in range(_ships.size()):
		for j in range(i + 1, _ships.size()):
			var a: Ship = _ships[i] as Ship
			var b: Ship = _ships[j] as Ship
			if a.is_destroyed or b.is_destroyed or a.team != b.team:
				continue
			if a.global_position.distance_to(b.global_position) <= CombatSystem.FORMATION_RANGE:
				draw_line(a.global_position, b.global_position, Color(0.3, 0.8, 1.0, 0.22), 2.0)


func _on_resolution_started() -> void:
	planning_strip.visible = false


func _on_all_confirmed() -> void:
	RoundManager.resolve_maneuvers()


func _on_game_ended(message: String, color: Color, won: bool) -> void:
	_game_over = true
	CampaignManager.record_battle(_player_ships, won)
	hud.show_result(message, color, CampaignManager.last_summary)


func _input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and not event.echo:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
