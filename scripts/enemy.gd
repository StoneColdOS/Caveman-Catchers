extends "res://scripts/fighter.gd"
## Enemy mechs, two kinds:
##   GUNNER    crimson with gold trim, rifle. Keeps its distance and fires 3-round
##             bursts, each one warned by a red laser sight first. Guard deflects
##             the bullets; rolling or diving dodges them. Close in and cut it apart.
##   SWORDSMAN black with red trim, katana. Squares up, circles, and swings. Every
##             swing is telegraphed: the visor flashes and the blade draws back
##             (longer for a heavy). Guards your quick slashes sometimes; heavies
##             break his guard. Parry him and he's wide open.
## Both: visor cyan = calm, amber = suspicious, red = fighting, blue = weakened
## (head and torso can now be cut through in Blade Mode).
## Lose an arm and he can't use his weapon (he charges and slams instead).
## Lose a leg and he limps; lose both and he's stuck where he is.

enum State { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT }

const MAX_HP := 16
const WALK_SPEED := 4.0
const RUN_SPEED := 9.0
const SIGHT_RANGE := 70.0
const FOV_DEG := 110.0
const NOTICE_TIME := 1.0
const CALM_RATE := 0.2
const EYE_HEIGHT := 9.0
const LOSE_TIME := 6.0
const SHOUT := 80.0
# Gunner
const FAR := 48.0
const NEAR := 20.0
const LASER_TIME := 0.75
const BURST := 3
const BURST_GAP := 0.14
const SHOT_DAMAGE := 1
# Swordsman
const DUEL_RANGE := 8.0
const SLAM_WINDUP := 0.7
const SLAM_RANGE := 10.0
const SLAM_DAMAGE := 3

var kind := "gunner"              # set before adding to the tree
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
var attack_cd := 1.2
var guard_hold := 0.0
var react_t := -1.0
var strafe := 1.0
var strafe_t := 0.0
var slam_t := 0.0
var slam_cd := 1.0
var frozen := false
var heading := 0.0
var alert: Label3D
var laser: MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Util.LAYER_ENEMY
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_ENEMY
	_setup_mech(true, MAX_HP, "rifle" if kind == "gunner" else "katana")
	windup_mult = 3.6   # his light swing winds up ~0.36 s, heavy ~1.2 s: time to read it
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


func opponents() -> Array:
	return [player] if player else []


func is_unaware() -> bool:
	return state == State.PATROL or state == State.INVESTIGATE


func is_fighting() -> bool:
	return state == State.COMBAT and not dead


func is_aiming() -> bool:
	return kind == "gunner" and (laser_t > 0.0 or burst_left > 0) and not dead and not disarmed()


func is_bashing() -> bool:
	return slam_t > 0.0


