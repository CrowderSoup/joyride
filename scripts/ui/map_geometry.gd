class_name MapGeometry
extends RefCounted
## Flattens the map JSON into one 2D mesh (buildings + roads) and a set of street labels,
## shared by the minimap and the full map. Map space is world X/Z in meters, north up.

const BUILDING_COLOR := Color(0.3, 0.3, 0.34)
const MINOR_ROAD_COLOR := Color(0.55, 0.55, 0.58)
const MAJOR_ROAD_COLOR := Color(0.95, 0.8, 0.4)
const MOTORWAY_COLOR := Color(0.95, 0.55, 0.3)
const AEROWAY_COLOR := Color(0.42, 0.42, 0.46)
const AREA_COLORS := {
	"aeroway": AEROWAY_COLOR, "green": Color(0.2, 0.32, 0.18), "water": Color(0.2, 0.36, 0.5),
}
const MAJOR_KINDS := ["trunk", "primary", "secondary"]
const LABEL_KINDS := ["motorway", "trunk", "primary", "secondary", "tertiary"]
const LABEL_SPACING := 700.0

var mesh: ArrayMesh
var bounds: Rect2
## Array of {"name": String, "pos": Vector2, "major": bool}
var labels: Array = []

var _verts := PackedVector2Array()
var _colors := PackedColorArray()


func _init(map: Dictionary) -> void:
	for area in map.areas:
		if AREA_COLORS.has(area.kind):
			_add_polygon(area.pts, AREA_COLORS[area.kind])
	for b in map.buildings:
		var poly := PackedVector2Array()
		for p in b.pts:
			poly.append(Vector2(p[0], p[1]))
		var tris := Geometry2D.triangulate_polygon(poly)
		for i in tris:
			_verts.append(poly[i])
			_colors.append(BUILDING_COLOR)

	# Draw minor roads first so the big ones paint over them at intersections.
	var ordered: Array = map.roads.duplicate()
	ordered.sort_custom(func(a, b): return _rank(a.kind) < _rank(b.kind))
	for road in ordered:
		var col := MINOR_ROAD_COLOR
		if road.kind in MAJOR_KINDS:
			col = MAJOR_ROAD_COLOR
		elif road.kind.begins_with("motorway"):
			col = MOTORWAY_COLOR
		var half_width: float = road.width * 0.5
		var pts: Array = road.pts
		for i in pts.size():
			var p := Vector2(pts[i][0], pts[i][1])
			_add_square(p, half_width, col)
			if i > 0:
				_add_ribbon(Vector2(pts[i - 1][0], pts[i - 1][1]), p, half_width, col)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	bounds = Rect2(_verts[0], Vector2.ZERO)
	for v in _verts:
		bounds = bounds.expand(v)
	_verts.clear()
	_colors.clear()

	_build_labels(map.roads)


static func _rank(kind: String) -> int:
	if kind.begins_with("motorway"):
		return 3
	if kind in MAJOR_KINDS:
		return 2
	if kind == "service":
		return 0
	return 1


func _add_polygon(pts: Array, col: Color) -> void:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p[0], p[1]))
	for i in Geometry2D.triangulate_polygon(poly):
		_verts.append(poly[i])
		_colors.append(col)


func _add_ribbon(a: Vector2, b: Vector2, half_width: float, col: Color) -> void:
	var dir := b - a
	if dir.length_squared() < 0.0001:
		return
	var side := dir.normalized().orthogonal() * half_width
	for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
		_verts.append(v)
		_colors.append(col)


func _add_square(c: Vector2, r: float, col: Color) -> void:
	# Cheap joint filler; at map scale nobody can tell it's not round.
	var d := Vector2(r, r) * 0.8
	var e := Vector2(r, -r) * 0.8
	for v in [c - d, c + e, c + d, c - d, c + d, c - e]:
		_verts.append(v)
		_colors.append(col)


func _build_labels(roads: Array) -> void:
	# One label per street every LABEL_SPACING meters, so long grid streets stay readable.
	var placed := {}
	for road in roads:
		var street_name: String = road.name
		if street_name == "" or not road.kind in LABEL_KINDS:
			continue
		var pts: Array = road.pts
		for i in range(1, pts.size()):
			var mid := (Vector2(pts[i - 1][0], pts[i - 1][1]) + Vector2(pts[i][0], pts[i][1])) * 0.5
			var existing: Array = placed.get_or_add(street_name, [])
			var too_close := false
			for other in existing:
				if other.distance_to(mid) < LABEL_SPACING:
					too_close = true
					break
			if too_close:
				continue
			existing.append(mid)
			labels.append({"name": street_name, "pos": mid, "major": road.kind != "tertiary"})
