extends RefCounted

## На телефоне атака подтверждается вторым тапом, мышь бьёт сразу.

func get_title() -> String:
	return "Mobile Attack Confirm: first tap previews, second tap attacks; mouse attacks at once"

func _tap(ba, pos: Vector2, device: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.device = device
		ba._gui_input(ev)

## Бой, где грифон стоит в трёх клетках от волков и может до них долететь.
func _setup_battle(t):
	GameState.reset()
	GameState.start_chapter(1)
	GameState.pending_battle_id = "patrol_wolves"
	var ba = load("res://src/battle/battle_arena.tscn").instantiate()
	t.add_child(ba)
	await t.get_tree().process_frame
	var target = null
	for s in ba.all_stacks:
		if s.team == 1:
			target = s
	ba.current_actor.hex = target.hex + Vector2i(-3, 0)
	ba._update_reachable_hexes()
	return ba

func run(t) -> void:
	var ba = await _setup_battle(t)
	var actor = ba.current_actor
	var target = ba.armed_target
	for s in ba.all_stacks:
		if s.team == 1:
			target = s
	var start_hex: Vector2i = actor.hex
	var pos := HexGrid.hex_to_pixel(target.hex.x, target.hex.y, ba.HEX_SIZE, ba.grid_origin) + Vector2(-40, 0)
	_tap(ba, pos, InputEvent.DEVICE_ID_EMULATION)
	t._check(ba.armed_target == target, "First touch tap must arm the target")
	t._check(ba.hovered_forecast.size() > 0, "First touch tap must show the damage forecast")
	t._check(HexGrid.distance(ba.armed_attack_hex, target.hex) == 1, "First touch tap must mark the hex the attack comes from")
	t._check(actor.hex == start_hex and not actor.has_acted, "First touch tap must not attack yet")
	_tap(ba, pos, InputEvent.DEVICE_ID_EMULATION)
	t._check(ba.armed_target == null, "Second touch tap must consume the preview")
	t._check(HexGrid.distance(actor.hex, target.hex) == 1, "Second touch tap must attack from the marked hex")
	ba.queue_free()
	await t.get_tree().process_frame

	var ba2 = await _setup_battle(t)
	var actor2 = ba2.current_actor
	var target2 = null
	for s in ba2.all_stacks:
		if s.team == 1:
			target2 = s
	var pos2 := HexGrid.hex_to_pixel(target2.hex.x, target2.hex.y, ba2.HEX_SIZE, ba2.grid_origin)
	_tap(ba2, pos2, 0)
	t._check(HexGrid.distance(actor2.hex, target2.hex) == 1, "Mouse click must attack immediately")
	ba2.queue_free()
	await t.get_tree().process_frame
