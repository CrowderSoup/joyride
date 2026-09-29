class_name CityBuilder
extends RefCounted
## Builds the drivable city (ground, lots, parks, roads, buildings) from the map JSON.
## Street furniture lives in Scenery, the mountains in Terrain.

# Everything is flat; these tiny offsets just keep overlapping layers from z-fighting.
const PARKING_Y := 0.012
const GREEN_Y := 0.018
const SIDEWALK_Y := 0.025
const ROAD_HEIGHT := {
	"motorway": 0.09, "trunk": 0.085, "primary": 0.08, "secondary": 0.075,
	"tertiary": 0.07, "residential": 0.06, "unclassified": 0.06, "service": 0.045,
}
const MARKING_LIFT := 0.012

const GROUND_COLOR := Color(0.34, 0.4, 0.25)
const GREEN_COLOR := Color(0.3, 0.5, 0.2)
const PARKING_COLOR := Color(0.25, 0.25, 0.26)
const SIDEWALK_COLOR := Color(0.52, 0.51, 0.48)
const ROAD_COLOR := Color(0.13, 0.13, 0.14)
const SERVICE_COLOR := Color(0.2, 0.2, 0.21)
const YELLOW_LINE := Color(0.95, 0.75, 0.2)
const WHITE_LINE := Color(0.9, 0.9, 0.88)

const WALL_COLORS := [
	Color(0.85, 0.78, 0.66), Color(0.76, 0.55, 0.45), Color(0.66, 0.7, 0.74),
	Color(0.9, 0.87, 0.8), Color(0.6, 0.48, 0.4), Color(0.72, 0.76, 0.68),
	Color(0.8, 0.66, 0.52),
]
const HOUSE_COLORS := [
	Color(0.92, 0.9, 0.84), Color(0.85, 0.78, 0.62), Color(0.7, 0.78, 0.82),
	Color(0.9, 0.85, 0.6), Color(0.7, 0.42, 0.34), Color(0.78, 0.82, 0.72),
]
const ROOF_COLORS := [
	Color(0.25, 0.25, 0.27), Color(0.38, 0.28, 0.22), Color(0.55, 0.3, 0.22),
	Color(0.35, 0.38, 0.42),
]
const FLAT_ROOF_COLOR := Color(0.5, 0.5, 0.5)
const HVAC_COLOR := Color(0.7, 0.7, 0.68)

const DISC_SEGMENTS := 6
const SIDEWALK_WIDTH := 2.5
const INTERSECTION_TRIM := 10.0  # keep lane markings out of intersections
const DASH := 3.0
const DASH_GAP := 6.0


static func build(map: Dictionary, intersections: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "City"
	root.add_child(_build_ground())
	root.add_child(_build_surface(map, intersections))
	root.add_child(_build_buildings(map.buildings))
	return root


## Road vertices shared by more than one way. Keyed by position rounded to 10cm.
static func find_intersections(roads: Array) -> Dictionary:
	var counts := {}
	for road in roads:
		var seen := {}
		for p in road.pts:
			var key := _key(p[0], p[1])
			if not seen.has(key):
				seen[key] = true
				counts[key] = counts.get(key, 0) + 1
	var result := {}
	for key in counts:
		if counts[key] > 1:
			result[key] = true
	return result


static func _key(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x * 10.0), roundi(z * 10.0))


static func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	return mat


static func _build_ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)

	var plane := PlaneMesh.new()
	plane.size = Vector2(60000, 60000)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 1.0
	plane.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	body.add_child(mesh)
	return body


## Everything painted flat on the ground: lots, parks, sidewalks, roads, and markings.
static func _build_surface(map: Dictionary, intersections: Dictionary) -> StaticBody3D:
	var tiles := MeshTiles.new()

	for area in map.areas:
		var y := PARKING_Y if area.kind == "parking" else GREEN_Y
		var col := PARKING_COLOR if area.kind == "parking" else GREEN_COLOR
		var poly := PackedVector2Array()
		for p in area.pts:
			poly.append(Vector2(p[0], p[1]))
		var buf := tiles.at(_v3(poly[0], y))
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			buf.add_tri(_v3(poly[tris[t]], y), _v3(poly[tris[t + 1]], y), _v3(poly[tris[t + 2]], y), Vector3.UP, col)

	for road in map.roads:
		if _has_sidewalk(road.kind):
			_add_polyline(tiles, road.pts, SIDEWALK_Y, road.width * 0.5 + SIDEWALK_WIDTH, SIDEWALK_COLOR)
	for road in map.roads:
		var col := SERVICE_COLOR if road.kind == "service" else ROAD_COLOR
		_add_polyline(tiles, road.pts, ROAD_HEIGHT.get(road.kind, 0.05), road.width * 0.5, col)
	for road in map.roads:
		_add_markings(tiles, road, intersections)
	return tiles.build("Surface", _vertex_color_material(), false, false)


