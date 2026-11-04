extends CharacterBody3D
## The hero: a lanky old space chimp from the user's sketch. Droopy eye, X eye, chewed
## ear, a cigarette floating at his mouth, harness, pouches, a satchel he stuffs robots
## into, and a robot arm.

signal caught_one

const Util := preload("res://scripts/util.gd")

# MGS-style movement: how hard you push the stick decides how loud you are.
const CROUCH_SPEED := 1.6     # creeping: silent
const SNEAK_SPEED := 2.4      # light tilt: quiet footsteps
const RUN_SPEED := 5.0        # full tilt: loud footsteps
const SNEAK_TILT := 0.7       # stick tilt below this = sneaking
const ACCEL := 30.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const LOOK_SPEED := 2.6
const GRAB_RANGE := 1.7      # he has to get right up to them
const GRAB_COOLDOWN := 0.5
const GRAB_TIME := 0.45      # lunge forward, then stuff it over his shoulder
const LUNGE_SPEED := 4.5     # little burst forward on every grab, so chases are winnable

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
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var legs: Array = []
var feet: Array = []
var right_arm: Array = []
var robot_arm: Array = []
var claw: MeshInstance3D
var knee_pads: Array = []
var right_band: MeshInstance3D
var smoke_origin: Array = []
var smoke_away: Array = []
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
	# Colors pulled from the inspo: worn grey suit, olive gear, brown fur
	var suit := Color(0.4, 0.43, 0.45)
	var gear := Color(0.37, 0.38, 0.27)
	var dark := Color(0.16, 0.16, 0.15)
	var metal := Color(0.55, 0.6, 0.64)
	var fur := Color(0.33, 0.23, 0.16)
	var face := Color(0.85, 0.72, 0.6)
	var ink := Color(0.07, 0.06, 0.05)

	# Everything above the hips lives on body_root, which bounces, leans and squashes.
	body_root = Node3D.new()
	visual.add_child(body_root)
	body_root.add_child(Util.mesh(Util.capsule(0.25, 0.62), suit, Vector3(0, 1.2, 0)))
	# Chest, shoulders and hips give the torso some shape
	var chest := Util.mesh(Util.sphere(0.2), suit.lightened(0.05), Vector3(0, 1.3, 0.1))
	chest.scale = Vector3(1.25, 0.85, 0.65)
	body_root.add_child(chest)
	for side in [-1.0, 1.0]:
		var pad := Util.mesh(Util.sphere(0.1), suit.darkened(0.12), Vector3(0.26 * side, 1.42, 0))
		pad.scale = Vector3(1.1, 0.75, 1.1)
		body_root.add_child(pad)
	var hips := Util.mesh(Util.sphere(0.22), suit.darkened(0.08), Vector3(0, 0.96, 0))
	hips.scale = Vector3(1.1, 0.55, 1.0)
	body_root.add_child(hips)
	# V harness straps meeting at the belt
	for side in [-1.0, 1.0]:
		var strap := Util.mesh(Util.box(Vector3(0.05, 0.5, 0.03)), gear, Vector3(0.08 * side, 1.2, 0.235))
		strap.rotation.z = 0.32 * side
		body_root.add_child(strap)
	# Belt with three pouches
	body_root.add_child(Util.mesh(Util.box(Vector3(0.56, 0.07, 0.52)), dark, Vector3(0, 0.95, 0)))
	for x in [-0.13, 0.0, 0.13]:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.1, 0.13, 0.07)), gear, Vector3(x, 0.93, 0.27)))
		body_root.add_child(Util.mesh(Util.box(Vector3(0.11, 0.045, 0.085)), gear.darkened(0.2), Vector3(x, 0.99, 0.275)))  # pouch flap
		body_root.add_child(Util.mesh(Util.box(Vector3(0.015, 0.06, 0.01)), dark, Vector3(x, 0.93, 0.31)))
	# Satchel on his back: caught robots get stuffed in here, and it bulges as it fills
	satchel = Node3D.new()
	satchel.position = Vector3(0, 1.12, -0.3)
	body_root.add_child(satchel)
	satchel.add_child(Util.mesh(Util.box(Vector3(0.34, 0.3, 0.14)), Color(0.45, 0.36, 0.24), Vector3.ZERO))
	satchel.add_child(Util.mesh(Util.box(Vector3(0.36, 0.12, 0.17)), Color(0.38, 0.3, 0.2), Vector3(0, 0.12, -0.01)))  # flap
	satchel.add_child(Util.mesh(Util.box(Vector3(0.05, 0.05, 0.02)), Color(0.7, 0.62, 0.4), Vector3(0, 0.08, -0.1)))   # buckle
	var cross := Util.mesh(Util.box(Vector3(0.04, 0.62, 0.02)), Color(0.38, 0.3, 0.2), Vector3(0.0, 1.22, 0.24))
	cross.rotation.z = -0.6
	body_root.add_child(cross)
	# Robot arm's shoulder joint (his left)
	body_root.add_child(Util.mesh(Util.sphere(0.09), Color(0.91, 0.51, 0.23), Vector3(0.3, 1.38, 0)))

	# Head on a springy pivot (no helmet)
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.5, 0)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.sphere(0.26), fur, Vector3(0, 0.24, 0)))
	for tuft in [[-0.04, 0.3, 0.15], [0.06, 0.25, -0.2]]:
		var spike := Util.mesh(Util.box(Vector3(0.05, 0.16, 0.05)), fur, Vector3(tuft[0], 0.52, 0.02))
		spike.rotation = Vector3(0, 0, tuft[2] * 2.0)
		head_pivot.add_child(spike)
	var mask := Util.mesh(Util.sphere(0.2), face, Vector3(0, 0.2, 0.11))
	mask.scale = Vector3(1.05, 1.0, 0.75)
	head_pivot.add_child(mask)
	# His right ear: plain. His left ear: big, with a bite chewed out of it.
	head_pivot.add_child(Util.mesh(Util.sphere(0.08), face, Vector3(-0.26, 0.22, 0)))
	for e in [[0.28, 0.3, 0.0], [0.34, 0.2, -0.01], [0.3, 0.11, 0.03]]:
		head_pivot.add_child(Util.mesh(Util.sphere(0.065), face, Vector3(e[0], e[1], e[2])))
	# Droopy half-lidded eye (his right) and an X for the other one
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.05, 0.035, 0.02)), ink, Vector3(-0.07, 0.222, 0.262), false))
	var lid := Util.mesh(Util.box(Vector3(0.075, 0.018, 0.02)), ink, Vector3(-0.07, 0.243, 0.26), false)
	lid.rotation.z = -0.25
	head_pivot.add_child(lid)
	for r in [0.785, -0.785]:
		var stroke := Util.mesh(Util.box(Vector3(0.075, 0.016, 0.02)), ink, Vector3(0.07, 0.235, 0.255), false)
		stroke.rotation.z = r
		head_pivot.add_child(stroke)
	# Brow ridge and a muzzle that sticks out, so the face has depth
	var brow := Util.mesh(Util.sphere(0.12), fur.darkened(0.1), Vector3(0, 0.29, 0.17))
	brow.scale = Vector3(1.55, 0.32, 0.75)
	head_pivot.add_child(brow)
	var snout := Util.mesh(Util.sphere(0.11), face.lightened(0.06), Vector3(0, 0.12, 0.2))
	snout.scale = Vector3(1.25, 0.8, 0.85)
	head_pivot.add_child(snout)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.03, 0.022, 0.02)), ink, Vector3(0.0, 0.17, 0.286), false))   # nose
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.1, 0.016, 0.02)), ink, Vector3(0.0, 0.1, 0.285), false))    # mouth
	for side in [-1.0, 1.0]:  # cheeks
		head_pivot.add_child(Util.mesh(Util.sphere(0.06), face.darkened(0.05), Vector3(0.12 * side, 0.15, 0.17)))
	# Neck
	var neck := CylinderMesh.new()
	neck.top_radius = 0.09
	neck.bottom_radius = 0.11
	neck.height = 0.14
	neck.radial_segments = 8
	head_pivot.add_child(Util.mesh(neck, suit, Vector3(0, -0.03, 0)))
	# Cigarette floats in front of his mouth, cartoon style. It's on the body, not the
	# head, so it stays put while his head bobbles.
	var cig := Util.mesh(Util.box(Vector3(0.028, 0.028, 0.24)), Color(0.95, 0.93, 0.88), Vector3(-0.13, 1.6, 0.37))
	cig.rotation = Vector3(-0.12, -1.05, 0)
	body_root.add_child(cig)
	cig.add_child(Util.mesh(Util.box(Vector3(0.03, 0.03, 0.06)), Color(0.85, 0.6, 0.35), Vector3(0, 0, -0.09)))  # filter at his lips
	cig_tip = MeshInstance3D.new()
	cig_tip.mesh = Util.sphere(0.022)
	cig_tip.material_override = Util.mat(Color(1.0, 0.45, 0.1), true)
	cig_tip.position = Vector3(0, 0, 0.125)
	cig.add_child(cig_tip)
	# Smoke trails up from the tip in world space
	smoke = Node3D.new()
	smoke.top_level = true
	add_child(smoke)
	for i in 16:
		var puff := MeshInstance3D.new()
		puff.mesh = Util.sphere(0.09)
		puff.material_override = Util.mat(Color(0.88, 0.9, 0.92, 0.6), true)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.add_child(puff)
		smoke_origin.append(Vector3.ZERO)
		smoke_away.append(Vector3.ZERO)

	# Long, lanky noodle limbs
	for side in [-1.0, 1.0]:
		legs.append(_make_noodle(14, 0.06, suit, Color()))
		var pad := Util.mesh(Util.sphere(0.085), dark, Vector3.ZERO)
		pad.scale = Vector3(1, 1.15, 0.7)
		visual.add_child(pad)
		knee_pads.append(pad)
		var boot := Util.mesh(Util.sphere(0.12), dark, Vector3(0.14 * side, 0.08, 0.05))
		boot.scale = Vector3(1.0, 0.75, 1.6)
		visual.add_child(boot)
		boot.add_child(Util.mesh(Util.box(Vector3(0.17, 0.05, 0.14)), gear, Vector3(0, 0.13, -0.03)))  # boot band
		boot.add_child(Util.mesh(Util.box(Vector3(0.21, 0.04 / 0.75, 0.36 / 1.6)), Color(0.08, 0.08, 0.08), Vector3(0, -0.085 / 0.75, 0)))  # sole
		feet.append(boot)
	right_arm = _make_noodle(12, 0.05, suit, Color())
	robot_arm = _make_noodle(13, 0.055, metal, Color(0.32, 0.36, 0.4))  # accordion-striped spring arm
	right_band = Util.mesh(Util.sphere(0.065), gear, Vector3.ZERO)
	visual.add_child(right_band)
	claw = Util.mesh(Util.sphere(0.08), Color(0.4, 0.45, 0.5), Vector3.ZERO)
	claw.scale = Vector3(1, 0.8, 1.25)
	body_root.add_child(claw)
	claw.add_child(Util.mesh(Util.box(Vector3(0.03, 0.12, 0.03)), metal, Vector3(-0.04, -0.09, 0.04)))
	claw.add_child(Util.mesh(Util.box(Vector3(0.03, 0.12, 0.03)), metal, Vector3(0.04, -0.09, 0.04)))

	# His right hand (chimp hand) does the grabbing
	net_pivot = Node3D.new()
	net_pivot.position = Vector3(-0.4, 0.78, 0.08)
	body_root.add_child(net_pivot)
	net_pivot.add_child(Util.mesh(Util.sphere(0.075), face, Vector3.ZERO))
	for f in 3:
		net_pivot.add_child(Util.mesh(Util.box(Vector3(0.025, 0.025, 0.07)), face.darkened(0.1), Vector3(-0.04 + f * 0.04, -0.03, 0.07)))


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
		body_y -= 0.4
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
		var hip := body_root.transform * Vector3(0.13 * side, 0.92, 0)
		_noodle(legs[i], hip, feet[i].position + Vector3(0, 0.07, -0.04), 0.9, Vector3(0.35 * side, 0.0, 1.0))
		knee_pads[i].position = legs[i][legs[i].size() / 2].position + Vector3(0, 0, 0.04)

	# Arms (hand targets are in body space)
	var net_hand := Vector3(-0.4, 0.78, 0.08)
	var claw_hand := Vector3(0.4, 0.74, 0.02)
	if not on_floor:
		var f := sin(t * 18.0) * 0.15 * amp
		net_hand = Vector3(-0.58, 1.78 + f, 0.0)
		claw_hand = Vector3(0.58, 1.78 - f, 0.05)
	elif moving and running:
		var a := walk_phase * 2.0
		claw_hand = Vector3(0.42, 1.38, 0.0) + Vector3(0, sin(a), cos(a)) * 0.55 * amp  # windmill
		net_hand = Vector3(-0.4, 0.85, 0.08 - sin(walk_phase) * 0.4 * amp)
	elif moving and sneaky:
		var w := sin(walk_phase) * 0.05 * amp
		net_hand = Vector3(-0.32, 1.36 + w, 0.32)   # hands up like claws, tiptoeing
		claw_hand = Vector3(0.3, 1.36 - w, 0.34)
	elif moving:
		net_hand.z -= sin(walk_phase) * 0.28 * amp
		claw_hand.z += sin(walk_phase) * 0.32 * amp
	else:
		net_hand.z += sin(beat * 0.5) * 0.06 * amp
		claw_hand.z -= sin(beat * 0.5) * 0.08 * amp
		claw_hand.y += absf(sin(beat * 0.5)) * 0.06 * amp
	if grab_timer > 0.0:
		# Lunge the hand out, then swing it back over his shoulder to the satchel
		var g := 1.0 - grab_timer / GRAB_TIME
		net_hand = Vector3(-0.12, 1.15, 0.8) if g < 0.45 else Vector3(-0.15, 1.6, -0.35)
	net_pivot.position = net_pivot.position.lerp(net_hand, clampf((24.0 if grab_timer > 0.0 else 14.0) * delta, 0.0, 1.0))
	claw.position = claw.position.lerp(claw_hand, clampf(14.0 * delta, 0.0, 1.0))
	var bt := body_root.transform
	_noodle(right_arm, bt * Vector3(-0.3, 1.38, 0), bt * net_pivot.position, 0.8, Vector3(-1.0, -0.5, -0.3))
	_noodle(robot_arm, bt * Vector3(0.3, 1.38, 0), bt * claw.position, 0.84, Vector3(1.0, -0.5, -0.3))
	right_band.position = right_arm[right_arm.size() - 3].position  # wristband

	# Landing squash recovers on the whole figure
	visual.scale = visual.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.6
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
	# Camera
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * LOOK_SPEED * delta
	pitch = clamp(pitch - look.y * LOOK_SPEED * delta, -1.2, 0.3)
	camera_pivot.rotation = Vector3(pitch, yaw, 0)

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

	if dir != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	_animate(delta, on_floor)

	_animate_smoke()

	# Net
	net_timer -= delta
	if net_timer <= 0.0 and Input.is_action_just_pressed("net"):
		grab()
	grab_timer = maxf(0.0, grab_timer - delta)


