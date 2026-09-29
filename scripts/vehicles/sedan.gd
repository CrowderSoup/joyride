class_name Sedan
extends RefCounted
## Generic modern midsize sedan (think Accord/Camry) - low-poly.
## Rough real dimensions: 4.9 m long, 1.84 m wide, 1.44 m tall, 2.83 m wheelbase,
## 235/45R18 tires (~0.68 m tall). Faces -Z; origin on the ground, mid-car.

const PAINT := Color(0.12, 0.42, 0.5)  # deep teal metallic; change this one line for another color
const FRONT_AXLE := Vector2(-1.42, 0.34)  # (z, y)
const REAR_AXLE := Vector2(1.41, 0.34)
const TIRE_RADIUS := 0.34
const TRACK_HALF := 0.80
const ROCKER_Y := 0.27
const ARCH_RADIUS := 0.40
const HALF_WIDTH := 0.92
const NOSE_Z := -2.46
const TAIL_Z := 2.48


static func make() -> GroundVehicle:
	var v := GroundVehicle.new()
	v.display_name = "Sedan"
	v.lean_amount = 0.05
	v.pitch_amount = 0.004
	v.exit_offset = Vector3(-1.6, 0, -0.2)
	Parts.collision_box(v, Vector3(1.84, 1.3, 4.9), Vector3(0, 0.7, 0))
	v.add_engine(EngineSound.SEDAN)

	v.body = Node3D.new()
	v.visual.add_child(v.body)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _body_mesh()
	v.body.add_child(mesh_inst)
	_add_badges(v.body)

	var wheel := _wheel_mesh()
	for z in [FRONT_AXLE.x, REAR_AXLE.x]:
		for sx in [-1.0, 1.0]:
			v.add_wheel(wheel, Vector3(sx * TRACK_HALF, TIRE_RADIUS, z), TIRE_RADIUS, z == FRONT_AXLE.x)
	return v


## Body sides: a little tumblehome up top and tuck at the rocker, and the nose and tail
## pinched in plan view so the corners read round instead of like a brick.
static func _body_half_width(z: float, y: float) -> float:
	var w := HALF_WIDTH - 0.035 * clampf((y - 0.82) / 0.2, 0.0, 1.0) - 0.025 * clampf((0.45 - y) / 0.18, 0.0, 1.0)
	var nose := clampf((-1.95 - z) / (-1.95 - NOSE_Z), 0.0, 1.0)
	var tail := clampf((z - 2.0) / (TAIL_Z - 2.0), 0.0, 1.0)
	return w - 0.16 * nose * nose - 0.10 * tail * tail


static func _cabin_half_width(y: float) -> float:
	return lerpf(0.86, 0.66, clampf((y - 0.96) / 0.48, 0.0, 1.0))


## z along the windshield / rear glass lines, for a given height.
static func _windshield_z(y: float) -> float:
	return -1.08 + (y - 0.95) * (0.80 / 0.48)


static func _rear_glass_z(y: float) -> float:
	return 0.78 + (1.43 - y) * (0.86 / 0.43)


