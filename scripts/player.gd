extends "res://scripts/fighter.gd"
## Your mech: a 10 m cyborg swordsman. Moves like an anime ninja, fights with the stick.
##
## SWORD   R2 strikes. Keep pulling it and the cuts flow into each other, each one
##         starting where the last ended, lunging you onto the enemy. Every 4th cut
##         in a chain is a huge finisher that breaks guards. Hold the right stick in
##         a direction while you pull R2 to slash that way.
##         L1: guard. Raise it just as his blade lands to PARRY: he reels, wide open.
##         Blades that land together clash.
## MOVE    Hold R1: ninja run, ducked low, arms and blade streaming behind.
##         A: big ninja leap (flips when you're moving; lands on rooftops).
##         B: dash (moving, untouchable) / crouch (standing) / dive (ninja running).
##         The camera follows on its own and frames the enemy you're fighting.
## BLADE   Hold L2: time nearly stops. The right stick tilts the cut line, the left
## MODE    stick slides it, R2 cuts (pull it again and again). Whatever it crosses
##         comes off. Heads and torsos only give once he's weakened or parried.
##         A finishing cut through head or torso repairs your armor.

const WALK_SPEED := 4.0
const JOG_SPEED := 9.0
const SPRINT_SPEED := 23.0         # ninja run
const JUMP_SPEED := 20.0
const NINJA_JUMP_FORWARD := 26.0
const CROUCH_SPEED := 3.0
const ACCEL := 26.0
const DECEL := 34.0
const TURN_SPEED := 11.0
const FOLLOW_SPEED := 3.0
const COMBAT_RANGE := 28.0
const DIVE_TIME := 0.85
const DIVE_SPEED := 24.0
const MAX_HP := 30
const MAX_ENERGY := 100.0
const BLADE_DRAIN := 18.0         # per real second in Blade Mode
const CUT_COST := 12.0
const CUT_RANGE := 20.0
const TARGET_RANGE := 18.0
const OPENING_ANGLE := -PI / 4.0    # first cut of a chain: high right, down to low left
const COMBO_WINDOW := 0.75           # pull R2 again within this to keep the chain going
const FINISHER_EVERY := 4
const STRIKE_BUFFER := 0.3
const LUNGE_STOP := 7.0              # lunge until you're this close
const LUNGE_RANGE := 20.0
const WALK_NOISE := 15.0
const RUN_NOISE := 40.0
const SPRINT_NOISE := 60.0

var move_mode := "Standing"
var yaw := 0.0
var pitch := -0.16
var camera_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var shake := 0.0
var hurt := 0.0
var hit_marker := 0.0
var energy := MAX_ENERGY
var sprinting := false
var combo := 0
var combo_window := 0.0
var strike_buffer := 0.0          # a buffered R2 pull (fires as soon as you can)
var strike_dir := Vector2.ZERO    # screen direction held on the right stick (zero = flow)
var strike_target: Node = null    # who you lunge at / turn toward mid-strike
var last_strike_screen := 0.0
var _windup_held := 0.0
# Blade Mode
var blade_on := false
var blade_target: Node = null
var cut_angle := 0.0              # angle of the cut line on screen (0 = horizontal)
var cut_offset := Vector2.ZERO    # where the line sits on his body (meters)
var _flick_peak := 0.0
var _flick_t := 0.0
var _flick_angle := 0.0
var cut_cd := 0.0
var cuts_made := 0
var touch_cut_angle := 0.0
var touch_cutting := false
var combat_target: Node = null
var air_time := 0.0
var was_on_floor := true


func _ready() -> void:
	add_to_group("player")
	add_to_group("shakers")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_ENEMY
	_setup_mech(false, MAX_HP, "katana")
	_build_camera()


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 11.0
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 14.0
	arm.position = Vector3(4.0, 0.6, 0)        # over the right shoulder
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.5
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 400.0
	arm.add_child(camera)
	camera.make_current()
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 2.2
	fill.omni_range = 35.0
	fill.omni_attenuation = 1.0
	fill.light_specular = 0.0
	camera.add_child(fill)


func opponents() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func is_running() -> bool:
	return move_mode.begins_with("Jogging") or move_mode.begins_with("Ninja")


func is_sprinting() -> bool:
	return sprinting and move_mode.begins_with("Ninja")


func is_ninja_running() -> bool:
	return is_sprinting()


func in_blade_mode() -> bool:
	return blade_on


func add_shake(amount: float) -> void:
	shake = minf(1.6, shake + amount)


