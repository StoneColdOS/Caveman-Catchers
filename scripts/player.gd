extends CharacterBody3D
## The hero: a grumpy old space chimp. Shadowed eyes, cigarette, smoke stuck in his
## helmet, a robot arm and a net. Placeholder shapes until the real model.

signal caught_one

const Util := preload("res://scripts/util.gd")
const DartScript := preload("res://scripts/dart.gd")

# MGS-style movement: how hard you push the stick decides how loud you are.
const CROUCH_SPEED := 1.6     # creeping: silent
const SNEAK_SPEED := 2.4      # light tilt: quiet footsteps
const RUN_SPEED := 5.0        # full tilt: loud footsteps
const SNEAK_TILT := 0.7       # stick tilt below this = sneaking
const ACCEL := 30.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const LOOK_SPEED := 2.6
const NET_RANGE := 2.4
const NET_COOLDOWN := 0.45

# How far each sound carries (meters).
const RUN_NOISE := 9.0
const SNEAK_NOISE := 2.5
const LAND_NOISE := 7.0
const TRANQ_NOISE := 8.0      # gunshot: loud
const MAX_DARTS := 5
const TRANQ_COOLDOWN := 0.5
const RUN_STEP := 0.32        # seconds between footsteps
const SNEAK_STEP := 0.55

var crouching := false
var move_mode := "Standing still"
var step_timer := 0.0
var was_on_floor := true
var air_time := 0.0
var darts := MAX_DARTS
var tranq_timer := 0.0
var aiming := false
var aim_on_target := false     # crosshair is over a caveman (turns it red)
var arm: SpringArm3D
var visual: Node3D
var net_pivot: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var net_timer := 0.0
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var legs: Array = []
var feet: Array = []
var right_arm: Array = []
var robot_arm: Array = []
var claw: MeshInstance3D
var walk_phase := 0.0
var cig_tip: MeshInstance3D
var smoke: Node3D
var yaw := 0.0
var pitch := -0.35


