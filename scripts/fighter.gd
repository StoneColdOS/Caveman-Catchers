extends CharacterBody3D
## Shared rules for every mech (yours and the enemies'): a rifle, armor, rolling,
## crouching, and being shot. Syphon Filter style gunfights at giant scale.
##
## Shots are hitscan from the muzzle with spread. Whatever the bullet reaches
## first gets hit: a mech, a building (chips it, and enough shots bring it down),
## or a prop (knocked flying). Buildings between you and a shooter are cover.

signal killed(by)

const Util := preload("res://scripts/util.gd")
const RigScript := preload("res://scripts/mech_rig.gd")

const SCALE := 3.7               # model meters -> game meters (~10 m tall mech)
const GRAVITY := 30.0
const ROLL_TIME := 0.55
const ROLL_SPEED := 22.0
const SHOT_RANGE := 160.0
const SHOT_NOISE := 70.0          # gunfire is loud
const CENTER := 6.0               # height of a standing mech's center mass
const CROUCH_CENTER := 4.2
const JUMP_SPEED := 14.0
# How close a shot has to land to its aim point to hit that part (meters)
const PART_RADIUS := {"head": 1.0, "arm": 1.1, "leg": 1.4, "body": 99.0}

static var hitstop_enabled := true   # tests switch this off

var max_hp := 16
var hp := 16
var dead := false
var stagger := 0.0
var crouching := false
var roll_t := 0.0
var roll_dir := Vector3.ZERO
var mag_size := 12
var ammo := 12
var reload_t := 0.0
var reload_time := 1.3
var rig: Node3D
var city: Node                   # set by main
var _flash_t := 0.0
var lost_head := false
var lost_arm := false             # gun arm gone: disarmed
var lost_leg := false             # left leg gone at the knee: crawling


func _setup_mech(is_enemy: bool, hp_max: int) -> void:
	max_hp = hp_max
	hp = hp_max
	ammo = mag_size
	rig = Node3D.new()
	rig.set_script(RigScript)
	rig.owner_mech = self
	add_child(rig)
	rig.build(is_enemy)
	rig.scale = Vector3.ONE * SCALE
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.7
	cap.height = 9.4
	shape.shape = cap
	shape.position.y = 4.7
	add_child(shape)


# --- Filled in by player / enemy

func is_aiming() -> bool:
	return false


func is_running() -> bool:
	return false


func aim_direction() -> Vector3:
	return facing()


func is_unaware() -> bool:
	return false


func on_hit_taken(_from: Node, _damage: int) -> void:
	pass


# --- Shared

func facing() -> Vector3:
	var f := rig.global_basis.z
	f.y = 0.0
	return f.normalized()


func center() -> Vector3:
	return global_position + Vector3.UP * (CROUCH_CENTER if crouching else CENTER)


func is_rolling() -> bool:
	return roll_t > 0.0


func can_shoot() -> bool:
	return not dead and not lost_arm and roll_t <= 0.0 and reload_t <= 0.0 and stagger <= 0.0 and ammo > 0


func start_reload() -> void:
	if reload_t <= 0.0 and ammo < mag_size and not dead:
		reload_t = reload_time


func start_roll(dir: Vector3) -> bool:
	if dead or roll_t > 0.0 or stagger > 0.0:
		return false
	roll_dir = Vector3(dir.x, 0, dir.z).normalized()
	if roll_dir.length() < 0.1:
		roll_dir = -facing()
	roll_t = ROLL_TIME
	crouching = false
	return true


## Fires one bullet from the muzzle toward `target_point`, scattered by `spread`
## (meters of wobble at the target). Returns what it hit: a mech, a building or nothing.
func shoot_at(target_point: Vector3, spread: float, damage: int, part := "body") -> Node:
	if not can_shoot():
		return null
	ammo -= 1
	var from: Vector3 = rig.muzzle_world()
	var off := randf() * spread
	var aim := target_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * off
	var part_hit: String = part if off < PART_RADIUS.get(part, 99.0) else "body"
	var dir := (aim - from).normalized()
	var to := from + dir * SHOT_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, Util.LAYER_WORLD | Util.LAYER_PLAYER | Util.LAYER_ENEMY)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	var victim: Node = null
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.collider
		if col.has_method("take_shot"):
			victim = col
			col.take_shot(self, damage, end, part_hit)
		elif city and col.is_in_group("breakable"):
			city.shoot_building(col, end, from)
			victim = col
	if city:
		city.shot_props(from, end)
		city.tracer(from, end, Color(1.0, 0.9, 0.5) if not rig.enemy else Color(1.0, 0.35, 0.3))
		city.impact(end, victim != null and victim.has_method("take_shot"))
	rig.fire_kick()
	get_tree().call_group("enemies", "hear_noise", global_position, SHOT_NOISE, self)
	if ammo <= 0:
		start_reload()
	return victim


## A bullet hit us. Rolling through fire makes you untouchable.
func take_shot(from: Node, damage: int, _at: Vector3, _part := "body") -> void:
	if dead or roll_t > ROLL_TIME * 0.15:
		return
	hp -= damage
	stagger = maxf(stagger, 0.12)
	_flash_t = 0.08
	rig.set_eye(Color(1, 1, 1))
	if hp <= 0:
		die(from)
		return
	on_hit_taken(from, damage)


## A body part got shot off: it flies away for real.
func lose_part(part: String, from: Node) -> void:
	match part:
		"head":
			if lost_head: return
			lost_head = true
		"arm":
			if lost_arm: return
			lost_arm = true
			reload_t = 0.0
		"leg":
			if lost_leg: return
			lost_leg = true
	var rb: RigidBody3D = rig.detach(part)
	if rb and city:
		var away: Vector3 = (global_position - from.global_position).normalized() if from else Vector3.UP
		city._launch(rb, away * 9.0 + Vector3.UP * 10.0)
		city.burst(rb.global_position)
		city.smoke(rb.global_position)


func die(by: Node) -> void:
	if dead:
		return
	dead = true
	hp = 0
	crouching = false
	collision_layer = 0
	rig.set_eye(Color(0.05, 0.05, 0.05))
	get_tree().call_group("enemies", "hear_noise", global_position, 60.0, self)
	if city:
		city.smoke(global_position + Vector3.UP * 7.0)
		city.burst(global_position + Vector3.UP * 6.0)
	_hitstop(0.12)
	killed.emit(by)


## A tiny freeze on big impacts: makes kills land.
func _hitstop(t: float) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = 0.08
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	get_tree().call_group("shakers", "add_shake", t * 6.0)


func _update_mech(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	roll_t = maxf(0.0, roll_t - delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = mag_size
	if _flash_t > 0.0:
		_flash_t -= delta
	rig.animate(delta)
