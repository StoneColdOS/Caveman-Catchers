extends Node3D
## Mech Mania: builds the night-time Tokyo neighborhood (heavy PSX look), your mech,
## the enemy mechs and the HUD (lock-on reticle, ammo, armor).

const Util := preload("res://scripts/util.gd")
const Controls := preload("res://scripts/controls.gd")
const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const CityScript := preload("res://scripts/city.gd")
const FighterScript := preload("res://scripts/fighter.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")

const PLAYER_SPAWN := Vector3(-72, 0.2, 72)
const ENEMY_SPAWNS := [Vector3(24, 0.2, -24), Vector3(72, 0.2, 24), Vector3(-24, 0.2, -72)]

var player: CharacterBody3D
var city: Node3D
var downed := 0
var game_over := false
var count_label: Label
var mode_label: Label
var alert_label: Label
var ammo_label: Label
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
	# Tokyo night: deep blue-violet sky, hazy fog, neon does the rest
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.65)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.08, 0.16)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 35, 0)
	moon.light_energy = 0.4
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
	for spot in ENEMY_SPAWNS:
		var e := CharacterBody3D.new()
		e.set_script(EnemyScript)
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
	ammo_label = _label(30, Vector2(24, 136), layer)

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
	hint_label.text = "Run: L-stick  Lock: R1 (R-stick aims: head/arm/leg)  Fire: R2  Manual aim: L1  Roll: L2 or B  Jump: A  Reload: Y"
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
	ammo_label.text = ("RELOADING..." if player.reload_t > 0.0 else "AMMO  %d / %d" % [player.ammo, player.mag_size])
	ammo_label.modulate = Color(1, 0.6, 0.3) if player.reload_t > 0.0 or player.ammo <= 3 else Color.WHITE
	hurt_rect.color.a = player.hurt * 0.35
	reticle.queue_redraw()

	var fighting := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_fighting():
			fighting = true
	alert_label.text = ""

	# Flash what your last strike did
	if player.last_result != "":
		var words := {"crit": "CRITICAL", "kill": "MECH DOWN", "silent": "SILENT KILL", "headshot": "HEADSHOT", "decap": "HEAD OFF", "disarmed": "DISARMED", "leg": "LEG OFF"}
		result_label.text = words.get(player.last_result, "")
		result_label.modulate = Color(1, 0.85, 0.4) if player.last_result != "crit" else Color(1, 0.5, 0.4)
		player.last_result = ""
		result_timer = 1.0
	result_timer -= delta
	if result_timer <= 0.0:
		result_label.text = ""


## Crosshair, or lock brackets around your target that close in as the lock settles.
## White = loose, yellow = getting there, red = full lock (double damage).
func _draw_reticle() -> void:
	if player == null or player.dead:
		return
	var cam: Camera3D = player.camera
	var size := reticle.get_viewport_rect().size
	var hm: float = player.hit_marker
	if player.target and is_instance_valid(player.target):
		var tgt = player.target
		var top: Vector3 = tgt.global_position + Vector3.UP * 10.5
		var bot: Vector3 = tgt.global_position
		if cam.is_position_behind(top) or cam.is_position_behind(bot):
			return
		var pt := cam.unproject_position(top)
		var pb := cam.unproject_position(bot)
		var hh := absf(pb.y - pt.y) * 0.5
		var mid := (pt + pb) * 0.5
		var hw := hh * 0.45
		var l: float = player.lock
		var c := Color(1, 1, 1).lerp(Color(1, 0.9, 0.2), clampf(l * 2.0, 0, 1)).lerp(Color(1, 0.15, 0.1), clampf(l * 2.0 - 1.0, 0, 1))
		if l >= 0.999:
			c = Color(1, 0.1, 0.1)
		# Full-body brackets that tighten as the lock settles
		var grow := lerpf(1.6, 1.05, l)
		var ex := hw * grow
		var ey := hh * grow
		var arm := minf(ex, ey) * 0.35
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := mid + Vector2(sx * ex, sy * ey)
				reticle.draw_line(corner, corner - Vector2(sx * arm, 0), c, 3.0)
				reticle.draw_line(corner, corner - Vector2(0, sy * arm), c, 3.0)
		# The aim dot (moved with the right stick) and the part under it
		var dot := cam.unproject_position(player.lock_point())
		reticle.draw_circle(dot, 6.0, c)
		reticle.draw_arc(dot, 12.0, 0, TAU, 20, c, 2.0)
		var font := reticle.get_theme_default_font()
		var label: String = player.part.to_upper()
		reticle.draw_string_outline(font, dot + Vector2(18, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color.BLACK)
		reticle.draw_string(font, dot + Vector2(18, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, c)
		if hm > 0.0:
			_hit_x(dot, Color(1, 1, 1, hm * 5.0))
	else:
		var p := size * 0.5
		var c := Color(1, 1, 1, 0.75) if player.is_aiming() else Color(1, 1, 1, 0.35)
		reticle.draw_line(p + Vector2(-14, 0), p + Vector2(-5, 0), c, 3.0)
		reticle.draw_line(p + Vector2(14, 0), p + Vector2(5, 0), c, 3.0)
		reticle.draw_line(p + Vector2(0, -14), p + Vector2(0, -5), c, 3.0)
		reticle.draw_line(p + Vector2(0, 14), p + Vector2(0, 5), c, 3.0)
		if hm > 0.0:
			_hit_x(p, Color(1, 1, 1, hm * 5.0))


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
	for a in ["lock", "aim", "fire", "strafe_left", "strafe_right", "roll", "jump", "reload"]:
		if Input.is_action_pressed(a):
			held.append(a)
	lines.append("Held: " + (", ".join(held) if held.size() > 0 else "-"))
	lines.append("Last input: " + last_raw)
	debug_label.text = "\n".join(lines)