func _ready() -> void:
	add_to_group("player")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_CAVEMAN

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	shape.shape = cap
	shape.position.y = 0.8
	add_child(shape)

	_build_visual()
	_build_camera()


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var suit := Color(0.79, 0.73, 0.56)
	var boots := Color(0.56, 0.18, 0.18)
	var metal := Color(0.55, 0.6, 0.64)
	var fur := Color(0.36, 0.25, 0.18)
	var face := Color(0.72, 0.58, 0.48)

	# Everything above the hips lives on body_root, which bounces, leans and squashes.
	body_root = Node3D.new()
	visual.add_child(body_root)
	body_root.add_child(Util.mesh(Util.capsule(0.34, 0.86), suit, Vector3(0, 1.0, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.74, 0.1, 0.72)), Color(0.17, 0.14, 0.12), Vector3(0, 0.72, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.32, 0.24, 0.14)), Color(0.36, 0.42, 0.46), Vector3(0, 1.08, 0.32)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.08, 0.06, 0.02)), Color(0.31, 0.82, 0.55), Vector3(0, 1.08, 0.4), false))
	body_root.add_child(Util.mesh(Util.sphere(0.1), Color(0.91, 0.51, 0.23), Vector3(-0.36, 1.2, 0)))

	# Head on a springy pivot: fur, ears, muzzle, a band of shadow for eyes
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.42, 0)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.sphere(0.24), fur, Vector3(0, 0.18, 0)))
	head_pivot.add_child(Util.mesh(Util.sphere(0.08), face, Vector3(-0.24, 0.18, 0)))
	head_pivot.add_child(Util.mesh(Util.sphere(0.08), face, Vector3(0.24, 0.18, 0)))
	var muzzle := Util.mesh(Util.sphere(0.15), face, Vector3(0, 0.08, 0.15))
	muzzle.scale = Vector3(1.2, 0.85, 0.9)
	head_pivot.add_child(muzzle)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.38, 0.09, 0.08)), Color(0.04, 0.03, 0.03), Vector3(0, 0.24, 0.19), false))
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.4, 0.05, 0.1)), Color(0.24, 0.17, 0.12), Vector3(0, 0.3, 0.18)))
	var cig := Util.mesh(Util.box(Vector3(0.03, 0.03, 0.2)), Color(0.95, 0.93, 0.88), Vector3(0.08, 0.05, 0.34))
	cig.rotation.y = 0.35
	head_pivot.add_child(cig)
	cig_tip = MeshInstance3D.new()
	cig_tip.mesh = Util.sphere(0.022)
	cig_tip.material_override = Util.mat(Color(1.0, 0.45, 0.1), true)
	cig_tip.position = Vector3(0.115, 0.05, 0.43)
	head_pivot.add_child(cig_tip)
	smoke = Node3D.new()
	smoke.position = Vector3(0, 0.18, 0)
	head_pivot.add_child(smoke)
	for i in 7:
		var puff := MeshInstance3D.new()
		puff.mesh = Util.sphere(0.07)
		puff.material_override = Util.mat(Color(0.85, 0.88, 0.9, 0.35), true)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.add_child(puff)
	var helmet := Util.mesh(Util.sphere(0.4), Color(0.8, 0.9, 0.95, 0.22), Vector3(0, 0.18, 0))
	helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_pivot.add_child(helmet)
	var ant := Util.mesh(Util.box(Vector3(0.03, 0.32, 0.03)), metal, Vector3(0.16, 0.66, 0))
	ant.rotation.z = -0.35
	head_pivot.add_child(ant)
	var light := MeshInstance3D.new()
	light.mesh = Util.sphere(0.06)
	light.material_override = Util.mat(Color(1.0, 0.3, 0.2), true)
	light.position = Vector3(0.22, 0.83, 0)
	head_pivot.add_child(light)

	# Noodle limbs: chains of overlapping balls bent along a curve every frame.
	for side in [-1.0, 1.0]:
		legs.append(_make_noodle(11, 0.07, suit.darkened(0.08), Color()))
		var shoe := Util.mesh(Util.sphere(0.13), boots, Vector3(0.16 * side, 0.08, 0.05))
		shoe.scale = Vector3(1.05, 0.7, 1.7)
		visual.add_child(shoe)
		feet.append(shoe)
	right_arm = _make_noodle(9, 0.055, suit, Color())
	robot_arm = _make_noodle(10, 0.06, metal, Color(0.32, 0.36, 0.4))  # accordion-striped spring arm
	claw = Util.mesh(Util.sphere(0.09), Color(0.4, 0.45, 0.5), Vector3.ZERO)
	claw.scale = Vector3(1, 0.8, 1.2)
	body_root.add_child(claw)

	# Net in his gloved right hand
	net_pivot = Node3D.new()
	net_pivot.position = Vector3(0.45, 0.95, 0.05)
	body_root.add_child(net_pivot)
	net_pivot.add_child(Util.mesh(Util.sphere(0.09), Color(0.97, 0.96, 0.92), Vector3.ZERO))  # white cartoon glove
	var handle := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 1.2
	cyl.radial_segments = 6
	handle.mesh = cyl
	handle.material_override = Util.mat(Color(0.6, 0.65, 0.68))
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(0, 0, 0.6)
	net_pivot.add_child(handle)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.36
	torus.rings = 10
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = Util.mat(Color(0.91, 0.51, 0.23))
	ring.rotation.z = PI / 2.0
	ring.position = Vector3(0, 0, 1.45)
	net_pivot.add_child(ring)
	_rest_net()


func _make_noodle(count: int, radius: float, color: Color, stripe: Color) -> Array:
	var balls := []
	for i in count:
		var c := stripe if stripe != Color() and i % 2 == 1 else color
		var b := Util.mesh(Util.sphere(radius), c, Vector3.ZERO)
		visual.add_child(b)
		balls.append(b)
	return balls


