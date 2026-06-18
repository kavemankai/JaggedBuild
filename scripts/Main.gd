extends Node2D

const SHIP_SCENE: PackedScene = preload("res://scenes/Ship.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/GhostShip.tscn")

# Per-class sprites — player (all classes share the new painted sprite)
const TEX_FIGHTER:     Texture2D = preload("res://assets/ships/ship_player_fighter.png")
const TEX_HEAVY:       Texture2D = preload("res://assets/ships/ship_player_fighter.png")
const TEX_INTERCEPTOR: Texture2D = preload("res://assets/ships/ship_player_fighter.png")
const TEX_GUNSHIP:     Texture2D = preload("res://assets/ships/ship_player_fighter.png")
const TEX_HAULER:      Texture2D = preload("res://assets/ships/ship_player_fighter.png")
# Per-class sprites — enemy (all classes share the new painted sprite)
const TEX_AI_FIGHTER:  Texture2D = preload("res://assets/ships/ship_enemy_fighter.png")
const TEX_AI_SCOUT:    Texture2D = preload("res://assets/ships/ship_enemy_fighter.png")
const TEX_AI_ASSAULT:  Texture2D = preload("res://assets/ships/ship_enemy_fighter.png")
const TEX_AI_LARGE:    Texture2D = preload("res://assets/ships/ship_enemy_fighter.png")
const ShipDials := preload("res://scripts/ShipDials.gd")
const ShipClasses := preload("res://scripts/ShipClasses.gd")
const Objective := preload("res://scripts/Objective.gd")
const CameraRig := preload("res://scripts/CameraRig.gd")
const Minimap := preload("res://scripts/Minimap.gd")

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
		CampaignManager.squad_size = int(mission.get("squad_size", 2))

	# Arena dimensions are per-mission data (defaults to 1600x900). Set every battle so
	# a large-map mission's size never leaks into the next.
	var aw: float = float(mission.get("arena_width", ManeuverSystem.DEFAULT_ARENA_WIDTH))
	var ah: float = float(mission.get("arena_height", ManeuverSystem.DEFAULT_ARENA_HEIGHT))
	ManeuverSystem.set_arena(Vector2(aw, ah))
	ManeuverSystem.set_edges(mission.get("edges", {}))

	# Advancing Map (Gate 42-43): a Danger Zone sweeps forward each round. The Threshing
	# Engine's leading edge — fall behind it and you're caught. Mission data drives it.
	if mission.get("advancing", false):
		var axis_arr: Array = mission.get("scroll_axis", [0.0, -1.0])
		var axis: Vector2 = Vector2(float(axis_arr[0]), float(axis_arr[1]))
		var speed: float = float(mission.get("scroll_speed_px", 60.0))
		ManeuverSystem.configure_danger(true, axis, speed)

	_add_background()

	# Background spans the whole arena (not just the legacy 1600x900 screen).
	var arena_rect: ColorRect = $Arena
	arena_rect.size = ManeuverSystem.arena_size
	arena_rect.color = Color(0.04, 0.04, 0.12, 0.7)

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
	_build_minimap()
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


# Corner minimap (bottom-right, above the planning strip). Screen-space on $UI.
func _build_minimap() -> void:
	var map := Minimap.new()
	map.size = Vector2(260, 150)
	map.position = Vector2(1600 - 260 - 16, 900 - 150 - 212)
	$UI.add_child(map)
	map.setup(_ships, _camera, _objective, ManeuverSystem.arena_size)


func _add_background() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	bg_layer.name = "Background"
	add_child(bg_layer)
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/map_nebular.png")
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)


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
	# Player ships are spawned dynamically (1 per pilot, up to 6) — the scene's two
	# fixed placeholders are freed so squad size isn't capped at two.
	player_ship.queue_free()
	wing_ship.queue_free()

	var deployed: Array = []
	for i in range(pilots.size()):
		var class_id: String = pilots[i].get("ship_class", "fighter")
		var ship: Ship = SHIP_SCENE.instantiate()
		ship.ship_texture = _player_texture(class_id)
		ship.team = "PLAYER"
		ships_root.add_child(ship)
		ship.speed_options = [1, 2, 3, 4]
		ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
		_apply_spec(ship, pilots[i], true)  # skip passives until after class stats
		var cls = ShipClasses.for_id(class_id)
		ship.dial_data = cls.dial
		ship.attack = cls.attack
		ship.defence = cls.defence
		ship.shields = cls.shields
		ship.hull = cls.hull
		ship.firing_arc_degrees = cls.firing_arc_degrees
		_apply_size_class(ship, cls)
		ship.rebuild_arc()
		ship.apply_setup_passives()
		var spawn: Array = _player_spawns[i] if i < _player_spawns.size() else [Vector2(800, 650), 0.0]
		ship.position = spawn[0]
		ship.rotation = spawn[1]
		deployed.append(ship)

	return deployed


