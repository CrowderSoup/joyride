class_name Motorcycle
extends RefCounted
## Middleweight naked bike (parallel twin, think MT-07 / Z650) - low-poly.
## Rough real dimensions: 2.08 m long, 1.42 m wheelbase, 0.80 m seat height,
## 120/70-17 front and 180/55-17 rear tires. Faces -Z; origin on the ground, mid-bike.
## The fork, bars and front wheel hang off a raked steering head so they turn together.

const PAINT := Color(0.9, 0.42, 0.06)  # orange; change this one line for another color
const FRONT_AXLE := Vector3(0, 0.30, -0.71)
const REAR_AXLE := Vector3(0, 0.31, 0.71)
const FRONT_RADIUS := 0.30
const REAR_RADIUS := 0.31
const HEAD := Vector3(0, 1.0, -0.43)  # top of the steering head
const RAKE := 0.44  # ~25 degrees
const PIVOT := Vector3(0, 0.50, 0.20)  # swingarm pivot


static func make() -> GroundVehicle:
	var v := GroundVehicle.new()
	v.display_name = "Motorcycle"
	v.top_speed = 55.0
	v.acceleration = 20.0
	v.steer_rate = 2.6
	v.steer_angle = 0.3
	v.grip = 12.0
	v.handbrake_grip = 2.0
	v.lean_amount = -0.55  # bank the bike and rider inward, opposite a car's body roll
	v.camera_distance = 6.5
	v.camera_height = 2.5
	v.first_person_offset = Vector3(0, 1.5, -0.05)
	v.enter_radius = 2.2
	v.exit_offset = Vector3(-1.0, 0, 0)
	v.footprint = Vector2(0.35, 1.05)
	Parts.collision_box(v, Vector3(0.7, 1.3, 2.1), Vector3(0, 0.65, 0))
	v.add_engine(EngineSound.BIKE)

	var chassis := MeshInstance3D.new()
	chassis.mesh = _chassis_mesh()
	v.visual.add_child(chassis)

	var head := Node3D.new()
	head.position = HEAD
	head.rotation.x = RAKE
	v.visual.add_child(head)
	v.steering = Node3D.new()
	head.add_child(v.steering)
	var axle_local := head.transform.affine_inverse() * FRONT_AXLE
	var front_end := MeshInstance3D.new()
	front_end.mesh = _front_end_mesh(axle_local, head.transform.basis)
	v.steering.add_child(front_end)

	v.add_wheel(_wheel_mesh(FRONT_RADIUS, 0.12, [-0.07, 0.07], false), axle_local, FRONT_RADIUS, false, v.steering)
	v.add_wheel(_wheel_mesh(REAR_RADIUS, 0.18, [0.08], true), REAR_AXLE, REAR_RADIUS, false)

	v.rider = Walker.make_rider(Vector3(0, 0.86, 0.30))
	v.rider.visible = false
	v.visual.add_child(v.rider)
	return v


static func _materials(m: ModelBuilder) -> void:
	m.add_material("paint", PAINT, 0.25, 0.3)
	m.add_material("frame", Color(0.08, 0.08, 0.09), 0.45, 0.5)
	m.add_material("engine", Color(0.12, 0.12, 0.13), 0.6, 0.4)
	m.add_material("alloy", Color(0.62, 0.63, 0.65), 0.35, 0.8)
	m.add_material("chrome", Color(0.8, 0.81, 0.83), 0.15, 0.9)
	m.add_material("seat", Color(0.07, 0.07, 0.075), 0.9)
	m.add_material("rubber", Color(0.05, 0.05, 0.05), 0.9)
	m.add_material("gold", Color(0.85, 0.62, 0.2), 0.25, 0.9)
	m.add_material("glass", Color(0.8, 0.85, 0.9), 0.05, 0.3, 0.4)
	m.add_material("taillight", Color(0.75, 0.04, 0.04), 0.2, 0.0, 0.6)
	m.add_material("amber", Color(0.95, 0.5, 0.05), 0.2, 0.0, 0.4)
	m.add_material("plate", Color(0.95, 0.95, 0.92), 0.5)
	m.add_material("spring", Color(0.95, 0.75, 0.1), 0.4, 0.3)


