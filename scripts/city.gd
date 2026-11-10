extends Node3D
## A small night-time Tokyo neighborhood, 3x3 blocks, built at giant-mech scale.
## Low shops and houses come up to a mech's chest; a few apartment blocks tower over it.
##
## Destruction:
##   - Vending machines, cars, poles, lamps and bikes go flying when a mech walks into them.
##   - Bullets chip buildings; enough hits and the building comes down. Misses count.
##   - Running or rolling into a low building smashes through it.
##   - Buildings collapse into tumbling chunks and leave rubble. It's LOUD: every
##     enemy mech within earshot comes to look.

const Util := preload("res://scripts/util.gd")

const PITCH := 48.0          # street center to street center
const STREET := 14.0         # street width (mech-sized)
const LINES := [-72.0, -24.0, 24.0, 72.0]
const HALF := 84.0           # playable area half-size
const MAX_DEBRIS := 140
const DEBRIS_LIFE := 5.0
const COLLAPSE_NOISE := 80.0
const SMASH_MAX_HEIGHT := 13.0   # buildings up to this tall break when you charge into them
const TEX := 0.3                 # texture scale for buildings (one tile ~3 m)

var rng := RandomNumberGenerator.new()
var buildings: Array = []        # StaticBody3D with meta: half (Vector3 half-extents), color
var debris: Array = []           # [RigidBody3D, age]
var props: Array = []
var intersections: Array = []    # street crossing points, for patrols
var destroyed := 0


func build() -> void:
	rng.seed = 2049
	for x in LINES:
		for z in LINES:
			intersections.append(Vector3(x, 0, z))
	_ground()
	for bx in [-48.0, 0.0, 48.0]:
		for bz in [-48.0, 0.0, 48.0]:
			if bx == 0.0 and bz == 0.0:
				_plaza(Vector3.ZERO)
			else:
				_block(Vector3(bx, 0, bz))
	_backdrop()
	_street_props()


# --- Building the city

func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Util.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(HALF * 2 + 80, 1, HALF * 2 + 80)
	shape.shape = bs
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF * 2 + 80, HALF * 2 + 80)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	add_child(Util.mesh(plane, Color(0.17, 0.15, 0.28), Vector3.ZERO, false, 0.25))  # asphalt
	# Invisible walls at the edge of the neighborhood
	for i in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = Util.LAYER_WORLD
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(HALF * 2 + 20, 40, 2) if i < 2 else Vector3(2, 40, HALF * 2 + 20)
		ws.shape = wb
		wall.add_child(ws)
		wall.position = [Vector3(0, 20, -HALF - 1), Vector3(0, 20, HALF + 1), Vector3(-HALF - 1, 20, 0), Vector3(HALF + 1, 20, 0)][i]
		add_child(wall)
	# Road markings: lane dashes and crosswalks, merged into one mesh
	var marks: Array = []
	for l in LINES:
		var a := -HALF
		while a < HALF:
			var near_cross := false
			for c in LINES:
				if absf(a - c) < STREET * 0.6:
					near_cross = true
			if not near_cross:
				marks.append([Vector3(0.4, 0.05, 3.0), Vector3(l, 0.03, a)])
				marks.append([Vector3(3.0, 0.05, 0.4), Vector3(a, 0.03, l)])
			a += 6.0
		for c in LINES:
			for k in 6:
				var off := -5.0 + k * 2.0
				marks.append([Vector3(1.0, 0.05, 2.6), Vector3(l + off, 0.03, c - STREET * 0.5 - 1.8)])
				marks.append([Vector3(2.6, 0.05, 1.0), Vector3(c - STREET * 0.5 - 1.8, 0.03, l + off)])
	var mm := MeshInstance3D.new()
	mm.mesh = Util.merged_boxes(marks)
	mm.material_override = Util.mat(Color(0.5, 0.48, 0.62), true)
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)


## One city block: a sidewalk slab and 3 to 6 buildings packed onto lots.
func _block(c: Vector3) -> void:
	var size := PITCH - STREET   # 34
	var walk := Util.mesh(Util.box(Vector3(size, 0.3, size)), Color(0.33, 0.3, 0.48), c + Vector3(0, 0.15, 0), false, TEX)
	walk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walk)
	# Split the block into lots: 2 or 3 columns, 2 rows
	var cols := rng.randi_range(2, 3)
	var inner := size - 3.0
	var lot_w := inner / cols
	var lot_d := inner / 2.0
	for i in cols:
		for j in 2:
			if rng.randf() < 0.12:
				continue  # empty lot: a gap to sneak through
			var center := c + Vector3(-inner / 2.0 + lot_w * (i + 0.5), 0, -inner / 2.0 + lot_d * (j + 0.5))
			var fw := lot_w - rng.randf_range(1.5, 3.0)
			var fd := lot_d - rng.randf_range(1.5, 3.0)
			var roll := rng.randf()
			var h: float
			var kind: String
			if roll < 0.4:
				kind = "shop"
				h = rng.randf_range(5.0, 8.0)
			elif roll < 0.7:
				kind = "house"
				h = rng.randf_range(5.0, 7.0)
			elif roll < 0.88:
				kind = "office"
				h = rng.randf_range(10.0, 14.0)
			else:
				kind = "tower"
				h = rng.randf_range(18.0, 26.0)
			_building(center, Vector3(fw, h, fd), kind)


