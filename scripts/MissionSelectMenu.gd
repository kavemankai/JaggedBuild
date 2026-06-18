extends Control

# Developer test tool: jump to any mission directly without playing through the campaign.
# test_mode is set true so record_battle() is a no-op and the battle returns here, not MainMenu.

const ENEMY_CLASS_IDS: Array = ["enemy_fighter", "enemy_scout", "enemy_assault"]
const ENEMY_CLASS_NAMES: Array = ["Fighter", "Scout", "Assault"]

# [display_name, mission_index] — indices match CampaignManager.get_missions() order.
const MISSIONS: Array = [
	["T1 — FIRST LIGHT",      0],
	["T2 — TEETH",            1],
	["T3 — THE SHADOW",       2],
	["M1 — REARGUARD",        3],
	["M2 — STRAGGLERS",       4],
	["M3 — THE NET",          5],
	["M4 — THRESHING",        6],
	["M5 — A WAY OUT",        7],
	["M6 — BUYING TIME",      8],
	["M7 — THE GAUNTLET",     9],
	["M8 — RECKONING",       10],
	["M9 — BREATHING ROOM",  11],
	["M10 — NO TURNING BACK",12],
	["M11 — THE CORRIDOR",   13],
	["M12 — THE LONG RETREAT",14],
]

const SECTION_HEADERS: Dictionary = {
	0: "── TUTORIALS ──",
	3: "── ACT 1 — DESPERATE ──",
	7: "── ACT 2 — THE TURN ──",
	12: "── ACT 3 — THE RUN ──",
}

var _player_opt: OptionButton = null
var _enemy_opt: OptionButton = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(700, 0)
	margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(700, 0)
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	vbox.add_child(header_row)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.custom_minimum_size = Vector2(100, 34)
	back_btn.pressed.connect(_on_back_pressed)
	header_row.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "TEST MISSIONS"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.modulate = Color(0.6, 0.75, 1.0)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	# Mission list
	for entry in MISSIONS:
		var display: String = entry[0]
		var idx: int = entry[1]

		if SECTION_HEADERS.has(idx):
			var sep_lbl := Label.new()
			sep_lbl.text = SECTION_HEADERS[idx]
			sep_lbl.add_theme_font_size_override("font_size", 11)
			sep_lbl.modulate = Color(0.45, 0.45, 0.55)
			vbox.add_child(sep_lbl)

		var btn := Button.new()
		btn.text = display
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 15)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_mission_pressed.bind(idx))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	# Quick skirmish section
	var skirmish_hdr := Label.new()
	skirmish_hdr.text = "── QUICK SKIRMISH ──"
	skirmish_hdr.add_theme_font_size_override("font_size", 11)
	skirmish_hdr.modulate = Color(0.45, 0.45, 0.55)
	vbox.add_child(skirmish_hdr)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var plbl := Label.new()
	plbl.text = "Players:"
	plbl.add_theme_font_size_override("font_size", 14)
	plbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plbl)

	_player_opt = OptionButton.new()
	_player_opt.custom_minimum_size = Vector2(80, 32)
	for i in range(1, 7):
		_player_opt.add_item(str(i))
	_player_opt.selected = 1   # default 2
	row.add_child(_player_opt)

	var elbl := Label.new()
	elbl.text = "  Enemies:"
	elbl.add_theme_font_size_override("font_size", 14)
	elbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(elbl)

	_enemy_opt = OptionButton.new()
	_enemy_opt.custom_minimum_size = Vector2(80, 32)
	for i in range(1, 7):
		_enemy_opt.add_item(str(i))
	_enemy_opt.selected = 1   # default 2
	row.add_child(_enemy_opt)

	var skirmish_btn := Button.new()
	skirmish_btn.text = "LAUNCH SKIRMISH"
	skirmish_btn.custom_minimum_size = Vector2(0, 38)
	skirmish_btn.add_theme_font_size_override("font_size", 15)
	skirmish_btn.modulate = Color(0.8, 0.8, 1.0)
	skirmish_btn.pressed.connect(_on_skirmish_pressed)
	vbox.add_child(skirmish_btn)


func _on_mission_pressed(mission_index: int) -> void:
	CampaignManager.test_mode = true
	CampaignManager.skirmish_mode = false
	CampaignManager.mission_index = mission_index
	CampaignManager.squad_size = 2
	get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn")


func _on_skirmish_pressed() -> void:
	var player_count: int = (_player_opt.selected + 1) if _player_opt != null else 2
	var enemy_count: int = (_enemy_opt.selected + 1) if _enemy_opt != null else 2
	var specs: Array = []
	for _i in range(enemy_count):
		specs.append(_make_enemy(ENEMY_CLASS_IDS[randi() % ENEMY_CLASS_IDS.size()]))
	CampaignManager.test_mode = true
	CampaignManager.start_skirmish(specs, player_count)
	get_tree().change_scene_to_file("res://scenes/LoadoutScreen.tscn")


func _on_back_pressed() -> void:
	CampaignManager.reset_test_mode()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _make_enemy(class_id: String) -> Dictionary:
	var stat_map: Dictionary = {
		"enemy_fighter": {"attack": 2, "defence": 2, "shields": 2, "hull": 3, "weapon": "CANNONS"},
		"enemy_scout":   {"attack": 1, "defence": 3, "shields": 1, "hull": 2, "weapon": "ION"},
		"enemy_assault": {"attack": 3, "defence": 1, "shields": 2, "hull": 3, "weapon": "BURST"},
	}
	var name_map: Dictionary = {"enemy_fighter": "BANDIT", "enemy_scout": "VIPER", "enemy_assault": "FANG"}
	var accent_map: Dictionary = {
		"enemy_fighter": [0.55, 0.2, 0.55],
		"enemy_scout":   [0.2, 0.55, 0.55],
		"enemy_assault": [0.7, 0.25, 0.2],
	}
	var stats: Dictionary = stat_map.get(class_id, stat_map["enemy_fighter"])
	return {
		"name": name_map.get(class_id, "BANDIT"),
		"base_skill": 2, "skill": 2,
		"accuracy": 1.0, "agility": 1.1, "nerve": 0.1,
		"passive": "", "active": "",
		"weapon": stats["weapon"],
		"attack": stats["attack"], "defence": stats["defence"],
		"shields": stats["shields"], "hull": stats["hull"],
		"accent": accent_map.get(class_id, [0.55, 0.2, 0.55]),
		"xp": 0, "kills": 0, "status": "healthy",
		"ship_class": class_id,
	}