# Apply a ShipClassData's size/rear-turret/objective traits to a live ship.
func _apply_size_class(ship: Ship, cls) -> void:
	ship.set_size(cls.sprite_scale, cls.collision_radius)
	ship.rear_arc_degrees = cls.turret_arc_degrees
	ship.has_rear_turret = cls.has_rear_turret
	ship.is_objective = cls.is_objective
	ship.setup_rear_arc()


func _deploy_enemies(specs: Array) -> Array:
	var enemies: Array = []
	var capital_body: Ship = null
	var slot_i: int = 0

	for spec in specs:
		var ship: Ship = SHIP_SCENE.instantiate()
		ship.ship_texture = _enemy_texture(spec)
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
			# Wire the designed HOTAC statcard AI (Gates 36-39) onto this ship so
			# AIController._statcard_for() resolves it instead of falling back to the
			# tail-holding heuristic scorer. The class id maps 1:1 to an AIStatcard.
			ship.set_meta("statcard_class", spec.get("ship_class", "enemy_fighter"))
			# Large enemies (Bulk Cruiser): bigger footprint + rear turret.
			if spec.get("size_class", "SMALL") == "LARGE":
				ship.set_size(5.0, 75.0)
				ship.rear_arc_degrees = 90.0
				ship.has_rear_turret = true
				ship.setup_rear_arc()
				ship.speed_options = [1, 2, 3]
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
	ship.ship_texture = TEX_HAULER
	ship.team = "PLAYER"
	ships_root.add_child(ship)
	ship.speed_options = []
	ship.bearing_options = []
	_apply_spec(ship, spec)   # keeps the spec's tanky convoy stats (no class override)
	ship.dial_data = null     # never planned, never manoeuvres
	# Convoy Hull: Large size class, escort objective (destroyed = mission fail).
	ship.set_size(5.0, 75.0)
	ship.is_objective = true
	if spec.get("objective_armed", false):
		ship.has_rear_turret = true
		ship.rear_arc_degrees = 90.0
		ship.setup_rear_arc()
	ship.position = _transport_spawn[0]
	ship.rotation = _transport_spawn[1]
	return ship


func _player_texture(class_id: String) -> Texture2D:
	match class_id:
		"heavy_fighter": return TEX_HEAVY
		"interceptor":   return TEX_INTERCEPTOR
		"gunship":       return TEX_GUNSHIP
		"hauler":        return TEX_HAULER
		_:               return TEX_FIGHTER


func _enemy_texture(spec: Dictionary) -> Texture2D:
	if spec.get("is_capital_body", false) or spec.get("is_turret", false):
		return TEX_AI_LARGE
	match spec.get("ship_class", "enemy_fighter"):
		"enemy_scout":   return TEX_AI_SCOUT
		"enemy_assault": return TEX_AI_ASSAULT
		"enemy_large":   return TEX_AI_LARGE
		_:               return TEX_AI_FIGHTER


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
	# Torpedoes ammo: 1 shot only, set from weapon type.
	ship.torpedoes_ammo = 1 if w.weapon_type == Weapon.Type.TORPEDOES else 0
	ship.attack_base = int(spec.get("attack", 3))

	ship.is_drone = spec.get("is_drone", false)

	if spec.has("accent"):
		var a: Array = spec["accent"]
		ship.accent_color = Color(a[0], a[1], a[2], 1.0)

	# Fuel Leak persists from previous mission.
	if spec.get("fuel_leak", false):
		ship.active_crits.append("FUEL_LEAK")

	if not skip_passives:
		ship.apply_setup_passives()


func _dial_for_class(class_id: String):
	match class_id:
		"enemy_scout":   return ShipDials.enemy_scout()
		"enemy_assault": return ShipDials.enemy_assault()
		"enemy_large":   return ShipDials.large()
		_:               return ShipDials.enemy_fighter()


