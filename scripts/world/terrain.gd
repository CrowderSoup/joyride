class_name Terrain
extends RefCounted
## Builds the land from Ground's grids: fine, grassy ground under the city and the real
## valley out to the Wasatch, the Oquirrhs and the lake. Flat-shaded, low-poly on purpose.

## The city ground is drawn this far below the collision surface, so paint laid over it
## (lots, sidewalks, roads - which only approximate its creases) never gets poked through.
const SINK := 0.2

const GRASS_COLOR := Color(0.34, 0.4, 0.25)
const VALLEY_COLOR := Color(0.4, 0.42, 0.28)
const FOOTHILL_COLOR := Color(0.34, 0.3, 0.2)
const SCRUB_COLOR := Color(0.2, 0.26, 0.15)
const ROCK_COLOR := Color(0.4, 0.39, 0.41)
const SNOW_COLOR := Color(0.93, 0.95, 0.98)
const WATER_COLOR := Color(0.3, 0.45, 0.5)
const SALT_COLOR := Color(0.78, 0.76, 0.7)

## Where the town is: mowed grass here, wild hillside outside. The grid, then the airport
## and I-15 strip along the west side.
const URBAN := [Rect2(-1450, -600, 2950, 2700), Rect2(-1450, -1600, 600, 5150)]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var detail := FastNoiseLite.new()
	detail.seed = 7
	detail.frequency = 1.0 / 900.0
	root.add_child(_build_near(detail))
	root.add_child(_build_far(detail))

	# Past the edge of the data: flat lake-level plain to the horizon, and a floor under
	# everything so nothing falls forever.
	var plane := PlaneMesh.new()
	plane.size = Vector2(120000, 120000)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = VALLEY_COLOR
	mat.roughness = 1.0
	plane.material = mat
	var horizon := MeshInstance3D.new()
	horizon.mesh = plane
	horizon.position.y = Ground.LAKE_LEVEL - 3.0
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(horizon)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = Ground.LAKE_LEVEL - 20.0
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = WorldBoundaryShape3D.new()
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	return root


static func _build_near(detail: FastNoiseLite) -> StaticBody3D:
	var g := Ground.near()
	var tiles := MeshTiles.new()
	for iz in g.nz - 1:
		for ix in g.nx - 1:
			var x0 := g.x_at(ix)
			var z0 := g.z_at(iz)
			var p00 := Vector3(x0, g.at(ix, iz), z0)
			var p10 := Vector3(x0 + g.step, g.at(ix + 1, iz), z0)
			var p01 := Vector3(x0, g.at(ix, iz + 1), z0 + g.step)
			var p11 := Vector3(x0 + g.step, g.at(ix + 1, iz + 1), z0 + g.step)
			var buf := tiles.at(p00)
			# HeightMapShape3D splits each cell across p10-p01.
			_add_face(buf, p00, p10, p01, detail, true)
			_add_face(buf, p10, p11, p01, detail, true)
	var body := tiles.build("Ground", _material(), false, false)
	for child in body.get_children():
		child.position.y = -SINK
	# A heightmap rather than a trimesh: vehicle boxes sliding over a trimesh snag on its
	# internal edges. Heightmaps are 1 m per cell, so scale it up to the grid's step.
	var shape := HeightMapShape3D.new()
	shape.map_width = g.nx
	shape.map_depth = g.nz
	var data := g.h.duplicate()
	for i in data.size():
		data[i] /= g.step
	shape.map_data = data
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * g.step
	col.position = Vector3(g.x0 + (g.nx - 1) * g.step * 0.5, 0, g.z0 + (g.nz - 1) * g.step * 0.5)
	body.add_child(col)
	return body


static func _build_far(detail: FastNoiseLite) -> StaticBody3D:
	var g := Ground.far()
	var skip := Ground.near().bounds()
	var buf := MeshBuffer.new()
	for iz in g.nz - 1:
		for ix in g.nx - 1:
			var x0 := g.x_at(ix)
			var z0 := g.z_at(iz)
			# Near's edges are on this grid's lines, so a cell is either all in or all out.
			if skip.has_point(Vector2(x0 + g.step * 0.5, z0 + g.step * 0.5)):
				continue
			var p00 := Vector3(x0, g.at(ix, iz), z0)
			var p10 := Vector3(x0 + g.step, g.at(ix + 1, iz), z0)
			var p01 := Vector3(x0, g.at(ix, iz + 1), z0 + g.step)
			var p11 := Vector3(x0 + g.step, g.at(ix + 1, iz + 1), z0 + g.step)
			_add_face(buf, p00, p10, p11, detail, false)
			_add_face(buf, p00, p11, p01, detail, false)

	var body := StaticBody3D.new()
	body.name = "Valley"
	var mesh := MeshInstance3D.new()
	mesh.mesh = buf.to_mesh(_material())
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(buf.verts)
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body


static func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	return mat


static func _urban(x: float, z: float) -> float:
	var d := INF
	for r: Rect2 in URBAN:
		d = minf(d, Vector2(maxf(0.0, maxf(r.position.x - x, x - r.end.x)), maxf(0.0, maxf(r.position.y - z, z - r.end.y))).length())
	return 1.0 - smoothstep(0.0, 300.0, d)


static func _add_face(buf: MeshBuffer, a: Vector3, b: Vector3, c: Vector3, detail: FastNoiseLite, fine: bool) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var mid := (a + b + c) / 3.0
	var h := mid.y + detail.get_noise_2d(mid.x * 3.0, mid.z * 3.0) * 120.0
	var col := FOOTHILL_COLOR
	var top := maxf(a.y, maxf(b.y, c.y))
	if top <= Ground.LAKE_LEVEL + 0.05:
		col = WATER_COLOR  # the fetch tool flattened the lake to its surface
	elif top <= Ground.LAKE_LEVEL + 2.0:
		col = SALT_COLOR  # flats along the shore
	elif h > 1750.0 and n.y > 0.55:
		col = SNOW_COLOR
	elif n.y < 0.72 or h > 1500.0:
		col = ROCK_COLOR
	elif h > 450.0:
		col = SCRUB_COLOR
	elif mid.y < 60.0 and n.y > 0.97:
		col = VALLEY_COLOR
	if fine:
		col = col.lerp(GRASS_COLOR, _urban(mid.x, mid.z))
	col = col.lerp(col.darkened(0.15), (detail.get_noise_2d(mid.x, mid.z) + 1.0) * 0.5)
	buf.add_tri(a, b, c, n, col)
