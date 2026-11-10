extends "res://scripts/fighter.gd"
## Your mech, with a full Syphon Filter movement system at 10 m tall:
##   RUN       Push the stick and you run: big bouncy strides, rifle raised, free arm
##             pumping. The mech turns to run where you push, and the camera swings
##             in behind you on its own. Hold WALK to sneak (quiet, slow).
##   SIDESTEP  L2 / R2 strafe left and right without turning.
##   LOCK      Hold R1 to lock onto the enemy in front. You keep running anywhere
##             (run and gun): legs go where you push, the upper body stays on him.
##             Pick a part with the D-pad / flick the right stick:
##               BODY  normal damage
##               HEAD  triple damage; a full-lock headshot takes the head off
##               ARM   shoot his gun arm off: he's disarmed
##               LEG   shoot a leg off at the knee: he crawls
##             The brackets close in white -> yellow -> red. Small parts take longer.
##             A full-lock shot on an enemy who hasn't noticed you is a silent kill.
##   AIM       Hold L1 for manual aim: tight over-the-shoulder crosshair, right stick
##             aims, you walk. Shots hit exactly where the crosshair is (headshots!).
##   ROLL      B while moving: combat roll, bullets pass through you.
##             B standing still: crouch. JUMP with A.

const RUN_SPEED := 13.0
const WALK_SPEED := 4.5
const CROUCH_SPEED := 3.0
const STRAFE_SPEED := 9.0
const LOCK_RUN_SPEED := 11.0
const AIM_WALK_SPEED := 3.5
const ACCEL := 60.0
const TURN_SPEED := 10.0          # how fast the mech swings to face where you run
const LOOK_SPEED := 2.4
const AIM_LOOK_SPEED := 1.2
const FOLLOW_SPEED := 4.5         # camera swinging back in behind you
const MAX_HP := 20
const LOCK_RANGE := 110.0
const LOCK_CONE := 0.4
const LOCK_TIME := {"body": 0.8, "leg": 1.0, "arm": 1.2, "head": 1.4}
const PARTS := ["body", "head", "arm", "leg"]
const FIRE_RATE := 0.16
const DAMAGE := 2
const FULL_LOCK_DAMAGE := 4
const SILENT_KILL := 99

const WALK_NOISE := 18.0
const RUN_NOISE := 50.0
const LAND_NOISE := 45.0

var move_mode := "Standing"
var yaw := 0.0
var pitch := -0.15
var camera_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var locking := false              # holding R1
var manual := false               # holding L1
var target: Node = null
var part := "body"
var lock := 0.0                   # 0..1, how settled your aim is
var fire_cd := 0.0
var look_idle := 0.0
var shake := 0.0
var hurt := 0.0
var hit_marker := 0.0
var last_result := ""
var was_on_floor := true
var air_time := 0.0
var _flick_ready := true


func _ready() -> void:
	add_to_group("player")
	add_to_group("shakers")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_ENEMY
	_setup_mech(false, MAX_HP)
	_build_camera()


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 9.5
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 16.0
	arm.position = Vector3(0.0, 1.0, 0)
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.5
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.far = 400.0
	arm.add_child(camera)
	camera.make_current()
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 1.4
	fill.omni_range = 30.0
	fill.omni_attenuation = 1.0
	fill.light_specular = 0.0
	camera.add_child(fill)


func is_aiming() -> bool:
	return (target != null or manual) and not dead and roll_t <= 0.0


func is_running() -> bool:
	return move_mode.begins_with("Running")


func aim_direction() -> Vector3:
	return (aim_point() - center()).normalized()


## Where your shots go: the locked part, or exactly down the crosshair.
func aim_point() -> Vector3:
	if target and is_instance_valid(target) and not target.dead:
		return target.rig.part_point(part)
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from + fwd * 12.0, from + fwd * SHOT_RANGE, Util.LAYER_WORLD | Util.LAYER_ENEMY)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else from + fwd * SHOT_RANGE


