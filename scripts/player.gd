extends CharacterBody3D
## The hero: an old night watchman. Work jacket, knit cap, stubble, eyes in shadow,
## flashlight in his right hand, canvas bag on his hip. Grabs with his left hand.

signal caught_one

const Util := preload("res://scripts/util.gd")

# MGS-style movement: how hard you push the stick decides how loud you are.
const CROUCH_SPEED := 1.6     # creeping: silent
const SNEAK_SPEED := 2.4      # light tilt: quiet footsteps
const RUN_SPEED := 5.0        # full tilt: loud footsteps
const SNEAK_TILT := 0.7       # stick tilt below this = sneaking
const ACCEL := 14.0           # heavier, more grounded starts and stops
const DARK_SIGHT := 0.5       # robots see half as far when you're in the dark
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const LOOK_SPEED := 2.6
const LEG_UPPER := 0.41
const LEG_LOWER := 0.4
const ARM_UPPER := 0.3
const ARM_LOWER := 0.28
const GRAB_RANGE := 1.7      # he has to get right up to them
const GRAB_COOLDOWN := 0.5
const GRAB_TIME := 0.45      # lunge forward, then stuff it over his shoulder
const LUNGE_SPEED := 4.5     # little burst forward on every grab, so chases are winnable
const TAPS_UNAWARE := 4      # headlock: taps to wind down a robot you snuck up on
const TAPS_ALERT := 9        # ...or one that was already on to you
const BREAK_TIME := 1.0      # stop tapping this long and he wriggles free
const HOLD_DECAY := 0.12     # wind-down progress slowly creeps back

# How far each sound carries (meters).
const RUN_NOISE := 9.0
const SNEAK_NOISE := 2.5
const LAND_NOISE := 7.0
const RUN_STEP := 0.32        # seconds between footsteps
const SNEAK_STEP := 0.55

var crouching := false
var move_mode := "Standing still"
var step_timer := 0.0
var was_on_floor := true
var air_time := 0.0
var arm: SpringArm3D
var visual: Node3D
var net_pivot: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var net_timer := 0.0
var grab_timer := 0.0
var satchel: Node3D
var satchel_fill := 0
var holding: Node = null
var hold_needed := 0
var hold_progress := 0.0
var since_tap := 0.0
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var walk_phase := 0.0
var legs: Array = []
var feet: Array = []
var arms: Array = []
var light_hand: Node3D
var yaw := 0.0
var pitch := -0.25
var flashlight: SpotLight3D
var flashlight_on := true


