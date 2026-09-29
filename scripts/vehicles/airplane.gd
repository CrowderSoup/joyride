class_name Airplane
extends CharacterBody3D
## Arcade prop plane. On the ground it drives like everything else: W/S gas and brake
## (tap S at a stop to back up), A/D steer. Past takeoff speed, hold S to lift off.
## In the air: W/S pitch, A/D roll, Q/E rudder, Shift/Ctrl throttle.

const GROUND_Y := 0.0
const GRAVITY := 9.8

var display_name := "Prop Plane"
var max_speed := 75.0
var takeoff_speed := 28.0
var stall_speed := 24.0
var pitch_rate := 1.2
var roll_rate := 2.2
var yaw_rate := 0.5
var camera_distance := 16.0
var camera_height := 4.0
var enter_radius := 5.0
var exit_offset := Vector3(-1.5, 0, 1.3)  # behind the left wing

var active := false
var throttle := 0.0
var visual := Node3D.new()
var _speed := 0.0
var _prop: Node3D


func _init() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(visual)
	Parts.collision_box(self, Vector3(1.2, 1.4, 8.3), Vector3(0, 1.48, 0.1))
	Parts.collision_box(self, Vector3(11.0, 0.3, 1.6), Vector3(0, 2.3, -0.95))
	Parts.collision_box(self, Vector3(3.5, 0.3, 1.1), Vector3(0, 1.5, 3.9))
	_prop = PlaneModel.build(visual)


func get_speed() -> float:
	return _speed


func hud_extra() -> String:
	var text := "ALT %d ft   THR %d%%" % [roundi(global_position.y * 3.281), roundi(throttle * 100)]
	if _is_grounded() and _speed > takeoff_speed:
		text += "   Hold S to lift off"
	return text


func set_driving(on: bool) -> void:
	active = on
	if not on:
		throttle = 0.0


func can_exit() -> bool:
	# Parked, or crashed and actually at rest (wedged nose-down still counts).
	return absf(_speed) < 2.0 and (_is_grounded() or get_real_velocity().length() < 1.0)


func stop() -> void:
	velocity = Vector3.ZERO
	_speed = 0.0
	throttle = 0.0


func _is_grounded() -> bool:
	return global_position.y <= GROUND_Y + 0.05


func _physics_process(delta: float) -> void:
	var pitch_in := 0.0
	var roll_in := 0.0
	var yaw_in := 0.0
	if active:
		pitch_in = Input.get_axis("pitch_down", "pitch_up")
		roll_in = Input.get_axis("steer_left", "steer_right")
		yaw_in = Input.get_axis("yaw_right", "yaw_left")

	var grounded := _is_grounded()
	# On the ground, S pulls the nose up once you're fast enough; below that it's the brake.
	var rotating := grounded and pitch_in > 0.0 and _speed > takeoff_speed
	var gas := 0.0
	var brake := 0.0
	if active and grounded:
		gas = maxf(Input.get_action_strength("accelerate"), Input.get_action_strength("throttle_up"))
		brake = 0.0 if rotating else maxf(Input.get_action_strength("brake"), Input.get_action_strength("throttle_down"))
		throttle = clampf(throttle + (gas - brake) * 1.2 * delta, 0.0, 1.0)
	elif active:
		throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * 0.6 * delta, 0.0, 1.0)

	var fwd := -global_basis.z
	# Throttle pulls speed toward a target; climbing bleeds speed, diving adds it.
	_speed += (throttle * max_speed - _speed) * 0.3 * delta
	_speed -= fwd.y * GRAVITY * delta

	if grounded:
		if brake > 0.0:
			# Wheel brakes, and a slow pushback once stopped so you can't get stuck nose-in.
			if _speed > 0.5:
				_speed = move_toward(_speed, 0.0, 12.0 * brake * delta)
			else:
				_speed = move_toward(_speed, -3.0, 3.0 * brake * delta)
		elif throttle < 0.05:
			_speed = move_toward(_speed, 0.0, 4.0 * delta)
		_speed = maxf(_speed, -3.0)
		# Taxi: A/D steer on the ground, wings stay level, nose only lifts once fast enough.
		rotate_y(-roll_in * 1.0 * clampf(_speed / 10.0, -1.0, 1.0) * delta)
		rotation.z = move_toward(rotation.z, 0.0, 2.0 * delta)
		if rotating:
			rotation.x = minf(rotation.x + pitch_rate * pitch_in * delta, 0.25)  # more drags the tail
		else:
			rotation.x = move_toward(rotation.x, 0.0, 1.5 * delta)
		rotation.x = maxf(rotation.x, 0.0)
	else:
		_speed = maxf(_speed, 0.0)
		rotate_object_local(Vector3.RIGHT, pitch_in * pitch_rate * delta)
		rotate_object_local(Vector3.BACK, -roll_in * roll_rate * delta)
		rotate_object_local(Vector3.UP, yaw_in * yaw_rate * delta)
		# Bank turns the plane, and it gently levels its wings when you let go.
		var bank := global_basis.x.y
		rotate_y(bank * 1.2 * delta)
		if absf(roll_in) < 0.1:
			rotate_object_local(Vector3.BACK, -bank * 1.0 * delta)
	global_basis = global_basis.orthonormalized()

	fwd = -global_basis.z
	velocity = fwd * _speed
	var lift := clampf((_speed - stall_speed * 0.6) / (stall_speed * 0.4), 0.0, 1.0)
	if not grounded:
		velocity.y -= (1.0 - lift) * 15.0
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		_speed *= 0.5
	if global_position.y < GROUND_Y:
		global_position.y = GROUND_Y

	_prop.rotate_z((5.0 + throttle * 40.0) * delta)
