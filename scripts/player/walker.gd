class_name Walker
extends CharacterBody3D
## You, on foot. Walk up to a vehicle and hop in. Moves relative to the camera: push a
## direction and he turns and heads that way. Hold Shift to run.
## The body is built from smooth primitives with jointed limbs (hips, knees, shoulders,
## elbows) so walking and running read as different gaits.

const GRAVITY := 25.0
const HIP_Y := 0.95

var display_name := "On foot"
var walk_speed := 4.5
var run_speed := 9.0
var turn_rate := 12.0  # rad/s, turning to face where you're heading
var jump_speed := 7.0
var camera_distance := 6.5
var camera_height := 2.8

var active := true
var visual := Node3D.new()
var shape := CapsuleShape3D.new()
var _speed := 0.0
var _phase := 0.0
var _run := 0.0     # 0 = walking gait, 1 = running gait (blended)
var _step_player: AudioStreamPlayer3D
var _hips: Node3D   # bobs; carries the legs and torso
var _torso: Node3D  # leans into a run
var _legs: Array[Node3D] = []    # hip joints
var _knees: Array[Node3D] = []
var _arms: Array[Node3D] = []    # shoulder joints
var _elbows: Array[Node3D] = []
var _head: Node3D
var _cap: Array[Node3D] = []
var _mats := {}  # one material per color


func _init() -> void:
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	add_child(visual)
	_build_body()
	floor_constant_speed = true
	_step_player = Sfx.player(self, -12.0)
	_step_player.stream = Sfx.step()


func get_speed() -> float:
	return _speed


func hud_extra() -> String:
	return ""


func stop() -> void:
	velocity = Vector3.ZERO
	_speed = 0.0


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO  # x = right, y = forward, relative to the camera
	var running := false
	if active:
		input = Input.get_vector("steer_left", "steer_right", "move_back", "move_forward")
		running = Input.is_action_pressed("sprint")
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_speed

	var target := 0.0
	var cam := get_viewport().get_camera_3d()
	if input.length() > 0.05 and cam:
		var cam_fwd := -cam.global_basis.z
		var cam_right := cam.global_basis.x
		cam_fwd.y = 0.0
		cam_right.y = 0.0
		var dir := cam_right.normalized() * input.x + cam_fwd.normalized() * input.y
		rotation.y = rotate_toward(rotation.y, atan2(-dir.x, -dir.z), turn_rate * delta)
		target = minf(input.length(), 1.0) * (run_speed if running else walk_speed)
	_speed = move_toward(_speed, target, 20.0 * delta)
	var fwd := -global_basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_animate(delta)


func _animate(delta: float) -> void:
	var pace := absf(_speed)
	var moving := clampf(pace / 2.0, 0.0, 1.0)
	_run = move_toward(_run, clampf((pace - walk_speed) / (run_speed - walk_speed), 0.0, 1.0), 3.0 * delta)
	# One full cycle = two steps. Longer strides when running, so cadence doesn't go silly.
	var stride := lerpf(2.4, 3.6, _run)
	var prev_step := floori(_phase / PI)
	_phase = fmod(_phase + TAU * _speed / stride * delta, TAU)
	if floori(_phase / PI) != prev_step and pace > 0.5 and is_on_floor():
		_step_player.volume_db = lerpf(-14.0, -7.0, _run)
		_step_player.pitch_scale = randf_range(0.85, 1.15)
		_step_player.play()

	var leg_amp := lerpf(0.45, 0.85, _run) * moving
	var knee_amp := lerpf(0.6, 1.5, _run) * moving
	var arm_amp := lerpf(0.35, 0.9, _run) * moving
	var elbow := lerpf(0.25, 1.4, _run * moving) + 0.1
	var airborne := not is_on_floor()

	for side in 2:
		var p := _phase + PI * side
		var swing := sin(p) * leg_amp
		# Knee folds while that leg swings forward, straightens as it plants.
		var fold := maxf(0.0, cos(p)) * knee_amp + 0.05
		if airborne:
			swing = 0.5 if side == 0 else -0.2
			fold = 1.0 if side == 0 else 0.4
		_legs[side].rotation.x = swing
		_knees[side].rotation.x = -fold
		_arms[side].rotation.x = -sin(p) * arm_amp if not airborne else -0.6
		_arms[side].rotation.z = (0.12 + 0.08 * _run) * (-1.0 if side == 0 else 1.0)  # a bit away from the body
		_elbows[side].rotation.x = elbow if not airborne else 1.2

	# Bounce twice per cycle, lean into a run, and a little hip sway when walking.
	var bob := absf(cos(_phase)) * lerpf(0.03, 0.07, _run) * moving
	_hips.position.y = HIP_Y + bob - 0.04 * moving
	_hips.rotation.y = sin(_phase) * 0.08 * moving * (1.0 - _run)
	_torso.rotation.x = lerpf(_torso.rotation.x, -lerpf(0.03, 0.22, _run) * moving, 1.0 - exp(-8.0 * delta))
	_torso.rotation.y = -sin(_phase) * 0.12 * moving
	camera_distance = lerpf(6.5, 7.5, _run)


