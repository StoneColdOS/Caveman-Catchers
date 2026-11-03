extends CharacterBody3D
## The Gatherer: the standard caveman.
##   Calm: wanders around.
##   Suspicious: sees you, stops and stares while his meter fills ("?").
##   Spotted: runs away from you ("!"), calms down after losing you.

enum State { WANDER, SUSPICIOUS, FLEE, CAUGHT }

const Util := preload("res://scripts/util.gd")

const WANDER_SPEED := 1.6
const FLEE_SPEED := 5.2          # a bit slower than the player, so a chase is winnable
const WANDER_RADIUS := 8.0
const SIGHT_RANGE := 11.0
const SIGHT_RANGE_CROUCH := 5.0  # crouching makes you much harder to see
const FOV_DEG := 110.0
const NOTICE_TIME := 1.2         # seconds in plain view (far away) before he spots you
const CALM_RATE := 0.35
const FLEE_TIME := 4.0
const GRAVITY := 20.0

const CONE_CALM := Color(0.2, 1.0, 0.45, 0.3)
const CONE_SUSPICIOUS := Color(1.0, 0.85, 0.1, 0.45)
const CONE_SPOTTED := Color(1.0, 0.15, 0.1, 0.5)

var state := State.WANDER
var awareness := 0.0
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var wander_wait := 0.0
var wander_give_up := 0.0
var flee_timer := 0.0
var player: Node3D
var visual: Node3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D
var alert: Label3D


func _ready() -> void:
	add_to_group("gatherers")
	collision_layer = Util.LAYER_CAVEMAN
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_CAVEMAN
	home = global_position
	player = get_tree().get_first_node_in_group("player")

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.5
	shape.shape = cap
	shape.position.y = 0.75
	add_child(shape)

	_build_visual()
	_pick_wander_target()
	visual.rotation.y = randf() * TAU


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var fur := Color(0.45, 0.28, 0.16)
	var skin := Color(0.85, 0.66, 0.5)
	# Fur tunic body
	visual.add_child(Util.mesh(Util.capsule(0.42, 1.2), fur, Vector3(0, 0.65, 0)))
	# Head, big shaggy hair, and the all-important unibrow
	visual.add_child(Util.mesh(Util.sphere(0.27), skin, Vector3(0, 1.45, 0.05)))
	visual.add_child(Util.mesh(Util.sphere(0.32), Color(0.2, 0.13, 0.08), Vector3(0, 1.55, -0.08)))
	visual.add_child(Util.mesh(Util.box(Vector3(0.36, 0.07, 0.06)), Color(0.15, 0.1, 0.06), Vector3(0, 1.53, 0.3)))
	# Nose, so you can tell which way he's facing
	visual.add_child(Util.mesh(Util.box(Vector3(0.1, 0.1, 0.12)), skin.darkened(0.15), Vector3(0, 1.43, 0.33)))

	# Vision cone on the ground, rotates with him
	cone = MeshInstance3D.new()
	cone.mesh = _cone_mesh(SIGHT_RANGE, deg_to_rad(FOV_DEG))
	cone_mat = Util.mat(CONE_CALM, true)
	cone.material_override = cone_mat
	cone.position.y = 0.05
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(cone)

	# "?" and "!" above his head
	alert = Label3D.new()
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.font_size = 96
	alert.pixel_size = 0.012
	alert.outline_size = 18
	alert.position.y = 2.3
	alert.no_depth_test = true
	add_child(alert)


func _physics_process(delta: float) -> void:
	if state == State.CAUGHT:
		return

	var sees := can_see_player()
	var move := Vector3.ZERO

	match state:
		State.WANDER, State.SUSPICIOUS:
			if sees:
				awareness += delta / NOTICE_TIME * _closeness_boost()
				state = State.SUSPICIOUS
				_turn_toward(player.global_position, 2.5, delta)
			else:
				awareness = max(0.0, awareness - CALM_RATE * delta)
				if awareness == 0.0:
					state = State.WANDER
			if awareness >= 1.0:
				_start_flee()
			elif state == State.WANDER:
				move = _wander(delta)
		State.FLEE:
			if sees:
				flee_timer = FLEE_TIME
			else:
				flee_timer -= delta
			if flee_timer <= 0.0:
				# Lost you. Stays jumpy for a bit.
				state = State.SUSPICIOUS
				awareness = 0.6
			else:
				var away := global_position - player.global_position
				away.y = 0.0
				move = away.normalized() * FLEE_SPEED
				_turn_toward(global_position + away, 10.0, delta)

	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_indicators()