## Lays the balls along a curve from a to b. If the ends are closer than the limb's
## length, it bows out sideways like a rubber hose instead of shrinking.
static func _noodle(balls: Array, a: Vector3, b: Vector3, length: float, bend: Vector3) -> void:
	var d := a.distance_to(b)
	var bow := sqrt(maxf(0.0, length * length - d * d)) * 0.55
	var mid := (a + b) * 0.5 + bend.normalized() * bow
	var n := balls.size()
	for i in n:
		var u := float(i) / float(n - 1)
		balls[i].position = a.lerp(mid, u).lerp(mid.lerp(b, u), u)


## Rubber hose animation: bounce to the beat, tiptoe sneaking, windmill running,
## flailing in the air, springy head. Bigger when the rubber hose style is on.
func _animate(delta: float, on_floor: bool) -> void:
	var amp := Util.amp()
	var t := Time.get_ticks_msec() * 0.001
	var beat := Util.beat()
	var hs := Vector2(velocity.x, velocity.z).length()
	var running := move_mode.begins_with("Running")
	var sneaky := crouching or move_mode.begins_with("Sneaking")
	var moving := hs > 0.2 and on_floor
	if moving:
		walk_phase += hs * delta * (2.4 if running else 4.2)

	# Body: bounce, lean, sway, squash and stretch
	var body_y := 0.0
	var lean := 0.0
	var sway := 0.0
	var stretch := 0.0
	if not on_floor:
		lean = -0.2 * amp
		stretch = 0.12 * amp
	elif moving:
		var b := absf(sin(walk_phase))
		body_y = b * (0.2 if running else 0.13) * amp
		stretch = (b - 0.5) * 0.22 * amp
		lean = (0.4 if running else (0.3 if sneaky else 0.12)) * amp
		sway = sin(walk_phase) * (0.1 if running else 0.18) * amp
	else:
		var b := absf(sin(beat * 0.5))
		body_y = b * 0.08 * amp
		stretch = (b - 0.5) * 0.14 * amp
		sway = sin(beat * 0.25) * 0.12 * amp
	if crouching:
		body_y -= 0.32
	var k := clampf(16.0 * delta, 0.0, 1.0)
	body_root.position.y = lerp(body_root.position.y, body_y, k)
	body_root.rotation.x = lerp_angle(body_root.rotation.x, lean, k)
	body_root.rotation.z = lerp_angle(body_root.rotation.z, sway, k)
	body_root.scale = body_root.scale.lerp(Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5), k)

	# Springy head: lags behind the body, overshoots, wobbles back
	var head_target := Vector3(-lean * 0.9, 0.0, -sway * 1.6)
	head_vel += (head_target - head_rot) * 140.0 * delta
	head_vel -= head_vel * 7.0 * delta
	head_rot += head_vel * delta
	head_pivot.rotation = head_rot

	# Feet
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.16 * side, 0.08, 0.05)
		var pitch_foot := 0.0
		if not on_floor:
			foot += Vector3(0.06 * side, 0.32, -0.12 + 0.12 * sin(t * 22.0 + i * PI)) * amp
		elif moving:
			var stride := (0.48 if running else (0.24 if sneaky else 0.3)) * amp
			var lift := (0.32 if running else (0.4 if sneaky else 0.18)) * amp
			foot.z += sin(ph) * stride
			foot.y += maxf(0.0, cos(ph)) * lift
			pitch_foot = -cos(ph) * 0.6 * amp
			if sneaky:
				pitch_foot += 0.5 * amp  # up on tiptoes
		elif i == 1:
			foot.y += maxf(0.0, sin(beat)) * 0.07 * amp  # toe-tap on the beat
			pitch_foot = -maxf(0.0, sin(beat)) * 0.5 * amp
		feet[i].position = feet[i].position.lerp(foot, clampf(25.0 * delta, 0.0, 1.0))
		feet[i].rotation.x = pitch_foot
		var hip := body_root.transform * Vector3(0.15 * side, 0.66, 0)
		_noodle(legs[i], hip, feet[i].position + Vector3(0, 0.07, -0.04), 0.68, Vector3(0.35 * side, 0.0, 1.0))

	# Arms (hand targets are in body space)
	var net_hand := Vector3(0.45, 0.95, 0.05)
	var claw_hand := Vector3(-0.48, 0.8, 0.0)
	if aiming:
		net_hand = Vector3(0.4, 1.05, 0.2)
		claw_hand = Vector3(-0.15, 1.15, 0.45)
	elif not on_floor:
		var f := sin(t * 18.0) * 0.15 * amp
		net_hand = Vector3(0.6, 1.5 + f, 0.0)
		claw_hand = Vector3(-0.62, 1.5 - f, 0.05)
	elif moving and running:
		var a := walk_phase * 2.0
		claw_hand = Vector3(-0.5, 1.2, 0.0) + Vector3(0, sin(a), cos(a)) * 0.45 * amp  # windmill
		net_hand = Vector3(0.45, 1.0, 0.05 - sin(walk_phase) * 0.35 * amp)
	elif moving and sneaky:
		var w := sin(walk_phase) * 0.05 * amp
		net_hand = Vector3(0.36, 1.25 + w, 0.32)   # hands up like claws, tiptoeing
		claw_hand = Vector3(-0.32, 1.25 - w, 0.34)
	elif moving:
		net_hand.z -= sin(walk_phase) * 0.28 * amp
		claw_hand.z += sin(walk_phase) * 0.32 * amp
	else:
		net_hand.z += sin(beat * 0.5) * 0.06 * amp
		claw_hand.z -= sin(beat * 0.5) * 0.08 * amp
		claw_hand.y += absf(sin(beat * 0.5)) * 0.06 * amp
	net_pivot.position = net_pivot.position.lerp(net_hand, clampf(14.0 * delta, 0.0, 1.0))
	claw.position = claw.position.lerp(claw_hand, clampf(14.0 * delta, 0.0, 1.0))
	var bt := body_root.transform
	_noodle(right_arm, bt * Vector3(0.36, 1.2, 0), bt * net_pivot.position, 0.62, Vector3(1.0, -0.5, -0.3))
	_noodle(robot_arm, bt * Vector3(-0.36, 1.2, 0), bt * claw.position, 0.66, Vector3(-1.0, -0.5, -0.3))

	# Landing squash recovers on the whole figure
	visual.scale = visual.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.4
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 6.0
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	arm.add_child(camera)
	camera.make_current()


