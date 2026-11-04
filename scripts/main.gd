extends Node3D
## Builds the grey-box jungle clearing, the player, the cavemen and the HUD.
## Everything is placeholder shapes on purpose: we're testing fun, not art.

const Util := preload("res://scripts/util.gd")
const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const GathererScript := preload("res://scripts/gatherer.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const ARENA := 50.0
const GATHERER_SPOTS := [Vector3(-10, 0, -12), Vector3(12, 0, -8), Vector3(2, 0, 14), Vector3(-15, 0, 8), Vector3(15, 0, 13)]

var player: CharacterBody3D
var caught := 0
var count_label: Label
var mode_label: Label
var darts_label: Label
var alert_label: Label
var crosshair: Control
var game_over := false
var hint_label: Label
var message_label: Label
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Controls.setup()
	rng.seed = 7
	_build_environment()
	_build_ground()
	_build_cover()
	_spawn_player()
	_spawn_gatherers()
	_build_hud()
	_build_debug()
	if use_touch():
		_build_touch()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	_update_debug()
	_update_alert()
	if player and crosshair:
		crosshair.visible = player.aiming and not game_over
		crosshair.modulate = Color(1, 0.25, 0.2) if player.aim_on_target else Color(1, 0.95, 0.6)
	if player and darts_label:
		darts_label.text = "Darts: %d" % player.darts
		darts_label.modulate = Color(1, 0.45, 0.35) if player.darts == 0 else Color(1, 0.9, 0.5)
	if player and mode_label:
		mode_label.text = player.move_mode
		var loud: bool = player.move_mode.begins_with("Running")
		var silent: bool = player.move_mode.contains("silent")
		mode_label.modulate = Color(1, 0.45, 0.35) if loud else (Color(0.6, 1, 0.7) if silent else Color.WHITE)


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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.55)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.62, 0.55)
	env.fog_density = 0.01
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	_static_box(Vector3(ARENA + 20, 1, ARENA + 20), Vector3(0, -0.5, 0), Color(0.28, 0.45, 0.22))
	# Thick jungle walls around the edge
	var h := ARENA / 2.0
	var wall := Color(0.12, 0.25, 0.12)
	_static_box(Vector3(ARENA + 4, 6, 2), Vector3(0, 3, -h - 1), wall)
	_static_box(Vector3(ARENA + 4, 6, 2), Vector3(0, 3, h + 1), wall)
	_static_box(Vector3(2, 6, ARENA), Vector3(-h - 1, 3, 0), wall)
	_static_box(Vector3(2, 6, ARENA), Vector3(h + 1, 3, 0), wall)


## Rocks and trees: things to sneak behind. They block caveman eyesight.
func _build_cover() -> void:
	for i in 14:
		var p := _random_spot()
		var size := Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(1.2, 2.8), rng.randf_range(1.5, 4.0))
		var rock := _static_box(size, p + Vector3(0, size.y / 2.0, 0), Color(0.42, 0.4, 0.36))
		rock.rotation.y = rng.randf() * TAU
	for i in 18:
		var p := _random_spot()
		_tree(p)


func _tree(p: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Util.LAYER_WORLD
	body.position = p
	add_child(body)
	var trunk_h := rng.randf_range(4.0, 6.5)
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.45
	cyl_shape.height = trunk_h
	shape.shape = cyl_shape
	shape.position.y = trunk_h / 2.0
	body.add_child(shape)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.5
	trunk.height = trunk_h
	trunk.radial_segments = 6
	body.add_child(Util.mesh(trunk, Color(0.35, 0.24, 0.15), Vector3(0, trunk_h / 2.0, 0)))
	body.add_child(Util.mesh(Util.sphere(rng.randf_range(1.6, 2.4)), Color(0.18, 0.42, 0.18), Vector3(0, trunk_h + 0.6, 0)))


func _random_spot() -> Vector3:
	# Keep the middle open near the player start, and away from walls.
	while true:
		var p := Vector3(rng.randf_range(-21, 21), 0, rng.randf_range(-21, 21))
		if p.length() > 5.0:
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

	darts_label = Label.new()
	darts_label.position = Vector2(24, 96)
	darts_label.add_theme_font_size_override("font_size", 24)
	darts_label.add_theme_constant_override("outline_size", 6)
	darts_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(darts_label)

	alert_label = Label.new()
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_label.offset_top = 70
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 40)
	alert_label.add_theme_constant_override("outline_size", 10)
	alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(alert_label)

	# Crosshair drawn from rectangles so it sits exactly on the screen center.
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	layer.add_child(crosshair)
	var arms := [Rect2(-15, -1, 10, 2), Rect2(5, -1, 10, 2), Rect2(-1, -15, 2, 10), Rect2(-1, 5, 2, 10), Rect2(-1.5, -1.5, 3, 3)]
	for pass_i in 2:
		for r in arms:
			var bar := ColorRect.new()
			var grow := 1.0 if pass_i == 0 else 0.0
			bar.position = r.position - Vector2(grow, grow)
			bar.size = r.size + Vector2(grow, grow) * 2.0
			bar.color = Color(0, 0, 0, 0.8) if pass_i == 0 else Color.WHITE
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crosshair.add_child(bar)

	hint_label = Label.new()
	var hint := hint_label
	hint.text = "Move: L-stick (light tilt = sneak)  Jump: A  Crouch: L1  Net: R1  Aim: L2  Fire: R2  Look: R-stick  Restart: Start"
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


## Spotted robots just run (Ape Escape style); the "!" over their heads is the only alarm.
func _update_alert() -> void:
	pass


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