## Grab: lunge forward, snatch the nearest robot in front of him and stuff it in the satchel.
func grab() -> void:
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
		best.catch(satchel)
		caught_one.emit()
		get_tree().create_timer(0.4).timeout.connect(_stuffed)


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


## Sends a sound out. Any caveman inside the radius hears it.
func make_noise(radius: float, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = Color(1, 0.4, 0.3, 0.8) if radius >= RUN_NOISE else Color(1, 1, 1, 0.7)
	Util.noise_ring(get_parent(), global_position, radius, color)
	get_tree().call_group("gatherers", "hear_noise", global_position, radius, self)


## Thick smoke drifts up from the cigarette and trails behind him; the tip pulses.
func _animate_smoke() -> void:
	# Each puff leaves the cigarette tip, drifts up and grows, then starts over.
	var t := Time.get_ticks_msec() * 0.001
	var tip := cig_tip.global_position
	var n := smoke.get_child_count()
	for i in n:
		var puff: MeshInstance3D = smoke.get_child(i)
		var life := fposmod(t * 0.32 + float(i) / n, 1.0)
		if life < 0.05 or smoke_origin[i] == Vector3.ZERO:
			smoke_origin[i] = tip
			var away := tip - head_pivot.global_position
			away.y = 0.0
			smoke_away[i] = away.normalized() if away.length() > 0.01 else Vector3.ZERO
		var o: Vector3 = smoke_origin[i] + smoke_away[i] * life * 0.45  # drift away from his face
		# Puffs stay where they were puffed, so moving leaves a trail behind him
		puff.global_position = o + Vector3(sin(t * 1.6 + i) * 0.14 * life, life * 1.3, cos(t * 1.3 + i) * 0.12 * life)
		puff.scale = Vector3.ONE * (0.6 + life * 2.6)
		(puff.material_override as StandardMaterial3D).albedo_color.a = 0.62 * (1.0 - life * life)
	var glow := 0.75 + 0.25 * sin(t * 3.0)
	(cig_tip.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35 * glow + 0.1, 0.05)