func is_running() -> bool:
	return Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 1.0


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
	if stagger > 0.0 or dead or swing == 2:
		move *= 0.2
	if swing == 2:
		move = facing() * 8.0          # step into his own cut
	var ll := legs_lost()
	if ll == 1:
		move *= 0.35
	elif ll >= 2:
		move = Vector3.ZERO
	if roll_t > 0.0 and not dead:
		move = roll_dir * ROLL_SPEED * 0.85
	velocity.x = move_toward(velocity.x, move.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 30.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var pre := velocity
	move_and_slide()
	if city and not dead:
		city.push_props(global_position, 1.8, pre)
	if not dead and swing != 2:
		rig.rotation.y = lerp_angle(rig.rotation.y, heading, clampf(6.0 * delta, 0.0, 1.0))
	_update_mech(delta)
	_update_look()


# --- Awareness

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


# --- Combat

func _combat(delta: float, sees: bool) -> Vector3:
	if player.dead:
		laser_t = 0.0
		burst_left = 0
		guarding = false
		return Vector3.ZERO
	if sees:
		lose_timer = LOSE_TIME
		last_seen = player.global_position
	else:
		lose_timer -= delta
		if lose_timer <= 0.0:
			awareness = 0.6
			laser_t = 0.0
			guarding = false
			_investigate_at(last_seen)
			return Vector3.ZERO
	var to := _flat(last_seen - global_position)
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	if swing == 0:
		_face(last_seen)
	if disarmed():
		return _brawl(delta, dist, dir)
	if kind == "gunner":
		return _gunner(delta, sees, dist, dir)
	return _swordsman(delta, sees, dist, dir)


## Rifle: hold a firing distance, strafe, laser-sight you, then burst.
func _gunner(delta: float, sees: bool, dist: float, dir: Vector3) -> Vector3:
	if burst_left > 0:
		burst_t -= delta
		if burst_t <= 0.0:
			if can_shoot():
				var pv: Vector3 = player.velocity
				shoot_at(player.center(), 1.0 + Vector2(pv.x, pv.z).length() * 0.4, SHOT_DAMAGE)
			burst_left -= 1
			burst_t = BURST_GAP
		return Vector3.ZERO
	if laser_t > 0.0:
		laser_t -= delta
		if not sees:
			laser_t = 0.0
		elif laser_t <= 0.0:
			burst_left = BURST
			burst_t = 0.0
		return Vector3.ZERO
	fire_cd -= delta
	if sees and fire_cd <= 0.0 and reload_t <= 0.0 and stagger <= 0.0:
		laser_t = LASER_TIME
		fire_cd = randf_range(1.6, 2.8)
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe if randf() < 0.5 else strafe
		strafe_t = randf_range(1.0, 2.2)
	var side := Vector3.UP.cross(dir) * strafe
	if not sees or dist > FAR:
		return dir * RUN_SPEED
	if dist < NEAR:
		return -dir * RUN_SPEED * 0.8 + side * 3.0   # you're too close: back off
	return side * 4.0


## Katana: circle at sword range, swing with a clear tell, guard some of your cuts.
func _swordsman(delta: float, sees: bool, dist: float, dir: Vector3) -> Vector3:
	attack_cd -= delta
	# React to your swings: guard (blocks quick slashes; a heavy smashes through)
	if player.swing == 1 and react_t < 0.0 and swing == 0 and stagger <= 0.0:
		react_t = randf_range(0.05, 0.18)
	if react_t >= 0.0:
		react_t -= delta
		if react_t < 0.0 and player.swing in [1, 2] and dist < REACH + 3.0 and randf() < 0.45:
			guarding = true
			guard_t = 99.0
			guard_hold = 0.5
	if player.swing == 0:
		react_t = -1.0
	if guarding:
		guard_hold -= delta
		if guard_hold <= 0.0:
			guarding = false
			attack_cd = minf(attack_cd, 0.15)   # quick counter after a block
		return Vector3.ZERO
	if swing != 0 or stagger > 0.0:
		return Vector3.ZERO
	if sees and dist < REACH - 0.5 and attack_cd <= 0.0:
		var heavy := randf() < 0.3
		var ang := randf_range(-PI, PI) if not heavy else -PI / 2.0 + randf_range(-0.6, 0.6)
		if start_swing("heavy" if heavy else "light", ang):
			attack_cd = randf_range(0.9, 1.8)
		return Vector3.ZERO
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe if randf() < 0.5 else strafe
		strafe_t = randf_range(0.8, 1.8)
	var side := Vector3.UP.cross(dir) * strafe
	if dist > DUEL_RANGE + 10.0:
		return dir * RUN_SPEED
	if dist > DUEL_RANGE + 1.0:
		return dir * WALK_SPEED * 1.5 + side * 1.5
	if dist < DUEL_RANGE - 2.5:
		return -dir * WALK_SPEED + side * 2.0
	return side * 3.5


## No weapon arm: charge in and slam with what's left. Telegraphed (visor flashes white).
func _brawl(delta: float, dist: float, dir: Vector3) -> Vector3:
	laser_t = 0.0
	burst_left = 0
	guarding = false
	slam_cd -= delta
	if slam_t > 0.0:
		slam_t -= delta
		if slam_t <= 0.0:
			var to_p := _flat(player.global_position - global_position)
			if to_p.length() < SLAM_RANGE and facing().dot(to_p.normalized()) > 0.3:
				var r: String = player.receive_slash(self, "heavy", 0.0)
				if r == "hit" and city:
					city.impact(player.center(), true)
			slam_cd = 1.5
			return dir * 14.0
		return Vector3.ZERO
	if dist < SLAM_RANGE - 2.0 and slam_cd <= 0.0:
		slam_t = SLAM_WINDUP
		return Vector3.ZERO
	return dir * RUN_SPEED * 1.1


func start_combat() -> void:
	var was := state == State.COMBAT
	state = State.COMBAT
	awareness = 1.0
	lose_timer = LOSE_TIME
	last_seen = player.global_position
	if not was:
		fire_cd = randf_range(0.5, 1.2)
		attack_cd = randf_range(0.6, 1.2)
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


func on_hit_taken(_from: Node, _damage: int) -> void:
	laser_t = 0.0
	burst_left = 0
	if state != State.COMBAT:
		start_combat()


## Cut from behind before he knew you were there: the armor doesn't matter.
func receive_slash(attacker: Node, kind_: String, angle: float) -> String:
	if is_unaware() and not dead:
		var to_att: Vector3 = attacker.global_position - global_position
		to_att.y = 0.0
		if facing().dot(to_att.normalized()) < -0.2:
			exposed = EXPOSED_T     # caught cold
	return super.receive_slash(attacker, kind_, angle)


func can_see_player() -> bool:
	if player == null or player.dead:
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target: Vector3 = player.center()
	var flat := _flat(target - eye)
	var sight := SIGHT_RANGE * (0.5 if player.crouching else 1.0)
	if flat.length() > sight:
		return false
	if flat.length() > 6.0:
		if rad_to_deg(facing().angle_to(flat.normalized())) > FOV_DEG * 0.5:
			return false
	if city:
		return city.clear_line(eye, target)
	return true


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
	if weakened() and not dead:
		c = Color(0.2, 0.5, 1.0) if Time.get_ticks_msec() % 500 < 330 else Color(0.6, 0.85, 1.0)
	if (swing == 1 or slam_t > 0.0) and Time.get_ticks_msec() % 140 < 90:
		c = Color(1, 1, 1)        # about to strike
	if dead:
		c = Color(0.05, 0.05, 0.05)
		alert.text = ""
	if not lost.has("head") and not lost.has("upper"):
		rig.set_eye(c)
	alert.pixel_size = 0.04 * (1.0 + awareness)
	laser.visible = laser_t > 0.0 and not dead and Time.get_ticks_msec() % 120 < 90
	if laser.visible:
		var a: Vector3 = rig.muzzle_world()
		var b: Vector3 = player.center()
		laser.global_position = (a + b) * 0.5
		laser.look_at(b, Vector3.UP)
		laser.scale = Vector3(1, 1, a.distance_to(b))
