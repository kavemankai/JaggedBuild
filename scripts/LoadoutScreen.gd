extends Control

const ShipClasses := preload("res://scripts/ShipClasses.gd")

const UPGRADES: Array = [
	{"id": "",                    "name": "None"},
	{"id": "Reinforced Plating",  "name": "Reinforced Plating  [+1 hull at setup]"},
	{"id": "Shield Capacitor",    "name": "Shield Capacitor  [+1 shield at setup]"},
	{"id": "Targeting Computer",  "name": "Targeting Computer  [+1 ATK at close range]"},
	{"id": "Veteran Reflexes",    "name": "Veteran Reflexes  [absorb first stress/mission]"},
]

var _pilots: Array = []
var _class_opts: Array = [null, null]
var _weapon_opts: Array = [null, null]
var _upgrade_opts: Array = [null, null]
var _stats_labels: Array = [null, null]
var _selected_classes: Array = ["fighter", "fighter"]


func _ready() -> void:
	_pilots = CampaignManager.deployable_pilots()
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(root)
	add_child(margin)

	var mission_name: String
	if CampaignManager.skirmish_mode:
		mission_name = "SKIRMISH"
	else:
		mission_name = CampaignManager.current_mission().get("name", "MISSION")

	var header := Label.new()
	header.text = "LOADOUT — %s" % mission_name
	header.add_theme_font_size_override("font_size", 30)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(1.0, 0.3, 0.2)
	root.add_child(header)

	root.add_child(HSeparator.new())

	var slots_row := HBoxContainer.new()
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_row.add_theme_constant_override("separation", 30)
	root.add_child(slots_row)

	for i in range(2):
		slots_row.add_child(_build_slot_column(i))

	root.add_child(HSeparator.new())

	var launch := Button.new()
	launch.text = "LAUNCH MISSION"
	launch.custom_minimum_size = Vector2(0, 52)
	launch.add_theme_font_size_override("font_size", 22)
	launch.modulate = Color(0.3, 1.0, 0.45)
	launch.pressed.connect(_on_launch)
	root.add_child(launch)

	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)


func _build_slot_column(slot_idx: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	if slot_idx >= _pilots.size():
		var empty := Label.new()
		empty.text = "SLOT %d\n\n— No pilot available —" % (slot_idx + 1)
		empty.add_theme_font_size_override("font_size", 14)
		empty.modulate = Color(0.4, 0.4, 0.4)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
		return panel

	var pilot: Dictionary = _pilots[slot_idx]
	_selected_classes[slot_idx] = pilot.get("ship_class", "fighter")

	var accent: Array = pilot.get("accent", [1.0, 1.0, 1.0])
	var pilot_lbl := Label.new()
	pilot_lbl.text = "SLOT %d — %s  [skill %d]" % [slot_idx + 1, pilot.get("name", "?"), int(pilot.get("skill", 1))]
	pilot_lbl.add_theme_font_size_override("font_size", 16)
	pilot_lbl.modulate = Color(accent[0], accent[1], accent[2])
	col.add_child(pilot_lbl)

	col.add_child(_dim_label("CLASS"))
	var class_opt := OptionButton.new()
	class_opt.custom_minimum_size = Vector2(0, 38)
	class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cid in ShipClasses.player_class_ids():
		class_opt.add_item(ShipClasses.display_name(cid))
	var class_idx: int = ShipClasses.player_class_ids().find(_selected_classes[slot_idx])
	class_opt.selected = max(0, class_idx)
	_class_opts[slot_idx] = class_opt
	col.add_child(class_opt)

	col.add_child(_dim_label("WEAPON"))
	var weapon_opt := OptionButton.new()
	weapon_opt.custom_minimum_size = Vector2(0, 38)
	weapon_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_opts[slot_idx] = weapon_opt
	col.add_child(weapon_opt)

	col.add_child(_dim_label("UPGRADE"))
	var upgrade_opt := OptionButton.new()
	upgrade_opt.custom_minimum_size = Vector2(0, 38)
	upgrade_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for up in UPGRADES:
		upgrade_opt.add_item(up["name"])
	var cur_upg: String = pilot.get("upgrade", "")
	for i in range(UPGRADES.size()):
		if UPGRADES[i]["id"] == cur_upg:
			upgrade_opt.selected = i
			break
	_upgrade_opts[slot_idx] = upgrade_opt
	col.add_child(upgrade_opt)

	col.add_child(HSeparator.new())

	var stats_lbl := Label.new()
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.modulate = Color(0.72, 0.72, 0.82)
	_stats_labels[slot_idx] = stats_lbl
	col.add_child(stats_lbl)

	# Wire signals after all slot elements exist.
	class_opt.item_selected.connect(_on_class_changed.bind(slot_idx))

	_populate_weapons(slot_idx)
	_update_stats(slot_idx)

	return panel


func _dim_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.5, 0.5, 0.55)
	return lbl