## Frame, engine, tank, seat, tail, swingarm - everything that doesn't steer.
static func _chassis_mesh() -> ArrayMesh:
	var m := ModelBuilder.new()
	_materials(m)

	# Tank: fat and rounded, sloping down into the seat.
	var tank := [
		[-0.47, 0.12, 0.90, 0.97], [-0.40, 0.17, 0.86, 1.06], [-0.24, 0.20, 0.84, 1.12],
		[-0.05, 0.18, 0.85, 1.10], [0.08, 0.14, 0.87, 1.03], [0.14, 0.10, 0.88, 0.97],
	]
	m.loft("paint", _sections(tank, 0.6), true)
	# Radiator shrouds hanging off the front of the tank.
	for sx in [-1.0, 1.0]:
		m.extrude("paint", PackedVector2Array([
			Vector2(-0.53, 0.94), Vector2(-0.34, 0.90), Vector2(-0.30, 0.76), Vector2(-0.40, 0.68), Vector2(-0.52, 0.76),
		]), 0.012, sx * 0.19)

	# Seat, with a step up to the pillion; tail cowl underneath, up to a tail light.
	var seat := [
		[0.10, 0.11, 0.86, 0.93], [0.18, 0.15, 0.80, 0.87], [0.40, 0.15, 0.79, 0.86],
		[0.50, 0.13, 0.82, 0.91], [0.74, 0.09, 0.85, 0.94], [0.80, 0.06, 0.87, 0.93],
	]
	m.loft("seat", _sections(seat, 0.8), true)
	# Side covers filling in under the front of the seat.
	m.loft("frame", _sections([[0.08, 0.10, 0.64, 0.86], [0.24, 0.13, 0.66, 0.82], [0.42, 0.12, 0.70, 0.82]], 0.5))
	var tail := [
		[0.34, 0.13, 0.66, 0.81], [0.60, 0.11, 0.74, 0.86], [0.86, 0.07, 0.81, 0.89], [0.96, 0.04, 0.84, 0.88],
	]
	m.loft("paint", _sections(tail, 0.7), true)
	m.box("taillight", Vector3(0, 0.86, 0.955), Vector3(0.1, 0.035, 0.03))
	m.tube("frame", Vector3(0, 0.80, 0.85), Vector3(0, 0.60, 1.00), 0.012, 6)
	m.box("plate", Vector3(0, 0.55, 1.00), Vector3(0.18, 0.12, 0.01))
	for sx in [-1.0, 1.0]:
		m.tube("frame", Vector3(0, 0.70, 0.95), Vector3(sx * 0.11, 0.70, 0.95), 0.008, 6)
		m.tube("amber", Vector3(sx * 0.11, 0.70, 0.94), Vector3(sx * 0.11, 0.70, 0.99), 0.018, 8)

	# Trellis-ish frame: spars from the steering head around the engine to the swingarm pivot.
	var head_bottom := HEAD + Basis(Vector3.RIGHT, RAKE) * Vector3(0, -0.16, 0)
	m.tube("frame", HEAD + Vector3(0, 0.02, 0), head_bottom, 0.035, 12)
	for sx in [-1.0, 1.0]:
		var top := Vector3(sx * 0.13, 0.90, -0.12)
		var rear := Vector3(sx * 0.13, 0.72, 0.16)
		var pivot := PIVOT + Vector3(sx * 0.12, 0, 0)
		m.tube("frame", HEAD, top, 0.022)
		m.tube("frame", head_bottom, Vector3(sx * 0.13, 0.66, -0.20), 0.02)
		m.tube("frame", Vector3(sx * 0.13, 0.66, -0.20), top, 0.018)
		m.tube("frame", Vector3(sx * 0.13, 0.66, -0.20), rear, 0.018)
		m.tube("frame", top, rear, 0.022)
		m.tube("frame", rear, pivot, 0.024)
		m.cylinder_x("frame", pivot, 0.04, 0.05, 10)
		# Subframe up under the seat.
		m.tube("frame", rear, Vector3(sx * 0.08, 0.81, 0.80), 0.014, 8)
		m.tube("frame", pivot + Vector3(0, 0.04, 0.02), Vector3(sx * 0.09, 0.76, 0.58), 0.012, 8)
		# Swingarm and the chain adjusters at the axle.
		var axle := REAR_AXLE + Vector3(sx * 0.11, 0, 0)
		m.loft("alloy", [
			ModelBuilder.circle(pivot, (axle - pivot).normalized(), 0.035, 8),
			ModelBuilder.circle(axle, (axle - pivot).normalized(), 0.025, 8),
		], true)
		m.cylinder_x("alloy", axle, 0.03, 0.03, 8)
		# Rider and passenger pegs.
		m.tube("rubber", Vector3(sx * 0.12, 0.40, 0.18), Vector3(sx * 0.22, 0.40, 0.18), 0.016, 8)
		m.extrude("alloy", PackedVector2Array([
			Vector2(0.12, 0.38), Vector2(0.14, 0.52), Vector2(0.22, 0.52), Vector2(0.21, 0.38),
		]), 0.008, sx * 0.13)
		m.tube("rubber", Vector3(sx * 0.1, 0.52, 0.52), Vector3(sx * 0.19, 0.52, 0.52), 0.013, 8)
	m.tube("alloy", PIVOT + Vector3(-0.12, 0, 0.18), PIVOT + Vector3(0.12, 0, 0.18), 0.02, 8)
	# Mono shock, laid down under the seat.
	m.tube("engine", Vector3(0, 0.45, 0.36), Vector3(0, 0.62, 0.26), 0.022, 8)
	m.tube("spring", Vector3(0, 0.62, 0.26), Vector3(0, 0.78, 0.17), 0.04, 10)

	# Parallel twin: crankcase, cylinder block leaning forward, head, side covers.
	m.extrude("engine", PackedVector2Array([
		Vector2(-0.38, 0.30), Vector2(-0.42, 0.50), Vector2(-0.12, 0.60), Vector2(0.14, 0.58),
		Vector2(0.18, 0.40), Vector2(0.06, 0.26), Vector2(-0.26, 0.24),
	]), 0.14)
	m.extrude("engine", PackedVector2Array([
		Vector2(-0.42, 0.48), Vector2(-0.50, 0.76), Vector2(-0.22, 0.83), Vector2(-0.12, 0.58),
	]), 0.155)
	for i in 4:
		var y := 0.56 + i * 0.05
		m.extrude("alloy", PackedVector2Array([
			Vector2(-0.43 - (y - 0.5) * 0.28, y), Vector2(-0.43 - (y - 0.5) * 0.28 - 0.015, y + 0.012),
			Vector2(-0.14 - (y - 0.5) * 0.3, y + 0.03), Vector2(-0.13 - (y - 0.5) * 0.3, y + 0.018),
		]), 0.162)
	m.extrude("alloy", PackedVector2Array([
		Vector2(-0.50, 0.76), Vector2(-0.52, 0.84), Vector2(-0.25, 0.91), Vector2(-0.22, 0.83),
	]), 0.14)
	m.cylinder_x("alloy", Vector3(0.14, 0.42, -0.04), 0.12, 0.04, 16)
	m.cylinder_x("alloy", Vector3(-0.14, 0.44, -0.20), 0.09, 0.04, 14)
	m.cylinder_x("engine", Vector3(-0.13, 0.44, 0.06), 0.05, 0.03, 10)  # front sprocket cover
	# Radiator, tipped back behind the front wheel.
	m.extrude("frame", PackedVector2Array([
		Vector2(-0.52, 0.56), Vector2(-0.60, 0.88), Vector2(-0.555, 0.89), Vector2(-0.475, 0.57),
	]), 0.19)
	m.extrude("engine", PackedVector2Array([
		Vector2(-0.535, 0.58), Vector2(-0.61, 0.87), Vector2(-0.60, 0.87), Vector2(-0.525, 0.58),
	]), 0.17)

	# Two headers sweeping under the engine into a stubby belly can on the right.
	for sx in [-1.0, 1.0]:
		var pts := [
			Vector3(sx * 0.07, 0.72, -0.50), Vector3(sx * 0.07, 0.58, -0.60),
			Vector3(sx * 0.06, 0.34, -0.52), Vector3(sx * 0.04, 0.2, -0.30), Vector3(0.03, 0.18, -0.02),
		]
		for i in pts.size() - 1:
			m.tube("chrome", pts[i], pts[i + 1], 0.024, 8)
	m.loft("engine", [
		ModelBuilder.circle(Vector3(0.05, 0.19, -0.04), Vector3(0.3, 0.2, 1).normalized(), 0.05, 12),
		ModelBuilder.circle(Vector3(0.14, 0.26, 0.28), Vector3(0.3, 0.2, 1).normalized(), 0.09, 12),
		ModelBuilder.circle(Vector3(0.18, 0.29, 0.40), Vector3(0.3, 0.2, 1).normalized(), 0.08, 12),
	], true)
	m.tube("chrome", Vector3(0.18, 0.29, 0.40), Vector3(0.19, 0.30, 0.43), 0.035, 10)

	# Chain on the left, from the front sprocket to the rear one.
	var front_sprocket := Vector3(-0.1, 0.44, 0.06)
	var rear_sprocket := REAR_AXLE + Vector3(-0.1, 0, 0)
	for dy in [-1.0, 1.0]:
		m.tube("engine", front_sprocket + Vector3(0, dy * 0.05, 0), rear_sprocket + Vector3(0, dy * 0.1, 0), 0.01, 6)
	return m.build()