func _ready() -> void:
	add_to_group("player")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_CAVEMAN

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	shape.shape = cap
	shape.position.y = 0.95
	add_child(shape)

	_build_visual()
	_build_camera()
	# No ink outline on the hero (the user prefers him clean); robots and world keep theirs.
	for o in visual.find_children("", "MeshInstance3D", true, false):
		if o.is_in_group("outlines"):
			o.queue_free()


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var jacket := Color(0.3, 0.28, 0.2)      # worn canvas work jacket
	var pants := Color(0.18, 0.19, 0.21)
	var boots := Color(0.2, 0.14, 0.1)
	var skin := Color(0.66, 0.52, 0.43)
	var stubble := Color(0.5, 0.45, 0.42)
	var cap := Color(0.12, 0.14, 0.18)       # navy knit watch cap

	# Everything above the hips lives on body_root, which leans and bobs.
	body_root = Node3D.new()
	visual.add_child(body_root)
	var torso := Util.mesh(Util.capsule(0.24, 0.78), jacket, Vector3(0, 1.2, 0))
	torso.scale = Vector3(1.18, 1.0, 0.85)
	body_root.add_child(torso)
	body_root.add_child(Util.mesh(Util.box(Vector3(0.56, 0.16, 0.4)), jacket.darkened(0.08), Vector3(0, 0.88, 0)))  # jacket hem
	body_root.add_child(Util.mesh(Util.box(Vector3(0.4, 0.1, 0.32)), jacket.darkened(0.25), Vector3(0, 1.56, 0)))   # collar
	body_root.add_child(Util.mesh(Util.box(Vector3(0.02, 0.6, 0.02)), Color(0.12, 0.11, 0.09), Vector3(0, 1.2, 0.205), false))  # zipper
	for side in [-1.0, 1.0]:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.14, 0.05, 0.03)), jacket.darkened(0.2), Vector3(0.12 * side, 1.02, 0.2)))  # pocket flaps
		body_root.add_child(Util.mesh(Util.box(Vector3(0.12, 0.05, 0.03)), jacket.darkened(0.2), Vector3(0.12 * side, 1.34, 0.2)))
	# Watchman's patch
	body_root.add_child(Util.mesh(Util.box(Vector3(0.09, 0.05, 0.02)), Color(0.55, 0.5, 0.35), Vector3(0.13, 1.4, 0.215), false))

	# Canvas bag on his left hip, strap across his chest. Caught monkeys go in here.
	satchel = Node3D.new()
	satchel.position = Vector3(0.3, 0.92, -0.04)
	body_root.add_child(satchel)
	satchel.add_child(Util.mesh(Util.box(Vector3(0.12, 0.28, 0.32)), Color(0.42, 0.36, 0.26), Vector3.ZERO))
	satchel.add_child(Util.mesh(Util.box(Vector3(0.14, 0.1, 0.34)), Color(0.36, 0.3, 0.21), Vector3(0, 0.1, 0)))
	var strap := Util.mesh(Util.box(Vector3(0.04, 0.85, 0.02)), Color(0.3, 0.25, 0.17), Vector3(0.0, 1.22, 0.215))
	strap.rotation.z = 0.62
	body_root.add_child(strap)

	# Head: tired old face, stubble, eyes lost in shadow under the cap
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.62, 0)
	body_root.add_child(head_pivot)
	var neck := CylinderMesh.new()
	neck.top_radius = 0.06
	neck.bottom_radius = 0.07
	neck.height = 0.1
	neck.radial_segments = 8
	head_pivot.add_child(Util.mesh(neck, skin.darkened(0.1), Vector3(0, 0.0, 0)))
	var skull := Util.mesh(Util.sphere(0.13), skin, Vector3(0, 0.15, 0))
	skull.scale = Vector3(0.95, 1.15, 1.0)
	head_pivot.add_child(skull)
	var jaw := Util.mesh(Util.sphere(0.1), stubble, Vector3(0, 0.07, 0.035))
	jaw.scale = Vector3(1.05, 0.75, 1.0)
	head_pivot.add_child(jaw)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.04, 0.06, 0.05)), skin.darkened(0.08), Vector3(0, 0.13, 0.13)))  # nose
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.21, 0.055, 0.04)), Color(0.03, 0.03, 0.03), Vector3(0, 0.19, 0.11), false))  # shadowed eyes
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.07, 0.012, 0.02)), Color(0.2, 0.14, 0.12), Vector3(0, 0.055, 0.13), false))  # mouth
	for side in [-1.0, 1.0]:
		head_pivot.add_child(Util.mesh(Util.sphere(0.035), skin.darkened(0.05), Vector3(0.125 * side, 0.15, 0)))  # ears
	var beanie := Util.mesh(Util.sphere(0.145), cap, Vector3(0, 0.235, -0.005))
	beanie.scale = Vector3(1.0, 0.78, 1.02)
	head_pivot.add_child(beanie)
	var fold := CylinderMesh.new()
	fold.top_radius = 0.142
	fold.bottom_radius = 0.148
	fold.height = 0.06
	fold.radial_segments = 10
	head_pivot.add_child(Util.mesh(fold, cap.lightened(0.08), Vector3(0, 0.215, 0)))

	# Two-part limbs (upper + lower), bent at the knee and elbow every frame
	for side in [-1.0, 1.0]:
		legs.append([Util.mesh(Util.capsule(0.085, LEG_UPPER + 0.1), pants, Vector3.ZERO),
			Util.mesh(Util.capsule(0.07, LEG_LOWER + 0.08), pants.darkened(0.05), Vector3.ZERO)])
		for seg in legs[-1]:
			visual.add_child(seg)
		var boot := Util.mesh(Util.box(Vector3(0.13, 0.11, 0.28)), boots, Vector3(0.13 * side, 0.055, 0.04))
		visual.add_child(boot)
		feet.append(boot)
	for i in 2:
		arms.append([Util.mesh(Util.capsule(0.065, ARM_UPPER + 0.08), jacket, Vector3.ZERO),
			Util.mesh(Util.capsule(0.055, ARM_LOWER + 0.06), jacket.darkened(0.05), Vector3.ZERO)])
		for seg in arms[-1]:
			body_root.add_child(seg)

	# Right hand holds the flashlight; the beam moves with his arm
	light_hand = Node3D.new()
	light_hand.position = Vector3(-0.24, 1.15, 0.36)
	body_root.add_child(light_hand)
	light_hand.add_child(Util.mesh(Util.sphere(0.05), skin, Vector3.ZERO))
	var torch := CylinderMesh.new()
	torch.top_radius = 0.035
	torch.bottom_radius = 0.03
	torch.height = 0.22
	torch.radial_segments = 8
	var body_mesh := Util.mesh(torch, Color(0.1, 0.1, 0.11), Vector3(0, 0.0, 0.06))
	body_mesh.rotation.x = PI / 2.0
	light_hand.add_child(body_mesh)
	var lens := MeshInstance3D.new()
	lens.mesh = Util.box(Vector3(0.06, 0.06, 0.02))
	lens.material_override = Util.mat(Color(1.0, 0.97, 0.85), true)
	lens.position = Vector3(0, 0, 0.175)
	light_hand.add_child(lens)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0, 0, 0.19)
	flashlight.rotation = Vector3(0, PI, 0)
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 24.0
	flashlight.spot_attenuation = 0.9
	flashlight.light_energy = 8.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	light_hand.add_child(flashlight)

	# Left hand grabs
	net_pivot = Node3D.new()
	net_pivot.position = Vector3(0.32, 0.9, 0.05)
	body_root.add_child(net_pivot)
	net_pivot.add_child(Util.mesh(Util.sphere(0.055), skin, Vector3.ZERO))


