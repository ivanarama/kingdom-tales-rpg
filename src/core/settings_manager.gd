extends Node

## Общие настройки игры: громкость, язык. Хранятся в user://settings.cfg.

const PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var locale: String = "ru" # "ru" | "en"
var reduced_animations: bool = false # упрощённая графика для слабых устройств
var battle_tutorial_done: bool = false # обучение в первом бою пройдено или пропущено

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	if SoundManager:
		SoundManager.set_master_volume(master_volume)
		SoundManager.set_music_volume(music_volume)
		SoundManager.set_sfx_volume(sfx_volume)
	TranslationServer.set_locale(locale)

func set_locale(loc: String) -> void:
	locale = loc
	TranslationServer.set_locale(locale)
	save_settings()

func load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	var loc = str(cfg.get_value("general", "locale", "ru"))
	locale = "en" if loc == "en" else "ru"
	reduced_animations = bool(cfg.get_value("general", "reduced_animations", false))
	battle_tutorial_done = bool(cfg.get_value("general", "battle_tutorial_done", false))

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("general", "reduced_animations", reduced_animations)
	cfg.set_value("general", "battle_tutorial_done", battle_tutorial_done)
	cfg.save(PATH)
