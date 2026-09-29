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
## half_width is a float, or a Callable(y) -> float for tumblehome/tapers.
func extrude(mat_name: String, profile: PackedVector2Array, half_width: Variant, center_x := 0.0) -> void:
	var poly := profile.duplicate()  # reverse() below would flip the caller's array too
	if _signed_area(poly) < 0.0:
		poly.reverse()
	var n := poly.size()
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for p in poly:
		var w: float = half_width.call(p.y) if half_width is Callable else half_width
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
