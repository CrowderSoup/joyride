class_name Terrain
extends RefCounted
## Low-poly mountains around the valley: the Wasatch east of downtown, the foothills
## behind the Capitol to the north, and the Oquirrhs out west. Flat-shaded on purpose.
## Pulled in closer than real life so they frame the (also compressed) city.

const EXTENT := 28000.0
const STEP := 300.0

const FOOTHILL_COLOR := Color(0.34, 0.3, 0.2)
const SCRUB_COLOR := Color(0.2, 0.26, 0.15)
const ROCK_COLOR := Color(0.4, 0.39, 0.41)
const SNOW_COLOR := Color(0.93, 0.95, 0.98)


static func build() -> StaticBody3D:
	var noise := FastNoiseLite.new()
	noise.seed = 1896  # statehood
	noise.frequency = 1.0 / 5000.0
	noise.fractal_octaves = 4
	var detail := FastNoiseLite.new()
	detail.seed = 7
	detail.frequency = 1.0 / 900.0

	var n := int(EXTENT * 2.0 / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			var x := -EXTENT + ix * STEP
			var z := -EXTENT + iz * STEP
			heights[iz * n + ix] = height_at(x, z, noise, detail)

	var buf := MeshBuffer.new()
	for iz in n - 1:
		for ix in n - 1:
			var h00 := heights[iz * n + ix]
			var h10 := heights[iz * n + ix + 1]
			var h01 := heights[(iz + 1) * n + ix]
			var h11 := heights[(iz + 1) * n + ix + 1]
			if maxf(maxf(h00, h10), maxf(h01, h11)) < 3.0:
				continue
			var x0 := -EXTENT + ix * STEP
			var z0 := -EXTENT + iz * STEP
			var p00 := Vector3(x0, h00 - 2.0, z0)
			var p10 := Vector3(x0 + STEP, h10 - 2.0, z0)
			var p01 := Vector3(x0, h01 - 2.0, z0 + STEP)
			var p11 := Vector3(x0 + STEP, h11 - 2.0, z0 + STEP)
			_add_face(buf, p00, p10, p11, detail)
			_add_face(buf, p00, p11, p01, detail)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var body := StaticBody3D.new()
	body.name = "Mountains"
	var mesh := MeshInstance3D.new()
	mesh.mesh = buf.to_mesh(mat)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(buf.verts)
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	return body


static func height_at(x: float, z: float, noise: FastNoiseLite, detail: FastNoiseLite) -> float:
	var ridged := 1.0 - absf(noise.get_noise_2d(x, z))
	var bumps := detail.get_noise_2d(x, z)
	# Wasatch: rises fast a couple km east of downtown, big and jagged.
	var wasatch := smoothstep(3000.0, 9000.0, x) * (1300.0 + 900.0 * ridged + 150.0 * bumps)
	# Foothills behind the Capitol, fading out to the west so the runway's approach is clear.
	var north := smoothstep(-1500.0, -6000.0, z) * smoothstep(-1500.0, 500.0, x) * (350.0 + 450.0 * ridged + 60.0 * bumps)
	# Oquirrhs: far west, south of the lake.
	var oquirrh := smoothstep(-15000.0, -21000.0, x) * smoothstep(-12000.0, -3000.0, z) * (1000.0 + 500.0 * ridged + 100.0 * bumps)
	return maxf(wasatch, maxf(north, oquirrh))


static func _add_face(buf: MeshBuffer, a: Vector3, b: Vector3, c: Vector3, detail: FastNoiseLite) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var mid := (a + b + c) / 3.0
	var h := mid.y + detail.get_noise_2d(mid.x * 3.0, mid.z * 3.0) * 120.0
	var col := FOOTHILL_COLOR
	if h > 1750.0 and n.y > 0.55:
		col = SNOW_COLOR
	elif n.y < 0.72 or h > 1500.0:
		col = ROCK_COLOR
	elif h > 450.0:
		col = SCRUB_COLOR
	col = col.lerp(col.darkened(0.15), (detail.get_noise_2d(mid.x, mid.z) + 1.0) * 0.5)
	buf.add_tri(a, b, c, n, col)