func _physics_process(delta: float) -> void:
	# Aiming: hold L2 for an over-the-shoulder view with a crosshair.
	var want_aim := Input.is_action_pressed("aim")
	if want_aim and not aiming:
		pitch = -0.08  # level out so the crosshair starts on the horizon
	aiming = want_aim

	# Camera (slower and finer while aiming)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var look_speed := LOOK_SPEED * (0.45 if aiming else 1.0)
	yaw -= look.x * look_speed * delta
	pitch = clamp(pitch - look.y * look_speed * delta, -0.7 if aiming else -1.2, 0.6 if aiming else 0.3)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)
	var t := clampf(12.0 * delta, 0.0, 1.0)
	arm.spring_length = lerp(arm.spring_length, 3.2 if aiming else 6.0, t)
	arm.position.x = lerp(arm.position.x, 1.1 if aiming else 0.0, t)
	camera.fov = lerp(camera.fov, 48.0 if aiming else 70.0, t)

	# Movement relative to the camera.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var tilt := input.length()
	var dir := Vector3.ZERO
	if tilt > 0.15:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	crouching = Input.is_action_pressed("crouch")

	var speed := 0.0
	var noise := 0.0
	var step := 0.0
	if dir != Vector3.ZERO:
		if crouching:
			speed = CROUCH_SPEED
			move_mode = "Creeping (silent)"
		elif tilt < SNEAK_TILT or aiming or Input.is_action_pressed("walk"):
			speed = SNEAK_SPEED
			noise = SNEAK_NOISE
			step = SNEAK_STEP
			move_mode = "Sneaking (quiet)"
		else:
			speed = RUN_SPEED
			noise = RUN_NOISE
			step = RUN_STEP
			move_mode = "Running (LOUD)"
	else:
		move_mode = "Crouching (silent)" if crouching else "Standing still"

	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if is_on_floor() and not crouching and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		head_vel.x -= 6.0 * Util.amp()
	elif is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Landing from a real jump makes a thud.
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and air_time > 0.25:
		make_noise(LAND_NOISE)
		var sq := Util.amp()
		visual.scale = Vector3(1.0 + 0.45 * sq, 1.0 - 0.45 * sq, 1.0 + 0.45 * sq)
		head_vel.x += 7.0 * sq
	air_time = 0.0 if on_floor else air_time + delta
	was_on_floor = on_floor

	# Footsteps
	if on_floor and noise > 0.0:
		step_timer -= delta
		if step_timer <= 0.0:
			make_noise(noise)
			step_timer = step
	else:
		step_timer = 0.15

	if aiming:
		var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(fwd.x, fwd.z), 15.0 * delta)
	elif dir != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	_animate(delta, on_floor)

	_animate_smoke()

	# Net
	net_timer -= delta
	if net_timer <= 0.0 and Input.is_action_just_pressed("net"):
		swing_net()

	# Tranq gun
	aim_on_target = aiming and _crosshair_on_caveman()
	tranq_timer -= delta
	if tranq_timer <= 0.0 and Input.is_action_just_pressed("tranq"):
		fire_tranq()


