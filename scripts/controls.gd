extends RefCounted
## Sets up controls in code so they work on keyboard and on the Thor's gamepad.
## Phantom Pain movement, Rising-style sword.
##
##   Move          left stick  / WASD   (light push walks, full push jogs)
##   Sprint        A (hold)    / Shift
##   Camera        right stick / arrow keys
##   Quick slash   X or R2     / J      (tap 3x for a combo)
##   Heavy slash   Y           / K      (breaks guards)
##   Guard / parry L1          / L      (hold; raise it as a blade lands to parry)
##   Blade Mode    L2 (hold)   / F      (time slows: right stick tilts the cut line,
##                                       left stick slides it, flick or X to cut)
##   Crouch / roll / dive  B   / C      (standing / moving / sprinting)
##   Walk          L3 (hold)   / Ctrl
##   Restart       Start       / Enter


static func setup() -> void:
	_action("move_left");    _key("move_left", KEY_A);      _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_action("move_right");   _key("move_right", KEY_D);     _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_action("move_forward"); _key("move_forward", KEY_W);   _axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back");    _key("move_back", KEY_S);      _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)

	_action("look_left");  _key("look_left", KEY_LEFT);   _axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_action("look_right"); _key("look_right", KEY_RIGHT); _axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_action("look_up");    _key("look_up", KEY_UP);       _axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_action("look_down");  _key("look_down", KEY_DOWN);   _axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

	_action("attack")
	_key("attack", KEY_J)
	_button("attack", JOY_BUTTON_X)
	_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_action("heavy")
	_key("heavy", KEY_K)
	_button("heavy", JOY_BUTTON_Y)

	_action("guard")
	_key("guard", KEY_L)
	_button("guard", JOY_BUTTON_LEFT_SHOULDER)

	_action("blade")
	_key("blade", KEY_F)
	_axis("blade", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_action("sprint")
	_key("sprint", KEY_SHIFT)
	_button("sprint", JOY_BUTTON_A)

	_action("roll")
	_key("roll", KEY_C)
	_button("roll", JOY_BUTTON_B)

	_action("walk")
	_key("walk", KEY_CTRL)
	_button("walk", JOY_BUTTON_LEFT_STICK)

	_action("restart")
	_key("restart", KEY_ENTER)
	_button("restart", JOY_BUTTON_START)


static func _action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


static func _key(action: String, keycode: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = keycode
	InputMap.action_add_event(action, e)


static func _axis(action: String, axis: JoyAxis, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action, e)


static func _button(action: String, button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
