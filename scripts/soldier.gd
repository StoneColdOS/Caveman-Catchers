extends CharacterBody3D
## A lanky enemy soldier on night patrol. Winter coat, dark vest, gas mask, a helmet
## lamp that shows his mood (pale = calm, amber = suspicious, red = fighting) and a
## shock baton for wrecking mech joints.
##   Patrol:      walks his beat, stops to look around.
##   Distracted:  checks his radio, head down (half blind). Your window.
##   Hears noise: "?", walks over to check it out, looks around.
##   Sees you:    stares while his "?" grows. Lose him and he checks where you were.
##   Spotted:     shouts (nearby soldiers hear it) and comes at you with the baton.
##                Telegraphed overhead swings. Back off or punch him first.
##   Held:        dangling from your fist, kicking. Tap GRAB to put him out.
##   Down:        out cold in the snow ("zz"). Stays down.

enum State { PATROL, DISTRACTED, SUSPICIOUS, INVESTIGATE, FIGHT, HELD, THROWN, DOWN }

const Util := preload("res://scripts/util.gd")

const PATROL_SPEED := 1.5
const INVESTIGATE_SPEED := 2.2
const FIGHT_SPEED := 3.6         # slower than your run: you can always back off
const WANDER_RADIUS := 8.0
const SIGHT_RANGE := 12.0
const SIGHT_RANGE_CROUCH := 5.0
const DISTRACTED_SIGHT := 0.4    # head down: sees 40% as far
const FOV_DEG := 120.0
const DISTRACTED_FOV_DEG := 70.0
const NOTICE_TIME := 0.8         # seconds in view (at max range) to spot you; faster up close
const CALM_RATE := 0.25
const HEAR_BUMP := 0.3
const FIGHT_LOSE := 5.0          # out of sight this long and he goes back to searching
const SHOUT_RADIUS := 12.0
const EYE_HEIGHT := 1.75
const MAX_HP := 3
const STRIKE_RANGE := 2.3
const SWING_DISTANCE := 1.7      # how close he gets before swinging
const WINDUP := 0.55             # baton raised: your cue to back off or hit first
const STAGGER_TIME := 0.8
const GRAVITY := 20.0

const CONE_CALM := Color(0.2, 1.0, 0.45, 0.12)    # faint: the night stays dark
const CONE_SUSPICIOUS := Color(1.0, 0.85, 0.1, 0.22)
const CONE_SPOTTED := Color(1.0, 0.15, 0.1, 0.25)

var state := State.PATROL
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
var lose_timer := 0.0
var heading := 0.0
var turn_speed := 4.0
var hp := MAX_HP
var windup := 0.0
var swing_cooldown := 0.0
var swing_t := 0.0               # follow-through after a swing
var stagger := 0.0
var kick := Vector3.ZERO         # knockback
var hold_progress := 0.0
var walk_phase := 0.0
var player: Node3D
var visual: Node3D
var root: Node3D
var chest: Node3D
var head: Node3D
var hips: Array = []
var knees: Array = []
var shoulders: Array = []
var elbows: Array = []
var lamp_mat: StandardMaterial3D
var tip_mat: StandardMaterial3D
var cone: MeshInstance3D
var cone_mat: StandardMaterial3D
var alert: Label3D


