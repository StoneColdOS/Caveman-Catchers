extends Node3D
## A humanoid mech body: built in "model meters" (about 2.7 tall), scaled up ~3.7x
## by the owner to ~10 m. Lanky but human: forward knees, broad chest, neck, visor head.
##
## Carries a katana or a rifle. The pose comes from the owner's state:
##   katana: held low and to the side, trailed behind at a sprint, swung along any
##           angle (the swing arc follows the owner's swing_angle), raised in Blade Mode,
##           held across the body to guard.
##   rifle:  low ready, shouldered while aiming, reloads.
## Every limb can come off: head, either arm, either leg, or the whole upper body.
## The real pieces break away as tumbling physics bodies and the stumps gush oil.

const Util := preload("res://scripts/util.gd")

const HIP_HEIGHT := 1.3
const LEG_UPPER := 0.64
const LEG_LOWER := 0.66
const ARM_UPPER := 0.55
const ARM_LOWER := 0.58
const SHOULDER := Vector3(0.44, 2.08, 0.0)
const GUN_LEN := 0.95
const BLADE := 1.55               # katana blade length (model meters, ~5.7 m in game)
const RUN_MODEL_SPEED := 13.0 / 3.7
const SWING_CENTER := Vector3(0.0, 1.85, 0.55)

var owner_mech: Node              # the CharacterBody that owns us (reads its state)
var enemy := false
var weapon := "katana"            # or "rifle"
var body_root: Node3D
var head_pivot: Node3D
var head_rot := Vector3.ZERO
var head_vel := Vector3.ZERO
var walk_phase := 0.0
var legs: Array = []
var feet: Array = []
var arms: Array = []
var hands: Array = []
var gun: Node3D                   # the held weapon (katana or rifle); origin = grip
var muzzle: Node3D
var flash: MeshInstance3D
var eye_mat: StandardMaterial3D
var grip := Vector3(0.3, 1.3, 0.3)
var gun_dir := Vector3(0.3, -0.5, 0.8).normalized()
var recoil := 0.0
var step_signal := 0.0            # >0 on the frame a foot lands
var _last_lift := [0.0, 0.0]
var gait := 0.0                   # 0 = standing, ~0.5 = jog, 1 = full sprint (smoothed)
var bank := 0.0
var _last_yaw := 0.0
var stumps: Array = []            # Node3D markers where oil gushes from