func _building(center: Vector3, size: Vector3, kind: String) -> void:
	var palettes := {
		# Dark deco: slate indigo, plum, deep teal-gray, and red brick
		"shop": [Color(0.46, 0.14, 0.11), Color(0.36, 0.34, 0.54), Color(0.42, 0.24, 0.4), Color(0.52, 0.22, 0.13)],
		"house": [Color(0.38, 0.35, 0.55), Color(0.44, 0.13, 0.1), Color(0.3, 0.35, 0.46)],
		"office": [Color(0.32, 0.31, 0.5), Color(0.44, 0.13, 0.1), Color(0.28, 0.33, 0.44)],
		"tower": [Color(0.34, 0.32, 0.54), Color(0.25, 0.27, 0.4), Color(0.42, 0.13, 0.1)],
	}
	var pal: Array = palettes[kind]
	var color: Color = pal[rng.randi() % pal.size()]
	var body := StaticBody3D.new()
	body.collision_layer = Util.LAYER_WORLD
	body.position = center + Vector3(0, size.y / 2.0, 0)
	body.set_meta("half", size / 2.0)
	body.set_meta("color", color)
	body.set_meta("kind", kind)
	body.set_meta("hp", clampi(int(size.x * size.y * size.z / 300.0), 6, 30))
	body.add_to_group("breakable")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	# Cut the walls into ~4 m tiles so the PS1 texture warp stays wobbly but readable
	var bm := Util.box(size)
	bm.subdivide_width = int(size.x / 4.0)
	bm.subdivide_height = int(size.y / 4.0)
	bm.subdivide_depth = int(size.z / 4.0)
	body.add_child(Util.mesh(bm, color, Vector3.ZERO, false, TEX))

	# Windows: rows of dark panes with a few warm lit ones (two merged meshes)
	var dark: Array = []
	var lit: Array = []
	var floors := int(size.y / 3.2)
	var hx := size.x / 2.0
	var hz := size.z / 2.0
	for f in floors:
		var y := -size.y / 2.0 + 1.9 + f * 3.2
		if kind == "shop" and f == 0:
			continue  # storefront instead
		for face in 4:
			var along := size.x if face < 2 else size.z
			var n := int(along / 3.0)
			for w in n:
				var a := -along / 2.0 + (w + 0.5) * along / n
				var pane: Array
				if face == 0:
					pane = [Vector3(1.5, 1.4, 0.1), Vector3(a, y, hz + 0.02)]
				elif face == 1:
					pane = [Vector3(1.5, 1.4, 0.1), Vector3(a, y, -hz - 0.02)]
				elif face == 2:
					pane = [Vector3(0.1, 1.4, 1.5), Vector3(hx + 0.02, y, a)]
				else:
					pane = [Vector3(0.1, 1.4, 1.5), Vector3(-hx - 0.02, y, a)]
				if rng.randf() < 0.32:
					lit.append(pane)
				else:
					dark.append(pane)
	if dark.size() > 0:
		var dm := MeshInstance3D.new()
		dm.mesh = Util.merged_boxes(dark)
		dm.material_override = Util.mat(Color(0.03, 0.02, 0.06), true)
		dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(dm)
	if lit.size() > 0:
		var lm := MeshInstance3D.new()
		lm.mesh = Util.merged_boxes(lit)
		lm.material_override = Util.mat([Color(1.0, 0.84, 0.4), Color(0.98, 0.9, 0.62)][rng.randi() % 2], true)   # warm yellow
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(lm)

	match kind:
		"house":
			# Pitched tile roof
			var roof := PrismMesh.new()
			roof.size = Vector3(size.x + 1.0, 2.6, size.z + 1.0)
			var rc: Color = [Color(0.2, 0.2, 0.36), Color(0.45, 0.12, 0.1), Color(0.16, 0.14, 0.22)][rng.randi() % 3]
			body.add_child(Util.mesh(roof, rc, Vector3(0, size.y / 2.0 + 1.3, 0), false, TEX))
		"shop":
			# Lit storefront and a striped awning on the front (+Z) side
			var front := Util.glow(Util.box(Vector3(size.x * 0.8, 2.4, 0.1)), [Color(1.0, 0.88, 0.55), Color(1.0, 0.8, 0.45), Color(0.95, 0.92, 0.75)][rng.randi() % 3], Vector3(0, -size.y / 2.0 + 1.5, hz + 0.03))
			body.add_child(front)
			var aw := Util.mesh(Util.box(Vector3(size.x * 0.9, 0.2, 1.6)), [Color(0.7, 0.12, 0.1), Color(0.2, 0.18, 0.4), Color(0.12, 0.1, 0.14)][rng.randi() % 3], Vector3(0, -size.y / 2.0 + 3.1, hz + 0.8), false, TEX)
			aw.rotation.x = 0.2
			body.add_child(aw)
			_sign(body, size, rng.randf() < 0.6)
		"office", "tower":
			# Rooftop clutter: water tank, AC units
			body.add_child(Util.mesh(Util.box(Vector3(2.5, 1.5, 2.0)), color.darkened(0.3), Vector3(size.x * 0.2, size.y / 2.0 + 0.75, -size.z * 0.15), false, TEX))
			var tank := CylinderMesh.new()
			tank.top_radius = 1.2
			tank.bottom_radius = 1.2
			tank.height = 2.4
			tank.radial_segments = 8
			body.add_child(Util.mesh(tank, Color(0.4, 0.42, 0.45), Vector3(-size.x * 0.2, size.y / 2.0 + 1.2, size.z * 0.15), false, TEX))
			_sign(body, size, true)
	add_child(body)
	buildings.append(body)


