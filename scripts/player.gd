extends CharacterBody3D
## The hero: a lanky scout mech, about 2.7 m tall. Reverse-jointed bird legs, long
## arms with big blocky fists, a narrow cockpit chest and a small head with one red
## sensor slit and a head lamp.
##   Stealth:  sneak up and grab a soldier from behind, tap GRAB to put him out.
##   Caught:   brawl. PUNCH staggers, GRAB a staggered soldier to throw him.

signal subdued_one
signal died

const Util := preload("res://scripts/util.gd")

# MGS-style movement: how hard you push the stick decides how loud you are.
const CROUCH_SPEED := 1.6     # creeping: silent
const SNEAK_SPEED := 2.4      # light tilt: quiet steps
const RUN_SPEED := 5.2        # full tilt: loud, heavy stomps
const SNEAK_TILT := 0.7       # stick tilt below this = sneaking
const ACCEL := 12.0           # heavy machine: slow to start and stop
const DARK_SIGHT := 0.5       # soldiers see half as far when you're in the dark
const GRAVITY := 22.0
const JUMP_VELOCITY := 7.5
const LOOK_SPEED := 2.6

# Body proportions (meters). Long and skinny on purpose.
const HIP_HEIGHT := 1.42
const LEG_UPPER := 0.74
const LEG_LOWER := 0.78
const ARM_UPPER := 0.64
const ARM_LOWER := 0.72
const SHOULDER := Vector3(0.47, 2.12, 0.0)

# Takedowns
const GRAB_RANGE := 2.2
const GRAB_COOLDOWN := 0.5
const GRAB_TIME := 0.45
const LUNGE_SPEED := 4.5
const TAPS_UNAWARE := 4       # snuck up on him
const TAPS_ALERT := 9         # he was already on to you
const BREAK_TIME := 1.0       # stop tapping this long and he wriggles free
const HOLD_DECAY := 0.12

# Brawling
const MAX_HP := 6
const PUNCH_TIME := 0.42
const PUNCH_HIT_AT := 0.16    # seconds into the punch when the fist lands
const PUNCH_RANGE := 2.3
const PUNCH_NOISE := 6.0
const HURT_TIME := 0.7        # can't be hit again for this long

# How far each sound carries (meters).
const RUN_NOISE := 10.0
const SNEAK_NOISE := 2.5
const LAND_NOISE := 8.0
const RUN_STEP := 0.38
const SNEAK_STEP := 0.6