func build(is_enemy: bool, weapon_kind := "katana") -> void:
	enemy = is_enemy
	weapon = weapon_kind
	var hull := Color(0.6, 0.58, 0.5) if not enemy else Color(0.5, 0.15, 0.14)
	var frame := Color(0.15, 0.15, 0.16) if not enemy else Color(0.1, 0.08, 0.08)
	var accent := Color(0.75, 0.3, 0.1) if not enemy else Color(0.85, 0.68, 0.25)
	var eye_c := Color(1.0, 0.2, 0.12) if not enemy else Color(0.3, 0.9, 1.0)
	if enemy and weapon == "katana":
		hull = Color(0.36, 0.38, 0.46)          # sword mechs: gunmetal
		accent = Color(0.85, 0.15, 0.15)        # with red trim

	body_root = Node3D.new()
	add_child(body_root)
	body_root.add_child(Util.mesh(Util.box(Vector3(0.44, 0.24, 0.3)), frame, Vector3(0, HIP_HEIGHT, 0)))
	for side in [-1.0, 1.0]:
		var skirt := Util.mesh(Util.box(Vector3(0.22, 0.32, 0.07)), hull.darkened(0.08), Vector3(0.18 * side, HIP_HEIGHT - 0.1, 0.17))
		skirt.rotation.x = -0.2
		body_root.add_child(skirt)
		var side_plate := Util.mesh(Util.box(Vector3(0.07, 0.3, 0.26)), hull.darkened(0.08), Vector3(0.25 * side, HIP_HEIGHT - 0.1, 0))
		side_plate.rotation.z = 0.15 * side
		body_root.add_child(side_plate)
	body_root.add_child(Util.mesh(Util.box(Vector3(0.3, 0.3, 0.24)), frame, Vector3(0, HIP_HEIGHT + 0.27, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.36, 0.08, 0.28)), hull, Vector3(0, HIP_HEIGHT + 0.36, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.72, 0.5, 0.44)), hull, Vector3(0, 1.9, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.6, 0.14, 0.4)), hull.lightened(0.06), Vector3(0, 2.16, 0.02)))
	var plate := Util.mesh(Util.box(Vector3(0.56, 0.3, 0.08)), hull.lightened(0.08), Vector3(0, 1.88, 0.24))
	plate.rotation.x = -0.15
	body_root.add_child(plate)
	for i in 3:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.12, 0.025, 0.02)), frame, Vector3(0.18, 1.82 + i * 0.05, 0.285)))
		body_root.add_child(Util.mesh(Util.box(Vector3(0.12, 0.025, 0.02)), frame, Vector3(-0.18, 1.82 + i * 0.05, 0.285)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.05, 0.28, 0.02)), accent, Vector3(0, 1.86, 0.29)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.5, 0.46, 0.22)), hull.darkened(0.15), Vector3(0, 1.94, -0.32)))
	for side in [-1.0, 1.0]:
		var thruster := CylinderMesh.new()
		thruster.top_radius = 0.06
		thruster.bottom_radius = 0.09
		thruster.height = 0.18
		thruster.radial_segments = 6
		body_root.add_child(Util.mesh(thruster, frame, Vector3(0.15 * side, 1.66, -0.38)))
		var pad := Util.mesh(Util.box(Vector3(0.3, 0.26, 0.38)), hull.darkened(0.04), SHOULDER * Vector3(side, 1, 1) + Vector3(0.06 * side, 0.08, 0))
		pad.rotation.z = -0.25 * side
		body_root.add_child(pad)
		body_root.add_child(Util.mesh(Util.box(Vector3(0.31, 0.05, 0.39)), accent, SHOULDER * Vector3(side, 1, 1) + Vector3(0.09 * side, -0.04, 0)))
		if enemy:
			var horn := Util.mesh(Util.box(Vector3(0.05, 0.22, 0.05)), accent, SHOULDER * Vector3(side, 1, 1) + Vector3(0.1 * side, 0.3, -0.05))
			horn.rotation.z = -0.3 * side
			body_root.add_child(horn)

	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 2.2, 0.03)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.11, 0.14, 0.11)), frame, Vector3(0, 0.05, 0)))
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.24, 0.24, 0.27)), hull, Vector3(0, 0.22, 0.02)))
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.2, 0.08, 0.06)), frame, Vector3(0, 0.12, 0.15)))
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
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.015, 0.34, 0.015)), frame, Vector3(-0.1, 0.45, -0.06)))
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.05, 0.07, 0.08)), frame, Vector3(0.14, 0.24, 0.04)))
		# A long scarf-like cable trailing from the head: reads as "the swordsman"
		var tail := Util.mesh(Util.box(Vector3(0.05, 0.03, 0.5)), accent, Vector3(0, 0.3, -0.35))
		tail.rotation.x = -0.4
		head_pivot.add_child(tail)

	for side in [-1.0, 1.0]:
		var thigh := Util.mesh(Util.box(Vector3(0.18, LEG_UPPER + 0.06, 0.2)), hull, Vector3.ZERO)
		var shin := Util.mesh(Util.box(Vector3(0.17, LEG_LOWER + 0.06, 0.2)), hull.darkened(0.05), Vector3.ZERO)
		shin.add_child(Util.mesh(Util.box(Vector3(0.14, 0.18, 0.06)), hull.lightened(0.05), Vector3(0, LEG_LOWER * 0.42, 0.11)))
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

	gun = Node3D.new()
	body_root.add_child(gun)
	muzzle = Node3D.new()
	gun.add_child(muzzle)
	if weapon == "rifle":
		var gm := Color(0.12, 0.1, 0.1)
		gun.add_child(Util.mesh(Util.box(Vector3(0.1, 0.16, 0.6)), gm, Vector3(0, 0.05, 0.15)))
		gun.add_child(Util.mesh(Util.box(Vector3(0.05, 0.05, 0.45)), gm.darkened(0.3), Vector3(0, 0.08, 0.66)))
		gun.add_child(Util.mesh(Util.box(Vector3(0.07, 0.2, 0.1)), gm, Vector3(0, -0.1, 0.25)))
		gun.add_child(Util.mesh(Util.box(Vector3(0.08, 0.12, 0.28)), gm, Vector3(0, 0.0, -0.25)))
		gun.add_child(Util.mesh(Util.box(Vector3(0.04, 0.05, 0.14)), accent, Vector3(0, 0.16, 0.12)))
		muzzle.position = Vector3(0, 0.08, GUN_LEN)
	else:
		# Katana: origin at the grip, +Z = blade direction
		gun.add_child(Util.mesh(Util.box(Vector3(0.05, 0.05, 0.38)), Color(0.1, 0.08, 0.08), Vector3(0, 0, -0.08)))   # wrapped hilt
		gun.add_child(Util.mesh(Util.box(Vector3(0.14, 0.12, 0.03)), Color(0.6, 0.48, 0.2), Vector3(0, 0, 0.12)))    # guard
		var steel := Color(0.78, 0.8, 0.85) if not enemy else Color(0.4, 0.38, 0.42)
		gun.add_child(Util.mesh(Util.box(Vector3(0.022, 0.08, BLADE)), steel, Vector3(0, 0, 0.14 + BLADE * 0.5)))
		var edge_c := Color(0.75, 0.9, 1.0) if not enemy else Color(1.0, 0.35, 0.3)
		gun.add_child(Util.glow(Util.box(Vector3(0.026, 0.015, BLADE * 0.96)), edge_c, Vector3(0, -0.045, 0.14 + BLADE * 0.5)))
		muzzle.position = Vector3(0, 0, 0.14 + BLADE)   # blade tip
	flash = Util.glow(Util.box(Vector3(0.22, 0.22, 0.3)), Color(1.0, 0.85, 0.4))
	flash.visible = false
	muzzle.add_child(flash)
	# Less PS1 vertex jitter on the mechs themselves so moving bodies stay smooth
	for mi in find_children("", "MeshInstance3D", true, false):
		if mi.material_override is ShaderMaterial:
			mi.material_override.set_shader_parameter("snap_rows", 320.0)
			mi.material_override.set_shader_parameter("affine", 0.5)


