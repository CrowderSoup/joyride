class_name PlaneModel
extends RefCounted
## Cessna 172-style high-wing four-seater - low-poly.
## Rough real dimensions: 8.3 m long, 11 m span, 2.7 m tall, tricycle gear with wheel pants.
## Faces -Z; origin on the ground between the main wheels, so rotating for takeoff pivots
## on the mains like the real thing.

const PAINT := Color(0.95, 0.95, 0.93)
const STRIPE := Color(0.72, 0.09, 0.1)  # change these two for another livery
const STRIPE_2 := Color(0.1, 0.15, 0.35)
const WING_Y := 2.2  # leading edge height at the root
const WING_LE := -1.76
const SPAN_HALF := 5.5
const PROP_CENTER := Vector3(0, 1.38, -4.02)


## Builds the model under visual and returns the propeller node (it spins about Z).
static func build(visual: Node3D) -> Node3D:
	var body := MeshInstance3D.new()
	body.mesh = _airframe_mesh()
	visual.add_child(body)
	_add_registration(visual)

	var prop := Node3D.new()
	prop.position = PROP_CENTER
	visual.add_child(prop)
	var prop_mesh := MeshInstance3D.new()
	prop_mesh.mesh = _prop_mesh()
	prop.add_child(prop_mesh)
	return prop


static func _materials(m: ModelBuilder) -> void:
	m.add_material("paint", PAINT, 0.3, 0.1)
	m.add_material("stripe", STRIPE, 0.3, 0.1)
	m.add_material("stripe2", STRIPE_2, 0.3, 0.1)
	m.add_material("glass", Color(0.08, 0.11, 0.14), 0.05, 0.5)
	m.add_material("trim", Color(0.06, 0.06, 0.07), 0.7)
	m.add_material("metal", Color(0.7, 0.71, 0.73), 0.3, 0.8)
	m.add_material("tire", Color(0.07, 0.07, 0.07), 0.95)
	m.add_material("red_light", Color(0.9, 0.05, 0.05), 0.2, 0.0, 1.5)
	m.add_material("green_light", Color(0.05, 0.9, 0.2), 0.2, 0.0, 1.5)
	m.add_material("white_light", Color(1, 1, 0.95), 0.1, 0.0, 1.0)


## Fuselage stations: [z, half_width, bottom, top, corner radius].
const STATIONS := [
	[-3.93, 0.20, 1.18, 1.58, 0.2],    # cowl nose, around the spinner
	[-3.80, 0.40, 1.02, 1.70, 0.3],
	[-3.45, 0.52, 0.92, 1.78, 0.3],
	[-2.45, 0.57, 0.84, 1.83, 0.26],   # firewall / base of the windshield
	[-1.70, 0.585, 0.78, 2.14, 0.22],  # top of the windshield, under the wing
	[-1.60, 0.585, 0.78, 2.14, 0.22],
	[-0.20, 0.585, 0.78, 2.14, 0.22],
	[0.60, 0.54, 0.86, 2.10, 0.2],     # end of the cabin
	[1.40, 0.40, 1.00, 1.94, 0.16],
	[2.40, 0.27, 1.16, 1.80, 0.12],
	[3.40, 0.16, 1.30, 1.70, 0.08],
	[4.30, 0.06, 1.42, 1.64, 0.04],
]


static func _airframe_mesh() -> ArrayMesh:
	var m := ModelBuilder.new()
	_materials(m)

	var rings := []
	for s in STATIONS:
		rings.append(ModelBuilder.rounded_section(s[0], s[1], s[2], s[3], s[4], 8, 4))
	m.loft(_fuselage_paint, rings)
	_add_stripes(m)

	_add_wing(m)
	_add_tail(m)
	_add_gear(m)

	# Belly antenna, rooftop antenna, exhaust stack, beacon on the fin, landing light.
	m.tube("trim", Vector3(0, 2.14, 0.3), Vector3(0, 2.42, 0.45), 0.012, 6)
	m.tube("trim", Vector3(0, 0.84, 1.0), Vector3(0, 0.62, 1.12), 0.01, 6)
	m.tube("metal", Vector3(0.28, 0.98, -2.7), Vector3(0.3, 0.9, -2.55), 0.035, 8)
	m.box("red_light", Vector3(0, 2.83, 4.05), Vector3(0.05, 0.06, 0.1))
	m.box("white_light", Vector3(-2.2, WING_Y - 0.02, WING_LE - 0.005), Vector3(0.22, 0.06, 0.02))
	return m.build()


## Paints the fuselage skin by region: windows, the cheat line stripes, the cowl inlets.
static func _fuselage_paint(p: Vector3) -> String:
	var side := absf(p.x) > 0.44
	if p.z < -3.9:
		return "trim"
	if p.z > -2.45 and p.z < -1.7 and p.y > 1.78:
		return "glass"  # windshield, wrapping around the corners
	var in_door := (p.z > -1.6 and p.z < -0.3) or (p.z > -0.18 and p.z < 0.52)
	if side and in_door and p.y > 1.64 and p.y < 2.1:
		return "glass"
	if side and p.z > 0.66 and p.z < 1.35 and p.y > 1.66 and p.y < 1.98:
		return "glass"  # rear side windows
	return "paint"


