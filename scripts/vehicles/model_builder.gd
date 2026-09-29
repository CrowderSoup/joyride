class_name ModelBuilder
extends RefCounted
## Procedural low-poly modeling helpers for vehicles. Shapes are mostly side-profile
## polygons (in the Z/Y plane) extruded across X, which is how you'd block out a car
## in a real modeling tool. Each material becomes one surface of the final mesh.
## Convention: vehicle faces -Z, +Y up, origin on the ground at the center.

var _bufs := {}
var _mats := {}


func add_material(mat_name: String, color: Color, roughness := 0.6, metallic := 0.0, emission := 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_mats[mat_name] = mat
	_bufs[mat_name] = MeshBuffer.new()


func face(mat_name: String, a: Vector3, b: Vector3, c: Vector3, outward_hint: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot(outward_hint) < 0.0:
		n = -n
	_bufs[mat_name].add_tri(a, b, c, n, Color.WHITE)


func quad(mat_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward_hint: Vector3) -> void:
	face(mat_name, a, b, c, outward_hint)
	face(mat_name, a, c, d, outward_hint)


## Extrude a side profile (points are (z, y)) across X.
## half_width is a float, a Callable(y) -> float for tumblehome, or a Callable(z, y) -> float
## that also pinches the ends in plan view (keep those pieces short, the caps are flat tris).
func extrude(mat_name: String, profile: PackedVector2Array, half_width: Variant, center_x := 0.0) -> void:
	var poly := profile.duplicate()  # reverse() below would flip the caller's array too
	if _signed_area(poly) < 0.0:
		poly.reverse()
	var n := poly.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for p in poly:
		var w: float
		if half_width is Callable:
			w = half_width.call(p.y) if half_width.get_argument_count() == 1 else half_width.call(p.x, p.y)
		else:
			w = half_width
		left.append(Vector3(center_x - w, p.y, p.x))
		right.append(Vector3(center_x + w, p.y, p.x))

	var tris := Geometry2D.triangulate_polygon(poly)
	for t in range(0, tris.size(), 3):
		face(mat_name, right[tris[t]], right[tris[t + 1]], right[tris[t + 2]], Vector3.RIGHT)
		face(mat_name, left[tris[t]], left[tris[t + 1]], left[tris[t + 2]], Vector3.LEFT)
	for i in n:
		var j := (i + 1) % n
		var d := poly[j] - poly[i]
		# Outward normal of an edge on a counter-clockwise (z, y) polygon.
		var hint := Vector3(0, -d.x, d.y)
		quad(mat_name, left[i], left[j], right[j], right[i], hint)


func box(mat_name: String, center: Vector3, size: Vector3) -> void:
	var e := size * 0.5
	var profile := PackedVector2Array([
		Vector2(center.z - e.z, center.y - e.y), Vector2(center.z + e.z, center.y - e.y),
		Vector2(center.z + e.z, center.y + e.y), Vector2(center.z - e.z, center.y + e.y),
	])
	extrude(mat_name, profile, e.x, center.x)


## Cylinder whose axis runs along X (wheels, lights seen from the side).
func cylinder_x(mat_name: String, center: Vector3, radius: float, width: float, segments := 16) -> void:
	var profile := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		profile.append(Vector2(center.z + cos(a) * radius, center.y + sin(a) * radius))
	extrude(mat_name, profile, width * 0.5, center.x)


## Half-ring around a wheel opening, for fender flares. Profile in (z, y).
static func arch_profile(center: Vector2, inner: float, outer: float, floor_y: float, segments := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a_out := asin(clampf((floor_y - center.y) / outer, -1.0, 1.0))
	var a_in := asin(clampf((floor_y - center.y) / inner, -1.0, 1.0))
	for i in segments + 1:
		var a := lerpf(a_out, PI - a_out, float(i) / segments)
		pts.append(center + Vector2(cos(a), sin(a)) * outer)
	for i in segments + 1:
		var a := lerpf(PI - a_in, a_in, float(i) / segments)
		pts.append(center + Vector2(cos(a), sin(a)) * inner)
	return pts


## Points along a wheel-arch cutout, from the rear edge over the top to the front edge.
static func arch_points(center: Vector2, radius: float, floor_y: float, segments := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := asin(clampf((floor_y - center.y) / radius, -1.0, 1.0))
	for i in segments + 1:
		var a := lerpf(a0, PI - a0, float(i) / segments)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


## Skin a surface through closed rings of points (all the same size), capping the ends.
## mat is a material name, or a Callable(face_midpoint) -> String to paint regions (windows,
## stripes) straight onto the skin. smooth shades it round, with normals pointing away
## from each ring's center.
func loft(mat: Variant, rings: Array, smooth := false, caps := true) -> void:
	var centers: Array[Vector3] = []
	for ring in rings:
		centers.append(_centroid(ring))
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		for i in a.size():
			var j := (i + 1) % a.size()
			var mid := (a[i] + a[j] + b[i] + b[j]) * 0.25
			var m: String = mat.call(mid) if mat is Callable else mat
			if smooth:
				var na := (a[i] - centers[r]).normalized()
				var nb := (a[j] - centers[r]).normalized()
				var nc := (b[j] - centers[r + 1]).normalized()
				var nd := (b[i] - centers[r + 1]).normalized()
				_smooth_tri(m, a[i], a[j], b[j], na, nb, nc)
				_smooth_tri(m, a[i], b[j], b[i], na, nc, nd)
			else:
				quad(m, a[i], a[j], b[j], b[i], mid - (centers[r] + centers[r + 1]) * 0.5)
	if not caps:
		return
	for end in [0, rings.size() - 1]:
		var ring: PackedVector3Array = rings[end]
		var c := centers[end]
		var out := c - centers[1 if end == 0 else end - 1]
		var m: String = mat.call(c) if mat is Callable else mat
		for i in ring.size():
			face(m, c, ring[i], ring[(i + 1) % ring.size()], out)


## Round tube from a to b (frame rails, forks, struts, exhaust pipes).
func tube(mat_name: String, a: Vector3, b: Vector3, radius: float, segments := 10, radius_b := -1.0) -> void:
	var axis := (b - a).normalized()
	loft(mat_name, [
		circle(a, axis, radius, segments),
		circle(b, axis, radius_b if radius_b >= 0.0 else radius, segments),
	], true)


## Surface of revolution around an X-axis line through center (tires, rims, brake discs).
## profile is a closed cross-section of (x offset, radius) points - what you'd see if you
## sliced the wheel through the axle. Round around the axle, crisp along the profile.
func lathe(mat_name: String, profile: PackedVector2Array, center := Vector3.ZERO, segments := 24) -> void:
	var poly := profile.duplicate()
	if _signed_area(poly) < 0.0:
		poly.reverse()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var d := q - p
		var en := Vector2(d.y, -d.x).normalized()  # outward, for a counter-clockwise polygon
		for k in segments:
			var a0 := TAU * k / segments
			var a1 := TAU * (k + 1) / segments
			var u0 := Vector3(0, cos(a0), sin(a0))
			var u1 := Vector3(0, cos(a1), sin(a1))
			var n0 := Vector3(en.x, 0, 0) + u0 * en.y
			var n1 := Vector3(en.x, 0, 0) + u1 * en.y
			var pa := center + Vector3(p.x, 0, 0) + u0 * p.y
			var pb := center + Vector3(p.x, 0, 0) + u1 * p.y
			var qa := center + Vector3(q.x, 0, 0) + u0 * q.y
			var qb := center + Vector3(q.x, 0, 0) + u1 * q.y
			_smooth_tri(mat_name, pa, pb, qb, n0, n1, n1)
			_smooth_tri(mat_name, pa, qb, qa, n0, n1, n0)


## Ring of points around center, in the plane facing axis.
static func circle(center: Vector3, axis: Vector3, radius: float, segments := 12) -> PackedVector3Array:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	var pts := PackedVector3Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + (u * cos(a) + v * sin(a)) * radius)
	return pts


## Cross-section at station z: a box half_w wide, from bottom to top, with its corners
## rounded by radius r (clamped so tiny sections become ovals). Same point count every time,
## so sections can be lofted together. Points on the flat sides are spread evenly.
static func rounded_section(z: float, half_w: float, bottom: float, top: float, r: float,
		side_segs := 4, corner_segs := 4) -> PackedVector3Array:
	var half_h := (top - bottom) * 0.5
	var cy := (top + bottom) * 0.5
	r = minf(r, minf(half_w, half_h))
	var pts := PackedVector3Array()
	# Corner centers counter-clockwise from bottom-right, seen from +Z.
	var corners := [
		Vector2(half_w - r, cy - half_h + r), Vector2(half_w - r, cy + half_h - r),
		Vector2(-half_w + r, cy + half_h - r), Vector2(-half_w + r, cy - half_h + r),
	]
	for k in 4:
		var c: Vector2 = corners[k]
		var a0 := -PI / 2 + k * PI / 2
		for i in corner_segs:
			var a := a0 + (PI / 2) * i / corner_segs
			pts.append(Vector3(c.x + cos(a) * r, c.y + sin(a) * r, z))
		var next: Vector2 = corners[(k + 1) % 4]
		var edge_start: Vector2 = c + Vector2(cos(a0 + PI / 2), sin(a0 + PI / 2)) * r
		var edge_end: Vector2 = next + Vector2(cos(a0 + PI / 2), sin(a0 + PI / 2)) * r
		for i in side_segs:
			pts.append(_v3(edge_start.lerp(edge_end, float(i) / side_segs), z))
	return pts


## Airfoil ring: leading edge at le, chord running along chord_dir, thickness along up.
## camber moves thickness from the bottom to the top; 0 is symmetric (fins, tailplanes).
static func airfoil(le: Vector3, chord_dir: Vector3, up: Vector3, chord: float, thickness: float,
		camber := 0.25, segments := 8) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var upper: Array[Vector3] = []
	var lower: Array[Vector3] = []
	for i in segments + 1:
		var u := 1.0 - cos(PI * 0.5 * float(i) / segments)  # bunch points at the leading edge
		# NACA 4-digit thickness distribution.
		var t := 5.0 * thickness * (0.2969 * sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u * u * u - 0.1036 * u * u * u * u)
		var p := le + chord_dir * u * chord
		upper.append(p + up * t * chord * (1.0 + camber))
		lower.append(p - up * t * chord * (1.0 - camber))
	for i in segments + 1:
		pts.append(upper[i])
	for i in range(segments - 1, 0, -1):
		pts.append(lower[i])
	return pts


static func _v3(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, p.y, z)


static func _centroid(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / ring.size()


func _smooth_tri(mat_name: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var buf: MeshBuffer = _bufs[mat_name]
	var n := na + nb + nc
	if (b - a).cross(c - a).length_squared() < 1e-12:
		return
	# Godot treats clockwise triangles as front faces.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	buf.verts.append_array([a, b, c])
	buf.normals.append_array([na, nb, nc])
	buf.colors.append_array([Color.WHITE, Color.WHITE, Color.WHITE])
	buf.uvs.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	buf.uv2s.append_array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat_name in _bufs:
		var buf: MeshBuffer = _bufs[mat_name]
		if buf.verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = buf.verts
		arrays[Mesh.ARRAY_NORMAL] = buf.normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[mat_name])
	return mesh


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