# --- Dismemberment

## Cut off: the real pieces break away as one tumbling physics body. A stump marker
## stays behind so oil can gush from it. Returns the rigid body (or null).
func detach(part: String) -> RigidBody3D:
	var pieces: Array = []
	var stump_at := Vector3.ZERO     # in body_root space (or rig space for legs)
	var stump_parent: Node3D = body_root
	match part:
		"head":
			pieces = [head_pivot]
			stump_at = head_pivot.position
			head_pivot = Node3D.new()
			body_root.add_child(head_pivot)
		"arm_r", "arm_l":
			var i := 1 if part == "arm_r" else 0
			pieces = [arms[i][0], arms[i][1], hands[i]]
			stump_at = SHOULDER * Vector3(1 if i == 1 else -1, 1, 1)
			if i == 1:
				pieces.append(gun)
			arms[i] = [Node3D.new(), Node3D.new()]
			body_root.add_child(arms[i][0])
			body_root.add_child(arms[i][1])
			hands[i] = Node3D.new()
			body_root.add_child(hands[i])
			if i == 1:
				gun = Node3D.new()
				body_root.add_child(gun)
				muzzle = Node3D.new()
				gun.add_child(muzzle)
		"leg_l", "leg_r":
			var i := 0 if part == "leg_l" else 1
			pieces = [legs[i][1], feet[i]]
			stump_parent = self
			stump_at = legs[i][1].position + Vector3(0, LEG_LOWER * 0.5, 0)
			legs[i] = [legs[i][0], Node3D.new()]
			add_child(legs[i][1])
			feet[i] = Node3D.new()
			add_child(feet[i])
		"upper":
			# Cut through the waist: everything above it goes
			pieces = [body_root]
			stump_parent = self
			stump_at = Vector3(0, HIP_HEIGHT + 0.1, 0)
	if pieces.is_empty():
		return null
	var rb := RigidBody3D.new()
	rb.collision_layer = Util.LAYER_DEBRIS
	rb.collision_mask = Util.LAYER_WORLD
	rb.mass = 30.0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * (3.5 if part == "upper" else 2.0)
	shape.shape = bs
	rb.add_child(shape)
	owner_mech.get_parent().add_child(rb)
	rb.global_position = (pieces[0] as Node3D).global_position if part != "upper" else to_global(Vector3(0, 1.9, 0))
	for p in pieces:
		(p as Node3D).reparent(rb, true)
	if part == "upper":
		# Keep a stand-in so the rest of the code has something to hold on to
		body_root = Node3D.new()
		add_child(body_root)
		head_pivot = Node3D.new()
		body_root.add_child(head_pivot)
		for i in 2:
			arms[i] = [Node3D.new(), Node3D.new()]
			hands[i] = Node3D.new()
			body_root.add_child(arms[i][0])
			body_root.add_child(arms[i][1])
			body_root.add_child(hands[i])
		gun = Node3D.new()
		body_root.add_child(gun)
		muzzle = Node3D.new()
		gun.add_child(muzzle)
	var stump := Node3D.new()
	stump.position = stump_at
	stump_parent.add_child(stump)
	stumps.append(stump)
	# The cut-off piece gushes too
	var piece_stump := Node3D.new()
	rb.add_child(piece_stump)
	stumps.append(piece_stump)
	return rb


