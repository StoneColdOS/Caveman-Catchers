extends CharacterBody3D
## The standard janky robot monkey (internally still called a Gatherer).
##   Calm:        wanders, forages with his head down (half blind), stops to look around.
##   Hears noise: hops, says "?", walks over to check it out, looks around.
##   Sees you:    stares while his "?" grows. Lose him and he checks where he last saw you.
##   Spotted:     leaps, yells and runs to warn the tribe. Countdown over his head:
##                net him or dart him before it hits zero, or it's game over.
##   Darted:      staggers and yelps for a moment (nearby cavemen hear it), then drops.
##   Asleep:      lies flat ("Zzz"), easy to net, wakes up groggy.

signal warned_tribe

enum State { WANDER, FORAGE, SUSPICIOUS, INVESTIGATE, FLEE, CAUGHT, DROWSY, SLEEP }

const Util := preload("res://scripts/util.gd")

const WANDER_SPEED := 1.6
const INVESTIGATE_SPEED := 2.2
const FLEE_SPEED := 4.6          # just under your run speed, so chases are tight
const WANDER_RADIUS := 8.0
const SIGHT_RANGE := 12.0
const SIGHT_RANGE_CROUCH := 5.0
const FORAGE_SIGHT := 0.4        # foraging: sees 40% as far
const FOV_DEG := 120.0
const FORAGE_FOV_DEG := 70.0
const NOTICE_TIME := 0.8         # seconds in view (at max range) to spot you; faster up close
const CALM_RATE := 0.25
const HEAR_BUMP := 0.3
const WARN_TIME := 5.0           # seconds you have to stop a spotter
const YELL_RADIUS := 10.0
const YELP_RADIUS := 7.0         # yelp when a dart hits
const DROWSY_TIME := 2.0         # dart takes this long to kick in
const SLEEP_TIME := 8.0
const GRAVITY := 20.0

const CONE_CALM := Color(0.2, 1.0, 0.45, 0.3)
const CONE_SUSPICIOUS := Color(1.0, 0.85, 0.1, 0.45)
const CONE_SPOTTED := Color(1.0, 0.15, 0.1, 0.5)

