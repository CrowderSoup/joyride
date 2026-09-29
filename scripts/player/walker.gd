class_name Walker
extends CharacterBody3D
## You, on foot. Walk up to a vehicle and hop in. Same tank-style controls as driving:
## W/S forward/back, A/D turn, so the chase camera just works.

const GRAVITY := 25.0

var display_name := "On foot"
var walk_speed := 3.5
var run_speed := 7.5
var turn_rate := 3.2
var jump_speed := 7.0
var camera_distance := 6.5
var camera_height := 2.8

var active := true
var visual := Node3D.new()
var shape := CapsuleShape3D.new()
var _speed := 0.0
var _phase := 0.0
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []


func _init() -> void:
	shape.radius = 0.35
	shape.height = 1.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	add_child(visual)

	var denim := Color(0.2, 0.26, 0.4)
	var flannel := Color(0.6, 0.15, 0.12)
	var skin := Color(0.85, 0.66, 0.52)
	for sx in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(sx * 0.12, 0.95, 0)
		visual.add_child(hip)
		Parts.box(hip, Vector3(0.2, 0.9, 0.24), denim, Vector3(0, -0.45, 0))
		Parts.box(hip, Vector3(0.22, 0.1, 0.32), Color(0.25, 0.18, 0.12), Vector3(0, -0.9, -0.04))
		_legs.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(sx * 0.36, 1.56, 0)
		visual.add_child(shoulder)
		Parts.box(shoulder, Vector3(0.16, 0.6, 0.18), flannel, Vector3(0, -0.3, 0))
		Parts.box(shoulder, Vector3(0.12, 0.12, 0.12), skin, Vector3(0, -0.66, 0))
		_arms.append(shoulder)
	Parts.box(visual, Vector3(0.56, 0.66, 0.3), flannel, Vector3(0, 1.28, 0))
	Parts.box(visual, Vector3(0.28, 0.3, 0.28), skin, Vector3(0, 1.8, 0))
	# Ball cap, brim forward (-Z).
	Parts.box(visual, Vector3(0.31, 0.1, 0.31), Color(0.1, 0.12, 0.2), Vector3(0, 1.98, 0))
	Parts.box(visual, Vector3(0.28, 0.03, 0.16), Color(0.1, 0.12, 0.2), Vector3(0, 1.94, -0.21))


func get_speed() -> float:
	return _speed


func hud_extra() -> String:
	return ""


func stop() -> void:
	velocity = Vector3.ZERO
	_speed = 0.0


func _physics_process(delta: float) -> void:
	var move := 0.0
	var turn := 0.0
	var running := false
	if active:
		move = Input.get_axis("move_back", "move_forward")
		turn = Input.get_axis("steer_right", "steer_left")
		running = Input.is_action_pressed("sprint")
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_speed

	rotate_y(turn * turn_rate * delta)
	var target := move * (run_speed if running else walk_speed)
	if move < 0.0:
		target *= 0.6  # backpedaling is slower
	_speed = move_toward(_speed, target, 25.0 * delta)
	var fwd := -global_basis.z
	velocity.x = fwd.x * _speed
	velocity.z = fwd.z * _speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()

	# Swing arms and legs in step with how fast we're going.
	var pace := absf(_speed)
	_phase += pace * delta * 2.4
	var swing := sin(_phase) * clampf(pace / 4.0, 0.0, 1.0) * 0.7
	if not is_on_floor():
		swing = 0.4
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
