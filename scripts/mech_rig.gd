extends Node3D
## The body of a mech: built in "model meters" (about 2.7 tall) and scaled up by
## the fighter to ~10 m. Lanky: reverse-jointed bird legs, wasp waist, long arms.
## Holds a long sword in both hands; the sword pose comes from the fighter's state
## (stance, windup, strike, guard) and both arms reach for the hilt with IK.

const Util := preload("res://scripts/util.gd")

const HIP_HEIGHT := 1.42
const LEG_UPPER := 0.74
const LEG_LOWER := 0.78
const ARM_UPPER := 0.62
const ARM_LOWER := 0.66
const SHOULDER := Vector3(0.45, 2.12, 0.0)
const BLADE := 1.75             # blade length (model meters, ~6.5 m in game)

# Sword poses: [grip position, blade direction] in model space (+Z = forward).
# Indexed by stance: 0 = HIGH, 1 = MID, 2 = LOW.
const IDLE := [
	[Vector3(0.28, 2.35, 0.3), Vector3(0.25, 0.85, -0.45)],   # high: blade up over the right shoulder
	[Vector3(0.08, 1.75, 0.55), Vector3(0.0, 0.35, 1.0)],     # mid: point at the enemy's chest
	[Vector3(0.3, 1.25, 0.45), Vector3(0.2, -0.5, 0.85)],     # low: tip down and forward
]
const WINDUP := [
	[Vector3(0.12, 2.75, -0.05), Vector3(0.0, 0.25, -1.0)],   # blade cocked back behind the head
	[Vector3(0.8, 1.95, 0.0), Vector3(0.8, 0.2, -0.6)],       # wound back to the right
	[Vector3(0.55, 1.05, -0.15), Vector3(0.5, -0.6, -0.6)],   # low and back
]
const STRIKE_MID := [
	[Vector3(0.05, 2.6, 0.6), Vector3(0.0, 1.0, 0.15)],
	[Vector3(0.2, 1.85, 0.9), Vector3(0.15, 0.15, 1.0)],
	[Vector3(0.2, 1.3, 0.8), Vector3(0.3, -0.45, 0.85)],
]
const STRIKE_END := [
	[Vector3(0.0, 1.45, 0.9), Vector3(0.0, -0.65, 0.75)],     # chopped straight down
	[Vector3(-0.6, 1.8, 0.6), Vector3(-0.9, 0.1, 0.4)],       # swept across to the left
	[Vector3(-0.2, 2.15, 0.7), Vector3(-0.3, 0.85, 0.45)],    # rising cut
]
const GUARD := [Vector3(0.0, 1.95, 0.6), Vector3(-0.85, 0.45, 0.25)]   # blade held across the body
const RUN_POSE := [Vector3(0.6, 1.35, 0.05), Vector3(0.35, -0.25, -0.9)]  # trailing behind while running
const DEAD_POSE := [Vector3(0.7, 0.4, 0.9), Vector3(0.3, -0.1, 1.0)]

var fighter: Node                 # the CharacterBody that owns us (reads its state)
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
var sword: Node3D
var eye_mat: StandardMaterial3D
var grip := Vector3(0.08, 1.75, 0.55)
var blade_dir := Vector3(0, 0.35, 1).normalized()
var step_signal := 0.0            # >0 on the frame a foot lands (for stomp shake and dust)
var _last_lift := [0.0, 0.0]