func add_shake(amount: float) -> void:
	shake = minf(1.5, shake + amount)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if dead:
		input = Vector2.ZERO
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if not dead:
		_input_actions(delta, input, look)
	_update_target(delta)

	# --- Camera
	if target and not dead:
		var to: Vector3 = target.global_position - global_position
		yaw = lerp_angle(yaw, atan2(-to.x, -to.z) + 0.25, clampf(6.0 * delta, 0.0, 1.0))
		pitch = lerp(pitch, -0.14, clampf(3.0 * delta, 0.0, 1.0))
	elif manual:
		yaw -= look.x * AIM_LOOK_SPEED * delta
		pitch = clamp(pitch - look.y * AIM_LOOK_SPEED * delta, -0.7, 0.45)
	else:
		yaw -= look.x * LOOK_SPEED * delta
		pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -0.9, 0.35)
		look_idle = 0.0 if look.length() > 0.2 else look_idle + delta
		# Classic Syphon Filter camera: glued behind your back, swinging round as you turn
		if look_idle > 0.6 and (input.length() > 0.2 or look_idle > 2.0):
			yaw = lerp_angle(yaw, rig.rotation.y + PI, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
			pitch = lerp(pitch, -0.16, clampf(2.0 * delta, 0.0, 1.0))
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	var kc := clampf(6.0 * delta, 0.0, 1.0)
	arm.spring_length = lerp(arm.spring_length, 9.0 if manual else (14.0 if target else 16.0), kc)
	arm.position.x = lerp(arm.position.x, 4.2 if manual else (4.0 if target else 0.0), kc)   # centered behind you, like the original
	camera_pivot.position.y = lerp(camera_pivot.position.y, 10.5 if manual else 9.5, kc)
	camera.fov = lerp(camera.fov, 50.0 if manual else 66.0, kc)
	shake = maxf(0.0, shake - delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * shake * 0.5
	camera.v_offset = randf_range(-1, 1) * shake * 0.5
	hurt = maxf(0.0, hurt - delta * 2.0)
	hit_marker = maxf(0.0, hit_marker - delta)

	# --- Movement
	var dir := Vector3.ZERO
	if input.length() > 0.2:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	var strafe := Input.get_axis("strafe_left", "strafe_right") if not dead else 0.0
	var face_fwd := facing()
	var face_right := Vector3.UP.cross(face_fwd).normalized() * -1.0
	var want_v := Vector3.ZERO
	var noise := 0.0
	if dead:
		move_mode = "WRECKED"
	elif roll_t > 0.0:
		move_mode = "Rolling"
		want_v = roll_dir * ROLL_SPEED
	else:
		var speed := 0.0
		if dir != Vector3.ZERO:
			if crouching:
				speed = CROUCH_SPEED
				move_mode = "Crouch-walking (silent)"
			elif manual:
				speed = AIM_WALK_SPEED
				noise = WALK_NOISE
				move_mode = "Aiming"
			elif Input.is_action_pressed("walk"):
				speed = WALK_SPEED
				noise = WALK_NOISE
				move_mode = "Walking (quiet)"
			elif target:
				speed = LOCK_RUN_SPEED
				noise = RUN_NOISE
				move_mode = "Running (locked)"
			else:
				speed = RUN_SPEED
				noise = RUN_NOISE
				move_mode = "Running (LOUD)"
		else:
			move_mode = "Crouching (silent)" if crouching else ("Aiming" if is_aiming() else "Standing")
		want_v = dir * speed
		if absf(strafe) > 0.2 and not crouching:
			want_v += face_right * strafe * STRAFE_SPEED
			noise = maxf(noise, WALK_NOISE)
			if dir == Vector3.ZERO:
				move_mode = "Sidestepping"
	var accel := ACCEL if roll_t <= 0.0 else 400.0
	if not is_on_floor():
		accel *= 0.3
	velocity.x = move_toward(velocity.x, want_v.x, accel * delta)
	velocity.z = move_toward(velocity.z, want_v.z, accel * delta)
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	var pre := velocity
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and air_time > 0.3:
		get_tree().call_group("enemies", "hear_noise", global_position, LAND_NOISE, self)
		Util.noise_ring(get_parent(), global_position, LAND_NOISE, Color(1, 0.5, 0.3, 0.4))
		add_shake(0.6)
		if city:
			city.push_props(global_position, 6.0, Vector3.UP * 8.0)
	air_time = 0.0 if on_floor else air_time + delta
	was_on_floor = on_floor

	if city and not dead:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("breakable") and roll_t > 0.0:
				city.smash(col, global_position, Vector2(pre.x, pre.z).length())
		city.push_props(global_position, 1.8, pre)

	# --- Facing: toward the lock, down the crosshair, or where you're running
	if not dead:
		var face_to := Vector3.ZERO
		if target:
			face_to = target.global_position - global_position
		elif manual:
			face_to = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		elif dir != Vector3.ZERO and roll_t <= 0.0:
			face_to = dir
		if face_to.length() > 0.1:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(face_to.x, face_to.z), clampf(TURN_SPEED * delta, 0.0, 1.0))

	_update_mech(delta)
	if rig.step_signal > 0.0 and noise > 0.0:
		get_tree().call_group("enemies", "hear_noise", global_position, noise, self)
		Util.noise_ring(get_parent(), global_position, noise, Color(1, 0.4, 0.3, 0.25) if noise >= RUN_NOISE else Color(1, 1, 1, 0.2))
		add_shake(0.2 if is_running() else 0.05)


func _input_actions(delta: float, input: Vector2, look: Vector2) -> void:
	locking = Input.is_action_pressed("lock")
	manual = Input.is_action_pressed("aim") and not locking
	fire_cd -= delta
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("jump") and is_on_floor() and roll_t <= 0.0 and not crouching:
		velocity.y = JUMP_SPEED * (0.5 if lost_leg else 1.0)
		get_tree().call_group("enemies", "hear_noise", global_position, 30.0, self)
	if Input.is_action_just_pressed("roll"):
		var strafe := Input.get_axis("strafe_left", "strafe_right")
		if input.length() > 0.2:
			_try_roll(Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y))
		elif absf(strafe) > 0.2:
			_try_roll(Vector3.UP.cross(facing()) * -strafe)   # crouch + sidestep = side roll
		else:
			crouching = not crouching
	# Pick a body part while locked: D-pad, or flick the right stick up/down
	if target:
		if Input.is_action_just_pressed("part_next"):
			cycle_part(1)
		if Input.is_action_just_pressed("part_prev"):
			cycle_part(-1)
		if absf(look.y) > 0.7 and _flick_ready:
			cycle_part(-1 if look.y > 0 else 1)
			_flick_ready = false
		elif absf(look.y) < 0.3:
			_flick_ready = true
	if Input.is_action_pressed("fire") and fire_cd <= 0.0:
		fire()


