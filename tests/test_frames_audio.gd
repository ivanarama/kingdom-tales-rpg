extends Node

func _ready() -> void:
	var p = SoundManager.music_player
	var w = p.stream as AudioStreamWAV
	print("Before: loop_mode = ", w.loop_mode, " loop_end = ", w.loop_end)
	
	# Fix loop end to full length!
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = w.data.size() / 2
	print("Fixed loop_end: ", w.loop_end, " total samples")
	
	p.play()
	
	# Wait 0.3s
	await get_tree().create_timer(0.3).timeout
	print("After 0.3s: playing = ", p.playing, " pos = ", p.get_playback_position())
	get_tree().quit()