func _ready() -> void:
	add_to_group("soldiers")
	collision_layer = Util.LAYER_CAVEMAN
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_CAVEMAN
	home = global_position
	player = get_tree().get_first_node_in_group("player")

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.9
	shape.shape = cap
	shape.position.y = 0.95
	add_child(shape)

	_build_visual()
	_pick_wander_target()
	heading = randf() * TAU
	visual.rotation.y = heading


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	root = Node3D.new()
	visual.add_child(root)
	var coats := [Color(0.6, 0.62, 0.64), Color(0.55, 0.57, 0.56), Color(0.64, 0.64, 0.6)]
	var coat: Color = coats[randi() % coats.size()]   # winter camo greys
	var vest := Color(0.2, 0.23, 0.2)
	var dark := Color(0.08, 0.08, 0.09)
	var helmet_c := Color(0.4, 0.43, 0.38)

	root.add_child(Util.mesh(Util.box(Vector3(0.32, 0.18, 0.2)), coat.darkened(0.15), Vector3(0, 1.0, 0)))  # pelvis
	# Long thin legs: hip pivot -> thigh -> knee pivot -> shin -> boot
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0.98, 0)
		root.add_child(hip)
		hip.add_child(Util.mesh(Util.box(Vector3(0.12, 0.5, 0.13)), coat.darkened(0.1), Vector3(0, -0.24, 0)))
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.48, 0)
		hip.add_child(knee)
		knee.add_child(Util.mesh(Util.box(Vector3(0.1, 0.46, 0.11)), coat.darkened(0.1), Vector3(0, -0.22, 0)))
		knee.add_child(Util.mesh(Util.box(Vector3(0.12, 0.12, 0.24)), dark, Vector3(0, -0.46, 0.04)))  # boot
		hips.append(hip)
		knees.append(knee)

	# Upper body leans and staggers as one piece
	chest = Node3D.new()
	chest.position = Vector3(0, 1.04, 0)
	root.add_child(chest)
	chest.add_child(Util.mesh(Util.box(Vector3(0.36, 0.56, 0.2)), coat, Vector3(0, 0.28, 0)))
	chest.add_child(Util.mesh(Util.box(Vector3(0.4, 0.36, 0.26)), vest, Vector3(0, 0.34, 0)))
	for px in [-0.11, 0.0, 0.11]:
		chest.add_child(Util.mesh(Util.box(Vector3(0.09, 0.11, 0.06)), vest.lightened(0.08), Vector3(px, 0.24, 0.15)))  # pouches
	chest.add_child(Util.mesh(Util.box(Vector3(0.26, 0.3, 0.12)), vest.darkened(0.2), Vector3(0, 0.36, -0.18)))  # radio pack
	chest.add_child(Util.mesh(Util.box(Vector3(0.015, 0.3, 0.015)), dark, Vector3(0.09, 0.66, -0.2), false))      # radio aerial
	chest.add_child(Util.mesh(Util.box(Vector3(0.08, 0.1, 0.08)), coat.darkened(0.2), Vector3(0, 0.6, 0)))        # neck

	# Head: helmet, gas mask, lamp on the brow
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	chest.add_child(head)
	var skull := Util.mesh(Util.box(Vector3(0.2, 0.22, 0.22)), dark, Vector3(0, 0.0, 0.01))
	head.add_child(skull)
	var helmet := Util.mesh(Util.sphere(0.15), helmet_c, Vector3(0, 0.08, -0.005))
	helmet.scale = Vector3(1.05, 0.7, 1.12)
	head.add_child(helmet)
	head.add_child(Util.mesh(Util.box(Vector3(0.24, 0.03, 0.27)), helmet_c.darkened(0.15), Vector3(0, 0.04, 0.0)))  # rim
	head.add_child(Util.mesh(Util.box(Vector3(0.14, 0.06, 0.03)), Color(0.25, 0.3, 0.3), Vector3(0, 0.0, 0.12), false))  # mask lenses
	var can := CylinderMesh.new()
	can.top_radius = 0.045
	can.bottom_radius = 0.05
	can.height = 0.08
	can.radial_segments = 6
	var filter := Util.mesh(can, Color(0.18, 0.2, 0.18), Vector3(0, -0.08, 0.13))
	filter.rotation.x = PI / 2.0
	head.add_child(filter)
	lamp_mat = Util.mat(Color(0.9, 0.95, 1.0), true)
	var lamp := MeshInstance3D.new()
	lamp.mesh = Util.box(Vector3(0.07, 0.05, 0.04))
	lamp.material_override = lamp_mat
	lamp.position = Vector3(0, 0.1, 0.16)
	head.add_child(lamp)

	# Long arms: shoulder pivot -> upper arm -> elbow pivot -> forearm -> hand.
	tip_mat = Util.mat(Color(0.35, 0.7, 1.0), true)
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.23 * side, 0.52, 0)
		chest.add_child(sh)
		sh.add_child(Util.mesh(Util.box(Vector3(0.09, 0.38, 0.1)), coat, Vector3(0, -0.18, 0)))
		var el := Node3D.new()
		el.position = Vector3(0, -0.37, 0)
		sh.add_child(el)
		el.add_child(Util.mesh(Util.box(Vector3(0.08, 0.36, 0.09)), coat.darkened(0.05), Vector3(0, -0.17, 0)))
		el.add_child(Util.mesh(Util.box(Vector3(0.08, 0.08, 0.08)), dark, Vector3(0, -0.37, 0)))  # glove
		if side > 0.0:
			# Shock baton, held pointing forward, with a glowing tip
			el.add_child(Util.mesh(Util.box(Vector3(0.035, 0.035, 0.6)), dark, Vector3(0, -0.37, 0.24)))
			var tip := MeshInstance3D.new()
			tip.mesh = Util.box(Vector3(0.06, 0.06, 0.08))
			tip.material_override = tip_mat
			tip.position = Vector3(0, -0.37, 0.56)
			el.add_child(tip)
		shoulders.append(sh)
		elbows.append(el)

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
	alert.position.y = 2.5
	alert.no_depth_test = true
	add_child(alert)


