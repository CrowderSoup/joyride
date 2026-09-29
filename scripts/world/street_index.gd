class_name StreetIndex
extends RefCounted
## Spatial grid of named road segments, for "what street am I on?" lookups.

const CELL := 50.0

var _cells := {}


func _init(roads: Array) -> void:
	for road in roads:
		var street_name: String = road.name
		if street_name == "":
			continue
		var pts: Array = road.pts
		for i in range(1, pts.size()):
			var a := Vector2(pts[i - 1][0], pts[i - 1][1])
			var b := Vector2(pts[i][0], pts[i][1])
			var seg := [a, b, street_name]
			var lo := Vector2i(floori(minf(a.x, b.x) / CELL), floori(minf(a.y, b.y) / CELL))
			var hi := Vector2i(floori(maxf(a.x, b.x) / CELL), floori(maxf(a.y, b.y) / CELL))
			for cx in range(lo.x, hi.x + 1):
				for cy in range(lo.y, hi.y + 1):
					_cells.get_or_add(Vector2i(cx, cy), []).append(seg)


func nearest(pos: Vector3, max_dist := 25.0) -> String:
	var p := Vector2(pos.x, pos.z)
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := ""
	var best_dist := max_dist
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for seg in _cells.get(cell + Vector2i(dx, dy), []):
				var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1]))
				if d < best_dist:
					best_dist = d
					best = seg[2]
	return best
