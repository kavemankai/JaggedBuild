# DemoLoadout.gd
# Demo loadout — fixed configuration, no choices. Shows the player's ship class,
# weapon, and pilot, then LAUNCH moves to the battle. No roster, no campaign.
extends Control


func _ready() -> void:
	DemoConfig.reset()
	anchor_right = 1.0
	anchor_bottom = 1.0

	var bg := ColorRect.new()
	bg.color = UIConstants.COLOR_BG_PRIMARY
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "CONFIGURE YOUR SHIP"
	title.add_theme_font_override("font", UIConstants.FONT_NARR_BOLD)
	title.add_theme_font_size_override("font_size", UIConstants.SIZE_HEADING)
	title.add_theme_color_override("font_color", UIConstants.COLOR_WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 120)
	title.size = Vector2(1600, 30)
	add_child(title)

	var y: float = 250.0
	_line("SHIP CLASS", "Wraith Fighter", y); y += 55.0
	_line("PRIMARY WEAPON", "Cannons", y); y += 55.0
	_line("SECONDARY WEAPON", "Missiles (6)", y); y += 55.0
	_line("PILOT", "WARDEN  -  Skill 4  -  MARKSMAN / OVERCHARGE", y)

	var launch := Button.new()
	launch.text = "LAUNCH"
	launch.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	launch.add_theme_font_size_override("font_size", 16)
	launch.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
	launch.add_theme_color_override("font_hover_color", UIConstants.COLOR_WHITE)
	launch.add_theme_stylebox_override("normal", _cyan_border())
	launch.add_theme_stylebox_override("hover", _cyan_border())
	launch.add_theme_stylebox_override("pressed", _cyan_border())
	launch.custom_minimum_size = Vector2(220, 52)
	launch.position = Vector2(690, 560)
	launch.focus_mode = Control.FOCUS_NONE
	launch.pressed.connect(_on_launch)
	add_child(launch)


func _line(label_text: String, value_text: String, y: float) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	lbl.add_theme_font_size_override("font_size", UIConstants.SIZE_LABEL)
	lbl.add_theme_color_override("font_color", UIConstants.COLOR_SILVER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, y)
	lbl.size = Vector2(1600, 20)
	add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_override("font", UIConstants.FONT_UI)
	val.add_theme_font_size_override("font_size", UIConstants.SIZE_BODY)
	val.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.position = Vector2(0, y + 22.0)
	val.size = Vector2(1600, 24)
	add_child(val)


func _cyan_border() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIConstants.COLOR_BG_PANEL
	s.border_color = UIConstants.COLOR_CYAN
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(6)
	return s


func _on_launch() -> void:
	AudioManager.play_sfx("sfx_confirm")
	get_tree().change_scene_to_file("res://scenes/DemoBattle.tscn")