func _physics_process(delta: float) -> void:
	if state == State.HELD:
		_update_indicators(delta)  # the mech moves us; we just kick
		_animate(delta)
		return
	var sees := can_see_player()
	var move := Vector3.ZERO
	match state:
		State.PATROL:
			move = _do_patrol(delta, sees)
		State.DISTRACTED:
			_do_distracted(delta, sees)
		State.SUSPICIOUS:
			_do_suspicious(delta, sees)
		State.INVESTIGATE:
			move = _do_investigate(delta, sees)
		State.FIGHT:
			move = _do_fight(delta, sees)
		State.THROWN:
			_do_thrown(delta)

	kick = kick.move_toward(Vector3.ZERO, 14.0 * delta)
	if state != State.THROWN:
		velocity.x = move.x + kick.x
		velocity.z = move.z + kick.z
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	visual.rotation.y = lerp_angle(visual.rotation.y, heading, clamp(turn_speed * delta, 0.0, 1.0))
	_update_indicators(delta)
	_animate(delta)


# --- States

func _do_patrol(delta: float, sees: bool) -> Vector3:
	awareness = max(0.0, awareness - CALM_RATE * delta)
	if sees:
		_become_suspicious()
		return Vector3.ZERO
	if wait_timer > 0.0:
		# Standing around, glancing in different directions.
		wait_timer -= delta
		turn_timer -= delta
		turn_speed = 3.0
		if scan and turn_timer <= 0.0:
			heading += randf_range(-1.8, 1.8)
			turn_timer = randf_range(0.8, 1.6)
		if wait_timer <= 0.0:
			_pick_wander_target()
		return Vector3.ZERO
	var to := _flat(wander_target - global_position)
	give_up -= delta
	if to.length() < 0.5 or give_up <= 0.0:
		if randf() < 0.5:
			state = State.DISTRACTED
			state_timer = randf_range(3.0, 5.0)
		else:
			wait_timer = randf_range(2.0, 4.0)
			turn_timer = 0.5
		return Vector3.ZERO
	_face(wander_target, 4.0)
	return to.normalized() * PATROL_SPEED


func _do_distracted(delta: float, sees: bool) -> void:
	awareness = max(0.0, awareness - CALM_RATE * delta)
	if sees:
		_become_suspicious()
		return
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.PATROL
		wait_timer = 1.5
		turn_timer = 0.3


func _do_suspicious(delta: float, sees: bool) -> void:
	if sees:
		awareness += delta / NOTICE_TIME * _closeness_boost()
		last_seen = player.global_position
		_face(last_seen, 3.0)
		if awareness >= 1.0:
			_start_fight()
	else:
		_start_investigate(last_seen)


func _do_investigate(delta: float, sees: bool) -> Vector3:
	if sees:
		_become_suspicious()
		return Vector3.ZERO
	awareness = max(0.15, awareness - CALM_RATE * 0.3 * delta)
	if state_timer > 0.0:
		state_timer -= delta
		_face(interest_point, 5.0)
		return Vector3.ZERO
	var to := _flat(interest_point - global_position)
	if to.length() > 1.0 and give_up > 0.0:
		give_up -= delta
		_face(interest_point, 4.0)
		return to.normalized() * INVESTIGATE_SPEED
	look_timer -= delta
	turn_timer -= delta
	turn_speed = 3.0
	if turn_timer <= 0.0:
		heading += randf_range(-2.0, 2.0)
		turn_timer = 0.8
	if look_timer <= 0.0:
		state = State.PATROL
		awareness = min(awareness, 0.3)
		wait_timer = 0.0
		_pick_wander_target()
	return Vector3.ZERO