## World position of a body part (for cutting and aiming).
func part_point(part: String) -> Vector3:
	match part:
		"head":
			return head_pivot.to_global(Vector3(0, 0.22, 0))
		"arm_r":
			return arms[1][1].global_position
		"arm_l":
			return arms[0][1].global_position
		"leg_l":
			return legs[0][1].global_position
		"leg_r":
			return legs[1][1].global_position
		"waist":
			return to_global(Vector3(0, HIP_HEIGHT + 0.25, 0))
		"chest":
			return to_global(Vector3(0, 1.9, 0))
	return to_global(Vector3(0, 1.6, 0))


func set_eye(c: Color) -> void:
	eye_mat.albedo_color = c


func muzzle_world() -> Vector3:
	return muzzle.global_position


## [base, tip] of the katana in world space (for the slash trail).
func blade_world() -> Array:
	return [gun.to_global(Vector3(0, 0, 0.3)), gun.to_global(Vector3(0, 0, 0.14 + BLADE))]


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


# --- Weapon poses (body space, +Z forward)

## Rifle: low ready, shouldered while aiming, tipped up to reload.
func _rifle_pose(m: Node, aim_local: Vector3) -> Array:
	var g := Vector3(0.24, 1.5, 0.32)
	var d := Vector3(-0.25, -0.35, 1.0)
	if m.dead:
		return [Vector3(0.4, 0.5, 0.7), Vector3(0.3, -0.2, 1.0)]
	if m.is_aiming():
		return [Vector3(0.2, 2.0, 0.34), aim_local]
	if m.reload_t > 0.0:
		return [Vector3(0.15, 1.6, 0.4), Vector3(-0.6, 0.5, 0.6)]
	if gait > 0.3:
		return [Vector3(0.4, 1.32, 0.18 - sin(walk_phase) * 0.28 * gait), Vector3(0.05, -0.5, 0.85)]
	return [g, d]


