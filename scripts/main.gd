extends Node3D
## Builds the night-time snowy woods (PS1 horror look), the player, the robots and the HUD.
## Placeholder shapes on purpose: we're testing fun, not final art.

const Util := preload("res://scripts/util.gd")
const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const GathererScript := preload("res://scripts/gatherer.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const ARENA := 50.0
const LAMP_SPOTS := [Vector3(-7, 0, -5), Vector3(9, 0, 4), Vector3(-4, 0, 11), Vector3(14, 0, -14)]
const LAMP_RADIUS := 5.0
const GATHERER_SPOTS := [Vector3(-10, 0, -12), Vector3(12, 0, -8), Vector3(2, 0, 14), Vector3(-15, 0, 8), Vector3(15, 0, 13)]

var player: CharacterBody3D
var caught := 0
var count_label: Label
var mode_label: Label
var alert_label: Label
var game_over := false
var hint_label: Label
var hold_bar: ProgressBar
var snow_emitter: CPUParticles3D
var ps1: ColorRect
var message_label: Label
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Controls.setup()
	Util.reset_style_cache()
	rng.seed = 7
	_build_environment()
	_build_ground()
	_build_cover()
	_spawn_player()
	_spawn_gatherers()
	_build_ps1()
	_build_hud()
	_build_debug()
	if use_touch():
		_build_touch()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	_update_debug()
	_update_alert()
	if Input.is_action_just_pressed("style"):
		Util.set_rubber(get_tree(), not Util.rubber)
	if snow_emitter and player:
		snow_emitter.global_position = player.global_position + Vector3(0, 9, 0)
	if player and mode_label:
		mode_label.text = player.move_mode + ("   |   LIT UP" if player.is_lit() else "   |   in the dark")
		var loud: bool = player.move_mode.begins_with("Running")
		var silent: bool = player.move_mode.contains("silent")
		mode_label.modulate = Color(1, 0.45, 0.35) if loud else (Color(0.6, 1, 0.7) if silent else Color.WHITE)


## PS1-style screen: low resolution with chunky pixels and a little color dithering.
func _build_ps1() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	ps1 = ColorRect.new()
	ps1.set_anchors_preset(Control.PRESET_FULL_RECT)
	ps1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ps1.gdshader")
	ps1.material = sm
	layer.add_child(ps1)


## Is this spot inside a lamp's pool of light?
func in_lamp_light(pos: Vector3) -> bool:
	for l in LAMP_SPOTS:
		if Vector2(pos.x - l.x, pos.z - l.z).length() < LAMP_RADIUS:
			return true
	return false


## Phones and tablets get on-screen controls (?touch in the web address forces them on).
static func use_touch() -> bool:
	if OS.has_feature("web") and JavaScriptBridge.eval("location.search.includes('touch')", true):
		return true
	return DisplayServer.is_touchscreen_available()


func _build_touch() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var t := Control.new()
	t.set_script(TouchScript)
	t.player = player
	layer.add_child(t)
	hint_label.visible = false


# --- Controller debug readout (top right). Remove once controls are solid on the Thor.

var debug_label: Label
var last_raw := "nothing yet"


func _build_debug() -> void:
	var layer := CanvasLayer.new()
	layer.visible = not OS.has_feature("web") and not use_touch()
	layer.layer = 10
	add_child(layer)
	debug_label = Label.new()
	debug_label.anchor_left = 1.0
	debug_label.anchor_right = 1.0
	debug_label.offset_left = -460
	debug_label.offset_right = -16
	debug_label.offset_top = 12
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_constant_override("outline_size", 5)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	layer.add_child(debug_label)


## Remembers the last raw input event of any kind, so we can see what the Thor sends.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and abs(event.axis_value) < 0.3:
		return
	if event is InputEventMouseMotion:
		return
	last_raw = event.as_text()
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_raw += " (pad %d)" % event.device


func _update_debug() -> void:
	var pads := Input.get_connected_joypads()
	var lines: PackedStringArray = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	if pads.is_empty():
		lines.append("NO CONTROLLER DETECTED")
	for id in pads:
		lines.append("Pad %d: %s" % [id, Input.get_joy_name(id)])
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	lines.append("Move (%.1f, %.1f)  Look (%.1f, %.1f)" % [move.x, move.y, look.x, look.y])
	var held: PackedStringArray = []
	for a in ["crouch", "net", "restart"]:
		if Input.is_action_pressed(a):
			held.append(a)
	lines.append("Held: " + (", ".join(held) if held.size() > 0 else "-"))
	lines.append("Last input: " + last_raw)
	debug_label.text = "\n".join(lines)


func _build_environment() -> void:
	# Night: near-black sky, cold dim ambient, thick dark fog that swallows the distance
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.36, 0.5)
	env.ambient_light_energy = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.035, 0.05)
	env.fog_density = 0.075
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Weak blue moonlight
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_energy = 0.14
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.shadow_enabled = true
	add_child(moon)


