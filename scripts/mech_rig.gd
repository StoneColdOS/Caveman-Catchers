extends Node3D
## A humanoid mech body: built in "model meters" (about 2.7 tall), scaled up ~3.7x
## by the owner to ~10 m. Lanky but human: forward knees, broad chest, neck, visor head.
## Carries a rifle in both hands. The pose comes from the owner's state:
## a big Syphon Filter run (rifle raised in one hand, the other arm pumping),
## shoulder it while locked on (upper body twists toward the target while the
## legs run anywhere), jump, crouch-walk, combat roll, reload, collapse.
## Head, gun arm and left leg can be shot off: the real pieces fly away.

const Util := preload("res://scripts/util.gd")

const HIP_HEIGHT := 1.3
const LEG_UPPER := 0.64
const LEG_LOWER := 0.66
const ARM_UPPER := 0.55
const ARM_LOWER := 0.58
const SHOULDER := Vector3(0.44, 2.08, 0.0)
const GUN_LEN := 0.95

var owner_mech: Node             # the CharacterBody that owns us (reads its state)
var enemy := false
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var walk_phase := 0.0
var legs: Array = []
var feet: Array = []
var arms: Array = []
var hands: Array = []
var gun: Node3D
var muzzle: Node3D
var flash: MeshInstance3D
var eye_mat: StandardMaterial3D
var grip := Vector3(0.25, 1.55, 0.3)
var gun_dir := Vector3(0, -0.3, 1).normalized()
var recoil := 0.0
var step_signal := 0.0           # >0 on the frame a foot lands
var _last_lift := [0.0, 0.0]
var gait := 0.0                  # 0 = standing, ~0.4 = jog, 1 = full sprint (smoothed)
var bank := 0.0                  # leaning into turns
var _last_yaw := 0.0
const RUN_MODEL_SPEED := 13.0 / 3.7   # model meters per second at full sprint


func build(is_enemy: bool) -> void:
	enemy = is_enemy
	var hull := Color(0.6, 0.58, 0.5) if not enemy else Color(0.5, 0.15, 0.14)
	var frame := Color(0.15, 0.15, 0.16) if not enemy else Color(0.1, 0.08, 0.08)
	var accent := Color(0.75, 0.3, 0.1) if not enemy else Color(0.85, 0.68, 0.25)
	var eye_c := Color(1.0, 0.2, 0.12) if not enemy else Color(0.3, 0.9, 1.0)

	body_root = Node3D.new()
	add_child(body_root)
	# Pelvis, waist and hip armor
	body_root.add_child(Util.mesh(Util.box(Vector3(0.44, 0.24, 0.3)), frame, Vector3(0, HIP_HEIGHT, 0)))
	for side in [-1.0, 1.0]:
		var skirt := Util.mesh(Util.box(Vector3(0.22, 0.32, 0.07)), hull.darkened(0.08), Vector3(0.18 * side, HIP_HEIGHT - 0.1, 0.17))
		skirt.rotation.x = -0.2
		body_root.add_child(skirt)
		var side_plate := Util.mesh(Util.box(Vector3(0.07, 0.3, 0.26)), hull.darkened(0.08), Vector3(0.25 * side, HIP_HEIGHT - 0.1, 0))
		side_plate.rotation.z = 0.15 * side
		body_root.add_child(side_plate)
	body_root.add_child(Util.mesh(Util.box(Vector3(0.3, 0.3, 0.24)), frame, Vector3(0, HIP_HEIGHT + 0.27, 0)))  # waist
	body_root.add_child(Util.mesh(Util.box(Vector3(0.36, 0.08, 0.28)), hull, Vector3(0, HIP_HEIGHT + 0.36, 0)))
	# Broad chest with vents and a slanted collar
	body_root.add_child(Util.mesh(Util.box(Vector3(0.72, 0.5, 0.44)), hull, Vector3(0, 1.9, 0)))
	var collar := Util.mesh(Util.box(Vector3(0.6, 0.14, 0.4)), hull.lightened(0.06), Vector3(0, 2.16, 0.02))
	body_root.add_child(collar)
	var plate := Util.mesh(Util.box(Vector3(0.56, 0.3, 0.08)), hull.lightened(0.08), Vector3(0, 1.88, 0.24))
	plate.rotation.x = -0.15
	body_root.add_child(plate)
	for i in 3:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.12, 0.025, 0.02)), frame, Vector3(0.18, 1.82 + i * 0.05, 0.285)))
		body_root.add_child(Util.mesh(Util.box(Vector3(0.12, 0.025, 0.02)), frame, Vector3(-0.18, 1.82 + i * 0.05, 0.285)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.05, 0.28, 0.02)), accent, Vector3(0, 1.86, 0.29)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.5, 0.46, 0.22)), hull.darkened(0.15), Vector3(0, 1.94, -0.32)))  # backpack
	for side in [-1.0, 1.0]:
		var thruster := CylinderMesh.new()
		thruster.top_radius = 0.06
		thruster.bottom_radius = 0.09
		thruster.height = 0.18
		thruster.radial_segments = 6
		body_root.add_child(Util.mesh(thruster, frame, Vector3(0.15 * side, 1.66, -0.38)))
		# Shoulder armor: blocky, layered
		var pad := Util.mesh(Util.box(Vector3(0.3, 0.26, 0.38)), hull.darkened(0.04), SHOULDER * Vector3(side, 1, 1) + Vector3(0.06 * side, 0.08, 0))
		pad.rotation.z = -0.25 * side
		body_root.add_child(pad)
		body_root.add_child(Util.mesh(Util.box(Vector3(0.31, 0.05, 0.39)), accent, SHOULDER * Vector3(side, 1, 1) + Vector3(0.09 * side, -0.04, 0)))
		if enemy:
			var horn := Util.mesh(Util.box(Vector3(0.05, 0.22, 0.05)), accent, SHOULDER * Vector3(side, 1, 1) + Vector3(0.1 * side, 0.3, -0.05))
			horn.rotation.z = -0.3 * side
			body_root.add_child(horn)

	# Head on a neck: helmet with a visor
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 2.2, 0.03)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.11, 0.14, 0.11)), frame, Vector3(0, 0.05, 0)))
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.24, 0.24, 0.27)), hull, Vector3(0, 0.22, 0.02)))
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.2, 0.08, 0.06)), frame, Vector3(0, 0.12, 0.15)))  # chin/mouth guard
	eye_mat = Util.mat(eye_c, true)
	var eye := MeshInstance3D.new()
	eye.mesh = Util.box(Vector3(0.2, 0.045, 0.02) if enemy else Vector3(0.17, 0.04, 0.02))
	eye.material_override = eye_mat
	eye.position = Vector3(0, 0.23, 0.16)
	head_pivot.add_child(eye)
	if enemy:
		var crest := Util.mesh(Util.box(Vector3(0.03, 0.08, 0.36)), accent, Vector3(0, 0.37, -0.04))
		crest.rotation.x = 0.3
		head_pivot.add_child(crest)
	else:
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.015, 0.34, 0.015)), frame, Vector3(-0.1, 0.45, -0.06)))  # antenna
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.05, 0.07, 0.08)), frame, Vector3(0.14, 0.24, 0.04)))     # ear sensor

	# Legs: forward knees, armored shins
	for side in [-1.0, 1.0]:
		var thigh := Util.mesh(Util.box(Vector3(0.18, LEG_UPPER + 0.06, 0.2)), hull, Vector3.ZERO)
		var shin := Util.mesh(Util.box(Vector3(0.17, LEG_LOWER + 0.06, 0.2)), hull.darkened(0.05), Vector3.ZERO)
		shin.add_child(Util.mesh(Util.box(Vector3(0.14, 0.18, 0.06)), hull.lightened(0.05), Vector3(0, LEG_LOWER * 0.42, 0.11)))  # knee cap
		shin.add_child(Util.mesh(Util.box(Vector3(0.04, LEG_LOWER * 0.5, 0.02)), accent, Vector3(0, -0.05, 0.11)))
		legs.append([thigh, shin])
		add_child(thigh)
		add_child(shin)
		var foot := Node3D.new()
		foot.position = Vector3(0.18 * side, 0.0, 0.0)
		add_child(foot)
		foot.add_child(Util.mesh(Util.box(Vector3(0.22, 0.12, 0.42)), frame, Vector3(0, 0.06, 0.06)))
		foot.add_child(Util.mesh(Util.box(Vector3(0.2, 0.08, 0.16)), hull, Vector3(0, 0.14, 0.18)))
		feet.append(foot)

	# Arms
	for side in [-1.0, 1.0]:
		var upper := Util.mesh(Util.box(Vector3(0.14, ARM_UPPER + 0.05, 0.15)), hull, Vector3.ZERO)
		var lower := Util.mesh(Util.box(Vector3(0.16, ARM_LOWER + 0.04, 0.17)), hull.darkened(0.05), Vector3.ZERO)
		arms.append([upper, lower])
		body_root.add_child(upper)
		body_root.add_child(lower)
		var hand := Node3D.new()
		body_root.add_child(hand)
		hand.add_child(Util.mesh(Util.box(Vector3(0.13, 0.14, 0.15)), frame, Vector3.ZERO))
		hands.append(hand)

	# Rifle: origin at the trigger grip, +Z = barrel direction
	gun = Node3D.new()
	body_root.add_child(gun)
	var gm := Color(0.18, 0.18, 0.2) if not enemy else Color(0.12, 0.1, 0.1)
	gun.add_child(Util.mesh(Util.box(Vector3(0.1, 0.16, 0.6)), gm, Vector3(0, 0.05, 0.15)))       # receiver
	gun.add_child(Util.mesh(Util.box(Vector3(0.05, 0.05, 0.45)), gm.darkened(0.3), Vector3(0, 0.08, 0.66)))  # barrel
	gun.add_child(Util.mesh(Util.box(Vector3(0.07, 0.2, 0.1)), gm, Vector3(0, -0.1, 0.25)))      # magazine
	gun.add_child(Util.mesh(Util.box(Vector3(0.08, 0.12, 0.28)), gm, Vector3(0, 0.0, -0.25)))    # stock
	gun.add_child(Util.mesh(Util.box(Vector3(0.04, 0.05, 0.14)), accent, Vector3(0, 0.16, 0.12)))  # sight
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.08, GUN_LEN)
	gun.add_child(muzzle)
	flash = Util.glow(Util.box(Vector3(0.22, 0.22, 0.3)), Color(1.0, 0.85, 0.4))
	flash.visible = false
	muzzle.add_child(flash)
	_pose_gun(1.0, Vector3.FORWARD)
	# Less PS1 vertex jitter on the mechs themselves so moving bodies stay smooth
	for mi in find_children("", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial:
			mi.material_override.set_shader_parameter("snap_rows", 320.0)
			mi.material_override.set_shader_parameter("affine", 0.5)


## Shot off: the real piece breaks away as a tumbling physics body.
## Returns the rigid body so the city can throw it and clean it up.
func detach(part: String) -> RigidBody3D:
	var pieces: Array = []
	match part:
		"head":
			pieces = [head_pivot]
			head_pivot = Node3D.new()
			body_root.add_child(head_pivot)
		"arm":
			pieces = [arms[1][0], arms[1][1], hands[1], gun]
			arms[1] = [Node3D.new(), Node3D.new()]
			body_root.add_child(arms[1][0])
			body_root.add_child(arms[1][1])
			hands[1] = Node3D.new()
			body_root.add_child(hands[1])
			gun = Node3D.new()
			body_root.add_child(gun)
			muzzle = Node3D.new()
			gun.add_child(muzzle)
		"leg":
			pieces = [legs[0][1], feet[0]]
			legs[0] = [legs[0][0], Node3D.new()]
			add_child(legs[0][1])
			feet[0] = Node3D.new()
			add_child(feet[0])
	if pieces.is_empty():
		return null
	var rb := RigidBody3D.new()
	rb.collision_layer = Util.LAYER_DEBRIS
	rb.collision_mask = Util.LAYER_WORLD
	rb.mass = 30.0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * 2.0
	shape.shape = bs
	rb.add_child(shape)
	owner_mech.get_parent().add_child(rb)
	rb.global_position = (pieces[0] as Node3D).global_position
	for p in pieces:
		(p as Node3D).reparent(rb, true)
	return rb


## World position of a body part, for aiming at it.
func part_point(part: String) -> Vector3:
	var m := owner_mech
	if m and ((part == "head" and m.lost_head) or (part == "arm" and m.lost_arm) or (part == "leg" and m.lost_leg)):
		part = "body"
	match part:
		"head":
			return head_pivot.to_global(Vector3(0, 0.22, 0))
		"arm":
			return arms[1][1].global_position
		"leg":
			return legs[0][1].global_position
	return global_position + Vector3.UP * 6.0 * (scale.x / 3.7)


func set_eye(c: Color) -> void:
	eye_mat.albedo_color = c


func muzzle_world() -> Vector3:
	return muzzle.global_position


func fire_kick() -> void:
	recoil = 1.0
	flash.visible = true
	flash.rotation.z = randf() * TAU
	get_tree().create_timer(0.05).timeout.connect(func(): if is_instance_valid(flash): flash.visible = false)


static func _limb(segs: Array, a: Vector3, b: Vector3, l1: float, l2: float, pole: Vector3) -> void:
	var to := b - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - along * along))
	var side := (pole - dir * pole.dot(dir)).normalized()
	var joint := a + dir * along + side * h
	_place(segs[0], a, joint)
	_place(segs[1], joint, a + dir * d)