var state := State.WANDER
var awareness := 0.0
var scan := true                 # tests switch this off to freeze him in place
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var interest_point := Vector3.ZERO
var last_seen := Vector3.ZERO
var wait_timer := 0.0
var turn_timer := 0.0
var give_up := 0.0
var state_timer := 0.0
var look_timer := 0.0
var warn_timer := 0.0
var hop_timer := 0.0
var drowsy_timer := 0.0
var sleep_timer := 0.0
var heading := 0.0
var turn_speed := 4.0
var player: Node3D
var visual: Node3D
var torso: Node3D
var head: Node3D
var key: Node3D
var eye_mat: StandardMaterial3D
var glitch_timer := 0.0
var alerted := false
var escaped_for_good := false
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
	heading = randf() * TAU
	visual.rotation.y = heading


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	torso = Node3D.new()
	torso.position.y = 0.2
	visual.add_child(torso)
	# Each robot gets a slightly different, slightly wrong look.
	var tins := [Color(0.42, 0.6, 0.6), Color(0.68, 0.5, 0.36), Color(0.55, 0.57, 0.62), Color(0.64, 0.6, 0.42)]
	var tin: Color = tins[randi() % tins.size()]
	var rust := Color(0.5, 0.3, 0.18)
	var y := -0.2
	# Boxy tin body with a rust patch, stubby legs
	var body := Util.mesh(Util.box(Vector3(0.62, 0.66, 0.5)), tin, Vector3(0, 0.78 + y, 0))
	body.rotation.z = randf_range(-0.08, 0.08)
	torso.add_child(body)
	torso.add_child(Util.mesh(Util.box(Vector3(0.2, 0.16, 0.02)), rust, Vector3(-0.14, 0.66 + y, 0.26)))
	torso.add_child(Util.mesh(Util.box(Vector3(0.16, 0.3, 0.18)), tin.darkened(0.3), Vector3(-0.16, 0.32 + y, 0)))
	torso.add_child(Util.mesh(Util.box(Vector3(0.16, 0.3, 0.18)), tin.darkened(0.3), Vector3(0.16, 0.32 + y, 0)))
	# Arms: one normal, one hanging broken
	torso.add_child(Util.mesh(Util.box(Vector3(0.1, 0.42, 0.1)), tin.darkened(0.2), Vector3(0.38, 0.72 + y, 0.02)))
	var broken := Util.mesh(Util.box(Vector3(0.1, 0.46, 0.1)), tin.darkened(0.2), Vector3(-0.42, 0.6 + y, 0.06))
	broken.rotation.z = -0.5
	torso.add_child(broken)
	# TV-screen head on a neck spring, round ears
	torso.add_child(Util.mesh(Util.box(Vector3(0.08, 0.14, 0.08)), Color(0.3, 0.3, 0.32), Vector3(0, 1.17 + y, 0)))
	head = Node3D.new()
	head.position = Vector3(0, 1.42 + y, 0)
	torso.add_child(head)
	head.add_child(Util.mesh(Util.box(Vector3(0.56, 0.42, 0.4)), tin.lightened(0.1), Vector3.ZERO))
	head.add_child(Util.mesh(Util.box(Vector3(0.44, 0.3, 0.02)), Color(0.05, 0.07, 0.06), Vector3(0, 0, 0.205)))
	head.add_child(Util.mesh(Util.sphere(0.12), tin.darkened(0.15), Vector3(-0.32, 0.08, 0)))
	head.add_child(Util.mesh(Util.sphere(0.12), tin.darkened(0.15), Vector3(0.32, 0.08, 0)))
	var ant := Util.mesh(Util.box(Vector3(0.02, 0.22, 0.02)), Color(0.3, 0.3, 0.32), Vector3(0.12, 0.3, 0))
	ant.rotation.z = randf_range(-0.6, 0.6)
	head.add_child(ant)
	# Screen eyes (unshaded so they glow); color shows his mood
	eye_mat = Util.mat(Color(0.3, 1.0, 0.5), true)
	for ex in [-0.1, 0.1]:
		var eye := MeshInstance3D.new()
		eye.mesh = Util.box(Vector3(0.08, 0.08, 0.02))
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 0.03, 0.22)
		head.add_child(eye)
	# Wind-up key on his back
	key = Node3D.new()
	key.position = Vector3(0, 0.82 + y, -0.3)
	torso.add_child(key)
	key.add_child(Util.mesh(Util.box(Vector3(0.04, 0.04, 0.14)), Color(0.75, 0.62, 0.3), Vector3(0, 0, -0.07)))
	key.add_child(Util.mesh(Util.box(Vector3(0.3, 0.14, 0.03)), Color(0.85, 0.7, 0.3), Vector3(0, 0, -0.15)))

	cone = MeshInstance3D.new()
	cone.mesh = _cone_mesh(SIGHT_RANGE, deg_to_rad(FOV_DEG))
	cone_mat = Util.mat(CONE_CALM, true)
	cone.material_override = cone_mat
	cone.position.y = 0.05
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(cone)

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
		State.WANDER:
			move = _do_wander(delta, sees)
		State.FORAGE:
			_do_forage(delta, sees)
		State.SUSPICIOUS:
			_do_suspicious(delta, sees)
		State.INVESTIGATE:
			move = _do_investigate(delta, sees)
		State.FLEE:
			move = _do_flee(delta, sees)
		State.DROWSY:
			move = _do_drowsy(delta)
		State.SLEEP:
			_do_sleep(delta)

	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	visual.rotation.y = lerp_angle(visual.rotation.y, heading, clamp(turn_speed * delta, 0.0, 1.0))
	_update_indicators(delta)


# --- States