func build(is_enemy: bool) -> void:
	enemy = is_enemy
	var hull := Color(0.6, 0.58, 0.5) if not enemy else Color(0.5, 0.15, 0.14)      # enemies: lacquered crimson
	var frame := Color(0.15, 0.15, 0.16) if not enemy else Color(0.1, 0.08, 0.08)
	var accent := Color(0.75, 0.3, 0.1) if not enemy else Color(0.85, 0.68, 0.25)    # with gold trim
	var eye_c := Color(1.0, 0.18, 0.1) if not enemy else Color(0.3, 0.9, 1.0)

	body_root = Node3D.new()
	add_child(body_root)
	# Pelvis and the thin exposed spine: the wasp waist is what makes it read lanky.
	body_root.add_child(Util.mesh(Util.box(Vector3(0.46, 0.22, 0.32)), frame, Vector3(0, HIP_HEIGHT, 0)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.5, 0.08, 0.26)), hull, Vector3(0, HIP_HEIGHT + 0.12, 0)))
	var spine := CylinderMesh.new()
	spine.top_radius = 0.09
	spine.bottom_radius = 0.07
	spine.height = 0.36
	spine.radial_segments = 6
	body_root.add_child(Util.mesh(spine, frame, Vector3(0, HIP_HEIGHT + 0.32, 0)))
	# Hip skirt plates
	for side in [-1.0, 1.0]:
		var skirt := Util.mesh(Util.box(Vector3(0.2, 0.3, 0.06)), hull.darkened(0.1), Vector3(0.2 * side, HIP_HEIGHT - 0.12, 0.17))
		skirt.rotation.x = -0.25
		body_root.add_child(skirt)
	# Chest
	body_root.add_child(Util.mesh(Util.box(Vector3(0.62, 0.52, 0.5)), hull, Vector3(0, 2.0, 0)))
	var plate := Util.mesh(Util.box(Vector3(0.5, 0.36, 0.08)), hull.lightened(0.08), Vector3(0, 1.94, 0.27))
	plate.rotation.x = -0.35
	body_root.add_child(plate)
	for side in [-1.0, 1.0]:
		body_root.add_child(Util.mesh(Util.box(Vector3(0.05, 0.3, 0.02)), accent, Vector3(0.25 * side, 1.98, 0.255)))
	body_root.add_child(Util.mesh(Util.box(Vector3(0.44, 0.44, 0.22)), hull.darkened(0.15), Vector3(0, 2.02, -0.34)))  # backpack
	for side in [-1.0, 1.0]:
		if enemy:
			# Big hanging shoulder plates, like layered armor
			var sode := Util.mesh(Util.box(Vector3(0.36, 0.42, 0.42)), hull, SHOULDER * Vector3(side, 1, 1) + Vector3(0.1 * side, 0.0, 0))
			sode.rotation.z = -0.35 * side
			body_root.add_child(sode)
			body_root.add_child(Util.mesh(Util.box(Vector3(0.38, 0.05, 0.44)), accent, SHOULDER * Vector3(side, 1, 1) + Vector3(0.13 * side, -0.12, 0)))
		else:
			var pad := Util.mesh(Util.box(Vector3(0.3, 0.2, 0.36)), hull.darkened(0.06), SHOULDER * Vector3(side, 1, 1) + Vector3(0.02 * side, 0.1, 0))
			pad.rotation.z = -0.2 * side
			body_root.add_child(pad)
		var stack := CylinderMesh.new()
		stack.top_radius = 0.05
		stack.bottom_radius = 0.06
		stack.height = 0.4
		stack.radial_segments = 6
		body_root.add_child(Util.mesh(stack, frame, Vector3(0.14 * side, 2.32, -0.33)))

	# Head
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 2.3, 0.05)
	body_root.add_child(head_pivot)
	head_pivot.add_child(Util.mesh(Util.box(Vector3(0.08, 0.14, 0.08)), frame, Vector3(0, 0.05, 0)))
	eye_mat = Util.mat(eye_c, true)
	if enemy:
		# Wide flat head with a visor bar and a swept-back crest blade
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.34, 0.14, 0.3)), hull, Vector3(0, 0.17, 0.02)))
		var eye := MeshInstance3D.new()
		eye.mesh = Util.box(Vector3(0.3, 0.04, 0.02))
		eye.material_override = eye_mat
		eye.position = Vector3(0, 0.17, 0.175)
		head_pivot.add_child(eye)
		var crest := Util.mesh(Util.box(Vector3(0.03, 0.08, 0.5)), accent, Vector3(0, 0.3, -0.12))
		crest.rotation.x = 0.35
		head_pivot.add_child(crest)
	else:
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.26, 0.17, 0.32)), hull, Vector3(0, 0.18, 0.03)))
		var brow := Util.mesh(Util.box(Vector3(0.28, 0.05, 0.12)), hull.darkened(0.1), Vector3(0, 0.26, 0.15))
		brow.rotation.x = 0.25
		head_pivot.add_child(brow)
		var eye := MeshInstance3D.new()
		eye.mesh = Util.box(Vector3(0.2, 0.035, 0.02))
		eye.material_override = eye_mat
		eye.position = Vector3(0, 0.19, 0.19)
		head_pivot.add_child(eye)
		head_pivot.add_child(Util.mesh(Util.box(Vector3(0.015, 0.4, 0.015)), frame, Vector3(-0.1, 0.42, -0.08)))  # antenna

	# Reverse-jointed legs
	for side in [-1.0, 1.0]:
		var thigh := Util.mesh(Util.box(Vector3(0.15, LEG_UPPER + 0.08, 0.18)), hull, Vector3.ZERO)
		var shin := Util.mesh(Util.box(Vector3(0.1, LEG_LOWER + 0.06, 0.12)), frame, Vector3.ZERO)
		thigh.add_child(Util.mesh(Util.box(Vector3(0.04, LEG_UPPER * 0.6, 0.02)), accent, Vector3(0.0, 0.0, 0.1)))
		legs.append([thigh, shin])
		add_child(thigh)
		add_child(shin)
		var foot := Node3D.new()
		foot.position = Vector3(0.2 * side, 0.0, 0.05)
		add_child(foot)
		foot.add_child(Util.mesh(Util.box(Vector3(0.24, 0.1, 0.46)), frame, Vector3(0, 0.05, 0.06)))
		foot.add_child(Util.mesh(Util.box(Vector3(0.2, 0.08, 0.16)), hull, Vector3(0, 0.12, -0.06)))
		var toe := Util.mesh(Util.box(Vector3(0.26, 0.07, 0.14)), hull.darkened(0.1), Vector3(0, 0.04, 0.3))
		toe.rotation.x = 0.2
		foot.add_child(toe)
		feet.append(foot)

	# Long arms ending in fists that wrap the hilt
	for side in [-1.0, 1.0]:
		var upper := Util.mesh(Util.box(Vector3(0.13, ARM_UPPER + 0.06, 0.14)), hull, Vector3.ZERO)
		var lower := Util.mesh(Util.box(Vector3(0.15, ARM_LOWER + 0.04, 0.16)), hull.darkened(0.05), Vector3.ZERO)
		lower.add_child(Util.mesh(Util.box(Vector3(0.17, 0.05, 0.18)), accent, Vector3(0, -ARM_LOWER * 0.25, 0)))
		arms.append([upper, lower])
		body_root.add_child(upper)
		body_root.add_child(lower)
		var hand := Node3D.new()
		body_root.add_child(hand)
		hand.add_child(Util.mesh(Util.box(Vector3(0.16, 0.17, 0.17)), frame, Vector3.ZERO))
		hands.append(hand)

	# The sword: long straight-backed blade, square guard, wrapped hilt. Origin = right-hand grip, +Y = blade.
	sword = Node3D.new()
	body_root.add_child(sword)
	sword.add_child(Util.mesh(Util.box(Vector3(0.06, 0.42, 0.06)), Color(0.12, 0.1, 0.1), Vector3(0, -0.12, 0)))       # hilt
	sword.add_child(Util.mesh(Util.box(Vector3(0.16, 0.03, 0.14)), Color(0.55, 0.45, 0.2), Vector3(0, 0.1, 0)))        # guard
	var blade_c := Color(0.72, 0.75, 0.8) if not enemy else Color(0.45, 0.42, 0.48)
	sword.add_child(Util.mesh(Util.box(Vector3(0.025, BLADE, 0.09)), blade_c, Vector3(0, 0.12 + BLADE * 0.5, 0)))
	var edge := Util.glow(Util.box(Vector3(0.03, BLADE * 0.95, 0.015)), Color(0.85, 0.9, 1.0) if not enemy else Color(1.0, 0.45, 0.5), Vector3(0, 0.12 + BLADE * 0.5, 0.05))
	sword.add_child(edge)
	_pose_sword(1.0)