func _build_ground() -> void:
	_static_box(Vector3(ARENA + 20, 1, ARENA + 20), Vector3(0, -0.5, 0), Color(0.8, 0.84, 0.9))  # snow
	# Dense dark pines all around the edge (the fog hides how fake it is)
	var h := ARENA / 2.0
	var wall := Color(0.04, 0.07, 0.05)
	_static_box(Vector3(ARENA + 4, 8, 2), Vector3(0, 4, -h - 1), wall)
	_static_box(Vector3(ARENA + 4, 8, 2), Vector3(0, 4, h + 1), wall)
	_static_box(Vector3(2, 8, ARENA), Vector3(-h - 1, 4, 0), wall)
	_static_box(Vector3(2, 8, ARENA), Vector3(h + 1, 4, 0), wall)


## Rocks, pines and lamp posts. Rocks and trees block robot eyesight; lamps light you up.
func _build_cover() -> void:
	for i in 14:
		var p := _random_spot()
		var size := Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(1.2, 2.8), rng.randf_range(1.5, 4.0))
		var rock := _static_box(size, p + Vector3(0, size.y / 2.0, 0), Color(0.3, 0.3, 0.32))
		rock.rotation.y = rng.randf() * TAU
		rock.add_child(Util.mesh(Util.box(Vector3(size.x * 0.92, 0.12, size.z * 0.92)), Color(0.85, 0.88, 0.93), Vector3(0, size.y / 2.0 + 0.05, 0)))  # snow cap
	for i in 22:
		_pine(_random_spot())
	for spot in LAMP_SPOTS:
		_lamp(spot)
	_snowfall()


func _pine(p: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Util.LAYER_WORLD
	body.position = p
	add_child(body)
	var height := rng.randf_range(5.0, 8.0)
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.4
	cyl_shape.height = height
	shape.shape = cyl_shape
	shape.position.y = height / 2.0
	body.add_child(shape)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.3
	trunk.height = height * 0.35
	trunk.radial_segments = 6
	body.add_child(Util.mesh(trunk, Color(0.2, 0.14, 0.1), Vector3(0, height * 0.175, 0)))
	# Three stacked tiers of branches, each dusted with snow
	for tier in 3:
		var r := 1.8 - tier * 0.5
		var tier_h := height * 0.38
		var y := height * 0.25 + tier * height * 0.22
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = r
		cone.height = tier_h
		cone.radial_segments = 7
		body.add_child(Util.mesh(cone, Color(0.07, 0.15, 0.1), Vector3(0, y + tier_h / 2.0, 0)))
		var snow := CylinderMesh.new()
		snow.top_radius = 0.0
		snow.bottom_radius = r * 0.55
		snow.height = tier_h * 0.45
		snow.radial_segments = 7
		body.add_child(Util.mesh(snow, Color(0.82, 0.86, 0.92), Vector3(0, y + tier_h * 0.8, 0)))


## A lamp post with a warm pool of light. Standing in it lets robots see you from far away.
func _lamp(p: Vector3) -> void:
	var post := _static_box(Vector3(0.15, 3.2, 0.15), p + Vector3(0, 1.6, 0), Color(0.15, 0.15, 0.16))
	post.add_to_group("lamps")
	var head := MeshInstance3D.new()
	head.mesh = Util.box(Vector3(0.4, 0.3, 0.4))
	head.material_override = Util.mat(Color(1.0, 0.82, 0.5), true)
	head.position = Vector3(0, 1.7, 0)
	post.add_child(head)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 0)
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 3.5
	light.omni_range = LAMP_RADIUS + 2.5
	light.omni_attenuation = 1.2
	post.add_child(light)