func _do_wander(delta: float, sees: bool) -> Vector3:
	awareness = max(0.0, awareness - CALM_RATE * delta)
	if sees:
		_become_suspicious(true)
		return Vector3.ZERO
	if wait_timer > 0.0:
		# Standing around, glancing in different directions.
		wait_timer -= delta
		turn_timer -= delta
		turn_speed = 3.0
		if scan and turn_timer <= 0.0:
			heading += randf_range(-1.8, 1.8)
			turn_timer = randf_range(0.8, 1.6) * (0.5 if alerted else 1.0)
		if wait_timer <= 0.0:
			_pick_wander_target()
		return Vector3.ZERO
	var to := _flat(wander_target - global_position)
	give_up -= delta
	if to.length() < 0.5 or give_up <= 0.0:
		if randf() < 0.5:
			state = State.FORAGE
			state_timer = randf_range(3.0, 5.0)
		else:
			wait_timer = randf_range(2.0, 4.0)
			turn_timer = 0.5
		return Vector3.ZERO
	_face(wander_target, 4.0)
	return to.normalized() * WANDER_SPEED


func _do_forage(delta: float, sees: bool) -> void:
	awareness = max(0.0, awareness - CALM_RATE * delta)
	if sees:
		_become_suspicious(true)
		return
	if alerted:
		state_timer = 0.0  # no foraging during an alert
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.WANDER
		wait_timer = 1.5
		turn_timer = 0.3


func _do_suspicious(delta: float, sees: bool) -> void:
	if sees:
		awareness += delta / NOTICE_TIME * _closeness_boost() * (1.8 if alerted else 1.0)
		last_seen = player.global_position
		_face(last_seen, 3.0)
		if awareness >= 1.0:
			_start_flee()
	else:
		# Lost you. Go check where you were.
		_start_investigate(last_seen, false)


func _do_investigate(delta: float, sees: bool) -> Vector3:
	if sees:
		_become_suspicious(false)
		return Vector3.ZERO
	awareness = max(0.15, awareness - CALM_RATE * 0.3 * delta)
	if state_timer > 0.0:
		# Startled pause, staring toward the sound.
		state_timer -= delta
		_face(interest_point, 5.0)
		return Vector3.ZERO
	var to := _flat(interest_point - global_position)
	if to.length() > 1.0 and give_up > 0.0:
		give_up -= delta
		_face(interest_point, 4.0)
		return to.normalized() * INVESTIGATE_SPEED
	# Arrived: look around, then give up.
	look_timer -= delta
	turn_timer -= delta
	turn_speed = 3.0
	if turn_timer <= 0.0:
		heading += randf_range(-2.0, 2.0)
		turn_timer = 0.8
	if look_timer <= 0.0:
		state = State.WANDER
		awareness = min(awareness, 0.3)
		wait_timer = 0.0
		_pick_wander_target()
	return Vector3.ZERO


func _do_flee(delta: float, sees: bool) -> Vector3:
	if sees:
		last_seen = player.global_position
	# Running to warn the tribe. Stop him before the countdown runs out.
	warn_timer -= delta
	if warn_timer <= 0.0:
		warn_timer = 0.0
		_blast_off()
		return Vector3.ZERO
	# Panic hops while running.
	hop_timer -= delta
	if hop_timer <= 0.0 and is_on_floor():
		velocity.y = 4.0
		hop_timer = randf_range(0.8, 1.6)
	var away := _flat(global_position - player.global_position).normalized()
	_face(global_position + away, 10.0)
	return away * FLEE_SPEED


