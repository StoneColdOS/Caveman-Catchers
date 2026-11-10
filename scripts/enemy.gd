extends "res://scripts/fighter.gd"
## Enemy mech: dark armor, big layered shoulder plates, a crest blade and a visor bar.
## Its visor shows its mood: cyan = calm, amber = suspicious, red = dueling.
## While winding up a swing the visor flashes the stance color:
##   white = HIGH (big overhead, breaks your guard: dodge it or hit first)
##   red   = MID  (block it)
##   yellow= LOW  (fast; block it or step back)
##   Patrol:     walks the streets between crossings.
##   Suspicious: sees you, "?" grows. Buildings block his view.
##   Investigate: heard something (footsteps, a swing, a building coming down).
##   Duel:       squares up, circles, swings, sometimes guards.
## Catch him from behind before he knows you're there and one cut drops him.

enum State { PATROL, SUSPICIOUS, INVESTIGATE, DUEL }

const MAX_HP := 3
const WALK_SPEED := 4.0
const RUN_SPEED := 9.0           # slower than your run: you can always get away
const SIGHT_RANGE := 55.0
const FOV_DEG := 110.0
const NOTICE_TIME := 1.0
const CALM_RATE := 0.2
const EYE_HEIGHT := 9.0
const LOSE_TIME := 6.0
const DUEL_RANGE := 8.5          # where he likes to stand
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
var attack_cd := 1.2
var react_t := -1.0              # counting down to a guard/dodge reaction
var guard_hold := 0.0
var strafe := 1.0
var strafe_t := 0.0
var backstep_t := 0.0
var frozen := false              # tests freeze him in place
var heading := 0.0
var alert: Label3D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Util.LAYER_ENEMY
	collision_mask = Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_ENEMY
	_setup_fighter(true, MAX_HP)
	player = get_tree().get_first_node_in_group("player")
	heading = randf() * TAU
	rig.rotation.y = heading
	waypoint = global_position
	alert = Label3D.new()
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.font_size = 96
	alert.pixel_size = 0.04
	alert.outline_size = 18
	alert.position.y = 13.0
	alert.no_depth_test = true
	add_child(alert)


func opponents() -> Array:
	return [player] if player else []


func is_unaware() -> bool:
	return state == State.PATROL or state == State.INVESTIGATE


func is_dueling() -> bool:
	return state == State.DUEL and not dead


