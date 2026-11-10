extends RefCounted
## Sets up controls in code so they work on keyboard and on the Thor's gamepad.
## Syphon Filter style: hold to aim/lock, tap to fire, roll to dodge.
##
##   Run         left stick  / WASD   (you run where you push; camera swings in behind)
##   Walk        L3 (hold)   / Ctrl   (quiet)
##   Camera      right stick / arrow keys
##   Lock on     R1 (hold)   / K      (run and gun; D-pad up/down or flick right stick = pick HEAD/ARM/LEG/BODY)
##   Manual aim  L1 (hold)   / L      (precise crosshair)
##   Fire        X           / J
##   Sidestep    L2 / R2     / Q / E
##   Roll/crouch B           / C      (moving = roll, standing = crouch)
##   Jump        A           / Space
##   Reload      Y           / R
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

	_action("lock")
	_key("lock", KEY_K)
	_button("lock", JOY_BUTTON_RIGHT_SHOULDER)

	_action("aim")
	_key("aim", KEY_L)
	_button("aim", JOY_BUTTON_LEFT_SHOULDER)

	_action("fire")
	_key("fire", KEY_J)
	_button("fire", JOY_BUTTON_X)

	_action("strafe_left")
	_key("strafe_left", KEY_Q)
	_axis("strafe_left", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_action("strafe_right")
	_key("strafe_right", KEY_E)
	_axis("strafe_right", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_action("part_next")
	_key("part_next", KEY_TAB)
	_button("part_next", JOY_BUTTON_DPAD_UP)
	_action("part_prev")
	_button("part_prev", JOY_BUTTON_DPAD_DOWN)

	_action("roll")
	_key("roll", KEY_C)
	_button("roll", JOY_BUTTON_B)

	_action("jump")
	_key("jump", KEY_SPACE)
	_button("jump", JOY_BUTTON_A)

	_action("reload")
	_key("reload", KEY_R)
	_button("reload", JOY_BUTTON_Y)

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
