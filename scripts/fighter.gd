extends CharacterBody3D
## Shared sword-fighting rules for the player mech and enemy mechs (Bushido Blade style:
## few hits, every swing telegraphed, positioning matters).
##
## Three stances:
##   HIGH  slow overhead chop. 3 damage. Smashes through a guard (guard break).
##   MID   horizontal sweep. 2 damage. Blocked by guard.
##   LOW   fast rising cut. 1 damage and cripples a leg (half speed). Blocked by guard.
## Getting hit cancels your own swing, so a fast LOW beats a slow HIGH.
## Two strikes landing together clash: sparks, both bounce off.
## Hit someone unaware from behind and it's over in one cut.

signal killed(by)

const Util := preload("res://scripts/util.gd")
const RigScript := preload("res://scripts/mech_rig.gd")

enum Stance { HIGH, MID, LOW }
const SWING_NONE := 0
const SWING_WINDUP := 1
const SWING_STRIKE := 2
const SWING_RECOVER := 3

const SCALE := 3.7                       # model meters -> game meters (~10 m tall mech)
const WINDUP_T := [0.7, 0.42, 0.28]      # per stance
const STRIKE_T := 0.14
const RECOVER_T := [0.55, 0.4, 0.32]
const DAMAGE := [3, 2, 1]
const REACH := 10.0                      # blade reach from your center
const STAGGER_T := 0.9                   # after a guard break or a hit
const RECOIL_T := 0.45                   # your swing got blocked
const SWING_NOISE := 30.0
const GRAVITY := 30.0

static var hitstop_enabled := true       # tests switch this off

var stance: int = Stance.MID
var swing := SWING_NONE
var swing_stance: int = Stance.MID
var swing_t := 0.0
var swing_len := 1.0
var swing_hit := false
var guarding := false
var max_hp := 3
var hp := 3
var crippled := false
var stagger := 0.0
var dead := false
var rig: Node3D
var city: Node                           # set by main: buildings to cut through
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_pts: Array = []               # [base, tip, age]


func _setup_fighter(is_enemy: bool, hp_max: int) -> void:
	max_hp = hp_max
	hp = hp_max
	rig = Node3D.new()
	rig.set_script(RigScript)
	rig.fighter = self
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


# --- To be filled in by player / enemy

func opponents() -> Array:
	return []


func is_unaware() -> bool:
	return false


func is_running() -> bool:
	return false


func on_hit_taken(_attacker: Node) -> void:
	pass


# --- Swinging

func can_act() -> bool:
	return not dead and swing == SWING_NONE and stagger <= 0.0


func set_stance(s: int) -> void:
	if not dead and swing == SWING_NONE:
		stance = s


func start_swing() -> bool:
	if not can_act():
		return false
	guarding = false
	swing = SWING_WINDUP
	swing_stance = stance
	swing_len = WINDUP_T[stance] * (1.35 if crippled else 1.0)
	swing_t = swing_len
	return true


## Pull out of a windup (a feint). Only before the blade starts moving.
func cancel_windup() -> void:
	if swing == SWING_WINDUP:
		swing = SWING_NONE


func facing() -> Vector3:
	var f := rig.global_basis.z
	f.y = 0.0
	return f.normalized()


func _update_fighter(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	if swing != SWING_NONE:
		swing_t -= delta
		match swing:
			SWING_WINDUP:
				if swing_t <= 0.0:
					swing = SWING_STRIKE
					swing_len = STRIKE_T
					swing_t = STRIKE_T
					swing_hit = false
					_trail_pts.clear()
			SWING_STRIKE:
				if not swing_hit and swing_t <= STRIKE_T * 0.5:
					swing_hit = true
					_resolve_strike()
				if swing_t <= 0.0 and swing == SWING_STRIKE:
					swing = SWING_RECOVER
					swing_len = RECOVER_T[swing_stance]
					swing_t = swing_len
			SWING_RECOVER:
				if swing_t <= 0.0:
					swing = SWING_NONE
	rig.animate(delta)
	_update_trail(delta)


## The blade lands: hit the nearest opponent in front, and cut through buildings.
func _resolve_strike() -> void:
	var fwd := facing()
	var best: Node = null
	var best_d := REACH
	for o in opponents():
		if o.dead:
			continue
		var to: Vector3 = o.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 3.5 or fwd.dot(to / d) > 0.4):
			best = o
			best_d = d
	if best:
		best.receive_strike(self, swing_stance)
	_make_noise(SWING_NOISE)
	if city:
		var h: float = [8.5, 6.0, 3.0][swing_stance]
		for r in [5.0, 8.0, REACH]:
			city.cut(global_position + fwd * r + Vector3.UP * h, 2.5, global_position)
			if swing_stance == Stance.MID:
				var side := Vector3.UP.cross(fwd)
				city.cut(global_position + (fwd + side * 0.7).normalized() * r + Vector3.UP * h, 2.5, global_position)