## Rounded cross-sections for loft, from rows of [z, half_width, bottom, top]. roundness is the
## corner radius as a fraction of the smaller half-dimension.
static func _sections(rows: Array, roundness: float) -> Array:
	var rings := []
	for row in rows:
		var r := minf(row[1], (row[3] - row[2]) * 0.5) * roundness
		rings.append(ModelBuilder.rounded_section(row[0], row[1], row[2], row[3], r, 2, 4))
	return rings


## Fork, bars, headlight and fender, in the steering head's (raked) frame. axle is the front
## axle in that frame; head_basis turns world directions into it.
static func _front_end_mesh(axle: Vector3, head_basis: Basis) -> ArrayMesh:
	var m := ModelBuilder.new()
	_materials(m)
	var to_local := head_basis.inverse()
	var fwd := to_local * Vector3.FORWARD

	# Upside-down fork: gold tubes up top, black sliders down to the axle.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.09
		m.tube("frame", Vector3(x, axle.y, axle.z), Vector3(x, axle.y + 0.38, axle.z), 0.024, 10)
		m.tube("gold", Vector3(x, axle.y + 0.34, axle.z), Vector3(x, 0.08, axle.z), 0.03, 10)
		m.cylinder_x("frame", Vector3(x, axle.y, axle.z), 0.035, 0.05, 8)
		# Brake caliper hugging the disc behind the fork leg.
		m.box("gold", Vector3(sx * 0.075, axle.y + 0.14, axle.z + 0.1), Vector3(0.035, 0.14, 0.06))
	# Triple clamps and the steering stem.
	for y in [0.0, -0.16]:
		m.box("alloy", Vector3(0, y, axle.z * 0.5), Vector3(0.24, 0.03, absf(axle.z) + 0.08))
	# Bars on risers, with grips, levers and bar-end mirrors on stalks.
	m.tube("alloy", Vector3(-0.03, 0.02, 0.0), Vector3(-0.03, 0.10, 0.0), 0.018, 8)
	m.tube("alloy", Vector3(0.03, 0.02, 0.0), Vector3(0.03, 0.10, 0.0), 0.018, 8)
	var bar_y := 0.11
	var bars := [Vector3(-0.38, bar_y + 0.03, 0.10), Vector3(-0.16, bar_y, 0.02), Vector3(0.16, bar_y, 0.02), Vector3(0.38, bar_y + 0.03, 0.10)]
	for i in bars.size() - 1:
		m.tube("frame", bars[i], bars[i + 1], 0.012, 8)
	for sx in [-1.0, 1.0]:
		var end := Vector3(sx * 0.38, bar_y + 0.03, 0.10)
		m.tube("rubber", end - Vector3(sx * 0.12, 0, 0.03), end + Vector3(sx * 0.01, 0, 0), 0.02, 8)
		m.tube("alloy", end - Vector3(sx * 0.14, -0.01, 0.06), end - Vector3(sx * 0.02, -0.02, 0.1), 0.006, 6)
		var stalk_top := Vector3(sx * 0.33, bar_y + 0.17, 0.0)
		m.tube("frame", Vector3(sx * 0.23, bar_y + 0.02, 0.05), stalk_top, 0.007, 6)
		m.loft("frame", [
			ModelBuilder.circle(stalk_top + fwd * 0.005, fwd, 0.055, 10),
			ModelBuilder.circle(stalk_top - fwd * 0.015, fwd, 0.055, 10),
		])
		m.loft("glass", [
			ModelBuilder.circle(stalk_top - fwd * 0.015, fwd, 0.048, 10),
			ModelBuilder.circle(stalk_top - fwd * 0.018, fwd, 0.048, 10),
		])
	# Little TFT dash and a round headlight in a short nacelle.
	m.box("frame", Vector3(0, 0.09, -0.05), Vector3(0.16, 0.10, 0.03))
	m.box("glass", Vector3(0, 0.09, -0.035), Vector3(0.13, 0.07, 0.002))
	var lamp := Vector3(0, -0.12, -0.13)
	m.loft("frame", [
		ModelBuilder.circle(lamp - fwd * 0.12, fwd, 0.07, 16),
		ModelBuilder.circle(lamp - fwd * 0.02, fwd, 0.1, 16),
		ModelBuilder.circle(lamp + fwd * 0.03, fwd, 0.105, 16),
	], true)
	m.loft("glass", [
		ModelBuilder.circle(lamp + fwd * 0.03, fwd, 0.095, 16),
		ModelBuilder.circle(lamp + fwd * 0.045, fwd, 0.08, 16),
	], true)
	for sx in [-1.0, 1.0]:
		m.tube("amber", lamp + Vector3(sx * 0.14, 0.0, 0.02), lamp + Vector3(sx * 0.14, 0.0, 0.02) + fwd * 0.05, 0.016, 8)
		m.tube("frame", lamp + Vector3(sx * 0.09, 0.0, 0.05), lamp + Vector3(sx * 0.14, 0.0, 0.05), 0.006, 6)

	# Short front fender over the tire, painted to match.
	m.extrude("paint", _partial_arch(Vector2(axle.z, axle.y), FRONT_RADIUS + 0.03, FRONT_RADIUS + 0.05, 0.8, 2.2), 0.07)
	return m.build()


