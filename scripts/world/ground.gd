class_name Ground
extends RefCounted
## The shape of the land: real Salt Lake Valley elevations (see tools/fetch_elevation.py),
## squeezed horizontally like the city so every street sits over its real address. Heights
## are real meters relative to Temple Square. Everything that touches the ground asks here.
##
## Two grids: a fine one under the city (near) and a coarse one out to the mountains (far).
## Both are drawn and collided as triangles split along the same diagonal, and height()
## interpolates the same way, so things placed at height() sit exactly on the collision
## surface. Near's edges lie on far's grid lines and its outer rim fades into far's surface,
## so the two meshes meet without a seam.

const LAKE_LEVEL := -39.5   # the fetch tool clamps the Great Salt Lake bed to its surface
const RIM := 400.0          # near data fades into the far surface over this much of its edge

static var _near: Grid
static var _far: Grid


## A regular grid of heights. Cell (ix, iz) splits along its p00-p11 diagonal.
class Grid:
	var x0: float
	var z0: float
	var step: float
	var nx: int
	var nz: int
	var h: PackedFloat32Array

	static func from_file(path: String) -> Grid:
		var data := FileAccess.get_file_as_bytes(path).to_float32_array()
		assert(data.size() > 5, "Missing elevation data %s - run tools/fetch_elevation.py" % path)
		var g := Grid.new()
		g.x0 = data[0]
		g.z0 = data[1]
		g.step = data[2]
		g.nx = int(data[3])
		g.nz = int(data[4])
		g.h = data.slice(5)
		return g

	func x_at(ix: int) -> float:
		return x0 + ix * step

	func z_at(iz: int) -> float:
		return z0 + iz * step

	func at(ix: int, iz: int) -> float:
		return h[iz * nx + ix]

	func contains(x: float, z: float) -> bool:
		return x >= x0 and z >= z0 and x <= x0 + (nx - 1) * step and z <= z0 + (nz - 1) * step

	func bounds() -> Rect2:
		return Rect2(x0, z0, (nx - 1) * step, (nz - 1) * step)

	## Piecewise-linear over the triangles, clamped to the grid.
	func sample(x: float, z: float) -> float:
		var fx := clampf((x - x0) / step, 0.0, nx - 1.001)
		var fz := clampf((z - z0) / step, 0.0, nz - 1.001)
		var ix := int(fx)
		var iz := int(fz)
		fx -= ix
		fz -= iz
		var i := iz * nx + ix
		var h00 := h[i]
		var h11 := h[i + nx + 1]
		if fx >= fz:
			var h10 := h[i + 1]
			return h00 + fx * (h10 - h00) + fz * (h11 - h10)
		var h01 := h[i + nx]
		return h00 + fz * (h01 - h00) + fx * (h11 - h01)


static func load_data() -> void:
	_far = Grid.from_file("res://data/elevation_far.f32")
	_near = Grid.from_file("res://data/elevation_near.f32")
	# Fade near's rim into the far surface so the edges match exactly.
	var b := _near.bounds()
	for iz in _near.nz:
		for ix in _near.nx:
			var x := _near.x_at(ix)
			var z := _near.z_at(iz)
			var edge := minf(minf(x - b.position.x, b.end.x - x), minf(z - b.position.y, b.end.y - z))
			var w := smoothstep(0.0, RIM, edge)
			var i := iz * _near.nx + ix
			_near.h[i] = lerpf(_far.sample(x, z), _near.h[i], w)


static func near() -> Grid:
	return _near


static func far() -> Grid:
	return _far


## Ground height at world (x, z).
static func height(x: float, z: float) -> float:
	return _near.sample(x, z) if _near.contains(x, z) else _far.sample(x, z)


static func at(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, height(p.x, p.y) + lift, p.y)


static func normal(x: float, z: float) -> Vector3:
	const E := 2.0
	return Vector3(height(x - E, z) - height(x + E, z), 2.0 * E, height(x, z - E) - height(x, z + E)).normalized()


## Levels a pad for something that needs flat ground (a runway, a landmark on a hill):
## fully flat inside r, easing back to the land over margin meters around it. Call before
## anything is built. Returns the pad's height (the average ground inside r).
static func flatten(r: Rect2, margin: float) -> float:
	var total := 0.0
	var count := 0
	var z := r.position.y
	while z <= r.end.y:
		var x := r.position.x
		while x <= r.end.x:
			total += height(x, z)
			count += 1
			x += _near.step
		z += _near.step
	var pad := total / maxi(count, 1)
	var outer := r.grow(margin)
	var lo := Vector2i(maxi(0, floori((outer.position.x - _near.x0) / _near.step)), maxi(0, floori((outer.position.y - _near.z0) / _near.step)))
	var hi := Vector2i(mini(_near.nx - 1, ceili((outer.end.x - _near.x0) / _near.step)), mini(_near.nz - 1, ceili((outer.end.y - _near.z0) / _near.step)))
	for iz in range(lo.y, hi.y + 1):
		for ix in range(lo.x, hi.x + 1):
			var p := Vector2(_near.x_at(ix), _near.z_at(iz))
			var d := Vector2(maxf(0.0, maxf(r.position.x - p.x, p.x - r.end.x)), maxf(0.0, maxf(r.position.y - p.y, p.y - r.end.y))).length()
			var w := 1.0 - smoothstep(0.0, margin, d)
			var i := iz * _near.nx + ix
			_near.h[i] = lerpf(_near.h[i], pad, w)
	return pad
