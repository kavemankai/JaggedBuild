extends Control

var _roster_box: VBoxContainer
var _mission_btns: Array = []


func _ready() -> void:
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
	vbox.custom_minimum_size = Vector2(620, 0)
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "DOGFIGHT PROTO"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.3, 0.2)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var roster_hdr := Label.new()
	roster_hdr.text = "PILOTS"
	roster_hdr.add_theme_font_size_override("font_size", 13)
	roster_hdr.modulate = Color(0.55, 0.55, 0.6)
	vbox.add_child(roster_hdr)

	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_roster_box)

	vbox.add_child(HSeparator.new())

	var mission_hdr := Label.new()
	mission_hdr.text = "SELECT MISSION"
	mission_hdr.add_theme_font_size_override("font_size", 13)
	mission_hdr.modulate = Color(0.55, 0.55, 0.6)
	vbox.add_child(mission_hdr)

	_mission_btns.clear()
	var missions: Array = CampaignManager.get_missions()
	for i in range(missions.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(620, 44)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_mission_selected.bind(i))
		_mission_btns.append(btn)
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	var reset_btn := Button.new()
	reset_btn.text = "RESET CAMPAIGN"
	reset_btn.custom_minimum_size = Vector2(620, 36)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.modulate = Color(0.9, 0.45, 0.45)
	reset_btn.pressed.connect(_on_reset)
	vbox.add_child(reset_btn)

	_refresh_display()


func _refresh_display() -> void:
	for child in _roster_box.get_children():
		child.queue_free()

	for entry in CampaignManager.roster:
		var pname: String = entry.get("name", "?")
		var skill: int = int(entry.get("skill", 1))
		var xp: int = int(entry.get("xp", 0))
		var status: String = entry.get("status", "healthy")

		var row := Label.new()
		row.text = "%s   skill %d   xp %d   %s" % [pname, skill, xp, status.to_upper()]
		row.add_theme_font_size_override("font_size", 15)
		match status:
			"dead":     row.modulate = Color(0.32, 0.32, 0.32)
			"injured":  row.modulate = Color(1.0, 0.6, 0.2)
			_:          row.modulate = Color(0.9, 0.9, 0.9)
		_roster_box.add_child(row)

	var missions: Array = CampaignManager.get_missions()
	for i in range(_mission_btns.size()):
		var btn: Button = _mission_btns[i]
		var m: Dictionary = missions[i]
		var current_tag: String = "  ◄ CURRENT" if i == CampaignManager.mission_index else ""
		btn.text = "MISSION %d — %s%s" % [i + 1, m.get("name", ""), current_tag]


func _on_mission_selected(idx: int) -> void:
	CampaignManager.mission_index = idx
	CampaignManager.save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_reset() -> void:
	CampaignManager.reset_campaign()
	_refresh_display()
