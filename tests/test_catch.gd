extends SceneTree
## Plays the core loop automatically and checks it works.
## Run: godot --headless --path . -s res://tests/test_catch.gd

const Mech := preload("res://scripts/fighter.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Mech.hitstop_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)

	var player = main.player
	var city = main.city
	var es: Array = get_nodes_in_group("enemies")
	_check(es.size() == 3, "3 enemy mechs spawned")
	_check(city.buildings.size() > 25, "City built (%d buildings)" % city.buildings.size())
	_check(player.rig.global_transform.basis.get_scale().y > 3.0, "Mech is giant-sized")
	for e in es:
		e.frozen = true

	# --- 1. Syphon movement: you face the camera, the stick strafes.
	player.global_position = Vector3(-72, 0.2, 0)
	player.yaw = PI           # camera behind, looking toward -Z... facing = yaw + PI
	await _frames(30)
	var f0: Vector3 = player.facing()
	Input.action_press("move_right", 1.0)
	await _frames(30)
	Input.action_release("move_right")
	var moved: Vector3 = player.velocity
	_check(player.facing().dot(f0) > 0.95, "Strafing doesn't turn your mech")
	_check(absf(moved.normalized().dot(f0)) < 0.3 and moved.length() > 2.0, "Right on the stick moves you sideways")
	await _frames(20)

	# --- 2. Hold aim: locks onto the enemy in front, lock tightens over time.
	var e0 = es[0]
	_place_facing(player, e0, 40.0, true)
	await _frames(20)
	Input.action_press("aim")
	await _frames(3)
	_check(player.target == e0, "Holding AIM locks onto the enemy in front")
	var l0: float = player.lock
	await _frames(30)
	_check(player.lock > l0, "Lock tightens while you hold it")
	await _frames(40)
	_check(player.lock >= 0.999, "Standing still you reach a full lock")

	# --- 3. Full-lock shot on an unaware enemy: one-shot kill.
	_check(e0.is_unaware(), "He hasn't noticed you")
	player.fire()
	await _frames(2)
	_check(e0.dead, "Full-lock shot on an unaware mech: SILENT KILL")
	_check(main.downed == 1, "Counter goes up")
	Input.action_release("aim")
	await _frames(5)

	# --- 4. Aware enemy: shots chip his armor; full lock hits harder.
	var e1 = es[1]
	_place_facing(player, e1, 35.0, false)
	e1.state = e1.State.COMBAT
	await _frames(3)
	Input.action_press("aim")
	await _frames(3)
	player.lock = 0.0
	player.fire_cd = 0.0
	var hp0: int = e1.hp
	var tries := 0
	while e1.hp == hp0 and tries < 12:
		player.fire_cd = 0.0
		player.lock = 0.0
		player.fire()
		tries += 1
		await _frames(2)
	_check(e1.hp == hp0 - player.DAMAGE, "Loose shot hits for %d (took %d tries)" % [player.DAMAGE, tries])
	player.lock = 1.0
	var hp1: int = e1.hp
	player.fire()
	await _frames(2)
	_check(e1.hp == hp1 - player.FULL_LOCK_DAMAGE, "Full-lock shot hits for double")
	_check(e1.bar.visible, "His health bar shows once he's hurt")
	_check(player.ammo < player.mag_size, "Shooting uses ammo")
	Input.action_release("aim")

	# --- 5. Reload.
	player.ammo = 0
	player.fire()
	_check(player.reload_t > 0.0, "Empty magazine: auto reload")
	await _frames(int(player.reload_time * 60) + 5)
	_check(player.ammo == player.mag_size, "Reload refills the magazine")

	# --- 6. Enemy telegraphs with a laser, then bursts. Rolling dodges.
	e1.frozen = false
	e1.fire_cd = 0.0
	var laser_seen := false
	var hpp: int = player.hp
	for i in 150:
		await physics_frame
		if e1.laser.visible:
			laser_seen = true
		if player.hp < hpp:
			break
	_check(laser_seen, "His laser sight warns you before he fires")
	_check(player.hp < hpp, "His burst hits you if you stand still")
	await _frames(30)
	player.hp = player.MAX_HP
	var hp_before: int = player.hp
	player.start_roll(Vector3.RIGHT)
	player.take_shot(e1, 5, player.center())
	_check(player.hp == hp_before, "Bullets pass through you mid-roll")
	await _frames(40)
	e1.frozen = true

	# --- 7. Cover: a building between you blocks his sight.
	var b: Node3D = null
	for cand in city.buildings:
		if cand.get_meta("half").y * 2.0 > 9.0:
			b = cand
			break
	var half: Vector3 = b.get_meta("half")
	e1.global_position = b.global_position + Vector3(0, -b.global_position.y + 0.2, half.z + 12.0)
	player.global_position = b.global_position + Vector3(0, -b.global_position.y + 0.2, -half.z - 8.0)
	e1.heading = PI
	e1.rig.rotation.y = PI
	await _frames(3)
	_check(not e1.can_see_player(), "A building between you is cover")

	# --- 8. Shots wreck buildings.
	var hb: int = b.get_meta("hp")
	for i in hb:
		city.shoot_building(b, b.global_position, player.global_position)
	await _frames(3)
	_check(not city.buildings.has(b), "Enough hits bring a building down (%d)" % hb)
	_check(city.debris.size() > 3, "It collapses into chunks")
	var prop: RigidBody3D = city.props[0]
	city.shot_props(prop.global_position + Vector3(-20, 1, 0), prop.global_position + Vector3(20, 1, 0))
	_check(not prop.freeze, "Stray shots knock props over")

	# --- 9. Rolling into a low building smashes it.
	var low: Node3D = null
	for cand in city.buildings:
		if cand.get_meta("half").y * 2.0 < 9.0:
			low = cand
			break
	_check(city.smash(low, low.global_position + Vector3(0, 0, 20), player.ROLL_SPEED), "Rolling into a low shop smashes it")

	# --- 10. Hearing.
	var e2 = es[2]
	e2.state = e2.State.PATROL
	e2.hear_noise(e2.global_position + Vector3(30, 0, 0), player.WALK_NOISE, player)
	_check(e2.state == e2.State.PATROL, "Walking 30 m away goes unheard")
	e2.hear_noise(e2.global_position + Vector3(30, 0, 0), player.JOG_NOISE, player)
	_check(e2.state == e2.State.INVESTIGATE, "Jogging 30 m away gets him investigating")

	# --- 11. Crouch: quieter and harder to spot.
	player.crouching = false
	var e2_far: float = e2.SIGHT_RANGE
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	_check(player.crouching, "Crouch toggles on")

	# --- 12. Armor gone: game over.
	player.crouching = false
	while not player.dead:
		player.roll_t = 0.0
		player.take_shot(e2, 5, player.center())
	await _frames(2)
	_check(player.dead and main.game_over, "Armor gone: DEFEATED")

	# --- 13. Touch controls.
	var TouchScript := load("res://scripts/touch_controls.gd")
	var t: Control = TouchScript.new()
	t.player = player
	main.add_child(t)
	await _frames(2)
	t._touch_down(0, Vector2(100, 600))
	t._touch_move(0, Vector2(100 + t.STICK_RADIUS, 600))
	_check(Input.get_action_strength("move_right") > 0.9, "Touch joystick: full push = jog")
	t._touch_up(0)
	for name in ["fire", "roll", "reload", "crouch"]:
		t._touch_down(1, t.buttons[name].pos)
		var ok := Input.is_action_pressed(t.buttons[name].action)
		t._touch_up(1)
		_check(ok, "Touch %s button works" % name.to_upper())
	t._touch_down(1, t.buttons["aim"].pos)
	t._touch_up(1)
	_check(Input.is_action_pressed("aim"), "Touch AIM toggles on (stays locked)")
	t._touch_down(1, t.buttons["aim"].pos)
	t._touch_up(1)
	_check(not Input.is_action_pressed("aim"), "...and off")

	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	quit(failures)


## Player stands `dist` from the enemy, facing him. Enemy faces away (unaware) or toward.
func _place_facing(player, e, dist: float, behind: bool) -> void:
	e.heading = 0.0 if behind else PI
	e.rig.rotation.y = e.heading
	player.global_position = e.global_position + Vector3(0, 0, -dist)
	player.yaw = PI          # facing +Z toward him
	player.rig.rotation.y = 0.0
	player.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
