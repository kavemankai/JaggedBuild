extends PanelContainer

signal card_clicked(ship: Ship)
signal selection_changed
signal formation_toggled(ship: Ship)

@onready var _name_label: Label    = $Margin/VBox/NameLabel
@onready var _shield_bar: ProgressBar = $Margin/VBox/ShieldRow/ShieldBar
@onready var _shield_lbl: Label    = $Margin/VBox/ShieldRow/ShieldLabel
@onready var _hull_bar: ProgressBar   = $Margin/VBox/HullRow/HullBar
@onready var _hull_lbl: Label      = $Margin/VBox/HullRow/HullLabel
@onready var _token_row: HBoxContainer = $Margin/VBox/TokenRow
@onready var _ion_row: HBoxContainer   = $Margin/VBox/StatusRow/IonRow
@onready var _weapon_label: Label  = $Margin/VBox/StatusRow/WeaponLabel
@onready var _maneuver_label: Label = $Margin/VBox/ManeuverLabel
@onready var _action_row: HBoxContainer = $Margin/VBox/ActionRow
@onready var _change_btn: Button   = $Margin/VBox/ChangeButton
@onready var _crit_row: HBoxContainer   = $Margin/VBox/CritRow
@onready var _system_row: HBoxContainer = $Margin/VBox/SystemRow

var ship: Ship = null
var hud_mode: bool = false
var _stress_tween: Tween = null
var _form_btn: Button = null
var _panel_style: StyleBoxFlat = null
var _faction_color: Color = UIConstants.COLOR_INACTIVE
var _ion_pips: Array = []
var _last_crit_count: int = -1
var _last_system_mask: int = -1
# Static token textures with their action-key and atlas function
const _TOKEN_DEFS: Array = [
	["FOCUS",       "focus"],
	["EVADE",       "evade"],
	["TARGET_LOCK", "target_lock"],
	["OVERCHARGE",  "overcharge"],
]


func setup(s: Ship, p_hud_mode: bool = false) -> void:
	ship = s
	hud_mode = p_hud_mode
	_apply_panel_style()
	_apply_label_styles()
	_build_bars()
	_build_ion_pips()
	_build_token_row()
	if not hud_mode:
		# Planning strip — hide health rows (they're in the HUD right panel)
		$Margin/VBox/ShieldRow.visible = false
		$Margin/VBox/HullRow.visible = false
		$Margin/VBox/StatusRow.visible = false
		if ship.selected_action == "":
			ship.selected_action = "FOCUS"
		_populate_actions()
		_build_formation_button()
		_change_btn.pressed.connect(func(): card_clicked.emit(ship))
	else:
		_maneuver_label.visible = false
		_action_row.visible = false
		_change_btn.visible = false
	refresh()


func _apply_panel_style() -> void:
	if ship.is_drone:
		_faction_color = UIConstants.COLOR_INACTIVE
	elif ship.team == "PLAYER":
		_faction_color = UIConstants.COLOR_CYAN
	else:
		_faction_color = UIConstants.COLOR_MAGENTA

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = UIConstants.COLOR_BG_PANEL
	_panel_style.border_color = _faction_color
	_panel_style.set_border_width_all(UIConstants.BORDER_W)
	_panel_style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", _panel_style)


func _apply_label_styles() -> void:
	_name_label.add_theme_font_override("font", UIConstants.FONT_NARR)
	_name_label.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
	_name_label.add_theme_color_override("font_color",
		UIConstants.COLOR_INACTIVE if ship.is_drone else UIConstants.COLOR_WHITE)

	for lbl in [_shield_lbl, _hull_lbl]:
		lbl.add_theme_font_override("font", UIConstants.FONT_UI)
		lbl.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
		lbl.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)

	_weapon_label.add_theme_font_override("font", UIConstants.FONT_UI)
	_weapon_label.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)

	_maneuver_label.add_theme_font_override("font", UIConstants.FONT_UI)
	_maneuver_label.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)

	_change_btn.add_theme_font_override("font", UIConstants.FONT_UI)
	_change_btn.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)


func _build_bars() -> void:
	_shield_bar.max_value = maxi(1, ship.shields)
	_shield_bar.value = ship.shields
	_style_bar(_shield_bar, UIConstants.COLOR_SHIELD)

	_hull_bar.max_value = maxi(1, ship.hull)
	_hull_bar.value = ship.hull
	_style_bar(_hull_bar, UIConstants.COLOR_HULL)


func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIConstants.COLOR_BG_SECONDARY
	bar.add_theme_stylebox_override("background", bg)


func _build_ion_pips() -> void:
	for child in _ion_row.get_children():
		child.queue_free()
	_ion_pips.clear()
	for i in range(5):
		var pip := Label.new()
		pip.text = "●"
		pip.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
		_ion_row.add_child(pip)
		_ion_pips.append(pip)


