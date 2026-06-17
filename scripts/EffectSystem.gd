extends Node

const SHOT_ANIM_DURATION: float = 0.15

const _TEX_EXPLOSION  := preload("res://assets/effects/fx_explosion.png")
const _TEX_SHIELD_HIT := preload("res://assets/effects/fx_shield_hit.png")
const _TEX_HULL_HIT   := preload("res://assets/effects/fx_hull_hit.png")
const _TEX_CANNON     := preload("res://assets/effects/fx_cannon.png")
const _TEX_MISSILE    := preload("res://assets/effects/fx_missile.png")

const _EXPLOSION_FRAMES: int = 5
const _EXPLOSION_FRAME_W: int = 388
const _EXPLOSION_FRAME_H: int = 809

const _SHIELD_HIT_FRAMES: int = 4
const _SHIELD_HIT_FRAME_W: int = 495
const _SHIELD_HIT_FRAME_H: int = 793

const _HULL_HIT_FRAMES: int = 4
const _HULL_HIT_FRAME_W: int = 495
const _HULL_HIT_FRAME_H: int = 793

var _sf_explosion: SpriteFrames = null
var _sf_shield_hit: SpriteFrames = null
var _sf_hull_hit: SpriteFrames = null


func _ready() -> void:
	_sf_explosion  = _make_frames(_TEX_EXPLOSION,  _EXPLOSION_FRAMES,  _EXPLOSION_FRAME_W,  _EXPLOSION_FRAME_H, 10.0)
	_sf_shield_hit = _make_frames(_TEX_SHIELD_HIT, _SHIELD_HIT_FRAMES, _SHIELD_HIT_FRAME_W, _SHIELD_HIT_FRAME_H, 12.0)
	_sf_hull_hit   = _make_frames(_TEX_HULL_HIT,   _HULL_HIT_FRAMES,   _HULL_HIT_FRAME_W,   _HULL_HIT_FRAME_H, 12.0)


func _make_frames(tex: Texture2D, count: int, fw: int, fh: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("play")
	sf.set_animation_loop("play", false)
	sf.set_animation_speed("play", fps)
	for i in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(float(i * fw), 0.0, float(fw), float(fh))
		sf.add_frame("play", atlas)
	return sf


func spawn_projectile(from: Vector2, to: Vector2, is_hit: bool, is_missile: bool = false) -> void:
	var scene: Node2D = get_tree().current_scene
	if scene == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = _TEX_MISSILE if is_missile else _TEX_CANNON
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var direction: Vector2 = (to - from).normalized()
	sprite.rotation = direction.angle() + PI * 0.5
	var bolt_scale: float = 0.045 if is_missile else 0.035
	sprite.scale = Vector2(bolt_scale, bolt_scale)
	sprite.global_position = from
	scene.add_child(sprite)
	var target_pos: Vector2 = to if is_hit else from.lerp(to, 0.45)
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "global_position", target_pos, SHOT_ANIM_DURATION)
	await tween.finished
	sprite.queue_free()


func spawn_explosion(pos: Vector2) -> void:
	var scene: Node2D = get_tree().current_scene
	if scene == null or _sf_explosion == null:
		return
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = _sf_explosion
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim.scale = Vector2(0.32, 0.32)
	anim.global_position = pos
	scene.add_child(anim)
	anim.play("play")
	anim.animation_finished.connect(anim.queue_free)


func spawn_shield_hit(pos: Vector2) -> void:
	_spawn_animated(pos, _sf_shield_hit, 0.28)


func spawn_hull_hit(pos: Vector2) -> void:
	_spawn_animated(pos, _sf_hull_hit, 0.28)


func _spawn_animated(pos: Vector2, sf: SpriteFrames, scale_v: float) -> void:
	var scene: Node2D = get_tree().current_scene
	if scene == null or sf == null:
		return
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = sf
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim.scale = Vector2(scale_v, scale_v)
	anim.global_position = pos
	scene.add_child(anim)
	anim.play("play")
	anim.animation_finished.connect(anim.queue_free)