var crouching := false
var move_mode := "Standing still"
var step_timer := 0.0
var was_on_floor := true
var air_time := 0.0
var arm: SpringArm3D
var visual: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var grab_timer := 0.0
var grab_cooldown := 0.0
var holding: Node = null
var hold_needed := 0
var hold_progress := 0.0
var since_tap := 0.0
var hp := MAX_HP
var dead := false
var hurt_timer := 0.0
var punch_timer := 0.0
var punch_side := 0           # which fist throws the next punch
var punch_landed := false
var subdued := 0
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var walk_phase := 0.0
var legs: Array = []
var feet: Array = []
var arms: Array = []
var hands: Array = []         # [left, right] fists, in body_root space
var yaw := 0.0
var pitch := -0.22
var flashlight: SpotLight3D
var flashlight_on := false   # start dark: stealth first
var lens_mat: StandardMaterial3D
var shake := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = Util.LAYER_PLAYER
	collision_mask = Util.LAYER_WORLD | Util.LAYER_CAVEMAN

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.6
	shape.shape = cap
	shape.position.y = 1.3
	add_child(shape)

	_build_visual()
	_build_camera()
	for o in visual.find_children("", "MeshInstance3D", true, false):
		if o.is_in_group("outlines"):
			o.queue_free()


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var hull := Color(0.55, 0.53, 0.46)       # worn khaki-grey armor
	var frame := Color(0.15, 0.15, 0.16)      # dark inner frame and joints
	var rust := Color(0.72, 0.3, 0.1)         # hazard stripes
	var glow := Color(1.0, 0.18, 0.1)

	# Everything above the hips lives on body_root, which leans, bobs and crouches.
	body_root = Node3D.new()
	visual.add_child(body_root)
	# Pelvis block and a thin exposed spine: the wasp waist is what makes it read lanky.
	body_root.add_child(Util.mesh(Util.box(Vector3(0.46, 0.22, 0.32)), frame, Vector3(0, HIP_HEIGHT, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.5, 0.08, 0.26)), hull, Vector3(0, HIP_HEIGHT + 0.12, 0)))
	var spine := CylinderMesh.new()
	spine.top_radius = 0.09
	spine.bottom_radius = 0.07
	spine.height = 0.36
	spine.radial_segments = 6
	body_root.add_child(Util.mesh(spine, frame, Vector3(0, HIP_HEIGHT + 0.32, 0)))
	# Cockpit chest: a narrow box with a slanted front plate and a hatch line
	body_root.add_child(Util.mesh(Util.box(Vector3(0.62, 0.52, 0.5)), hull, Vector3(0, 2.0, 0)))
	var plate := Util.mesh(Util.box(Vector3(0.5, 0.36, 0.08)), hull.lightened(0.08), Vector3(0, 1.94, 0.27))
	plate.rotation.x = -0.35
	body_root.add_child(plate)
	body_root.add_child(Util.mesh(Util.box(Vector3(0.46, 0.03, 0.02)), frame, Vector3(0, 2.1, 0.255), false))
	for side in [-1.0, 1.0]:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.05, 0.3, 0.02)), rust, Vector3(0.25 * side, 1.98, 0.255), false))
	# Shoulder blocks and a backpack with two exhaust stacks
	for side in [-1.0, 1.0]:
		var pad := Util.mesh(Util.box(Vector3(0.3, 0.2, 0.36)), hull.darkened(0.06), SHOULDER * Vector3(side, 1, 1) + Vector3(0.02 * side, 0.1, 0))
		pad.rotation.z = -0.2 * side
		body_root.add_child(pad)
		var stack := CylinderMesh.new()
		stack.top_radius = 0.05
		stack.bottom_radius = 0.06
		stack.height = 0.4
		stack.radial_segments = 6
		body_root.add_child(Util.mesh(stack, frame, Vector3(0.14 * side, 2.32, -0.33)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.44, 0.44, 0.22)), hull.darkened(0.15), Vector3(0, 2.02, -0.34)))

	# Small head on a stalk: one red sensor slit and a head lamp on the right cheek
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 2.3, 0.05)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.08, 0.14, 0.08)), frame, Vector3(0, 0.05, 0)))
	var skull := Util.mesh(Util.box(Vector3(0.26, 0.17, 0.32)), hull, Vector3(0, 0.18, 0.03))
	head_pivot.add_child(skull)
	var brow := Util.mesh(Util.box(Vector3(0.28, 0.05, 0.12)), hull.darkened(0.1), Vector3(0, 0.26, 0.15))
	brow.rotation.x = 0.25
	head_pivot.add_child(brow)
	var eye := MeshInstance3D.new()
	eye.mesh = Util.box(Vector3(0.2, 0.035, 0.02))
	eye.material_override = Util.mat(glow, true)
	eye.position = Vector3(0, 0.19, 0.19)
	head_pivot.add_child(eye)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.015, 0.4, 0.015)), frame, Vector3(-0.1, 0.42, -0.08), false))  # antenna
	var lamp := Util.mesh(Util.box(Vector3(0.09, 0.08, 0.1)), frame, Vector3(0.17, 0.16, 0.12))
	head_pivot.add_child(lamp)
	lens_mat = Util.mat(Color(1.0, 0.95, 0.8), true)
	var lens := MeshInstance3D.new()
	lens.mesh = Util.box(Vector3(0.06, 0.05, 0.02))
	lens.material_override = lens_mat
	lens.position = Vector3(0.17, 0.16, 0.18)
	head_pivot.add_child(lens)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.17, 0.16, 0.2)
	flashlight.rotation = Vector3(-0.2, PI, 0)
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.9
	flashlight.light_energy = 9.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.visible = flashlight_on
	lens_mat.albedo_color = Color(1.0, 0.95, 0.8) if flashlight_on else Color(0.15, 0.15, 0.12)
	head_pivot.add_child(flashlight)

	# Reverse-jointed legs: thin struts with a big knee joint pointing backward
	for side in [-1.0, 1.0]:
		var thigh := Util.mesh(Util.box(Vector3(0.15, LEG_UPPER + 0.08, 0.18)), hull, Vector3.ZERO)
		var shin := Util.mesh(Util.box(Vector3(0.1, LEG_LOWER + 0.06, 0.12)), frame, Vector3.ZERO)
		legs.append([thigh, shin])
		visual.add_child(thigh)
		visual.add_child(shin)
		thigh.add_child(Util.mesh(Util.box(Vector3(0.04, LEG_UPPER * 0.6, 0.02)), rust, Vector3(0.0, 0.0, 0.1), false))
		var foot := Node3D.new()
		foot.position = Vector3(0.2 * side, 0.0, 0.05)
		visual.add_child(foot)
		foot.add_child(Util.mesh(Util.box(Vector3(0.24, 0.1, 0.46)), frame, Vector3(0, 0.05, 0.06)))
		foot.add_child(Util.mesh(Util.box(Vector3(0.2, 0.08, 0.16)), hull, Vector3(0, 0.12, -0.06)))  # ankle cap
		var toe := Util.mesh(Util.box(Vector3(0.26, 0.07, 0.14)), hull.darkened(0.1), Vector3(0, 0.04, 0.3))
		toe.rotation.x = 0.2
		foot.add_child(toe)
		feet.append(foot)

	# Long arms with big blocky fists
	for side in [-1.0, 1.0]:
		var upper := Util.mesh(Util.box(Vector3(0.13, ARM_UPPER + 0.06, 0.14)), hull, Vector3.ZERO)
		var lower := Util.mesh(Util.box(Vector3(0.15, ARM_LOWER + 0.04, 0.16)), hull.darkened(0.05), Vector3.ZERO)
		lower.add_child(Util.mesh(Util.box(Vector3(0.17, 0.05, 0.18)), rust, Vector3(0, -ARM_LOWER * 0.25, 0), false))
		arms.append([upper, lower])
		body_root.add_child(upper)
		body_root.add_child(lower)
		var hand := Node3D.new()
		hand.position = Vector3(0.52 * side, 1.05, 0.12)
		body_root.add_child(hand)
		hand.add_child(Util.mesh(Util.box(Vector3(0.2, 0.22, 0.22)), frame, Vector3(0, -0.04, 0)))
		hand.add_child(Util.mesh(Util.box(Vector3(0.21, 0.07, 0.23)), hull.darkened(0.1), Vector3(0, 0.06, 0)))  # knuckle guard
		hands.append(hand)


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