static func _has_sidewalk(kind: String) -> bool:
	return kind != "service" and not kind.begins_with("motorway") and not kind.ends_with("_link")


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _add_polyline(tiles: MeshTiles, pts: Array, y: float, half_width: float, col: Color) -> void:
	for i in pts.size():
		var p := Vector3(pts[i][0], y, pts[i][1])
		# A disc at every vertex fills the gaps where segments bend or meet.
		_add_disc(tiles.at(p), p, half_width, col)
		if i > 0:
			_add_ribbon(tiles.at(p), Vector3(pts[i - 1][0], y, pts[i - 1][1]), p, half_width, col)


static func _add_markings(tiles: MeshTiles, road: Dictionary, intersections: Dictionary) -> void:
	var w: float = road.width
	var is_motorway: bool = road.kind == "motorway"
	if w < 10.0 and not is_motorway:
		return
	var y: float = ROAD_HEIGHT.get(road.kind, 0.05) + MARKING_LIFT
	var pts: Array = road.pts
	for i in range(1, pts.size()):
		var a := Vector3(pts[i - 1][0], y, pts[i - 1][1])
		var b := Vector3(pts[i][0], y, pts[i][1])
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var dir := (b - a) / length
		var side := Vector3(-dir.z, 0, dir.x)
		var buf := tiles.at(a)
		var a_cross: bool = intersections.has(_key(pts[i - 1][0], pts[i - 1][1]))
		var b_cross: bool = intersections.has(_key(pts[i][0], pts[i][1]))
		var t0 := INTERSECTION_TRIM if a_cross else 0.0
		var t1 := length - (INTERSECTION_TRIM if b_cross else 0.0)
		if t1 - t0 > 1.0:
			var s := a + dir * t0
			var e := a + dir * t1
			if is_motorway:
				for off in [-w / 6.0, w / 6.0]:
					_add_dashes(buf, s + side * off, dir, t1 - t0, WHITE_LINE)
			else:
				for off in [-0.18, 0.18]:
					_add_ribbon(buf, s + side * off, e + side * off, 0.07, YELLOW_LINE)
				if w >= 12.0:
					for off in [-w * 0.25, w * 0.25]:
						_add_dashes(buf, s + side * off, dir, t1 - t0, WHITE_LINE)
			for off in [-(w * 0.5 - 0.5), w * 0.5 - 0.5]:
				_add_ribbon(buf, s + side * off, e + side * off, 0.08, WHITE_LINE)
		# Zebra crosswalks just outside each intersection on bigger streets.
		if not is_motorway and length > INTERSECTION_TRIM * 2.0:
			if a_cross:
				_add_crosswalk(buf, a + dir * (INTERSECTION_TRIM - 3.5), dir, side, w)
			if b_cross:
				_add_crosswalk(buf, b - dir * (INTERSECTION_TRIM - 0.5), dir, side, w)


static func _add_dashes(buf: MeshBuffer, start: Vector3, dir: Vector3, length: float, col: Color) -> void:
	var t := 0.0
	while t < length:
		var e := minf(t + DASH, length)
		_add_ribbon(buf, start + dir * t, start + dir * e, 0.08, col)
		t += DASH + DASH_GAP


static func _add_crosswalk(buf: MeshBuffer, start: Vector3, dir: Vector3, side: Vector3, w: float) -> void:
	var off := -w * 0.5 + 0.8
	while off < w * 0.5 - 0.6:
		var s := start + side * off
		_add_ribbon(buf, s, s + dir * 3.0, 0.3, WHITE_LINE)
		off += 1.2


static func _add_ribbon(buf: MeshBuffer, a: Vector3, b: Vector3, half_width: float, col: Color) -> void:
	var dir := b - a
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x) * half_width
	buf.add_quad(a - side, a + side, b + side, b - side, Vector3.UP, col)


static func _add_disc(buf: MeshBuffer, center: Vector3, radius: float, col: Color) -> void:
	for i in DISC_SEGMENTS:
		var a0 := TAU * i / DISC_SEGMENTS
		var a1 := TAU * (i + 1) / DISC_SEGMENTS
		buf.add_tri(
			center,
			center + Vector3(cos(a0), 0, sin(a0)) * radius,
			center + Vector3(cos(a1), 0, sin(a1)) * radius,
			Vector3.UP, col)


static func _build_buildings(buildings: Array) -> StaticBody3D:
	var tiles := MeshTiles.new()
	for idx in buildings.size():
		var p: Array = buildings[idx].pts[0]
		_add_building(tiles.at(Vector3(p[0], 0, p[1])), buildings[idx], idx)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/building.gdshader")
	return tiles.build("Buildings", mat, true, true)


