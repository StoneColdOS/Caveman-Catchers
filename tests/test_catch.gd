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

	# --- 1. Standing in plain view: suspicious, then spotted and running away.
	var g1 = gs[1]
	player.global_position = g1.global_position + Vector3(0, 0, 4)
	await _frames(10)
	_check(g1.state == g1.State.SUSPICIOUS, "Gatherer gets suspicious when he sees you")
	var max_y := 0.0
	for i in 60:
		await physics_frame
		max_y = max(max_y, g1.global_position.y)
	_check(g1.is_fleeing(), "Spotted: he runs away")
	_check(max_y > 0.5, "Gatherer jumps when he spots you")
	# Chase him down and grab him.
	player.global_position = g1.global_position - g1.velocity.normalized() * 1.2
	player.visual.rotation.y = atan2(g1.velocity.x, g1.velocity.z)
	await _frames(1)
	player.grab()
	_check(g1.is_caught(), "You can chase down a runner and grab him")
	await _frames(5)

	# --- 2. Crouch-sneak up behind another one and grab him.
	var g2 = gs[2]
	Input.action_press("crouch")
	player.global_position = g2.global_position + Vector3(0, 0, -1.3)
	player.visual.rotation.y = 0.0
	await _frames(30)
	_check(g2.state == g2.State.WANDER, "Gatherer doesn't notice you creeping up behind him")
	player.grab()
	_check(g2.is_caught(), "Grab catches the robot")
	_check(main.caught == 2, "Catch counter goes up")
	await _frames(80)
	_check(not is_instance_valid(g2), "Caught robot gets stuffed in the satchel")
	_check(player.satchel_fill == 2 and player.satchel.scale.x > 1.05, "Satchel bulges more with each catch")
	Input.action_release("crouch")
	await _frames(5)

	# --- 3. Sound.
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

	# --- 5. No tranq gun anymore: net only.
	_check(not InputMap.has_action("tranq") and not InputMap.has_action("aim"), "Tranq gun and aiming are gone")
	var g0 = gs[0]

	# --- 6. Lose a runner: he runs while he can see you, then calms down. No penalty.
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(3)
	g0.state = g0.State.SUSPICIOUS
	g0._start_flee()
	_check(g0.is_fleeing(), "Runner is running")
	var away_spot: Vector3 = g0.global_position + Vector3(20, 0, 0)  # well out of sight range
	away_spot.x = clamp(away_spot.x, -22.0, 22.0)
	if away_spot.distance_to(g0.global_position) < 15.0:
		away_spot = g0.global_position - Vector3(20, 0, 0)
	player.global_position = away_spot
	g0.flee_timer = 0.05
	await _frames(10)
	_check(not g0.is_fleeing() and g0.state == g0.State.INVESTIGATE, "Lose sight of him and he calms down to searching")
	_check(not main.game_over, "No game over for getting spotted")

	# --- 7. Touch controls drive the same actions.
	var TouchScript := load("res://scripts/touch_controls.gd")
	var t: Control = TouchScript.new()
	t.player = player
	main.add_child(t)
	await _frames(2)
	t._touch_down(0, Vector2(100, 600))
	t._touch_move(0, Vector2(100 + t.STICK_RADIUS, 600))
	_check(Input.get_action_strength("move_right") > 0.9, "Touch joystick: full push = full strength (run)")
	t._touch_move(0, Vector2(100 + t.STICK_RADIUS * 0.4, 600))
	var st := Input.get_action_strength("move_right")
	_check(st > 0.3 and st < 0.5, "Touch joystick: light push = partial strength (sneak)")
	t._touch_up(0)
	_check(Input.get_action_strength("move_right") == 0.0, "Letting go stops movement")
	t._touch_down(1, t.buttons["crouch"].pos)
	t._touch_up(1)
	_check(Input.is_action_pressed("crouch"), "Crouch button toggles on")
	t._touch_down(1, t.buttons["crouch"].pos)
	t._touch_up(1)
	_check(not Input.is_action_pressed("crouch"), "...and off")
	var y0: float = player.yaw
	t._touch_down(2, Vector2(900, 300))
	t._touch_move(2, Vector2(960, 300))
	_check(player.yaw < y0, "Dragging on the right turns the camera")
	t._touch_up(2)

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