func _physics_process(delta: float) -> void:
	# Blade Mode slows the world; you keep moving at real speed
	var rdelta := delta / maxf(Engine.time_scale, 0.01) if blade_on else delta
	rdelta = minf(rdelta, 0.05)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if dead:
		input = Vector2.ZERO
		_exit_blade_mode()
	else:
		_combat_input(rdelta, input, look)

	# --- Camera: automatic (the right stick is your sword). Frames the enemy you're
	# fighting; otherwise swings in behind you as you move.
	_update_combat_target()
	var focus: Node = blade_target if blade_on and is_instance_valid(blade_target) else combat_target
	if Input.is_action_just_pressed("recenter"):
		yaw = rig.rotation.y + PI
	if focus and not is_sprinting():
		var to: Vector3 = focus.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z) + 0.5, clampf(5.0 * rdelta, 0.0, 1.0))
		pitch = lerp(pitch, -0.2, clampf(3.0 * rdelta, 0.0, 1.0))
	elif input.length() > 0.2 or is_sprinting():
		yaw = lerp_angle(yaw, rig.rotation.y + PI, clampf(FOLLOW_SPEED * rdelta, 0.0, 1.0))
		pitch = lerp(pitch, -0.16, clampf(2.0 * rdelta, 0.0, 1.0))
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	var kc := clampf(6.0 * rdelta, 0.0, 1.0)
	var sprint_view := is_sprinting()
	var fighting := focus != null and not sprint_view
	arm.spring_length = lerp(arm.spring_length, 10.0 if blade_on else (17.0 if sprint_view else (12.0 if fighting else 14.0)), kc)
	camera_pivot.position.y = lerp(camera_pivot.position.y, 9.5 if fighting or blade_on else 11.0, kc)
	arm.position.x = lerp(arm.position.x, 5.0 if blade_on else (2.0 if sprint_view else 4.0), kc)
	camera.fov = lerp(camera.fov, 55.0 if blade_on else (88.0 if sprint_view else 68.0), kc)
	shake = maxf(0.0, shake - rdelta * 2.5)
	camera.h_offset = randf_range(-1, 1) * shake * 0.5
	camera.v_offset = randf_range(-1, 1) * shake * 0.5
	hurt = maxf(0.0, hurt - rdelta * 2.0)
	hit_marker = maxf(0.0, hit_marker - rdelta)

	# --- Movement
	var dir := Vector3.ZERO
	var tilt := input.length()
	if tilt > 0.15:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	var want_v := Vector3.ZERO
	var noise := 0.0
	sprinting = Input.is_action_pressed("sprint") and not crouching and legs_lost() == 0 and not guarding
	if dead:
		move_mode = "WRECKED"
	elif blade_on:
		move_mode = "BLADE MODE"
	elif dive_t > 0.0:
		move_mode = "Diving"
		var u := 1.0 - dive_t / DIVE_TIME
		want_v = roll_dir * DIVE_SPEED * clampf(1.2 - u * 1.3, 0.0, 1.0)   # launch, then slide to a stop
	elif roll_t > 0.0:
		move_mode = "Rolling"
		want_v = roll_dir * ROLL_SPEED
	elif swing != 0 or stagger > 0.0:
		move_mode = "Fighting"
		if swing == 1 or swing == 2:
			want_v = facing() * (6.0 if swing == 2 else 0.0)              # step into the cut
			var tgt := strike_target
			if is_instance_valid(tgt) and not tgt.dead and stagger <= 0.0:
				var dist := Vector2(tgt.global_position.x - global_position.x, tgt.global_position.z - global_position.z).length()
				var lunge := clampf((dist - LUNGE_STOP) / 0.08, 0.0, 70.0)   # dash in, Rising style
				want_v = facing() * maxf(lunge, want_v.length())
	elif dir != Vector3.ZERO:
		var speed := 0.0
		if crouching:
			speed = CROUCH_SPEED
			move_mode = "Crouch-walking"
		elif guarding:
			speed = WALK_SPEED
			move_mode = "Guarding"
		elif sprinting:
			speed = SPRINT_SPEED
			noise = SPRINT_NOISE
			move_mode = "Ninja running"
		elif tilt < 0.6 or Input.is_action_pressed("walk"):
			speed = lerpf(2.5, WALK_SPEED, clampf(tilt / 0.6, 0.0, 1.0))
			noise = WALK_NOISE
			move_mode = "Walking"
		else:
			speed = JOG_SPEED
			noise = RUN_NOISE
			move_mode = "Jogging"
		if legs_lost() > 0:
			speed *= 0.4
		want_v = dir * speed
	else:
		move_mode = "Crouching" if crouching else ("Guarding" if guarding else "Standing")
	var speeding_up := Vector2(want_v.x, want_v.z).length() > Vector2(velocity.x, velocity.z).length()
	var accel := ACCEL if speeding_up else DECEL
	if roll_t > 0.0 or dive_t > 0.0 or blade_on or swing == 1 or swing == 2:
		accel = 200.0
	if not is_on_floor():
		accel *= 0.35   # committed to the leap
	velocity.x = move_toward(velocity.x, want_v.x, accel * rdelta)
	velocity.z = move_toward(velocity.z, want_v.z, accel * rdelta)
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * rdelta
	var pre := velocity
	move_and_slide()
	var on_floor := is_on_floor()
	if not on_floor:
		air_time += rdelta
		if flip > 0.0:
			flip = minf(1.0, flip + rdelta / 0.75)
	elif not was_on_floor:
		if air_time > 0.3:
			add_shake(0.5)
			get_tree().call_group("enemies", "hear_noise", global_position, 40.0, self)
			if city:
				city.push_props(global_position, 5.0, Vector3.UP * 6.0)
		air_time = 0.0
		flip = 0.0
	was_on_floor = on_floor

	if city and not dead:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("breakable") and (roll_t > 0.0 or dive_t > 0.0 or is_sprinting()):
				city.smash(col, global_position, Vector2(pre.x, pre.z).length())
		city.push_props(global_position, 1.8, pre)

	# --- Facing: square up to the enemy you're fighting; otherwise face where you go
	if not dead and not blade_on and swing == 0 and dive_t <= 0.0 and roll_t <= 0.0:
		var face_to := dir
		if combat_target and not is_sprinting():
			face_to = combat_target.global_position - global_position
		elif guarding:
			face_to = Vector3.ZERO   # hold your facing behind the guard
		if face_to.length() > 0.1:
			var turn := TURN_SPEED * (0.55 if is_sprinting() else 1.0)
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(face_to.x, face_to.z), clampf(turn * rdelta, 0.0, 1.0))
	elif (swing == 1 or swing == 2) and is_instance_valid(strike_target) and not blade_on:
		# Mid-strike: whip around to face who you're cutting (fast, but not a snap)
		var to_t: Vector3 = strike_target.global_position - global_position
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(to_t.x, to_t.z), clampf(22.0 * rdelta, 0.0, 1.0))
	elif blade_on and is_instance_valid(blade_target):
		var to: Vector3 = blade_target.global_position - global_position
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(to.x, to.z), clampf(12.0 * rdelta, 0.0, 1.0))

	dive_t = maxf(0.0, dive_t - rdelta)
	_update_mech(rdelta)
	if rig.step_signal > 0.0 and noise > 0.0:
		get_tree().call_group("enemies", "hear_noise", global_position, noise, self)
		add_shake(0.12 if is_sprinting() else 0.04 * rig.gait)