## Two-bone limb: places the upper and lower segments from a (hip/shoulder) to b
## (ankle/wrist), bending the joint toward `pole`.
static func _limb(segs: Array, a: Vector3, b: Vector3, l1: float, l2: float, pole: Vector3) -> void:
	var to := b - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - along * along))
	var side := (pole - dir * pole.dot(dir)).normalized()
	var joint := a + dir * along + side * h
	var end := a + dir * d
	_place(segs[0], a, joint)
	_place(segs[1], joint, end)


static func _place(seg: Node3D, p: Vector3, q: Vector3) -> void:
	var up := (q - p).normalized()
	if up.length() < 0.5:
		return
	seg.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), (p + q) * 0.5)


## Grounded, heavy animation: small bob, hunch when sneaking, flashlight held out front.
func _animate(delta: float, on_floor: bool) -> void:
	var amp := Util.amp()
	var t := Time.get_ticks_msec() * 0.001
	var hs := Vector2(velocity.x, velocity.z).length()
	var running := move_mode.begins_with("Running")
	var sneaky := crouching or move_mode.begins_with("Sneaking")
	var moving := hs > 0.2 and on_floor
	if moving:
		walk_phase += hs * delta * (2.6 if running else 3.4)

	# Body: small bob, lean forward when running, hunch when sneaking
	var body_y := 0.0
	var lean := 0.04
	var sway := 0.0
	if not on_floor:
		lean = -0.08
	elif moving:
		body_y = absf(sin(walk_phase)) * (0.05 if running else 0.03) - 0.02
		lean = 0.22 if running else (0.28 if sneaky else 0.07)
		sway = sin(walk_phase) * 0.03
	else:
		body_y = sin(t * 1.6) * 0.008  # breathing
	if crouching:
		body_y -= 0.38
	var k := clampf(10.0 * delta, 0.0, 1.0)
	body_root.position.y = lerp(body_root.position.y, body_y, k)
	body_root.rotation.x = lerp_angle(body_root.rotation.x, lean, k)
	body_root.rotation.z = lerp_angle(body_root.rotation.z, sway, k)

	# Head settles with a slight lag
	var head_target := Vector3(-lean * 0.6, 0.0, -sway)
	head_vel += (head_target - head_rot) * 90.0 * delta
	head_vel -= head_vel * 12.0 * delta
	head_rot += head_vel * delta
	head_pivot.rotation = head_rot

	# Legs
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.13 * side, 0.055, 0.04)
		var pitch_foot := 0.0
		if not on_floor:
			foot += Vector3(0.0, 0.25, -0.1 if i == 0 else 0.12)
		elif moving:
			var stride := 0.45 if running else (0.22 if sneaky else 0.3)
			var lift := 0.22 if running else (0.16 if sneaky else 0.12)
			foot.z += sin(ph) * stride
			foot.y += maxf(0.0, cos(ph)) * lift
			pitch_foot = -cos(ph) * 0.35
		feet[i].position = feet[i].position.lerp(foot, clampf(25.0 * delta, 0.0, 1.0))
		feet[i].rotation.x = pitch_foot
		var hip := body_root.transform * Vector3(0.12 * side, 0.9, 0)
		_limb(legs[i], hip, feet[i].position + Vector3(0, 0.07, -0.05), LEG_UPPER, LEG_LOWER, Vector3(0.1 * side, 0, 1))

	# Flashlight hand: held out front, bobbing a bit when walking, pumping when running
	var light_target := Vector3(-0.22, 1.16, 0.38)
	if moving:
		light_target.y += sin(walk_phase * 2.0) * (0.04 if running else 0.015)
		light_target.z += sin(walk_phase) * (0.08 if running else 0.0)
	if not on_floor:
		light_target = Vector3(-0.3, 1.35, 0.3)
	light_hand.position = light_hand.position.lerp(light_target, clampf(14.0 * delta, 0.0, 1.0))
	light_hand.rotation.x = lerp_angle(light_hand.rotation.x, 0.18 - lean, clampf(10.0 * delta, 0.0, 1.0))  # aim a little down

	# Grab hand (left): swings opposite his left foot, reaches out on a grab
	var grab_hand := Vector3(0.32, 0.88, 0.05)
	if moving:
		grab_hand.z -= sin(walk_phase + PI) * (0.3 if running else 0.18)
		if sneaky:
			grab_hand = Vector3(0.28, 1.1, 0.25)  # hand out, ready
	if not on_floor:
		grab_hand = Vector3(0.45, 1.4, 0.05)
	if holding:
		grab_hand = Vector3(0.1, 1.02 + 0.04 * sin(t * 25.0), 0.42)  # cranking the key on its back
	elif grab_timer > 0.0:
		var g := 1.0 - grab_timer / GRAB_TIME
		grab_hand = Vector3(0.12, 1.1, 0.78) if g < 0.45 else Vector3(0.32, 0.95, -0.02)  # snatch, then into the bag
	net_pivot.position = net_pivot.position.lerp(grab_hand, clampf((24.0 if grab_timer > 0.0 else 12.0) * delta, 0.0, 1.0))

	_limb(arms[0], Vector3(-0.27, 1.5, 0), light_hand.position, ARM_UPPER, ARM_LOWER, Vector3(-0.6, -0.3, -1))
	_limb(arms[1], Vector3(0.27, 1.5, 0), net_pivot.position, ARM_UPPER, ARM_LOWER, Vector3(0.6, -0.3, -1))

	visual.scale = visual.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.65
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 3.4      # close, over the shoulder
	arm.position = Vector3(0.55, 0.15, 0)
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62.0
	arm.add_child(camera)
	camera.make_current()


