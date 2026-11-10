extends "res://scripts/fighter.gd"
## Enemy mech: crimson with gold trim, horned shoulders, a crest, a visor bar.
## Visor: cyan = calm, amber = suspicious, red = fighting.
##   Patrol:      walks the streets between crossings.
##   Suspicious:  sees you, "?" grows. Buildings block his view.
##   Investigate: heard something (footsteps, gunfire, a building coming down).
##   Combat:      keeps his distance, strafes, and fires 3-round bursts.
##                Every burst is telegraphed by a red laser sight on you first:
##                roll, get behind a building, or keep moving to make him miss.
## Unaware and caught by a full lock: one shot drops him.

enum State { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT }

const MAX_HP := 16
const WALK_SPEED := 4.0
const RUN_SPEED := 8.0
const SIGHT_RANGE := 70.0
const FOV_DEG := 110.0
const NOTICE_TIME := 1.0
const CALM_RATE := 0.2
const EYE_HEIGHT := 9.0
const LOSE_TIME := 6.0
const FAR := 48.0
const NEAR := 22.0
const LASER_TIME := 0.75         # warning before each burst
const BURST := 3
const BURST_GAP := 0.14
const SHOT_DAMAGE := 1
const SHOUT := 80.0

var state := State.PATROL
var awareness := 0.0
var player: Node
var waypoint := Vector3.ZERO
var interest := Vector3.ZERO
var last_seen := Vector3.ZERO
var lose_timer := 0.0
var look_timer := 0.0
var wait_timer := 0.0
var fire_cd := 1.5
var laser_t := 0.0
var burst_left := 0
var burst_t := 0.0
var strafe := 1.0
var strafe_t := 0.0
var frozen := false              # tests freeze him in place
var heading := 0.0
var alert: Label3D
var laser: MeshInstance3D
var bar: MeshInstance3D
var bar_fill: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Util.LAYER_ENEMY
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_ENEMY
	_setup_mech(true, MAX_HP)
	mag_size = 30
	ammo = mag_size
	player = get_tree().get_first_node_in_group("player")
	heading = randf() * TAU
	rig.rotation.y = heading
	waypoint = global_position
	alert = Label3D.new()
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.font_size = 96
	alert.pixel_size = 0.04
	alert.outline_size = 18
	alert.position.y = 13.5
	alert.no_depth_test = true
	add_child(alert)
	laser = Util.glow(Util.box(Vector3(0.12, 0.12, 1.0)), Color(1.0, 0.1, 0.1))
	laser.top_level = true
	laser.visible = false
	add_child(laser)
	# Health bar over his head (shows once he's been hit)
	bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.0, 0.5)
	bar.mesh = q
	var bm := Util.mat(Color(0, 0, 0, 0.6))
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.no_depth_test = true
	bar.material_override = bm
	bar.position.y = 12.0
	bar.visible = false
	add_child(bar)
	bar_fill = MeshInstance3D.new()
	var qf := QuadMesh.new()
	qf.size = Vector2(4.8, 0.36)
	bar_fill.mesh = qf
	var fm := Util.mat(Color(1.0, 0.3, 0.2), true)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.no_depth_test = true
	fm.render_priority = 1
	bar_fill.material_override = fm
	bar_fill.position.y = 12.0
	bar_fill.visible = false
	add_child(bar_fill)


func is_unaware() -> bool:
	return state == State.PATROL or state == State.INVESTIGATE


func is_fighting() -> bool:
	return state == State.COMBAT and not dead


func is_aiming() -> bool:
	return (laser_t > 0.0 or burst_left > 0) and not dead


func is_running() -> bool:
	return Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 1.0 and not is_aiming()


func aim_direction() -> Vector3:
	if player:
		return (player.center() - center()).normalized()
	return facing()