## Neon sign: a glowing board with darker "lettering" blocks (no real text).
func _sign(body: Node3D, size: Vector3, vertical: bool) -> void:
	var neon := [Color(1.0, 0.8, 0.3), Color(1.0, 0.25, 0.15), Color(0.95, 0.9, 0.7), Color(1.0, 0.55, 0.15)]   # deco: yellow, red, cream
	var c: Color = neon[rng.randi() % neon.size()]
	var node := Node3D.new()
	if vertical:
		var h := minf(size.y * 0.6, 9.0)
		node.position = Vector3(size.x / 2.0 * (1 if rng.randf() < 0.5 else -1) * 0.7, size.y / 2.0 - h / 2.0 - 0.5, size.z / 2.0 + 0.9)
		node.add_child(Util.glow(Util.box(Vector3(1.4, h, 0.3)), c))
		var glyphs: Array = []
		var n := int(h / 1.6)
		for i in n:
			glyphs.append([Vector3(0.9, 0.9, 0.35), Vector3(0, h / 2.0 - 1.0 - i * 1.6, 0)])
			if rng.randf() < 0.5:
				glyphs.append([Vector3(0.25, 0.6, 0.36), Vector3(0.45, h / 2.0 - 1.0 - i * 1.6, 0)])
		var gm := MeshInstance3D.new()
		gm.mesh = Util.merged_boxes(glyphs)
		gm.material_override = Util.mat(c.darkened(0.6), true)
		node.add_child(gm)
	else:
		node.position = Vector3(0, size.y / 2.0 + 1.0, size.z / 2.0 - 0.3)
		var w := size.x * 0.7
		node.add_child(Util.glow(Util.box(Vector3(w, 1.8, 0.3)), c))
		var glyphs: Array = []
		var n := int(w / 1.6)
		for i in n:
			glyphs.append([Vector3(1.0, 1.0, 0.35), Vector3(-w / 2.0 + 0.9 + i * 1.6, 0, 0)])
		var gm := MeshInstance3D.new()
		gm.mesh = Util.merged_boxes(glyphs)
		gm.material_override = Util.mat(c.darkened(0.6), true)
		node.add_child(gm)
	body.add_child(node)


## The center block is a small plaza: open ground for duels, a few trees and benches.
func _plaza(c: Vector3) -> void:
	var size := PITCH - STREET
	add_child(Util.mesh(Util.box(Vector3(size, 0.3, size)), Color(0.36, 0.32, 0.5), c + Vector3(0, 0.15, 0), false, TEX))
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 12.0
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.35
		trunk.bottom_radius = 0.5
		trunk.height = 4.0
		trunk.radial_segments = 6
		var tree := Node3D.new()
		tree.add_child(Util.mesh(trunk, Color(0.12, 0.08, 0.12), Vector3(0, 2.0, 0)))
		var crown := Util.mesh(Util.sphere(2.6), [Color(0.5, 0.14, 0.2), Color(0.12, 0.1, 0.2)][i % 2], Vector3(0, 5.3, 0))
		crown.scale = Vector3(1.0, 0.75, 1.0)
		tree.add_child(crown)
		_prop(tree, p, 2.5, 4.0)