func _physics_process(delta: float) -> void:
	# Camera
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * LOOK_SPEED * delta
	pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -1.2, 0.3)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)

	# Movement relative to the camera.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if holding:
		input = Vector2.ZERO  # can't move while holding one
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
		elif tilt < SNEAK_TILT or Input.is_action_pressed("walk"):
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

	if is_on_floor() and not crouching and holding == null and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		head_vel.x -= 1.5
	elif is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Landing from a real jump makes a thud.
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and air_time > 0.25:
		make_noise(LAND_NOISE)
		visual.scale = Vector3(1.04, 0.94, 1.04)
		head_vel.x += 2.0
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

	if dir != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	_animate(delta, on_floor)


	# Flashlight
	if Input.is_action_just_pressed("light"):
		toggle_flashlight()

	# Net
	net_timer -= delta
	if Input.is_action_just_pressed("net") and (holding or net_timer <= 0.0):
		grab()
	if holding:
		_update_hold(delta)
	grab_timer = maxf(0.0, grab_timer - delta)


## Grab: lunge forward, snatch the nearest robot in front of him and stuff it in the satchel.
func grab() -> void:
	if holding:
		_wind_tap()
		return
	net_timer = GRAB_COOLDOWN
	grab_timer = GRAB_TIME
	var fwd := visual.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if is_on_floor():
		velocity.x += fwd.x * LUNGE_SPEED
		velocity.z += fwd.z * LUNGE_SPEED
	var best: Node = null
	var best_dist := GRAB_RANGE
	for g in get_tree().get_nodes_in_group("gatherers"):
		if not g.can_be_netted():
			continue
		var to: Vector3 = g.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < best_dist and (dist < 0.9 or fwd.dot(to / dist) > 0.35):
			best = g
			best_dist = dist
	if best:
		# Headlock. Now tap to unwind his key.
		holding = best
		hold_needed = TAPS_ALERT if best.is_alert() else TAPS_UNAWARE
		hold_progress = 0.0
		since_tap = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		best.enter_headlock()