## Cheat-line stripes laid just off the flat fuselage sides, following the line of the
## fuselage up toward the tail instead of stair-stepping across the loft's rows.
static func _add_stripes(m: ModelBuilder) -> void:
	for i in range(1, STATIONS.size() - 1):
		var a: Array = STATIONS[i]
		var b: Array = STATIONS[i + 1]
		for band in [["stripe", 0.0, 0.1], ["stripe2", -0.085, -0.045]]:
			var za: float = a[0]
			var zb: float = b[0]
			if za > 3.9:
				continue
			var pts: Array[Vector3] = []
			for c in [[za, a[1]], [zb, b[1]]]:
				var y: float = _stripe_y(c[0])
				pts.append(Vector3(c[1] + 0.004, y + band[1], c[0]))
				pts.append(Vector3(c[1] + 0.004, y + band[2], c[0]))
			for sx in [-1.0, 1.0]:
				var q: Array[Vector3] = []
				for pt in pts:
					q.append(Vector3(sx * pt.x, pt.y, pt.z))
				m.quad(band[0], q[0], q[1], q[3], q[2], Vector3(sx, 0, 0))


## Height of the stripe's bottom edge at z: level along the cowl and cabin, then rising
## with the tail cone so it stays on the flat of the side.
static func _stripe_y(z: float) -> float:
	return 1.2 + 0.26 * smoothstep(0.6, 3.4, z)


static func _add_wing(m: ModelBuilder) -> void:
	# Constant chord inboard, tapering outboard, a couple degrees of dihedral.
	var rings := []
	for x in [-SPAN_HALF, -SPAN_HALF + 0.35, -2.5, 2.5, SPAN_HALF - 0.35, SPAN_HALF]:
		var out := absf(x)
		var t := clampf((out - 2.5) / (SPAN_HALF - 2.5), 0.0, 1.0)
		var chord := lerpf(1.63, 1.12, t)
		var le := Vector3(x, WING_Y + out * 0.03, WING_LE + t * 0.1)
		rings.append(ModelBuilder.airfoil(le, Vector3.BACK, Vector3.UP, chord, 0.13, 0.3, 10))
	m.loft(func(p: Vector3) -> String: return "stripe" if absf(p.x) > SPAN_HALF - 0.36 else "paint", rings)
	# Nav lights: red on the left tip, green on the right.
	m.box("red_light", Vector3(-SPAN_HALF - 0.02, WING_Y + 0.17, WING_LE + 0.2), Vector3(0.04, 0.05, 0.12))
	m.box("green_light", Vector3(SPAN_HALF + 0.02, WING_Y + 0.17, WING_LE + 0.2), Vector3(0.04, 0.05, 0.12))
	# Flap and aileron hinge lines.
	for sx in [-1.0, 1.0]:
		m.box("trim", Vector3(sx * 1.55, WING_Y + 0.03, -0.45), Vector3(1.9, 0.006, 0.012))
		m.box("trim", Vector3(sx * 4.0, WING_Y + 0.12, -0.8), Vector3(2.4, 0.006, 0.012))
	# Lift struts from the lower fuselage out to the wing.
	for sx in [-1.0, 1.0]:
		m.loft("paint", [
			ModelBuilder.circle(Vector3(sx * 0.5, 1.0, -1.05), Vector3(sx * 2.1, 1.12, -0.1).normalized(), 0.045, 8),
			ModelBuilder.circle(Vector3(sx * 2.6, WING_Y + 0.02, -1.15), Vector3(sx * 2.1, 1.12, -0.1).normalized(), 0.04, 8),
		], true)


static func _add_tail(m: ModelBuilder) -> void:
	# Horizontal stabilizer and elevator.
	var rings := []
	for x in [-1.75, 0.0, 1.75]:
		var t: float = absf(x) / 1.75
		rings.append(ModelBuilder.airfoil(Vector3(x, 1.5, 3.35 + t * 0.3), Vector3.BACK, Vector3.UP, lerpf(1.1, 0.72, t), 0.1, 0.0))
	m.loft("paint", rings)
	m.box("trim", Vector3(0, 1.525, 4.02), Vector3(3.2, 0.006, 0.012))

	# Swept fin and rudder, striped at the top, with a dorsal fillet running forward.
	rings = []
	for y in [1.6, 2.2, 2.42, 2.5, 2.8]:
		var t: float = (y - 1.6) / 1.2
		rings.append(ModelBuilder.airfoil(Vector3(0, y, lerpf(2.85, 3.78, t)), Vector3.BACK, Vector3.RIGHT, lerpf(1.52, 0.62, t), 0.1, 0.0))
	m.loft(func(p: Vector3) -> String: return "stripe" if p.y > 2.5 else ("stripe2" if p.y > 2.42 else "paint"), rings)
	m.extrude("paint", PackedVector2Array([
		Vector2(1.7, 1.93), Vector2(3.3, 1.72), Vector2(3.3, 2.1),
	]), 0.03)
	m.box("trim", Vector3(0, 2.2, 3.9), Vector3(0.006, 1.2, 0.012))


