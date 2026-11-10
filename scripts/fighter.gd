extends CharacterBody3D
## Shared rules for every mech: armor, a katana or a rifle, guarding and parrying,
## rolling, diving, and coming apart. Over-the-top on purpose: every hit sprays oil
## and sparks and stops time for a beat; kills drop into slow motion.
##
## Katana:
##   light  fast slash (combos), 2 damage
##   heavy  big slash, 4 damage, breaks guards
##   guard  blocks slashes from the front and deflects bullets
##   parry  guard just before a slash lands: the attacker reels, wide open (exposed)
## Cutting along a line (Blade Mode) takes off whatever the line passes through.
## Heads and torsos only give way once a mech is weakened (half armor or less)
## or exposed after a parry; until then the armor holds and the blade skids off.

signal killed(by)

const Util := preload("res://scripts/util.gd")
const RigScript := preload("res://scripts/mech_rig.gd")

const SCALE := 3.7
const GRAVITY := 30.0
const ROLL_TIME := 0.5
const ROLL_SPEED := 22.0
const SHOT_RANGE := 160.0
const SHOT_NOISE := 70.0
const CENTER := 6.0
const CROUCH_CENTER := 4.2
const PART_RADIUS := {"head": 1.0, "arm": 1.1, "leg": 1.4, "body": 99.0}

# Sword timing: [windup, strike, recover] in seconds
const SWING_TIMES := {"light": [0.1, 0.11, 0.2], "heavy": [0.34, 0.15, 0.38], "swipe": [0.03, 0.1, 0.16], "big": [0.05, 0.12, 0.26]}
const SWING_DAMAGE := {"light": 2, "heavy": 4, "swipe": 2, "big": 4}
const REACH := 10.5
const PARRY_WINDOW := 0.25
const STAGGER_T := 0.45
const EXPOSED_T := 2.5            # after being parried: wide open to a finishing cut

static var hitstop_enabled := true   # tests switch this off
static var blade_mode_active := false
static var BLADE_SCALE := 0.12

var max_hp := 16
var hp := 16
var dead := false
var stagger := 0.0
var exposed := 0.0
var crouching := false
var roll_t := 0.0
var roll_dir := Vector3.ZERO
var dive_t := 0.0
var mag_size := 12
var ammo := 12
var reload_t := 0.0
var reload_time := 1.3
var weapon := "katana"
var rig: Node3D
var city: Node
var lost := {}                    # part -> true once cut off
var flip := 0.0                   # mid-air front flip progress (0 = none)
var _flash_t := 0.0

var windup_mult := 1.0            # enemies wind up slower (readable tells)
var swing := 0                    # 0 none, 1 windup, 2 strike, 3 recover
var swing_kind := "light"
var swing_angle := 0.0            # direction the blade travels across the front plane
var swing_t := 0.0
var swing_len := 1.0
var swing_hit := false
var guarding := false
var guard_t := 99.0               # time since guard went up (parry window)
var last_result := ""             # what your last cut did (HUD)

var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []


func _setup_mech(is_enemy: bool, hp_max: int, weapon_kind := "katana") -> void:
	max_hp = hp_max
	hp = hp_max
	weapon = weapon_kind
	ammo = mag_size
	rig = Node3D.new()
	rig.set_script(RigScript)
	rig.owner_mech = self
	add_child(rig)
	rig.build(is_enemy, weapon_kind)
	rig.scale = Vector3.ONE * SCALE
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.7
	cap.height = 9.4
	shape.shape = cap
	shape.position.y = 4.7
	add_child(shape)
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.vertex_color_use_as_albedo = true
	_trail.material_override = tm
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	add_child(_trail)


# --- Filled in by player / enemy

func is_aiming() -> bool:
	return false


func is_running() -> bool:
	return false


func is_sprinting() -> bool:
	return false


func in_blade_mode() -> bool:
	return false


func is_ninja_running() -> bool:
	return false


func aim_direction() -> Vector3:
	return facing()


func is_unaware() -> bool:
	return false


func opponents() -> Array:
	return []


func on_hit_taken(_from: Node, _damage: int) -> void:
	pass


# --- Basics

func facing() -> Vector3:
	var f := rig.global_basis.z
	f.y = 0.0
	return f.normalized()


func center() -> Vector3:
	return global_position + Vector3.UP * (CROUCH_CENTER if crouching else CENTER)


