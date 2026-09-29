class_name Landmarks
extends RefCounted
## Hand-built, stylized nods to downtown SLC: Temple Square (temple + tabernacle), the
## Capitol at the head of State Street, the arena, and the City & County Building on
## Washington Square. Positions come from CityGen's grid; footprints go into the map so
## the minimap draws them and the city builder leaves their blocks alone.

const GRANITE := Color(0.78, 0.78, 0.76)
const SANDSTONE := Color(0.74, 0.56, 0.42)


# Footprints (x/z rects) of the main masses, shared by the builder, the map, and the tree
# keep-outs so parks don't plant a tree through a dome.
static func temple_rect() -> Rect2:
	return Rect2(Vector2(15, -14) - Vector2(28.5, 15), Vector2(57, 30))


static func tabernacle_rect() -> Rect2:
	return Rect2(Vector2(-30, 28) - Vector2(25, 15), Vector2(50, 30))


static func capitol_center() -> Vector2:
	var r := CityGen.capitol_rect()
	return Vector2(r.get_center().x, r.get_center().y - 12.0)


static func capitol_rect() -> Rect2:
	return Rect2(capitol_center() - Vector2(60, 16), Vector2(120, 32))


static func arena_rect() -> Rect2:
	return Rect2(CityGen.block_rect(-2, 1).get_center() - Vector2(50, 42), Vector2(100, 84))


static func civic_rect() -> Rect2:
	return Rect2(CityGen.block_rect(2, 5).get_center() - Vector2(26, 17), Vector2(52, 34))


static func keep_out(zone: String) -> Array:
	match zone:
		"temple": return [temple_rect().grow(8.0), tabernacle_rect().grow(6.0)]
		"capitol": return [capitol_rect().grow(10.0), Rect2(capitol_center() + Vector2(-25, 0), Vector2(50, 80))]
		"civic": return [civic_rect().grow(8.0)]
	return []


static func add_to_map(map: Dictionary) -> void:
	for r in [temple_rect(), tabernacle_rect(), capitol_rect(), arena_rect(), civic_rect()]:
		var pts := []
		for p in CityGen._rect_poly(r):
			pts.append([p.x, p.y])
		map.buildings.append({"pts": pts, "h": 20.0, "custom": true})


## Level the ground under each landmark (the Capitol sits on a real hill). Call before
## anything else is built on the ground.
static func level_ground() -> void:
	Ground.flatten(CityGen.block_rect(0, 0), 25.0)
	Ground.flatten(CityGen.capitol_rect(), 40.0)
	Ground.flatten(CityGen.block_rect(-2, 1), 20.0)
	Ground.flatten(CityGen.block_rect(2, 5), 20.0)


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	for item in [
		[_temple_square(), temple_rect()], [_capitol(), capitol_rect()],
		[_arena(), arena_rect()], [_civic(), civic_rect()],
	]:
		var body: Node3D = item[0]
		var at: Vector2 = item[1].get_center()
		body.position.y = Ground.height(at.x, at.y)
		root.add_child(body)
	return root


# --- Temple Square -------------------------------------------------------

static func _temple_square() -> StaticBody3D:
	var m := ModelBuilder.new()
	m.add_material("granite", GRANITE, 0.8)
	m.add_material("dark", Color(0.12, 0.14, 0.18), 0.3, 0.3)
	m.add_material("gold", Color(1.0, 0.78, 0.3), 0.25, 0.9, 0.6)
	m.add_material("wall", Color(0.7, 0.66, 0.6), 0.9)
	m.add_material("dome", Color(0.72, 0.74, 0.76), 0.6, 0.3)

	# Temple: long granite hall with three spires at each end, the east one tallest.
	var t := temple_rect()
	var c := t.get_center()
	_box(m, "granite", t, 0.0, 22.0)
	_box(m, "granite", t.grow(1.0), 20.5, 23.0)  # cornice
	for side in [-1.0, 1.0]:
		var z_face: float = c.y + side * (t.size.y * 0.5 + 0.05)
		var x := t.position.x + 9.0
		while x < t.end.x - 8.0:
			for y in [6.0, 15.0]:
				m.box("dark", Vector3(x, y, z_face), Vector3(1.4, 6.0, 0.12))
			x += 4.6
	for end in [-1.0, 1.0]:
		var ex: float = c.x + end * (t.size.x * 0.5 - 5.0)
		for zi in [-1, 0, 1]:
			var center: bool = zi == 0
			var half := 4.0 if center else 3.0
			var top := (46.0 if end > 0.0 else 42.0) if center else 36.0
			var base := Vector2(ex, c.y + zi * 9.5)
			_box(m, "granite", Rect2(base - Vector2(half, half), Vector2(half, half) * 2.0), 0.0, top)
			for y in [top - 8.0, top - 16.0]:
				for sz in [-1.0, 1.0]:
					m.box("dark", Vector3(base.x, y, base.y + sz * (half + 0.05)), Vector3(1.2, 4.5, 0.12))
			var spire := 18.0 if center else 11.0
			_pyramid(m, "granite", base, Vector2(half, half), top, spire)
			if center and end > 0.0:
				m.box("gold", Vector3(base.x, top + spire + 1.4, base.y), Vector3(0.7, 2.8, 0.7))

	# Tabernacle: the long low dome on stubby piers.
	var tab := tabernacle_rect()
	var tc := tab.get_center()
	for k in 14:
		var a := TAU * k / 14.0
		var p := tc + Vector2(cos(a) * (tab.size.x * 0.5 - 1.0), sin(a) * (tab.size.y * 0.5 - 1.0))
		m.box("wall", Vector3(p.x, 2.0, p.y), Vector3(2.0, 4.0, 2.0))
	_box(m, "dark", tab.grow(-2.0), 0.0, 3.8)
	_dome(m, "dome", Vector3(tc.x, 3.6, tc.y), Vector3(tab.size.x * 0.5, 13.0, tab.size.y * 0.5))

	# Low wall around the block with a gate in the middle of each side.
	var r := CityGen.block_rect(0, 0).grow(-1.5)
	var gate := 16.0
	for side in 4:
		var horizontal := side % 2 == 0
		var length := r.size.x if horizontal else r.size.y
		for half in [0, 1]:
			var a := 0.0 if half == 0 else length * 0.5 + gate * 0.5
			var b := length * 0.5 - gate * 0.5 if half == 0 else length
			var seg: Rect2
			if horizontal:
				var z := r.position.y if side == 0 else r.end.y
				seg = Rect2(r.position.x + a, z - 0.4, b - a, 0.8)
			else:
				var x := r.end.x if side == 1 else r.position.x
				seg = Rect2(x - 0.4, r.position.y + a, 0.8, b - a)
			_box(m, "wall", seg, 0.0, 3.2)
	return _body("TempleSquare", m)


# --- State Capitol ---------------------------------------------------------