static func _body_mesh() -> ArrayMesh:
	var m := ModelBuilder.new()
	m.add_material("paint", PAINT, 0.22, 0.45)
	m.add_material("trim", Color(0.05, 0.05, 0.06), 0.7)
	m.add_material("glass", Color(0.05, 0.07, 0.09), 0.05, 0.5)
	m.add_material("chrome", Color(0.8, 0.81, 0.83), 0.15, 0.9)
	m.add_material("grille", Color(0.03, 0.03, 0.035), 0.5)
	m.add_material("headlight", Color(0.55, 0.6, 0.66), 0.05, 0.7, 0.15)
	m.add_material("drl", Color(0.95, 0.97, 1.0), 0.1, 0.0, 1.5)
	m.add_material("taillight", Color(0.7, 0.03, 0.04), 0.15, 0.0, 0.5)
	m.add_material("plate", Color(0.95, 0.95, 0.92), 0.5)

	# Front clip: bumper, nose and the leading edge of the hood.
	m.extrude("paint", PackedVector2Array([
		Vector2(-1.95, ROCKER_Y), Vector2(-2.36, 0.29), Vector2(-2.45, 0.42), Vector2(NOSE_Z, 0.58),
		Vector2(-2.42, 0.70), Vector2(-2.30, 0.775), Vector2(-1.95, 0.83),
	]), _body_half_width)

	# Doors and fenders, both wheel arches cut out of one profile.
	var sides := PackedVector2Array([
		Vector2(-1.95, 0.83), Vector2(-1.08, 0.94), Vector2(1.55, 1.00),
		Vector2(2.0, 1.02), Vector2(2.0, ROCKER_Y),
	])
	sides.append_array(ModelBuilder.arch_points(REAR_AXLE, ARCH_RADIUS, ROCKER_Y))
	sides.append_array(ModelBuilder.arch_points(FRONT_AXLE, ARCH_RADIUS, ROCKER_Y))
	sides.append(Vector2(-1.95, ROCKER_Y))
	m.extrude("paint", sides, _body_half_width)

	# Tail: short deck with a lip spoiler, then the bumper.
	m.extrude("paint", PackedVector2Array([
		Vector2(2.0, 1.02), Vector2(2.32, 1.025), Vector2(2.44, 1.035), Vector2(TAIL_Z, 0.96),
		Vector2(TAIL_Z, 0.60), Vector2(2.44, 0.36), Vector2(2.34, ROCKER_Y), Vector2(2.0, ROCKER_Y),
	]), _body_half_width)

	# Fastback greenhouse, painted; the glass is laid over it so the pillars stay body color.
	m.extrude("paint", PackedVector2Array([
		Vector2(-1.08, 0.94), Vector2(-0.28, 1.42), Vector2(0.18, 1.44),
		Vector2(0.78, 1.43), Vector2(1.64, 1.00),
	]), _cabin_half_width)
	_add_glass(m)

	# Black wheel-well liners, backed by inner walls so you can't see through the car.
	for axle in [FRONT_AXLE, REAR_AXLE]:
		m.extrude("trim", ModelBuilder.arch_profile(axle, ARCH_RADIUS - 0.02, ARCH_RADIUS, ROCKER_Y), HALF_WIDTH - 0.04)
		for sx in [-1.0, 1.0]:
			m.extrude("trim", ModelBuilder.arch_points(axle, ARCH_RADIUS, ROCKER_Y), 0.02, sx * (TRACK_HALF - 0.15))
	m.box("trim", Vector3(0, 0.31, 0.0), Vector3(1.5, 0.1, 4.6))
	for sx in [-1.0, 1.0]:
		m.box("trim", Vector3(sx * 0.895, 0.30, 0.0), Vector3(0.06, 0.07, 2.0))

	# Front: wide dark grille with a chrome bar, lower intake, slim swept headlights, DRLs.
	m.extrude("grille", PackedVector2Array([
		Vector2(-2.44, 0.44), Vector2(-2.465, 0.56), Vector2(-2.44, 0.67), Vector2(-2.40, 0.67), Vector2(-2.40, 0.44),
	]), 0.46)
	m.box("chrome", Vector3(0, 0.66, -2.445), Vector3(0.94, 0.03, 0.03))
	m.box("chrome", Vector3(0, 0.56, -2.47), Vector3(0.16, 0.08, 0.02))
	m.box("grille", Vector3(0, 0.35, -2.40), Vector3(1.1, 0.10, 0.06))
	for sx in [-1.0, 1.0]:
		m.extrude("headlight", PackedVector2Array([
			Vector2(-2.445, 0.64), Vector2(-2.43, 0.705), Vector2(-2.30, 0.782),
			Vector2(-2.10, 0.812), Vector2(-2.14, 0.795), Vector2(-2.32, 0.745), Vector2(-2.445, 0.625),
		]), 0.15, sx * 0.63)
		m.box("drl", Vector3(sx * 0.62, 0.635, -2.44), Vector3(0.32, 0.015, 0.02))
		m.box("grille", Vector3(sx * 0.66, 0.40, -2.39), Vector3(0.22, 0.12, 0.06))

	# Rear: wraparound taillights joined by a thin light bar, plate, black diffuser.
	for sx in [-1.0, 1.0]:
		m.extrude("taillight", PackedVector2Array([
			Vector2(2.26, 0.95), Vector2(2.40, 1.02), Vector2(2.49, 0.96),
			Vector2(2.49, 0.86), Vector2(2.40, 0.86),
		]), 0.15, sx * 0.72)
	m.box("taillight", Vector3(0, 0.955, 2.485), Vector3(1.1, 0.02, 0.02))
	m.box("plate", Vector3(0, 0.74, 2.488), Vector3(0.31, 0.155, 0.01))
	m.box("trim", Vector3(0, 0.38, 2.42), Vector3(1.5, 0.12, 0.12))
	for sx in [-1.0, 1.0]:
		m.tube("chrome", Vector3(sx * 0.5, 0.36, 2.38), Vector3(sx * 0.5, 0.36, 2.49), 0.04, 10)

	# Sides: door cut lines, handles, mirrors, a shark-fin antenna.
	for sx in [-1.0, 1.0]:
		var x: float = sx * (HALF_WIDTH + 0.002)
		for z in [-1.02, 0.16, 1.12]:
			m.box("trim", Vector3(x, 0.63, z), Vector3(0.004, 0.66, 0.012))
		m.box("trim", Vector3(x, 0.94, 0.05), Vector3(0.004, 0.012, 2.0))
		for z in [-0.35, 0.72]:
			m.box("chrome", Vector3(sx * (HALF_WIDTH + 0.01), 0.86, z), Vector3(0.02, 0.035, 0.17))
		m.box("paint", Vector3(sx * 0.98, 1.05, -0.86), Vector3(0.16, 0.12, 0.2))
		m.box("trim", Vector3(sx * 0.90, 1.00, -0.86), Vector3(0.08, 0.04, 0.1))
	m.extrude("trim", PackedVector2Array([
		Vector2(0.55, 1.435), Vector2(0.66, 1.49), Vector2(0.72, 1.49), Vector2(0.74, 1.43),
	]), 0.035)
	return m.build()


