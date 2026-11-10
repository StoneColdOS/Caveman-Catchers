extends "res://scripts/fighter.gd"
## Your mech. Moves like Syphon Filter at 10 m tall:
##   The camera sits behind your back and you always face where it looks.
##   Left stick strafes and backpedals; right stick turns.
##   Light tilt = quiet walk, full tilt = jog (loud), crouch = silent creep.
##   Hold AIM to lock onto the enemy nearest your crosshair. The lock tightens
##   while you hold it (faster standing still); a full lock (red) hits for double
##   and barely misses. Firing loosens it a little, so tap in a rhythm.
##   A full-lock shot on an enemy who hasn't noticed you is a one-shot kill.
##   ROLL dodges: bullets pass through you while you tumble. Rolling into a low
##   building smashes through it.

const JOG_SPEED := 10.0
const WALK_SPEED := 4.5
const CROUCH_SPEED := 3.0
const AIM_SPEED := 4.0
const SNEAK_TILT := 0.7
const ACCEL := 45.0
const LOOK_SPEED := 2.4
const MAX_HP := 20
const LOCK_RANGE := 110.0
const LOCK_CONE := 0.55          # cos of the angle from your crosshair a target can be
const LOCK_TIME := 0.9           # seconds to a full lock standing still
const FIRE_RATE := 0.16
const DAMAGE := 2
const FULL_LOCK_DAMAGE := 4
const SILENT_KILL := 99

const WALK_NOISE := 18.0
const JOG_NOISE := 50.0

var move_mode := "Standing"
var yaw := 0.0
var pitch := -0.15
var camera_pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var aiming := false
var target: Node = null
var lock := 0.0                  # 0..1, how settled your aim is
var fire_cd := 0.0
var shake := 0.0
var hurt := 0.0                  # red screen flash
var hit_marker := 0.0
var last_result := ""


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
	arm.spring_length = 15.0
	arm.position = Vector3(3.5, 1.0, 0)
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
	return aiming and not dead and roll_t <= 0.0


func is_running() -> bool:
	return move_mode.begins_with("Jogging")


func aim_direction() -> Vector3:
	return (aim_point() - center()).normalized()


## Where your shots go: the locked target, or straight down the crosshair.
func aim_point() -> Vector3:
	if target and is_instance_valid(target) and not target.dead:
		return target.center()
	var from := camera.global_position
	var fwd := -camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from + fwd * 16.0, from + fwd * SHOT_RANGE, Util.LAYER_WORLD | Util.LAYER_ENEMY)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else from + fwd * SHOT_RANGE


func add_shake(amount: float) -> void:
	shake = minf(1.5, shake + amount)


