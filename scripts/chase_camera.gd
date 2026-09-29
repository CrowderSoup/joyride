class_name ChaseCamera
extends Camera3D
## Third-person camera. In a vehicle it rides behind you (look around with the mouse or
## right stick; it swings back on its own). On foot it orbits freely - walking is relative
## to it - and drifts in behind you while you walk. Pulls in instead of clipping through
## walls, and FOV widens with speed.

const BASE_FOV := 70.0
const SPEED_FOV := 18.0
const MOUSE_SENSITIVITY := 0.004
const STICK_SPEED := 2.6     # rad/s at full right stick (or Q/E on foot)
const LOOK_RETURN_DELAY := 1.2

var target: Node3D
var _yaw := 0.0              # on foot: the orbit angle. In a vehicle: offset from straight behind.
var _tilt := 0.0             # raises/lowers the camera; springs back in vehicles
var _idle_look := 0.0        # seconds since the player last looked around
var _follow := Vector3.ZERO  # where the camera wants to be, before walls get in the way
var _boom := 1.0             # fraction of the way out to _follow that's clear


func _init() -> void:
	far = 40000.0
	fov = BASE_FOV
	# We already follow the target's interpolated transform every frame.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## snap = jump straight there; otherwise glide over (getting in and out of vehicles).
func set_target(new_target: Node3D, snap := true) -> void:
	var t := new_target.global_transform
	if new_target is Walker:
		# Keep looking the way we were: behind whatever you just got out of.
		var from := target.global_transform if target else t
		_yaw = _heading(from) + (0.0 if target is Walker or target == null else _yaw)
	else:
		_yaw = 0.0
	_tilt = 0.0
	target = new_target
	if snap:
		_follow = _desired_position(t)
		global_position = _follow
	_look(t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_tilt = clampf(_tilt + event.relative.y * MOUSE_SENSITIVITY * 0.8, -0.7, 1.6)
		_idle_look = 0.0


func _process(delta: float) -> void:
	if target == null:
		return
	var on_foot := target is Walker
	var stick := Input.get_axis("look_right", "look_left")
	if on_foot:
		stick = clampf(stick + Input.get_axis("orbit_right", "orbit_left"), -1.0, 1.0)
	if stick != 0.0:
		_yaw += stick * STICK_SPEED * delta
		_idle_look = 0.0
	_idle_look += delta

	var t := target.get_global_transform_interpolated()
	if on_foot:
		# Drift in behind the walker while they head away from the camera.
		var heading := _heading(t)
		var behind := angle_difference(_yaw, heading)
		if _idle_look > 0.4 and absf(behind) < 1.8:
			var pace := clampf(absf(target.get_speed()) / 9.0, 0.0, 1.0)
			_yaw += behind * minf(1.0, 1.2 * pace * delta)
	elif _idle_look > LOOK_RETURN_DELAY:
		_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-3.0 * delta))
		_tilt = lerpf(_tilt, 0.0, 1.0 - exp(-3.0 * delta))

	_follow = _follow.lerp(_desired_position(t), 1.0 - exp(-6.0 * delta))
	var focus := _focus(t)
	# Snap in front of anything between us and the target; ease back out once it's clear.
	var clear := _clear_fraction(focus, _follow)
	_boom = clear if clear < _boom else move_toward(_boom, clear, delta * 1.5)
	var pos := focus.lerp(_follow, _boom)
	pos.y = maxf(pos.y, Ground.height(pos.x, pos.z) + 0.6)
	global_position = pos
	_look(t)
	var speed_ratio := clampf(absf(target.get_speed()) / 50.0, 0.0, 1.0)
	fov = lerpf(fov, BASE_FOV + SPEED_FOV * speed_ratio, 1.0 - exp(-3.0 * delta))


static func _heading(t: Transform3D) -> float:
	var fwd := -t.basis.z
	return atan2(-fwd.x, -fwd.z)


func _desired_position(t: Transform3D) -> Vector3:
	var back: Vector3
	if target is Walker:
		back = Basis(Vector3.UP, _yaw).z
	elif target is Airplane:
		back = Basis(Vector3.UP, _yaw) * t.basis.z  # follow the plane's pitch too
	else:
		back = Basis(Vector3.UP, _yaw) * Vector3(t.basis.z.x, 0, t.basis.z.z).normalized()
	back = back.normalized()
	var height: float = target.camera_height * (1.0 + _tilt)
	return t.origin + back * target.camera_distance + Vector3.UP * height


func _focus(t: Transform3D) -> Vector3:
	return t.origin + Vector3.UP * 1.5


## How far from focus toward to we can go before hitting something (0..1).
func _clear_fraction(focus: Vector3, to: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(focus, to)
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var length := focus.distance_to(to)
	# Stop a little short so the near plane doesn't slice into the wall.
	return clampf((focus.distance_to(hit.position) - 0.4) / maxf(length, 0.01), 0.05, 1.0)


func _look(t: Transform3D) -> void:
	var focus := _focus(t)
	if not global_position.is_equal_approx(focus):
		look_at(focus, Vector3.UP)