func _populate_weapons(slot_idx: int) -> void:
	var opt: OptionButton = _weapon_opts[slot_idx]
	if opt == null:
		return
	var pilot: Dictionary = _pilots[slot_idx] if slot_idx < _pilots.size() else {}
	var cls = ShipClasses.for_id(_selected_classes[slot_idx])
	var ids: Array = cls.primary_weapon_options.duplicate()
	opt.clear()
	for w in ids:
		opt.add_item(_weapon_display(w))
	opt.set_meta("weapon_ids", ids)
	var cur: String = pilot.get("weapon", "CANNONS")
	for i in range(ids.size()):
		if ids[i] == cur:
			opt.selected = i
			return
	opt.selected = 0


func _update_stats(slot_idx: int) -> void:
	var lbl: Label = _stats_labels[slot_idx]
	if lbl == null or slot_idx >= _pilots.size():
		return
	var cls = ShipClasses.for_id(_selected_classes[slot_idx])
	var pilot: Dictionary = _pilots[slot_idx]
	lbl.text = "ATK %d   DEF %d   SHD %d   HULL %d   ARC %d°\nPassive: %s     Active: %s" % [
		cls.attack, cls.defence, cls.shields, cls.hull,
		int(cls.firing_arc_degrees),
		pilot.get("passive", "—") if pilot.get("passive", "") != "" else "—",
		pilot.get("active", "—") if pilot.get("active", "") != "" else "—",
	]


func _on_class_changed(item_idx: int, slot_idx: int) -> void:
	_selected_classes[slot_idx] = ShipClasses.player_class_ids()[item_idx]
	_populate_weapons(slot_idx)
	_update_stats(slot_idx)


func _weapon_display(weapon_id: String) -> String:
	match weapon_id:
		"CANNONS":  return "Cannons"
		"BURST":    return "Burst Laser"
		"HEAVY":    return "Heavy Cannon"
		"ION":      return "Ion Cannon"
		"MISSILES": return "Missiles (×2)"
		"TURRET":   return "Rear Turret"
		_:          return weapon_id


func _on_launch() -> void:
	for slot_idx in range(mini(2, _pilots.size())):
		var pilot: Dictionary = _pilots[slot_idx]
		pilot["ship_class"] = _selected_classes[slot_idx]

		var wpn_opt: OptionButton = _weapon_opts[slot_idx]
		if wpn_opt != null and wpn_opt.selected >= 0:
			var ids: Array = wpn_opt.get_meta("weapon_ids", [])
			if wpn_opt.selected < ids.size():
				pilot["weapon"] = ids[wpn_opt.selected]

		var upg_opt: OptionButton = _upgrade_opts[slot_idx]
		if upg_opt != null and upg_opt.selected >= 0:
			pilot["upgrade"] = UPGRADES[upg_opt.selected]["id"]

	CampaignManager.save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
