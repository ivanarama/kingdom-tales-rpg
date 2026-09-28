extends SceneTree

func _init():
	var s = load('res://assets/audio/music/themes/homm2_01_sorceress_garden.ogg') as AudioStreamWAV
	var p = AudioStreamPlayer.new()
	root.add_child(p)
	p.stream = s
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = 0
	p.play()
	for i in range(10):
		await process_frame
		print('Frame', i, 'Playing:', p.playing, 'pos:', p.get_playback_position())
	quit()
