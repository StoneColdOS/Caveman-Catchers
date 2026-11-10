extends SceneTree
## Plays the core loop automatically and checks it works.
## Run: godot --headless --path . -s res://tests/test_catch.gd

const Fighter := preload("res://scripts/fighter.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Fighter.hitstop_enabled = false
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
		_freeze(e)

	# --- 1. Backstab: sneak up behind an unaware mech, one cut.
	var e0 = es[0]
	_place_behind(player, e0, 7.0)
	await _frames(2)
	_check(e0.is_unaware(), "Enemy hasn't noticed you behind him")
	player.set_stance(player.Stance.MID)
	player.start_swing()
	await _swing_done(player)
	_check(e0.dead, "Cut from behind: one hit takes him down")
	_check(main.downed == 1, "Counter goes up")

	# --- 2. Seen from the front: suspicious, then a duel.
	var e1 = es[1]
	e1.frozen = false
	_place_front(player, e1, 25.0)
	await _frames(10)
	_check(e1.state == e1.State.SUSPICIOUS or e1.state == e1.State.DUEL, "He sees you and gets suspicious")
	await _frames(120)
	_check(e1.is_dueling(), "Spotted: he squares up for a duel")
	await _frames(2)
	_check(player.lock_target == e1, "Your mech locks on to him")
	e1.frozen = true
	e1.velocity = Vector3.ZERO

	# --- 3. Guard blocks MID and LOW; HIGH breaks it.
	_reset(e1)
	e1.state = e1.State.DUEL
	_place_front(player, e1, 8.0)
	await _frames(2)
	e1.guarding = true
	player.set_stance(player.Stance.MID)
	player.start_swing()
	await _swing_done(player)
	_check(e1.hp == e1.MAX_HP and player.stagger > 0.0, "Guard blocks a MID cut and you recoil")
	await _frames(40)
	_reset(e1)
	e1.state = e1.State.DUEL
	e1.guarding = true
	player.set_stance(player.Stance.HIGH)
	player.start_swing()
	await _swing_done(player)
	_check(e1.hp == e1.MAX_HP and e1.stagger > 0.0 and not e1.guarding, "HIGH cut smashes through his guard (guard break)")
	await _frames(70)

	# --- 4. LOW cripples, MID finishes.
	_reset(e1)
	e1.state = e1.State.DUEL
	_place_front(player, e1, 8.0)
	await _frames(2)
	player.set_stance(player.Stance.LOW)
	player.start_swing()
	await _swing_done(player)
	_check(e1.crippled and e1.hp == e1.MAX_HP - 1, "LOW cut cripples his leg")
	await _frames(40)
	e1.stagger = 0.0
	_place_front(player, e1, 8.0)   # step back in after knocking him back
	await _frames(2)
	player.set_stance(player.Stance.MID)
	player.start_swing()
	await _swing_done(player)
	_check(e1.dead, "Follow up with MID: he's down")

	# --- 5. Two blades at once clash.
	var e2 = es[2]
	_reset(e2)
	e2.state = e2.State.DUEL
	_place_front(player, e2, 8.0)
	await _frames(2)
	e2.swing = e2.SWING_STRIKE
	var r: String = e2.receive_strike(player, player.Stance.MID)
	_check(r == "clash" and e2.hp == e2.MAX_HP, "Strikes landing together clash")
	await _frames(40)

	# --- 6. His swing hits you if you stand there; guard blocks it.
	_reset(e2)
	e2.state = e2.State.DUEL
	player.stagger = 0.0
	var hp0: int = player.hp
	e2.set_stance(e2.Stance.MID)
	e2.start_swing()
	await _swing_done(e2)
	_check(player.hp == hp0 - 2, "His MID cut hits you for 2")
	await _frames(40)
	player.stagger = 0.0
	e2.stagger = 0.0
	_place_front(player, e2, 8.0)
	Input.action_press("guard")
	await _frames(2)
	e2.start_swing()
	await _swing_done(e2)
	Input.action_release("guard")
	_check(player.hp == hp0 - 2 and e2.stagger > 0.0, "Holding guard blocks it and he recoils")
	await _frames(40)

	# --- 7. Stance switching.
	player.set_stance(player.Stance.MID)
	Input.action_press("stance_cycle")
	await _frames(2)
	Input.action_release("stance_cycle")
	_check(player.stance == player.Stance.HIGH, "Stance button cycles MID -> HIGH")
	Input.action_press("stance_low")
	await _frames(2)
	Input.action_release("stance_low")
	_check(player.stance == player.Stance.LOW, "D-pad down picks LOW")

	# --- 8. Destruction: your sword cuts through a building.
	var b: Node3D = null
	for cand in city.buildings:
		if cand.global_position.distance_to(e2.global_position) > 30.0:
			b = cand
			break
	var half: Vector3 = b.get_meta("half")
	player.global_position = Vector3(b.global_position.x, 0.2, b.global_position.z + half.z + 6.0)
	player.rig.rotation.y = PI
	player.lock_enabled = false
	player.lock_target = null
	await _frames(3)
	var n0: int = city.buildings.size()
	player.set_stance(player.Stance.MID)
	player.start_swing()
	await _swing_done(player)
	_check(city.buildings.size() < n0 and not is_instance_valid(b) or b.is_queued_for_deletion(), "Sword cut brings a building down")
	await _frames(5)
	_check(city.debris.size() > 3, "It collapses into chunks (%d)" % city.debris.size())

	# --- 9. Charging into a low building smashes through it; tall ones hold.
	var low: Node3D = null
	var tall: Node3D = null
	for cand in city.buildings:
		var hh: float = cand.get_meta("half").y * 2.0
		if hh < 9.0 and low == null:
			low = cand
		if hh > 16.0 and tall == null:
			tall = cand
	_check(city.smash(low, low.global_position + Vector3(0, 0, 20), 12.0), "Running into a low shop smashes it")
	_check(tall == null or not city.smash(tall, tall.global_position + Vector3(0, 0, 20), 12.0), "Tall buildings need the sword")

	# --- 10. Props go flying when a mech walks into them.
	var prop: RigidBody3D = city.props[0]
	_check(prop.freeze, "Props stand still until touched")
	var pushed: int = city.push_props(prop.global_position + Vector3(1, 0, 0), 1.8, Vector3(-6, 0, 0))
	_check(pushed > 0 and not prop.freeze, "Walking into a prop knocks it flying")

	# --- 11. Hearing: loud stomps get investigated, collapses carry far.
	var listener = e2
	_reset(listener)
	listener.state = listener.State.PATROL
	listener.hear_noise(listener.global_position + Vector3(30, 0, 0), player.WALK_NOISE, player)
	_check(listener.state == listener.State.PATROL, "Quiet walking 30 m away goes unheard")
	listener.hear_noise(listener.global_position + Vector3(30, 0, 0), player.RUN_NOISE, player)
	_check(listener.state == listener.State.INVESTIGATE, "Running 30 m away gets him investigating")

	# --- 12. Dash.
	player.global_position = Vector3(-72, 0.2, 0)
	player.velocity = Vector3.ZERO
	player.stagger = 0.0
	await _frames(40)
	player.dash_cd = 0.0
	var p0: Vector3 = player.global_position
	player.dash()
	await _frames(20)
	_check(player.global_position.distance_to(p0) > 4.0, "Dash bursts you across the street")

	# --- 13. Lose all your armor: defeated.
	while not player.dead:
		player.stagger = 0.0
		player.receive_strike(e2, player.Stance.HIGH)
	await _frames(2)
	_check(player.dead and main.game_over, "Armor gone: DEFEATED")

	# --- 14. Touch controls drive the same actions.
	var TouchScript := load("res://scripts/touch_controls.gd")
	var t: Control = TouchScript.new()
	t.player = player
	main.add_child(t)
	await _frames(2)
	t._touch_down(0, Vector2(100, 600))
	t._touch_move(0, Vector2(100 + t.STICK_RADIUS, 600))
	_check(Input.get_action_strength("move_right") > 0.9, "Touch joystick: full push = run")
	t._touch_move(0, Vector2(100 + t.STICK_RADIUS * 0.4, 600))
	var st := Input.get_action_strength("move_right")
	_check(st > 0.3 and st < 0.5, "Touch joystick: light push = walk")
	t._touch_up(0)
	for name in ["slash", "guard", "dash", "stance", "lock"]:
		t._touch_down(1, t.buttons[name].pos)
		var ok := Input.is_action_pressed(t.buttons[name].action)
		t._touch_up(1)
		_check(ok, "Touch %s button works" % name.to_upper())

	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures))
	quit(failures)


func _freeze(e) -> void:
	e.frozen = true
	e.velocity = Vector3.ZERO


func _reset(e) -> void:
	e.hp = e.MAX_HP
	e.crippled = false
	e.stagger = 0.0
	e.guarding = false
	e.swing = e.SWING_NONE
	e.frozen = true
	e.velocity = Vector3.ZERO


## Player stands `dist` behind the enemy, both facing the same way.
func _place_behind(player, e, dist: float) -> void:
	e.heading = 0.0
	e.rig.rotation.y = 0.0
	player.global_position = e.global_position + Vector3(0, 0, -dist)
	player.rig.rotation.y = 0.0
	player.velocity = Vector3.ZERO


## Player and enemy face each other, `dist` apart.
func _place_front(player, e, dist: float) -> void:
	e.heading = PI
	e.rig.rotation.y = PI
	player.global_position = e.global_position + Vector3(0, 0, -dist)
	player.rig.rotation.y = 0.0
	player.velocity = Vector3.ZERO


func _swing_done(f) -> void:
	for i in 200:
		await physics_frame
		if f.swing == f.SWING_RECOVER or f.swing == f.SWING_NONE:
			break


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1