## Where the blade is in the world: [base, tip].
func blade_world() -> Array:
	return [sword.to_global(Vector3(0, 0.3, 0)), sword.to_global(Vector3(0, 0.12 + BLADE, 0))]


func set_eye(c: Color) -> void:
	eye_mat.albedo_color = c


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


static func _lerp_pose(a: Array, b: Array, u: float) -> Array:
	var d: Vector3 = (a[1] as Vector3).normalized().lerp((b[1] as Vector3).normalized(), u)
	if d.length() < 0.05:
		d = b[1]
	return [(a[0] as Vector3).lerp(b[0], u), d.normalized()]


## Where the sword should be right now, from the fighter's state.
func _sword_target() -> Array:
	var f := fighter
	var st: int = f.swing_stance if f.swing != 0 else f.stance
	if f.dead:
		return DEAD_POSE
	match f.swing:
		1:  # windup
			var u: float = 1.0 - f.swing_t / maxf(f.swing_len, 0.001)
			return _lerp_pose(IDLE[st], WINDUP[st], ease(u, 0.4))
		2:  # strike: two-step arc so the blade travels through the swing, not across it
			var u: float = 1.0 - f.swing_t / maxf(f.swing_len, 0.001)
			if u < 0.5:
				return _lerp_pose(WINDUP[st], STRIKE_MID[st], u * 2.0)
			return _lerp_pose(STRIKE_MID[st], STRIKE_END[st], (u - 0.5) * 2.0)
		3:  # recover
			var u: float = 1.0 - f.swing_t / maxf(f.swing_len, 0.001)
			return _lerp_pose(STRIKE_END[st], IDLE[f.stance], ease(u, 2.0))
	if f.guarding:
		return GUARD
	if f.is_running():
		return RUN_POSE
	return IDLE[f.stance]