static func _add_glass(m: ModelBuilder) -> void:
	var yb := 0.98
	var yt := 1.39
	var n := Vector3(0, 0.80, -0.48).normalized()
	var ws := [
		Vector3(-(_cabin_half_width(yb) - 0.07), yb, _windshield_z(yb)),
		Vector3(_cabin_half_width(yb) - 0.07, yb, _windshield_z(yb)),
		Vector3(_cabin_half_width(yt) - 0.07, yt, _windshield_z(yt)),
		Vector3(-(_cabin_half_width(yt) - 0.07), yt, _windshield_z(yt)),
	]
	m.quad("glass", ws[0] + n * 0.008, ws[1] + n * 0.008, ws[2] + n * 0.008, ws[3] + n * 0.008, n)

	yb = 1.04
	yt = 1.40
	n = Vector3(0, 0.86, 0.43).normalized()
	var rg := [
		Vector3(-(_cabin_half_width(yb) - 0.09), yb, _rear_glass_z(yb)),
		Vector3(_cabin_half_width(yb) - 0.09, yb, _rear_glass_z(yb)),
		Vector3(_cabin_half_width(yt) - 0.09, yt, _rear_glass_z(yt)),
		Vector3(-(_cabin_half_width(yt) - 0.09), yt, _rear_glass_z(yt)),
	]
	m.quad("glass", rg[0] + n * 0.008, rg[1] + n * 0.008, rg[2] + n * 0.008, rg[3] + n * 0.008, n)

	# Side glass: front door, blacked-out B-pillar, rear door, and a small quarter window.
	var windows := [
		PackedVector2Array([Vector2(-0.93, 1.00), Vector2(-0.33, 1.37), Vector2(0.12, 1.385), Vector2(0.12, 1.00)]),
		PackedVector2Array([Vector2(0.12, 1.00), Vector2(0.12, 1.385), Vector2(0.21, 1.385), Vector2(0.21, 1.00)]),
		PackedVector2Array([
			Vector2(0.21, 1.00), Vector2(0.21, 1.385), Vector2(0.80, 1.37), Vector2(1.08, 1.19), Vector2(1.08, 1.00),
		]),
		PackedVector2Array([Vector2(1.14, 1.01), Vector2(1.14, 1.15), Vector2(1.44, 1.01)]),
	]
	for w_idx in windows.size():
		var poly: PackedVector2Array = windows[w_idx]
		var mat := "trim" if w_idx == 1 else "glass"
		var tris := Geometry2D.triangulate_polygon(poly)
		for sx in [-1.0, 1.0]:
			for t in range(0, tris.size(), 3):
				var pts: Array[Vector3] = []
				for k in 3:
					var p := poly[tris[t + k]]
					pts.append(Vector3(sx * (_cabin_half_width(p.y) + 0.006), p.y, p.x))
				m.face(mat, pts[0], pts[1], pts[2], Vector3(sx, 0, 0))
	# Chrome strip along the top of the side glass.
	for sx in [-1.0, 1.0]:
		m.box("chrome", Vector3(sx * (_cabin_half_width(0.985) + 0.004), 0.985, 0.25), Vector3(0.01, 0.018, 2.2))