static func _add_gear(m: ModelBuilder) -> void:
	# Spring-steel mains out to faired wheels, and the nose strut.
	for sx in [-1.0, 1.0]:
		var axle := Vector3(sx * 1.25, 0.22, 0.05)
		m.tube("paint", Vector3(sx * 0.4, 0.86, 0.0), axle + Vector3(-sx * 0.1, 0.12, 0), 0.04, 8)
		_wheel(m, axle, 0.22, 0.14)
		_wheel_pant(m, axle, 0.22)
	var nose_axle := Vector3(0, 0.19, -3.05)
	m.tube("metal", Vector3(0, 0.95, -3.0), nose_axle + Vector3(0, 0.25, 0), 0.04, 8)
	m.tube("trim", nose_axle + Vector3(0, 0.3, 0), nose_axle + Vector3(0, 0.05, 0), 0.03, 8)
	_wheel(m, nose_axle, 0.19, 0.12)
	_wheel_pant(m, nose_axle, 0.19)


static func _wheel(m: ModelBuilder, axle: Vector3, radius: float, width: float) -> void:
	var hw := width * 0.5
	m.lathe("tire", PackedVector2Array([
		Vector2(-hw * 0.8, 0.07), Vector2(-hw, radius * 0.7), Vector2(-hw * 0.7, radius), Vector2(hw * 0.7, radius),
		Vector2(hw, radius * 0.7), Vector2(hw * 0.8, 0.07),
	]), axle, 16)


## Teardrop speed fairing around a wheel, open at the bottom so the tire shows.
static func _wheel_pant(m: ModelBuilder, axle: Vector3, radius: float) -> void:
	var rows := [
		[-radius * 2.0, 0.02, 0.9, 1.1], [-radius * 1.4, 0.09, 0.35, 1.65], [-radius * 0.4, 0.12, 0.25, 2.05],
		[radius * 0.9, 0.11, 0.35, 1.9], [radius * 2.4, 0.03, 0.85, 1.35],
	]
	var rings := []
	for r in rows:
		var z: float = axle.z + r[0]
		var bottom: float = axle.y - radius + radius * r[2]
		var top: float = axle.y - radius + radius * r[3]
		var ring := ModelBuilder.rounded_section(z, r[1], bottom, top, 1.0, 2, 4)
		for i in ring.size():
			ring[i].x += axle.x
		rings.append(ring)
	m.loft("paint", rings, true)


static func _prop_mesh() -> ArrayMesh:
	var m := ModelBuilder.new()
	m.add_material("spinner", PAINT, 0.3, 0.1)
	m.add_material("blade", Color(0.12, 0.12, 0.13), 0.5, 0.4)
	m.add_material("tip", Color(0.95, 0.8, 0.1), 0.4)

	# Spinner, in the prop's frame (spins about Z, nose toward -Z).
	var spinner := []
	for p in [[-0.36, 0.0], [-0.3, 0.07], [-0.18, 0.14], [-0.02, 0.19], [0.1, 0.2]]:
		spinner.append(ModelBuilder.circle(Vector3(0, 0, p[0]), Vector3.BACK, maxf(p[1], 0.005), 14))
	m.loft("spinner", spinner, true)

	# Two blades, twisted flatter toward the tips, with painted tips.
	for sx in [-1.0, 1.0]:
		var rings := []
		for r in [0.12, 0.35, 0.7, 0.86, 0.95]:
			var pitch: float = lerpf(0.9, 0.3, r)
			var chord: float = 0.14 if r < 0.9 else 0.09
			var dir := Vector3(0, cos(pitch), -sin(pitch))
			var le := Vector3(sx * r, 0, -0.05) - dir * chord * 0.5
			rings.append(ModelBuilder.airfoil(le, dir, dir.cross(Vector3.RIGHT).normalized(), chord, 0.14, 0.2, 4))
		m.loft(func(p: Vector3) -> String: return "tip" if absf(p.x) > 0.86 else "blade", rings)
	return m.build()


static func _add_registration(visual: Node3D) -> void:
	for sx in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "N172JR"
		label.font_size = 72
		label.pixel_size = 0.0035
		label.modulate = STRIPE_2
		label.outline_size = 0
		label.double_sided = false
		label.shaded = true
		# Tail cone tapers about 7 degrees in plan, so angle the letters to lie on it.
		label.position = Vector3(sx * 0.33, 1.52, 2.1)
		label.rotation.y = sx * (PI / 2 - 0.13)
		visual.add_child(label)
