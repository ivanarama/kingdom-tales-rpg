extends Node

var music_player: AudioStreamPlayer # играющая сейчас тема
var _music_prev: AudioStreamPlayer # второй плеер: на нём затихает прежняя тема
var _music_tween: Tween
const MUSIC_FADE_TIME := 0.8
const SILENT_DB := -60.0

## Звук стихии заклинания — поверх общего spell_cast.
const SPELL_SFX := {
	"fireball": "fire_whoosh", "dark_flame": "fire_whoosh",
	"lightning": "lightning",
	"heal": "heal_chime", "restoration": "heal_chime", "bless": "heal_chime", "inspiration": "heal_chime",
	"slow": "frost",
	"stoneskin": "ward", "shield_light": "ward", "retribution": "ward",
	"haste": "swift", "blind": "swift",
}
## Боевые звуки звучат чуть выше или ниже — одинаковые удары не повторяются дословно.
const VARIED_SFX := ["sword_hit", "arrow_hit", "bow_shot", "fire_whoosh", "lightning", "frost", "ward", "swift", "heal_chime"]
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

var sfx_cache: Dictionary = {}
var current_music_path: String = "res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume) if master_volume > 0.001 else -80.0)

func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
		if _music_prev:
			_music_prev.stop()
	if music_player:
		music_player.volume_db = linear_to_db(music_volume) if music_volume > 0.001 else -80.0

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)

const PREF_PATH := "user://music_pref.cfg"
var custom_menu_theme: String = ""

func load_music_preference() -> String:
	if FileAccess.file_exists(PREF_PATH):
		var f = FileAccess.open(PREF_PATH, FileAccess.READ)
		if f:
			var p = f.get_as_text().strip_edges()
			f.close()
			if p != "" and ResourceLoader.exists(p):
				custom_menu_theme = p
				return p
			# Migration: preference saved as .wav before the OGG conversion
			if p.ends_with(".wav"):
				var ogg_path = p.replace(".wav", ".ogg")
				if ResourceLoader.exists(ogg_path):
					custom_menu_theme = ogg_path
					return ogg_path
	return ""

func save_music_preference(path: String) -> void:
	custom_menu_theme = path
	var f = FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if f:
		f.store_string(path)
		f.close()

func _ready() -> void:
	music_player = _make_music_player()
	_music_prev = _make_music_player()
	

	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		sfx_players.append(p)

	# Preload sounds
	_load_sfx("coin", "res://assets/audio/sfx/coin.wav")
	_load_sfx("click", "res://assets/audio/sfx/click.wav")
	_load_sfx("page_turn", "res://assets/audio/sfx/page_turn.wav")
	_load_sfx("spell_cast", "res://assets/audio/sfx/spell_cast.wav")
	_load_sfx("sword_hit", "res://assets/audio/sfx/sword_hit.wav")
	_load_sfx("victory", "res://assets/audio/sfx/victory.wav")
	_load_sfx("horse_gallop", "res://assets/audio/sfx/horse_gallop.wav")
	_load_sfx("bow_shot", "res://assets/audio/sfx/bow_shot.wav")
	_load_sfx("arrow_hit", "res://assets/audio/sfx/arrow_hit.wav")
	# События и стихии заклинаний (tools/make_event_sfx.py)
	for sfx_name in ["defeat", "level_up", "fire_whoosh", "lightning", "heal_chime", "frost", "ward", "swift"]:
		_load_sfx(sfx_name, "res://assets/audio/sfx/%s.wav" % sfx_name)
	
	var pref = load_music_preference()
	if pref != "":
		current_music_path = pref
	call_deferred("play_music", current_music_path)

func _load_sfx(name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		sfx_cache[name] = load(path)

func play_music(path: String, force_restart: bool = false) -> void:
	current_music_path = path
	if not ResourceLoader.exists(path):
		return
	if not force_restart and music_player.stream != null and music_player.stream.resource_path == path and music_player.playing:
		return
	var stream: AudioStream = load(path)
	if stream:
		if stream is AudioStreamWAV:
			var w = stream as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		var target_db := linear_to_db(music_volume) if music_volume > 0.001 else -80.0
		if _music_tween and _music_tween.is_valid():
			_music_tween.kill()
			_music_prev.stop()
		if not music_player.playing:
			music_player.stream = stream
			music_player.volume_db = target_db
			music_player.play()
			return
		var old := music_player
		music_player = _music_prev
		_music_prev = old
		music_player.stream = stream
		music_player.volume_db = SILENT_DB
		music_player.play()
		_music_tween = create_tween().set_parallel(true)
		_music_tween.tween_property(music_player, "volume_db", target_db, MUSIC_FADE_TIME)
		_music_tween.tween_property(_music_prev, "volume_db", SILENT_DB, MUSIC_FADE_TIME)
		_music_tween.chain().tween_callback(_music_prev.stop)

## Звук заклинания: общий spell_cast и, если есть, звук его стихии.
func play_spell_sfx(spell_id: String) -> void:
	play_sfx("spell_cast")
	if SPELL_SFX.has(spell_id):
		play_sfx(SPELL_SFX[spell_id], -2.0)

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Master"
	add_child(p)
	p.finished.connect(func():
		if p == music_player and p.stream:
			p.play()
	)
	return p

func play_sfx(name: String, volume_db: float = 0.0) -> void:
	if not sfx_cache.has(name):
		return
	var stream: AudioStream = sfx_cache[name]
	var sfx_db = volume_db + (linear_to_db(sfx_volume) if sfx_volume > 0.001 else -80.0)
	var pitch := randf_range(0.93, 1.07) if VARIED_SFX.has(name) else 1.0
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_db
			p.pitch_scale = pitch
			p.play()
			return
	# Fallback to first player
	sfx_players[0].stream = stream
	sfx_players[0].volume_db = sfx_db
	sfx_players[0].pitch_scale = pitch
	sfx_players[0].play()