## Ring segment in (z, y) around center, between angles a0 and a1 (0 = +z, PI/2 = up).
static func _partial_arch(center: Vector2, inner: float, outer: float, a0: float, a1: float, segments := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / segments)
		pts.append(center + Vector2(cos(a), sin(a)) * outer)
	for i in segments + 1:
		var a := lerpf(a1, a0, float(i) / segments)
		pts.append(center + Vector2(cos(a), sin(a)) * inner)
	return pts


## Bike wheel: round-profile tire, 17" cast rim with split spokes, brake discs at disc_xs.
## Symmetric about x = 0 so it doesn't need mirroring; the rear one carries the sprocket.
static func _wheel_mesh(radius: float, width: float, disc_xs: Array, sprocket: bool) -> ArrayMesh:
	var m := ModelBuilder.new()
	m.add_material("tire", Color(0.07, 0.07, 0.07), 0.95)
	m.add_material("rim", Color(0.1, 0.1, 0.11), 0.4, 0.5)
	m.add_material("lip", PAINT, 0.3, 0.3)
	m.add_material("disc", Color(0.7, 0.71, 0.73), 0.35, 0.85)
	m.add_material("sprocket", Color(0.25, 0.25, 0.27), 0.4, 0.8)

	var rim_r := 0.216
	var hw := width * 0.5
	var a := hw * 0.8
	m.lathe("tire", PackedVector2Array([
		Vector2(-a, rim_r), Vector2(-hw, rim_r + 0.03), Vector2(-hw * 0.98, radius - 0.035),
		Vector2(-hw * 0.8, radius - 0.012), Vector2(-hw * 0.4, radius - 0.001), Vector2(0.0, radius),
		Vector2(hw * 0.4, radius - 0.001), Vector2(hw * 0.8, radius - 0.012), Vector2(hw * 0.98, radius - 0.035),
		Vector2(hw, rim_r + 0.03), Vector2(a, rim_r),
	]))
	# Rim barrel, with painted pinstripes on each lip.
	m.lathe("rim", PackedVector2Array([
		Vector2(-a, rim_r + 0.012), Vector2(a, rim_r + 0.012), Vector2(a, rim_r - 0.02), Vector2(-a, rim_r - 0.02),
	]))
	for sx in [-1.0, 1.0]:
		var x: float = sx * (a + 0.001)
		m.lathe("lip", PackedVector2Array([
			Vector2(x - 0.001, rim_r - 0.018), Vector2(x + 0.001, rim_r - 0.018),
			Vector2(x + 0.001, rim_r + 0.01), Vector2(x - 0.001, rim_r + 0.01),
		]))
	m.lathe("rim", PackedVector2Array([
		Vector2(-hw * 0.9, 0.0), Vector2(hw * 0.9, 0.0), Vector2(hw * 0.9, 0.05), Vector2(-hw * 0.9, 0.05),
	]), Vector3.ZERO, 12)
	# Three split spokes.
	for i in 3:
		var ang := TAU * i / 3.0 + 0.3
		for off in [-0.16, 0.16]:
			var dir := Vector2(cos(ang + off), sin(ang + off))
			var perp := dir.orthogonal() * 0.013
			m.extrude("rim", PackedVector2Array([
				dir * 0.04 - perp * 1.5, dir * (rim_r - 0.015) - perp, dir * (rim_r - 0.015) + perp, dir * 0.04 + perp * 1.5,
			]), 0.018)
	for x in disc_xs:
		var outer := 0.15 if not sprocket else 0.11
		m.lathe("disc", PackedVector2Array([
			Vector2(x - 0.003, outer - 0.035), Vector2(x + 0.003, outer - 0.035), Vector2(x + 0.003, outer), Vector2(x - 0.003, outer),
		]))
		# Carrier arms out to the floating disc.
		for i in 5:
			var ang := TAU * i / 5.0
			var dir := Vector2(cos(ang), sin(ang))
			var perp := dir.orthogonal() * 0.008
			m.extrude("rim", PackedVector2Array([
				dir * 0.045 - perp, dir * (outer - 0.03) - perp, dir * (outer - 0.03) + perp, dir * 0.045 + perp,
			]), 0.004, x)
	if sprocket:
		m.lathe("sprocket", PackedVector2Array([
			Vector2(-0.104, 0.04), Vector2(-0.096, 0.04), Vector2(-0.096, 0.105), Vector2(-0.104, 0.105),
		]), Vector3.ZERO, 20)
	return m.build()