static func _capitol() -> StaticBody3D:
	var m := ModelBuilder.new()
	m.add_material("granite", Color(0.84, 0.83, 0.8), 0.75)
	m.add_material("dome", Color(0.6, 0.66, 0.62), 0.5, 0.4)
	m.add_material("dark", Color(0.15, 0.17, 0.2), 0.3, 0.3)
	m.add_material("steps", Color(0.7, 0.7, 0.68), 0.9)
	var c := capitol_center()
	var body := Rect2(c - Vector2(40, 12), Vector2(80, 24))
	_box(m, "granite", body, 0.0, 20.0)
	for side in [-1.0, 1.0]:
		_box(m, "granite", Rect2(Vector2(c.x + side * 50.0 - 10.0, c.y - 16.0), Vector2(20, 32)), 0.0, 18.0)
	_box(m, "granite", body.grow(1.0), 18.5, 21.0)
	# Rows of tall windows.
	for side in [-1.0, 1.0]:
		var x := c.x - 56.0
		while x <= c.x + 56.0:
			var depth := 16.05 if absf(x - c.x) > 40.0 else 12.05
			m.box("dark", Vector3(x, 9.0, c.y + side * depth), Vector3(1.6, 8.0, 0.12))
			x += 5.0
	# South portico: steps, columns, entablature.
	var front := c.y + 12.0
	_box(m, "steps", Rect2(c.x - 24.0, front, 48.0, 14.0), 0.0, 1.2)
	_box(m, "steps", Rect2(c.x - 22.0, front, 44.0, 9.0), 1.2, 2.4)
	var x := c.x - 18.0
	while x <= c.x + 18.0:
		m.box("granite", Vector3(x, 10.4, front + 6.0), Vector3(1.5, 16.0, 1.5))
		x += 36.0 / 7.0
	_box(m, "granite", Rect2(c.x - 21.0, front, 42.0, 8.0), 18.4, 21.0)
	_box(m, "granite", Rect2(c.x - 14.0, front + 1.0, 28.0, 6.0), 21.0, 23.5)
	# Drum ringed by columns, dome, lantern.
	var dc := Vector3(c.x, 0, c.y)
	_prism(m, "granite", dc + Vector3(0, 20, 0), 13.5, 3.0, 20)
	_prism(m, "dark", dc + Vector3(0, 23, 0), 11.0, 9.0, 20)
	for k in 20:
		var a := TAU * k / 20.0
		m.box("granite", dc + Vector3(cos(a) * 12.5, 27.5, sin(a) * 12.5), Vector3(1.0, 9.0, 1.0))
	_prism(m, "granite", dc + Vector3(0, 32, 0), 13.5, 2.0, 20)
	_dome(m, "dome", dc + Vector3(0, 34, 0), Vector3(12.0, 15.0, 12.0))
	_prism(m, "granite", dc + Vector3(0, 48, 0), 2.6, 5.0, 10)
	_dome(m, "dome", dc + Vector3(0, 53, 0), Vector3(2.8, 3.0, 2.8))
	return _body("Capitol", m)


# --- Arena -----------------------------------------------------------------

static func _arena() -> StaticBody3D:
	var m := ModelBuilder.new()
	m.add_material("shell", Color(0.78, 0.8, 0.82), 0.4, 0.5)
	m.add_material("glass", Color(0.1, 0.16, 0.22), 0.08, 0.5)
	m.add_material("canopy", Color(0.2, 0.22, 0.26), 0.6)
	var r := arena_rect()
	var c := r.get_center()
	# Barrel-roofed box: profile across z, extruded along x.
	var half_z := r.size.y * 0.5
	var profile := PackedVector2Array([Vector2(c.y - half_z, 0)])
	for k in 13:
		var a := PI - PI * k / 12.0
		profile.append(Vector2(c.y + cos(a) * half_z, 20.0 + sin(a) * 12.0))
	profile.append(Vector2(c.y + half_z, 0))
	m.extrude("shell", profile, r.size.x * 0.5, c.x)
	_box(m, "glass", r.grow(0.4), 0.0, 8.0)
	_box(m, "canopy", Rect2(c.x - 20.0, r.end.y, 40.0, 8.0), 7.6, 8.4)
	var body := _body("Arena", m)
	for side in [-1.0, 1.0]:
		var sign := Label3D.new()
		sign.text = "ARENA"
		sign.font_size = 160
		sign.pixel_size = 0.04
		sign.outline_size = 16
		sign.modulate = Color(0.95, 0.75, 0.2)
		sign.outline_modulate = Color(0.1, 0.1, 0.12)
		sign.shaded = true
		sign.double_sided = false
		sign.position = Vector3(c.x, 14.0, c.y + side * (half_z + 0.1))
		sign.rotation.y = 0.0 if side > 0.0 else PI
		body.add_child(sign)
	return body


# --- City & County Building --------------------------------------------------