# --- Body -----------------------------------------------------------------

func _build_body() -> void:
	var skin := Color(0.86, 0.66, 0.52)
	var tee := Color(0.2, 0.21, 0.23)
	var denim := Color(0.38, 0.47, 0.6)
	var sneaker := Color(0.92, 0.92, 0.9)
	var sole := Color(0.22, 0.22, 0.24)
	var cap := Color(0.1, 0.1, 0.11)
	var beard := Color(0.3, 0.2, 0.13)

	_hips = _joint(visual, Vector3(0, HIP_Y, 0))
	_part(_hips, _capsule(0.165, 0.35), denim, Vector3(0, 0.02, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.75))

	for side in [-1.0, 1.0]:
		var leg := _joint(_hips, Vector3(side * 0.097, 0, 0))
		_part(leg, _capsule(0.083, 0.5), denim, Vector3(0, -0.22, 0))
		var knee := _joint(leg, Vector3(0, -0.44, 0))
		_part(knee, _capsule(0.07, 0.46), denim, Vector3(0, -0.2, 0))
		# Jeans stack a little over the shoes.
		_part(knee, _cylinder(0.072, 0.078, 0.08), denim.darkened(0.08), Vector3(0, -0.38, 0))
		var ankle := _joint(knee, Vector3(0, -0.44, 0))
		_part(ankle, _capsule(0.058, 0.28), sneaker, Vector3(0, -0.005, -0.06), Vector3(PI / 2, 0, 0), Vector3(1.15, 1, 0.75))
		_part(ankle, _capsule(0.062, 0.3), sole, Vector3(0, -0.035, -0.06), Vector3(PI / 2, 0, 0), Vector3(1.2, 1, 0.3))
		_legs.append(leg)
		_knees.append(knee)

	_torso = _joint(_hips, Vector3(0, 0.1, 0))
	# Broad shoulders tapering to the waist; flattened front to back.
	_part(_torso, _cylinder(0.225, 0.17, 0.46), tee, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1, 1, 0.64))
	_part(_torso, _sphere(0.225, 0.2), tee, Vector3(0, 0.44, 0), Vector3.ZERO, Vector3(1.05, 0.5, 0.66))
	# Loose tee hanging over the jeans.
	_part(_torso, _cylinder(0.175, 0.185, 0.1), tee, Vector3(0, -0.01, 0), Vector3.ZERO, Vector3(1, 1, 0.74))
	_part(_torso, _cylinder(0.058, 0.064, 0.1), skin, Vector3(0, 0.55, 0))

	# Head: nose, ears, short beard, sunglasses, snapback on backwards.
	var head := _joint(_torso, Vector3(0, 0.68, 0))
	_head = head
	_part(head, _sphere(0.115, 0.26), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 1.05))
	_part(head, _sphere(0.118, 0.236, true), beard, Vector3(0, -0.035, -0.004), Vector3(PI, 0, 0), Vector3(1, 0.62, 1.03))
	# Hair: a shell nudged back so it covers the back and sides but not the face.
	_part(head, _sphere(0.116, 0.232), beard, Vector3(0, 0.005, 0.022), Vector3.ZERO, Vector3(1.03, 0.97, 1.0))
	_part(head, _sphere(0.022, 0.05), skin.darkened(0.05), Vector3(0, -0.005, -0.12))
	_part(head, _capsule(0.026, 0.14), Color(0.04, 0.04, 0.05), Vector3(0, 0.018, -0.106), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.35))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.025, 0.055), skin.darkened(0.05), Vector3(side * 0.112, 0, 0.005), Vector3.ZERO, Vector3(0.5, 1, 1))
		_part(head, _capsule(0.006, 0.11), Color(0.04, 0.04, 0.05), Vector3(side * 0.106, 0.03, -0.05), Vector3(PI / 2, 0, 0))
	_cap.append(_part(head, _sphere(0.121, 0.24, true), cap, Vector3(0, 0.03, 0.005), Vector3.ZERO, Vector3(1, 0.7, 1.04)))
	_cap.append(_part(head, _cylinder(0.09, 0.09, 0.012), cap, Vector3(0, 0.03, 0.12), Vector3(-0.15, 0, 0), Vector3(1.05, 1, 0.9)))

	for side in [-1.0, 1.0]:
		var arm := _joint(_torso, Vector3(side * 0.235, 0.43, 0))
		_part(arm, _sphere(0.068, 0.13), tee, Vector3(0, -0.01, 0))
		_part(arm, _cylinder(0.07, 0.066, 0.18), tee, Vector3(0, -0.08, 0))  # short sleeve
		_part(arm, _capsule(0.056, 0.32), skin, Vector3(0, -0.15, 0))
		var elbow := _joint(arm, Vector3(0, -0.29, 0))
		_part(elbow, _capsule(0.05, 0.3), skin, Vector3(0, -0.12, 0))
		_part(elbow, _sphere(0.05, 0.11), skin, Vector3(0, -0.3, -0.005), Vector3.ZERO, Vector3(0.75, 1, 1))
		if side < 0.0:
			_part(elbow, _cylinder(0.05, 0.05, 0.03), Color(0.08, 0.08, 0.09), Vector3(0, -0.23, 0))  # watch
		_arms.append(arm)
		_elbows.append(elbow)