func swing_net() -> void:
	net_timer = NET_COOLDOWN
	net_pivot.rotation = Vector3(0, 1.3, 0)
	var tw := create_tween()
	tw.tween_property(net_pivot, "rotation:y", -1.3, 0.18)
	tw.tween_callback(_rest_net)

	var fwd := visual.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for g in get_tree().get_nodes_in_group("gatherers"):
		if not g.can_be_netted():
			continue
		var to: Vector3 = g.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < NET_RANGE and (dist < 0.9 or fwd.dot(to / dist) > 0.35):
			g.catch()
			caught_one.emit()


## Fires a dart. Aiming (L2): straight at the crosshair. Not aiming: straight ahead.
## No auto-aim. Returns true if a dart was fired.
func fire_tranq() -> bool:
	if darts <= 0:
		return false
	darts -= 1
	tranq_timer = TRANQ_COOLDOWN
	var muzzle := global_position + Vector3.UP * 1.1
	var dir := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	if aiming:
		# Fly exactly down the crosshair line, starting level with the hero.
		var fwd := -camera.global_basis.z
		var from := camera.global_position
		dir = fwd
		muzzle = from + fwd * max(0.0, (muzzle - from).dot(fwd))
	if not aiming:
		visual.rotation.y = atan2(dir.x, dir.z)
	var dart := Node3D.new()
	dart.set_script(DartScript)
	dart.direction = dir
	get_parent().add_child(dart)
	dart.global_position = muzzle + dir * 0.3
	make_noise(TRANQ_NOISE, Color(1, 0.85, 0.2, 0.85))
	return true


func _crosshair_on_caveman() -> bool:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 60.0,
		Util.LAYER_WORLD | Util.LAYER_CAVEMAN)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider.is_in_group("gatherers")


## Sends a sound out. Any caveman inside the radius hears it.
func make_noise(radius: float, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = Color(1, 0.4, 0.3, 0.8) if radius >= RUN_NOISE else Color(1, 1, 1, 0.7)
	Util.noise_ring(get_parent(), global_position, radius, color)
	get_tree().call_group("gatherers", "hear_noise", global_position, radius, self)


## Puffs swirl slowly around inside the helmet; the cigarette tip pulses.
func _animate_smoke() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var i := 0
	for puff in smoke.get_children():
		var a := t * (0.6 + i * 0.07) + i * 0.9
		var r := 0.2 + 0.06 * sin(t * 0.7 + i)
		puff.position = Vector3(cos(a) * r, 0.1 + 0.12 * sin(t * 0.5 + i * 1.3), sin(a) * r * 0.8)
		puff.scale = Vector3.ONE * (0.8 + 0.4 * sin(t + i))
		i += 1
	var glow := 0.75 + 0.25 * sin(t * 3.0)
	(cig_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35 * glow + 0.1, 0.05)


## Net held upright beside him when not swinging.
func _rest_net() -> void:
	net_pivot.rotation = Vector3(-1.2, 0.2, 0)
