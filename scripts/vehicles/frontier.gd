class_name Frontier
extends RefCounted
## 2008 Nissan Frontier NISMO crew cab, short bed, 4x4 - low-poly.
## Rough real dimensions: 5.22 m long, 1.85 m wide, 1.87 m tall, 3.20 m wheelbase,
## 265/75R16 tires (~0.78 m tall). Faces -Z; origin on the ground, mid-truck.

const PAINT := Color(0.62, 0.05, 0.06)  # red; change this one line for another color
const FRONT_AXLE := Vector2(-1.70, 0.40)  # (z, y)
const REAR_AXLE := Vector2(1.50, 0.40)
const TIRE_RADIUS := 0.39
const TRACK_HALF := 0.79
const ROCKER_Y := 0.55


static func make() -> GroundVehicle:
	var v := GroundVehicle.new()
	v.display_name = "Frontier NISMO"
	v.top_speed = 42.0
	v.acceleration = 12.0
	v.steer_rate = 1.8
	v.grip = 8.0
	v.lean_amount = 0.06
	v.pitch_amount = 0.004
	v.camera_distance = 10.5
	v.camera_height = 3.8
	v.enter_radius = 3.6
	v.exit_offset = Vector3(-1.6, 0, -0.4)
	Parts.collision_box(v, Vector3(1.85, 1.6, 5.3), Vector3(0, 0.8, 0))

	v.body = Node3D.new()
	v.visual.add_child(v.body)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _body_mesh()
	v.body.add_child(mesh_inst)
	_add_decals(v.body)

	var wheel := _wheel_mesh()
	for z in [FRONT_AXLE.x, REAR_AXLE.x]:
		for sx in [-1.0, 1.0]:
			v.add_wheel(wheel, Vector3(sx * TRACK_HALF, TIRE_RADIUS, z), TIRE_RADIUS, z == FRONT_AXLE.x)
	return v


static func _cabin_half_width(y: float) -> float:
	return lerpf(0.885, 0.76, clampf((y - 1.26) / 0.62, 0.0, 1.0))


## z along the windshield / rear glass lines, for a given height.
static func _windshield_z(y: float) -> float:
	return -1.25 + (y - 1.26) * (0.70 / 0.60)


static func _rear_glass_z(y: float) -> float:
	return 0.95 - (y - 1.30) * (0.09 / 0.58)