## Spotted you: close in and swing. Every swing is telegraphed by raising the baton.
func _do_fight(delta: float, sees: bool) -> Vector3:
	if player.dead:
		windup = 0.0
		_face(player.global_position, 4.0)
		return Vector3.ZERO
	if sees:
		lose_timer = FIGHT_LOSE
		last_seen = player.global_position
	else:
		lose_timer -= delta
		if lose_timer <= 0.0:
			awareness = 0.6
			windup = 0.0
			_start_investigate(last_seen)
			return Vector3.ZERO
	swing_cooldown -= delta
	swing_t = maxf(0.0, swing_t - delta)
	if stagger > 0.0:
		stagger -= delta
		windup = 0.0
		return Vector3.ZERO
	var to := _flat(last_seen - global_position)
	var dist := to.length()
	if windup > 0.0:
		windup -= delta
		_face(player.global_position, 6.0)
		if windup <= 0.0:
			_swing()
		return Vector3.ZERO
	if sees and dist < SWING_DISTANCE + 0.2 and swing_cooldown <= 0.0:
		windup = WINDUP
		return Vector3.ZERO
	_face(last_seen, 8.0)
	if dist > SWING_DISTANCE - 0.2:
		return to.normalized() * FIGHT_SPEED
	return Vector3.ZERO


func _swing() -> void:
	swing_t = 0.25
	swing_cooldown = randf_range(1.1, 1.7)
	var to := _flat(player.global_position - global_position)
	var fwd := _flat(visual.global_basis.z).normalized()
	if to.length() < STRIKE_RANGE and (to.length() < 0.9 or fwd.dot(to.normalized()) > 0.3):
		player.take_hit(global_position, 1)
		_zap()


func _do_thrown(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0 and is_on_floor():
		velocity = Vector3.ZERO
		if hp <= 0:
			knock_out()
		else:
			state = State.FIGHT
			stagger = STAGGER_TIME
			lose_timer = FIGHT_LOSE


func _become_suspicious() -> void:
	state = State.SUSPICIOUS
	last_seen = player.global_position


func _start_investigate(point: Vector3) -> void:
	state = State.INVESTIGATE
	interest_point = point
	state_timer = 0.6
	look_timer = 3.0
	turn_timer = 0.5
	give_up = 8.0


func _start_fight() -> void:
	var was_fighting := state == State.FIGHT
	state = State.FIGHT
	awareness = 1.0
	lose_timer = FIGHT_LOSE
	last_seen = player.global_position
	swing_cooldown = 0.4
	if not was_fighting:
		# Shout! Nearby soldiers hear it and come check it out.
		Util.noise_ring(get_parent(), global_position, SHOUT_RADIUS, Color(1, 0.2, 0.15, 0.8))
		get_tree().call_group("soldiers", "hear_noise", global_position, SHOUT_RADIUS, self)


# --- Getting hit

## Punched by the mech: staggers back. Three punches and he's out.
func take_punch(dir: Vector3) -> void:
	if not can_be_hit():
		return
	hp -= 1
	kick = dir * 6.0
	windup = 0.0
	if hp <= 0:
		knock_out()
		return
	if state != State.FIGHT:
		_start_fight()
	stagger = STAGGER_TIME


## Grabbed while staggered and thrown. Heavy damage.
func thrown(dir: Vector3) -> void:
	hp -= 2
	state = State.THROWN
	state_timer = 0.35
	windup = 0.0
	velocity = dir * 7.0 + Vector3.UP * 5.0
	kick = Vector3.ZERO


## Lifted off his feet in the mech's fist.
func enter_hold() -> void:
	state = State.HELD
	hold_progress = 0.0
	velocity = Vector3.ZERO
	collision_mask = Util.LAYER_WORLD
	collision_layer = 0


func squeeze(progress: float) -> void:
	hold_progress = progress
	head.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.3, 0.3))


## You stopped squeezing: he twists free, and now he's angry.
func break_free() -> void:
	collision_layer = Util.LAYER_CAVEMAN
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_CAVEMAN
	state = State.SUSPICIOUS
	kick = _flat(global_position - player.global_position).normalized() * 3.0
	_start_fight()
	stagger = 0.3


## Out cold. Drops where he is (or where he's set down) and stays there.
func knock_out(drop_at = null) -> void:
	if state == State.DOWN:
		return
	state = State.DOWN
	collision_layer = 0
	collision_mask = Util.LAYER_WORLD
	windup = 0.0
	if drop_at != null:
		global_position = drop_at
	velocity = Vector3.ZERO
	kick = Vector3.ZERO
	cone.visible = false
	if player and player.has_method("on_subdued"):
		player.on_subdued()


