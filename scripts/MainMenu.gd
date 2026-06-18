extends Control

const _KEY_ART := preload("res://Demo_assets/tittle.jpg")

var _roster_box: VBoxContainer
var _ui_layer: CanvasLayer
var _selected_btn: int = 0
var _menu_buttons: Array = []
var _arrow_label: Label = null


func _ready() -> void:
	CampaignManager.skirmish_mode = false
	CampaignManager.reset_test_mode()
	_build_ui()
	AudioManager.play_music("music_title", 2.0)


func _build_ui() -> void:
	# ── Key art background (full-screen, behind everything) ──────────────────
	var bg := TextureRect.new()
	bg.texture = _KEY_ART
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Darkening overlay so text is readable
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.12, 0.72)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── UILayer — all menu elements ──────────────────────────────────────────
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 1
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)

	# Fade-in starts invisible
	var ui_root := Control.new()
	ui_root.anchor_right = 1.0
	ui_root.anchor_bottom = 1.0
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	ui_root.name = "UIRoot"
	_ui_layer.add_child(ui_root)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	ui_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(680, 0)
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "THE LONG RETREAT"
	title.add_theme_font_override("font", UIConstants.FONT_NARR_BOLD)
	title.add_theme_font_size_override("font_size", UIConstants.SIZE_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Escape is the only victory."
	subtitle.add_theme_font_override("font", UIConstants.FONT_NARR)
	subtitle.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	_build_engine_bar(vbox)
	vbox.add_child(HSeparator.new())
	_build_mission_card(vbox)
	vbox.add_child(HSeparator.new())

	var roster_hdr := Label.new()
	roster_hdr.text = "SQUADRON"
	roster_hdr.add_theme_font_override("font", UIConstants.FONT_UI)
	roster_hdr.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	roster_hdr.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
	vbox.add_child(roster_hdr)

	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 2)
	vbox.add_child(_roster_box)

	vbox.add_child(HSeparator.new())

	# Quote
	var quote := Label.new()
	quote.text = "Space is vast.\nThe war is endless.\nAll we can do is pull back...\nand live to fight again."
	quote.add_theme_font_override("font", UIConstants.FONT_NARR)
	quote.add_theme_font_size_override("font_size", 12)
	quote.add_theme_color_override("font_color", Color(UIConstants.COLOR_SILVER, 0.7))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(quote)

	vbox.add_child(HSeparator.new())

	# ── Menu buttons with ▶ indicator ────────────────────────────────────────
	_menu_buttons.clear()
	var btn_defs: Array = []

	var w: int = int(CampaignManager.skirmish_record.get("w", 0))
	var l: int = int(CampaignManager.skirmish_record.get("l", 0))
	btn_defs.append(["SKIRMISH  (W %d / L %d)" % [w, l],
		func(): get_tree().change_scene_to_file("res://scenes/SkirmishSetup.tscn")])
	btn_defs.append(["TEST MISSIONS",
		func(): get_tree().change_scene_to_file("res://scenes/MissionSelectMenu.tscn")])
	btn_defs.append(["RESET CAMPAIGN", _on_reset])

	_arrow_label = Label.new()
	_arrow_label.text = "▶"
	_arrow_label.add_theme_font_override("font", UIConstants.FONT_UI)
	_arrow_label.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
	_arrow_label.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)

	for i in range(btn_defs.size()):
		var def: Array = btn_defs[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var arrow_slot := Label.new()
		arrow_slot.text = "▶"
		arrow_slot.add_theme_font_override("font", UIConstants.FONT_UI)
		arrow_slot.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
		arrow_slot.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
		arrow_slot.visible = (i == _selected_btn)
		row.add_child(arrow_slot)

		var btn := Button.new()
		btn.text = def[0]
		btn.add_theme_font_override("font", UIConstants.FONT_UI)
		btn.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
		btn.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
		btn.add_theme_color_override("font_hover_color", UIConstants.COLOR_CYAN)
		btn.add_theme_color_override("font_focus_color", UIConstants.COLOR_CYAN)
		btn.add_theme_color_override("font_pressed_color", UIConstants.COLOR_WHITE)
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		flat.draw_center = false
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(state, flat)
		btn.flat = true
		btn.set_meta("arrow_slot", arrow_slot)
		btn.set_meta("btn_index", i)
		btn.pressed.connect(def[1])
		btn.pressed.connect(func(): AudioManager.play_sfx("sfx_click"))
		btn.mouse_entered.connect(func(): AudioManager.play_sfx("sfx_hover"))
		btn.focus_entered.connect(_on_btn_focus.bind(btn))
		row.add_child(btn)
		vbox.add_child(row)
		_menu_buttons.append(btn)

	_refresh_roster()

	# ── Fade-in sequence ─────────────────────────────────────────────────────
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(ui_root, "modulate:a", 1.0, 1.5)


func _on_btn_focus(btn: Button) -> void:
	for b in _menu_buttons:
		var slot: Label = b.get_meta("arrow_slot", null)
		if slot != null:
			slot.visible = (b == btn)


func _build_engine_bar(parent: VBoxContainer) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	var dist: int = int(CampaignManager.distance)
	var closing: bool = CampaignManager.distance < CampaignManager.ENGINE_THRESHOLD
	label.text = "THE THRESHING ENGINE     %s" % ("CLOSING — it will appear next sortie" if closing else "distance %d" % dist)
	label.add_theme_font_override("font", UIConstants.FONT_UI)
	label.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	label.add_theme_color_override("font_color",
		UIConstants.COLOR_HULL_CRIT if closing else UIConstants.COLOR_SILVER)
	row.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(680, 18)
	bar.min_value = 0
	bar.max_value = CampaignManager.DISTANCE_MAX
	bar.value = CampaignManager.distance
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIConstants.COLOR_HULL_CRIT if closing else UIConstants.COLOR_SHIELD
	bar.add_theme_stylebox_override("fill", fill)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = UIConstants.COLOR_BG_SECONDARY
	bar.add_theme_stylebox_override("background", bgs)
	row.add_child(bar)


func _build_mission_card(parent: VBoxContainer) -> void:
	if CampaignManager.is_campaign_complete():
		var done := Label.new()
		done.text = "CAMPAIGN COMPLETE — you made the jump."
		done.add_theme_font_override("font", UIConstants.FONT_NARR)
		done.add_theme_font_size_override("font_size", UIConstants.SIZE_HEADING)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
		parent.add_child(done)

		var replay := Button.new()
		replay.text = "NEW CAMPAIGN"
		replay.custom_minimum_size = Vector2(680, 44)
		replay.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
		replay.add_theme_font_size_override("font_size", UIConstants.SIZE_HEADING)
		replay.pressed.connect(_on_reset)
		parent.add_child(replay)
		return

	var m: Dictionary = CampaignManager.current_mission()
	var act: int = int(m.get("act", 0))
	var act_name: String = ["TUTORIAL", "ACT 1 — DESPERATE", "ACT 2 — THE TURN", "ACT 3 — THE RUN"][clampi(act, 0, 3)]

	var hdr := Label.new()
	hdr.text = act_name
	hdr.add_theme_font_override("font", UIConstants.FONT_UI)
	hdr.add_theme_font_size_override("font_size", UIConstants.SIZE_TINY)
	hdr.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
	parent.add_child(hdr)

	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [m.get("id", ""), m.get("name", "")]
	name_lbl.add_theme_font_override("font", UIConstants.FONT_NARR_BOLD)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
	parent.add_child(name_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = "Objective:  " + _objective_desc(m.get("objective", {}))
	obj_lbl.add_theme_font_override("font", UIConstants.FONT_UI)
	obj_lbl.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	obj_lbl.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
	parent.add_child(obj_lbl)

	if CampaignManager.engine_present():
		var eng := Label.new()
		if m.get("advancing", false):
			eng.text = "⚠  THE ENGINE BEARS DOWN — a Danger Zone sweeps the map. Flee to the jump point."
		else:
			eng.text = "⚠  THE ENGINE IS PRESENT — its turrets will be on the map edge."
		eng.add_theme_font_override("font", UIConstants.FONT_UI)
		eng.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
		eng.add_theme_color_override("font_color", UIConstants.COLOR_HULL_CRIT)
		parent.add_child(eng)

	var deploy := Button.new()
	deploy.text = "DEPLOY  ▶"
	deploy.custom_minimum_size = Vector2(680, 48)
	deploy.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	deploy.add_theme_font_size_override("font_size", 20)
	deploy.add_theme_color_override("font_color", UIConstants.COLOR_GREEN_DIAL)
	deploy.add_theme_color_override("font_hover_color", UIConstants.COLOR_WHITE)
	deploy.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn"))
	deploy.pressed.connect(func(): AudioManager.play_sfx("sfx_click"))
	deploy.mouse_entered.connect(func(): AudioManager.play_sfx("sfx_hover"))
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
		row.add_theme_font_override("font", UIConstants.FONT_UI)
		row.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
		if status == "dead":
			row.add_theme_color_override("font_color", UIConstants.COLOR_INACTIVE)
		elif is_drone:
			row.add_theme_color_override("font_color", Color(UIConstants.COLOR_INACTIVE, 0.8))
		elif status == "injured":
			row.add_theme_color_override("font_color", UIConstants.COLOR_AMBER)
		else:
			row.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
		_roster_box.add_child(row)


func _on_reset() -> void:
	CampaignManager.reset_campaign()
	for child in get_children():
		child.queue_free()
	_build_ui()