static func _body_mesh() -> ArrayMesh:
	var m := ModelBuilder.new()
	m.add_material("paint", PAINT, 0.28, 0.25)
	m.add_material("trim", Color(0.06, 0.06, 0.07), 0.8)
	m.add_material("bedliner", Color(0.09, 0.09, 0.09), 1.0)
	m.add_material("glass", Color(0.06, 0.08, 0.11), 0.05, 0.4)
	m.add_material("metal", Color(0.72, 0.73, 0.75), 0.3, 0.8)
	m.add_material("grille", Color(0.03, 0.03, 0.035), 0.6)
	m.add_material("headlight", Color(0.92, 0.94, 0.96), 0.1, 0.2, 0.3)
	m.add_material("taillight", Color(0.75, 0.05, 0.04), 0.2, 0.0, 0.4)
	m.add_material("plate", Color(0.95, 0.95, 0.92), 0.5)

	# Hood, fenders, doors - one side profile with the front wheel arch cut out.
	var lower := PackedVector2Array([
		Vector2(-2.52, 0.60), Vector2(-2.57, 1.00), Vector2(-2.44, 1.13),
		Vector2(-1.55, 1.22), Vector2(-1.25, 1.26), Vector2(0.95, 1.30), Vector2(0.95, ROCKER_Y),
	])
	lower.append_array(ModelBuilder.arch_points(FRONT_AXLE, 0.47, ROCKER_Y))
	m.extrude("paint", lower, 0.925)

	# Power-bulge hood, the Frontier's big tell from the driver's seat.
	m.extrude("paint", PackedVector2Array([
		Vector2(-2.36, 1.10), Vector2(-2.28, 1.175), Vector2(-1.40, 1.28), Vector2(-1.28, 1.25), Vector2(-1.28, 1.10),
	]), 0.42)

	# Crew cab greenhouse, painted; glass is laid over it so pillars stay body color.
	m.extrude("paint", PackedVector2Array([
		Vector2(-1.25, 1.26), Vector2(-0.55, 1.86), Vector2(0.86, 1.88), Vector2(0.95, 1.30),
	]), _cabin_half_width)
	_add_glass(m)

	# Bed sides with the rear arch, plus floor, bulkhead, tailgate, rail caps.
	var bed_side := PackedVector2Array([
		Vector2(0.98, 0.58), Vector2(0.98, 1.33), Vector2(2.62, 1.33), Vector2(2.62, 0.60),
	])
	bed_side.append_array(ModelBuilder.arch_points(REAR_AXLE, 0.47, ROCKER_Y))
	for sx in [-1.0, 1.0]:
		m.extrude("paint", bed_side, 0.05, sx * 0.875)
		m.box("trim", Vector3(sx * 0.875, 1.345, 1.80), Vector3(0.12, 0.03, 1.66))
	m.box("bedliner", Vector3(0, 0.75, 1.80), Vector3(1.66, 0.05, 1.60))
	m.box("bedliner", Vector3(0, 1.03, 1.02), Vector3(1.66, 0.6, 0.05))
	m.box("paint", Vector3(0, 0.97, 2.59), Vector3(1.75, 0.72, 0.06))
	m.box("trim", Vector3(0, 1.20, 2.625), Vector3(0.22, 0.06, 0.02))

	# Boxy NISMO fender flares, and black liners so the wheel wells aren't painted inside.
	for axle in [FRONT_AXLE, REAR_AXLE]:
		m.extrude("trim", ModelBuilder.arch_profile(axle, 0.44, 0.465, ROCKER_Y), 0.9)
		for sx in [-1.0, 1.0]:
			m.extrude("trim", ModelBuilder.arch_profile(axle, 0.47, 0.56, ROCKER_Y), 0.035, sx * 0.945)

	# Front end: grille, headlights, bumper, fogs, skid plate.
	m.box("grille", Vector3(0, 0.87, -2.565), Vector3(1.05, 0.30, 0.04))
	for y in [0.79, 0.87, 0.95]:
		m.box("metal", Vector3(0, y, -2.59), Vector3(1.0, 0.045, 0.03))
	m.box("metal", Vector3(0, 0.87, -2.61), Vector3(0.2, 0.09, 0.02))
	for sx in [-1.0, 1.0]:
		m.extrude("headlight", PackedVector2Array([
			Vector2(-2.585, 0.92), Vector2(-2.585, 1.04), Vector2(-2.44, 1.16),
			Vector2(-2.26, 1.165), Vector2(-2.40, 0.96),
		]), 0.17, sx * 0.72)
		m.box("headlight", Vector3(sx * 0.62, 0.55, -2.69), Vector3(0.18, 0.1, 0.03))
	m.extrude("trim", PackedVector2Array([
		Vector2(-2.45, 0.40), Vector2(-2.68, 0.45), Vector2(-2.70, 0.72),
		Vector2(-2.58, 0.78), Vector2(-2.45, 0.78),
	]), 0.93)
	m.extrude("metal", PackedVector2Array([
		Vector2(-2.62, 0.40), Vector2(-2.30, 0.28), Vector2(-1.80, 0.28),
		Vector2(-1.80, 0.32), Vector2(-2.30, 0.34), Vector2(-2.58, 0.45),
	]), 0.55)

	# Rear: bumper, plate, tall taillights.
	m.box("trim", Vector3(0, 0.53, 2.72), Vector3(1.80, 0.22, 0.26))
	m.box("plate", Vector3(0, 0.53, 2.855), Vector3(0.31, 0.155, 0.01))
	for sx in [-1.0, 1.0]:
		m.box("taillight", Vector3(sx * 0.875, 1.08, 2.625), Vector3(0.10, 0.38, 0.05))

	# Sides: mirrors, door handles, tube steps. Chassis fills the gap under the body.
	for sx in [-1.0, 1.0]:
		m.box("trim", Vector3(sx * 1.02, 1.40, -1.05), Vector3(0.12, 0.2, 0.24))
		m.box("trim", Vector3(sx * 0.94, 1.36, -1.05), Vector3(0.12, 0.04, 0.08))
		for z in [-0.45, 0.55]:
			m.box("trim", Vector3(sx * 0.91, 1.17, z), Vector3(0.02, 0.04, 0.16))
		m.box("trim", Vector3(sx * 0.97, 0.43, -0.15), Vector3(0.07, 0.07, 1.9))
		for z in [-0.9, 0.6]:
			m.box("trim", Vector3(sx * 0.935, 0.49, z), Vector3(0.1, 0.12, 0.06))
	m.box("trim", Vector3(0, 0.45, 0.0), Vector3(1.2, 0.2, 4.6))
	return m.build()