## Heavy walk: big slow strides, body bob on each stomp, long arms swinging.
func _animate(delta: float, on_floor: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var hs := Vector2(velocity.x, velocity.z).length()
	var running := move_mode.begins_with("Running")
	var sneaky := crouching or move_mode.begins_with("Sneaking")
	var moving := hs > 0.2 and on_floor
	if moving:
		walk_phase += hs * delta * (2.0 if running else 2.8)

	var body_y := 0.0
	var lean := 0.03
	var sway := 0.0
	if dead:
		body_y = -0.9
		lean = 0.7
	elif not on_floor:
		lean = -0.06
	elif moving:
		body_y = -absf(sin(walk_phase)) * (0.09 if running else 0.05)
		lean = 0.2 if running else (0.3 if sneaky else 0.08)
		sway = sin(walk_phase) * 0.04
	else:
		body_y = sin(t * 1.3) * 0.01  # idle hum
	if crouching and not dead:
		body_y -= 0.62
		lean += 0.12
	if hurt_timer > 0.0:
		lean -= 0.25 * hurt_timer / HURT_TIME
	if punch_timer > 0.0:
		lean += 0.12
	var k := clampf(9.0 * delta, 0.0, 1.0)
	body_root.position.y = lerp(body_root.position.y, body_y, k)
	body_root.rotation.x = lerp_angle(body_root.rotation.x, lean, k)
	body_root.rotation.z = lerp_angle(body_root.rotation.z, sway, k)

	# Head settles with a slight lag, and jolts when hit
	var head_target := Vector3(-lean * 0.7, 0.0, -sway)
	head_vel += (head_target - head_rot) * 80.0 * delta
	head_vel -= head_vel * 11.0 * delta
	head_rot += head_vel * delta
	head_pivot.rotation = head_rot

	# Legs
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.2 * side, 0.0, 0.05)
		if crouching:
			foot.x *= 1.35
		if not on_floor:
			foot += Vector3(0.0, 0.35, -0.15 if i == 0 else 0.2)
		elif moving:
			var stride := 0.6 if running else (0.3 if sneaky else 0.4)
			var lift := 0.3 if running else (0.16 if sneaky else 0.18)
			foot.z += sin(ph) * stride
			foot.y += maxf(0.0, cos(ph)) * lift
		feet[i].position = feet[i].position.lerp(foot, clampf(22.0 * delta, 0.0, 1.0))
		var hip := body_root.transform * Vector3(0.17 * side, HIP_HEIGHT - 0.05, 0)
		var ankle: Vector3 = feet[i].position + Vector3(0, 0.14, -0.08)
		_limb(legs[i], hip, ankle, LEG_UPPER, LEG_LOWER, Vector3(0.15 * side, 0, -1))  # knees bend backward

	# Arms: long and hanging, swinging opposite the legs. Punches and grabs override.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var target := Vector3(0.52 * side, 1.05, 0.12)
		if moving:
			target.z += -sin(walk_phase + (PI if i == 1 else 0.0)) * (0.38 if running else 0.2)
			target.y += absf(sin(walk_phase)) * 0.05
			if sneaky:
				target = Vector3(0.45 * side, 1.35, 0.45)  # hands out, ready
		if not on_floor:
			target = Vector3(0.7 * side, 1.7, 0.0)
		if dead:
			target = Vector3(0.6 * side, 0.5, 0.6)
		var speed := 12.0
		if punch_timer > 0.0 and i == punch_side:
			var u := 1.0 - punch_timer / PUNCH_TIME
			if u < 0.25:
				target = Vector3(0.4 * side, 1.9, -0.25)        # wind back
			elif u < 0.6:
				target = Vector3(0.12 * side, 2.0, 1.25)        # straight jab
			speed = 30.0
		elif punch_timer > 0.0:
			target = Vector3(0.3 * side, 1.8, 0.45)            # guard up
		if i == 1:
			if holding:
				target = Vector3(0.1, 1.95 + 0.04 * sin(t * 25.0), 0.95)  # holding him up by the collar
			elif grab_timer > 0.0:
				var g := 1.0 - grab_timer / GRAB_TIME
				target = Vector3(0.15, 1.6, 1.3) if g < 0.5 else Vector3(0.4, 1.4, 0.5)
				speed = 26.0
		hands[i].position = hands[i].position.lerp(target, clampf(speed * delta, 0.0, 1.0))
		var shoulder := SHOULDER * Vector3(side, 1, 1)
		_limb(arms[i], shoulder, hands[i].position, ARM_UPPER, ARM_LOWER, Vector3(0.5 * side, -0.4, -1))

	# Getting hit shakes the whole frame
	shake = maxf(0.0, shake - delta * 3.0)
	visual.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.08
	visual.scale = visual.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 2.35
	add_child(camera_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 4.8      # pulled back so the whole lanky frame fits
	arm.position = Vector3(0.75, 0.2, 0)
	arm.collision_mask = Util.LAYER_WORLD
	arm.margin = 0.3
	arm.add_excluded_object(get_rid())
	camera_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62.0
	arm.add_child(camera)
	camera.make_current()
	# Faint cool fill light riding with the camera, so the mech reads as a shape
	# in the dark instead of a black stick figure. Doesn't change who can see you.
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.light_energy = 1.3
	fill.omni_range = 10.0
	fill.omni_attenuation = 1.0
	fill.light_specular = 0.0
	fill.position = Vector3(0, 0.6, 0)
	camera.add_child(fill)


func _physics_process(delta: float) -> void:
	# Camera
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * LOOK_SPEED * delta
	pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -1.2, 0.3)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)

	# Movement relative to the camera.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if holding or dead or punch_timer > 0.0:
		input = Vector2.ZERO
	var tilt := input.length()
	var dir := Vector3.ZERO
	if tilt > 0.15:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
	crouching = Input.is_action_pressed("crouch") and not dead

	var speed := 0.0
	var noise := 0.0
	var step := 0.0
	if dead:
		move_mode = "MECH DOWN"
	elif dir != Vector3.ZERO:
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
	var accel := ACCEL if hurt_timer <= 0.0 else ACCEL * 0.4  # knockback slides a bit
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if is_on_floor() and not crouching and not dead and holding == null and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		head_vel.x -= 1.5
	elif is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Landing from a real jump: a heavy thud.
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and air_time > 0.25:
		make_noise(LAND_NOISE)
		visual.scale = Vector3(1.05, 0.92, 1.05)
		head_vel.x += 2.5
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
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 10.0 * delta)
	_animate(delta, on_floor)

	hurt_timer = maxf(0.0, hurt_timer - delta)
	if dead:
		return

	if Input.is_action_just_pressed("light"):
		toggle_flashlight()

	grab_cooldown -= delta
	if Input.is_action_just_pressed("net") and (holding or grab_cooldown <= 0.0):
		grab()
	if Input.is_action_just_pressed("punch"):
		punch()
	if holding:
		_update_hold(delta)
	grab_timer = maxf(0.0, grab_timer - delta)
	_update_punch(delta)


