extends CanvasLayer

@onready var _round_label: Label = $Info/Round
@onready var _phase_label: Label = $Info/Phase
@onready var _p_shields: ProgressBar = $HealthBars/PlayerRow/PlayerShields
@onready var _p_hull: ProgressBar = $HealthBars/PlayerRow/PlayerHull
@onready var _p_tokens: Label = $HealthBars/PlayerRow/PlayerTokens
@onready var _p_stress: Label = $HealthBars/PlayerRow/PlayerStress
@onready var _p_weapon: Label = $HealthBars/PlayerRow/PlayerWeapon
@onready var _ai_shields: ProgressBar = $HealthBars/AIRow/AIShields
@onready var _ai_hull: ProgressBar = $HealthBars/AIRow/AIHull
@onready var _ai_tokens: Label = $HealthBars/AIRow/AITokens
@onready var _ai_stress: Label = $HealthBars/AIRow/AIStress
@onready var _ai_weapon: Label = $HealthBars/AIRow/AIWeapon
@onready var _result: Label = $Result

var _player_ship: Ship = null
var _ai_ship: Ship = null
var _p_hull_low: bool = false
var _ai_hull_low: bool = false


func _ready() -> void:
	_style_bar(_p_shields, Color(0.2, 0.4, 0.9))
	_style_bar(_ai_shields, Color(0.2, 0.4, 0.9))
	_style_bar(_p_hull, Color(0.9, 0.5, 0.1))
	_style_bar(_ai_hull, Color(0.9, 0.5, 0.1))

	RoundManager.planning_phase_started.connect(func():
		_round_label.text = "Round %d" % RoundManager.round_number
		_phase_label.text = "PLANNING")
	RoundManager.resolution_phase_started.connect(func():
		_phase_label.text = "RESOLVING")
	RoundManager.action_phase_started.connect(func():
		_phase_label.text = "ACTIONS")
	RoundManager.combat_phase_started.connect(func():
		_phase_label.text = "COMBAT")
	RoundManager.evaluation_phase_started.connect(func():
		_phase_label.text = "")
	RoundManager.game_ended.connect(_on_game_ended)


func setup_health(player_ship: Ship, ai_ship: Ship) -> void:
	_player_ship = player_ship
	_ai_ship = ai_ship
	_p_shields.max_value = player_ship.shields
	_p_hull.max_value = player_ship.hull
	_ai_shields.max_value = ai_ship.shields
	_ai_hull.max_value = ai_ship.hull


func _process(_delta: float) -> void:
	if _player_ship == null:
		return
	_p_shields.value = _player_ship.shields
	_p_hull.value = _player_ship.hull
	_ai_shields.value = _ai_ship.shields
	_ai_hull.value = _ai_ship.hull

	_p_tokens.text = _token_text(_player_ship)
	_ai_tokens.text = _token_text(_ai_ship)
	_p_stress.text = "S×%d" % _player_ship.stress if _player_ship.stress > 0 else ""
	_ai_stress.text = "S×%d" % _ai_ship.stress if _ai_ship.stress > 0 else ""
	_p_weapon.text = _weapon_text(_player_ship)
	_ai_weapon.text = _weapon_text(_ai_ship)

	var p_low := _player_ship.hull <= _p_hull.max_value * 0.5
	if p_low != _p_hull_low:
		_p_hull_low = p_low
		_style_bar(_p_hull, Color(0.9, 0.15, 0.1) if p_low else Color(0.9, 0.5, 0.1))

	var ai_low := _ai_ship.hull <= _ai_hull.max_value * 0.5
	if ai_low != _ai_hull_low:
		_ai_hull_low = ai_low
		_style_bar(_ai_hull, Color(0.9, 0.15, 0.1) if ai_low else Color(0.9, 0.5, 0.1))


func _on_game_ended(message: String, color: Color) -> void:
	_result.text = message + "\n\nPRESS ANY KEY"
	_result.modulate = color
	_result.visible = true


func _weapon_text(ship: Ship) -> String:
	if ship.weapon == null:
		return "Cannons"
	match ship.weapon.weapon_type:
		Weapon.Type.BURST:
			return "Burst ×2"
		Weapon.Type.HEAVY:
			if ship.heavy_cooldown > 0:
				return "Heavy [cd:%d]" % ship.heavy_cooldown
			return "Heavy READY"
		Weapon.Type.MISSILES:
			return "Missiles"
		Weapon.Type.ION:
			return "Ion"
	return "Cannons"


func _token_text(ship: Ship) -> String:
	var parts: Array = []
	if ship.focus_token:
		parts.append("F")
	if ship.evade_token:
		parts.append("E")
	if ship.target_lock != null:
		parts.append("TL")
	return " ".join(parts)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bar.add_theme_stylebox_override("background", bg)