## Tall indestructible buildings ringing the neighborhood: black deco silhouettes
## against the red sky, with stepped setback crowns, spires and scattered yellow windows.
func _backdrop() -> void:
	var sil := Util.mat(Color(0.05, 0.025, 0.06), true)
	var win := Util.mat(Color(1.0, 0.8, 0.35), true)
	for side in 4:
		var a := -HALF - 10.0
		while a < HALF + 10.0:
			var w := rng.randf_range(10.0, 18.0)
			var h := rng.randf_range(28.0, 60.0)
			var base: Vector3
			if side == 0:
				base = Vector3(a, 0, -HALF - 14)
			elif side == 1:
				base = Vector3(a, 0, HALF + 14)
			elif side == 2:
				base = Vector3(-HALF - 14, 0, a)
			else:
				base = Vector3(HALF + 14, 0, a)
			var parts: Array = [[Vector3(w, h, w), Vector3(0, h / 2.0, 0)]]
			var top := h
			var tw := w
			for step in rng.randi_range(1, 3):        # setbacks
				tw *= rng.randf_range(0.6, 0.78)
				var sh := rng.randf_range(3.0, 8.0)
				parts.append([Vector3(tw, sh, tw), Vector3(0, top + sh / 2.0, 0)])
				top += sh
			if rng.randf() < 0.45:                    # spire
				var sp := rng.randf_range(6.0, 16.0)
				parts.append([Vector3(0.7, sp, 0.7), Vector3(0, top + sp / 2.0, 0)])
			var mi := MeshInstance3D.new()
			mi.mesh = Util.merged_boxes(parts)
			mi.material_override = sil
			mi.position = base
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			var lit: Array = []
			for k in 9:
				lit.append([Vector3(0.9, 1.2, w + 0.1), Vector3(rng.randf_range(-w / 2 + 1, w / 2 - 1), rng.randf_range(3.0, h - 2), 0)])
				lit.append([Vector3(w + 0.1, 1.2, 0.9), Vector3(0, rng.randf_range(3.0, h - 2), rng.randf_range(-w / 2 + 1, w / 2 - 1))])
			var lm := MeshInstance3D.new()
			lm.mesh = Util.merged_boxes(lit)
			lm.material_override = win
			lm.position = base
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lm)
			a += w + rng.randf_range(1.0, 4.0)


## Vending machines, cars, power poles and street lamps along the sidewalks.
func _street_props() -> void:
	for bx in [-48.0, 0.0, 48.0]:
		for bz in [-48.0, 0.0, 48.0]:
			var edge := (PITCH - STREET) / 2.0 - 0.8
			for k in 3:
				var t := rng.randf_range(-edge + 2, edge - 2)
				var which := rng.randi_range(0, 3)
				var p: Vector3
				var yaw := 0.0
				match which:
					0: p = Vector3(bx + t, 0.3, bz + edge)
					1: p = Vector3(bx + t, 0.3, bz - edge)
					2:
						p = Vector3(bx + edge, 0.3, bz + t)
						yaw = PI / 2.0
					_:
						p = Vector3(bx - edge, 0.3, bz + t)
						yaw = PI / 2.0
				var r := rng.randf()
				if r < 0.4:
					_vending(p, yaw)
				elif r < 0.7:
					_pole(p)
				else:
					_lamp(p)
	# Parked cars in the streets
	for i in 14:
		var l: float = LINES[rng.randi() % LINES.size()]
		var a := rng.randf_range(-HALF + 6, HALF - 6)
		var near := false
		for c in LINES:
			if absf(a - c) < STREET:
				near = true
		if near:
			continue
		if rng.randf() < 0.5:
			_car(Vector3(l + (4.0 if rng.randf() < 0.5 else -4.0), 0, a), 0.0)
		else:
			_car(Vector3(a, 0, l + (4.0 if rng.randf() < 0.5 else -4.0)), PI / 2.0)


