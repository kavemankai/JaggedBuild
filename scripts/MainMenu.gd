extends Control

var _roster_box: VBoxContainer


func _ready() -> void:
	CampaignManager.skirmish_mode = false
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(680, 0)
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "THE LONG RETREAT"
	title.add_theme_font_size_override("font_size", 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.3, 0.2)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Escape is the only victory."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.55, 0.55, 0.65)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	_build_engine_bar(vbox)
	vbox.add_child(HSeparator.new())
	_build_mission_card(vbox)
	vbox.add_child(HSeparator.new())

	# Roster
	var roster_hdr := Label.new()
	roster_hdr.text = "SQUADRON"
	roster_hdr.add_theme_font_size_override("font_size", 13)
	roster_hdr.modulate = Color(0.55, 0.55, 0.6)
	vbox.add_child(roster_hdr)

	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_roster_box)

	vbox.add_child(HSeparator.new())

	# Skirmish + reset row
	var skirmish_btn := Button.new()
	var w: int = int(CampaignManager.skirmish_record.get("w", 0))
	var l: int = int(CampaignManager.skirmish_record.get("l", 0))
	skirmish_btn.text = "SKIRMISH  (W %d / L %d)" % [w, l]
	skirmish_btn.custom_minimum_size = Vector2(680, 38)
	skirmish_btn.add_theme_font_size_override("font_size", 15)
	skirmish_btn.modulate = Color(0.8, 0.8, 1.0)
	skirmish_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/SkirmishSetup.tscn"))
	vbox.add_child(skirmish_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET CAMPAIGN"
	reset_btn.custom_minimum_size = Vector2(680, 32)
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.modulate = Color(0.9, 0.45, 0.45)
	reset_btn.pressed.connect(_on_reset)
	vbox.add_child(reset_btn)

	_refresh_roster()


func _build_engine_bar(parent: VBoxContainer) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	var dist: int = int(CampaignManager.distance)
	var closing: bool = CampaignManager.distance < CampaignManager.ENGINE_THRESHOLD
	label.text = "THE THRESHING ENGINE     %s" % ("CLOSING — it will appear next sortie" if closing else "distance %d" % dist)
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(1.0, 0.35, 0.3) if closing else Color(0.7, 0.7, 0.75)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(680, 18)
	bar.min_value = 0
	bar.max_value = CampaignManager.DISTANCE_MAX
	bar.value = CampaignManager.distance
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.3, 0.25) if closing else Color(0.3, 0.7, 0.9)
	bar.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.12, 0.1, 0.1, 0.9)
	bar.add_theme_stylebox_override("background", bgs)
	row.add_child(bar)


func _build_mission_card(parent: VBoxContainer) -> void:
	if CampaignManager.is_campaign_complete():
		var done := Label.new()
		done.text = "CAMPAIGN COMPLETE — you made the jump."
		done.add_theme_font_size_override("font_size", 18)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.modulate = Color(0.4, 1.0, 0.5)
		parent.add_child(done)

		var replay := Button.new()
		replay.text = "NEW CAMPAIGN"
		replay.custom_minimum_size = Vector2(680, 44)
		replay.add_theme_font_size_override("font_size", 18)
		replay.pressed.connect(_on_reset)
		parent.add_child(replay)
		return

	var m: Dictionary = CampaignManager.current_mission()
	var act: int = int(m.get("act", 0))
	var act_name: String = ["TUTORIAL", "ACT 1 — DESPERATE", "ACT 2 — THE TURN", "ACT 3 — THE RUN"][clampi(act, 0, 3)]

	var hdr := Label.new()
	hdr.text = act_name
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.modulate = Color(0.55, 0.55, 0.6)
	parent.add_child(hdr)

	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [m.get("id", ""), m.get("name", "")]
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.modulate = Color(1.0, 0.85, 0.4)
	parent.add_child(name_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = "Objective:  " + _objective_desc(m.get("objective", {}))
	obj_lbl.add_theme_font_size_override("font_size", 14)
	obj_lbl.modulate = Color(0.7, 0.95, 0.75)
	parent.add_child(obj_lbl)

	if CampaignManager.engine_present():
		var eng := Label.new()
		if m.get("advancing", false):
			eng.text = "⚠  THE ENGINE BEARS DOWN — a Danger Zone sweeps the map. Flee to the jump point."
		else:
			eng.text = "⚠  THE ENGINE IS PRESENT — its turrets will be on the map edge."
		eng.add_theme_font_size_override("font_size", 13)
		eng.modulate = Color(1.0, 0.4, 0.35)
		parent.add_child(eng)

	var deploy := Button.new()
	deploy.text = "DEPLOY  ▶"
	deploy.custom_minimum_size = Vector2(680, 48)
	deploy.add_theme_font_size_override("font_size", 20)
	deploy.modulate = Color(0.35, 1.0, 0.5)
	deploy.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn"))
	parent.add_child(deploy)


func _objective_desc(obj: Dictionary) -> String:
	match obj.get("type", "DESTROY_ALL"):
		"SURVIVE_ROUNDS": return "Survive %d rounds" % int(obj.get("rounds", 5))
		"HOLD_POSITION":  return "Hold position for %d rounds" % int(obj.get("rounds", 5))
		"REACH_EDGE":     return "Break through to the far edge"
		"PROTECT":        return "Protect the transport — destroy all attackers"
		_:                return "Destroy all enemies"


func _refresh_roster() -> void:
	for child in _roster_box.get_children():
		child.queue_free()

	for entry in CampaignManager.roster:
		var pname: String = entry.get("name", "?")
		var skill: int = int(entry.get("skill", 1))
		var status: String = entry.get("status", "healthy")
		var is_drone: bool = entry.get("is_drone", false)
		var tag: String = ""
		if entry.get("commander", false):
			tag = "  ★CO"
		elif is_drone:
			tag = "  [DRONE]"

		var row := Label.new()
		var cls: String = entry.get("ship_class", "fighter").replace("_", " ")
		row.text = "%s%s   skill %d   %s   %s" % [pname, tag, skill, status.to_upper(), cls.to_upper()]
		row.add_theme_font_size_override("font_size", 14)
		if status == "dead":
			row.modulate = Color(0.3, 0.3, 0.3)
		elif is_drone:
			row.modulate = Color(0.5, 0.5, 0.55)
		elif status == "injured":
			row.modulate = Color(1.0, 0.6, 0.2)
		else:
			row.modulate = Color(0.9, 0.9, 0.9)
		_roster_box.add_child(row)


func _on_reset() -> void:
	CampaignManager.reset_campaign()
	# Rebuild the whole menu so the mission card / engine bar refresh.
	for child in get_children():
		child.queue_free()
	_build_ui()