## One tap while holding: crank his key the wrong way.
func _wind_tap() -> void:
	since_tap = 0.0
	hold_progress = minf(1.0, hold_progress + 1.0 / hold_needed)
	holding.wind_tap(hold_progress)
	make_noise(3.0, Color(0.85, 0.85, 0.8, 0.7))  # clank, clank: quiet, but not silent
	if hold_progress >= 0.999:
		var r := holding
		holding = null
		r.catch(satchel)
		caught_one.emit()
		get_tree().create_timer(0.4).timeout.connect(_stuffed)


## Keeps the held robot in front of him, and lets it go if he stops cranking.
func _update_hold(delta: float) -> void:
	if not is_instance_valid(holding):
		holding = null
		return
	since_tap += delta
	hold_progress = maxf(0.0, hold_progress - HOLD_DECAY * delta)
	holding.hold_progress = hold_progress
	var fwd := visual.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	holding.global_position = global_position + fwd * 0.55
	holding.heading = atan2(fwd.x, fwd.z)
	holding.visual.rotation.y = holding.heading
	if since_tap > BREAK_TIME:
		var r := holding
		holding = null
		r.break_free()


## A robot just landed in the bag: it bulges a bit more and rattles.
func _stuffed() -> void:
	satchel_fill += 1
	var full := 1.0 + minf(satchel_fill, 5) * 0.1
	var tw := create_tween()
	tw.tween_property(satchel, "scale", Vector3(full * 1.25, full * 1.2, full * 1.5), 0.08)
	tw.tween_property(satchel, "scale", Vector3(full, full, full * 1.15), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in 4:
		tw.parallel().tween_property(satchel, "rotation:z", 0.25 * (1 if i % 2 == 0 else -1), 0.05).set_delay(i * 0.05)
	tw.tween_property(satchel, "rotation:z", 0.0, 0.08)


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	make_noise(1.5, Color(0.9, 0.9, 0.8, 0.5))  # click


## Can robots see you from far away? True with the flashlight on or standing in lamplight.
func is_lit() -> bool:
	if flashlight_on:
		return true
	var main := get_parent()
	return main != null and main.has_method("in_lamp_light") and main.in_lamp_light(global_position)


## Sends a sound out. Any caveman inside the radius hears it.
func make_noise(radius: float, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = Color(1, 0.4, 0.3, 0.8) if radius >= RUN_NOISE else Color(1, 1, 1, 0.7)
	Util.noise_ring(get_parent(), global_position, radius, color)
	get_tree().call_group("gatherers", "hear_noise", global_position, radius, self)


