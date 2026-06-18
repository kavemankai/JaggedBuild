# DemoTitleScreen.gd
# Demo title screen. Full-bleed key art, a fading-in quote + "CLICK TO BEGIN",
# title music from launch. Any click or keypress (once the overlay is visible)
# fades out and moves to the loadout screen. No menu buttons, no campaign ties.
extends Node

const TITLE_ART := preload("res://Demo_assets/tittle.jpg")

# NOTE: CanvasLayer is not a CanvasItem and has no `modulate` in Godot 4, so the
# fade is driven off the overlay Control (a CanvasItem) instead.
var _overlay: Control
var _accepting_input: bool = false


func _ready() -> void:
	# Title music starts immediately (no fade-in).
	AudioManager.play_music("music_title", 0.0)

	# Full-screen key art.
	var bg := TextureRect.new()
	bg.texture = TITLE_ART
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Fading overlay (quote + prompt + title), drawn above the art.
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	layer.add_child(_overlay)

	# Title text (in case the key art does not already carry it).
	var title := Label.new()
	title.text = "THE LONG RETREAT"
	title.add_theme_font_override("font", UIConstants.FONT_NARR_BOLD)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 90)
	title.size = Vector2(1600, 70)
	_overlay.add_child(title)

	# The quote.
	var quote := Label.new()
	quote.text = "Space is vast. The war is endless. All we can do is pull back... and live to fight again."
	quote.add_theme_font_override("font", UIConstants.FONT_NARR)
	quote.add_theme_font_size_override("font_size", 12)
	var silver70 := UIConstants.COLOR_SILVER
	silver70.a = 0.7
	quote.add_theme_color_override("font_color", silver70)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.position = Vector2(0, 470)
	quote.size = Vector2(1600, 30)
	_overlay.add_child(quote)

	# "CLICK TO BEGIN" prompt with a gentle alpha pulse.
	var prompt := Label.new()
	prompt.text = "CLICK TO BEGIN"
	prompt.add_theme_font_override("font", UIConstants.FONT_UI_BOLD)
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.add_theme_color_override("font_color", UIConstants.COLOR_CYAN)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(0, 520)
	prompt.size = Vector2(1600, 30)
	_overlay.add_child(prompt)

	var pulse := create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 1.0)
	pulse.tween_property(prompt, "modulate:a", 1.0, 1.0)

	# Fade the overlay in after a 2-second hold on the bare key art.
	_fade_in_overlay()


func _fade_in_overlay() -> void:
	await get_tree().create_timer(2.0).timeout
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 1.5)
	await tw.finished
	_accepting_input = true


func _input(event: InputEvent) -> void:
	if not _accepting_input:
		return
	var pressed: bool = false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	if pressed:
		_accepting_input = false
		_advance()


func _advance() -> void:
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.5)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/DemoLoadout.tscn")
