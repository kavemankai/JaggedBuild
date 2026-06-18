extends Control

signal all_confirmed

const SHIP_CARD: PackedScene = preload("res://scenes/ShipCard.tscn")
const Formation := preload("res://scripts/Formation.gd")

@onready var _cards_row: HBoxContainer = $Panel/Margin/HBox/Cards
@onready var _confirm_btn: Button = $Panel/Margin/HBox/ConfirmAll
@onready var _selector: PanelContainer = $ManeuverSelector

var _ships: Array = []          # friendly ships
var _ghosts: Dictionary = {}    # ship -> GhostShip
var _cards: Array = []
var _camera: Node = null        # CameraRig; clicking a card focuses it on the ship
var _formations: Array = []     # active Formation objects (player wing-locks)


func _ready() -> void:
	_apply_style()


func _apply_style() -> void:
	# Panel background + top border
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIConstants.COLOR_BG_PANEL
	panel_style.border_color = UIConstants.COLOR_CYAN
	panel_style.border_width_top = UIConstants.BORDER_W
	$Panel.add_theme_stylebox_override("panel", panel_style)

	# ConfirmAll button — styled in refresh(); initial inactive state
	_apply_confirm_btn_style(false)


func _apply_confirm_btn_style(ready: bool) -> void:
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UIConstants.COLOR_BG_PANEL
	btn_style.border_color = UIConstants.COLOR_CYAN if ready else UIConstants.COLOR_INACTIVE
	btn_style.set_border_width_all(UIConstants.BORDER_W_PRI)
	btn_style.set_corner_radius_all(2)
	_confirm_btn.add_theme_stylebox_override("normal", btn_style)
	_confirm_btn.add_theme_stylebox_override("disabled", btn_style)
	_confirm_btn.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	_confirm_btn.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
	_confirm_btn.add_theme_color_override("font_color",
		UIConstants.COLOR_WHITE if ready else UIConstants.COLOR_INACTIVE)
	_confirm_btn.add_theme_color_override("font_disabled_color", UIConstants.COLOR_INACTIVE)


func set_camera(cam: Node) -> void:
	_camera = cam


func setup(friendly_ships: Array, ghosts: Dictionary) -> void:
	_ships = friendly_ships
	_ghosts = ghosts
	_build_cards()
	_selector.maneuver_picked.connect(_on_maneuver_picked)
	_selector.closed.connect(_on_selector_closed)
	_confirm_btn.pressed.connect(_on_confirm)
	refresh()


func _build_cards() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_cards.clear()

	for s in _ships:
		var ship: Ship = s as Ship
		var card := SHIP_CARD.instantiate()
		_cards_row.add_child(card)
		card.setup(ship)
		card.card_clicked.connect(_open_selector)
		card.selection_changed.connect(refresh)
		card.formation_toggled.connect(_on_formation_toggled)
		_cards.append(card)


# New planning round: clear friendly selections.
func reset() -> void:
	_selector.close()
	for s in _ships:
		var ship: Ship = s as Ship
		ship.selected_maneuver = null
		ship.selected_action = "FOCUS"
	refresh()


# --- Formation lock (Gate 44) -----------------------------------------------
# LOCK pressed: if the ship is already in a formation, break it; otherwise gather
# every nearby unformed friendly (within lock range) and snap them into one
# formation — highest-skill becomes Lead, up to 2 others become Wings.
func _on_formation_toggled(ship: Ship) -> void:
	var existing = _formation_of(ship)
	if existing != null:
		_dissolve(existing)
		refresh()
		return

	var group: Array = [ship]
	for s in _ships:
		var o: Ship = s as Ship
		if o == ship or o.is_destroyed or o.escaped:
			continue
		if _formation_of(o) != null:
			continue
		if ship.global_position.distance_to(o.global_position) <= CombatSystem.FORMATION_RANGE:
			group.append(o)
	if group.size() < 2:
		return   # nobody close enough to form with

	group.sort_custom(func(a, b): return (a as Ship).get_skill() > (b as Ship).get_skill())
	var f = Formation.new()
	f.lead = group[0]
	f.wings = group.slice(1, 1 + Formation.MAX_WINGS)
	f.lead.formation = f
	f.lead.formation_role = "LEAD"
	for w in f.wings:
		(w as Ship).formation = f
		(w as Ship).formation_role = "WING"
		(w as Ship).selected_maneuver = null   # cleared; lead will drive it
	_formations.append(f)
	refresh()


func _formation_of(ship: Ship):
	for f in _formations:
		if f.has(ship):
			return f
	return null


func _dissolve(f) -> void:
	for m in f.members():
		var ship: Ship = m as Ship
		if ship == null:
			continue
		ship.formation = null
		ship.formation_role = "NONE"
	_formations.erase(f)


# Mirror each lead's maneuver onto its wings (clamped to the wing's own dial), and
# drop any formation that's no longer valid (member lost or strayed out of range).
func _apply_formations() -> void:
	var dead: Array = []
	for f in _formations:
		if not f.is_valid():
			dead.append(f)
			continue
		if f.lead.selected_maneuver != null:
			for w in f.wings:
				var wing: Ship = w as Ship
				if wing.is_destroyed or wing.escaped:
					continue
				wing.selected_maneuver = _legal_for(wing, f.lead.selected_maneuver)
	for f in dead:
		_dissolve(f)