func _physics_process(delta: float) -> void:
	var move := Vector3.ZERO
	if not dead and not frozen:
		var sees := can_see_player()
		match state:
			State.PATROL:
				move = _patrol(delta, sees)
			State.SUSPICIOUS:
				_suspicious(delta, sees)
			State.INVESTIGATE:
				move = _investigate(delta, sees)
			State.COMBAT:
				move = _combat(delta, sees)
	if stagger > 0.0 or dead:
		move *= 0.3
	velocity.x = move_toward(velocity.x, move.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 30.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var pre := velocity
	move_and_slide()
	if city and not dead:
		city.push_props(global_position, 1.8, pre)
	if not dead:
		rig.rotation.y = lerp_angle(rig.rotation.y, heading, clampf(6.0 * delta, 0.0, 1.0))
	_update_mech(delta)
	_update_look()


# --- States

func _patrol(delta: float, sees: bool) -> Vector3:
	awareness = maxf(0.0, awareness - CALM_RATE * delta)
	if sees:
		state = State.SUSPICIOUS
		return Vector3.ZERO
	if wait_timer > 0.0:
		wait_timer -= delta
		return Vector3.ZERO
	var to := _flat(waypoint - global_position)
	if to.length() < 2.0:
		var nb: Array = city.neighbors(city.nearest_intersection(global_position)) if city else []
		if nb.is_empty():
			wait_timer = 3.0
			return Vector3.ZERO
		waypoint = nb[randi() % nb.size()]
		wait_timer = randf_range(1.0, 3.0)
		return Vector3.ZERO
	_face(waypoint)
	return to.normalized() * WALK_SPEED


func _suspicious(delta: float, sees: bool) -> void:
	if sees:
		var d := global_position.distance_to(player.global_position)
		awareness += delta / NOTICE_TIME * lerp(3.0, 1.0, clampf(d / SIGHT_RANGE, 0.0, 1.0))
		last_seen = player.global_position
		_face(last_seen)
		if awareness >= 1.0:
			start_combat()
	else:
		_investigate_at(last_seen)


func _investigate(delta: float, sees: bool) -> Vector3:
	if sees:
		state = State.SUSPICIOUS
		return Vector3.ZERO
	var to := _flat(interest - global_position)
	if to.length() > 4.0:
		_face(interest)
		return to.normalized() * WALK_SPEED * 1.5
	look_timer -= delta
	heading += delta * 0.8
	if look_timer <= 0.0:
		state = State.PATROL
		awareness = minf(awareness, 0.3)
		waypoint = city.nearest_intersection(global_position) if city else global_position
	return Vector3.ZERO


## Fighting: hold a firing distance, strafe, laser-sight you, then burst.
func _combat(delta: float, sees: bool) -> Vector3:
	if player.dead:
		laser_t = 0.0
		burst_left = 0
		return Vector3.ZERO
	if sees:
		lose_timer = LOSE_TIME
		last_seen = player.global_position
	else:
		lose_timer -= delta
		if lose_timer <= 0.0:
			awareness = 0.6
			laser_t = 0.0
			_investigate_at(last_seen)
			return Vector3.ZERO
	var to := _flat(last_seen - global_position)
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	_face(last_seen)

	# Shooting: laser warning, then a 3-round burst
	if burst_left > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			_fire_once()
			burst_left -= 1
			burst_t = BURST_GAP
		return Vector3.ZERO
	if laser_t > 0.0:
		laser_t -= delta
		if not sees:
			laser_t = 0.0  # lost his shot
		elif laser_t <= 0.0:
			burst_left = BURST
			burst_t = 0.0
		return _flat(Vector3.UP.cross(dir)) * strafe * 1.5
	fire_cd -= delta
	if sees and fire_cd <= 0.0 and reload_t <= 0.0 and stagger <= 0.0:
		laser_t = LASER_TIME
		fire_cd = randf_range(1.6, 2.8)

	# Footwork: close in if far, back off if close, strafe otherwise
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe if randf() < 0.5 else strafe
		strafe_t = randf_range(1.2, 2.8)
	var side := Vector3.UP.cross(dir) * strafe
	if not sees or dist > FAR:
		return dir * RUN_SPEED
	if dist < NEAR:
		return -dir * WALK_SPEED + side * 2.0
	return side * 3.5


## One bullet at you. Harder to hit you when you're moving fast; rolling dodges.
func _fire_once() -> void:
	if not can_shoot():
		return
	var pv: Vector3 = player.velocity
	var spread := 1.0 + Vector2(pv.x, pv.z).length() * 0.45
	shoot_at(player.center(), spread, SHOT_DAMAGE)


func start_combat() -> void:
	var was := state == State.COMBAT
	state = State.COMBAT
	awareness = 1.0
	lose_timer = LOSE_TIME
	last_seen = player.global_position
	if not was:
		fire_cd = randf_range(0.5, 1.2)
		Util.noise_ring(get_parent(), global_position, SHOUT, Color(1, 0.2, 0.15, 0.8))
		get_tree().call_group("enemies", "hear_noise", global_position, SHOUT, self)


func _investigate_at(p: Vector3) -> void:
	state = State.INVESTIGATE
	interest = p
	look_timer = 4.0


func hear_noise(pos: Vector3, radius: float, source: Node) -> void:
	if source == self or dead or state == State.COMBAT or state == State.SUSPICIOUS:
		return
	if global_position.distance_to(pos) > radius:
		return
	awareness = minf(0.9, awareness + 0.3)
	_investigate_at(pos)


## Shot: whatever he was doing, now he's fighting (if he survived).
func on_hit_taken(_from: Node, _damage: int) -> void:
	if state != State.COMBAT:
		start_combat()
	laser_t = minf(laser_t, 0.0) if randf() < 0.3 else laser_t  # sometimes flinches off his shot


# --- Senses

func can_see_player() -> bool:
	if player == null or player.dead:
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target: Vector3 = player.center()
	var flat := _flat(target - eye)
	var sight := SIGHT_RANGE * (0.6 if player.crouching else 1.0)
	if flat.length() > sight:
		return false
	if flat.length() > 6.0:
		if rad_to_deg(facing().angle_to(flat.normalized())) > FOV_DEG * 0.5:
			return false
	if city:
		return city.clear_line(eye, target)
	return true


# --- Helpers

func _face(p: Vector3) -> void:
	var to := _flat(p - global_position)
	if to.length() > 0.1:
		heading = atan2(to.x, to.z)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _update_look() -> void:
	var c := Color(0.3, 0.9, 1.0)
	alert.text = ""
	match state:
		State.SUSPICIOUS, State.INVESTIGATE:
			c = Color(1.0, 0.7, 0.15)
			alert.text = "?"
			alert.modulate = Color(1, 0.85, 0.2)
		State.COMBAT:
			c = Color(1.0, 0.15, 0.1)
	if dead:
		c = Color(0.05, 0.05, 0.05)
		alert.text = ""
	if _flash_t <= 0.0:
		rig.set_eye(c)
	alert.pixel_size = 0.04 * (1.0 + awareness)
	# Laser sight from his muzzle to you while he lines up a burst
	laser.visible = laser_t > 0.0 and not dead and Time.get_ticks_msec() % 120 < 90
	if laser.visible:
		var a: Vector3 = rig.muzzle_world()
		var b: Vector3 = player.center()
		var len := a.distance_to(b)
		laser.global_position = (a + b) * 0.5
		laser.look_at(b, Vector3.UP)
		laser.scale = Vector3(1, 1, len)
	# Health bar
	var show := hp < max_hp and not dead
	bar.visible = show
	bar_fill.visible = show
	if show:
		var f := float(hp) / max_hp
		bar_fill.scale.x = f
