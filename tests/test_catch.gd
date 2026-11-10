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
	var kinds := {}
	for e in es:
		e.frozen = true
		kinds[e.kind] = kinds.get(e.kind, 0) + 1
	_check(es.size() == 4 and kinds.get("swordsman", 0) == 4, "4 sword mechs spawned (everyone has a blade)")
	_check(player.weapon == "katana" and player.rig.weapon == "katana", "You carry a katana")

	# --- 1. Phantom Pain movement: walk, jog, sprint, smooth ramp.
	player.global_position = Vector3(-72, 0.2, 75)
	player.yaw = 0.0
	player.rig.rotation.y = PI
	await _frames(5)
	Input.action_press("move_forward", 0.4)
	await _frames(50)
	var walk := _hspeed(player)
	_check(walk > 1.5 and walk < 5.0, "Light push walks (%.1f m/s)" % walk)
	Input.action_press("move_forward", 1.0)
	await _frames(50)
	var jog := _hspeed(player)
	_check(jog > 7.5 and jog < 10.0, "Full push jogs (%.1f m/s)" % jog)
	Input.action_press("sprint")
	await _frames(3)
	var early := _hspeed(player)
	await _frames(60)
	var sprint := _hspeed(player)
	_check(early < 14.0 and sprint > 20.0, "Hold R1: ninja run (%.1f m/s)" % sprint)
	_check(player.is_ninja_running() and player.rig.body_root.rotation.x > 0.6, "Ninja run: ducked low, torso flat forward")
	# Dive out of a sprint
	var p0: Vector3 = player.global_position
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	_check(player.dive_t > 0.0, "B while ninja running: dive")
	await _frames(55)
	_check(player.global_position.distance_to(p0) > 8.0 and player.dive_t <= 0.0, "Dive launches you forward and you slide to a stop")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(40)
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	_check(player.crouching, "B standing still: crouch")
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	player.crouching = false
	await _frames(5)

	# Ninja leap
	player.global_position = Vector3(-72, 0.2, 30)
	await _frames(20)
	Input.action_press("move_forward", 1.0)
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var peak := 0.0
	var flipped := false
	for i in 90:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
		if player.flip > 0.3:
			flipped = true
	Input.action_release("move_forward")
	_check(peak > 5.0, "A: big ninja leap (%.1f m)" % peak)
	_check(flipped, "...with a front flip when you're moving")
	await _frames(30)

	# --- 2. R2 combo on a swordsman: cuts flow into each other, 4th is a finisher.
	var sw = _first(es, "swordsman")
	_face_off(player, sw, 7.0)
	await _frames(3)
	sw.hp = 40                                  # tough enough that the finisher doesn't cut him through
	var hp0: int = sw.hp
	var angles := []
	var strike_kinds := []
	for i in 4:
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		angles.append(player.swing_angle)
		strike_kinds.append(player.swing_kind)
		await _swing_done(player)
	_check(sw.hp == hp0 - 10 and not sw.dead, "R2 x4: three cuts and a finisher land (%d -> %d)" % [hp0, sw.hp])
	_check(strike_kinds[0] == "slash" and strike_kinds[2] == "slash" and strike_kinds[3] == "finisher", "Every 4th cut in a chain is a finisher (%s)" % [strike_kinds])
	var flow := absf(wrapf(angles[1] - angles[0] - PI, -PI, PI))
	_check(flow < 0.7 and angles[1] != angles[2], "Each cut swings back from where the last ended (off by %.2f)" % flow)
	await _frames(40)
	_check(city._puddles.size() > 0, "Oil splashes onto the street (%d puddles)" % city._puddles.size())

	# --- 2b. R2 buffering, stick direction, lunge.
	_reset(sw)
	_face_off(player, sw, 7.0)
	player.stagger = 0.0
	player.combo_window = 0.0
	await _frames(30)
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _frames(3)
	Input.action_press("attack")              # pulled again mid-cut: it waits, then chains
	await _frames(2)
	Input.action_release("attack")
	var first_angle: float = player.swing_angle
	var chained := false
	for i in 80:
		await physics_frame
		if player.swing_angle != first_angle and player.swing != 0:
			chained = true
			break
	_check(chained, "Pulling R2 during a cut chains the next one straight after")
	await _swing_done(player)
	await _frames(50)
	player.combo_window = 0.0
	Input.action_press("look_right", 1.0)      # hold the stick right...
	Input.action_press("attack")              # ...and strike: the slash goes left to right on screen
	await _frames(2)
	Input.action_release("attack")
	Input.action_release("look_right")
	_check(absf(wrapf(player.swing_angle - PI, -PI, PI)) < 0.01, "Stick held right + R2: slash travels to the right")
	await _swing_done(player)
	await _frames(50)
	_reset(sw)
	_face_off(player, sw, 7.0)
	player.global_position = sw.global_position + Vector3(0, 0, 17)   # from the open side of the street
	player.rig.rotation.y = PI
	player.yaw = 0.0
	sw.rig.rotation.y = 0.0
	player.combo_window = 0.0
	await _frames(3)
	var hp_l: int = sw.hp
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	await _swing_done(player)
	var gap: float = player.global_position.distance_to(sw.global_position)
	_check(gap < 13.0 and sw.hp < hp_l, "R2 from 17 m: he lunges in and the cut lands (now %.1f m, hp %d -> %d)" % [gap, hp_l, sw.hp])
	await _frames(40)
	# The finisher smashes a guard
	_reset(sw)
	_face_off(player, sw, 7.0)
	sw.guarding = true
	player.stagger = 0.0
	await _frames(3)
	player.start_swing("finisher", 0.0)
	await _swing_done(player)
	_check(not sw.guarding and sw.stagger > 0.5 and sw.hp == sw.MAX_HP, "A finisher breaks his guard")
	await _frames(40)
	# Clash: both blades land together
	_reset(sw)
	sw.swing = 2
	var cr: String = sw.receive_slash(player, "slash", 0.0)
	_check(cr == "clash" and sw.hp == sw.MAX_HP, "Blades landing together CLASH")
	await _frames(40)
	# The camera frames whoever you're fighting
	sw.state = sw.State.COMBAT
	await _frames(5)
	_check(player.combat_target == sw, "Camera locks onto the mech you're fighting")

	# --- 3. Guard: blocks a normal cut (you recoil).
	_reset(sw)
	sw.guarding = true
	_face_off(player, sw, 7.0)
	player.stagger = 0.0
	await _frames(3)
	player.start_swing("slash", 0.0)
	await _swing_done(player)
	_check(sw.hp == sw.MAX_HP and player.stagger > 0.0, "His guard blocks a normal cut (you recoil)")
	await _frames(60)

	# --- 4. Parry: raise guard just as his blade lands.
	_reset(sw)
	_face_off(player, sw, 7.0)
	player.stagger = 0.0
	await _frames(3)
	sw.start_swing("light", 0.0)
	for i in 200:
		await physics_frame
		if sw.swing == 2 or (sw.swing == 1 and sw.swing_t < 0.05):
			break
	Input.action_press("guard")
	await _swing_done(sw)
	Input.action_release("guard")
	_check(sw.exposed > 0.0 and sw.stagger > 0.0 and player.hp == player.MAX_HP, "Parry: he reels, wide open, and you take nothing")
	await _frames(40)

	# --- 5. His unblocked slash hurts.
	_reset(sw)
	player.stagger = 0.0
	var php: int = player.hp
	sw.start_swing("light", 0.0)
	await _swing_done(sw)
	_check(player.hp < php, "Stand there and his slash hurts")
	await _frames(40)
	player.hp = player.MAX_HP

	# --- 6. Guard deflects bullets; without it they hurt.
	var gn = _spawn(main, "gunner", Vector3(-72, 0.2, -20))
	await _frames(3)
	_reset(gn)
	gn.global_position = Vector3(-72, 0.2, -20)
	player.global_position = Vector3(-72, 0.2, 10)
	player.rig.rotation.y = PI
	gn.heading = 0.0
	gn.rig.rotation.y = 0.0
	player.stagger = 0.0
	await _frames(5)
	Input.action_press("guard")
	await _frames(3)
	var hpg: int = player.hp
	for i in 3:
		gn.shoot_at(player.center(), 0.0, 1)
	_check(player.hp == hpg, "Guard deflects bullets")
	Input.action_release("guard")
	await _frames(3)
	gn.shoot_at(player.center(), 0.0, 1)
	_check(player.hp < hpg, "Without guard the bullets hurt")
	player.hp = player.MAX_HP

	# --- 7. Blade Mode: time slows, cut line, sever along the line.
	var sw2 = _second(es, "swordsman")
	sw.global_position = Vector3(72, 0.2, -72)   # out of the way
	_reset(sw2)
	_face_off(player, sw2, 9.0)
	await _frames(5)
	player.energy = player.MAX_ENERGY
	player.stagger = 0.0
	Input.action_press("blade")
	await _frames(3)
	_check(player.in_blade_mode() and Engine.time_scale < 0.2, "Hold L2: Blade Mode, time slows to a crawl")
	_check(player.blade_target == sw2, "The cut line goes on the nearest enemy")
	# Vertical cut through his sword arm
	player.cut_offset = _plane(player, sw2, "arm_r")
	var r: Array = player.blade_cut(PI / 2.0)
	_check(sw2.lost.has("arm_r") and sw2.disarmed() and not sw2.dead, "Cut through his sword arm: it comes off, he's disarmed (%s)" % [r])
	await _frames(3)
	# Horizontal cut through the waist while he's still healthy: the armor holds
	player.cut_cd = 0.0
	player.cut_offset = _plane(player, sw2, "waist")
	r = player.blade_cut(0.0)
	_check(not sw2.dead and not sw2.lost.has("upper"), "Full armor: a torso cut skids off (%s)" % [r])
	await _frames(3)
	# Weakened now: cut him in half
	sw2.hp = 4
	player.hp = 10
	player.cut_cd = 0.0
	player.cut_offset = _plane(player, sw2, "waist")
	r = player.blade_cut(0.05)
	_check(sw2.dead and sw2.lost.has("upper"), "Weakened: cut him in half (%s)" % [r])
	_check(player.hp > 10 and player.last_result == "zandatsu", "Finishing cut repairs your armor")
	_check(player.energy < player.MAX_ENERGY + 1, "Blade Mode runs on energy")
	Input.action_release("blade")
	await _frames(3)
	_check(not player.in_blade_mode() and Engine.time_scale == 1.0, "Let go: back to normal speed")
	_check(main.downed >= 1, "Counter goes up")

	# --- 8. Blade Mode leg cut: he limps.
	_reset(gn)
	_face_off(player, gn, 9.0)
	await _frames(5)
	player.energy = player.MAX_ENERGY
	player.stagger = 0.0
	Input.action_press("blade")
	await _frames(3)
	player.blade_target = gn
	player.cut_offset = _plane(player, gn, "leg_l")
	player.cut_cd = 0.0
	player.blade_cut(PI / 2.0)
	_check(gn.lost.has("leg_l") and gn.legs_lost() == 1, "Cut a leg off: he limps")
	Input.action_release("blade")
	await _frames(5)

	# --- 9. Sneak attack: slash an unaware mech from behind and he's exposed.
	var g2 = _spawn(main, "gunner", Vector3(24, 0.2, 60))
	await _frames(3)
	_reset(g2)
	g2.state = g2.State.PATROL
	g2.global_position = Vector3(24, 0.2, 60)
	g2.heading = 0.0
	g2.rig.rotation.y = 0.0
	player.global_position = g2.global_position + Vector3(0, 0, -7)
	player.rig.rotation.y = 0.0
	player.stagger = 0.0
	await _frames(3)
	player.start_swing("slash", 0.0)
	await _swing_done(player)
	_check(g2.exposed > 0.0 and g2.weakened(), "Cut him from behind before he knows: he's wide open")

	# --- 10. Destruction: a slash brings a building down.
	var b: Node3D = null
	for cand in city.buildings:
		if cand.global_position.distance_to(g2.global_position) > 30.0 and cand.get_meta("half").y * 2.0 < 12.0:
			b = cand
			break
	var half: Vector3 = b.get_meta("half")
	player.global_position = Vector3(b.global_position.x, 0.2, b.global_position.z + half.z + 6.0)
	player.rig.rotation.y = PI
	player.stagger = 0.0
	await _frames(3)
	var n0: int = city.buildings.size()
	player.start_swing("finisher", 0.0)
	await _swing_done(player)
	_check(city.buildings.size() < n0, "A slash cuts a building down")

	# --- 11. Hearing.
	var e3 = g2
	e3.state = e3.State.PATROL
	e3.hear_noise(e3.global_position + Vector3(30, 0, 0), player.WALK_NOISE, player)
	_check(e3.state == e3.State.PATROL, "Walking 30 m away goes unheard")
	e3.hear_noise(e3.global_position + Vector3(30, 0, 0), player.SPRINT_NOISE, player)
	_check(e3.state == e3.State.INVESTIGATE, "Sprinting 30 m away gets him looking")

	# --- 12. Armor gone: defeated.
	while not player.dead:
		player.stagger = 0.0
		player.roll_t = 0.0
		player.take_shot(e3, 5, player.center())
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
	_check(Input.get_action_strength("move_right") > 0.9, "Touch joystick: full push")
	t._touch_up(0)
	for name in ["guard", "dodge", "jump"]:
		t._touch_down(1, t.buttons[name].pos)
		var ok := Input.is_action_pressed(t.buttons[name].action)
		t._touch_up(1)
		_check(ok, "Touch %s button works" % name.to_upper())
	t._touch_down(1, t.buttons["blade"].pos)
	t._touch_up(1)
	_check(Input.is_action_pressed("blade"), "Touch BLADE toggles Blade Mode on")
	t._touch_down(1, t.buttons["blade"].pos)
	t._touch_up(1)
	_check(not Input.is_action_pressed("blade"), "...and off")

	Engine.time_scale = 1.0
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	quit(failures)