# The lead's maneuver, clamped to what the wing's dial actually allows (and never a
# RED maneuver while the wing is stressed). Formation dial = intersection of members'.
func _legal_for(wing: Ship, lead_m: Maneuver) -> Maneuver:
	var available: bool = true
	if wing.dial_data != null:
		available = wing.dial_data.get_color(lead_m.bearing, lead_m.speed) != ""
	else:
		available = lead_m.bearing in wing.bearing_options
	var col: String = wing.get_maneuver_color(lead_m.bearing, lead_m.speed)
	if available and not (wing.stress > 0 and col == "RED"):
		var m := Maneuver.new()
		m.bearing = lead_m.bearing
		m.speed = lead_m.speed
		return m
	return _closest_non_red(wing, lead_m.speed)


func _open_selector(ship: Ship) -> void:
	if ship.is_destroyed or ship.escaped:
		return
	# Wings don't pick their own maneuver — the lead drives them.
	if ship.formation_role == "WING":
		if _camera != null:
			_camera.focus_on(ship.global_position, false)
		return
	# Focus the camera on this ship so it's never lost on a large map. Recenter only
	# (don't override the player's chosen zoom).
	if _camera != null:
		_camera.focus_on(ship.global_position, false)
	_selector.open_for(ship, _ghosts.get(ship))
	_refresh_ghosts(ship)
	_position_selector_over(ship)


func _position_selector_over(ship: Ship) -> void:
	var idx: int = _ships.find(ship)
	if idx < 0 or idx >= _cards.size():
		return
	# Defer so the selector has computed its size after _populate().
	await get_tree().process_frame
	var card: Control = _cards[idx]
	var sel_size: Vector2 = _selector.size
	var target_x: float = card.global_position.x + card.size.x * 0.5 - sel_size.x * 0.5
	target_x = clampf(target_x, 8.0, get_viewport_rect().size.x - sel_size.x - 8.0)
	var target_y: float = $Panel.global_position.y - sel_size.y - 8.0
	_selector.global_position = Vector2(target_x, target_y)


func _on_maneuver_picked(_ship: Ship, _maneuver: Maneuver) -> void:
	refresh()


func _on_selector_closed() -> void:
	_refresh_ghosts(null)


# Show every friendly ghost for its committed maneuver; the active ship (selector
# open) brightens, the rest dim. Ships with no selection hide their ghost.
func _refresh_ghosts(active_ship) -> void:
	for s in _ships:
		var ship: Ship = s as Ship
		var ghost: Node2D = _ghosts.get(ship)
		if ghost == null:
			continue
		if ship.selected_maneuver != null:
			ghost.update_preview(ship, ship.selected_maneuver, ship == active_ship)
		elif ship != active_ship:
			ghost.clear_preview()


func refresh() -> void:
	_apply_formations()
	var missing: int = 0
	for s in _ships:
		var ship: Ship = s as Ship
		if not ship.is_destroyed and not ship.escaped and ship.selected_maneuver == null:
			missing += 1

	var now_ready: bool = missing == 0
	if now_ready and _confirm_btn.disabled:
		AudioManager.play_sfx("sfx_phase")
	_confirm_btn.disabled = not now_ready
	_confirm_btn.text = "CONFIRM ALL" if now_ready else "%d SHIPS NEED ORDERS" % missing
	_apply_confirm_btn_style(now_ready)

	for card in _cards:
		card.refresh()
	_refresh_ghosts(null)


func _on_confirm() -> void:
	AudioManager.play_sfx("sfx_confirm")
	for s in _ships:
		var ship: Ship = s as Ship
		if ship.selected_action == "":
			ship.selected_action = "FOCUS"
		# Safety: if a red maneuver slipped through on a stressed ship, swap it.
		if ship.stress > 0 and ship.selected_maneuver != null \
				and ship.get_maneuver_color(ship.selected_maneuver.bearing, ship.selected_maneuver.speed) == "RED":
			ship.selected_maneuver = _closest_non_red(ship, ship.selected_maneuver.speed)
	all_confirmed.emit()


func _closest_non_red(ship: Ship, speed: int) -> Maneuver:
	if ship.dial_data != null:
		# Prefer same speed; fall back to any non-red option.
		for option: Dictionary in ship.dial_data.get_all_options():
			if int(option["speed"]) == speed and option["color"] != "RED":
				var m := Maneuver.new()
				m.bearing = option["bearing"] as String
				m.speed = speed
				return m
		for option: Dictionary in ship.dial_data.get_all_options():
			if option["color"] != "RED":
				var m := Maneuver.new()
				m.bearing = option["bearing"] as String
				m.speed = int(option["speed"])
				return m
	else:
		for bearing: String in ship.bearing_options:
			if ship.get_maneuver_color(bearing) != "RED":
				var m := Maneuver.new()
				m.bearing = bearing
				m.speed = speed
				return m
	var fallback := Maneuver.new()
	fallback.bearing = "STRAIGHT"
	fallback.speed = 1
	return fallback


func _unhandled_input(event: InputEvent) -> void:
	if _selector.visible and event is InputEventMouseButton and event.pressed:
		if not _selector.get_global_rect().has_point(event.global_position):
			_selector.close()