## Katana: where the grip is and which way the blade points.
## A swing travels along an arc in front of the body in the direction of swing_angle
## (0 = toward the mech's left side, PI/2 = upward, -PI/2 = downward chop...).
func _katana_pose(m: Node) -> Array:
	if m.dead:
		return [Vector3(0.45, 0.6, 0.6), Vector3(0.3, -0.4, 1.0)]
	var swing: int = m.swing
	if swing != 0:
		var a: float = m.swing_angle
		var c := Vector3(cos(a), sin(a), 0.0)       # direction the blade travels
		var u: float = 1.0 - m.swing_t / maxf(m.swing_len, 0.001)
		var s := -1.25                               # position along the arc: -1.25 cocked .. 1 finished
		match swing:
			1: s = lerpf(-0.9, -1.25, ease(u, 0.5))  # wind up
			2: s = lerpf(-1.25, 1.0, u)              # the cut itself
			3: s = 1.0
		var g := SWING_CENTER + c * s * 0.62 + Vector3(0, 0, 1) * (1.0 - s * s) * 0.3
		if swing == 3:
			g = g.lerp(Vector3(0.35, 1.3, 0.35), ease(u, 2.0))
		var d := (c * s * 1.1 + Vector3(0, 0, 0.9)).normalized()
		return [g, d]
	if m.guarding:
		return [Vector3(0.0, 1.95, 0.6), Vector3(-0.95, 0.25, 0.2)]   # blade across the body
	if m.in_blade_mode():
		return [Vector3(0.25, 2.25, 0.35), Vector3(0.1, 0.8, 0.55)]   # raised, ready to cut
	if m.is_sprinting() or m.dive_t > 0.0:
		return [Vector3(0.45, 1.35, -0.1), Vector3(0.25, -0.25, -0.95)]  # trailing behind, ninja run
	# Idle / jog: low and to the side, edge forward
	return [Vector3(0.38, 1.25 + sin(walk_phase) * 0.03 * gait, 0.3), Vector3(0.35, -0.45, 0.8)]


func _pose_weapon(k: float, aim_local: Vector3) -> void:
	var m := owner_mech
	var p: Array = _katana_pose(m) if weapon == "katana" else _rifle_pose(m, aim_local)
	var g: Vector3 = p[0]
	var d: Vector3 = (p[1] as Vector3).normalized()
	g -= d * recoil * 0.12
	var fast: bool = m.swing == 2
	grip = g if fast else grip.lerp(g, k)
	gun_dir = d if fast else gun_dir.lerp(d, k).normalized()
	if gun_dir.length() < 0.01:
		gun_dir = Vector3.FORWARD
	gun.transform = Transform3D(Basis.looking_at(-gun_dir, Vector3.UP) if absf(gun_dir.y) < 0.98 else Basis.looking_at(-gun_dir, Vector3.FORWARD), grip)


# --- Animation