## The same guy, posed sitting on a bike with his hands out on the bars and a helmet on
## instead of the cap. hips is where his hips go in the bike's space; the pose is a
## sport-standard crouch: hands forward and down, knees tucked, feet back on the pegs.
static func make_rider(hips: Vector3) -> Node3D:
	var w := Walker.new()
	var fig := w.visual
	w.remove_child(fig)
	fig.position = hips - Vector3(0, HIP_Y, 0)
	for part in w._cap:
		part.visible = false
	# Full-face helmet: the shell, and a flatter, deeper ellipsoid that only breaks through
	# the shell across the front, which reads as the visor.
	w._part(w._head, _sphere(0.15, 0.3), Color(0.9, 0.42, 0.06), Vector3(0, 0.0, 0.01), Vector3.ZERO, Vector3(0.95, 1.1, 1.08))
	w._part(w._head, _sphere(0.15, 0.3), Color(0.02, 0.03, 0.04), Vector3(0, 0.02, 0.01), Vector3.ZERO, Vector3(0.9, 0.5, 1.18))
	w._torso.rotation.x = -0.55
	w._head.rotation.x = 0.4
	for side in 2:
		var out := -1.0 if side == 0 else 1.0
		w._legs[side].rotation = Vector3(1.25, 0, 0.2 * out)
		w._knees[side].rotation.x = -2.1
		w._arms[side].rotation = Vector3(1.3, 0, 0.22 * out)
		w._elbows[side].rotation.x = 0.45
	w.free()
	return fig


static func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _part(parent: Node3D, mesh: PrimitiveMesh, color: Color, pos: Vector3,
		rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	mesh.material = _mat(color)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation = rot
	inst.scale = scale
	parent.add_child(inst)
	return inst


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.75
		_mats[key] = mat
	return _mats[key]


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 6
	return m


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	m.rings = 1
	return m


static func _sphere(radius: float, height: float, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.is_hemisphere = hemisphere
	m.radial_segments = 16
	m.rings = 8
	return m
