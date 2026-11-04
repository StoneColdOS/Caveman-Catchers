extends RefCounted
## Sets up controls in code so they work on keyboard and on the Thor's gamepad.
##
##   Move       left stick  / WASD   (tilt lightly to sneak, all the way to run)
##   Sneak-walk              / hold Ctrl
##   Camera     right stick / arrow keys
##   Jump       A (bottom)  / Space
##   Crouch     L1          / Shift or C
##   Aim        hold L2     / hold Q
##   Swing net  R1          / J or E
##   Tranq gun  R2          / F or K   (at the crosshair while aiming)
##   Art style  Select      / T   (rubber hose on/off)
##   Restart    Start       / Enter


static func setup() -> void:
	_action("move_left");    _key("move_left", KEY_A);      _axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_action("move_right");   _key("move_right", KEY_D);     _axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_action("move_forward"); _key("move_forward", KEY_W);   _axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_action("move_back");    _key("move_back", KEY_S);      _axis("move_back", JOY_AXIS_LEFT_Y, 1.0)

	# D-pad as a backup for movement
	_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_button("move_forward", JOY_BUTTON_DPAD_UP)
	_button("move_back", JOY_BUTTON_DPAD_DOWN)

	_action("look_left");  _key("look_left", KEY_LEFT);   _axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_action("look_right"); _key("look_right", KEY_RIGHT); _axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_action("look_up");    _key("look_up", KEY_UP);       _axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_action("look_down");  _key("look_down", KEY_DOWN);   _axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)

	_action("crouch")
	_key("crouch", KEY_SHIFT)
	_key("crouch", KEY_C)
	_button("crouch", JOY_BUTTON_LEFT_SHOULDER)

	_action("aim")
	_key("aim", KEY_Q)
	_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)

	_action("net")
	_key("net", KEY_J)
	_key("net", KEY_E)
	_button("net", JOY_BUTTON_RIGHT_SHOULDER)

	_action("tranq")
	_key("tranq", KEY_F)
	_key("tranq", KEY_K)
	_axis("tranq", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_action("jump")
	_key("jump", KEY_SPACE)
	_button("jump", JOY_BUTTON_A)

	_action("walk")
	_key("walk", KEY_CTRL)

	_action("style")
	_key("style", KEY_T)
	_button("style", JOY_BUTTON_BACK)

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
