extends RefCounted
## Small helpers shared by every script.

## Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_CAVEMAN := 4


## Art style: rubber hose (ink outlines on robots and props, extra bounce) or plain.
static var rubber := true
const BPM := 112.0               # everything bobs to this beat in rubber hose mode
const OUTLINE := 0.05            # outline thickness in meters
static var _outline_mat: StandardMaterial3D
const PIXEL_VARIANTS := 4
const PIXEL_SCALE := 1.4          # one texture tile covers about 0.7 m, so a pixel is ~4 cm
static var _pixel_textures: Array = []


## Small grayscale-ish noise texture in 2x2 blocks with slight warm/cool tint shifts,
## like hand-painted low-res textures. Multiplies the material color.
static func _pixel_texture(variant: int) -> ImageTexture:
	if _pixel_textures.is_empty():
		for v in PIXEL_VARIANTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + v
			var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
			for by in 8:
				for bx in 8:
					var base := rng.randf_range(0.7, 1.0)
					var warm := rng.randf_range(-0.06, 0.06)
					var c := Color(clampf(base + warm, 0, 1), base, clampf(base - warm, 0, 1))
					img.fill_rect(Rect2i(bx * 2, by * 2, 2, 2), c)
			_pixel_textures.append(ImageTexture.create_from_image(img))
	return _pixel_textures[variant % PIXEL_VARIANTS]


## Rebuilds a smooth primitive with one normal per face, so it looks faceted (low-poly).
static func faceted(m: Mesh) -> Mesh:
	if not (m is PrimitiveMesh):
		return m
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()
static var _shaded: Array = []


## Phase of the shared beat, in radians.
static func beat() -> float:
	return Time.get_ticks_msec() * 0.001 * BPM / 60.0 * TAU


## How exaggerated animation should be right now.
static func amp() -> float:
	return 1.0 if rubber else 0.35


static func set_rubber(tree: SceneTree, on: bool) -> void:
	rubber = on
	for n in tree.get_nodes_in_group("outlines"):
		n.visible = on
	tree.call_group("style_listeners", "on_style_changed", on)


## Call when a scene starts so old materials aren't kept around.
static func reset_style_cache() -> void:
	_shaded.clear()


static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif not unshaded:
		m.roughness = 0.9
		# Chunky pixel texture with mottled color patches, mapped by position so it
		# needs no UVs. Nearest filtering keeps the pixels crisp.
		m.albedo_texture = _pixel_texture(randi() % PIXEL_VARIANTS)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * PIXEL_SCALE
		_shaded.append(m)
	return m


static func _outline() -> StandardMaterial3D:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.albedo_color = Color(0.06, 0.05, 0.04)
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	return _outline_mat


## A mesh with an ink outline: a slightly bigger, inside-out black copy behind it.
static func mesh(m: Mesh, color: Color, pos := Vector3.ZERO, outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	m = faceted(m)
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	if outline and color.a >= 1.0:
		var o := MeshInstance3D.new()
		o.mesh = m
		o.material_override = _outline()
		var sz := m.get_aabb().size
		o.scale = Vector3((sz.x + 2.0 * OUTLINE) / maxf(sz.x, 0.001),
			(sz.y + 2.0 * OUTLINE) / maxf(sz.y, 0.001),
			(sz.z + 2.0 * OUTLINE) / maxf(sz.z, 0.001))
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.visible = rubber
		o.add_to_group("outlines")
		mi.add_child(o)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 8
	c.rings = 2
	return c


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


## A ring that ripples out on the ground to show how far a sound carries.
static func noise_ring(parent: Node, pos: Vector3, radius: float, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 28
	t.ring_segments = 3
	ring.mesh = t
	var m := mat(color, true)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.12
	ring.scale = Vector3(0.3, 0.05, 0.3)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, 0.05, radius), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)