# --- Stealth takedown

## Grab: lunge and grab the nearest soldier in front. Unaware or wary soldiers go
## into a hold (tap to put them out). A soldier staggered mid-fight gets thrown.
func grab() -> void:
	if holding:
		_squeeze_tap()
		return
	grab_cooldown = GRAB_COOLDOWN
	grab_timer = GRAB_TIME
	var fwd := _forward()
	if is_on_floor():
		velocity.x += fwd.x * LUNGE_SPEED
		velocity.z += fwd.z * LUNGE_SPEED
	var best := _nearest_in_front(GRAB_RANGE)
	if best == null:
		return
	if best.is_fighting():
		if best.is_staggered():
			best.thrown(fwd)       # heave him into the snow
			make_noise(PUNCH_NOISE)
		return                     # can't get a grip on someone swinging at you
	holding = best
	hold_needed = TAPS_ALERT if best.is_alert() else TAPS_UNAWARE
	hold_progress = 0.0
	since_tap = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	best.enter_hold()


## One tap while holding: squeeze until he passes out.
func _squeeze_tap() -> void:
	since_tap = 0.0
	hold_progress = minf(1.0, hold_progress + 1.0 / hold_needed)
	holding.squeeze(hold_progress)
	make_noise(2.0, Color(0.85, 0.85, 0.8, 0.6))  # servo whine: quiet, not silent
	if hold_progress >= 0.999:
		var s := holding
		holding = null
		s.knock_out(global_position + _forward() * 1.1)