func is_rolling() -> bool:
	return roll_t > 0.0


func disarmed() -> bool:
	return lost.has("arm_r") or lost.has("upper")


func legs_lost() -> int:
	return int(lost.has("leg_l")) + int(lost.has("leg_r"))


func weakened() -> bool:
	return hp <= max_hp / 2 or exposed > 0.0


func busy() -> bool:
	return dead or swing != 0 or stagger > 0.0 or roll_t > 0.0 or dive_t > 0.0


func start_roll(dir: Vector3) -> bool:
	if dead or roll_t > 0.0 or stagger > 0.0 or legs_lost() > 0:
		return false
	roll_dir = Vector3(dir.x, 0, dir.z).normalized()
	if roll_dir.length() < 0.1:
		roll_dir = -facing()
	roll_t = ROLL_TIME
	swing = 0
	crouching = false
	return true


# --- Sword

func start_swing(kind: String, angle: float) -> bool:
	if weapon != "katana" or dead or disarmed() or swing == 2 or stagger > 0.0 or roll_t > 0.0:
		return false
	if swing == 1:
		return false
	guarding = false
	swing = 1
	swing_kind = kind
	swing_angle = angle
	swing_len = SWING_TIMES[kind][0] * windup_mult
	swing_t = swing_len
	swing_hit = false
	return true


func _update_swing(delta: float) -> void:
	if swing == 0:
		return
	swing_t -= delta
	match swing:
		1:
			if swing_t <= 0.0:
				swing = 2
				swing_len = SWING_TIMES[swing_kind][1]
				swing_t = swing_len
				_trail_pts.clear()
		2:
			if not swing_hit and swing_t <= swing_len * 0.5:
				swing_hit = true
				_resolve_slash()
			if swing_t <= 0.0 and swing == 2:
				swing = 3
				swing_len = SWING_TIMES[swing_kind][2]
				swing_t = swing_len
		3:
			if swing_t <= 0.0:
				swing = 0


## The blade passes through: hit the nearest opponent in front, cut what's in the way.
func _resolve_slash() -> void:
	var fwd := facing()
	var best: Node = null
	var best_d := REACH
	for o in opponents():
		if o.dead:
			continue
		var to: Vector3 = o.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 3.5 or fwd.dot(to / d) > 0.35):
			best = o
			best_d = d
	if best:
		last_result = best.receive_slash(self, swing_kind, swing_angle)
	if city:
		for r in [5.0, 8.0, REACH]:
			city.cut(global_position + fwd * r + Vector3.UP * 6.0, 2.5, global_position)
	get_tree().call_group("enemies", "hear_noise", global_position, 30.0, self)


## Someone's blade reached us. Returns what happened.
func receive_slash(attacker: Node, kind: String, angle: float) -> String:
	if dead or roll_t > ROLL_TIME * 0.15 or dive_t > 0.0:
		return "miss"
	var to_att: Vector3 = attacker.global_position - global_position
	to_att.y = 0.0
	to_att = to_att.normalized()
	var front := facing().dot(to_att) > 0.3
	var hit_at := center() + to_att * 1.5
	# Both blades landing at once: CLASH. Both bounce off in a shower of sparks.
	if swing == 2 and front:
		swing = 0
		stagger = 0.35
		attacker.recoil()
		_knock(-to_att, 7.0)
		if city:
			city.sparks(hit_at, 34, Color(1, 0.95, 0.65))
		_hitstop(0.12)
		return "clash"
	if guarding and front:
		if guard_t < PARRY_WINDOW:
			attacker.parried(self)
			if city:
				city.sparks(hit_at, 30, Color(1, 0.95, 0.6))
			_hitstop(0.14)
			return "parry"
		if kind == "heavy" or kind == "big":
			guarding = false
			stagger = 0.9
			_knock(-to_att, 10.0)
			if city:
				city.sparks(hit_at, 18, Color(1, 0.8, 0.4))
			_hitstop(0.09)
			on_hit_taken(attacker, 0)
			return "break"
		attacker.recoil()
		if city:
			city.sparks(hit_at, 10, Color(0.85, 0.9, 1.0))
		_hitstop(0.05)
		return "block"
	var dmg: int = SWING_DAMAGE[kind]
	hp -= dmg
	swing = 0
	guarding = false
	var heavy_hit := kind == "heavy" or kind == "big"
	stagger = STAGGER_T * (1.6 if heavy_hit else 1.0)
	_knock(-to_att, 12.0 if heavy_hit else 6.0)
	var spray := Vector3(cos(angle), sin(angle), 0)
	spray = rig.global_basis * spray
	if city:
		city.oil(hit_at, (spray + -to_att * 0.6).normalized(), 18 if heavy_hit else 10)
		city.sparks(hit_at, 10, Color(1, 0.7, 0.3))
	_hitstop(0.09 if heavy_hit else 0.055)
	if hp <= 0:
		# Finished with a normal slash: the blade goes on through
		var part := "upper" if absf(sin(angle)) < 0.5 else ("head" if randf() < 0.5 else "arm_r")
		sever(part, attacker)
		die(attacker)
		return "kill"
	on_hit_taken(attacker, dmg)
	return "hit"


