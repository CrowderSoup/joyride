class_name Controls
extends RefCounted
## Input map, set up in code so it's all in one place. Several actions share keys (W is gas,
## walk and pitch down); whoever's in control reads the ones that make sense for them.


static func setup() -> void:
	_action("accelerate", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("brake", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("steer_left", [KEY_A, KEY_LEFT], [_joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("steer_right", [KEY_D, KEY_RIGHT], [_joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("handbrake", [KEY_SPACE], [_joy_button(JOY_BUTTON_A)])
	_action("pitch_up", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("pitch_down", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("yaw_left", [KEY_Q], [_joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("yaw_right", [KEY_E], [_joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("throttle_up", [KEY_SHIFT], [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("throttle_down", [KEY_CTRL], [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("move_forward", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_back", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("sprint", [KEY_SHIFT], [_joy_button(JOY_BUTTON_X)])
	_action("jump", [KEY_SPACE], [_joy_button(JOY_BUTTON_A)])
	# Camera: right stick looks around anywhere; Q/E orbit only on foot (they're the rudder).
	_action("look_left", [], [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("look_right", [], [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("look_up", [], [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("look_down", [], [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("orbit_left", [KEY_Q], [])
	_action("orbit_right", [KEY_E], [])
	_action("interact", [KEY_F], [_joy_button(JOY_BUTTON_Y)])
	_action("reset_vehicle", [KEY_R], [_joy_button(JOY_BUTTON_BACK)])
	_action("toggle_help", [KEY_H], [])
	_action("toggle_ao", [KEY_F3], [])
	_action("toggle_map", [KEY_M], [_joy_button(JOY_BUTTON_START)])
	_action("toggle_camera", [KEY_V], [_joy_button(JOY_BUTTON_RIGHT_STICK)])


static func _action(action: StringName, keys: Array, joy_events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for ev in joy_events:
		InputMap.action_add_event(action, ev)


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev
