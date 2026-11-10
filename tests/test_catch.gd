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

	# --- 1. Syphon Filter running: you run where you push, the camera swings in behind.
	player.global_position = Vector3(-72, 0.2, 0)
	player.yaw = PI
	player.rig.rotation.y = 0.0
	await _frames(10)
	player.global_position = Vector3(-72, 0.2, 70)   # long open street running toward -Z
	player.yaw = 0.0
	player.rig.rotation.y = PI
	await _frames(5)
	Input.action_press("move_forward", 0.5)   # a light push jogs
	await _frames(60)
	var jog: float = Vector2(player.velocity.x, player.velocity.z).length()
	_check(jog > player.JOG_SPEED * 0.8 and jog < player.RUN_SPEED * 0.8, "A light push jogs (%.1f m/s)" % jog)
	Input.action_press("move_forward", 1.0)   # full push sprints, ramping up smoothly
	await _frames(4)
	var early: float = Vector2(player.velocity.x, player.velocity.z).length()
	await _frames(50)
	var v: Vector3 = player.velocity
	_check(early < player.RUN_SPEED * 0.85, "Speed ramps up instead of snapping")
	_check(Vector2(v.x, v.z).length() > player.RUN_SPEED * 0.9, "A full push sprints (%.1f m/s)" % Vector2(v.x, v.z).length())
	Input.action_release("move_forward")
	await _frames(40)
	player.global_position = Vector3(-72, 0.2, 0)
	player.yaw = PI
	player.rig.rotation.y = 0.0
	await _frames(5)
	Input.action_press("move_right", 1.0)
	await _frames(40)
	v = player.velocity
	_check(player.facing().dot(v.normalized()) > 0.9, "Your mech turns to run where you push")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(160)   # stand still a moment: the camera settles in behind you
	var behind := Vector3(sin(player.yaw), 0, cos(player.yaw))
	_check(behind.dot(-player.facing()) > 0.8, "The camera swings in behind you")
	await _frames(30)
	var f0: Vector3 = player.facing()
	Input.action_press("strafe_right")
	await _frames(30)
	Input.action_release("strafe_right")
	_check(player.facing().dot(f0) > 0.95 and absf(player.velocity.normalized().dot(f0)) < 0.3, "L2/R2 sidestep without turning")
	await _frames(30)
	Input.action_press("walk")
	Input.action_press("move_forward")
	await _frames(30)
	_check(player.move_mode.begins_with("Walking"), "Holding WALK sneaks quietly")
	Input.action_release("walk")
	Input.action_release("move_forward")
	await _frames(30)

	# --- 2. R1 locks onto the enemy in front; the lock tightens.
	var e0 = es[0]
	_place_facing(player, e0, 40.0, true)
	await _frames(20)
	Input.action_press("lock")
	await _frames(3)
	_check(player.target == e0, "Holding LOCK grabs the enemy in front")
	var l0: float = player.lock
	await _frames(70)
	_check(player.lock >= 0.999 and player.lock > l0, "Standing still you reach a full lock")

	# --- 3. Full-lock shot on an unaware enemy: silent kill.
	_check(e0.is_unaware(), "He hasn't noticed you")
	player.fire()
	await _frames(2)
	_check(e0.dead, "Full-lock shot on an unaware mech: SILENT KILL")
	_check(main.downed == 1, "Counter goes up")
	Input.action_release("lock")
	await _frames(5)

	# --- 4. Full-body lock; push the right stick up to aim at the HEAD.
	var e1 = es[1]
	_place_facing(player, e1, 35.0, false)
	e1.state = e1.State.COMBAT
	await _frames(3)
	Input.action_press("lock")
	await _frames(3)
	_check(player.part == "body", "Lock-on aims at the whole body (center mass)")
	Input.action_press("look_up", 1.0)
	await _frames(20)
	_check(player.part == "head", "Right stick up slides the aim to the HEAD")
	player.lock = 1.0
	player.fire_cd = 0.0
	player.fire()
	await _frames(3)
	_check(e1.lost_head and e1.dead, "Full-lock headshot: HEAD OFF")
	Input.action_release("look_up")
	Input.action_release("lock")
	await _frames(5)

	# --- 5. Shoot the gun arm off: disarmed. He charges and slams instead.
	var e2 = es[2]
	e2.global_position = Vector3(-24, 0.2, 40)   # out on an open street
	_place_facing(player, e2, 30.0, false)
	e2.state = e2.State.COMBAT
	await _frames(3)
	Input.action_press("lock")
	await _frames(3)
	Input.action_press("look_right", 1.0)
	await _frames(20)
	_check(player.part == "arm", "Right stick sideways aims at the gun ARM")
	var shots := 0
	while not e2.lost_arm and shots < 12:
		player.lock = 1.0
		player.fire_cd = 0.0
		player.ammo = player.mag_size
		player.fire()
		shots += 1
		await _frames(2)
	_check(e2.lost_arm and not e2.dead, "Shooting the gun arm blows it off (%d shots)" % shots)
	_check(not e2.can_shoot(), "...and he can't shoot anymore")
	Input.action_release("look_right")
	Input.action_press("look_down", 1.0)
	await _frames(20)
	_check(player.part == "leg", "Right stick down aims at the LEG")
	shots = 0
	while not e2.lost_leg and shots < 12:
		player.lock = 1.0
		player.fire_cd = 0.0
		player.ammo = player.mag_size
		player.fire()
		shots += 1
		await _frames(2)
	_check(e2.lost_leg and not e2.dead, "Shooting a leg takes it off at the knee (%d shots)" % shots)
	Input.action_release("look_down")
	Input.action_release("lock")
	await _frames(3)
	_place_facing(player, e2, 16.0, false)
	await _frames(2)
	e2.frozen = false
	var hp_b: int = player.hp
	var bashed := false
	for i in 600:
		await physics_frame
		if e2.is_bashing():
			bashed = true
		if player.hp < hp_b:
			break
	_check(bashed, "Disarmed, he winds up a slam (visor flashes)")
	_check(player.hp < hp_b, "...and the slam hurts if you stand there")
	e2.frozen = true
	player.hp = player.MAX_HP
	await _frames(40)
	# A fresh, armed enemy for the rest of the tests
	e1 = CharacterBody3D.new()
	e1.set_script(load("res://scripts/enemy.gd"))
	e1.position = Vector3(24, 0.2, 60)
	main.add_child(e1)
	e1.city = city
	e1.frozen = true
	await _frames(3)
	_place_facing(player, e1, 35.0, false)
	e1.state = e1.State.COMBAT
	await _frames(3)

	# --- 5b. Reload.
	player.ammo = 0
	player.fire()
	_check(player.reload_t > 0.0, "Empty magazine: auto reload")
	await _frames(int(player.reload_time * 60) + 5)
	_check(player.ammo == player.mag_size, "Reload refills the magazine")

	# --- 5c. Jump.
	player.global_position = Vector3(-72, 0.2, 10)
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := 0.0
	for i in 40:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	_check(peak > 2.0, "Mech jumps (%.1f m)" % peak)
	await _frames(40)

	# --- 5d. Enemies dodge: lock on and settle, and he rolls out of it.
	_place_facing(player, e1, 35.0, false)
	e1.state = e1.State.COMBAT
	e1.frozen = false
	e1.dodge_cd = 0.0
	e1.fire_cd = 99.0
	Input.action_press("lock")
	var dodged := false
	for i in 240:
		await physics_frame
		if e1.roll_t > 0.0:
			dodged = true
			break
	_check(dodged, "Lock onto him and he dodge-rolls out of it")
	await _frames(40)
	Input.action_release("lock")
	e1.frozen = true
	e1.fire_cd = 0.0
	await _frames(30)

	# --- 6. Enemy telegraphs with a laser, then bursts. Rolling dodges.
	_place_facing(player, e1, 35.0, false)
	e1.state = e1.State.COMBAT
	await _frames(3)
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
	e2 = es[0]
	e2.dead = false
	e2.state = e2.State.PATROL
	e2.hear_noise(e2.global_position + Vector3(30, 0, 0), player.WALK_NOISE, player)
	_check(e2.state == e2.State.PATROL, "Walking 30 m away goes unheard")
	e2.hear_noise(e2.global_position + Vector3(30, 0, 0), player.RUN_NOISE, player)
	_check(e2.state == e2.State.INVESTIGATE, "Running 30 m away gets him investigating")

	# --- 11. B standing still crouches; B while running rolls.
	player.crouching = false
	player.velocity = Vector3.ZERO
	await _frames(20)
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	_check(player.crouching, "B standing still: crouch")
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	player.crouching = false
	await _frames(40)
	Input.action_press("move_forward")
	await _frames(10)
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	_check(player.roll_t > 0.0, "B while running: combat roll")
	Input.action_release("move_forward")
	await _frames(40)

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
	for name in ["fire", "roll", "reload", "jump"]:
		t._touch_down(1, t.buttons[name].pos)
		var ok := Input.is_action_pressed(t.buttons[name].action)
		t._touch_up(1)
		_check(ok, "Touch %s button works" % name.to_upper())
	t._touch_down(1, t.buttons["lock"].pos)
	t._touch_up(1)
	_check(Input.is_action_pressed("lock"), "Touch LOCK toggles on")
	t._touch_down(1, t.buttons["lock"].pos)
	t._touch_up(1)
	_check(not Input.is_action_pressed("lock"), "...and off")

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