func _spawn(main, kind: String, at: Vector3) -> Node:
	var e := CharacterBody3D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.kind = kind
	e.position = at
	main.add_child(e)
	e.city = main.city
	e.frozen = true
	return e


func _first(es: Array, kind: String) -> Node:
	for e in es:
		if e.kind == kind:
			return e
	return null


func _second(es: Array, kind: String) -> Node:
	var seen := false
	for e in es:
		if e.kind == kind:
			if seen:
				return e
			seen = true
	return null


func _hspeed(m) -> float:
	return Vector2(m.velocity.x, m.velocity.z).length()


func _reset(e) -> void:
	e.frozen = true
	e.stagger = 0.0
	e.guarding = false
	e.swing = 0
	e.exposed = 0.0
	e.velocity = Vector3.ZERO
	if not e.dead:
		e.hp = e.MAX_HP


## Player and enemy face each other on an open street, `dist` apart.
func _face_off(player, e, dist: float) -> void:
	e.global_position = Vector3(-24, 0.2, 40)
	e.heading = PI
	e.rig.rotation.y = PI
	player.global_position = e.global_position + Vector3(0, 0, -dist)
	player.rig.rotation.y = 0.0
	player.yaw = PI
	player.velocity = Vector3.ZERO


## Where a body part sits on the cut plane (for aiming a Blade Mode line through it).
func _plane(player, e, part: String) -> Vector2:
	var right: Vector3 = player.camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var w: Vector3 = e.rig.part_point(part) - e.center()
	return Vector2(w.dot(right), w.dot(Vector3.UP))


func _swing_done(f) -> void:
	for i in 300:
		await physics_frame
		if f.swing == 3 or f.swing == 0:
			break


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if what == "":
		return
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
