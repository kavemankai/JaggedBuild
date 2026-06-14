extends Node2D

const SHIP_SCENE: PackedScene = preload("res://scenes/Ship.tscn")
const GHOST_SCENE: PackedScene = preload("res://scenes/GhostShip.tscn")
const AI_TEXTURE: Texture2D = preload("res://assets/ships/ship_ai.png")
const ShipDials := preload("res://scripts/ShipDials.gd")

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
var _ghosts: Dictionary = {}

const PLAYER_SLOTS: Array = [
	[Vector2(800, 650), 0.0],
	[Vector2(960, 670), 0.0],
]
const ENEMY_SLOTS: Array = [
	[Vector2(800, 250), PI],
	[Vector2(620, 280), PI],
	[Vector2(980, 280), PI],
]

# Per-ship ghost opacities so overlapping friendly paths stay distinguishable.
const GHOST_ARC_ALPHAS: Array = [0.9, 0.6, 0.45]
const GHOST_BODY_ALPHAS: Array = [0.45, 0.4, 0.35]


func _ready() -> void:
	var mission: Dictionary = CampaignManager.current_mission()
	_player_ships = _deploy_player_team()
	_enemy_ships = _deploy_enemies(mission)
	_ships = _player_ships + _enemy_ships

	_build_ghosts()

	planning_strip.setup(_player_ships, _ghosts)
	planning_strip.all_confirmed.connect(_on_all_confirmed)

	# HUD lists combatants only — the capital hull is non-targetable scenery.
	var hud_ships: Array = _ships.filter(func(s): return (s as Ship).is_targetable)
	hud.setup_ships(hud_ships)
	hud.set_mission_label(mission.get("name", ""))

	RoundManager.register_ships(_ships)
	RoundManager.planning_phase_started.connect(_on_planning_started)
	RoundManager.resolution_phase_started.connect(_on_resolution_started)
	RoundManager.game_ended.connect(_on_game_ended)
	RoundManager.begin_round()


func _deploy_player_team() -> Array:
	var pilots: Array = CampaignManager.deployable_pilots()
	var slots: Array = [player_ship, wing_ship]
	var deployed: Array = []

	for i in range(slots.size()):
		var ship: Ship = slots[i]
		if i < pilots.size():
			ship.team = "PLAYER"
			ship.speed_options = [1, 2, 3, 4]
			ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT", "K_TURN"]
			ship.dial_data = ShipDials.fighter()
			_apply_spec(ship, pilots[i])
			ship.position = PLAYER_SLOTS[i][0]
			ship.rotation = PLAYER_SLOTS[i][1]
			deployed.append(ship)
		else:
			ship.queue_free()

	return deployed


func _deploy_enemies(mission: Dictionary) -> Array:
	var specs: Array = mission.get("enemies", [])
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
				ship.position = Vector2(800.0 + float(spec.get("x_offset", 0.0)), 220.0)
			ship.rotation = PI

		else:
			ships_root.add_child(ship)
			ship.speed_options = [1, 2, 3]
			ship.bearing_options = ["STRAIGHT", "BANK_LEFT", "BANK_RIGHT", "TURN_LEFT", "TURN_RIGHT"]
			_apply_spec(ship, spec)
			var slot: Array = ENEMY_SLOTS[slot_i % ENEMY_SLOTS.size()]
			slot_i += 1
			ship.position = slot[0]
			ship.rotation = slot[1]

		enemies.append(ship)
	return enemies


func _build_ghosts() -> void:
	for i in range(_player_ships.size()):
		var ship: Ship = _player_ships[i]
		var ghost := GHOST_SCENE.instantiate()
		ghosts_root.add_child(ghost)
		ghost.base_arc_alpha = GHOST_ARC_ALPHAS[i % GHOST_ARC_ALPHAS.size()]
		ghost.base_body_alpha = GHOST_BODY_ALPHAS[i % GHOST_BODY_ALPHAS.size()]
		ghost.clear_preview()
		_ghosts[ship] = ghost


func _apply_spec(ship: Ship, spec: Dictionary) -> void:
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

	var w := Weapon.new()
	w.weapon_type = _weapon_type(spec.get("weapon", "CANNONS"))
	w.display_name = spec.get("weapon", "Cannons").capitalize()
	ship.weapon = w

	if spec.has("accent"):
		var a: Array = spec["accent"]
		ship.accent_color = Color(a[0], a[1], a[2], 1.0)

	ship.apply_setup_passives()


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


func _on_game_ended(message: String, color: Color) -> void:
	_game_over = true
	var won: bool = not RoundManager.is_team_alive("ENEMY")
	CampaignManager.record_battle(_player_ships, won)
	hud.show_result(message, color, CampaignManager.last_summary)


func _input(event: InputEvent) -> void:
	if _game_over and event is InputEventKey and event.pressed and not event.echo:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
