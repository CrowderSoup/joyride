class_name SmashProps
extends RefCounted
## What you can smash: how much it's worth, how it hits, and its low-poly model. Models
## face -Z (the street), sit on the ground at the origin, and are one vertex-colored
## surface so they can go in MultiMeshes.

## coins: dropped when smashed. size: rough bounding box (hits and debris collision).
## mass: how it flies. slow: fraction of your speed it costs to plow through it.
## sound: which crash to play. tints: per-instance color variety (multiplies the model).
const KINDS := {
	"hydrant": {"coins": 5, "size": Vector3(0.5, 0.85, 0.5), "mass": 60.0, "slow": 0.2, "sound": "metal", "tints": [Color.WHITE]},
	"cone": {"coins": 1, "size": Vector3(0.4, 0.7, 0.4), "mass": 2.0, "slow": 0.0, "sound": "plastic", "tints": [Color.WHITE]},
	"trash_can": {"coins": 2, "size": Vector3(0.6, 0.95, 0.6), "mass": 12.0, "slow": 0.04, "sound": "plastic", "tints": [Color.WHITE]},
	"bin": {"coins": 2, "size": Vector3(0.6, 1.05, 0.7), "mass": 8.0, "slow": 0.03, "sound": "plastic",
		"tints": [Color(0.3, 0.55, 0.3), Color(0.25, 0.4, 0.75), Color(0.35, 0.35, 0.37)]},
	"news_box": {"coins": 3, "size": Vector3(0.5, 1.1, 0.45), "mass": 20.0, "slow": 0.06, "sound": "metal",
		"tints": [Color(0.8, 0.15, 0.12), Color(0.2, 0.35, 0.75), Color(0.95, 0.8, 0.2), Color(0.9, 0.9, 0.88)]},
	"mailbox": {"coins": 4, "size": Vector3(0.55, 1.25, 0.55), "mass": 40.0, "slow": 0.1, "sound": "metal", "tints": [Color.WHITE]},
	"bench": {"coins": 3, "size": Vector3(1.8, 0.95, 0.6), "mass": 30.0, "slow": 0.08, "sound": "wood", "tints": [Color.WHITE]},
}

static var _meshes := {}


static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		var buf := MeshBuffer.new()
		match kind:
			"hydrant": _hydrant(buf)
			"cone": _cone(buf)
			"trash_can": _trash_can(buf)
			"bin": _bin(buf)
			"news_box": _news_box(buf)
			"mailbox": _mailbox(buf)
			"bench": _bench(buf)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.7
		_meshes[kind] = buf.to_mesh(mat)
	return _meshes[kind]


static func _hydrant(buf: MeshBuffer) -> void:
	var red := Color(0.78, 0.12, 0.08)
	var cap := Color(0.75, 0.75, 0.72)
	_frustum(buf, Vector3.ZERO, 0.2, 0.2, 0.08, 8, red.darkened(0.2))
	_frustum(buf, Vector3(0, 0.08, 0), 0.15, 0.14, 0.52, 8, red)
	_frustum(buf, Vector3(0, 0.6, 0), 0.17, 0.12, 0.12, 8, cap)
	_frustum(buf, Vector3(0, 0.72, 0), 0.05, 0.04, 0.08, 6, cap)
	for side in [-1.0, 1.0]:
		_box(buf, Vector3(side * 0.19, 0.42, 0), Vector3(0.1, 0.1, 0.1), cap)
	_box(buf, Vector3(0, 0.36, -0.18), Vector3(0.13, 0.13, 0.1), cap)


static func _cone(buf: MeshBuffer) -> void:
	var orange := Color(1.0, 0.42, 0.05)
	_box(buf, Vector3(0, 0.015, 0), Vector3(0.4, 0.03, 0.4), Color(0.1, 0.1, 0.1))
	_frustum(buf, Vector3(0, 0.03, 0), 0.15, 0.1, 0.26, 10, orange)
	_frustum(buf, Vector3(0, 0.29, 0), 0.1, 0.075, 0.12, 10, Color(0.95, 0.95, 0.92))
	_frustum(buf, Vector3(0, 0.41, 0), 0.075, 0.025, 0.29, 10, orange)


static func _trash_can(buf: MeshBuffer) -> void:
	var green := Color(0.16, 0.3, 0.2)
	_frustum(buf, Vector3.ZERO, 0.26, 0.29, 0.85, 10, green)
	_frustum(buf, Vector3(0, 0.85, 0), 0.31, 0.2, 0.1, 10, green.darkened(0.3))
	_box(buf, Vector3(0, 0.55, -0.285), Vector3(0.28, 0.12, 0.04), Color(0.9, 0.9, 0.85))