func _build_token_row() -> void:
	for child in _token_row.get_children():
		child.queue_free()
	if ship.is_drone:
		return
	for entry in _TOKEN_DEFS:
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = UIConstants.ICON_SIZE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_meta("action_key", entry[0])
		match entry[1]:
			"focus":       tex_rect.texture = UIConstants.icon_focus()
			"evade":       tex_rect.texture = UIConstants.icon_evade()
			"target_lock": tex_rect.texture = UIConstants.icon_target_lock()
			"overcharge":  tex_rect.texture = UIConstants.icon_overcharge()
		_token_row.add_child(tex_rect)
	# Formation icon
	var form_icon := TextureRect.new()
	form_icon.custom_minimum_size = UIConstants.ICON_SIZE
	form_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	form_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	form_icon.texture = UIConstants.icon_formation()
	form_icon.set_meta("action_key", "FORMATION")
	form_icon.modulate = Color(UIConstants.COLOR_CYAN, 0.0)
	_token_row.add_child(form_icon)


# A LOCK toggle the player uses to form/break a wing formation with nearby ships.
func _build_formation_button() -> void:
	_form_btn = Button.new()
	_form_btn.add_theme_font_override("font", UIConstants.FONT_UI)
	_form_btn.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
	_form_btn.custom_minimum_size = Vector2(0, 22)
	_form_btn.focus_mode = Control.FOCUS_NONE
	_form_btn.pressed.connect(func(): formation_toggled.emit(ship))
	$Margin/VBox.add_child(_form_btn)
	$Margin/VBox.move_child(_form_btn, $Margin/VBox.get_child_count() - 1)


func _populate_actions() -> void:
	for child in _action_row.get_children():
		child.queue_free()

	var actions := [["FOCUS", "FOCUS"], ["LOCK", "TARGET_LOCK"], ["EVADE", "EVADE"], ["BOOST", "BOOST"]]
	if ship.has_active_ability():
		actions.append([ship.get_active_ability().replace("_", " "), "ABILITY"])

	for entry in actions:
		var label: String = entry[0]
		var key: String = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", UIConstants.FONT_UI)
		btn.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
		btn.set_meta("action_key", key)
		if key == "ABILITY":
			btn.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
		btn.toggled.connect(_on_action_toggled.bind(key))
		_action_row.add_child(btn)


func _on_action_toggled(pressed: bool, action: String) -> void:
	if not pressed:
		if ship.selected_action == action:
			for btn in _action_row.get_children():
				if btn is Button and btn.get_meta("action_key", "") == action:
					btn.set_pressed_no_signal(true)
		return
	ship.selected_action = action
	for btn in _action_row.get_children():
		if btn is Button and btn.get_meta("action_key", "") != action:
			btn.set_pressed_no_signal(false)
	selection_changed.emit()


func has_maneuver() -> bool:
	return ship.selected_maneuver != null


func refresh() -> void:
	if not is_instance_valid(ship):
		return

	if ship.escaped:
		_name_label.text = ship.get_pilot_name() + "  ESCAPED"
		_name_label.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
		_maneuver_label.text = "— JUMPED OUT —"
		_maneuver_label.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
		if not hud_mode:
			_change_btn.disabled = true
		_kill_stress_tween()
		modulate = Color(0.55, 0.8, 0.6, 0.9)
		for btn in _action_row.get_children():
			if btn is Button:
				btn.disabled = true
		_update_bars()
		return

	if ship.is_destroyed:
		_name_label.text = ship.get_pilot_name() + "  DOWN"
		_name_label.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)
		_maneuver_label.text = "— DESTROYED —"
		_maneuver_label.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)
		if not hud_mode:
			_change_btn.disabled = true
		_kill_stress_tween()
		modulate = Color(0.3, 0.3, 0.3, 0.9)
		if _panel_style != null:
			_panel_style.border_color = UIConstants.COLOR_INACTIVE
			add_theme_stylebox_override("panel", _panel_style)
		for btn in _action_row.get_children():
			if btn is Button:
				btn.disabled = true
		_update_weapon_label()
		_update_bars()
		_update_crits()
		_update_systems()
		return

	modulate = Color(1.0, 1.0, 1.0, 0.8 if ship.is_drone else 1.0)
	if not hud_mode:
		_change_btn.disabled = false

	_name_label.text = "%s  PS:%d" % [ship.get_pilot_name(), ship.get_skill()]
	_name_label.add_theme_color_override("font_color",
		UIConstants.COLOR_INACTIVE if ship.is_drone else UIConstants.COLOR_WHITE)

	_update_bars()
	_update_tokens()
	_update_ion_pips()
	_update_weapon_label()

	if not hud_mode:
		_update_maneuver_label()
		_update_action_buttons()
		_refresh_formation_ui()

	_update_crits()
	_update_systems()

	var stressed: bool = ship.stress > 0
	var disrupted: bool = ship.ion_tokens > 0 or not ship.disabled_systems.is_empty()
	_update_stress_border(stressed or disrupted)


