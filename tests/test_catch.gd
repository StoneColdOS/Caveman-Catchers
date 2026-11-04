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

	# --- 1. Standing in plain view: suspicious, then spotted and running to warn the tribe.
	var g1 = gs[1]
	player.global_position = g1.global_position + Vector3(0, 0, 4)
	await _frames(10)
	_check(g1.state == g1.State.SUSPICIOUS, "Gatherer gets suspicious when he sees you")
	var max_y := 0.0
	for i in 60:
		await physics_frame
		max_y = max(max_y, g1.global_position.y)
	_check(g1.is_warning(), "Spotted: he runs to warn the tribe")
	_check(max_y > 0.5, "Gatherer jumps when he spots you")
	_check(g1.warn_timer > 0.0 and g1.warn_timer < g1.WARN_TIME, "Warning countdown is ticking")
	_check(main.alert_label.text.begins_with("ALERT"), "HUD shows the alert")
	# Stop him in time: chase him down and net him.
	player.global_position = g1.global_position - g1.velocity.normalized() * 1.2
	player.visual.rotation.y = atan2(g1.velocity.x, g1.velocity.z)
	await _frames(1)
	player.swing_net()
	_check(g1.is_caught(), "Catching the spotter in time stops the alert")
	await _frames(5)
	_check(not main.game_over, "No game over when you stop him")
	_check(main.alert_label.text == "", "Alert clears")

	# --- 2. Crouch-sneak up behind another one and net him.
	var g2 = gs[2]
	Input.action_press("crouch")
	player.global_position = g2.global_position + Vector3(0, 0, -1.6)
	player.visual.rotation.y = 0.0
	await _frames(30)
	_check(g2.state == g2.State.WANDER, "Gatherer doesn't notice you creeping up behind him")
	player.swing_net()
	_check(g2.is_caught(), "Net catches the Gatherer")
	_check(main.caught == 2, "Catch counter goes up")
	await _frames(80)
	_check(not is_instance_valid(g2), "Caught Gatherer gets beamed away")
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

	# --- 5. Aiming and the tranq gun.
	_check(player.darts == 5, "Start with 5 darts")
	player.global_position = g4.global_position + Vector3(0, 0, -10)
	player.yaw = PI
	Input.action_press("aim")
	await _frames(20)
	_check(player.aiming, "Holding aim enters aim mode")
	_check(main.crosshair.visible, "Crosshair shows while aiming")
	_check(player.camera.fov < 60.0, "Camera zooms in while aiming")
	# Crosshair just past his shoulder: not red, and the dart should miss (no drift either way).
	var off_target: Vector3 = g4.global_position + Vector3.UP * 0.9 + Vector3(0.9, 0, 0)
	for i in 6:
		var to_off: Vector3 = off_target - player.camera.global_position
		player.yaw = atan2(-to_off.x, -to_off.z)
		player.pitch = atan2(to_off.y, Vector2(to_off.x, to_off.z).length())
		await _frames(4)
	_check(not player.aim_on_target, "Crosshair stays normal when it's off him")
	player.fire_tranq()
	await _frames(25)
	_check(not g4.is_drowsy(), "A shot just past him misses, exactly like the crosshair showed")
	player.darts = 5
	player.tranq_timer = 0.0

	# Put the crosshair on his chest, like a player nudging the right stick.
	var cam_target: Vector3 = g4.global_position + Vector3.UP * 0.9
	for i in 6:
		var to_target: Vector3 = cam_target - player.camera.global_position
		player.yaw = atan2(-to_target.x, -to_target.z)
		player.pitch = atan2(to_target.y, Vector2(to_target.x, to_target.z).length())
		await _frames(4)
	_check(player.aim_on_target, "Crosshair turns red when it's on a caveman")
	_check(player.fire_tranq(), "Tranq gun fires")
	_check(player.darts == 4, "Firing uses a dart")
	await _frames(25)
	_check(g4.is_drowsy(), "Aimed dart hits: he staggers first instead of dropping instantly")
	await _frames(130)
	_check(g4.is_asleep(), "...then falls asleep")
	Input.action_release("aim")
	await _frames(5)
	_check(not main.crosshair.visible, "Crosshair hides when you stop aiming")
	player.global_position = g4.global_position + Vector3(0, 0, -1.5)
	player.visual.rotation.y = 0.0
	await _frames(3)
	player.swing_net()
	_check(g4.is_caught(), "Sleeping Gatherer can be netted")

	# A hip-fire shot pointed away from everyone hits nothing (no auto-aim).
	var g0 = gs[0]
	player.global_position = g0.global_position + Vector3(6, 0, 0)
	player.yaw = 0.0  # facing -Z, g0 is off to the side
	await _frames(3)
	player.fire_tranq()
	await _frames(40)
	_check(not g0.is_drowsy() and not g0.is_asleep(), "No auto-aim: a shot pointed away misses")
	player.darts = 0
	_check(not player.fire_tranq(), "Out of darts: nothing fires")

	# --- 6. Let a spotter get away: game over.
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(3)
	g0.state = g0.State.SUSPICIOUS
	g0._start_flee()
	for i in 330:
		await physics_frame
		if main.game_over:
			break
	_check(main.game_over, "Spotter gets away after the countdown: game over")
	_check(main.message_label.text.contains("GAME OVER"), "Game over screen shows")

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
