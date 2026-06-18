extends Node

const SFX_POOL_SIZE: int = 8

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var _in_battle: bool = false

# Demo-slice guard: when true, phase-music crossfades are suppressed so a demo
# battle holds its combat track from start to game_ended. Set by DemoBattle only.
var demo_mode: bool = false


func _ready() -> void:
	# Create buses if the default project layout doesn't include them.
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_count() - 1, "Master")

	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicA"
	_music_a.bus = "Music"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicB"
	_music_b.bus = "Music"
	add_child(_music_b)

	_active_music = _music_a

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	_load_streams()

	# Phase music — connect after all autoloads are ready.
	RoundManager.planning_phase_started.connect(_on_planning)
	RoundManager.combat_phase_started.connect(_on_combat)
	RoundManager.evaluation_phase_started.connect(_on_evaluation)
	RoundManager.game_ended.connect(_on_game_ended)


func _load_streams() -> void:
	# ── Music (looping duplicates) ────────────────────────────────────────────
	streams["music_title"]    = _looping("res://Demo_assets/music/Tittle.mp3")
	streams["music_planning"] = _looping("res://Demo_assets/music/Menu.mp3")
	streams["music_combat"]   = _looping("res://Demo_assets/music/main_battle.mp3")

	# ── Combat SFX ────────────────────────────────────────────────────────────
	streams["sfx_cannon"]     = load("res://Demo_assets/Bonus/sfx_laser1.ogg")
	streams["sfx_burst"]      = load("res://Demo_assets/Bonus/sfx_laser2.ogg")
	streams["sfx_heavy"]      = load("res://Demo_assets/Audio/laserLarge_000.ogg")
	streams["sfx_ion"]        = load("res://Demo_assets/Bonus/sfx_zap.ogg")
	streams["sfx_missile"]    = load("res://Demo_assets/Audio/thrusterFire_000.ogg")     # PLACEHOLDER — needs missile launch sound
	streams["sfx_torpedo"]    = load("res://Demo_assets/Audio/spaceEngineLarge_000.ogg") # PLACEHOLDER — needs torpedo launch sound
	streams["sfx_shield_hit"] = load("res://Demo_assets/Bonus/sfx_shieldDown.ogg")
	streams["sfx_hull_hit"]   = load("res://Demo_assets/Audio/impactMetal_000.ogg")
	streams["sfx_explosion"]  = load("res://Demo_assets/Audio/explosionCrunch_000.ogg")
	streams["sfx_ion_hit"]    = load("res://Demo_assets/Bonus/sfx_zap.ogg")              # same source, played at -6db
	streams["sfx_crit"]       = load("res://Demo_assets/Bonus/sfx_twoTone.ogg")
	streams["sfx_kia"]        = load("res://Demo_assets/Audio/lowFrequency_explosion_000.ogg") # PLACEHOLDER — needs pilot KIA sting

	# ── UI SFX ────────────────────────────────────────────────────────────────
	streams["sfx_click"]   = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Select - 1.wav")
	streams["sfx_hover"]   = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.wav")
	streams["sfx_confirm"] = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Popup Open - 1.wav")
	streams["sfx_cancel"]  = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Cancel - 1.wav")
	streams["sfx_phase"]   = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Swipe - 1.wav")
	streams["sfx_error"]   = load("res://Demo_assets/uisfx/JDSherbert - Ultimate UI SFX Pack - Error - 1.wav")
	streams["sfx_win"]     = load("res://Demo_assets/Bonus/sfx_twoTone.ogg")             # PLACEHOLDER — needs win sting
	streams["sfx_lose"]    = load("res://Demo_assets/Bonus/sfx_lose.ogg")


# Returns a looping duplicate of the audio stream at the given path.
func _looping(path: String) -> AudioStream:
	var s: AudioStream = load(path)
	if s == null:
		push_warning("AudioManager: failed to load " + path)
		return null
	s = s.duplicate() as AudioStream
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if not streams.has(key) or streams[key] == null:
		push_warning("AudioManager: unknown sfx key: " + key)
		return
	var player := _get_free_sfx_player()
	player.stream = streams[key]
	player.volume_db = volume_db
	player.play()


func play_music(key: String, fade_duration: float = 1.0) -> void:
	if not streams.has(key) or streams[key] == null:
		push_warning("AudioManager: unknown music key: " + key)
		return
	# Already playing this stream — don't restart/crossfade.
	if _active_music.playing and _active_music.stream == streams[key]:
		return
	var incoming: AudioStreamPlayer = _music_b if _active_music == _music_a else _music_a
	incoming.stream = streams[key]
	incoming.volume_db = -80.0
	incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_active_music, "volume_db", -80.0, fade_duration)
	tween.tween_property(incoming, "volume_db", 0.0, fade_duration)
	await tween.finished
	_active_music.stop()
	_active_music = incoming


func stop_music(fade_duration: float = 1.0) -> void:
	if not _active_music.playing:
		return
	var tween := create_tween()
	tween.tween_property(_active_music, "volume_db", -80.0, fade_duration)
	await tween.finished
	_active_music.stop()


# Fire-and-forget: call WITHOUT await. Plays KIA sting 0.3s after the explosion.
# Only call for named pilots (check is_drone before calling).
func play_kia_sting() -> void:
	_kia_delayed()


func _kia_delayed() -> void:
	await get_tree().create_timer(0.3).timeout
	play_sfx("sfx_kia", -3.0)


func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]  # oldest sound gets cut


# ── Phase music transitions ────────────────────────────────────────────────────

func _on_planning() -> void:
	if demo_mode:
		return   # demo battle holds its combat track across all phases
	if not _in_battle:
		play_music("music_planning", 1.5)


func _on_combat() -> void:
	_in_battle = true
	if demo_mode:
		return   # demo battle already playing combat music
	play_music("music_combat", 0.5)


func _on_evaluation() -> void:
	# (No music change in either mode; demo_mode guard kept for symmetry.)
	pass


func _on_game_ended(_message: String, _color: Color, won: bool) -> void:
	_in_battle = false
	stop_music(2.0)
	if won:
		play_sfx("sfx_win")
	else:
		play_sfx("sfx_lose")
