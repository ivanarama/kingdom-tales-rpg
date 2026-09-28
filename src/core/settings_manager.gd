extends Node

## Настройки игрока: громкость, язык и упрощённые анимации.
## Хранятся в user://settings.cfg, применяются при запуске игры.
## Автозагрузка SettingsManager идёт после SoundManager — ей нужны его плееры.

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var locale: String = "ru"
var reduced_animations: bool = false

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	SoundManager.music_volume = clampf(float(cfg.get_value("audio", "music", SoundManager.music_volume)), 0.0, 1.0)
	SoundManager.sfx_volume = clampf(float(cfg.get_value("audio", "sfx", SoundManager.sfx_volume)), 0.0, 1.0)
	locale = str(cfg.get_value("game", "locale", locale))
	reduced_animations = bool(cfg.get_value("game", "reduced_animations", reduced_animations))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", SoundManager.music_volume)
	cfg.set_value("audio", "sfx", SoundManager.sfx_volume)
	cfg.set_value("game", "locale", locale)
	cfg.set_value("game", "reduced_animations", reduced_animations)
	cfg.save(SETTINGS_PATH)

func apply() -> void:
	SoundManager.set_master_volume(master_volume)
	SoundManager.set_music_volume(SoundManager.music_volume)
	SoundManager.set_sfx_volume(SoundManager.sfx_volume)
	TranslationServer.set_locale(locale)

func set_locale(new_locale: String) -> void:
	locale = new_locale
	TranslationServer.set_locale(locale)
	save_settings()