func _try_roll(d: Vector3) -> void:
	if start_roll(d):
		lock *= 0.3
		get_tree().call_group("enemies", "hear_noise", global_position, 35.0, self)


func cycle_part(step: int) -> void:
	var i := PARTS.find(part)
	part = PARTS[(i + step + PARTS.size()) % PARTS.size()]
	lock *= 0.5   # re-settle on the new spot


## R1 locks the best target in front; holding keeps it. The lock tightens over time.
func _update_target(delta: float) -> void:
	if target and (not is_instance_valid(target) or target.dead or not locking or dead or not _can_lock(target)):
		target = null
	if locking and target == null and not dead:
		target = _best_target()
		lock = 0.0
		part = "body"
	if target:
		var moving := Vector2(velocity.x, velocity.z).length() > 1.0
		lock = minf(1.0, lock + delta / LOCK_TIME[part] * (0.6 if moving else 1.0))
	else:
		lock = 0.0


func _can_lock(e: Node) -> bool:
	var d := global_position.distance_to(e.global_position)
	return d < LOCK_RANGE and (city == null or city.clear_line(center(), e.center()))


func _best_target() -> Node:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node = null
	var best_score := LOCK_CONE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not _can_lock(e):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var score := fwd.dot(to.normalized()) - to.length() / LOCK_RANGE * 0.2
		if score > best_score:
			best = e
			best_score = score
	return best


func fire() -> void:
	if not can_shoot():
		if ammo <= 0:
			start_reload()
		return
	fire_cd = FIRE_RATE
	var full: bool = target != null and lock >= 0.999
	var spread := 2.5
	var dmg := DAMAGE
	var shot_part := "body"
	if target:
		spread = lerp(5.0, 0.3, lock)
		shot_part = part
		if full:
			dmg = FULL_LOCK_DAMAGE
		if full and target.is_unaware():
			dmg = SILENT_KILL
	elif manual:
		spread = 0.15   # dead on the crosshair
		dmg = FULL_LOCK_DAMAGE
		shot_part = "precise"   # the enemy works out which part the bullet hit
	var victim := shoot_at(aim_point(), spread, dmg, shot_part)
	lock *= 0.8
	add_shake(0.08)
	if victim and victim.has_method("take_shot") and victim != self:
		hit_marker = 0.2
		var r: String = victim.last_hit_result
		if victim.dead:
			last_result = "silent" if dmg == SILENT_KILL else (r if r == "decap" else "kill")
		elif r != "":
			last_result = r
		elif full:
			last_result = "crit"


func on_hit_taken(_from: Node, _damage: int) -> void:
	hurt = 1.0
	add_shake(0.35)
