class_name GroundVehicle
extends Vehicle
## Arcade driving model shared by cars, trucks, and bikes. Not a sim - it's supposed to feel good.

const GRAVITY := 25.0
const SLOPE_PULL := GRAVITY  # hills slow you going up and let you coast down them
const GEARS := [0.14, 0.3, 0.5, 0.74, 1.0]  # top of each gear as a fraction of top speed

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

var body: Node3D             # the part that leans/pitches; null = the whole visual
var rider: Node3D            # only shown while someone's driving (bikes)
var steering: Node3D         # turns about its own Y with the steering (a bike's fork and bars)
var _steer := 0.0
var _speed := 0.0
var _prev_speed := 0.0
var _pitch := 0.0
var _lean := 0.0
var _wheels: Array = []      # [pivot, spinner, radius, steers]
# The collision box stays upright, so on a slope it rests on one edge. The visual drops
# down onto the ground under the middle and tilts to match it.
var _ground_basis := Basis.IDENTITY
var _ground_drop := 0.0
var _settle := 30            # physics frames to keep grounding the visual after spawning
var _halted := false         # stopped or teleported since the last step: ignore how we last moved
var _keep := 1.0             # speed left after bumps since the last step


func _init() -> void:
	super()
	display_name = "Car"
	floor_snap_length = 0.3
	# We hold parked vehicles still ourselves; this would also stop them rolling downhill.
	floor_stop_on_slope = false


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


func set_driving(on: bool) -> void:
	super(on)
	if rider:
		rider.visible = on


func bump(fraction: float) -> void:
	_keep *= 1.0 - fraction


func stop() -> void:
	super()
	_speed = 0.0
	_prev_speed = 0.0
	_settle = 30
	_halted = true


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	var handbrake := false
	if active:
		throttle = Input.get_axis("brake", "accelerate")
		steer_input = Input.get_axis("steer_right", "steer_left")
		handbrake = Input.is_action_pressed("handbrake")
	_steer = move_toward(_steer, steer_input, delta * 4.0)

	# Work in the plane of the ground while on it, so hills don't read as walls.
	var on_floor := is_on_floor()
	var up := get_floor_normal() if on_floor else Vector3.UP
	var fwd := _along(-global_basis.z, up)
	var side := _along(global_basis.x, up)
	# How we actually moved last step. (velocity comes back from move_and_slide with the
	# downhill part flattened off, which would bleed speed on every descent.)
	var moved := Vector3.ZERO if _halted else get_real_velocity()
	_halted = false
	var speed := moved.dot(fwd) * _keep
	var lateral := moved.dot(side)
	_keep = 1.0
	if on_floor:
		speed -= SLOPE_PULL * fwd.y * delta

	if throttle > 0.0:
		if speed < 0.0:
			speed += braking * throttle * delta
		elif speed < top_speed:
			speed = minf(speed + acceleration * throttle * delta, top_speed)
	elif throttle < 0.0:
		if speed > 0.5:
			speed -= braking * -throttle * delta
		elif speed > -reverse_speed:
			speed = maxf(speed - acceleration * 0.6 * -throttle * delta, -reverse_speed)
	elif on_floor:
		# Parked vehicles sit on the brake instead of coasting (or rolling downhill).
		speed = move_toward(speed, 0.0, (rolling_drag if active else braking) * delta)
	if handbrake and on_floor:
		speed = move_toward(speed, 0.0, 8.0 * delta)
	# Gravity can take you a bit past top speed downhill.
	speed = clampf(speed, -reverse_speed * 1.5, top_speed * 1.25)

	# Steering authority ramps in from a standstill and softens at high speed.
	var speed_ratio := clampf(absf(speed) / top_speed, 0.0, 1.0)
	var yaw := _steer * steer_rate * clampf(speed / 6.0, -1.0, 1.0) * (1.0 - 0.4 * speed_ratio)
	if handbrake:
		yaw *= 1.5
	if not on_floor:
		yaw *= 0.3  # a little air control
	rotate_y(yaw * delta)

	fwd = _along(-global_basis.z, up)
	side = _along(global_basis.x, up)
	var slide := lateral * exp(-(handbrake_grip if handbrake else grip) * delta)
	# Keep a little of the slide when throwing it into a corner with the handbrake.
	if handbrake:
		slide += -yaw * absf(speed) * 0.15 * delta
	if on_floor:
		# Along the ground only; floor snapping keeps us on it. (Pushing into it would look
		# like standing still to stop-on-slope, and we'd never start rolling downhill.)
		velocity = fwd * speed + side * slide
	else:
		velocity = fwd * speed + side * slide + Vector3.UP * (velocity.y - GRAVITY * delta)
	move_and_slide()
	_speed = get_real_velocity().dot(_along(-global_basis.z, get_floor_normal() if is_on_floor() else Vector3.UP))

	_animate(delta, throttle, absf(lateral))


## dir flattened onto the ground plane with normal up.
static func _along(dir: Vector3, up: Vector3) -> Vector3:
	return (dir - up * dir.dot(up)).normalized()


func _animate(delta: float, throttle: float, slip: float) -> void:
	_update_ground(delta)
	_lean = lerpf(_lean, -_steer * lean_amount * clampf(_speed / 15.0, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	# Nose lifts under throttle, dives under braking.
	var accel := (_speed - _prev_speed) / delta
	_prev_speed = _speed
	_pitch = lerpf(_pitch, clampf(accel * pitch_amount, -0.05, 0.05), 1.0 - exp(-5.0 * delta))
	var tilt := Basis.from_euler(Vector3(_pitch, 0, _lean))
	if body:
		body.basis = tilt
		visual.transform = Transform3D(_ground_basis, Vector3.UP * _ground_drop)
	else:
		visual.transform = Transform3D(_ground_basis * tilt, Vector3.UP * _ground_drop)

	for w in _wheels:
		w[1].rotation.x -= _speed / w[2] * delta
		if w[3]:
			w[0].rotation.y = _steer * steer_angle
	if steering:
		steering.rotation.y = _steer * steer_angle

	if engine:
		var ratio := absf(_speed) / top_speed
		var gear := 0
		while gear < GEARS.size() - 1 and ratio > GEARS[gear]:
			gear += 1
		var lo: float = GEARS[gear - 1] if gear > 0 else 0.0
		var rev := inverse_lerp(lo, GEARS[gear], minf(ratio, 1.0))
		# First gear revs from idle; the others drop back to mid-range after each shift.
		engine.rpm = rev if gear == 0 else lerpf(0.35, 1.0, rev)
		engine.rpm = maxf(engine.rpm, absf(throttle) * 0.25)
		engine.load = absf(throttle)
		engine.slip = clampf((slip - 3.0) / 6.0, 0.0, 1.0) if is_on_floor() else 0.0


## Drop the visual onto the ground under the middle of the vehicle and tilt it to match.
func _update_ground(delta: float) -> void:
	if not active and _settle <= 0 and velocity.length_squared() < 0.01:
		return
	_settle -= 1
	var from := global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var drop := 0.0
	var n := Vector3.UP
	if not hit.is_empty() and is_on_floor():
		drop = clampf(hit.position.y - global_position.y, -1.0, 0.0)
		n = global_basis.inverse() * hit.normal
	var k := 1.0 - exp(-12.0 * delta) if _settle < 25 else 1.0
	_ground_drop = lerpf(_ground_drop, drop, k)
	var target := Basis(Quaternion(Vector3.UP, n.normalized()))
	_ground_basis = _ground_basis.slerp(target, k).orthonormalized()
