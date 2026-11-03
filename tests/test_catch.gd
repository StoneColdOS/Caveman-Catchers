extends SceneTree
## Plays the core loop automatically and checks it works.
## Run: godot --headless --path . -s res://tests/test_catch.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)

	var player = main.player
	var gs: Array = get_nodes_in_group("gatherers")
	_check(gs.size() == 3, "3 Gatherers spawned")

	# --- 1. Standing in plain view in front of one: he should notice and run.
	var g1 = gs[1]  # out in the open (gs[0] spawns near a rock)
	_freeze(g1)
	player.global_position = g1.global_position + Vector3(0, 0, 4)
	await _frames(15)
	_check(g1.state == g1.State.SUSPICIOUS, "Gatherer gets suspicious when he sees you")
	await _frames(90)
	_check(g1.state == g1.State.FLEE, "Gatherer runs away once he's sure")
	var start: Vector3 = g1.global_position
	await _frames(30)
	_check(g1.global_position.distance_to(player.global_position) > start.distance_to(player.global_position),
		"Gatherer moves away from you while fleeing")

	# --- 2. Crouch-sneak up behind another one: he stays calm and gets netted.
	var g2 = gs[2]
	_freeze(g2)
	Input.action_press("crouch")
	player.global_position = g2.global_position + Vector3(0, 0, -1.6)
	player.visual.rotation.y = 0.0   # face him
	await _frames(30)
	_check(g2.state == g2.State.WANDER, "Gatherer doesn't notice you sneaking up behind him")
	player.swing_net()
	_check(g2.is_caught(), "Net catches the Gatherer")
	_check(main.caught == 1, "Catch counter goes up")
	await _frames(80)
	_check(not is_instance_valid(g2), "Caught Gatherer gets beamed away")

	# --- 3. A miss: swinging at thin air catches nothing.
	var g3 = gs[0]
	player.global_position = g3.global_position + Vector3(10, 0, 10)
	player.swing_net()
	_check(not g3.is_caught(), "Swinging out of range catches nothing")
	Input.action_release("crouch")

	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	quit(failures)


func _freeze(g) -> void:
	g.wander_wait = 9999.0
	g.visual.rotation.y = 0.0  # facing +Z
	g.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