func _vending(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	var c: Color = [Color(0.85, 0.15, 0.15), Color(0.9, 0.9, 0.92), Color(0.2, 0.4, 0.8)][rng.randi() % 3]
	n.add_child(Util.mesh(Util.box(Vector3(1.1, 1.9, 0.8)), c, Vector3(0, 0.95, 0)))
	n.add_child(Util.glow(Util.box(Vector3(0.9, 1.1, 0.05)), Color(0.95, 0.95, 0.85), Vector3(0, 1.25, 0.42)))
	n.rotation.y = yaw
	_prop(n, p, 1.0, 1.0)


func _car(p: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	var c: Color = [Color(0.85, 0.85, 0.8), Color(0.15, 0.15, 0.18), Color(0.6, 0.1, 0.1), Color(0.3, 0.45, 0.6), Color(0.85, 0.75, 0.2)][rng.randi() % 5]
	n.add_child(Util.mesh(Util.box(Vector3(1.8, 0.8, 4.4)), c, Vector3(0, 0.7, 0)))
	n.add_child(Util.mesh(Util.box(Vector3(1.6, 0.6, 2.2)), c.darkened(0.15), Vector3(0, 1.4, -0.2)))
	n.add_child(Util.glow(Util.box(Vector3(1.5, 0.45, 0.05)), Color(0.1, 0.12, 0.16), Vector3(0, 1.45, 0.92)))
	for s in [-0.6, 0.6]:
		n.add_child(Util.glow(Util.box(Vector3(0.3, 0.15, 0.05)), Color(1, 1, 0.85), Vector3(s, 0.8, 2.22)))
		n.add_child(Util.glow(Util.box(Vector3(0.3, 0.15, 0.05)), Color(0.9, 0.1, 0.1), Vector3(s, 0.8, -2.22)))
	n.rotation.y = yaw
	_prop(n, p, 2.3, 3.0)


func _pole(p: Vector3) -> void:
	var n := Node3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.18
	pole.bottom_radius = 0.22
	pole.height = 10.0
	pole.radial_segments = 6
	n.add_child(Util.mesh(pole, Color(0.45, 0.43, 0.4), Vector3(0, 5.0, 0)))
	n.add_child(Util.mesh(Util.box(Vector3(2.4, 0.15, 0.15)), Color(0.3, 0.3, 0.3), Vector3(0, 9.0, 0)))
	n.add_child(Util.mesh(Util.box(Vector3(0.5, 0.7, 0.5)), Color(0.35, 0.35, 0.37), Vector3(0.4, 8.0, 0)))  # transformer
	_prop(n, p, 0.6, 1.5)


func _lamp(p: Vector3) -> void:
	var n := Node3D.new()
	n.add_child(Util.mesh(Util.box(Vector3(0.2, 6.0, 0.2)), Color(0.2, 0.2, 0.22), Vector3(0, 3.0, 0)))
	n.add_child(Util.mesh(Util.box(Vector3(1.4, 0.15, 0.2)), Color(0.2, 0.2, 0.22), Vector3(0.6, 6.0, 0)))
	n.add_child(Util.glow(Util.box(Vector3(0.6, 0.2, 0.4)), Color(0.92, 0.94, 1.0), Vector3(1.1, 5.9, 0)))
	_prop(n, p, 0.6, 1.0)
	_light_pool(p + Vector3(1.1, 0, 0))


## A pool of cold lamp light painted on the street (cheap: no real light).
var _pool_mat: StandardMaterial3D
func _light_pool(at: Vector3) -> void:
	if _pool_mat == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = smoothstep(0.0, 0.35, a) * 0.85     # flat pool with a short soft edge
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_pool_mat = StandardMaterial3D.new()
		_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pool_mat.albedo_texture = ImageTexture.create_from_image(img)
		_pool_mat.albedo_color = Color(0.26, 0.28, 0.5)
	var q := PlaneMesh.new()
	q.size = Vector2(11, 11)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _pool_mat
	mi.position = Vector3(at.x, 0.37, at.z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Wraps a prop in a frozen rigid body: it stands still until something big hits it.
func _prop(visual: Node3D, p: Vector3, radius: float, mass: float) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = Util.LAYER_DEBRIS
	rb.collision_mask = Util.LAYER_WORLD
	rb.freeze = true
	rb.mass = mass
	rb.position = p
	rb.set_meta("radius", radius)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(radius * 1.4, radius * 1.4, radius * 1.4)
	shape.shape = bs
	shape.position.y = radius * 0.7
	rb.add_child(shape)
	rb.add_child(visual)
	add_child(rb)
	props.append(rb)


# --- Destruction

## A mech is touching this spot: knock nearby props flying. Returns how many went.
func push_props(pos: Vector3, reach: float, vel: Vector3) -> int:
	var n := 0
	for i in range(props.size() - 1, -1, -1):
		var p: RigidBody3D = props[i]
		if not is_instance_valid(p):
			props.remove_at(i)
			continue
		var to := p.global_position - pos
		to.y = 0.0
		if to.length() < reach + p.get_meta("radius"):
			props.remove_at(i)
			var dir := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
			var push := maxf(Vector2(vel.x, vel.z).length(), 6.0)
			_launch(p, (dir + Vector3(vel.x, 0, vel.z).normalized() * 0.5).normalized() * push * 1.3 + Vector3.UP * rng.randf_range(4.0, 8.0))
			n += 1
	if n > 0:
		_noise(pos, 20.0)
	return n


## A blade passes through this point: anything here gets cut. Returns true if something broke.
func cut(point: Vector3, radius: float, from: Vector3) -> bool:
	var hit := false
	for b in buildings.duplicate():
		if _overlaps(b, point, radius):
			collapse(b, from)
			hit = true
	if push_props(point - Vector3(0, point.y, 0), radius, (point - from).normalized() * 12.0) > 0:
		hit = true
	return hit


## A mech rolled into this building. Low ones give way; tall ones need gunfire.
func smash(b: Node, from: Vector3, speed: float) -> bool:
	if not buildings.has(b) or speed < 7.0:
		return false
	var half: Vector3 = b.get_meta("half")
	if half.y * 2.0 > SMASH_MAX_HEIGHT:
		return false
	collapse(b, from)
	return true


## A bullet hit a building: chips fly, and it comes down when it runs out of hits.
func shoot_building(b: Node3D, at: Vector3, from: Vector3) -> void:
	if not buildings.has(b):
		return
	var hp: int = b.get_meta("hp") - 1
	b.set_meta("hp", hp)
	var color: Color = b.get_meta("color")
	var away := (from - at).normalized()
	for i in 2:
		var rb := RigidBody3D.new()
		rb.collision_layer = Util.LAYER_DEBRIS
		rb.collision_mask = Util.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * 0.8
		shape.shape = bs
		rb.add_child(shape)
		var mi := MeshInstance3D.new()
		mi.mesh = Util.box(Vector3.ONE * 0.8)
		mi.material_override = Util.mat(color.darkened(0.2))
		rb.add_child(mi)
		add_child(rb)
		rb.global_position = at + away * 0.6
		_launch(rb, away * rng.randf_range(4, 9) + Vector3(rng.randf_range(-3, 3), rng.randf_range(2, 6), rng.randf_range(-3, 3)))
	if hp <= 0:
		collapse(b, from)


## Props near a bullet's path get knocked over.
func shot_props(from: Vector3, to: Vector3) -> void:
	var seg := to - from
	var len := seg.length()
	if len < 0.1:
		return
	var dir := seg / len
	for i in range(props.size() - 1, -1, -1):
		var p: RigidBody3D = props[i]
		if not is_instance_valid(p):
			props.remove_at(i)
			continue
		var c := p.global_position + Vector3.UP * float(p.get_meta("radius"))
		var t := clampf((c - from).dot(dir), 0.0, len)
		if (from + dir * t).distance_to(c) < float(p.get_meta("radius")) + 0.5:
			props.remove_at(i)
			_launch(p, dir * 14.0 + Vector3.UP * 5.0)


## Bright streak from muzzle to impact for a split second.
func tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var len := from.distance_to(to)
	if len < 0.5:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Util.box(Vector3(0.12, 0.12, len))
	mi.material_override = Util.mat(color, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), 0.07)
	tw.tween_callback(mi.queue_free)


## Spark puff where a bullet lands. Hits on mechs are bigger and hotter.
func impact(at: Vector3, on_mech: bool) -> void:
	var n := 6 if on_mech else 3
	var c := Color(1.0, 0.6, 0.2) if on_mech else Color(0.9, 0.85, 0.7)
	for i in n:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3.ONE * (0.5 if on_mech else 0.3))
		sp.material_override = Util.mat(c, true)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		sp.global_position = at
		var tw := sp.create_tween()
		tw.tween_property(sp, "global_position", at + Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 1), rng.randf_range(-1, 1)) * (3.0 if on_mech else 1.5), 0.22)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * 0.1, 0.22)
		tw.tween_callback(sp.queue_free)