func _update_bars() -> void:
	_shield_bar.value = ship.shields
	var hull_frac: float = float(ship.hull) / float(maxi(1, _hull_bar.max_value))
	var hull_color: Color = UIConstants.COLOR_HULL_CRIT if hull_frac <= 0.3 else UIConstants.COLOR_HULL
	_style_bar(_hull_bar, hull_color)
	_hull_bar.value = ship.hull


func _update_tokens() -> void:
	var active_keys: Dictionary = {
		"FOCUS": ship.focus_token,
		"EVADE": ship.evade_token,
		"TARGET_LOCK": ship.target_lock != null,
		"OVERCHARGE": ship.overcharged,
		"FORMATION": ship.in_formation,
	}
	for child in _token_row.get_children():
		if child is TextureRect:
			var key: String = child.get_meta("action_key", "")
			var active: bool = active_keys.get(key, false)
			if key == "FORMATION":
				child.modulate = Color(UIConstants.COLOR_CYAN, 1.0 if active else 0.0)
			else:
				child.modulate = Color(1.0, 1.0, 1.0, 1.0 if active else 0.25)


func _update_ion_pips() -> void:
	for i in range(_ion_pips.size()):
		var pip: Label = _ion_pips[i]
		if i < ship.ion_tokens:
			pip.add_theme_color_override("font_color", UIConstants.COLOR_ION)
		else:
			pip.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)


func _update_weapon_label() -> void:
	if ship.is_destroyed:
		_weapon_label.text = "DOWN"
		_weapon_label.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)
		return
	var w: Weapon = ship.weapon as Weapon
	var wname: String = "CANNONS"
	var state_text: String = "READY"
	var state_color: Color = UIConstants.COLOR_CYAN
	if w != null:
		match w.weapon_type:
			Weapon.Type.BURST:    wname = "BURST"
			Weapon.Type.HEAVY:    wname = "HEAVY"
			Weapon.Type.ION:      wname = "ION"
			Weapon.Type.MISSILES: wname = "MISSILES"
			Weapon.Type.TORPEDOES: wname = "TORPEDOES"
			Weapon.Type.TURRET:   wname = "TURRET"
		if ship.heavy_cooldown > 0:
			state_text = "cd:%d" % ship.heavy_cooldown
			state_color = UIConstants.COLOR_AMBER
		elif w.weapon_type == Weapon.Type.MISSILES and ship.missiles_ammo <= 0:
			state_text = "EMPTY"
			state_color = UIConstants.COLOR_INACTIVE
		elif w.weapon_type == Weapon.Type.TORPEDOES and ship.torpedoes_ammo <= 0:
			state_text = "EMPTY"
			state_color = UIConstants.COLOR_INACTIVE
	_weapon_label.text = "%s %s" % [wname, state_text]
	_weapon_label.add_theme_color_override("font_color", state_color)


func _update_maneuver_label() -> void:
	var ion_note: String = _ion_note()
	if ship.selected_maneuver != null:
		var m: Maneuver = ship.selected_maneuver
		var col: String = ship.get_maneuver_color(m.bearing, m.speed)
		var dial_color: Color
		match col:
			"GREEN": dial_color = UIConstants.COLOR_GREEN_DIAL
			"RED":   dial_color = UIConstants.COLOR_RED_DIAL
			_:       dial_color = UIConstants.COLOR_WHITE
		_maneuver_label.text = "► " + m.bearing.replace("_", " ") + " " + str(m.speed)
		_maneuver_label.add_theme_color_override("font_color", dial_color)
	else:
		_maneuver_label.text = "— no orders —"
		_maneuver_label.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
	if ion_note != "":
		_maneuver_label.text += "  " + ion_note
		_maneuver_label.add_theme_color_override("font_color", UIConstants.COLOR_ION)


func _update_action_buttons() -> void:
	var stressed: bool = ship.stress > 0
	for btn in _action_row.get_children():
		if btn is Button:
			var key: String = btn.get_meta("action_key", "")
			btn.set_pressed_no_signal(key == ship.selected_action)
			match key:
				"ABILITY":     btn.disabled = ship.ability_used
				"BOOST":       btn.disabled = stressed or ship.engines_disabled()
				"TARGET_LOCK": btn.disabled = stressed or ship.sensors_disabled()
				_:             btn.disabled = stressed