func _combat_input(rdelta: float, input: Vector2, look: Vector2) -> void:
	combo_window -= rdelta
	if swing == 0:
		strike_target = null
	cut_cd -= rdelta
	if not blade_on:
		energy = minf(MAX_ENERGY, energy + 2.0 * rdelta)

	# Guard (raising it opens the parry window)
	var g := Input.is_action_pressed("guard") and weapon == "katana" and not disarmed()
	if g and not guarding and swing == 0 and stagger <= 0.0:
		guard_t = 0.0
	guarding = g and swing == 0 and stagger <= 0.0 and roll_t <= 0.0 and dive_t <= 0.0 and not blade_on

	# Blade Mode
	var can_enter := not dead and stagger <= 0.0 and roll_t <= 0.0 and dive_t <= 0.0 and (swing == 0 or swing == 3)
	if Input.is_action_pressed("blade") and not blade_on and energy >= 10.0 and can_enter and not disarmed():
		_enter_blade_mode()
	elif blade_on and (not Input.is_action_pressed("blade") or energy <= 0.0 or stagger > 0.0):
		_exit_blade_mode()
	if blade_on:
		_blade_mode_input(rdelta, input, look)
		return

	# A: ninja leap (flips when moving; a ninja-run leap goes a long way)
	if Input.is_action_just_pressed("jump") and is_on_floor() and roll_t <= 0.0 and dive_t <= 0.0 and swing != 2 and legs_lost() == 0:
		velocity.y = JUMP_SPEED
		crouching = false
		if input.length() > 0.2:
			flip = 0.01
			if is_sprinting():
				velocity.x += facing().x * (NINJA_JUMP_FORWARD - SPRINT_SPEED)
				velocity.z += facing().z * (NINJA_JUMP_FORWARD - SPRINT_SPEED)
		add_shake(0.2)

	# B: crouch / dash / dive
	if Input.is_action_just_pressed("roll"):
		if is_sprinting() and input.length() > 0.2:
			dive_t = DIVE_TIME
			roll_dir = facing()
			swing = 0
			get_tree().call_group("enemies", "hear_noise", global_position, 35.0, self)
			add_shake(0.4)
		elif input.length() > 0.2:
			start_roll(Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
		else:
			crouching = not crouching

	# R2: strike. Buffered, so pulling it during a cut chains straight into the next
	if Input.is_action_just_pressed("attack"):
		_buffer_strike(Vector2(look.x, -look.y))
	strike_buffer -= rdelta
	if strike_buffer > 0.0 and (swing == 0 or swing == 3) and stagger <= 0.0 and roll_t <= 0.0 and dive_t <= 0.0:
		strike_buffer = 0.0
		_strike(strike_dir)


func _buffer_strike(stick_screen: Vector2) -> void:
	strike_buffer = STRIKE_BUFFER
	strike_dir = stick_screen.normalized() if stick_screen.length() > 0.5 else Vector2.ZERO


## One cut. With no stick direction the chain flows by itself: each cut reverses
## the last one (with a shifting tilt), so it starts right where the last ended.
func _strike(screen_dir: Vector2) -> void:
	if combo_window <= 0.0:
		combo = 0
	combo += 1
	var finisher := combo % FINISHER_EVERY == 0
	var ang := OPENING_ANGLE
	if screen_dir != Vector2.ZERO:
		ang = PI - screen_dir.angle()              # screen right = the mech's -X
	elif combo > 1:
		ang = swing_angle + PI + (0.5 if combo % 2 == 0 else -0.35)
	if finisher and screen_dir == Vector2.ZERO:
		ang = swing_angle + PI                      # the finisher sweeps all the way back through
	ang = wrapf(ang, -PI, PI)
	swing = 0
	crouching = false
	strike_target = _nearest_enemy(LUNGE_RANGE, -0.2)
	if combat_target and is_instance_valid(combat_target) and not combat_target.dead and global_position.distance_to(combat_target.global_position) < LUNGE_RANGE:
		strike_target = combat_target
	if start_swing("finisher" if finisher else "slash", ang):
		last_strike_screen = wrapf(PI - ang, -PI, PI)
		combo_window = COMBO_WINDOW + SWING_TIMES[swing_kind][0] + SWING_TIMES[swing_kind][1]


## Dashing in from range: hold the cocked blade until he's in reach (briefly).
func _hold_windup(delta: float) -> bool:
	if not is_instance_valid(strike_target) or strike_target.dead or _windup_held > 0.3:
		_windup_held = 0.0
		return false
	var to: Vector3 = strike_target.global_position - global_position
	to.y = 0.0
	if to.length() > REACH - 2.0:
		_windup_held += delta
		return true
	_windup_held = 0.0
	return false


## Touch: a swipe on the right side of the screen strikes along it.
func touch_swipe(dir_screen: Vector2) -> void:
	if blade_on:
		touch_cut(dir_screen.angle())
	else:
		_buffer_strike(dir_screen.normalized())


## Snap to face the nearest enemy in front before a swing (soft targeting).
func _face_nearest() -> void:
	var t := _nearest_enemy(14.0, -0.2)
	if t:
		var to: Vector3 = t.global_position - global_position
		rig.rotation.y = atan2(to.x, to.z)


## The enemy you're fighting: the nearest one who's onto you (or very close).
func _update_combat_target() -> void:
	if combat_target and (not is_instance_valid(combat_target) or combat_target.dead or global_position.distance_to(combat_target.global_position) > COMBAT_RANGE + 8.0):
		combat_target = null
	var best: Node = null
	var best_d := COMBAT_RANGE
	for e in opponents():
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d and (e.is_fighting() or d < 14.0):
			best = e
			best_d = d
	if best and (combat_target == null or best_d < global_position.distance_to(combat_target.global_position) - 6.0):
		combat_target = best


func _nearest_enemy(reach: float, cone: float) -> Node:
	var cam_fwd := -camera.global_basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var best: Node = null
	var best_d := reach
	for e in opponents():
		if e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 6.0 or cam_fwd.dot(to / d) > cone):
			best = e
			best_d = d
	return best