## OIL. Thick black gouts arcing out of a wound, landing as puddles on the street.
var _oil_mat: StandardMaterial3D
var _oil_amber: StandardMaterial3D
var _puddles: Array = []
const MAX_PUDDLES := 70


func oil(at: Vector3, dir: Vector3, n: int) -> void:
	if _oil_mat == null:
		_oil_mat = Util.mat(Color(0.03, 0.03, 0.04))
		_oil_mat.metallic = 0.6
		_oil_mat.roughness = 0.15
	if _oil_amber == null:
		_oil_amber = Util.mat(Color(0.45, 0.28, 0.06))
		_oil_amber.metallic = 0.5
		_oil_amber.roughness = 0.2
	for i in n:
		var d := MeshInstance3D.new()
		d.mesh = Util.box(Vector3.ONE * rng.randf_range(0.25, 0.7))
		d.material_override = _oil_mat if rng.randf() < 0.65 else _oil_amber   # black with dirty amber
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		d.global_position = at
		var v := (dir + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.2, 0.8), rng.randf_range(-0.6, 0.6))).normalized() * rng.randf_range(6.0, 16.0)
		var t := rng.randf_range(0.5, 0.9)
		# Ballistic arc: x/z straight, y up then down
		var land := at + Vector3(v.x, 0, v.z) * t
		land.y = 0.05
		var peak := at + Vector3(v.x, 0, v.z) * t * 0.5 + Vector3.UP * maxf(v.y, 2.0) * t * 0.35
		var tw := d.create_tween()
		tw.tween_property(d, "global_position", peak, t * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(d, "global_position", land, t * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func():
			if i % 3 == 0:
				_puddle(land, rng.randf_range(0.8, 2.2))
			d.queue_free())


func _puddle(at: Vector3, size: float) -> void:
	var p := MeshInstance3D.new()
	p.mesh = Util.box(Vector3(size, 0.04, size * rng.randf_range(0.6, 1.4)))
	p.material_override = _oil_mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.rotation.y = rng.randf() * TAU
	add_child(p)
	p.global_position = Vector3(at.x, 0.06, at.z)
	_puddles.append(p)
	while _puddles.size() > MAX_PUDDLES:
		var old: Node = _puddles.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## A stump keeps gushing in pulses for a while.
func oil_fountain(stump: Node3D, seconds: float) -> void:
	var pulses := int(seconds / 0.12)
	var tw := create_tween()
	for i in pulses:
		tw.tween_interval(0.12)
		tw.tween_callback(func():
			if is_instance_valid(stump) and stump.is_inside_tree():
				var up := stump.global_basis.y.normalized() if stump.global_basis.y.length() > 0.1 else Vector3.UP
				oil(stump.global_position, (up + Vector3.UP).normalized(), 3))


## Hot sparks flying off steel.
func sparks(at: Vector3, n: int, color: Color) -> void:
	for i in n:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3(0.12, 0.12, rng.randf_range(0.5, 1.4)))
		sp.material_override = Util.mat(color, true)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		sp.global_position = at
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		var end := at + dir * rng.randf_range(3.0, 9.0) + Vector3.DOWN * 1.5
		if (end - at).length() > 0.1:
			sp.look_at_from_position(at, end, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		var tw := sp.create_tween()
		tw.tween_property(sp, "global_position", end, rng.randf_range(0.18, 0.35))
		tw.parallel().tween_property(sp, "scale", Vector3(0.2, 0.2, 0.2), 0.3)
		tw.tween_callback(sp.queue_free)


## Mech goes down: a fireball of chunky cubes.
func burst(at: Vector3) -> void:
	for i in 18:
		var sp := MeshInstance3D.new()
		sp.mesh = Util.box(Vector3.ONE * rng.randf_range(0.8, 1.8))
		sp.material_override = Util.mat([Color(1.0, 0.75, 0.2), Color(1.0, 0.4, 0.1), Color(0.9, 0.2, 0.1)][i % 3], true)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		sp.global_position = at
		var tw := sp.create_tween()
		tw.tween_property(sp, "global_position", at + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(4.0, 9.0), 0.45)
		tw.parallel().tween_property(sp, "scale", Vector3.ONE * 0.1, 0.45)
		tw.tween_callback(sp.queue_free)


func _overlaps(b: Node3D, point: Vector3, radius: float) -> bool:
	var half: Vector3 = b.get_meta("half")
	var d := (point - b.global_position).abs() - half
	return d.x < radius and d.y < radius and d.z < radius


## Brings a building down: it breaks into tumbling chunks and leaves rubble.
func collapse(b: Node3D, from: Vector3) -> void:
	if not buildings.has(b):
		return
	buildings.erase(b)
	destroyed += 1
	var half: Vector3 = b.get_meta("half")
	var color: Color = b.get_meta("color")
	var center := b.global_position
	var away := center - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var mat := Util.psx(color, TEX)
	var dark_mat := Util.psx(color.darkened(0.45), TEX)
	var nx := clampi(int(half.x * 2.0 / 3.5), 2, 3)
	var ny := clampi(int(half.y * 2.0 / 3.5), 2, 4)
	var nz := clampi(int(half.z * 2.0 / 3.5), 2, 3)
	var cs := Vector3(half.x * 2.0 / nx, half.y * 2.0 / ny, half.z * 2.0 / nz)
	for ix in nx:
		for iy in ny:
			for iz in nz:
				var p := center - half + Vector3((ix + 0.5) * cs.x, (iy + 0.5) * cs.y, (iz + 0.5) * cs.z)
				var rb := RigidBody3D.new()
				rb.collision_layer = Util.LAYER_DEBRIS
				rb.collision_mask = Util.LAYER_WORLD
				rb.mass = 20.0
				var csz := cs * rng.randf_range(0.75, 0.95)
				var shape := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = csz
				shape.shape = bs
				rb.add_child(shape)
				var mi := MeshInstance3D.new()
				mi.mesh = Util.faceted(Util.box(csz))
				mi.material_override = dark_mat if rng.randf() < 0.3 else mat
				rb.add_child(mi)
				add_child(rb)
				rb.global_position = p
				var up := float(iy) / ny
				_launch(rb, away * rng.randf_range(2.0, 7.0) * (0.5 + up) + Vector3(rng.randf_range(-2, 2), rng.randf_range(0.0, 4.0) * up, rng.randf_range(-2, 2)))
	# Rubble pile left behind (no collision: mechs wade through it)
	var rubble: Array = []
	for i in 7:
		var s := Vector3(rng.randf_range(2.0, 4.5), rng.randf_range(0.6, 1.8), rng.randf_range(2.0, 4.5))
		rubble.append([s, Vector3(rng.randf_range(-half.x, half.x) * 0.8, s.y * 0.4, rng.randf_range(-half.z, half.z) * 0.8)])
	var pile := MeshInstance3D.new()
	pile.mesh = Util.faceted(Util.merged_boxes(rubble))
	pile.material_override = dark_mat
	pile.position = Vector3(center.x, 0.0, center.z)
	add_child(pile)
	_dust(center - Vector3(0, half.y * 0.5, 0), maxf(half.x, half.z))
	b.queue_free()
	_noise(center, COLLAPSE_NOISE)
	get_tree().call_group("shakers", "add_shake", 0.6)


func _launch(rb: RigidBody3D, v: Vector3) -> void:
	rb.freeze = false
	rb.linear_velocity = v
	rb.angular_velocity = Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), rng.randf_range(-3, 3))
	debris.append([rb, 0.0])
	while debris.size() > MAX_DEBRIS:
		var old: Array = debris.pop_front()
		if is_instance_valid(old[0]):
			old[0].queue_free()