func is_running() -> bool:
	return state == State.DUEL and Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 1.0


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
			State.DUEL:
				move = _duel(delta, sees)
	if stagger > 0.0 or dead:
		move = Vector3.ZERO
	if crippled:
		move *= 0.5
	var accel := 30.0 if stagger <= 0.0 else 8.0
	velocity.x = move_toward(velocity.x, move.x, accel * delta)
	velocity.z = move_toward(velocity.z, move.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	var pre := velocity
	move_and_slide()
	if city and not dead:
		city.push_props(global_position, 1.8, pre)
	if not dead:
		rig.rotation.y = lerp_angle(rig.rotation.y, heading, clampf(6.0 * delta, 0.0, 1.0))
	_update_fighter(delta)
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
			start_duel()
	else:
		_investigate_at(last_seen)


func _investigate(delta: float, sees: bool) -> Vector3:
	if sees:
		state = State.SUSPICIOUS
		return Vector3.ZERO
	var to := _flat(interest - global_position)
	if to.length() > 4.0:
		_face(interest)
		return to.normalized() * WALK_SPEED * 1.4
	look_timer -= delta
	heading += delta * 0.8
	if look_timer <= 0.0:
		state = State.PATROL
		awareness = minf(awareness, 0.3)
		waypoint = city.nearest_intersection(global_position) if city else global_position
	return Vector3.ZERO


## Squared up: keep at sword range, circle, swing, react to your swings.
func _duel(delta: float, sees: bool) -> Vector3:
	if player.dead:
		guarding = false
		return Vector3.ZERO
	if sees:
		lose_timer = LOSE_TIME
		last_seen = player.global_position
	else:
		lose_timer -= delta
		if lose_timer <= 0.0:
			awareness = 0.6
			guarding = false
			_investigate_at(last_seen)
			return Vector3.ZERO
	var target: Vector3 = player.global_position if sees else last_seen
	var to := _flat(target - global_position)
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	_face(target)
	attack_cd -= delta

	# React to your windup: guard against MID/LOW, back off from a HIGH
	if player.swing == SWING_WINDUP and react_t < 0.0 and swing == SWING_NONE:
		react_t = randf_range(0.15, 0.32)
	if react_t >= 0.0:
		react_t -= delta
		if react_t < 0.0 and player.swing in [SWING_WINDUP, SWING_STRIKE] and dist < REACH + 3.0:
			var ps: int = player.swing_stance
			if ps == Stance.HIGH and randf() < 0.55:
				backstep_t = 0.45
			elif ps != Stance.HIGH and randf() < [0.0, 0.6, 0.35][ps]:
				guarding = true
				guard_hold = 0.35
	if player.swing == SWING_NONE:
		react_t = -1.0
	if guarding:
		guard_hold -= delta
		if guard_hold <= 0.0 and player.swing != SWING_STRIKE:
			guarding = false
		return Vector3.ZERO
	if backstep_t > 0.0:
		backstep_t -= delta
		return -dir * RUN_SPEED * 1.3

	if swing != SWING_NONE:
		return dir * 2.0 if swing == SWING_STRIKE else Vector3.ZERO

	# Attack when in range and ready
	if dist < REACH - 0.5 and attack_cd <= 0.0 and stagger <= 0.0:
		var weights := [0.25, 0.45, 0.3]
		if player.guarding:
			weights = [0.7, 0.15, 0.15]
		var r := randf()
		var s := Stance.LOW
		if r < weights[0]:
			s = Stance.HIGH
		elif r < weights[0] + weights[1]:
			s = Stance.MID
		stance = s
		start_swing()
		attack_cd = randf_range(1.2, 2.4)
		return Vector3.ZERO

	# Footwork: close in, keep distance, circle
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe = -strafe if randf() < 0.5 else strafe
		strafe_t = randf_range(1.0, 2.5)
	var side := Vector3.UP.cross(dir) * strafe
	if dist > DUEL_RANGE + 12.0:
		return dir * RUN_SPEED
	if dist > DUEL_RANGE + 1.0:
		return dir * WALK_SPEED * 1.3 + side * 1.0
	if dist < DUEL_RANGE - 2.5:
		return -dir * WALK_SPEED + side * 1.5
	return side * 2.5


func start_duel() -> void:
	var was := state == State.DUEL
	state = State.DUEL
	awareness = 1.0
	lose_timer = LOSE_TIME
	last_seen = player.global_position
	attack_cd = randf_range(0.8, 1.5)
	if not was:
		Util.noise_ring(get_parent(), global_position, SHOUT, Color(1, 0.2, 0.15, 0.8))
		_make_noise(SHOUT)


func _investigate_at(p: Vector3) -> void:
	state = State.INVESTIGATE
	interest = p
	look_timer = 4.0


func hear_noise(pos: Vector3, radius: float, source: Node) -> void:
	if source == self or dead or state == State.DUEL or state == State.SUSPICIOUS:
		return
	if global_position.distance_to(pos) > radius:
		return
	awareness = minf(0.9, awareness + 0.3)
	_investigate_at(pos)


## Hit by you: whatever he was doing, now he's fighting.
func on_hit_taken(_attacker: Node) -> void:
	if state != State.DUEL:
		start_duel()


func receive_strike(attacker: Node, st: int) -> String:
	var r := super.receive_strike(attacker, st)
	if r == "block" or r == "hit" or r == "break":
		if state != State.DUEL:
			start_duel()
	if attacker.has_method("note_result"):
		attacker.note_result(r)
	return r


# --- Senses

func can_see_player() -> bool:
	if player == null or player.dead:
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target: Vector3 = player.global_position + Vector3.UP * 6.0
	var flat := _flat(target - eye)
	if flat.length() > SIGHT_RANGE:
		return false
	if flat.length() > 6.0:
		var fwd := facing()
		if rad_to_deg(fwd.angle_to(flat.normalized())) > FOV_DEG * 0.5:
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
		State.DUEL:
			c = Color(1.0, 0.15, 0.1)
	if swing == SWING_WINDUP and Time.get_ticks_msec() % 160 < 100:
		c = [Color(1, 1, 1), Color(1, 0.1, 0.1), Color(1, 0.9, 0.1)][swing_stance]
	if dead:
		c = Color(0.05, 0.05, 0.05)
		alert.text = ""
	rig.set_eye(c)
	alert.pixel_size = 0.04 * (1.0 + awareness)