## Our swing got parried: knocked off balance and wide open.
func parried(by: Node) -> void:
	swing = 0
	stagger = 1.2
	exposed = EXPOSED_T
	_knock(-facing(), 6.0)


func recoil() -> void:
	swing = 0
	stagger = 0.3
	_knock(-facing(), 4.0)


## Blade Mode cut: a straight line across our front plane. Everything it passes
## through comes off. axes = [right, up] of the plane, line = point + t * dir (meters).
## Returns a list of what came off (or "armor" if the armor held).
func apply_cut(attacker: Node, point: Vector2, dir: Vector2, axes: Array) -> Array:
	if dead and lost.has("upper"):
		return []
	var origin := center()
	var right: Vector3 = axes[0]
	var up: Vector3 = axes[1]
	dir = dir.normalized()
	var cuts: Array = []
	var parts := {"head": 0.95, "arm_r": 0.75, "arm_l": 0.75, "leg_l": 0.6, "leg_r": 0.6}   # precise: you take what you aim for
	for part in parts:
		if lost.has(part):
			continue
		var w: Vector3 = rig.part_point(part) - origin
		var q := Vector2(w.dot(right), w.dot(up))
		var dist := absf((q - point).cross(dir))
		if dist < parts[part]:
			cuts.append(part)
	# Through the waist (more or less sideways) or straight down the chest: cut in half
	var waist: Vector3 = rig.part_point("waist") - origin
	var wq := Vector2(waist.dot(right), waist.dot(up))
	var chest: Vector3 = rig.part_point("chest") - origin
	var cq := Vector2(chest.dot(right), chest.dot(up))
	if (absf((wq - point).cross(dir)) < 1.1 and absf(dir.y) < 0.7) or (absf((cq - point).cross(dir)) < 0.8 and absf(dir.y) > 0.7):
		cuts.append("upper")
	var fatal := cuts.has("upper") or cuts.has("head")
	var hit_at: Vector3 = origin + right * point.x + up * point.y
	if fatal and not weakened():
		# Armor holds: the blade skids off the head / torso, limbs still go
		cuts.erase("upper")
		cuts.erase("head")
		hp -= 3
		if city:
			city.sparks(hit_at, 16, Color(1, 0.85, 0.5))
		if cuts.is_empty():
			stagger = maxf(stagger, 0.3)
			if hp <= 0:
				sever("upper", attacker)
				die(attacker)
				return ["upper"]
			on_hit_taken(attacker, 3)
			return ["armor"]
	fatal = cuts.has("upper") or cuts.has("head")
	for part in cuts:
		sever(part, attacker)
	if fatal or hp <= 0:
		die(attacker)
	elif not cuts.is_empty():
		stagger = maxf(stagger, 0.6)
		on_hit_taken(attacker, 2)
	return cuts


## Cut a part off for real, with an oil geyser.
func sever(part: String, from: Node) -> void:
	if lost.has(part) or lost.has("upper"):
		return
	lost[part] = true
	if part.begins_with("arm") or part.begins_with("leg"):
		hp -= 2
	if part == "arm_r":
		reload_t = 0.0
		swing = 0
	var rb: RigidBody3D = rig.detach(part)
	if rb and city:
		var away: Vector3 = (global_position - from.global_position).normalized() if from else Vector3.UP
		city._launch(rb, away * 7.0 + Vector3.UP * (12.0 if part == "upper" else 9.0))
		city.oil(rb.global_position, Vector3.UP, 30)
		city.sparks(rb.global_position, 14, Color(1, 0.75, 0.3))
		for st in rig.stumps.slice(-2):
			city.oil_fountain(st, 1.8 if part == "upper" else 1.2)