## Someone's blade reached us. Returns what happened: clash, block, break, hit, kill.
func receive_strike(attacker: Node, st: int) -> String:
	if dead:
		return "none"
	var to_att: Vector3 = attacker.global_position - global_position
	to_att.y = 0.0
	to_att = to_att.normalized()
	var front := facing().dot(to_att)
	# Both blades moving at once: clash
	if swing == SWING_STRIKE and front > 0.3:
		swing = SWING_NONE
		stagger = RECOIL_T
		attacker.recoil()
		_sparks(Color(1, 0.9, 0.5), 12)
		_hitstop(0.09)
		return "clash"
	# Caught from behind while not expecting it: one clean cut
	if is_unaware() and front < -0.2:
		_sparks(Color(1, 0.6, 0.3), 16)
		_hitstop(0.18)
		die(attacker)
		return "backstab"
	if guarding and front > 0.3:
		if st == Stance.HIGH:
			guarding = false
			stagger = STAGGER_T
			_knock(-to_att, 6.0)
			_sparks(Color(1, 0.8, 0.4), 10)
			_hitstop(0.08)
			on_hit_taken(attacker)
			return "break"
		attacker.recoil()
		_sparks(Color(0.8, 0.9, 1.0), 8)
		_hitstop(0.05)
		return "block"
	hp -= DAMAGE[st]
	swing = SWING_NONE        # interrupted
	guarding = false
	if st == Stance.LOW:
		crippled = true
	_knock(-to_att, 8.0)
	_sparks(Color(1, 0.55, 0.2), 14)
	_hitstop(0.12)
	if hp <= 0:
		die(attacker)
		return "kill"
	stagger = 0.5
	on_hit_taken(attacker)
	return "hit"


func recoil() -> void:
	swing = SWING_NONE
	stagger = RECOIL_T
	_knock(-facing(), 5.0)


func die(by: Node) -> void:
	if dead:
		return
	dead = true
	hp = 0
	swing = SWING_NONE
	guarding = false
	collision_layer = 0
	rig.set_eye(Color(0.05, 0.05, 0.05))
	_make_noise(60.0)
	_sparks(Color(1, 0.5, 0.1), 24)
	if city:
		city.smoke(global_position + Vector3.UP * 7.0)
	killed.emit(by)


func _knock(dir: Vector3, speed: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _make_noise(radius: float) -> void:
	get_tree().call_group("enemies", "hear_noise", global_position, radius, self)


## A tiny freeze on impact: makes hits feel heavy instead of mushy.
func _hitstop(t: float) -> void:
	if not hitstop_enabled:
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(t, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	get_tree().call_group("shakers", "add_shake", t * 8.0)


func _sparks(color: Color, n: int) -> void:
	var at: Vector3 = rig.blade_world()[1] if swing != SWING_NONE else global_position + Vector3.UP * 7.0
	var parent := get_parent()
	if parent == null:
		return
	for i in n:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3(0.35, 0.35, 0.35))
		sp.material_override = Util.mat(color, true)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(sp)
		sp.global_position = at
		var tw := sp.create_tween()
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)).normalized()
		tw.tween_property(sp, "global_position", at + dir * randf_range(2.0, 5.0), 0.3)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * 0.1, 0.3)
		tw.tween_callback(sp.queue_free)


## Glowing ribbon behind the blade tip during a strike.
func _update_trail(delta: float) -> void:
	for p in _trail_pts:
		p[2] += delta
	while _trail_pts.size() > 0 and _trail_pts[0][2] > 0.18:
		_trail_pts.pop_front()
	if swing == SWING_STRIKE:
		var bw: Array = rig.blade_world()
		_trail_pts.append([bw[0], bw[1], 0.0])
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var c := Color(0.9, 0.95, 1.0) if not rig.enemy else Color(1.0, 0.4, 0.45)
	for p in _trail_pts:
		var a := clampf(1.0 - p[2] / 0.18, 0.0, 1.0) * 0.8
		_trail_mesh.surface_set_color(Color(c, a * 0.2))
		_trail_mesh.surface_add_vertex(p[0])
		_trail_mesh.surface_set_color(Color(c, a))
		_trail_mesh.surface_add_vertex(p[1])
	_trail_mesh.surface_end()
