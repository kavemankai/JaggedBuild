extends Control

const ShipClasses := preload("res://scripts/ShipClasses.gd")

const UPGRADES: Array = [
	{"id": "",                    "name": "None"},
	{"id": "Reinforced Plating",  "name": "Reinforced Plating  [+1 hull]"},
	{"id": "Shield Capacitor",    "name": "Shield Capacitor  [+1 shield]"},
	{"id": "Targeting Computer",  "name": "Targeting Computer  [+1 ATK close]"},
	{"id": "Veteran Reflexes",    "name": "Veteran Reflexes  [absorb 1 stress]"},
]

const SLOTS: int = 2

var _deployable: Array = []
var _slot_pilot: Array = [null, null]          # selected roster entry per slot
var _pilot_opts: Array = [null, null]
var _class_opts: Array = [null, null]
var _weapon_opts: Array = [null, null]
var _upgrade_opts: Array = [null, null]
var _stats_labels: Array = [null, null]
var _selected_classes: Array = ["fighter", "fighter"]


func _ready() -> void:
	_deployable = CampaignManager.deployable_pilots()
	# Sensible defaults: first two distinct deployable pilots.
	_slot_pilot[0] = _deployable[0] if _deployable.size() >= 1 else null
	_slot_pilot[1] = _deployable[1] if _deployable.size() >= 2 else null
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var mission_name: String
	if CampaignManager.skirmish_mode:
		mission_name = "SKIRMISH"
	else:
		mission_name = CampaignManager.current_mission().get("name", "MISSION")

	var header := Label.new()
	header.text = "LOADOUT — %s" % mission_name
	header.add_theme_font_size_override("font_size", 28)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(1.0, 0.3, 0.2)
	root.add_child(header)

	# Role-based briefing transmission (campaign only).
	if not CampaignManager.skirmish_mode:
		var beat: Dictionary = CampaignManager.resolve_beat(CampaignManager.current_mission())
		if not beat.is_empty():
			var panel := PanelContainer.new()
			var bx := VBoxContainer.new()
			panel.add_child(bx)
			var who := Label.new()
			who.text = "▶ TRANSMISSION — %s" % beat.get("speaker", "COMMAND")
			who.add_theme_font_size_override("font_size", 12)
			who.modulate = Color(0.5, 0.8, 1.0)
			bx.add_child(who)
			var line := Label.new()
			line.text = "\"%s\"" % beat.get("text", "")
			line.add_theme_font_size_override("font_size", 14)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size = Vector2(900, 0)
			line.modulate = Color(0.85, 0.85, 0.9)
			bx.add_child(line)
			root.add_child(panel)

	root.add_child(HSeparator.new())

	var slots_row := HBoxContainer.new()
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_row.add_theme_constant_override("separation", 30)
	root.add_child(slots_row)

	for i in range(SLOTS):
		slots_row.add_child(_build_slot_column(i))

	root.add_child(HSeparator.new())

	var launch := Button.new()
	launch.text = "LAUNCH MISSION"
	launch.custom_minimum_size = Vector2(0, 50)
	launch.add_theme_font_size_override("font_size", 22)
	launch.modulate = Color(0.3, 1.0, 0.45)
	launch.pressed.connect(_on_launch)
	root.add_child(launch)

	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)