func _weapon_type(weapon_name: String) -> Weapon.Type:
	match weapon_name:
		"BURST": return Weapon.Type.BURST
		"HEAVY": return Weapon.Type.HEAVY
		"ION": return Weapon.Type.ION
		"MISSILES": return Weapon.Type.MISSILES
		"TORPEDOES": return Weapon.Type.TORPEDOES
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
	_draw_edges()
	_draw_danger_zone()
	for i in range(_ships.size()):
		for j in range(i + 1, _ships.size()):
			var a: Ship = _ships[i] as Ship
			var b: Ship = _ships[j] as Ship
			if a.is_destroyed or b.is_destroyed or a.team != b.team:
				continue
			if a.global_position.distance_to(b.global_position) <= CombatSystem.FORMATION_RANGE:
				draw_line(a.global_position, b.global_position, Color(0.3, 0.8, 1.0, 0.22), 2.0)
	# Target lock visuals: thick line from locker to locked ship + RED X on the target.
	# Also shows a dimmer pending lock (target chosen but not yet acquired).
	for s in _ships:
		var sh: Ship = s as Ship
		if sh.is_destroyed:
			continue
		# Active lock (acquired last round) — full RED X + thick line.
		if sh.target_lock != null and not sh.target_lock.is_destroyed:
			var tp: Vector2 = sh.target_lock.global_position
			draw_line(sh.global_position, tp, Color(1.0, 0.18, 0.18, 0.7), 4.0)
			var xs: float = 22.0
			draw_line(tp - Vector2(xs, xs), tp + Vector2(xs, xs), Color(1.0, 0.12, 0.12, 0.95), 3.5)
			draw_line(tp - Vector2(xs, -xs), tp + Vector2(xs, -xs), Color(1.0, 0.12, 0.12, 0.95), 3.5)
		# Pending lock (chosen this round, activates next round) — amber line + X.
		elif sh.pending_lock_target != null and not sh.pending_lock_target.is_destroyed:
			var pp: Vector2 = sh.pending_lock_target.global_position
			draw_line(sh.global_position, pp, Color(1.0, 0.55, 0.1, 0.45), 2.5)
			var pxs: float = 18.0
			draw_line(pp - Vector2(pxs, pxs), pp + Vector2(pxs, pxs), Color(1.0, 0.55, 0.1, 0.65), 2.0)
			draw_line(pp - Vector2(pxs, -pxs), pp + Vector2(pxs, -pxs), Color(1.0, 0.55, 0.1, 0.65), 2.0)


# Telegraph edge behaviour so the player never learns it by dying: ESCAPE glows green
# (the jump point / safety), WALL reads as a red hazard border, BLOCK is a grey wall.
func _draw_edges() -> void:
	var a: Vector2 = ManeuverSystem.arena_size
	var corners := {
		"top": [Vector2(0, 0), Vector2(a.x, 0)],
		"bottom": [Vector2(0, a.y), Vector2(a.x, a.y)],
		"left": [Vector2(0, 0), Vector2(0, a.y)],
		"right": [Vector2(a.x, 0), Vector2(a.x, a.y)],
	}
	for key in corners.keys():
		var mode: String = ManeuverSystem.edges.get(key, "WALL")
		var pts: Array = corners[key]
		match mode:
			"ESCAPE":
				draw_line(pts[0], pts[1], Color(0.3, 1.0, 0.5, 0.9), 6.0)
				draw_line(pts[0], pts[1], Color(0.5, 1.0, 0.7, 0.35), 16.0)
			"BLOCK":
				draw_line(pts[0], pts[1], Color(0.55, 0.55, 0.6, 0.8), 5.0)
			_:  # WALL
				draw_line(pts[0], pts[1], Color(0.8, 0.25, 0.2, 0.5), 3.0)


# The advancing Danger Zone: a bright leading edge with a hazard fill behind it
# (the consumed space). Telegraphs the sweep so the player flees forward in time.
func _draw_danger_zone() -> void:
	if not ManeuverSystem.danger_active:
		return
	var line: Array = ManeuverSystem.danger_line_points()
	if line.size() < 2:
		return
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	var arena: Vector2 = ManeuverSystem.arena_size
	# Fill the trailing (caught) side. For the default upward sweep, that's below the line.
	var axis: Vector2 = ManeuverSystem.danger_axis
	var fill_pts := PackedVector2Array()
	if absf(axis.y) >= absf(axis.x):
		var y: float = a.y
		var caught_y: float = arena.y if axis.y < 0.0 else 0.0
		fill_pts = PackedVector2Array([Vector2(0, y), Vector2(arena.x, y),
									   Vector2(arena.x, caught_y), Vector2(0, caught_y)])
	else:
		var x: float = a.x
		var caught_x: float = arena.x if axis.x < 0.0 else 0.0
		fill_pts = PackedVector2Array([Vector2(x, 0), Vector2(x, arena.y),
									   Vector2(caught_x, arena.y), Vector2(caught_x, 0)])
	draw_colored_polygon(fill_pts, Color(0.8, 0.15, 0.1, 0.18))
	draw_line(a, b, Color(1.0, 0.35, 0.2, 0.95), 6.0)
	draw_line(a, b, Color(1.0, 0.5, 0.3, 0.4), 18.0)


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
		if CampaignManager.test_mode:
			get_tree().change_scene_to_file("res://scenes/MissionSelectMenu.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