func _physics_process(delta: float) -> void:
	if not dead:
		_input_actions(delta)
	_update_target(delta)

	# Camera: right stick turns you; a lock keeps the target framed
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if target and not dead:
		var to: Vector3 = target.global_position - global_position
		var want := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, want, clampf(6.0 * delta, 0.0, 1.0))
		pitch = lerp(pitch, -0.12, clampf(3.0 * delta, 0.0, 1.0))
	else:
		yaw -= look.x * LOOK_SPEED * delta
		pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -0.9, 0.35)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	var kc := clampf(6.0 * delta, 0.0, 1.0)
	var aim_view := is_aiming()
	arm.spring_length = lerp(arm.spring_length, 14.0 if aim_view else 16.0, kc)
	arm.position.x = lerp(arm.position.x, 5.5 if aim_view else 3.5, kc)
	camera.fov = lerp(camera.fov, 58.0 if aim_view else 66.0, kc)
	shake = maxf(0.0, shake - delta * 2.5)
	camera.h_offset = randf_range(-1, 1) * shake * 0.5
	camera.v_offset = randf_range(-1, 1) * shake * 0.5
	hurt = maxf(0.0, hurt - delta * 2.0)
	hit_marker = maxf(0.0, hit_marker - delta)

	# Movement relative to where you're facing (camera forward)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var tilt := input.length()
	var dir := Vector3.ZERO
	if tilt > 0.15 and not dead:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	var speed := 0.0
	var noise := 0.0
	if dead:
		move_mode = "WRECKED"
	elif roll_t > 0.0:
		move_mode = "Rolling"
	elif dir != Vector3.ZERO:
		if crouching:
			speed = CROUCH_SPEED
			move_mode = "Crouch-walking (silent)"
		elif is_aiming():
			speed = AIM_SPEED
			noise = WALK_NOISE
			move_mode = "Aiming"
		elif tilt < SNEAK_TILT or Input.is_action_pressed("walk"):
			speed = WALK_SPEED
			noise = WALK_NOISE
			move_mode = "Walking (quiet)"
		else:
			speed = JOG_SPEED
			noise = JOG_NOISE
			move_mode = "Jogging (LOUD)"
	else:
		move_mode = "Crouching (silent)" if crouching else ("Aiming" if is_aiming() else "Standing")

	var want_v := dir * speed
	if roll_t > 0.0:
		want_v = roll_dir * ROLL_SPEED
	var accel := ACCEL if roll_t <= 0.0 else 300.0
	velocity.x = move_toward(velocity.x, want_v.x, accel * delta)
	velocity.z = move_toward(velocity.z, want_v.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var pre := velocity
	move_and_slide()

	if city and not dead:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col and col.is_in_group("breakable") and roll_t > 0.0:
				city.smash(col, global_position, Vector2(pre.x, pre.z).length())
		city.push_props(global_position, 1.8, pre)

	# Always face down the camera (Syphon Filter style)
	if not dead:
		rig.rotation.y = lerp_angle(rig.rotation.y, yaw + PI, clampf(14.0 * delta, 0.0, 1.0))

	_update_mech(delta)
	if rig.step_signal > 0.0 and noise > 0.0:
		get_tree().call_group("enemies", "hear_noise", global_position, noise, self)
		Util.noise_ring(get_parent(), global_position, noise, Color(1, 0.4, 0.3, 0.25) if noise >= JOG_NOISE else Color(1, 1, 1, 0.2))
		add_shake(0.15 if is_running() else 0.05)


func _input_actions(delta: float) -> void:
	aiming = Input.is_action_pressed("aim")
	fire_cd -= delta
	if Input.is_action_just_pressed("crouch"):
		crouching = not crouching
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("roll"):
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var d := (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)) if input.length() > 0.2 else -facing()
		if start_roll(d):
			lock *= 0.3
			get_tree().call_group("enemies", "hear_noise", global_position, 35.0, self)
	if Input.is_action_pressed("fire") and fire_cd <= 0.0:
		fire()


## Pick a target when you start aiming; keep it while you hold. Lock tightens over time.
func _update_target(delta: float) -> void:
	if target and (not is_instance_valid(target) or target.dead or not is_aiming() or not _can_lock(target)):
		target = null
	if is_aiming() and target == null:
		target = _best_target()
		lock = 0.0
	if target:
		var moving := Vector2(velocity.x, velocity.z).length() > 1.0
		lock = minf(1.0, lock + delta / LOCK_TIME * (0.5 if moving else 1.0))
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
	var spread: float = lerp(5.0, 0.3, lock) if target else 2.5
	var dmg: int = FULL_LOCK_DAMAGE if full else DAMAGE
	var silent: bool = full and target.is_unaware()
	if silent:
		dmg = SILENT_KILL
	var victim := shoot_at(aim_point(), spread, dmg)
	lock *= 0.8
	add_shake(0.08)
	if victim and victim.has_method("take_shot") and victim != self:
		hit_marker = 0.2
		if victim.dead:
			last_result = "silent" if silent else "kill"
		elif full:
			last_result = "crit"


func on_hit_taken(_from: Node, _damage: int) -> void:
	hurt = 1.0
	add_shake(0.35)