static func _wheel_mesh() -> ArrayMesh:
	# Built with the outer face toward +X; left-side wheels get flipped.
	var m := ModelBuilder.new()
	m.add_material("tire", Color(0.07, 0.07, 0.07), 0.95)
	m.add_material("sidewall", Color(0.11, 0.11, 0.11), 0.9)
	m.add_material("barrel", Color(0.18, 0.18, 0.19), 0.5, 0.6)
	m.add_material("rim", Color(0.78, 0.79, 0.81), 0.3, 0.6)
	m.cylinder_x("tire", Vector3.ZERO, TIRE_RADIUS, 0.235, 24)
	m.cylinder_x("sidewall", Vector3(0.004, 0, 0), 0.27, 0.24, 20)
	m.cylinder_x("barrel", Vector3(0.0, 0, 0), 0.228, 0.242, 20)
	m.cylinder_x("rim", Vector3(0.117, 0, 0), 0.228, 0.012, 20)
	m.cylinder_x("barrel", Vector3(0.118, 0, 0), 0.205, 0.012, 20)
	m.cylinder_x("rim", Vector3(0.12, 0, 0), 0.06, 0.02, 10)
	# Five split spokes.
	for i in 5:
		var a := TAU * i / 5.0
		for off in [-0.13, 0.13]:
			var dir := Vector2(cos(a + off), sin(a + off))
			var perp := dir.orthogonal() * 0.016
			m.extrude("rim", PackedVector2Array([
				dir * 0.05 - perp, dir * 0.21 - perp * 1.6, dir * 0.21 + perp * 1.6, dir * 0.05 + perp,
			]), 0.009, 0.121)
	return m.build()


static func _add_badges(body: Node3D) -> void:
	var plate := Label3D.new()
	plate.text = "JOYRIDE"
	plate.font_size = 26
	plate.pixel_size = 0.0028
	plate.modulate = Color(0.1, 0.15, 0.35)
	plate.outline_size = 0
	plate.double_sided = false
	plate.shaded = true
	plate.position = Vector3(0, 0.735, 2.494)
	body.add_child(plate)