## Keeps the held soldier dangling in front, and lets him go if you stop squeezing.
func _update_hold(delta: float) -> void:
	if not is_instance_valid(holding):
		holding = null
		return
	since_tap += delta
	hold_progress = maxf(0.0, hold_progress - HOLD_DECAY * delta)
	holding.hold_progress = hold_progress
	var fwd := _forward()
	holding.global_position = global_position + fwd * 1.0 + Vector3.UP * 0.35
	holding.heading = atan2(-fwd.x, -fwd.z)   # facing you, legs kicking
	holding.visual.rotation.y = holding.heading
	if since_tap > BREAK_TIME:
		var s := holding
		holding = null
		s.break_free()


## A soldier went down: called by the soldier so throws and punches count too.
func on_subdued() -> void:
	subdued += 1
	subdued_one.emit()


# --- Brawling

func punch() -> void:
	if punch_timer > 0.0 or holding or dead:
		return
	punch_timer = PUNCH_TIME
	punch_landed = false
	punch_side = 1 - punch_side
	var fwd := _forward()
	if is_on_floor():
		velocity.x = fwd.x * 2.5
		velocity.z = fwd.z * 2.5


func _update_punch(delta: float) -> void:
	if punch_timer <= 0.0:
		return
	punch_timer = maxf(0.0, punch_timer - delta)
	if not punch_landed and PUNCH_TIME - punch_timer >= PUNCH_HIT_AT:
		punch_landed = true
		var s := _nearest_in_front(PUNCH_RANGE)
		if s:
			s.take_punch(_forward())
			head_vel.x += 1.0
		make_noise(PUNCH_NOISE if s else 3.0)