func _dust(at: Vector3, size: float) -> void:
	for i in 8:
		var d := MeshInstance3D.new()
		d.mesh = Util.box(Vector3.ONE * size * 0.6)
		d.material_override = Util.mat(Color(0.55, 0.53, 0.5, 0.5))
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		d.global_position = at + Vector3(rng.randf_range(-size, size), rng.randf_range(0, size * 0.5), rng.randf_range(-size, size))
		var tw := d.create_tween()
		tw.tween_property(d, "scale", Vector3.ONE * 2.2, 1.4)
		tw.parallel().tween_property(d, "position:y", d.position.y + 4.0, 1.4)
		tw.parallel().tween_property(d.material_override, "albedo_color:a", 0.0, 1.4)
		tw.tween_callback(d.queue_free)


## Black smoke column from a wrecked mech.
func smoke(at: Vector3) -> void:
	for i in 10:
		var d := MeshInstance3D.new()
		d.mesh = Util.box(Vector3.ONE * 2.0)
		d.material_override = Util.mat(Color(0.08, 0.08, 0.09, 0.7))
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
		d.global_position = at
		var tw := d.create_tween()
		tw.tween_interval(i * 0.25)
		tw.tween_property(d, "global_position", at + Vector3(rng.randf_range(-2, 2), 10.0 + i, rng.randf_range(-2, 2)), 3.0)
		tw.parallel().tween_property(d, "scale", Vector3.ONE * 3.0, 3.0)
		tw.parallel().tween_property(d.material_override, "albedo_color:a", 0.0, 3.0)
		tw.tween_callback(d.queue_free)


