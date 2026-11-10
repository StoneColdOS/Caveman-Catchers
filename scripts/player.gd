extends "res://scripts/fighter.gd"
## Your mech: ~10 m, lanky, reverse-jointed legs, a long two-handed sword.
##   Walk (light stick tilt): quiet. Run (full tilt): loud stomps, smashes through low buildings.
##   Dash: thruster burst. Cancels a windup (feint).
##   Slash in your stance (HIGH / MID / LOW). Hold guard to block MID and LOW.
##   Lock-on keeps the camera and your blade on one enemy; you strafe around him.

const WALK_SPEED := 5.5
const RUN_SPEED := 12.0
const GUARD_SPEED := 3.0
const SWING_SPEED := 1.5
const SNEAK_TILT := 0.7
const ACCEL := 40.0             # heavy-looking, but responsive
const TURN := 9.0
const DASH_SPEED := 30.0
const DASH_TIME := 0.28
const DASH_COOLDOWN := 0.7
const LUNGE := 9.0              # step into your strike
const LOCK_RANGE := 70.0
const LOOK_SPEED := 2.4
const MAX_HP := 5

const WALK_NOISE := 22.0
const RUN_NOISE := 60.0
const DASH_NOISE := 45.0

var move_mode := "Standing"
var yaw := 0.0
var pitch := -0.18
var camera_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var lock_target: Node = null
var lock_enabled := true         # auto-locks onto enemies that are fighting you
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector3.ZERO
var shake := 0.0
var kills := 0
var last_result := ""


func _ready() -> void:
	add_to_group("player")
	add_to_group("shakers")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_ENEMY
	_setup_fighter(false, MAX_HP)
	_build_camera()


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 9.0
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 17.0
	arm.position = Vector3(2.8, 1.5, 0)
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.5
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 66.0
	camera.far = 400.0
	arm.add_child(camera)
	camera.make_current()
	# Faint cool fill light riding with the camera, so the mech reads in the dark
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 1.4
	fill.omni_range = 30.0
	fill.omni_attenuation = 1.0
	fill.light_specular = 0.0
	camera.add_child(fill)


func opponents() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func is_running() -> bool:
	return move_mode.begins_with("Running") or dash_t > 0.0


func add_shake(amount: float) -> void:
	shake = minf(1.5, shake + amount)