## Hit by a soldier's shock baton.
func take_hit(from: Vector3, damage := 1) -> void:
	if dead or hurt_timer > 0.0:
		return
	hp = maxi(0, hp - damage)
	hurt_timer = HURT_TIME
	shake = 1.0
	head_vel += Vector3(-4.0, randf_range(-3, 3), randf_range(-3, 3))
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() * 5.0
	velocity.x = away.x
	velocity.z = away.z
	if holding:
		var s := holding
		holding = null
		s.break_free()
	_sparks()
	if hp <= 0:
		dead = true
		flashlight.visible = false
		lens_mat.albedo_color = Color(0.1, 0.1, 0.1)
		died.emit()


func _sparks() -> void:
	for i in 6:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3(0.06, 0.06, 0.06))
		sp.material_override = Util.mat(Color(0.6, 0.85, 1.0), true)
		body_root.add_child(sp)
		sp.position = Vector3(randf_range(-0.3, 0.3), 2.0, 0.3)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", sp.position + Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 0.8), randf_range(-0.2, 0.8)), 0.3)
		tw.tween_callback(sp.queue_free)


# --- Helpers

func _forward() -> Vector3:
	var fwd := visual.global_basis.z
	fwd.y = 0.0
	return fwd.normalized()


func _nearest_in_front(reach: float) -> Node:
	var fwd := _forward()
	var best: Node = null
	var best_dist := reach
	for s in get_tree().get_nodes_in_group("soldiers"):
		if not s.can_be_hit():
			continue
		var to: Vector3 = s.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < best_dist and (dist < 1.0 or fwd.dot(to / dist) > 0.35):
			best = s
			best_dist = dist
	return best


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	lens_mat.albedo_color = Color(1.0, 0.95, 0.8) if flashlight_on else Color(0.15, 0.15, 0.12)
	make_noise(1.5, Color(0.9, 0.9, 0.8, 0.5))  # click


## Can soldiers see you from far away? True with the head lamp on or standing in lamplight.
func is_lit() -> bool:
	if flashlight_on:
		return true
	var main := get_parent()
	return main != null and main.has_method("in_lamp_light") and main.in_lamp_light(global_position)


## Sends a sound out. Any soldier inside the radius hears it.
func make_noise(radius: float, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = Color(1, 0.4, 0.3, 0.8) if radius >= RUN_NOISE else Color(1, 1, 1, 0.7)
	Util.noise_ring(get_parent(), global_position, radius, color)
	get_tree().call_group("soldiers", "hear_noise", global_position, radius, self)