static func _add_glass(m: ModelBuilder) -> void:
	# Windshield, inset from the pillars and nudged just off the painted surface.
	var yb := 1.31
	var yt := 1.81
	var n := Vector3(0, 0.70, -0.60).normalized()
	var ws := [
		Vector3(-(_cabin_half_width(yb) - 0.07), yb, _windshield_z(yb)),
		Vector3(_cabin_half_width(yb) - 0.07, yb, _windshield_z(yb)),
		Vector3(_cabin_half_width(yt) - 0.07, yt, _windshield_z(yt)),
		Vector3(-(_cabin_half_width(yt) - 0.07), yt, _windshield_z(yt)),
	]
	m.quad("glass", ws[0] + n * 0.008, ws[1] + n * 0.008, ws[2] + n * 0.008, ws[3] + n * 0.008, n)

	yb = 1.37
	yt = 1.80
	n = Vector3(0, 0.09, 0.58).normalized()
	var rg := [
		Vector3(-(_cabin_half_width(yb) - 0.12), yb, _rear_glass_z(yb)),
		Vector3(_cabin_half_width(yb) - 0.12, yb, _rear_glass_z(yb)),
		Vector3(_cabin_half_width(yt) - 0.12, yt, _rear_glass_z(yt)),
		Vector3(-(_cabin_half_width(yt) - 0.12), yt, _rear_glass_z(yt)),
	]
	m.quad("glass", rg[0] + n * 0.008, rg[1] + n * 0.008, rg[2] + n * 0.008, rg[3] + n * 0.008, n)

	# Side glass. The rear door window's kicked-up bottom edge is the Frontier's signature line.
	var windows := [
		PackedVector2Array([Vector2(-1.04, 1.34), Vector2(-0.52, 1.78), Vector2(0.02, 1.78), Vector2(0.02, 1.34)]),
		PackedVector2Array([Vector2(0.02, 1.34), Vector2(0.02, 1.78), Vector2(0.12, 1.78), Vector2(0.12, 1.34)]),
		PackedVector2Array([
			Vector2(0.12, 1.34), Vector2(0.55, 1.34), Vector2(0.68, 1.46),
			Vector2(0.80, 1.46), Vector2(0.80, 1.78), Vector2(0.12, 1.78),
		]),
	]
	for w_idx in windows.size():
		var poly: PackedVector2Array = windows[w_idx]
		var mat := "trim" if w_idx == 1 else "glass"  # blacked-out B-pillar
		var tris := Geometry2D.triangulate_polygon(poly)
		for sx in [-1.0, 1.0]:
			for t in range(0, tris.size(), 3):
				var pts: Array[Vector3] = []
				for k in 3:
					var p := poly[tris[t + k]]
					pts.append(Vector3(sx * (_cabin_half_width(p.y) + 0.006), p.y, p.x))
				m.face(mat, pts[0], pts[1], pts[2], Vector3(sx, 0, 0))


static func _wheel_mesh() -> ArrayMesh:
	# Built with the outer face toward +X; left-side wheels get flipped.
	var m := ModelBuilder.new()
	m.add_material("tire", Color(0.07, 0.07, 0.07), 0.95)
	m.add_material("sidewall", Color(0.12, 0.12, 0.12), 0.9)
	m.add_material("rim", Color(0.3, 0.31, 0.33), 0.35, 0.7)
	m.add_material("hub", Color(0.55, 0.56, 0.58), 0.3, 0.8)
	m.cylinder_x("tire", Vector3.ZERO, TIRE_RADIUS, 0.26, 20)
	m.cylinder_x("sidewall", Vector3(0.005, 0, 0), 0.30, 0.265, 16)
	m.cylinder_x("rim", Vector3(0.01, 0, 0), 0.21, 0.265, 16)
	m.cylinder_x("hub", Vector3(0.02, 0, 0), 0.06, 0.27, 8)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector2(cos(a), sin(a))
		var perp := dir.orthogonal() * 0.025
		m.extrude("hub", PackedVector2Array([
			dir * 0.06 - perp, dir * 0.20 - perp, dir * 0.20 + perp, dir * 0.06 + perp,
		]), 0.01, 0.137)
	return m.build()


static func _add_decals(body: Node3D) -> void:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.2
	font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.25, 1), Vector2.ZERO)  # italic

	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.05, 0.05)
	for sx in [-1.0, 1.0]:
		var label := _label(font, "NISMO", 96, Color(0.05, 0.05, 0.05), Color(0.9, 0.9, 0.9))
		label.position = Vector3(sx * 0.931, 1.1, 1.78)
		label.rotation.y = sx * PI / 2
		body.add_child(label)
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.004, 0.035, 1.6)
		stripe_mesh.material = red
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(sx * 0.927, 1.24, 1.80)
		body.add_child(stripe)

	var tailgate := _label(font, "FRONTIER", 48, Color(0.3, 0.3, 0.32), Color(0.1, 0.1, 0.1))
	tailgate.position = Vector3(0, 1.0, 2.623)
	body.add_child(tailgate)
	var badge := _label(font, "NISMO", 32, Color(0.85, 0.05, 0.05), Color(0.95, 0.95, 0.95))
	badge.position = Vector3(0.55, 0.78, 2.623)
	body.add_child(badge)
	var plate := _label(ThemeDB.fallback_font, "DRIVE", 30, Color(0.1, 0.15, 0.35), Color(0, 0, 0, 0))
	plate.position = Vector3(0, 0.525, 2.862)
	body.add_child(plate)


static func _label(font: Font, text: String, size: int, color: Color, outline: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = 0.0028
	label.modulate = color
	label.outline_modulate = outline
	label.outline_size = maxi(4, size / 10)
	label.double_sided = false
	label.shaded = true
	return label