func _build_slot_column(slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var hdr := Label.new()
	hdr.text = "SLOT %d" % (slot + 1)
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.modulate = Color(0.7, 0.7, 0.8)
	col.add_child(hdr)

	if _slot_pilot[slot] == null:
		var empty := Label.new()
		empty.text = "— No pilot available —"
		empty.modulate = Color(0.4, 0.4, 0.4)
		col.add_child(empty)
		return panel

	col.add_child(_dim("PILOT"))
	var pilot_opt := OptionButton.new()
	pilot_opt.custom_minimum_size = Vector2(0, 36)
	pilot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pilot_opts[slot] = pilot_opt
	col.add_child(pilot_opt)
	_populate_pilots(slot)
	pilot_opt.item_selected.connect(_on_pilot_changed.bind(slot))

	col.add_child(_dim("CLASS"))
	var class_opt := OptionButton.new()
	class_opt.custom_minimum_size = Vector2(0, 36)
	class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cid in ShipClasses.player_class_ids():
		class_opt.add_item(ShipClasses.display_name(cid))
	_class_opts[slot] = class_opt
	col.add_child(class_opt)
	class_opt.item_selected.connect(_on_class_changed.bind(slot))

	col.add_child(_dim("WEAPON"))
	var weapon_opt := OptionButton.new()
	weapon_opt.custom_minimum_size = Vector2(0, 36)
	weapon_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_opts[slot] = weapon_opt
	col.add_child(weapon_opt)

	col.add_child(_dim("UPGRADE"))
	var upgrade_opt := OptionButton.new()
	upgrade_opt.custom_minimum_size = Vector2(0, 36)
	upgrade_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for up in UPGRADES:
		upgrade_opt.add_item(up["name"])
	_upgrade_opts[slot] = upgrade_opt
	col.add_child(upgrade_opt)

	col.add_child(HSeparator.new())
	var stats := Label.new()
	stats.add_theme_font_size_override("font_size", 12)
	stats.modulate = Color(0.72, 0.72, 0.82)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_labels[slot] = stats
	col.add_child(stats)

	# Initialise dropdowns from the slot's pilot.
	_sync_slot_to_pilot(slot)
	return panel


func _dim(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.5, 0.5, 0.55)
	return lbl


# Fill a slot's pilot dropdown with deployable pilots, excluding the OTHER slot's pick.
func _populate_pilots(slot: int) -> void:
	var opt: OptionButton = _pilot_opts[slot]
	if opt == null:
		return
	var other: Variant = _slot_pilot[1 - slot]
	var ids: Array = []
	opt.clear()
	for entry in _deployable:
		if entry == other and entry != _slot_pilot[slot]:
			continue
		var label: String = entry.get("name", "?")
		if entry.get("is_drone", false):
			label += "  [drone]"
		elif entry.get("commander", false):
			label += "  ★"
		label += "  (skill %d)" % int(entry.get("skill", 1))
		opt.add_item(label)
		ids.append(entry)
	opt.set_meta("pilot_ids", ids)
	# Select the slot's current pilot.
	for i in range(ids.size()):
		if ids[i] == _slot_pilot[slot]:
			opt.selected = i
			return
	if not ids.is_empty():
		opt.selected = 0
		_slot_pilot[slot] = ids[0]


func _on_pilot_changed(item_idx: int, slot: int) -> void:
	var ids: Array = _pilot_opts[slot].get_meta("pilot_ids", [])
	if item_idx < 0 or item_idx >= ids.size():
		return
	_slot_pilot[slot] = ids[item_idx]
	_sync_slot_to_pilot(slot)
	# Rebuild the sibling's pilot list so the new pick can't be duplicated.
	_populate_pilots(1 - slot)


# Set a slot's class/weapon/upgrade dropdowns to its pilot's stored loadout.
func _sync_slot_to_pilot(slot: int) -> void:
	var pilot: Dictionary = _slot_pilot[slot]
	if pilot.is_empty():
		return
	_selected_classes[slot] = pilot.get("ship_class", "fighter")
	var class_opt: OptionButton = _class_opts[slot]
	var cidx: int = ShipClasses.player_class_ids().find(_selected_classes[slot])
	class_opt.selected = max(0, cidx)

	_populate_weapons(slot)

	var upg_opt: OptionButton = _upgrade_opts[slot]
	var cur_upg: String = pilot.get("upgrade", "")
	upg_opt.selected = 0
	for i in range(UPGRADES.size()):
		if UPGRADES[i]["id"] == cur_upg:
			upg_opt.selected = i
			break

	_update_stats(slot)


func _populate_weapons(slot: int) -> void:
	var opt: OptionButton = _weapon_opts[slot]
	if opt == null:
		return
	var cls = ShipClasses.for_id(_selected_classes[slot])
	var ids: Array = cls.primary_weapon_options.duplicate()
	opt.clear()
	for wid in ids:
		opt.add_item(_weapon_display(wid))
	opt.set_meta("weapon_ids", ids)
	var cur: String = _slot_pilot[slot].get("weapon", "CANNONS")
	opt.selected = 0
	for i in range(ids.size()):
		if ids[i] == cur:
			opt.selected = i
			break


func _on_class_changed(item_idx: int, slot: int) -> void:
	_selected_classes[slot] = ShipClasses.player_class_ids()[item_idx]
	_populate_weapons(slot)
	_update_stats(slot)


func _update_stats(slot: int) -> void:
	var lbl: Label = _stats_labels[slot]
	if lbl == null:
		return
	var cls = ShipClasses.for_id(_selected_classes[slot])
	var pilot: Dictionary = _slot_pilot[slot]
	var passive: String = pilot.get("passive", "")
	var active: String = pilot.get("active", "")
	lbl.text = "ATK %d  DEF %d  SHD %d  HULL %d  ARC %d°\nPassive: %s   Active: %s" % [
		cls.attack, cls.defence, cls.shields, cls.hull, int(cls.firing_arc_degrees),
		passive if passive != "" else "—",
		active if active != "" else "—",
	]


func _weapon_display(weapon_id: String) -> String:
	match weapon_id:
		"CANNONS":  return "Cannons"
		"BURST":    return "Burst Laser"
		"HEAVY":    return "Heavy Cannon"
		"ION":      return "Ion Cannon"
		"MISSILES": return "Missiles (x2)"
		_:          return weapon_id


func _on_launch() -> void:
	var deployment: Array = []
	for slot in range(SLOTS):
		var pilot: Variant = _slot_pilot[slot]
		if pilot == null or (pilot is Dictionary and pilot.is_empty()):
			continue
		if deployment.has(pilot.get("name", "")):
			continue   # guard against any duplicate slipping through

		pilot["ship_class"] = _selected_classes[slot]

		var wpn_opt: OptionButton = _weapon_opts[slot]
		if wpn_opt != null and wpn_opt.selected >= 0:
			var wids: Array = wpn_opt.get_meta("weapon_ids", [])
			if wpn_opt.selected < wids.size():
				pilot["weapon"] = wids[wpn_opt.selected]

		var upg_opt: OptionButton = _upgrade_opts[slot]
		if upg_opt != null and upg_opt.selected >= 0:
			pilot["upgrade"] = UPGRADES[upg_opt.selected]["id"]

		deployment.append(pilot.get("name", ""))

	CampaignManager.selected_deployment = deployment
	CampaignManager.save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
