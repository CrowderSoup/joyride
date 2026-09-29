class_name ChaseCamera
extends Camera3D
## Follows the active vehicle from behind, widening FOV with speed.

const BASE_FOV := 70.0
const SPEED_FOV := 18.0

var target: Node3D


func _init() -> void:
	far = 40000.0
	fov = BASE_FOV
	# We already follow the target's interpolated transform every frame.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## snap = jump straight there; otherwise glide over (getting in and out of vehicles).
func set_target(new_target: Node3D, snap := true) -> void:
	target = new_target
	if snap:
		global_position = _desired_position(target.global_transform)
	_look(target.global_transform)


func _process(delta: float) -> void:
	if target == null:
		return
	var t := target.get_global_transform_interpolated()
	global_position = global_position.lerp(_desired_position(t), 1.0 - exp(-6.0 * delta))
	_look(t)
	var speed_ratio := clampf(absf(target.get_speed()) / 50.0, 0.0, 1.0)
	fov = lerpf(fov, BASE_FOV + SPEED_FOV * speed_ratio, 1.0 - exp(-3.0 * delta))


func _desired_position(t: Transform3D) -> Vector3:
	var back := t.basis.z
	if not target is Airplane:
		back.y = 0.0
	back = back.normalized()
	var pos: Vector3 = t.origin + back * target.camera_distance + Vector3.UP * target.camera_height
	pos.y = maxf(pos.y, 1.0)
	return pos


func _look(t: Transform3D) -> void:
	var focus := t.origin + Vector3.UP * 1.5
	if not global_position.is_equal_approx(focus):
		look_at(focus, Vector3.UP)