# --- Blade Mode

func _enter_blade_mode() -> void:
	blade_on = true
	blade_mode_active = true
	Engine.time_scale = BLADE_SCALE
	blade_target = _nearest_enemy(TARGET_RANGE, 0.2)
	cut_offset = Vector2.ZERO
	cut_angle = 0.0
	crouching = false
	guarding = false
	swing = 0


func _exit_blade_mode() -> void:
	if not blade_on:
		return
	blade_on = false
	blade_mode_active = false
	Engine.time_scale = 1.0
	blade_target = null


## Right stick tilts the line, left stick slides it; R2 cuts.
func _blade_mode_input(rdelta: float, input: Vector2, look: Vector2) -> void:
	energy = maxf(0.0, energy - BLADE_DRAIN * rdelta)
	if blade_target and (not is_instance_valid(blade_target) or (blade_target.dead and blade_target.lost.has("upper"))):
		blade_target = _nearest_enemy(TARGET_RANGE, 0.2)
	cut_offset += Vector2(input.x, -input.y) * 5.0 * rdelta
	cut_offset = cut_offset.limit_length(4.5)
	var mag := look.length()
	if mag > 0.5:
		cut_angle = atan2(-look.y, look.x)   # the line previews where the stick points
	if touch_cutting:
		cut_angle = touch_cut_angle
	if Input.is_action_just_pressed("attack"):
		blade_cut(cut_angle)