func _noise(pos: Vector3, radius: float) -> void:
	get_tree().call_group("enemies", "hear_noise", pos, radius, self)


func _physics_process(delta: float) -> void:
	# Old debris settles, then sinks away so the scene stays light
	for i in range(debris.size() - 1, -1, -1):
		var d: Array = debris[i]
		var rb: RigidBody3D = d[0]
		if not is_instance_valid(rb):
			debris.remove_at(i)
			continue
		d[1] += delta
		if d[1] > DEBRIS_LIFE and not rb.freeze:
			rb.freeze = true
			var tw := rb.create_tween()
			tw.tween_property(rb, "position:y", rb.position.y - 6.0, 2.0)
			tw.tween_callback(rb.queue_free)
			debris.remove_at(i)


## Is there a clear line between two points (buildings block it)?
func clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Util.LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Street crossings next to this one (for patrol routes along the streets).
func neighbors(p: Vector3) -> Array:
	var out: Array = []
	for q in intersections:
		var d: Vector3 = q - p
		if absf(d.length() - PITCH) < 1.0 and (absf(d.x) < 1.0 or absf(d.z) < 1.0):
			out.append(q)
	return out


func nearest_intersection(p: Vector3) -> Vector3:
	var best: Vector3 = intersections[0]
	for q in intersections:
		if (q - p).length() < (best - p).length():
			best = q
	return best