## Snow falling around the player.
func _snowfall() -> void:
	var snow := CPUParticles3D.new()
	snow.amount = 450
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(14, 0.5, 14)
	snow.direction = Vector3(0.15, -1, 0)
	snow.spread = 12.0
	snow.gravity = Vector3(0, -0.6, 0)
	snow.initial_velocity_min = 0.8
	snow.initial_velocity_max = 1.4
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.9, 0.93, 1.0)
	flake.material = m
	snow.mesh = flake
	snow.position = Vector3(0, 9, 0)
	snow_emitter = snow
	add_child(snow)


func _random_spot() -> Vector3:
	# Keep the middle open near the player start, and away from walls.
	while true:
		var p := Vector3(rng.randf_range(-21, 21), 0, rng.randf_range(-21, 21))
		var clear := p.length() > 5.0
		for l in LAMP_SPOTS:
			if p.distance_to(l) < 3.0:
				clear = false
		if clear:
			return p
	return Vector3.ZERO


func _static_box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Util.LAYER_WORLD
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(Util.mesh(Util.box(size), color))
	add_child(body)
	return body


func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	player.caught_one.connect(_on_caught)


func _spawn_gatherers() -> void:
	for spot in GATHERER_SPOTS:
		var g := CharacterBody3D.new()
		g.set_script(GathererScript)
		g.position = spot + Vector3(0, 0.1, 0)
		add_child(g)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	count_label = Label.new()
	count_label.position = Vector2(24, 18)
	count_label.add_theme_font_size_override("font_size", 34)
	count_label.add_theme_constant_override("outline_size", 8)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(count_label)

	mode_label = Label.new()
	mode_label.position = Vector2(24, 62)
	mode_label.add_theme_font_size_override("font_size", 24)
	mode_label.add_theme_constant_override("outline_size", 6)
	mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(mode_label)


	alert_label = Label.new()
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_label.offset_top = 70
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 40)
	alert_label.add_theme_constant_override("outline_size", 10)
	alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(alert_label)

	hold_bar = ProgressBar.new()
	hold_bar.min_value = 0.0
	hold_bar.max_value = 1.0
	hold_bar.show_percentage = false
	hold_bar.custom_minimum_size = Vector2(320, 22)
	hold_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hold_bar.offset_left = -160
	hold_bar.offset_right = 160
	hold_bar.offset_top = 125
	hold_bar.offset_bottom = 147
	hold_bar.visible = false
	layer.add_child(hold_bar)


	hint_label = Label.new()
	var hint := hint_label
	hint.text = "Move: L-stick (light tilt = sneak)  Jump: A  Crouch: L1/L2  Grab: R1/R2  Light: Y  Look: R-stick  Style: Select  Restart: Start"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -44
	hint.offset_left = 24
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(hint)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 52)
	message_label.add_theme_constant_override("outline_size", 12)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(message_label)

	_update_hud()


## Spotted robots just run (Ape Escape style). The top banner is only used for the headlock.
func _update_alert() -> void:
	# Headlock prompt and wind-down meter
	var held: bool = player != null and player.holding != null
	if hold_bar:
		hold_bar.visible = held
	if held:
		alert_label.text = "Tap GRAB to wind him down!"
		alert_label.modulate = Color(1, 0.8, 0.3)
		hold_bar.value = player.hold_progress
	elif alert_label:
		alert_label.text = ""


func _on_caught() -> void:
	caught += 1
	_update_hud()


func _update_hud() -> void:
	var total := GATHERER_SPOTS.size()
	count_label.text = "Caught: %d / %d" % [caught, total]
	if caught >= total:
		game_over = true
		message_label.text = "Every robot monkey caught!\nPress Start to play again"
	else:
		message_label.text = ""
