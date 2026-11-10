extends RefCounted
## Sets up controls in code so they work on keyboard and on the Thor's gamepad.
##
##   Move        left stick  / WASD   (light tilt = quiet walk, full tilt = loud run)
##   Walk                    / hold Ctrl
##   Camera      right stick / arrow keys
##   Slash       X or R2     / J
##   Guard       L1 or L2    / K (hold)
##   Dash        A           / Space  (cancels a windup: feint)
##   Stance      Y cycles    / I cycles, or 1 / 2 / 3
##               D-pad up = HIGH, left/right = MID, down = LOW
##   Lock-on     R1 or R3    / Tab    (toggle)
##   Restart     Start       / Enter


static func setup() -> void:
	_action("move_left");    _key("move_left", KEY_A);      _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_action("move_right");   _key("move_right", KEY_D);     _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_action("move_forward"); _key("move_forward", KEY_W);   _axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back");    _key("move_back", KEY_S);      _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)

	_action("look_left");  _key("look_left", KEY_LEFT);   _axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_action("look_right"); _key("look_right", KEY_RIGHT); _axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_action("look_up");    _key("look_up", KEY_UP);       _axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_action("look_down");  _key("look_down", KEY_DOWN);   _axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

	_action("slash")
	_key("slash", KEY_J)
	_button("slash", JOY_BUTTON_X)
	_axis("slash", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_action("guard")
	_key("guard", KEY_K)
	_button("guard", JOY_BUTTON_LEFT_SHOULDER)
	_axis("guard", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_action("dash")
	_key("dash", KEY_SPACE)
	_button("dash", JOY_BUTTON_A)

	_action("stance_cycle")
	_key("stance_cycle", KEY_I)
	_button("stance_cycle", JOY_BUTTON_Y)
	_action("stance_high")
	_key("stance_high", KEY_1)
	_button("stance_high", JOY_BUTTON_DPAD_UP)
	_action("stance_mid")
	_key("stance_mid", KEY_2)
	_button("stance_mid", JOY_BUTTON_DPAD_LEFT)
	_button("stance_mid", JOY_BUTTON_DPAD_RIGHT)
	_action("stance_low")
	_key("stance_low", KEY_3)
	_button("stance_low", JOY_BUTTON_DPAD_DOWN)

	_action("lock")
	_key("lock", KEY_TAB)
	_button("lock", JOY_BUTTON_RIGHT_SHOULDER)
	_button("lock", JOY_BUTTON_RIGHT_STICK)

	_action("walk")
	_key("walk", KEY_CTRL)

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