static func _add_building(buf: MeshBuffer, b: Dictionary, idx: int) -> void:
	var h: float = b.h
	var poly := PackedVector2Array()
	for p in b.pts:
		poly.append(Vector2(p[0], p[1]))
	var n := poly.size()
	if n < 3:
		return

	# Signed area tells us winding, so we know which side of each wall is "outside".
	var area2 := 0.0
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		area2 += p0.x * p1.y - p1.x * p0.y
	var outward_sign := 1.0 if area2 > 0.0 else -1.0
	var area := absf(area2) * 0.5

	var is_house := h <= 9.0 and area < 300.0 and _is_convex(poly)
	var wall_col: Color = (HOUSE_COLORS if is_house else WALL_COLORS)[idx % (HOUSE_COLORS.size() if is_house else WALL_COLORS.size())]
	var wall_flags := Vector2(1.0, h)
	var roof_flags := Vector2(0.0, h)

	# Walls. UV = meters along the perimeter / meters up, for the window shader.
	var run := 0.0
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var d := p1 - p0
		var seg := d.length()
		if seg < 0.01:
			continue
		var normal := Vector3(d.y, 0, -d.x).normalized() * outward_sign
		buf.add_quad(
			Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y),
			Vector3(p1.x, h, p1.y), Vector3(p0.x, h, p0.y),
			normal, wall_col,
			Vector2(run, 0), Vector2(run + seg, 0), Vector2(run + seg, h), Vector2(run, h), wall_flags)
		run += seg

	if is_house:
		_add_hip_roof(buf, poly, h, area, ROOF_COLORS[idx % ROOF_COLORS.size()], roof_flags)
		return

	# Flat roof sunk below a parapet: inward-facing walls make the lip.
	var roof_y := h - 0.45
	for i in n:
		var p0 := poly[i]
		var p1 := poly[(i + 1) % n]
		var d := p1 - p0
		if d.length_squared() < 0.0001:
			continue
		var inward := -Vector3(d.y, 0, -d.x).normalized() * outward_sign
		buf.add_quad(
			Vector3(p0.x, roof_y, p0.y), Vector3(p1.x, roof_y, p1.y),
			Vector3(p1.x, h, p1.y), Vector3(p0.x, h, p0.y),
			inward, wall_col.darkened(0.2), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, roof_flags)
	var tris := Geometry2D.triangulate_polygon(poly)
	for t in range(0, tris.size(), 3):
		buf.add_tri(_v3(poly[tris[t]], roof_y), _v3(poly[tris[t + 1]], roof_y), _v3(poly[tris[t + 2]], roof_y),
			Vector3.UP, FLAT_ROOF_COLOR, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, roof_flags)

	if h >= 12.0 and area > 300.0:
		_add_rooftop_units(buf, poly, roof_y, area, idx, roof_flags)


static func _is_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	var sign := 0.0
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var c := poly[(i + 2) % n]
		var cross := (b - a).cross(c - b)
		if absf(cross) < 0.01:
			continue
		if sign == 0.0:
			sign = signf(cross)
		elif signf(cross) != sign:
			return false
	return true


static func _add_hip_roof(buf: MeshBuffer, poly: PackedVector2Array, h: float, area: float, col: Color, flags: Vector2) -> void:
	var center := Vector2.ZERO
	for p in poly:
		center += p
	center /= poly.size()
	var apex := _v3(center, h + clampf(sqrt(area) * 0.22, 1.2, 3.2))
	for i in poly.size():
		var a := _v3(poly[i], h)
		var b := _v3(poly[(i + 1) % poly.size()], h)
		var n := (b - a).cross(apex - a).normalized()
		if n.y < 0.0:
			n = -n
		buf.add_tri(a, b, apex, n, col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, flags)


static func _add_rooftop_units(buf: MeshBuffer, poly: PackedVector2Array, roof_y: float, area: float, idx: int, flags: Vector2) -> void:
	var center := Vector2.ZERO
	for p in poly:
		center += p
	center /= poly.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = idx
	var spread := sqrt(area) * 0.25
	for i in rng.randi_range(1, 3):
		var pos := center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
		if not Geometry2D.is_point_in_polygon(pos, poly):
			continue
		var size := Vector3(rng.randf_range(2.0, 5.0), rng.randf_range(1.2, 2.5), rng.randf_range(2.0, 5.0))
		_add_box(buf, _v3(pos, roof_y + size.y * 0.5), size, HVAC_COLOR, flags)


static func _add_box(buf: MeshBuffer, c: Vector3, size: Vector3, col: Color, flags: Vector2) -> void:
	var e := size * 0.5
	var faces := [
		[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3.RIGHT, [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
		[Vector3.LEFT, [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)]],
		[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3.FORWARD, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
	]
	for f in faces:
		var q: Array = f[1]
		var shade: float = 1.0 if f[0] == Vector3.UP else 0.85
		buf.add_quad(c + q[0] * e, c + q[1] * e, c + q[2] * e, c + q[3] * e, f[0], col * shade,
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, flags)
