extends Node3D
## Mech Mania: builds the night-time Tokyo neighborhood (heavy PSX look), your mech,
## the enemy mechs and the HUD (armor, blade energy, the Blade Mode cut line).

const Util := preload("res://scripts/util.gd")
const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const CityScript := preload("res://scripts/city.gd")
const FighterScript := preload("res://scripts/fighter.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const PLAYER_SPAWN := Vector3(-72, 0.2, 72)
const ENEMY_SPAWNS := [Vector3(24, 0.2, -24), Vector3(72, 0.2, 24), Vector3(-24, 0.2, -72), Vector3(-24, 0.2, 24)]
const ENEMY_KINDS := ["swordsman", "swordsman", "swordsman", "swordsman"]

var player: CharacterBody3D
var city: Node3D
var downed := 0
var game_over := false
var count_label: Label
var mode_label: Label
var alert_label: Label
var energy_bar: ProgressBar
var reticle: Control
var hurt_rect: ColorRect
var result_label: Label
var hint_label: Label
var message_label: Label
var armor_bar: ProgressBar
var result_timer := 0.0


func _ready() -> void:
	Controls.setup()
	Engine.time_scale = 1.0
	Util.reset_style_cache()
	_build_environment()
	city = Node3D.new()
	city.set_script(CityScript)
	add_child(city)
	city.build()
	_spawn_player()
	_spawn_enemies()
	_build_ps1()
	_build_hud()
	_build_debug()
	if use_touch():
		_build_touch()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return
	_update_debug()
	_update_hud_live(delta)


func _build_environment() -> void:
	# Tokyo night, cleaner and brighter than before so fights read: lighter haze,
	# filmic tonemapping, and glow so neon, blades and mech trim pop.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.8)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.14, 0.12, 0.22)
	env.fog_density = 0.006
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 35, 0)
	moon.light_energy = 0.95
	moon.light_color = Color(0.6, 0.65, 0.95)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	add_child(moon)

	# A few colored neon glows at street crossings
	var colors := [Color(1.0, 0.3, 0.6), Color(0.2, 0.8, 1.0), Color(1.0, 0.75, 0.3), Color(0.5, 1.0, 0.5)]
	var spots := [Vector3(-24, 6, -24), Vector3(24, 6, 24), Vector3(-24, 6, 24), Vector3(24, 6, -24), Vector3(-72, 6, 72), Vector3(72, 6, -72)]
	for i in spots.size():
		var l := OmniLight3D.new()
		l.position = spots[i]
		l.light_color = colors[i % colors.size()]
		l.light_energy = 2.0
		l.omni_range = 26.0
		l.omni_attenuation = 1.2
		add_child(l)


## PS1-style screen: low resolution with chunky pixels and color dithering.
func _build_ps1() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/ps1.gdshader")
	# Just a hint of retro now: high resolution, light dithering
	sm.set_shader_parameter("pixel_height", 540.0)
	sm.set_shader_parameter("color_levels", 96.0)
	rect.material = sm
	layer.add_child(rect)


func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = PLAYER_SPAWN
	add_child(player)
	player.city = city
	player.yaw = PI * 0.75 + PI   # facing into the city
	player.rig.rotation.y = player.yaw + PI
	player.killed.connect(_on_player_killed)


func _spawn_enemies() -> void:
	for i in ENEMY_SPAWNS.size():
		var spot: Vector3 = ENEMY_SPAWNS[i]
		var e := CharacterBody3D.new()
		e.set_script(EnemyScript)
		e.kind = ENEMY_KINDS[i]
		e.position = spot
		add_child(e)
		e.city = city
		e.killed.connect(_on_enemy_killed)


func _on_enemy_killed(_by) -> void:
	downed += 1
	if downed >= ENEMY_SPAWNS.size() and not player.dead:
		game_over = true
		message_label.text = "CITY CLEARED\nPress Start to play again"
		message_label.modulate = Color(1, 0.95, 0.7)
	_update_count()


func _on_player_killed(_by) -> void:
	game_over = true
	message_label.text = "DEFEATED\nPress Start to try again"
	message_label.modulate = Color(1, 0.35, 0.3)


# --- HUD

func _label(size: int, pos: Vector2, parent: Node) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", size / 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	layer.add_child(hurt_rect)
	reticle = Control.new()
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(_draw_reticle)
	layer.add_child(reticle)
	count_label = _label(34, Vector2(24, 18), layer)
	mode_label = _label(24, Vector2(24, 62), layer)
	var armor_text := _label(20, Vector2(24, 100), layer)
	armor_text.text = "ARMOR"
	armor_bar = ProgressBar.new()
	armor_bar.max_value = player.MAX_HP
	armor_bar.value = player.MAX_HP
	armor_bar.show_percentage = false
	armor_bar.position = Vector2(110, 104)
	armor_bar.size = Vector2(220, 20)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.75, 0.3)
	armor_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	armor_bar.add_theme_stylebox_override("background", bg)
	layer.add_child(armor_bar)
	var energy_text := _label(20, Vector2(24, 132), layer)
	energy_text.text = "BLADE"
	energy_bar = ProgressBar.new()
	energy_bar.max_value = player.MAX_ENERGY
	energy_bar.show_percentage = false
	energy_bar.position = Vector2(110, 136)
	energy_bar.size = Vector2(220, 16)
	var efill := StyleBoxFlat.new()
	efill.bg_color = Color(0.3, 0.75, 1.0)
	energy_bar.add_theme_stylebox_override("fill", efill)
	var ebg := StyleBoxFlat.new()
	ebg.bg_color = Color(0, 0, 0, 0.6)
	energy_bar.add_theme_stylebox_override("background", ebg)
	layer.add_child(energy_bar)

	alert_label = Label.new()
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_label.offset_top = 70
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 40)
	alert_label.add_theme_constant_override("outline_size", 10)
	alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(alert_label)

	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_CENTER)
	result_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_label.offset_top = -140
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 46)
	result_label.add_theme_constant_override("outline_size", 12)
	result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(result_label)

	hint_label = Label.new()
	hint_label.text = "SWORD: right stick (sweep between directions)  Guard/parry: L1  Blade Mode: L2  Ninja run: R1  Jump: A  Dash: B"
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -44
	hint_label.offset_left = 24
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(hint_label)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 52)
	message_label.add_theme_constant_override("outline_size", 12)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(message_label)
	_update_count()


func _update_count() -> void:
	count_label.text = "Mechs down: %d / %d" % [downed, ENEMY_SPAWNS.size()]


func _update_hud_live(delta: float) -> void:
	if player == null or armor_bar == null:
		return
	armor_bar.value = player.hp
	mode_label.text = "Crouching" if player.crouching else ""
	energy_bar.value = player.energy
	hurt_rect.color.a = player.hurt * 0.35
	reticle.queue_redraw()

	var fighting := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_fighting():
			fighting = true
	alert_label.text = ""

	# Flash what your last strike did
	if player.last_result != "":
		var words := {"kill": "CUT DOWN", "zandatsu": "CUT IN HALF  +REPAIR", "cut": "SEVERED", "armor": "ARMOR HOLDS", "parry": "PARRY", "break": "GUARD BREAK", "block": "BLOCKED", "deflect": "DEFLECTED", "hit": ""}
		result_label.text = words.get(player.last_result, "")
		result_label.modulate = Color(1, 0.85, 0.4) if player.last_result != "crit" else Color(1, 0.5, 0.4)
		player.last_result = ""
		result_timer = 1.0
	result_timer -= delta
	if result_timer <= 0.0:
		result_label.text = ""


## Blade Mode overlay: dim blue wash, letterbox bars, and the cut line across the
## target (it tilts with the right stick and slides with the left).
func _draw_reticle() -> void:
	if player == null or player.dead:
		return
	var size := reticle.get_viewport_rect().size
	if not player.in_blade_mode():
		if player.hit_marker > 0.0:
			_hit_x(size * 0.5, Color(1, 1, 1, player.hit_marker * 5.0))
		return
	reticle.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.15, 0.35, 0.28))
	var bar := size.y * 0.09
	reticle.draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.85))
	reticle.draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.85))
	var cam: Camera3D = player.camera
	var right := cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var base: Vector3 = player.global_position + player.facing() * 9.0 + Vector3.UP * 6.0
	var t = player.blade_target
	if t and is_instance_valid(t):
		base = t.center()
	var p0: Vector3 = base + right * player.cut_offset.x + Vector3.UP * player.cut_offset.y
	var d := Vector2(cos(player.cut_angle), sin(player.cut_angle))
	var dw: Vector3 = right * d.x + Vector3.UP * d.y
	var a3 := p0 - dw * 9.0
	var b3 := p0 + dw * 9.0
	if cam.is_position_behind(a3) or cam.is_position_behind(b3):
		return
	var a2 := cam.unproject_position(a3)
	var b2 := cam.unproject_position(b3)
	var glow := Color(0.4, 0.85, 1.0, 0.35)
	reticle.draw_line(a2, b2, glow, 14.0)
	reticle.draw_line(a2, b2, Color(0.85, 0.97, 1.0), 3.0)
	var font := reticle.get_theme_default_font()
	var label := "BLADE MODE"
	if t and is_instance_valid(t) and not t.dead:
		label += "   " + ("WEAKENED: CUT THROUGH" if t.weakened() else "LIMBS ONLY (armor)")
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var lp := Vector2((size.x - lw) * 0.5, size.y - bar - 24)
	reticle.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color.BLACK)
	reticle.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.7, 0.9, 1.0))
	if player.hit_marker > 0.0:
		_hit_x(cam.unproject_position(p0), Color(1, 1, 1, player.hit_marker * 4.0))


func _hit_x(p: Vector2, c: Color) -> void:
	for d in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		reticle.draw_line(p + d * 10.0, p + d * 22.0, c, 4.0)


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
	var held: PackedStringArray = []
	for a in ["attack", "heavy", "guard", "blade", "sprint", "roll"]:
		if Input.is_action_pressed(a):
			held.append(a)
	lines.append("Held: " + (", ".join(held) if held.size() > 0 else "-"))
	lines.append("Last input: " + last_raw)
	debug_label.text = "\n".join(lines)
