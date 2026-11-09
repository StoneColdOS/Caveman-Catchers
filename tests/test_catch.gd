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
	var ss: Array = get_nodes_in_group("soldiers")
	_check(ss.size() == 5, "5 soldiers spawned")
	for s in ss:
		_freeze(s)

	# --- 1. Stealth takedown: creep up behind one and grab him.
	var s2 = ss[2]
	Input.action_press("crouch")
	player.global_position = s2.global_position + Vector3(0, 0, -1.6)
	player.visual.rotation.y = 0.0
	await _frames(30)
	_check(s2.state == s2.State.PATROL, "Soldier doesn't notice the mech creeping up behind him")
	player.grab()
	_check(s2.is_held() and player.hold_needed == player.TAPS_UNAWARE, "Sneak-grab: he's lifted up and needs only a few taps")
	var start_pos: Vector3 = player.global_position
	Input.action_press("move_forward")
	await _frames(15)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start_pos) < 0.3, "You can't walk away while holding one")
	await _takedown(player)
	_check(s2.is_down(), "Tapping puts him out")
	_check(main.caught == 1, "Counter goes up")
	await _frames(60)
	_check(is_instance_valid(s2) and s2.is_down(), "He stays down in the snow")
	Input.action_release("crouch")
	await _frames(5)

	# --- 2. Stop squeezing and he breaks free, angry.
	var s3 = ss[3]
	player.global_position = s3.global_position + Vector3(0, 0, -1.6)
	player.visual.rotation.y = 0.0
	await _frames(3)
	player.grab()
	_check(s3.is_held(), "Grab another one")
	player.grab()
	await _frames(int(player.BREAK_TIME * 60) + 20)
	_check(not s3.is_held() and s3.is_fighting(), "Stop tapping: he breaks free and fights")
	_check(player.holding == null, "...and you can move again")
	_reset_soldier(s3)

	# --- 3. Getting spotted starts a fight.
	var s1 = ss[1]
	player.global_position = s1.global_position + Vector3(0, 0, 5)
	await _frames(10)
	_check(s1.state == s1.State.SUSPICIOUS, "Soldier gets suspicious when he sees you")
	await _frames(60)
	_check(s1.is_fighting(), "Spotted: he comes at you")
	# He closes in and winds up a swing. Stand there and you get hit.
	var hp0: int = player.hp
	var wound_up := false
	for i in 200:
		await physics_frame
		if s1.is_winding_up():
			wound_up = true
		if player.hp < hp0:
			break
	_check(wound_up, "He telegraphs his swing (baton raised)")
	_check(player.hp == hp0 - 1, "Standing in range: the baton hits you")

	# --- 4. Brawl: punch staggers, grab a staggered soldier to throw him.
	await _frames(int(player.HURT_TIME * 60) + 5)
	_face(player, s1)
	player.global_position = s1.global_position - player._forward() * 1.6
	await _frames(1)
	player.grab()
	_check(s1.is_fighting() and not s1.is_held(), "Can't grab a soldier who's swinging at you")
	await _frames(int(player.GRAB_COOLDOWN * 60) + 2)
	var shp: int = s1.hp
	_face(player, s1)
	player.punch()
	await _frames(int(player.PUNCH_HIT_AT * 60) + 3)
	_check(s1.hp == shp - 1 and s1.is_staggered(), "Punch lands: he staggers")
	await _frames(int(player.PUNCH_TIME * 60))
	_face(player, s1)
	player.global_position = s1.global_position - player._forward() * 1.5
	await _frames(1)
	player.grab()
	_check(s1.state == s1.State.THROWN, "Grab a staggered soldier: he gets thrown")
	await _frames(90)
	_check(s1.is_down(), "Punch + throw puts him down")
	_check(main.caught == 2, "Brawl takedowns count too")

	# --- 5. Sound.
	var s4 = ss[4]
	var s0 = ss[0]
	player.global_position = s4.global_position + Vector3(0, 0, -5)
	await _frames(3)
	player.make_noise(player.SNEAK_NOISE)
	await _frames(3)
	_check(s4.state == s4.State.PATROL, "Quiet steps 5m away go unheard")
	player.global_position = s0.global_position + Vector3(0, 0, -5)
	await _frames(3)
	player.make_noise(player.RUN_NOISE)
	await _frames(3)
	_check(s0.state == s0.State.INVESTIGATE, "Heavy stomps 5m away get him investigating")
	_check(s0.awareness < 1.0, "Hearing alone doesn't spot you")
	_reset_soldier(s0)

	# --- 6. Jumping.
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := 0.0
	for i in 30:
		await physics_frame
		peak = max(peak, player.global_position.y)
	_check(peak > 0.8, "Mech can jump")

	# --- 7. Light and dark.
	_check(not player.flashlight_on, "Head lamp starts off (stealth first)")
	player.toggle_flashlight()
	var lit_range: float = s4._sight_range()
	player.toggle_flashlight()
	_check(not player.flashlight_on, "Head lamp toggles off")
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(2)
	_check(not player.is_lit(), "In the dark with the lamp off: not lit")
	_check(s4._sight_range() < lit_range * 0.6, "Soldiers see you half as far in the dark")
	player.global_position = main.LAMP_SPOTS[0] + Vector3(1, 0.1, 0)
	await _frames(2)
	_check(player.is_lit(), "Standing in lamplight lights you up even with the lamp off")
	player.toggle_flashlight()
	_check(player.flashlight_on and player.is_lit(), "Head lamp back on")

	# --- 8. Lose a fighter: out of sight long enough and he goes back to searching.
	player.global_position = Vector3(0, 0.1, 0)
	await _frames(3)
	s4._start_fight()
	player.global_position = Vector3(-22, 0.1, 22) if s4.global_position.x > 0 else Vector3(22, 0.1, -22)
	s4.lose_timer = 0.05
	await _frames(10)
	_check(not s4.is_fighting() and s4.state == s4.State.INVESTIGATE, "Lose him and he goes back to searching")

	# --- 9. Take enough hits and the mech goes down.
	while player.hp > 0:
		player.hurt_timer = 0.0
		player.take_hit(player.global_position + Vector3(1, 0, 0))
	await _frames(2)
	_check(player.dead and main.game_over, "Armor gone: MECH DOWN")

	# --- 10. Touch controls drive the same actions.
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
	t._touch_down(1, t.buttons["punch"].pos)
	_check(Input.is_action_pressed("punch"), "Punch button works")
	t._touch_up(1)
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
func _freeze(s) -> void:
	s.scan = false
	s.wait_timer = 9999.0
	s.heading = 0.0
	s.visual.rotation.y = 0.0
	s.velocity = Vector3.ZERO


## Puts a soldier back to calm patrol, standing still.
func _reset_soldier(s) -> void:
	s.state = s.State.PATROL
	s.awareness = 0.0
	s.stagger = 0.0
	s.windup = 0.0
	s.hp = s.MAX_HP
	_freeze(s)


func _face(player, s) -> void:
	var to: Vector3 = s.global_position - player.global_position
	player.visual.rotation.y = atan2(to.x, to.z)


## Grabs (if not already holding) and taps until he's out. Returns taps used.
func _takedown(player) -> int:
	var taps := 0
	if player.holding == null:
		player.grab()
	while player.holding != null and taps < 30:
		await physics_frame
		player.grab()
		taps += 1
	return taps


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
