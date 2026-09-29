class_name Scenery
extends RefCounted
## Street furniture scattered as chunked MultiMeshes: trees and streetlights.

const CHUNK := 400.0
const TREE_RANGE := 2200.0
const LIGHT_RANGE := 1200.0
const LIGHT_SPACING := 45.0

const TRUNK_COLOR := Color(0.36, 0.26, 0.18)
const LEAF_COLOR := Color(0.28, 0.48, 0.2)
const POLE_COLOR := Color(0.22, 0.23, 0.25)
const LAMP_COLOR := Color(0.95, 0.92, 0.8)
# It's late September in SLC: most trees green, a few already turning.
const TREE_TINTS := [
	Color(1, 1, 1), Color(0.85, 0.95, 0.8), Color(1.1, 1.05, 0.8), Color(1, 1, 1),
	Color(0.9, 1.05, 0.9), Color(0.8, 0.9, 0.75), Color(1, 1, 1), Color(1.05, 1.0, 0.9),
	Color(2.6, 1.4, 0.3), Color(2.8, 0.9, 0.25),
]


static func build(map: Dictionary, intersections: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Scenery"
	# Trunks and canopies are separate so the fall-color tint only hits the leaves.
	var trees := _tree_items(map.trees)
	var trunks := trees.map(func(item): return [item[0], Color.WHITE])
	_scatter(root, "TreeTrunks", _trunk_mesh(), trunks, TREE_RANGE)
	_scatter(root, "TreeCanopies", _canopy_mesh(), trees, TREE_RANGE)
	_scatter(root, "Streetlights", _streetlight_mesh(), _streetlight_items(map.roads, intersections), LIGHT_RANGE)
	return root


static func _material() -> StandardMaterial3D:
	# Instance colors multiply into vertex colors.
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat


## items: Array of [Transform3D, Color]. Chunks let far-away groups get culled.
static func _scatter(parent: Node3D, label: String, mesh: Mesh, items: Array, range_end: float) -> void:
	var group := Node3D.new()
	group.name = label
	parent.add_child(group)
	var chunks := {}
	for item in items:
		var o: Vector3 = item[0].origin
		chunks.get_or_add(Vector2i(floori(o.x / CHUNK), floori(o.z / CHUNK)), []).append(item)
	for key in chunks:
		var list: Array = chunks[key]
		var center := Vector3((key.x + 0.5) * CHUNK, 0, (key.y + 0.5) * CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var t: Transform3D = list[i][0]
			t.origin -= center
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, list[i][1])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.position = center
		inst.visibility_range_end = range_end
		inst.visibility_range_end_margin = 150.0
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		group.add_child(inst)


static func _tree_items(trees: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1847  # Pioneers arrive; also keeps every run identical.
	var items := []
	for p in trees:
		var s := rng.randf_range(0.75, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s))
		items.append([Transform3D(basis, Ground.at(Vector2(p[0], p[1]))), TREE_TINTS[rng.randi() % TREE_TINTS.size()]])
	return items


static func _streetlight_items(roads: Array, intersections: Dictionary) -> Array:
	var items := []
	for road in roads:
		if road.width < 10 or road.kind.begins_with("motorway"):
			continue
		var offset: float = road.width * 0.5 + 1.0
		var pts: Array = road.pts
		for i in range(1, pts.size()):
			var a := Vector3(pts[i - 1][0], 0, pts[i - 1][1])
			var b := Vector3(pts[i][0], 0, pts[i][1])
			var length := a.distance_to(b)
			if length < 1.0:
				continue
			var dir := (b - a) / length
			var side := Vector3(-dir.z, 0, dir.x)
			var start := 12.0 if intersections.has(CityBuilder._key(pts[i - 1][0], pts[i - 1][1])) else 0.0
			var end := length - (12.0 if intersections.has(CityBuilder._key(pts[i][0], pts[i][1])) else 0.0)
			var t := start + LIGHT_SPACING * 0.5
			while t < end:
				for s in [-1.0, 1.0]:
					var toward_road: Vector3 = -side * s
					var basis := Basis(toward_road, Vector3.UP, toward_road.cross(Vector3.UP))
					var p: Vector3 = a + dir * t + side * s * offset
					items.append([Transform3D(basis, Ground.at(Vector2(p.x, p.z))), Color.WHITE])
				t += LIGHT_SPACING
	return items


static func _trunk_mesh() -> ArrayMesh:
	var buf := MeshBuffer.new()
	_add_prism(buf, Vector3.ZERO, 0.22, 2.4, 5, TRUNK_COLOR)
	return buf.to_mesh(_material())


static func _canopy_mesh() -> ArrayMesh:
	var buf := MeshBuffer.new()
	_add_icosahedron(buf, Vector3(0, 4.2, 0), Vector3(2.4, 2.1, 2.4), LEAF_COLOR)
	_add_icosahedron(buf, Vector3(0.6, 5.4, -0.3), Vector3(1.5, 1.4, 1.5), LEAF_COLOR.lightened(0.08))
	return buf.to_mesh(_material())


static func _streetlight_mesh() -> ArrayMesh:
	# Local +X points out over the road.
	var buf := MeshBuffer.new()
	_add_prism(buf, Vector3.ZERO, 0.1, 7.5, 6, POLE_COLOR)
	_add_prism(buf, Vector3.ZERO, 0.18, 0.5, 6, POLE_COLOR)
	CityBuilder._add_box(buf, Vector3(1.1, 7.45, 0), Vector3(2.2, 0.1, 0.1), POLE_COLOR, Vector2.ZERO)
	CityBuilder._add_box(buf, Vector3(2.15, 7.35, 0), Vector3(0.6, 0.14, 0.3), LAMP_COLOR, Vector2.ZERO)
	return buf.to_mesh(_material())


static func _add_prism(buf: MeshBuffer, base: Vector3, radius: float, height: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := base + Vector3(cos(a1), 0, sin(a1)) * radius
		var n := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		buf.add_quad(p0, p1, p1 + Vector3.UP * height, p0 + Vector3.UP * height, n, col)


static func _add_icosahedron(buf: MeshBuffer, center: Vector3, scale: Vector3, col: Color) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for f in faces:
		var a: Vector3 = center + v[f[0]].normalized() * scale
		var b: Vector3 = center + v[f[1]].normalized() * scale
		var c: Vector3 = center + v[f[2]].normalized() * scale
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c) / 3.0 - center) < 0.0:
			n = -n
		# Darken the underside a touch so canopies read as round even in flat light.
		var shade := lerpf(0.75, 1.05, n.y * 0.5 + 0.5)
		buf.add_tri(a, b, c, n, col * shade)