func _update_crits() -> void:
	var count: int = ship.active_crits.size()
	if count == _last_crit_count:
		return
	_last_crit_count = count
	for child in _crit_row.get_children():
		child.queue_free()
	if count == 0:
		return
	var shown: int = mini(ship.active_crits.size(), 3)
	for i in range(shown):
		var crit_id: String = ship.active_crits[i]
		var tex := _crit_atlas(crit_id)
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(16, 16)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.modulate = UIConstants.COLOR_CRIT
		_crit_row.add_child(tr)
	if ship.active_crits.size() > 3:
		var overflow := Label.new()
		overflow.text = "+%d" % (ship.active_crits.size() - 3)
		overflow.add_theme_font_override("font", UIConstants.FONT_UI)
		overflow.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
		overflow.add_theme_color_override("font_color", UIConstants.COLOR_CRIT)
		_crit_row.add_child(overflow)


func _crit_atlas(crit_id: String) -> AtlasTexture:
	match crit_id:
		"DIRECT_HIT":        return UIConstants.icon_direct_hit()
		"HULL_BREACH":       return UIConstants.icon_hull_breach()
		"STRUCTURAL_DAMAGE": return UIConstants.icon_structural_damage()
		"WEAPONS_FAILURE":   return UIConstants.icon_weapons_failure()
		"DAMAGED_ENGINE":    return UIConstants.icon_damaged_engine()
		"FUEL_LEAK":         return UIConstants.icon_fuel_leak()
	return null


func _update_systems() -> void:
	var mask: int = (1 if ship.engines_disabled() else 0) \
		| (2 if ship.weapons_disabled() else 0) \
		| (4 if ship.sensors_disabled() else 0) \
		| (8 if ship.shields_disrupted() else 0)
	if mask == _last_system_mask:
		return
	_last_system_mask = mask
	for child in _system_row.get_children():
		child.queue_free()
	var icons: Array = []
	if mask & 1: icons.append(UIConstants.icon_engines_disabled())
	if mask & 2: icons.append(UIConstants.icon_weapons_disabled())
	if mask & 4: icons.append(UIConstants.icon_sensors_disabled())
	if mask & 8: icons.append(UIConstants.icon_shields_disrupted())
	for tex in icons:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(16, 16)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_system_row.add_child(tr)


func _refresh_formation_ui() -> void:
	if _form_btn == null:
		return
	match ship.formation_role:
		"LEAD":
			_form_btn.text = "◆ LEAD — break"
			_form_btn.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
			_maneuver_label.text += "   ◆LEAD"
		"WING":
			_form_btn.text = "◇ WING — break"
			_form_btn.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
			if ship.selected_maneuver != null:
				_maneuver_label.text = "↳ " + ship.selected_maneuver.bearing.replace("_", " ") + " " + str(ship.selected_maneuver.speed)
			else:
				_maneuver_label.text = "↳ following lead"
			_maneuver_label.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
		_:
			_form_btn.text = "LOCK ▲"
			_form_btn.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)
	_change_btn.disabled = _change_btn.disabled or ship.formation_role == "WING"
	_form_btn.disabled = ship.is_destroyed or ship.escaped


func _ion_note() -> String:
	var parts: Array = []
	if ship.ion_tokens > 0:
		parts.append("ION%d" % ship.ion_tokens)
	if ship.engines_disabled():
		parts.append("ENG✕")
	if ship.weapons_disabled():
		parts.append("WPN✕")
	if ship.sensors_disabled():
		parts.append("SEN✕")
	if ship.shields_disrupted():
		parts.append("SHLD✕")
	return " ".join(parts)


func _kill_stress_tween() -> void:
	if _stress_tween != null:
		_stress_tween.kill()
		_stress_tween = null
	modulate = Color(1.0, 1.0, 1.0, 0.8 if ship.is_drone else 1.0)
	if _panel_style != null:
		_panel_style.border_color = _faction_color
		add_theme_stylebox_override("panel", _panel_style)


func _update_stress_border(active: bool) -> void:
	if active and _stress_tween == null:
		_stress_tween = create_tween().set_loops()
		_stress_tween.tween_method(_set_border_color, _faction_color, UIConstants.COLOR_HULL_CRIT, 0.6)
		_stress_tween.tween_method(_set_border_color, UIConstants.COLOR_HULL_CRIT, _faction_color, 0.6)
	elif not active and _stress_tween != null:
		_kill_stress_tween()


func _set_border_color(c: Color) -> void:
	if _panel_style != null:
		_panel_style.border_color = c
		add_theme_stylebox_override("panel", _panel_style)


func _gui_input(event: InputEvent) -> void:
	if hud_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _change_btn.disabled:
			card_clicked.emit(ship)
