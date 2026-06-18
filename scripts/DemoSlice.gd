# DemoSlice.gd
# Demo entry point (the project main scene).
# A thin router: it does nothing but open the demo title screen. No game logic
# lives here; this exists only so the launch path is isolated from the campaign.
extends Node


func _ready() -> void:
	# Defer one frame: the scene tree is still building during _ready, so changing
	# scenes immediately would race the tree setup.
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/DemoTitleScreen.tscn")