func _pose_sword(k: float) -> void:
	var target := _sword_target()
	grip = grip.lerp(target[0], k)
	blade_dir = blade_dir.lerp(target[1], k).normalized()
	var side := Vector3.UP.cross(blade_dir)
	if side.length() < 0.1:
		side = Vector3.RIGHT
	side = side.normalized()
	var fwd := side.cross(blade_dir).normalized()
	sword.transform = Transform3D(Basis(side, blade_dir, fwd), grip)


## Heavy walk, strafing, stances and swings.
func animate(delta: float) -> void:
	var f := fighter
	var t := Time.get_ticks_msec() * 0.001
	var s: float = scale.x
	var local_v: Vector3 = global_basis.inverse() * f.velocity * s  # model meters per second
	var hv := Vector2(local_v.x, local_v.z)
	var hs := hv.length()
	var running: bool = f.is_running()
	var moving: bool = hs > 0.15 and f.is_on_floor() and not f.dead
	if moving:
		walk_phase += hs * delta * (1.7 if running else 2.4)

	var body_y := 0.0
	var lean := 0.04
	var twist := 0.0
	var sway := 0.0
	if f.dead:
		body_y = -1.0
		lean = 1.2
	elif moving:
		body_y = -absf(sin(walk_phase)) * (0.08 if running else 0.04)
		lean = 0.25 if running else 0.08
		sway = sin(walk_phase) * 0.04
	else:
		body_y = sin(t * 1.3) * 0.01
	if f.guarding:
		body_y -= 0.12
		lean += 0.06
	if f.crippled and not f.dead:
		body_y -= 0.3
		sway += 0.12
	if f.stagger > 0.0 and not f.dead:
		lean -= 0.3
	match f.swing:
		1:
			twist = [0.0, 0.45, 0.3][f.swing_stance]
			lean -= 0.05
		2:
			twist = [0.0, -0.5, -0.2][f.swing_stance]
			lean += 0.25
	var k := clampf(9.0 * delta, 0.0, 1.0)
	var kb := clampf((25.0 if f.swing == 2 else 9.0) * delta, 0.0, 1.0)
	body_root.position.y = lerp(body_root.position.y, body_y, k)
	body_root.position.z = lerp(body_root.position.z, 0.6 if f.dead else 0.0, k * 0.5)
	body_root.rotation.x = lerp_angle(body_root.rotation.x, lean, kb)
	body_root.rotation.y = lerp_angle(body_root.rotation.y, twist, kb)
	body_root.rotation.z = lerp_angle(body_root.rotation.z, sway, k)

	var head_target := Vector3(-lean * 0.6, -twist * 0.7, -sway)
	head_vel += (head_target - head_rot) * 80.0 * delta
	head_vel -= head_vel * 11.0 * delta
	head_rot += head_vel * delta
	head_pivot.rotation = head_rot

	# Legs: stride along the direction we're actually moving (walks, strafes, backsteps)
	var mdir := Vector3(hv.x, 0, hv.y).normalized() if hs > 0.15 else Vector3.BACK
	step_signal = 0.0
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var foot := Vector3(0.2 * side, 0.0, 0.05)
		if f.guarding or f.swing != 0:
			foot.z += 0.25 if i == 0 else -0.2   # fighting stance: one foot forward
			foot.x *= 1.3
		if f.crippled and i == 0 and not moving:
			foot.z -= 0.35
		var lift_now := 0.0
		if moving:
			var stride := 0.6 if running else 0.4
			foot += mdir * sin(ph) * stride
			lift_now = maxf(0.0, cos(ph)) * (0.28 if running else 0.18)
			foot.y += lift_now
		if _last_lift[i] > 0.02 and lift_now <= 0.02 and moving:
			step_signal = 1.0 if running else 0.5
		_last_lift[i] = lift_now
		feet[i].position = feet[i].position.lerp(foot, clampf(22.0 * delta, 0.0, 1.0))
		var hip := body_root.transform * Vector3(0.17 * side, HIP_HEIGHT - 0.05, 0)
		var ankle: Vector3 = feet[i].position + Vector3(0, 0.14, -0.08)
		_limb(legs[i], hip, ankle, LEG_UPPER, LEG_LOWER, Vector3(0.15 * side, 0, -1))

	# Sword and both hands on the hilt
	var ks := 1.0 if f.swing == 2 else clampf(14.0 * delta, 0.0, 1.0)
	if f.stagger > 0.0 and f.swing == 0 and not f.dead:
		ks = clampf(6.0 * delta, 0.0, 1.0)
	_pose_sword(ks)
	hands[1].position = grip
	hands[0].position = grip - blade_dir * 0.2
	# The body_root is rotated; hands/sword are its children so shoulders stay in body space.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_limb(arms[i], SHOULDER * Vector3(side, 1, 1), hands[i].position, ARM_UPPER, ARM_LOWER, Vector3(0.6 * side, -0.5, -0.8))
