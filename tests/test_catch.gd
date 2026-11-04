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
	_check(gs.size() == 5, "5 Gatherers spawned")
	for g in gs:
		_freeze(g)

	# --- 1. Standing in plain view in front of one: suspicious, then spotted.
	var g1 = gs[1]
	player.global_position = g1.global_position + Vector3(0, 0, 4)
	await _frames(10)
	_check(g1.state == g1.State.SUSPICIOUS, "Gatherer gets suspicious when he sees you")
	var max_y := 0.0
	for i in 60:
		await physics_frame
		max_y = max(max_y, g1.global_position.y)
	_check(g1.state == g1.State.FLEE, "Gatherer flees once he's sure")
	_check(max_y > 0.5, "Gatherer jumps when he spots you")
	var start: Vector3 = g1.global_position
	await _frames(30)
	_check(g1.global_position.distance_to(player.global_position) > start.distance_to(player.global_position),
		"Gatherer runs away from you")

	# --- 2. Crouch-sneak up behind another one and net him.
	var g2 = gs[2]
	Input.action_press("crouch")
	player.global_position = g2.global_position + Vector3(0, 0, -1.6)
	player.visual.rotation.y = 0.0
	await _frames(30)
	_check(g2.state == g2.State.WANDER, "Gatherer doesn't notice you creeping up behind him")
	player.swing_net()
	_check(g2.is_caught(), "Net catches the Gatherer")
	_check(main.caught == 1, "Catch counter goes up")
	await _frames(80)
	_check(not is_instance_valid(g2), "Caught Gatherer gets beamed away")
	Input.action_release("crouch")
	await _frames(5)

	# --- 3. Sound: a loud noise behind him makes him investigate, a quiet one doesn't.
	var g3 = gs[3]
	var g4 = gs[4]
	player.global_position = g4.global_position + Vector3(0, 0, -5)
	await _frames(3)
	player.make_noise(player.SNEAK_NOISE)
	await _frames(3)
	_check(g4.state == g4.State.WANDER, "Quiet footsteps 5m away go unheard")
	player.global_position = g3.global_position + Vector3(0, 0, -5)
	await _frames(3)
	player.make_noise(player.RUN_NOISE)
	await _frames(3)
	_check(g3.state == g3.State.INVESTIGATE, "Loud footsteps 5m away get him investigating")
	_check(g3.interest_point.distance_to(player.global_position) < 0.5, "He investigates where the noise came from")
	_check(g3.awareness < 1.0, "Hearing alone doesn't spot you")

	# --- 4. Jumping.
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := 0.0
	for i in 30:
		await physics_frame
		peak = max(peak, player.global_position.y)
	_check(peak > 0.8, "Player can jump")

	# --- 5. A miss: swinging at thin air catches nothing.
	var g0 = gs[0]
	player.swing_net()
	_check(not g0.is_caught(), "Swinging out of range catches nothing")

	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	quit(failures)


## Stops him wandering and glancing around, facing +Z, so tests are repeatable.
func _freeze(g) -> void:
	g.scan = false
	g.wait_timer = 9999.0
	g.heading = 0.0
	g.visual.rotation.y = 0.0
	g.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