# --- Guns (gunner mechs)

func can_shoot() -> bool:
	return weapon == "rifle" and not dead and not disarmed() and roll_t <= 0.0 and reload_t <= 0.0 and stagger <= 0.0 and ammo > 0


func start_reload() -> void:
	if reload_t <= 0.0 and ammo < mag_size and not dead:
		reload_t = reload_time


func shoot_at(target_point: Vector3, spread: float, damage: int) -> Node:
	if not can_shoot():
		return null
	ammo -= 1
	var from: Vector3 = rig.muzzle_world()
	var aim := target_point + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf() * spread
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
			col.take_shot(self, damage, end)
		elif city and col.is_in_group("breakable"):
			city.shoot_building(col, end, from)
	if city:
		city.shot_props(from, end)
		city.tracer(from, end, Color(1.0, 0.35, 0.3))
		city.impact(end, victim != null)
	rig.fire_kick()
	get_tree().call_group("enemies", "hear_noise", global_position, SHOT_NOISE, self)
	if ammo <= 0:
		start_reload()
	return victim


## A bullet hit us. Guarding (blade up, facing it) deflects it; rolling dodges it.
func take_shot(from: Node, damage: int, at: Vector3, _part := "body") -> void:
	if dead or roll_t > ROLL_TIME * 0.15 or dive_t > 0.0:
		return
	if guarding and weapon == "katana" and not disarmed():
		var to: Vector3 = from.global_position - global_position
		to.y = 0.0
		if facing().dot(to.normalized()) > 0.3:
			if city:
				city.sparks(at, 6, Color(0.9, 0.95, 1.0))
			last_result = "deflect"
			return
	hp -= damage
	stagger = maxf(stagger, 0.12)
	_flash_t = 0.08
	if city:
		city.oil(at, (at - from.global_position).normalized(), 5)
	if hp <= 0:
		die(from)
		return
	on_hit_taken(from, damage)


func die(by: Node) -> void:
	if dead:
		return
	dead = true
	hp = 0
	swing = 0
	guarding = false
	crouching = false
	collision_layer = 0
	rig.set_eye(Color(0.05, 0.05, 0.05))
	get_tree().call_group("enemies", "hear_noise", global_position, 60.0, self)
	if city:
		city.smoke(global_position + Vector3.UP * 6.0)
		city.oil(global_position + Vector3.UP * 6.0, Vector3.UP, 26)
	slowmo(0.45, 0.2)
	killed.emit(by)


func _knock(dir: Vector3, speed: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


# --- Time effects (shared: hit-stop and slow-mo never fight Blade Mode)

func _hitstop(t: float) -> void:
	slowmo(t, 0.05)
	get_tree().call_group("shakers", "add_shake", t * 6.0)


func slowmo(t: float, scale: float) -> void:
	if not hitstop_enabled or blade_mode_active:
		return
	Engine.time_scale = minf(Engine.time_scale, scale)
	get_tree().create_timer(t, true, false, true).timeout.connect(func():
		Engine.time_scale = BLADE_SCALE if blade_mode_active else 1.0)


func _update_mech(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	exposed = maxf(0.0, exposed - delta)
	roll_t = maxf(0.0, roll_t - delta)
	guard_t += delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = mag_size
	if _flash_t > 0.0:
		_flash_t -= delta
	_update_swing(delta)
	rig.animate(delta)
	_update_trail(delta)


## Glowing ribbon behind the blade during a cut.
func _update_trail(delta: float) -> void:
	for p in _trail_pts:
		p[2] += delta
	while _trail_pts.size() > 0 and _trail_pts[0][2] > 0.16:
		_trail_pts.pop_front()
	if swing == 2 and weapon == "katana":
		var bw: Array = rig.blade_world()
		_trail_pts.append([bw[0], bw[1], 0.0])
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var c := Color(0.75, 0.9, 1.0) if not rig.enemy else Color(1.0, 0.35, 0.3)
	for p in _trail_pts:
		var a := clampf(1.0 - p[2] / 0.16, 0.0, 1.0) * 0.85
		_trail_mesh.surface_set_color(Color(c, a * 0.15))
		_trail_mesh.surface_add_vertex(p[0])
		_trail_mesh.surface_set_color(Color(c, a))
		_trail_mesh.surface_add_vertex(p[1])
	_trail_mesh.surface_end()
