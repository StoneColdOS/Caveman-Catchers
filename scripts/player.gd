extends CharacterBody3D
## The hero. Placeholder look: silver capsule with a bubble helmet and a net.

signal caught_one

const Util := preload("res://scripts/util.gd")

const WALK_SPEED := 6.5
const CROUCH_SPEED := 2.6
const ACCEL := 30.0
const GRAVITY := 20.0
const LOOK_SPEED := 2.6
const NET_RANGE := 2.4
const NET_COOLDOWN := 0.45

var crouching := false
var visual: Node3D
var net_pivot: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var net_timer := 0.0
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
	# Suit
	visual.add_child(Util.mesh(Util.capsule(0.4, 1.3), Color(0.82, 0.84, 0.86), Vector3(0, 0.7, 0)))
	# Orange chest box, on the front (+Z is forward)
	visual.add_child(Util.mesh(Util.box(Vector3(0.36, 0.26, 0.12)), Color(0.91, 0.51, 0.23), Vector3(0, 0.95, 0.36)))
	# Dark head inside a glass bubble
	visual.add_child(Util.mesh(Util.sphere(0.24), Color(0.12, 0.1, 0.09), Vector3(0, 1.58, 0)))
	var helmet := Util.mesh(Util.sphere(0.36), Color(0.8, 0.9, 0.95, 0.35), Vector3(0, 1.6, 0))
	visual.add_child(helmet)
	# Antenna
	visual.add_child(Util.mesh(Util.box(Vector3(0.03, 0.3, 0.03)), Color(0.6, 0.65, 0.68), Vector3(0.15, 2.05, 0)))
	visual.add_child(Util.mesh(Util.sphere(0.06), Color(0.91, 0.51, 0.23), Vector3(0.15, 2.22, 0)))

	# Net: pivots around the shoulder, handle points forward
	net_pivot = Node3D.new()
	net_pivot.position = Vector3(0.45, 1.0, 0)
	visual.add_child(net_pivot)
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


func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.4
	add_child(camera_pivot)
	var arm := SpringArm3D.new()
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

	# Movement relative to the camera. Analog sticks give analog speed.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	crouching = Input.is_action_pressed("crouch")
	var speed := CROUCH_SPEED if crouching else WALK_SPEED
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	if dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	visual.scale.y = lerp(visual.scale.y, 0.6 if crouching else 1.0, 12.0 * delta)

	# Net
	net_timer -= delta
	if net_timer <= 0.0 and Input.is_action_just_pressed("net"):
		swing_net()


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
		if g.is_caught():
			continue
		var to: Vector3 = g.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < NET_RANGE and (dist < 0.9 or fwd.dot(to / dist) > 0.35):
			g.catch()
			caught_one.emit()


## Net held upright beside him when not swinging.
func _rest_net() -> void:
	net_pivot.rotation = Vector3(-1.2, 0.2, 0)
