extends RefCounted
## Sets up controls in code so they work on keyboard and on the Thor's gamepad.
## Syphon Filter style: hold to aim/lock, tap to fire, roll to dodge.
##
##   Run         left stick  / WASD   (you run where you push; camera swings in behind)
##   Walk        L3 (hold)   / Ctrl   (quiet)
##   Camera      right stick / arrow keys
##   Lock on     R1 (hold)   / K      (run and gun; right stick slides your aim to head / arm / leg)
##   Manual aim  L1 (hold)   / L      (precise crosshair)
##   Fire        R2 or X     / J      (R2 keeps your right thumb free to aim)
##   Sidestep                / Q / E  (while locked, the left stick strafes anyway)
##   Roll/crouch B or L2     / C      (moving = roll, standing = crouch)
##   Part pick               / 1-4    (body / head / arm / leg; sticks until you change it)
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
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)    # R2: index finger fires, thumb stays on the aim stick

	_action("strafe_left")
	_key("strafe_left", KEY_Q)
	_action("strafe_right")
	_key("strafe_right", KEY_E)

	# Sticky part picks (phone buttons / number keys): the aim stays on that part
	for part in ["body", "head", "arm", "leg"]:
		_action("part_" + part)
	_key("part_body", KEY_1)
	_key("part_head", KEY_2)
	_key("part_arm", KEY_3)
	_key("part_leg", KEY_4)

	_action("roll")
	_key("roll", KEY_C)
	_button("roll", JOY_BUTTON_B)
	_axis("roll", JOY_AXIS_TRIGGER_LEFT, 1.0)      # L2: quick dodge

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
