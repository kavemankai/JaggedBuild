extends Control

const ENEMY_CLASS_IDS: Array = ["enemy_fighter", "enemy_scout", "enemy_assault"]
const ENEMY_CLASS_NAMES: Array = ["Fighter", "Scout", "Assault"]

var _manual_opts: Array = []  # OptionButtons per enemy slot (0=None, 1-3=class)
var _squad_opt: OptionButton = null   # player squad size (1-4)


func _ready() -> void:
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
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := Label.new()
	header.text = "SKIRMISH SETUP"
	header.add_theme_font_size_override("font_size", 32)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(1.0, 0.3, 0.2)
	root.add_child(header)

	var record_lbl := Label.new()
	var w: int = int(CampaignManager.skirmish_record.get("w", 0))
	var l: int = int(CampaignManager.skirmish_record.get("l", 0))
	record_lbl.text = "Skirmish record:  W %d  /  L %d" % [w, l]
	record_lbl.add_theme_font_size_override("font_size", 14)
	record_lbl.modulate = Color(0.65, 0.65, 0.7)
	record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(record_lbl)

	root.add_child(HSeparator.new())

	# ── YOUR SQUAD ──────────────────────────────────────────────────────────
	var squad_row := HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 12)
	root.add_child(squad_row)
	var squad_lbl := Label.new()
	squad_lbl.text = "YOUR SQUAD"
	squad_lbl.add_theme_font_size_override("font_size", 15)
	squad_lbl.modulate = Color(0.55, 0.55, 0.6)
	squad_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	squad_row.add_child(squad_lbl)
	_squad_opt = OptionButton.new()
	_squad_opt.custom_minimum_size = Vector2(220, 34)
	for n in range(1, 5):
		_squad_opt.add_item("%d ship%s" % [n, "" if n == 1 else "s"])
	var avail: int = mini(4, CampaignManager.deployable_pilots().size())
	_squad_opt.selected = clampi(avail - 1, 0, 3)
	squad_row.add_child(_squad_opt)

	root.add_child(HSeparator.new())

	# ── RANDOM SECTION ──────────────────────────────────────────────────────
	var rand_hdr := Label.new()
	rand_hdr.text = "RANDOM ENCOUNTER"
	rand_hdr.add_theme_font_size_override("font_size", 15)
	rand_hdr.modulate = Color(0.55, 0.55, 0.6)
	root.add_child(rand_hdr)

	var rand_info := Label.new()
	rand_info.text = "2-6 enemies, random classes."
	rand_info.add_theme_font_size_override("font_size", 13)
	rand_info.modulate = Color(0.7, 0.7, 0.75)
	root.add_child(rand_info)

	var rand_btn := Button.new()
	rand_btn.text = "RANDOMIZE & LAUNCH"
	rand_btn.custom_minimum_size = Vector2(0, 46)
	rand_btn.add_theme_font_size_override("font_size", 18)
	rand_btn.pressed.connect(_on_random)
	root.add_child(rand_btn)

	root.add_child(HSeparator.new())

	# ── MANUAL SECTION ──────────────────────────────────────────────────────
	var man_hdr := Label.new()
	man_hdr.text = "MANUAL SETUP"
	man_hdr.add_theme_font_size_override("font_size", 15)
	man_hdr.modulate = Color(0.55, 0.55, 0.6)
	root.add_child(man_hdr)

	var man_row := HBoxContainer.new()
	man_row.add_theme_constant_override("separation", 16)
	root.add_child(man_row)

	for i in range(6):
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = "Enemy %d" % (i + 1)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(0.6, 0.6, 0.65)
		col.add_child(lbl)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(0, 36)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_item("None")
		for cls_name in ENEMY_CLASS_NAMES:
			opt.add_item(cls_name)
		opt.selected = 1 if i < 2 else 0   # default: two Fighters, rest None
		_manual_opts.append(opt)
		col.add_child(opt)
		man_row.add_child(col)

	var man_launch := Button.new()
	man_launch.text = "LAUNCH CUSTOM"
	man_launch.custom_minimum_size = Vector2(0, 46)
	man_launch.add_theme_font_size_override("font_size", 18)
	man_launch.pressed.connect(_on_manual_launch)
	root.add_child(man_launch)

	root.add_child(HSeparator.new())

	var back := Button.new()
	back.text = "← BACK"
	back.custom_minimum_size = Vector2(0, 36)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	root.add_child(back)


func _squad_size() -> int:
	return (_squad_opt.selected + 1) if _squad_opt != null else 2


func _on_random() -> void:
	var count: int = randi_range(2, 6)
	var specs: Array = []
	for _i in range(count):
		specs.append(_make_enemy(ENEMY_CLASS_IDS[randi() % ENEMY_CLASS_IDS.size()]))
	CampaignManager.start_skirmish(specs, _squad_size())
	get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn")


func _on_manual_launch() -> void:
	var specs: Array = []
	for opt in _manual_opts:
		var sel: int = (opt as OptionButton).selected
		if sel <= 0:
			continue  # None
		specs.append(_make_enemy(ENEMY_CLASS_IDS[sel - 1]))
	if specs.is_empty():
		return  # nothing selected
	CampaignManager.start_skirmish(specs, _squad_size())
	get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn")


func _make_enemy(class_id: String) -> Dictionary:
	var skill: int = randi_range(2, 3)
	var accent_map: Dictionary = {
		"enemy_fighter": [0.55, 0.2, 0.55],
		"enemy_scout":   [0.2, 0.55, 0.55],
		"enemy_assault": [0.7, 0.25, 0.2],
	}
	var name_map: Dictionary = {
		"enemy_fighter": "BANDIT",
		"enemy_scout":   "VIPER",
		"enemy_assault": "FANG",
	}
	var stat_map: Dictionary = {
		"enemy_fighter": {"attack": 2, "defence": 2, "shields": 2, "hull": 3, "weapon": "CANNONS"},
		"enemy_scout":   {"attack": 1, "defence": 3, "shields": 1, "hull": 2, "weapon": "ION"},
		"enemy_assault": {"attack": 3, "defence": 1, "shields": 2, "hull": 3, "weapon": "BURST"},
	}
	var stats: Dictionary = stat_map.get(class_id, stat_map["enemy_fighter"])
	return {
		"name": name_map.get(class_id, "BANDIT"),
		"base_skill": skill, "skill": skill,
		"accuracy": 1.0, "agility": 1.1, "nerve": 0.1,
		"passive": "", "active": "",
		"weapon": stats["weapon"],
		"attack": stats["attack"], "defence": stats["defence"],
		"shields": stats["shields"], "hull": stats["hull"],
		"accent": accent_map.get(class_id, [0.6, 0.6, 0.6]),
		"xp": 0, "kills": 0, "status": "healthy",
		"ship_class": class_id, "upgrade": "",
	}
