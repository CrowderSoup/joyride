class_name Airplane
extends CharacterBody3D
## Arcade prop plane: taxi, take off down State St, bank to turn, land wherever.

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

var active := false
var throttle := 0.0
var visual := Node3D.new()
var _speed := 0.0
var _prop: Node3D


func _init() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(visual)
	Parts.collision_box(self, Vector3(2.0, 1.6, 7.0), Vector3(0, 1.2, 0))
	var paint := Color(0.95, 0.93, 0.88)
	var trim := Color(0.85, 0.3, 0.2)
	Parts.box(visual, Vector3(1.2, 1.2, 7.0), paint, Vector3(0, 1.4, 0))
	Parts.box(visual, Vector3(10.0, 0.15, 1.6), trim, Vector3(0, 1.9, -0.6))
	Parts.box(visual, Vector3(3.5, 0.12, 0.9), trim, Vector3(0, 1.6, 3.1))
	Parts.box(visual, Vector3(0.12, 1.3, 1.0), trim, Vector3(0, 2.4, 3.1))
	Parts.box(visual, Vector3(1.0, 0.5, 1.2), Color(0.1, 0.12, 0.15), Vector3(0, 2.2, -1.3))
	Parts.wheel(visual, 0.3, 0.2, Vector3(-1.0, 0.3, -1.0))
	Parts.wheel(visual, 0.3, 0.2, Vector3(1.0, 0.3, -1.0))
	Parts.wheel(visual, 0.2, 0.15, Vector3(0, 0.2, 3.0))
	_prop = Node3D.new()
	_prop.position = Vector3(0, 1.4, -3.6)
	visual.add_child(_prop)
	Parts.box(_prop, Vector3(2.4, 0.2, 0.08), Color(0.2, 0.2, 0.2), Vector3.ZERO)


func get_speed() -> float:
	return _speed


func hud_extra() -> String:
	return "ALT %d ft   THR %d%%" % [roundi(global_position.y * 3.281), roundi(throttle * 100)]


func _physics_process(delta: float) -> void:
	var pitch_in := 0.0
	var roll_in := 0.0
	var yaw_in := 0.0
	if active:
		pitch_in = Input.get_axis("pitch_down", "pitch_up")
		roll_in = Input.get_axis("steer_left", "steer_right")
		yaw_in = Input.get_axis("yaw_right", "yaw_left")
		throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * 0.6 * delta, 0.0, 1.0)

	var fwd := -global_basis.z
	# Throttle pulls speed toward a target; climbing bleeds speed, diving adds it.
	_speed += (throttle * max_speed - _speed) * 0.3 * delta
	_speed -= fwd.y * GRAVITY * delta
	_speed = maxf(_speed, 0.0)

	var grounded := global_position.y <= GROUND_Y + 0.05
	if grounded:
		# Taxi: A/D steer on the ground, wings stay level, nose only lifts once fast enough.
		rotate_y(-roll_in * 1.0 * clampf(_speed / 10.0, 0.0, 1.0) * delta)
		rotation.z = move_toward(rotation.z, 0.0, 2.0 * delta)
		if pitch_in > 0.0 and _speed > takeoff_speed:
			rotation.x = minf(rotation.x + pitch_rate * pitch_in * delta, 0.35)
		else:
			rotation.x = move_toward(rotation.x, 0.0, 1.5 * delta)
		rotation.x = maxf(rotation.x, 0.0)
		if throttle < 0.05:
			_speed = move_toward(_speed, 0.0, 4.0 * delta)
	else:
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
