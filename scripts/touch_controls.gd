extends Control
## On-screen controls for phones.
##   Left side:  floating joystick (light push walks, full push jogs).
##   Right side: SWIPE TO SLASH. The cut follows your swipe (keep your finger down
##               and swipe again to chain; every 4th cut is a finisher).
##               In Blade Mode the swipe is the cut line.
##   Buttons:    Jump, Guard (hold; tap right as a blade lands to parry), Blade Mode
##               (toggle), Dodge (crouch / dash / dive), Ninja run (toggle).

const STICK_RADIUS := 80.0
const LOOK_SENSITIVITY := 0.006
const SWIPE_MIN := 40.0

var player: Node
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var swipe_start := Vector2.ZERO
var button_fingers := {}
var toggles := {"blade": false, "sprint": false}
var buttons := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = Input.get_connected_joypads().is_empty()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	var r := 46.0
	var right := s.x - 90.0
	var bottom := s.y - 90.0
	buttons = {
		"jump":   {"pos": Vector2(right, bottom), "radius": 50.0, "label": "JUMP", "action": "jump", "toggle": false},
		"guard":  {"pos": Vector2(right - 125, bottom + 10), "radius": r, "label": "GUARD", "action": "guard", "toggle": false},
		"dodge":  {"pos": Vector2(right - 10, bottom - 120), "radius": r, "label": "DODGE", "action": "roll", "toggle": false},
		"blade":  {"pos": Vector2(215, s.y - 340), "radius": 40.0, "label": "BLADE", "action": "blade", "toggle": true},
		"sprint": {"pos": Vector2(95, s.y - 340), "radius": 40.0, "label": "NINJA", "action": "sprint", "toggle": true},
		"restart": {"pos": Vector2(s.x - 60, 150), "radius": 30.0, "label": "RESET", "action": "restart", "toggle": false},
	}
	queue_redraw()


func _process(_delta: float) -> void:
	# Blade Mode ends on its own (energy, getting hit): keep the toggle honest
	if toggles["blade"] and player and not player.in_blade_mode() and player.energy < 10.0:
		toggles["blade"] = false
		Input.action_release("blade")
	queue_redraw()


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton) or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.5):
		visible = false
		return
	if event is InputEventScreenTouch:
		visible = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
		get_viewport().set_input_as_handled()


func _touch_down(finger: int, pos: Vector2) -> void:
	for name in buttons:
		var b: Dictionary = buttons[name]
		if pos.distance_to(b.pos) <= b.radius * 1.15:
			button_fingers[finger] = name
			if b.toggle:
				toggles[name] = not toggles[name]
				if toggles[name]:
					Input.action_press(b.action)
				else:
					Input.action_release(b.action)
			else:
				Input.action_press(b.action)
			queue_redraw()
			return
	var s := get_viewport_rect().size
	if pos.x < s.x * 0.45 and stick_finger == -1:
		stick_finger = finger
		stick_origin = pos
		stick_vec = Vector2.ZERO
	elif look_finger == -1:
		look_finger = finger
		look_last = pos
		swipe_start = pos
	queue_redraw()


func _touch_move(finger: int, pos: Vector2) -> void:
	if finger == stick_finger:
		var v := (pos - stick_origin) / STICK_RADIUS
		stick_vec = v.limit_length(1.0)
		_apply_stick()
		queue_redraw()
	elif finger == look_finger:
		var d := pos - look_last
		look_last = pos
		var sw := pos - swipe_start
		if player and player.in_blade_mode():
			if sw.length() > 12.0:
				player.touch_cutting = true
				player.touch_cut_angle = atan2(-sw.y, sw.x)
		elif player and sw.length() > 70.0:
			# A swipe: slash along it, then start tracking the next one
			var dir := Vector2(sw.x, -sw.y) / 70.0
			player.touch_swipe(dir)
			swipe_start = pos


func _touch_up(finger: int) -> void:
	if finger == stick_finger:
		stick_finger = -1
		stick_vec = Vector2.ZERO
		_apply_stick()
	elif finger == look_finger:
		look_finger = -1
		if player and player.in_blade_mode():
			var sw := look_last - swipe_start
			if sw.length() > SWIPE_MIN:
				player.touch_cut(atan2(-sw.y, sw.x))
			else:
				player.touch_cutting = false
	elif button_fingers.has(finger):
		var name: String = button_fingers[finger]
		button_fingers.erase(finger)
		if not buttons[name].toggle:
			Input.action_release(buttons[name].action)
	queue_redraw()


func _apply_stick() -> void:
	_axis("move_left", "move_right", stick_vec.x)
	_axis("move_forward", "move_back", stick_vec.y)


func _axis(neg: String, pos: String, value: float) -> void:
	if value < -0.05:
		Input.action_press(neg, -value)
		Input.action_release(pos)
	elif value > 0.05:
		Input.action_press(pos, value)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _draw() -> void:
	var font := get_theme_default_font()
	var s := get_viewport_rect().size
	if stick_finger != -1:
		draw_circle(stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(stick_origin, STICK_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
		draw_circle(stick_origin + stick_vec * STICK_RADIUS, 34, Color(1, 1, 1, 0.6))
	else:
		var hint := Vector2(150, s.y - 150)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.18), 3.0)
		draw_string(font, hint + Vector2(-34, 6), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.35))
	if look_finger == -1:
		var msg := "SWIPE TO CUT" if player and player.in_blade_mode() else "SWIPE TO SLASH"
		draw_string(font, Vector2(s.x * 0.58, s.y * 0.42), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.75, 0.92, 1.0, 0.45))
	for name in buttons:
		var b: Dictionary = buttons[name]
		var held: bool = button_fingers.values().has(name) or (b.toggle and toggles.get(name, false))
		var fill := Color(1, 0.85, 0.3, 0.55) if held else Color(0, 0, 0, 0.35)
		if name == "blade" and held:
			fill = Color(0.3, 0.7, 1.0, 0.6)
		draw_circle(b.pos, b.radius, fill)
		draw_arc(b.pos, b.radius, 0, TAU, 40, Color(1, 1, 1, 0.65), 3.0)
		var text: String = b.label
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, b.pos + Vector2(-w / 2.0, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if s.y > s.x:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.75))
		var msg := "Turn your phone sideways"
		var mw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		draw_string(font, Vector2((s.x - mw) / 2.0, s.y / 2.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
