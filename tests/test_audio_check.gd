extends Node

func _ready() -> void:
	print("\n--- AUDIO DIAGNOSTIC TEST ---")
	print("AudioServer bus count: ", AudioServer.bus_count)
	print("Master bus volume db: ", AudioServer.get_bus_volume_db(0))
	print("Master bus mute: ", AudioServer.is_bus_mute(0))
	print("AudioServer output device list: ", AudioServer.get_output_device_list())
	print("AudioServer output device: ", AudioServer.get_output_device())
	
	var music_path = "res://assets/audio/music/fairy_tale_theme.wav"
	print("ResourceLoader exists music: ", ResourceLoader.exists(music_path))
	var stream = load(music_path)
	print("Loaded stream: ", stream)
	if stream:
		print("Stream class: ", stream.get_class())
		print("Stream length: ", stream.get_length())
		if stream is AudioStreamWAV:
			var w = stream as AudioStreamWAV
			print("AudioStreamWAV format: ", w.format)
			print("AudioStreamWAV loop_mode: ", w.loop_mode)
			print("AudioStreamWAV mix_rate: ", w.mix_rate)
			print("AudioStreamWAV stereo: ", w.stereo)
			print("AudioStreamWAV data size: ", w.data.size())
			
	var p = SoundManager.music_player
	print("SoundManager music_player: ", p)
	print("music_player stream: ", p.stream)
	print("music_player playing: ", p.playing)
	print("music_player volume_db: ", p.volume_db)
	print("music_player bus: ", p.bus)
	
	# Test SFX
	for k in SoundManager.sfx_cache.keys():
		var s = SoundManager.sfx_cache[k]
		print("SFX: ", k, " -> ", s, " (len: ", s.get_length() if s else 0, ")")
		
	print("--- END AUDIO DIAGNOSTIC ---\n")
	get_tree().quit()