## Smooth Phantom Pain locomotion plus sword work.
func animate(delta: float) -> void:
	var m := owner_mech
	var t := Time.get_ticks_msec() * 0.001
	var s: float = scale.x
	var local_v: Vector3 = global_basis.inverse() * m.velocity * s
	var hv := Vector2(local_v.x, local_v.z)
	var hs := hv.length()
	var rolling: bool = m.roll_t > 0.0
	var diving: bool = m.dive_t > 0.0
	var airborne: bool = not m.is_on_floor() and not m.dead
	var grounded_move: bool = m.is_on_floor() and not m.dead and not rolling and not diving
	var target_gait := clampf(hs / RUN_MODEL_SPEED, 0.0, 1.25) if grounded_move else 0.0
	gait = move_toward(gait, target_gait, delta * 3.0)
	var cadence := lerpf(1.0, 1.6, minf(gait, 1.2))
	if hs > 0.05 and grounded_move:
		walk_phase += TAU * cadence * delta
	var amp := clampf(hs / (4.0 * cadence), 0.0, 1.0) if grounded_move else 0.0
	recoil = maxf(0.0, recoil - delta * 9.0)
	var lost: Dictionary = m.lost
	var upper_gone: bool = lost.has("upper")

	var yaw_rate := wrapf(global_rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = global_rotation.y
	bank = lerpf(bank, clampf(-yaw_rate * 0.08 * gait, -0.3, 0.3), clampf(5.0 * delta, 0.0, 1.0))

	var body_y := 0.0
	var lean := 0.03
	var sway := bank
	var hip_twist := 0.0
	if m.dead:
		body_y = -1.0
		lean = 1.25
		sway = 0.0
	elif diving:
		body_y = -0.9
		lean = 1.35            # flat out, Phantom Pain dive
	elif airborne:
		lean = -0.08
	else:
		body_y = -absf(sin(walk_phase)) * lerpf(0.02, 0.08, minf(gait, 1.0)) * clampf(gait * 3.0, 0.0, 1.0)
		lean = lerpf(0.04, 0.22, minf(gait, 1.0)) + maxf(0.0, gait - 1.0) * 0.6   # sprint leans hard
		sway += sin(walk_phase) * 0.025 * gait
		hip_twist = sin(walk_phase) * 0.14 * minf(gait, 1.0)
		if gait < 0.05:
			body_y = sin(t * 1.4) * 0.008
	var legs_lost := int(lost.has("leg_l")) + int(lost.has("leg_r"))
	if legs_lost > 0 and not m.dead:
		body_y -= 0.55 * legs_lost
		sway += 0.18 if lost.has("leg_l") else (-0.18 if lost.has("leg_r") else 0.0)
	if m.crouching and not m.dead:
		body_y -= 0.5
		lean += 0.15
	if m.stagger > 0.0 and not m.dead:
		lean -= 0.3
	lean -= recoil * 0.05

	# Swings drive the whole body: wind back, then unwind hard through the cut
	var twist := -hip_twist
	if m.swing != 0:
		var a: float = m.swing_angle
		var dirx := cos(a)
		match m.swing:
			1: twist = -dirx * 0.55
			2: twist = dirx * 0.7
			3: twist = dirx * 0.45
		lean += 0.15 if m.swing == 2 else 0.0
	var aim_body: Vector3 = global_basis.inverse() * m.aim_direction()
	aim_body = aim_body.normalized() if aim_body.length() > 0.01 else Vector3.FORWARD
	if weapon == "rifle" and m.is_aiming():
		twist = clampf(atan2(aim_body.x, aim_body.z), -1.2, 1.2)

	var k := clampf(9.0 * delta, 0.0, 1.0)
	var kt := clampf((30.0 if m.swing == 2 else 10.0) * delta, 0.0, 1.0)
	if not upper_gone:
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
			var b := Basis.from_euler(Vector3(lerp_angle(body_root.rotation.x, lean, k), lerp_angle(body_root.rotation.y, twist, kt), lerp_angle(body_root.rotation.z, sway, k)))
			body_root.basis = b
			body_root.position.x = lerp(body_root.position.x, 0.0, k)
			body_root.position.z = lerp(body_root.position.z, (0.6 if m.dead else (0.9 if diving else 0.0)), k)

		var head_target := Vector3(-lean * 0.6, -twist * 0.4, -sway * 0.5)
		if weapon == "rifle" and m.is_aiming():
			head_target.x = clampf(-asin(clampf(aim_body.y, -1.0, 1.0)), -0.5, 0.5)
		head_vel += (head_target - head_rot) * 60.0 * delta
		head_vel -= head_vel * 12.0 * delta
		head_rot += head_vel * delta
		head_pivot.rotation = head_rot

	# Legs
	var mdir := Vector3(hv.x, 0, hv.y).normalized() if hs > 0.05 else Vector3.BACK
	step_signal = 0.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.17 * side, 0.0, 0.0)
		if m.crouching:
			foot.x *= 1.4
			foot.z += 0.2 if i == 0 else -0.25
		if m.swing != 0 or m.guarding or m.in_blade_mode():
			foot.x *= 1.5
			foot.z += 0.3 if i == 0 else -0.3       # fighting stance
		var lift_now := 0.0
		if amp > 0.0:
			foot += mdir * sin(ph) * amp
			lift_now = maxf(0.0, cos(ph)) * lerpf(0.1, 0.4, minf(gait, 1.2))
			foot.y += lift_now
			foot -= mdir * lift_now * 0.35 * minf(gait, 1.0)
		if airborne:
			foot = Vector3(0.2 * side, 0.5, 0.15 if i == 0 else -0.1)
		if diving:
			foot = Vector3(0.2 * side, 0.3, -1.2)
		if rolling:
			foot = Vector3(0.15 * side, 0.6, 0.1)
		if m.dead and upper_gone:
			foot = Vector3(0.2 * side, 0.0, 0.0)
		if _last_lift[i] > 0.02 and lift_now <= 0.02 and amp > 0.0:
			step_signal = 1.0 if gait > 0.6 else 0.5
		_last_lift[i] = lift_now
		var follow := 30.0 if amp > 0.0 and not airborne else 12.0
		feet[i].position = feet[i].position.lerp(foot, clampf(follow * delta, 0.0, 1.0))
		var hip: Vector3
		if upper_gone:
			hip = Vector3(0.16 * side, HIP_HEIGHT - 0.06 - (0.6 if m.dead else 0.0), 0)
		elif rolling:
			hip = Vector3(0.16 * side, HIP_HEIGHT - 0.06 + body_root.position.y, 0)
		else:
			hip = body_root.transform * Vector3(0.16 * side, HIP_HEIGHT - 0.06, 0)
		var ankle: Vector3 = feet[i].position + Vector3(0, 0.14, -0.04)
		_limb(legs[i], hip, ankle, LEG_UPPER, LEG_LOWER, Vector3(0.1 * side, 0, 1))
	if upper_gone:
		return

	# Weapon and hands
	_pose_weapon(clampf(14.0 * delta, 0.0, 1.0), (body_root.basis.inverse() * aim_body).normalized())
	hands[1].position = grip
	var fore := grip + gun_dir * (0.45 if weapon == "rifle" else -0.2)   # rifle foregrip / two-hand katana
	var two_handed: bool = weapon == "rifle" or m.guarding or m.in_blade_mode() or (m.swing != 0 and m.swing_kind == "heavy")
	if weapon == "rifle" and m.reload_t > 0.0 and fmod(t, 0.5) < 0.25:
		fore = grip + gun_dir * 0.2 + Vector3(0, -0.2, 0)
	if not two_handed or lost.has("arm_r") or (weapon == "rifle" and gait > 0.3 and not m.is_aiming() and m.reload_t <= 0.0):
		# Free arm swings with the stride, or flings out for balance in a swing
		fore = Vector3(-0.43, 1.42 + maxf(0.0, sin(walk_phase)) * 0.18 * gait, 0.1 + sin(walk_phase) * 0.38 * gait)
		if m.swing == 2:
			fore = Vector3(-0.75, 1.75, -0.2)
		if m.has_method("is_bashing") and m.is_bashing():
			fore = Vector3(-0.2, 1.9, 0.9)
	if airborne or diving:
		fore = Vector3(-0.6, 1.8, 0.6)
	hands[0].position = hands[0].position.lerp(fore, clampf((30.0 if m.swing == 2 else 12.0) * delta, 0.0, 1.0))
	for i in 2:
		if (i == 1 and lost.has("arm_r")) or (i == 0 and lost.has("arm_l")):
			continue
		var side := -1.0 if i == 0 else 1.0
		_limb(arms[i], SHOULDER * Vector3(side, 1, 1), hands[i].position, ARM_UPPER, ARM_LOWER, Vector3(0.7 * side, -0.6, -0.5))