func _zap() -> void:
	for i in 5:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3(0.05, 0.05, 0.05))
		sp.material_override = tip_mat
		elbows[1].add_child(sp)
		sp.position = Vector3(0, -0.37, 0.56)
		var tw := sp.create_tween()
		tw.tween_property(sp, "position", sp.position + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4), randf_range(0.0, 0.5)), 0.2)
		tw.tween_callback(sp.queue_free)


# --- Senses

func hear_noise(pos: Vector3, radius: float, source: Node) -> void:
	if source == self or state in [State.FIGHT, State.SUSPICIOUS, State.HELD, State.THROWN, State.DOWN]:
		return
	if global_position.distance_to(pos) > radius:
		return
	awareness = min(0.95, awareness + HEAR_BUMP)
	_start_investigate(pos)


func can_see_player() -> bool:
	if player == null or state in [State.HELD, State.THROWN, State.DOWN]:
		return false
	var sight := _sight_range()
	var fov := DISTRACTED_FOV_DEG if state == State.DISTRACTED else FOV_DEG
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := player.global_position + Vector3.UP * (1.2 if player.crouching else 2.0)
	var flat := _flat(target - eye)
	if flat.length() > sight:
		return false
	if flat.length() > 1.2:
		var fwd := _flat(visual.global_basis.z)
		if rad_to_deg(fwd.normalized().angle_to(flat.normalized())) > fov * 0.5:
			return false
	# Rocks, containers and trees block his view
	var q := PhysicsRayQueryParameters3D.create(eye, target, Util.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _sight_range() -> float:
	var sight := SIGHT_RANGE_CROUCH if player.crouching else SIGHT_RANGE
	if state == State.DISTRACTED:
		sight *= DISTRACTED_SIGHT
	if not player.is_lit():
		sight *= player.DARK_SIGHT  # hard to see you in the dark
	return sight


func can_be_hit() -> bool:
	return state != State.HELD and state != State.DOWN and state != State.THROWN


func is_down() -> bool:
	return state == State.DOWN


func is_held() -> bool:
	return state == State.HELD


func is_fighting() -> bool:
	return state == State.FIGHT


func is_staggered() -> bool:
	return state == State.FIGHT and stagger > 0.0


func is_winding_up() -> bool:
	return windup > 0.0


## Was he already on to you when you grabbed him? (Wary soldiers take longer to put out.)
func is_alert() -> bool:
	return state == State.SUSPICIOUS or state == State.INVESTIGATE


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
	var mood := Color(0.9, 0.95, 1.0)
	match state:
		State.PATROL, State.DISTRACTED:
			cone_mat.albedo_color = CONE_CALM
			alert.text = "..." if state == State.DISTRACTED else ""
			alert.modulate = Color(0.85, 1, 0.85)
		State.SUSPICIOUS, State.INVESTIGATE:
			cone_mat.albedo_color = CONE_SUSPICIOUS
			alert.text = "?"
			alert.modulate = Color(1, 0.85, 0.2)
			mood = Color(1.0, 0.7, 0.15)
		State.FIGHT, State.THROWN:
			cone_mat.albedo_color = CONE_SPOTTED
			alert.text = "!"
			alert.modulate = Color(1, 0.3, 0.25)
			mood = Color(1.0, 0.15, 0.1)
		State.HELD:
			alert.text = "!!"
			alert.modulate = Color(1, 0.55, 0.2)
			mood = Color(1.0, 0.4, 0.1) * (1.0 - hold_progress * 0.8)
		State.DOWN:
			alert.text = "zz"
			alert.modulate = Color(0.7, 0.85, 1)
			mood = Color(0.08, 0.08, 0.08)
	lamp_mat.albedo_color = mood
	# Baton tip charges up white-hot while he winds up a swing
	tip_mat.albedo_color = Color(0.95, 0.98, 1.0) if windup > 0.0 and fmod(windup, 0.12) < 0.07 else Color(0.35, 0.7, 1.0)
	cone.visible = state in [State.PATROL, State.DISTRACTED, State.SUSPICIOUS, State.INVESTIGATE, State.FIGHT]
	alert.pixel_size = 0.012 * (1.0 + awareness * 0.8) if state != State.FIGHT else 0.02
	if state == State.DOWN:
		alert.pixel_size = 0.008
	# The cone shows how far he can actually see you right now.
	var reach := _sight_range() / SIGHT_RANGE
	cone.scale = cone.scale.lerp(Vector3(reach, 1, reach), clamp(8.0 * delta, 0.0, 1.0))


## Stiff, lanky movement: long strides, baton held out, big overhead swings.
func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var hs := Vector2(velocity.x, velocity.z).length()
	walk_phase += hs * delta * 3.2
	var moving := hs > 0.2 and state != State.HELD
	var hip_x := [0.0, 0.0]
	var knee_x := [0.0, 0.0]
	var sh_x := [0.0, 0.0]
	var sh_z := [0.15, -0.15]
	var el_x := [-0.15, -0.5]       # baton arm held a little forward
	var lean := 0.0
	var head_x := 0.0
	var lie := 0.0
	var lift := 0.0
	if moving:
		for i in 2:
			var ph := walk_phase + (PI if i == 1 else 0.0)
			hip_x[i] = -sin(ph) * 0.5
			knee_x[i] = maxf(0.0, sin(ph + 1.2)) * 0.9
		sh_x[0] = sin(walk_phase) * 0.45
		sh_x[1] = -sin(walk_phase) * 0.2
		lift = absf(sin(walk_phase)) * 0.03
	match state:
		State.DISTRACTED:
			sh_x[0] = -1.5   # radio up to his mask
			el_x[0] = -1.7
			head_x = 0.45
			lean = 0.15
		State.SUSPICIOUS, State.INVESTIGATE:
			sh_x[1] = -0.6
			el_x[1] = -0.7
		State.FIGHT:
			sh_x = [-0.7, -0.9]       # guard up, baton forward
			el_x = [-1.3, -0.6]
			lean = 0.15
			if moving:
				sh_x[0] += sin(walk_phase) * 0.2
			if windup > 0.0:
				sh_x[1] = -2.9        # baton raised overhead
				el_x[1] = -0.5
				lean = -0.15
			elif swing_t > 0.0:
				sh_x[1] = -0.4        # slammed down
				el_x[1] = -0.2
				lean = 0.4
			if stagger > 0.0:
				lean = -0.45
				sh_z = [0.9, -0.9]
				sh_x = [-0.3, -0.3]
				head_x = -0.4
		State.THROWN:
			lean = -0.6
			sh_z = [1.4, -1.4]
			hip_x = [-0.8, 0.4]
		State.HELD:
			var fight := 1.0 - hold_progress
			hip_x = [sin(t * 16.0) * 0.7 * fight, -sin(t * 16.0) * 0.7 * fight]
			knee_x = [0.6, 0.6]
			sh_x = [-2.2, -2.2]     # clawing at the mech's fist
			el_x = [-0.8 + sin(t * 20.0) * 0.4 * fight, -0.8 - sin(t * 20.0) * 0.4 * fight]
			head_x = -0.3 + hold_progress * 0.8
		State.DOWN:
			lie = -PI / 2.0
			sh_z = [0.5, -0.5]
			sh_x = [0.0, 0.0]
			el_x = [0.0, 0.0]
	var k := clampf(14.0 * delta, 0.0, 1.0)
	var fast := clampf((40.0 if swing_t > 0.0 else 14.0) * delta, 0.0, 1.0)
	for i in 2:
		hips[i].rotation.x = lerp_angle(hips[i].rotation.x, hip_x[i], k)
		knees[i].rotation.x = lerp_angle(knees[i].rotation.x, knee_x[i], k)
		shoulders[i].rotation.x = lerp_angle(shoulders[i].rotation.x, sh_x[i], fast if i == 1 else k)
		shoulders[i].rotation.z = lerp_angle(shoulders[i].rotation.z, sh_z[i], k)
		elbows[i].rotation.x = lerp_angle(elbows[i].rotation.x, el_x[i], k)
	chest.rotation.x = lerp_angle(chest.rotation.x, lean, k)
	head.rotation.x = lerp_angle(head.rotation.x, head_x, k)
	head.rotation.y = lerp_angle(head.rotation.y, 0.0, k)
	head.rotation.z = lerp_angle(head.rotation.z, 0.0, k)
	root.position.y = lerp(root.position.y, lift + (0.15 if lie != 0.0 else 0.0), k)
	visual.rotation.x = lerp_angle(visual.rotation.x, lie, clampf(6.0 * delta, 0.0, 1.0))


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