func _physics_process(delta: float) -> void:
	_update_lock()
	# Camera: free look, or swing around behind you to frame the locked enemy
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if lock_target:
		var to: Vector3 = lock_target.global_position - global_position
		var want := atan2(-to.x, -to.z) + 0.35   # off-axis so your own mech doesn't block the view
		yaw = lerp_angle(yaw, want, clampf(5.0 * delta, 0.0, 1.0))
		pitch = lerp(pitch, -0.2, clampf(3.0 * delta, 0.0, 1.0))
	else:
		yaw -= look.x * LOOK_SPEED * delta
		pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -1.0, 0.25)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	# Locked on: pull the camera up and out over your shoulder so both mechs are in frame
	var kc := clampf(4.0 * delta, 0.0, 1.0)
	arm.position.x = lerp(arm.position.x, 5.5 if lock_target else 2.8, kc)
	arm.spring_length = lerp(arm.spring_length, 15.0 if lock_target else 17.0, kc)
	camera_pivot.position.y = lerp(camera_pivot.position.y, 10.5 if lock_target else 9.0, kc)
	shake = maxf(0.0, shake - delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * shake * 0.6
	camera.v_offset = randf_range(-1, 1) * shake * 0.6

	if not dead:
		_combat_input()

	# Movement relative to the camera
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var tilt := input.length()
	var dir := Vector3.ZERO
	if tilt > 0.15 and not dead:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	var speed := 0.0
	var noise := 0.0
	if dead:
		move_mode = "WRECKED"
	elif stagger > 0.0:
		move_mode = "Staggered"
	elif dir != Vector3.ZERO:
		if swing != SWING_NONE:
			speed = SWING_SPEED
			move_mode = "Swinging"
		elif guarding:
			speed = GUARD_SPEED
			move_mode = "Guarding"
		elif tilt < SNEAK_TILT or Input.is_action_pressed("walk"):
			speed = WALK_SPEED
			noise = WALK_NOISE
			move_mode = "Walking (quiet)"
		else:
			speed = RUN_SPEED
			noise = RUN_NOISE
			move_mode = "Running (LOUD)"
	else:
		move_mode = "Guarding" if guarding else "Standing"
	if crippled:
		speed *= 0.5

	var target := dir * speed
	if swing == SWING_STRIKE and swing_t > STRIKE_T * 0.4:
		target = facing() * LUNGE
	if dash_t > 0.0:
		dash_t -= delta
		target = dash_dir * DASH_SPEED * (0.5 if crippled else 1.0)
	var accel := ACCEL if stagger <= 0.0 else ACCEL * 0.25
	if dash_t > 0.0:
		accel = 400.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var pre := velocity
	move_and_slide()

	# Charging into low buildings smashes through them; props go flying either way
	var hs := Vector2(pre.x, pre.z).length()
	if city and not dead:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("breakable") and is_running():
				city.smash(col, global_position, hs)
		city.push_props(global_position, 1.8, pre)

	# Face where you're going, or face your locked enemy
	var face_dir := Vector3.ZERO
	if lock_target and not dead:
		face_dir = lock_target.global_position - global_position
	elif dir != Vector3.ZERO and swing == SWING_NONE:
		face_dir = dir
	if face_dir.length() > 0.1 and not dead:
		var turn := TURN if swing != SWING_WINDUP else TURN * 0.6
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(face_dir.x, face_dir.z), clampf(turn * delta, 0.0, 1.0))

	_update_fighter(delta)
	if rig.step_signal > 0.0 and noise > 0.0:
		_make_noise(noise)
		Util.noise_ring(get_parent(), global_position, noise, Color(1, 0.4, 0.3, 0.6) if noise >= RUN_NOISE else Color(1, 1, 1, 0.45))
		add_shake(0.25 if is_running() else 0.08)


func _combat_input() -> void:
	if Input.is_action_just_pressed("stance_high"):
		set_stance(Stance.HIGH)
	if Input.is_action_just_pressed("stance_mid"):
		set_stance(Stance.MID)
	if Input.is_action_just_pressed("stance_low"):
		set_stance(Stance.LOW)
	if Input.is_action_just_pressed("stance_cycle"):
		set_stance((stance + 2) % 3)   # MID -> HIGH -> LOW -> MID
	if Input.is_action_just_pressed("lock"):
		lock_enabled = not lock_enabled
		if not lock_enabled:
			lock_target = null
	guarding = Input.is_action_pressed("guard") and swing == SWING_NONE and stagger <= 0.0
	if Input.is_action_just_pressed("slash"):
		start_swing()
	dash_cd -= get_physics_process_delta_time()
	if Input.is_action_just_pressed("dash"):
		dash()


func dash() -> void:
	if dead or dash_cd > 0.0 or stagger > 0.0 or swing == SWING_STRIKE or swing == SWING_RECOVER:
		return
	cancel_windup()   # feint
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.2:
		dash_dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	else:
		dash_dir = -facing()   # back-step
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN
	_make_noise(DASH_NOISE)
	add_shake(0.3)


## Lock onto the nearest enemy that's fighting you (or the nearest one in view when locking manually).
func _update_lock() -> void:
	if lock_target and (not is_instance_valid(lock_target) or lock_target.dead or global_position.distance_to(lock_target.global_position) > LOCK_RANGE):
		lock_target = null
	if not lock_enabled or lock_target or dead:
		return
	var best: Node = null
	var best_d := LOCK_RANGE
	for e in opponents():
		if e.dead or not e.is_dueling():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best = e
			best_d = d
	lock_target = best


## What your last strike did (for the HUD): hit, block, break, clash, kill, backstab.
func note_result(r: String) -> void:
	last_result = r


func on_hit_taken(_attacker: Node) -> void:
	add_shake(1.0)