static func _place(seg: Node3D, p: Vector3, q: Vector3) -> void:
	var up := (q - p).normalized()
	if up.length() < 0.5:
		return
	seg.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), (p + q) * 0.5)


## Rifle pose in body space. aim_local = direction to the target in body space.
func _pose_gun(k: float, aim_local: Vector3) -> void:
	var m := owner_mech
	var g := Vector3(0.24, 1.5, 0.32)                  # low ready: rifle angled down in front
	var d := Vector3(-0.25, -0.35, 1.0)
	if m and not m.dead:
		if m.is_aiming():
			g = Vector3(0.2, 2.0, 0.34)                # shouldered, at eye level
			d = aim_local
		elif m.reload_t > 0.0:
			g = Vector3(0.15, 1.6, 0.4)
			d = Vector3(-0.6, 0.5, 0.6)                 # tipped up to swap the magazine
		elif gait > 0.3:
			# Running: rifle carried low in the right hand, swinging gently with the stride
			g = Vector3(0.4, 1.32, 0.18 - sin(walk_phase) * 0.28 * gait)
			d = Vector3(0.05, -0.5, 0.85)
	elif m and m.dead:
		g = Vector3(0.4, 0.5, 0.7)
		d = Vector3(0.3, -0.2, 1.0)
	g -= d.normalized() * recoil * 0.12
	grip = grip.lerp(g, k)
	gun_dir = gun_dir.lerp(d.normalized(), k).normalized()
	gun.transform = Transform3D(Basis.looking_at(-gun_dir, Vector3.UP) if absf(gun_dir.y) < 0.98 else Basis(), grip)


