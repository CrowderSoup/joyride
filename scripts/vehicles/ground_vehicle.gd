class_name GroundVehicle
extends CharacterBody3D
## Arcade driving model shared by cars, trucks, and bikes. Not a sim - it's supposed to feel good.

const GRAVITY := 25.0

var display_name := "Car"
var top_speed := 45.0        # m/s (~100 mph)
var reverse_speed := 12.0
var acceleration := 14.0
var braking := 30.0
var rolling_drag := 2.0
var steer_rate := 2.0        # rad/s at full lock
var steer_angle := 0.55      # how far the front wheels (or bars) visibly turn at full lock
var grip := 10.0             # how fast sideways slide gets killed
var handbrake_grip := 1.2    # low grip = drift
var lean_amount := 0.04      # visual roll into turns
var pitch_amount := 0.0      # visual squat/dive per m/s^2 of acceleration
var camera_distance := 9.0
var camera_height := 3.5
var enter_radius := 3.0              # how close you have to walk to get in
var exit_offset := Vector3(-1.6, 0, 0)  # where you step out (driver's side); mirrored if blocked

var active := false
var visual := Node3D.new()
var body: Node3D             # the part that leans/pitches; null = the whole visual
var rider: Node3D            # only shown while someone's driving (bikes)
var steering: Node3D         # turns about its own Y with the steering (a bike's fork and bars)
var _steer := 0.0
var _speed := 0.0
var _prev_speed := 0.0
var _pitch := 0.0
var _wheels: Array = []      # [pivot, spinner, radius, steers]


func _init() -> void:
	add_child(visual)


## Adds a wheel that spins with speed (and steers, for front wheels). pos is in parent's
## space; a bike's front wheel goes under its steering node instead of steering itself.
func add_wheel(mesh: Mesh, pos: Vector3, radius: float, steers: bool, parent: Node3D = null) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	(parent if parent else visual).add_child(pivot)
	var spinner := Node3D.new()
	pivot.add_child(spinner)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	if pos.x < 0.0:
		inst.rotation.y = PI  # wheel meshes face +X; mirror for the left side
	spinner.add_child(inst)
	_wheels.append([pivot, spinner, radius, steers])


func get_speed() -> float:
	return _speed


func hud_extra() -> String:
	return ""


func set_driving(on: bool) -> void:
	active = on
	if rider:
		rider.visible = on


func can_exit() -> bool:
	return absf(_speed) < 2.0


func stop() -> void:
	velocity = Vector3.ZERO
	_speed = 0.0
	_prev_speed = 0.0


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := false
	if active:
		throttle = Input.get_axis("brake", "accelerate")
		steer_input = Input.get_axis("steer_right", "steer_left")
		handbrake = Input.is_action_pressed("handbrake")
	_steer = move_toward(_steer, steer_input, delta * 4.0)

	var fwd := -global_basis.z
	var planar := Vector3(velocity.x, 0, velocity.z)
	var speed := planar.dot(fwd)

	if throttle > 0.0:
		speed += (acceleration if speed >= 0.0 else braking) * throttle * delta
	elif throttle < 0.0:
		speed -= (braking if speed > 0.5 else acceleration * 0.6) * -throttle * delta
	else:
		# Parked vehicles sit on the brake instead of coasting.
		speed = move_toward(speed, 0.0, (rolling_drag if active else braking) * delta)
	if handbrake:
		speed = move_toward(speed, 0.0, 8.0 * delta)
	speed = clampf(speed, -reverse_speed, top_speed)

	# Steering authority ramps in from a standstill and softens at high speed.
	var speed_ratio := absf(speed) / top_speed
	var yaw := _steer * steer_rate * clampf(speed / 6.0, -1.0, 1.0) * (1.0 - 0.4 * speed_ratio)
	if handbrake:
		yaw *= 1.5
	rotate_y(yaw * delta)

	fwd = -global_basis.z
	var side := global_basis.x
	var lateral := planar.dot(side) * exp(-(handbrake_grip if handbrake else grip) * delta)
	# Keep a little of the slide when throwing it into a corner with the handbrake.
	if handbrake:
		lateral += -yaw * absf(speed) * 0.15 * delta
	planar = fwd * speed + side * lateral

	var vy := -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	velocity = Vector3(planar.x, vy, planar.z)
	move_and_slide()
	_speed = Vector3(velocity.x, 0, velocity.z).dot(-global_basis.z)

	var tilt := body if body else visual
	var target_lean := -_steer * lean_amount * clampf(_speed / 15.0, 0.0, 1.0)
	tilt.rotation.z = lerpf(tilt.rotation.z, target_lean, 1.0 - exp(-8.0 * delta))
	# Nose lifts under throttle, dives under braking.
	var accel := (_speed - _prev_speed) / delta
	_prev_speed = _speed
	_pitch = lerpf(_pitch, clampf(accel * pitch_amount, -0.05, 0.05), 1.0 - exp(-5.0 * delta))
	tilt.rotation.x = _pitch

	for w in _wheels:
		w[1].rotation.x -= _speed / w[2] * delta
		if w[3]:
			w[0].rotation.y = _steer * steer_angle
	if steering:
		steering.rotation.y = _steer * steer_angle