static func _civic() -> StaticBody3D:
	var m := ModelBuilder.new()
	m.add_material("stone", SANDSTONE, 0.85)
	m.add_material("roof", Color(0.3, 0.26, 0.24), 0.7)
	m.add_material("dark", Color(0.14, 0.15, 0.18), 0.3, 0.3)
	m.add_material("clock", Color(0.95, 0.93, 0.85), 0.4, 0.0, 0.3)
	var r := civic_rect()
	var c := r.get_center()
	_box(m, "stone", r, 0.0, 19.0)
	_pyramid(m, "roof", c, r.size * 0.5, 19.0, 7.0)
	for side in [-1.0, 1.0]:
		var x := r.position.x + 4.0
		while x < r.end.x - 3.0:
			for y in [5.0, 13.0]:
				m.box("dark", Vector3(x, y, c.y + side * (r.size.y * 0.5 + 0.05)), Vector3(1.8, 4.0, 0.12))
			x += 4.0
	# Corner turrets.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := c + Vector2(sx * (r.size.x * 0.5 - 1.5), sz * (r.size.y * 0.5 - 1.5))
			_box(m, "stone", Rect2(p - Vector2(3, 3), Vector2(6, 6)), 0.0, 25.0)
			_pyramid(m, "roof", p, Vector2(3.3, 3.3), 25.0, 6.0)
	# Clock tower in the middle.
	_box(m, "stone", Rect2(c - Vector2(6, 6), Vector2(12, 12)), 0.0, 50.0)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var face := c + dir * 6.05
		var size := Vector3(6.0, 6.0, 0.12) if dir.x == 0.0 else Vector3(0.12, 6.0, 6.0)
		m.box("clock", Vector3(face.x, 44.0, face.y), size)
		var slit := Vector3(1.4, 7.0, 0.12) if dir.x == 0.0 else Vector3(0.12, 7.0, 1.4)
		m.box("dark", Vector3(face.x, 33.0, face.y), slit)
	_pyramid(m, "roof", c, Vector2(6.6, 6.6), 50.0, 13.0)
	return _body("CityCountyBuilding", m)


# --- Helpers -------------------------------------------------------------

static func _body(node_name: String, m: ModelBuilder) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	var mesh := MeshInstance3D.new()
	mesh.mesh = m.build()
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(col)
	return body


## Axis-aligned box over an x/z rect, from y0 to y1.
static func _box(m: ModelBuilder, mat: String, r: Rect2, y0: float, y1: float) -> void:
	var c := r.get_center()
	m.box(mat, Vector3(c.x, (y0 + y1) * 0.5, c.y), Vector3(r.size.x, y1 - y0, r.size.y))


static func _pyramid(m: ModelBuilder, mat: String, center: Vector2, half: Vector2, y: float, rise: float) -> void:
	var apex := Vector3(center.x, y + rise, center.y)
	var corners := [
		Vector3(center.x - half.x, y, center.y - half.y), Vector3(center.x + half.x, y, center.y - half.y),
		Vector3(center.x + half.x, y, center.y + half.y), Vector3(center.x - half.x, y, center.y + half.y),
	]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		m.face(mat, a, b, apex, (a + b) * 0.5 - Vector3(center.x, y, center.y) + Vector3.UP)


## Vertical n-sided prism with a lid, base at `base`.
static func _prism(m: ModelBuilder, mat: String, base: Vector3, radius: float, height: float, sides: int) -> void:
	var top := base + Vector3.UP * height
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var d1 := Vector3(cos(a1), 0, sin(a1)) * radius
		m.quad(mat, base + d0, base + d1, top + d1, top + d0, d0 + d1)
		m.face(mat, top, top + d0, top + d1, Vector3.UP)


## Upper half of an ellipsoid sitting on `base`.
static func _dome(m: ModelBuilder, mat: String, base: Vector3, radii: Vector3, rings := 6, segs := 20) -> void:
	for ri in rings:
		var p0 := PI * 0.5 * ri / rings
		var p1 := PI * 0.5 * (ri + 1) / rings
		for si in segs:
			var a0 := TAU * si / segs
			var a1 := TAU * (si + 1) / segs
			var v := [
				_dome_pt(base, radii, p0, a0), _dome_pt(base, radii, p0, a1),
				_dome_pt(base, radii, p1, a1), _dome_pt(base, radii, p1, a0),
			]
			var mid: Vector3 = (v[0] + v[2]) * 0.5 - base
			if ri == rings - 1:
				m.face(mat, v[0], v[1], v[2], mid)
			else:
				m.quad(mat, v[0], v[1], v[2], v[3], mid)


static func _dome_pt(base: Vector3, radii: Vector3, phi: float, theta: float) -> Vector3:
	return base + Vector3(cos(phi) * cos(theta) * radii.x, sin(phi) * radii.y, cos(phi) * sin(theta) * radii.z)