func can_see_player() -> bool:
	if player == null:
		return false
	var crouching: bool = player.crouching
	var sight := SIGHT_RANGE_CROUCH if crouching else SIGHT_RANGE
	var eye := global_position + Vector3.UP * 1.45
	var target := player.global_position + Vector3.UP * (0.6 if crouching else 1.2)
	var to := target - eye
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > sight:
		return false
	if flat.length() > 1.2:
		var fwd := visual.global_basis.z
		fwd.y = 0.0
		if rad_to_deg(fwd.normalized().angle_to(flat.normalized())) > FOV_DEG * 0.5:
			return false
	# Rocks and trees block his view
	var q := PhysicsRayQueryParameters3D.create(eye, target, Util.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func is_caught() -> bool:
	return state == State.CAUGHT


func catch() -> void:
	state = State.CAUGHT
	collision_layer = 0
	collision_mask = 0
	alert.text = ""
	cone.visible = false

	# Beam him away
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.7
	cyl.height = 30.0
	cyl.radial_segments = 10
	beam.mesh = cyl
	beam.material_override = Util.mat(Color(0.5, 0.95, 1.0, 0.45), true)
	beam.position.y = 15.0
	add_child(beam)

	var tw := create_tween()
	tw.tween_property(visual, "position:y", 4.0, 0.7).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "scale", Vector3(0.1, 2.0, 0.1), 0.7).set_ease(Tween.EASE_IN)
	tw.tween_property(beam, "scale", Vector3(0.01, 1, 0.01), 0.25)
	tw.tween_callback(queue_free)


func _start_flee() -> void:
	awareness = 1.0
	state = State.FLEE
	flee_timer = FLEE_TIME


## Closer means he notices you faster (up to 3x).
func _closeness_boost() -> float:
	var dist := global_position.distance_to(player.global_position)
	return lerp(3.0, 1.0, clamp(dist / SIGHT_RANGE, 0.0, 1.0))


func _wander(delta: float) -> Vector3:
	if wander_wait > 0.0:
		wander_wait -= delta
		return Vector3.ZERO
	var to := wander_target - global_position
	to.y = 0.0
	wander_give_up -= delta
	if to.length() < 0.5 or wander_give_up <= 0.0:
		wander_wait = randf_range(1.0, 3.0)
		_pick_wander_target()
		return Vector3.ZERO
	_turn_toward(wander_target, 4.0, delta)
	return to.normalized() * WANDER_SPEED


func _pick_wander_target() -> void:
	var a := randf() * TAU
	var r := randf_range(2.0, WANDER_RADIUS)
	wander_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	wander_give_up = 8.0


func _turn_toward(point: Vector3, speed: float, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), clamp(speed * delta, 0.0, 1.0))


func _update_indicators() -> void:
	match state:
		State.WANDER:
			cone_mat.albedo_color = CONE_CALM
			alert.text = ""
		State.SUSPICIOUS:
			cone_mat.albedo_color = CONE_SUSPICIOUS
			alert.text = "?"
			alert.modulate = Color(1, 0.85, 0.2)
		State.FLEE:
			cone_mat.albedo_color = CONE_SPOTTED
			alert.text = "!"
			alert.modulate = Color(1, 0.3, 0.25)
	# The cone shrinks when you crouch, so you can see how close you can get.
	var reach := (SIGHT_RANGE_CROUCH if player.crouching else SIGHT_RANGE) / SIGHT_RANGE
	cone.scale = Vector3(reach, 1, reach)


## A flat fan shape pointing along +Z.
static func _cone_mesh(length: float, angle: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 12
	for i in steps:
		var a0 := -angle / 2.0 + angle * i / steps
		var a1 := -angle / 2.0 + angle * (i + 1) / steps
		verts.append(Vector3.ZERO)
		verts.append(Vector3(sin(a0), 0, cos(a0)) * length)
		verts.append(Vector3(sin(a1), 0, cos(a1)) * length)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