static func _bin(buf: MeshBuffer) -> void:
	# Neutral gray body so the instance tint makes it green, blue or black.
	var body := Color(0.85, 0.85, 0.85)
	_box(buf, Vector3(0, 0.5, 0), Vector3(0.55, 0.9, 0.65), body)
	_box(buf, Vector3(0, 0.97, 0.02), Vector3(0.6, 0.06, 0.72), body * 0.8)
	for side in [-1.0, 1.0]:
		_box(buf, Vector3(side * 0.22, 0.1, 0.3), Vector3(0.06, 0.2, 0.2), Color(0.15, 0.15, 0.15))


static func _news_box(buf: MeshBuffer) -> void:
	var body := Color(0.9, 0.9, 0.9)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(buf, Vector3(sx * 0.18, 0.15, sz * 0.15), Vector3(0.04, 0.3, 0.04), Color(0.2, 0.2, 0.2))
	_box(buf, Vector3(0, 0.7, 0), Vector3(0.48, 0.8, 0.42), body)
	_box(buf, Vector3(0, 0.82, -0.215), Vector3(0.36, 0.3, 0.02), Color(0.12, 0.14, 0.18))
	_box(buf, Vector3(0, 1.12, 0), Vector3(0.5, 0.04, 0.44), body * 0.7)


static func _mailbox(buf: MeshBuffer) -> void:
	var blue := Color(0.1, 0.2, 0.55)
	for sx in [-1.0, 1.0]:
		_box(buf, Vector3(sx * 0.2, 0.15, 0), Vector3(0.06, 0.3, 0.45), blue.darkened(0.3))
	_box(buf, Vector3(0, 0.7, 0), Vector3(0.52, 0.8, 0.5), blue)
	# Rounded top: a squat lid stepped in at the sides.
	_box(buf, Vector3(0, 1.14, 0), Vector3(0.44, 0.08, 0.5), blue)
	_box(buf, Vector3(0, 1.2, 0), Vector3(0.3, 0.05, 0.5), blue)
	_box(buf, Vector3(0, 0.95, -0.255), Vector3(0.36, 0.05, 0.02), Color(0.1, 0.1, 0.12))
	_box(buf, Vector3(0, 0.62, -0.255), Vector3(0.3, 0.16, 0.02), Color(0.9, 0.9, 0.9))


static func _bench(buf: MeshBuffer) -> void:
	var wood := Color(0.55, 0.36, 0.2)
	var iron := Color(0.12, 0.13, 0.14)
	for sx in [-0.75, 0.75]:
		_box(buf, Vector3(sx, 0.22, 0), Vector3(0.06, 0.44, 0.5), iron)
		_box(buf, Vector3(sx, 0.65, 0.22), Vector3(0.06, 0.45, 0.06), iron)
	for k in 3:
		_box(buf, Vector3(0, 0.46, -0.15 + k * 0.15), Vector3(1.8, 0.04, 0.12), wood)
	for k in 2:
		_box(buf, Vector3(0, 0.62 + k * 0.16, 0.24), Vector3(1.8, 0.1, 0.04), wood)


static func _box(buf: MeshBuffer, c: Vector3, size: Vector3, col: Color) -> void:
	CityBuilder._add_box(buf, c, size, col, Vector2.ZERO)
	# _add_box skips the bottom (buildings sit on the ground); flying debris shows it.
	var e := size * 0.5
	buf.add_quad(c + Vector3(-e.x, -e.y, -e.z), c + Vector3(e.x, -e.y, -e.z), c + Vector3(e.x, -e.y, e.z),
		c + Vector3(-e.x, -e.y, e.z), Vector3.DOWN, col * 0.7)


## Tapered n-sided prism with a lid, base at `base`.
static func _frustum(buf: MeshBuffer, base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	var top := base + Vector3.UP * h
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var mid := (d0 + d1).normalized()
		var n := (mid * h + Vector3.UP * (r0 - r1)).normalized()
		buf.add_quad(base + d0 * r0, base + d1 * r0, top + d1 * r1, top + d0 * r1, n, col * lerpf(0.8, 1.0, mid.z * 0.5 + 0.5))
		buf.add_tri(top, top + d0 * r1, top + d1 * r1, Vector3.UP, col)
		buf.add_tri(base, base + d1 * r0, base + d0 * r0, Vector3.DOWN, col * 0.7)