## One Blade Mode cut along the current line.
func blade_cut(angle: float) -> Array:
	if not blade_on or cut_cd > 0.0 or energy < 1.0:
		return []
	cut_cd = 0.12
	energy = maxf(0.0, energy - CUT_COST)
	cuts_made += 1
	# Animate a real-speed slash along the same line
	swing = 2
	swing_kind = "slash"
	swing_angle = PI - angle if cuts_made % 2 == 0 else -angle   # along the line, alternating ends
	swing_len = 0.1
	swing_t = 0.1
	swing_hit = true
	_start_arc()
	add_shake(0.25)
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var axes := [right, Vector3.UP]
	var dir2 := Vector2(cos(angle), sin(angle))
	var result: Array = []
	var base: Vector3 = global_position + facing() * 9.0 + Vector3.UP * 6.0
	if is_instance_valid(blade_target) and not (blade_target.dead and blade_target.lost.has("upper")):
		base = blade_target.center()
		if blade_target.global_position.distance_to(global_position) < CUT_RANGE:
			var was_dead: bool = blade_target.dead
			result = blade_target.apply_cut(self, cut_offset, dir2, axes)
			if not result.is_empty() and result[0] != "armor":
				hit_marker = 0.25
				energy = minf(MAX_ENERGY, energy + 4.0 * result.size())
				if not was_dead and blade_target.dead and (result.has("upper") or result.has("head")):
					hp = mini(MAX_HP, hp + 8)       # finishing cut: repair
					energy = MAX_ENERGY
					last_result = "zandatsu"
				else:
					last_result = "cut"
			elif not result.is_empty():
				last_result = "armor"
	# Cut through anything else along the line: buildings, props
	if city:
		var p0: Vector3 = base + right * cut_offset.x + Vector3.UP * cut_offset.y
		var dw: Vector3 = right * dir2.x + Vector3.UP * dir2.y
		for t in range(-8, 9, 2):
			city.cut(p0 + dw * t, 1.5, global_position)
	return result


## Touch: a swipe on the right side of the screen while in Blade Mode.
func touch_cut(angle: float) -> void:
	touch_cutting = false
	blade_cut(angle)


# --- Taking hits

func receive_slash(attacker: Node, kind: String, angle: float) -> String:
	var r := super.receive_slash(attacker, kind, angle)
	if r == "parry":
		energy = minf(MAX_ENERGY, energy + 25.0)
		last_result = "parry"
	return r


func on_hit_taken(_from: Node, _damage: int) -> void:
	hurt = 1.0
	add_shake(0.5)
	_exit_blade_mode()


func die(by: Node) -> void:
	_exit_blade_mode()
	super.die(by)


## Our hits feed blade energy.
func note_hit(kind: String) -> void:
	hit_marker = 0.2
	energy = minf(MAX_ENERGY, energy + (12.0 if kind in BREAKERS else 8.0))


func _resolve_slash() -> void:
	super._resolve_slash()
	# A finisher through a weakened mech goes right through along the swing line
	if swing_kind == "finisher" and (last_result == "hit" or last_result == "break"):
		var t := _nearest_enemy(REACH, 0.2)
		if t and not t.dead and t.weakened():
			var right := camera.global_basis.x
			right.y = 0.0
			var cuts: Array = t.apply_cut(self, Vector2.ZERO, Vector2(cos(last_strike_screen), sin(last_strike_screen)), [right.normalized(), Vector3.UP])
			if not cuts.is_empty() and cuts[0] != "armor":
				last_result = "cut"
	if last_result == "hit" or last_result == "kill" or last_result == "break":
		note_hit(swing_kind)
