extends Control

signal all_confirmed

const SHIP_CARD: PackedScene = preload("res://scenes/ShipCard.tscn")

@onready var _cards_row: HBoxContainer = $Panel/Margin/HBox/Cards
@onready var _confirm_btn: Button = $Panel/Margin/HBox/ConfirmAll
@onready var _selector: PanelContainer = $ManeuverSelector

var _ships: Array = []          # friendly ships
var _ghosts: Dictionary = {}    # ship -> GhostShip
var _cards: Array = []


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
		_cards.append(card)


# New planning round: clear friendly selections (ion-locked ships keep a forced run).
func reset() -> void:
	_selector.close()
	for s in _ships:
		var ship: Ship = s as Ship
		if ship.is_ionized():
			var forced := Maneuver.new()
			forced.bearing = "STRAIGHT"
			forced.speed = 1
			ship.selected_maneuver = forced
		else:
			ship.selected_maneuver = null
		ship.selected_action = "FOCUS"
	refresh()


func _open_selector(ship: Ship) -> void:
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
	var missing: int = 0
	for s in _ships:
		if (s as Ship).selected_maneuver == null:
			missing += 1

	_confirm_btn.disabled = missing > 0
	_confirm_btn.text = "CONFIRM ALL" if missing == 0 else "%d ship(s) need orders" % missing

	for card in _cards:
		card.refresh()
	_refresh_ghosts(null)


func _on_confirm() -> void:
	for s in _ships:
		var ship: Ship = s as Ship
		if ship.selected_action == "":
			ship.selected_action = "FOCUS"
		# Safety: if a red maneuver slipped through on a stressed ship, swap it.
		if ship.stress > 0 and ship.selected_maneuver != null \
				and ship.get_maneuver_color(ship.selected_maneuver.bearing) == "RED":
			ship.selected_maneuver = _closest_non_red(ship, ship.selected_maneuver.speed)
	all_confirmed.emit()


func _closest_non_red(ship: Ship, speed: int) -> Maneuver:
	for bearing: String in ship.bearing_options:
		if ship.get_maneuver_color(bearing) != "RED":
			var m := Maneuver.new()
			m.bearing = bearing
			m.speed = speed
			return m
	# Fallback — straight.
	var fallback := Maneuver.new()
	fallback.bearing = "STRAIGHT"
	fallback.speed = speed
	return fallback


func _unhandled_input(event: InputEvent) -> void:
	if _selector.visible and event is InputEventMouseButton and event.pressed:
		if not _selector.get_global_rect().has_point(event.global_position):
			_selector.close()