## Smooth run cycle: stride length comes from speed (feet don't slide), the body
## bobs twice per cycle, shoulders counter-rotate the hips, and the mech banks into turns.
func animate(delta: float) -> void:
	var m := owner_mech
	var t := Time.get_ticks_msec() * 0.001
	var s: float = scale.x
	var local_v: Vector3 = global_basis.inverse() * m.velocity * s  # model meters per second
	var hv := Vector2(local_v.x, local_v.z)
	var hs := hv.length()
	var rolling: bool = m.roll_t > 0.0
	var airborne: bool = not m.is_on_floor() and not m.dead
	var grounded_move: bool = m.is_on_floor() and not m.dead and not rolling
	var target_gait := clampf(hs / RUN_MODEL_SPEED, 0.0, 1.0) if grounded_move else 0.0
	gait = move_toward(gait, target_gait, delta * 3.0)
	# Cadence rises gently with speed; stride length makes up the rest, so feet stay planted
	var cadence := lerpf(1.0, 1.55, gait)              # strides per second per leg
	if hs > 0.05 and grounded_move:
		walk_phase += TAU * cadence * delta
	var amp := clampf(hs / (4.0 * cadence), 0.0, 0.9) if grounded_move else 0.0
	recoil = maxf(0.0, recoil - delta * 9.0)

	# Bank into turns from how fast we're rotating
	var yaw_rate := wrapf(global_rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = global_rotation.y
	bank = lerpf(bank, clampf(-yaw_rate * 0.07 * gait, -0.22, 0.22), clampf(5.0 * delta, 0.0, 1.0))

	var body_y := 0.0
	var lean := 0.03
	var sway := bank
	var hip_twist := 0.0
	if m.dead:
		body_y = -1.0
		lean = 1.25
		sway = 0.0
	elif airborne:
		lean = -0.08
	else:
		# Two soft bobs per cycle (one per footfall), lowest at mid-stance
		body_y = -absf(sin(walk_phase)) * lerpf(0.02, 0.07, gait) * clampf(gait * 3.0, 0.0, 1.0)
		lean = lerpf(0.04, 0.2, gait)
		sway += sin(walk_phase) * 0.025 * gait
		hip_twist = sin(walk_phase) * 0.14 * gait     # shoulders counter-rotate the stride
		if gait < 0.05:
			body_y = sin(t * 1.4) * 0.008
	if m.lost_leg and not m.dead:
		body_y -= 0.55
		sway += 0.18
	if m.crouching and not m.dead:
		body_y -= 0.5
		lean += 0.15
	if m.stagger > 0.0 and not m.dead:
		lean -= 0.25
	lean -= recoil * 0.05

	# Upper body twists toward the aim target; legs keep following the movement
	var aim_world: Vector3 = m.aim_direction()
	var aim_body := global_basis.inverse() * aim_world
	aim_body = aim_body.normalized() if aim_body.length() > 0.01 else Vector3.FORWARD
	var twist := -hip_twist
	if m.is_aiming():
		twist = clampf(atan2(aim_body.x, aim_body.z), -1.2, 1.2)

	var k := clampf(8.0 * delta, 0.0, 1.0)
	body_root.position.y = lerp(body_root.position.y, body_y, clampf(14.0 * delta, 0.0, 1.0))
	if rolling:
		var u: float = 1.0 - m.roll_t / m.ROLL_TIME
		var rdir: Vector3 = global_basis.inverse() * m.roll_dir
		rdir.y = 0.0
		rdir = rdir.normalized() if rdir.length() > 0.01 else Vector3.BACK
		var axis := Vector3.UP.cross(rdir).normalized()
		var pivot := Vector3(0, 1.0, 0)
		body_root.basis = Basis(axis, u * TAU)
		body_root.position = pivot - body_root.basis * pivot + Vector3(0, -0.9 * sin(u * PI), 0)
	else:
		var b := Basis.from_euler(Vector3(lerp_angle(body_root.rotation.x, lean, k), lerp_angle(body_root.rotation.y, twist, k), lerp_angle(body_root.rotation.z, sway, k)))
		body_root.basis = b
		body_root.position.x = lerp(body_root.position.x, 0.0, k)
		body_root.position.z = lerp(body_root.position.z, 0.6 if m.dead else 0.0, k * 0.5)

	var head_target := Vector3(-lean * 0.6, -twist * 0.5 if not m.is_aiming() else 0.0, -sway * 0.5)
	if m.is_aiming():
		head_target.x = clampf(-asin(clampf(aim_body.y, -1.0, 1.0)), -0.5, 0.5)
	head_vel += (head_target - head_rot) * 60.0 * delta
	head_vel -= head_vel * 12.0 * delta
	head_rot += head_vel * delta
	head_pivot.rotation = head_rot

	# Legs: each foot traces a smooth loop (planted, then lifted and swung forward)
	var mdir := Vector3(hv.x, 0, hv.y).normalized() if hs > 0.05 else Vector3.BACK
	step_signal = 0.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.17 * side, 0.0, 0.0)
		if m.crouching:
			foot.x *= 1.4
			foot.z += 0.2 if i == 0 else -0.25
		var lift_now := 0.0
		if amp > 0.0:
			foot += mdir * sin(ph) * amp
			# Swing phase (foot travelling forward): lift in a smooth arc
			lift_now = maxf(0.0, cos(ph)) * lerpf(0.1, 0.34, gait)
			foot.y += lift_now
			foot -= mdir * lift_now * 0.35 * gait   # knee folds as the foot passes under
		if airborne:
			foot = Vector3(0.2 * side, 0.5, 0.15 if i == 0 else -0.1)
		if m.lost_leg and i == 0:
			foot = Vector3(0.2 * side, 0.0, -0.2)
		if rolling:
			foot = Vector3(0.15 * side, 0.6, 0.1)
		if _last_lift[i] > 0.02 and lift_now <= 0.02 and amp > 0.0:
			step_signal = 1.0 if gait > 0.6 else 0.5
		_last_lift[i] = lift_now
		var follow := 30.0 if amp > 0.0 and not airborne else 12.0
		feet[i].position = feet[i].position.lerp(foot, clampf(follow * delta, 0.0, 1.0))
		var hip: Vector3 = body_root.transform * Vector3(0.16 * side, HIP_HEIGHT - 0.06, 0) if not rolling else Vector3(0.16 * side, HIP_HEIGHT - 0.06 + body_root.position.y, 0)
		var ankle: Vector3 = feet[i].position + Vector3(0, 0.14, -0.04)
		_limb(legs[i], hip, ankle, LEG_UPPER, LEG_LOWER, Vector3(0.1 * side, 0, 1))  # knees bend forward

	# Rifle and both hands
	_pose_gun(clampf(12.0 * delta, 0.0, 1.0), (body_root.basis.inverse() * aim_body).normalized())
	hands[1].position = grip
	var fore := grip + gun_dir * 0.45 + Vector3(0, 0.02, 0)
	if m.reload_t > 0.0 and fmod(t, 0.5) < 0.25:
		fore = grip + gun_dir * 0.2 + Vector3(0, -0.2, 0)   # slapping the magazine
	if (gait > 0.3 and not m.is_aiming() and m.reload_t <= 0.0) or m.lost_arm:
		# Free arm swings opposite the left leg, bigger the faster you go
		fore = Vector3(-0.43, 1.42 + maxf(0.0, sin(walk_phase)) * 0.18 * gait, 0.1 + sin(walk_phase) * 0.38 * gait)
		if m.has_method("is_bashing") and m.is_bashing():
			fore = Vector3(-0.2, 1.9, 0.9)
	if airborne:
		fore = Vector3(-0.6, 1.8, 0.1)
	hands[0].position = hands[0].position.lerp(fore, clampf(12.0 * delta, 0.0, 1.0))
	for i in 2:
		if i == 1 and m.lost_arm:
			continue
		var side := -1.0 if i == 0 else 1.0
		_limb(arms[i], SHOULDER * Vector3(side, 1, 1), hands[i].position, ARM_UPPER, ARM_LOWER, Vector3(0.7 * side, -0.6, -0.5))