## Got away: his janky rocket kicks in and he's gone for good. Everyone else goes on alert.
func _blast_off() -> void:
	state = State.CAUGHT  # out of play
	escaped_for_good = true
	collision_layer = 0
	collision_mask = 0
	alert.text = ""
	cone.visible = false
	Util.noise_ring(get_parent(), global_position, 30.0, Color(1, 0.2, 0.15, 0.9))
	warned_tribe.emit()
	_spark()
	var tw := create_tween()
	tw.tween_property(visual, "position", visual.position + Vector3(randf_range(-2, 2), 18, randf_range(-2, 2)), 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(visual, "rotation:z", randf_range(-4, 4), 1.2)
	tw.tween_callback(queue_free)


## Area alert: sharper eyes, faster to spot you, constantly looking around.
func set_alert(on: bool) -> void:
	alerted = on


func _do_drowsy(delta: float) -> Vector3:
	# Dart's kicking in: staggering around before he drops.
	drowsy_timer -= delta
	if drowsy_timer <= 0.0:
		state = State.SLEEP
		sleep_timer = SLEEP_TIME
		return Vector3.ZERO
	heading += sin(Time.get_ticks_msec() * 0.01) * 2.0 * delta
	turn_speed = 6.0
	return _flat(visual.global_basis.z).normalized() * 0.8


func _do_sleep(delta: float) -> void:
	sleep_timer -= delta
	if sleep_timer <= 0.0:
		awareness = 0.7
		_start_investigate(global_position, true)


## Hit by a tranq dart. Takes a moment to kick in, and he yelps.
func tranq() -> void:
	if state in [State.CAUGHT, State.SLEEP, State.DROWSY]:
		return
	state = State.DROWSY
	drowsy_timer = DROWSY_TIME
	warn_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_hop(3.0)
	Util.noise_ring(get_parent(), global_position, YELP_RADIUS, Color(1, 0.6, 0.2, 0.8))
	get_tree().call_group("gatherers", "hear_noise", global_position, YELP_RADIUS, self)


func _become_suspicious(hop: bool) -> void:
	state = State.SUSPICIOUS
	last_seen = player.global_position
	if hop:
		_hop(3.5)


func _start_investigate(point: Vector3, hop: bool) -> void:
	state = State.INVESTIGATE
	interest_point = point
	state_timer = 0.6
	look_timer = 3.0
	turn_timer = 0.5
	give_up = 8.0
	if hop:
		_hop(3.5)


func _start_flee() -> void:
	state = State.FLEE
	awareness = 1.0
	warn_timer = WARN_TIME
	hop_timer = 0.9
	_hop(6.0)
	# Yell! Nearby cavemen hear it and come check it out.
	Util.noise_ring(get_parent(), global_position, YELL_RADIUS, Color(1, 0.2, 0.15, 0.8))
	get_tree().call_group("gatherers", "hear_noise", global_position, YELL_RADIUS, self)


func _hop(power: float) -> void:
	if is_on_floor():
		velocity.y = power


# --- Senses

## Called whenever something makes a sound.
func hear_noise(pos: Vector3, radius: float, source: Node) -> void:
	if source == self or state in [State.FLEE, State.CAUGHT, State.SUSPICIOUS, State.DROWSY, State.SLEEP]:
		return
	if global_position.distance_to(pos) > radius:
		return
	var was_calm := state == State.WANDER or state == State.FORAGE
	awareness = min(0.95, awareness + HEAR_BUMP)
	_start_investigate(pos, was_calm)


func can_see_player() -> bool:
	if player == null or state == State.SLEEP or state == State.DROWSY:
		return false
	var crouching: bool = player.crouching
	var sight := _sight_range()
	var fov := FORAGE_FOV_DEG if state == State.FORAGE else FOV_DEG
	var eye := global_position + Vector3.UP * 1.45
	var target := player.global_position + Vector3.UP * (0.6 if crouching else 1.2)
	var flat := _flat(target - eye)
	if flat.length() > sight:
		return false
	if flat.length() > 1.2:
		var fwd := _flat(visual.global_basis.z)
		if rad_to_deg(fwd.normalized().angle_to(flat.normalized())) > fov * 0.5:
			return false
	# Rocks and trees block his view
	var q := PhysicsRayQueryParameters3D.create(eye, target, Util.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _sight_range() -> float:
	var sight := SIGHT_RANGE_CROUCH if player.crouching else SIGHT_RANGE
	if state == State.FORAGE:
		sight *= FORAGE_SIGHT
	if alerted:
		sight *= 1.35
	return sight


func is_caught() -> bool:
	return state == State.CAUGHT


func can_be_netted() -> bool:
	return state != State.CAUGHT


func is_asleep() -> bool:
	return state == State.SLEEP


func is_drowsy() -> bool:
	return state == State.DROWSY


func is_warning() -> bool:
	return state == State.FLEE


func catch() -> void:
	state = State.CAUGHT
	collision_layer = 0
	collision_mask = 0
	alert.text = ""
	cone.visible = false
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


# --- Helpers

func _closeness_boost() -> float:
	var dist := global_position.distance_to(player.global_position)
	return lerp(3.0, 1.0, clamp(dist / SIGHT_RANGE, 0.0, 1.0))


func _pick_wander_target() -> void:
	var a := randf() * TAU
	var r := randf_range(2.0, WANDER_RADIUS)
	wander_target = home + Vector3(cos(a) * r, 0, sin(a) * r)
	give_up = 8.0


func _face(point: Vector3, speed: float) -> void:
	var to := _flat(point - global_position)
	if to.length() > 0.01:
		heading = atan2(to.x, to.z)
	turn_speed = speed


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _update_indicators(delta: float) -> void:
	var foraging := state == State.FORAGE
	_jank(delta)
	match state:
		State.WANDER, State.FORAGE:
			cone_mat.albedo_color = CONE_CALM
			alert.text = "..." if foraging else ""
			alert.modulate = Color(0.85, 1, 0.85)
		State.SUSPICIOUS, State.INVESTIGATE:
			cone_mat.albedo_color = CONE_SUSPICIOUS
			alert.text = "?"
			alert.modulate = Color(1, 0.85, 0.2)
		State.FLEE:
			cone_mat.albedo_color = CONE_SPOTTED
			alert.text = "! %d" % ceil(warn_timer)
			alert.modulate = Color(1, 0.3, 0.25)
		State.DROWSY:
			alert.text = "!?"
			alert.modulate = Color(1, 0.6, 0.3)
		State.SLEEP:
			alert.text = "Zzz"
			alert.modulate = Color(0.7, 0.85, 1)
	cone.visible = state != State.SLEEP and state != State.DROWSY
	# "?" grows as he gets closer to spotting you.
	alert.pixel_size = 0.012 * (1.0 + awareness * 0.8) if state != State.FLEE else 0.02
	if state == State.SLEEP:
		alert.pixel_size = 0.01
	# Head down while foraging.
	var lean := 0.7 + sin(Time.get_ticks_msec() * 0.012) * 0.12 if foraging else 0.0
	if state == State.SLEEP:
		lean = -1.45  # flat on his back
	elif state == State.DROWSY:
		lean = -0.35 + sin(Time.get_ticks_msec() * 0.015) * 0.25  # wobbling
	torso.rotation.x = lerp(torso.rotation.x, lean, clamp(10.0 * delta, 0.0, 1.0))
	# The cone shows how far he can actually see you right now.
	var reach := _sight_range() / SIGHT_RANGE
	cone.scale = cone.scale.lerp(Vector3(reach, 1, reach), clamp(8.0 * delta, 0.0, 1.0))
	cone.rotation.y = 0.0


## Broken-robot behavior: wind-up key spins, head twitches, sparks fly, eyes match mood.
func _jank(delta: float) -> void:
	var spin := 8.0 if state == State.FLEE else (0.0 if state == State.SLEEP else 2.0)
	key.rotation.z += spin * delta
	var mood := Color(0.3, 1.0, 0.5)
	match state:
		State.SUSPICIOUS, State.INVESTIGATE:
			mood = Color(1.0, 0.85, 0.1)
		State.FLEE:
			mood = Color(1.0, 0.15, 0.1)
		State.DROWSY:
			mood = Color(1.0, 0.5, 0.1) if randf() < 0.5 else Color(0.2, 0.2, 0.2)
		State.SLEEP:
			mood = Color(0.08, 0.1, 0.12)
	eye_mat.albedo_color = mood
	glitch_timer -= delta
	if glitch_timer <= 0.0 and state != State.SLEEP:
		glitch_timer = randf_range(1.5, 4.0)
		head.rotation = Vector3(randf_range(-0.25, 0.25), randf_range(-0.4, 0.4), randf_range(-0.3, 0.3))
		if randf() < 0.5:
			_spark()
	head.rotation = head.rotation.lerp(Vector3.ZERO, clamp(3.0 * delta, 0.0, 1.0))


func _spark() -> void:
	for i in 3:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3(0.05, 0.05, 0.05))
		sp.material_override = Util.mat(Color(1.0, 0.9, 0.4), true)
		head.add_child(sp)
		sp.position = Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.2, 0.2))
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", sp.position + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.5), randf_range(-0.4, 0.4)), 0.3)
		tw.tween_callback(sp.queue_free)


## A flat fan shape pointing along +Z.
static func _cone_mesh(length: float, angle: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var steps := 14
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
