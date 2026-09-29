class_name MeshBuffer
extends RefCounted
## Accumulates flat-shaded, vertex-colored triangles and turns them into one ArrayMesh.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()


## uv_a/b/c are per-vertex UVs; uv2 is a per-triangle value (shaders use it as flags).
func add_tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, uv2 := Vector2.ZERO) -> void:
	# Godot treats clockwise triangles as front faces; flip so the face points along n.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tuv := uv_b
		uv_b = uv_c
		uv_c = tuv
	verts.append(a)
	verts.append(b)
	verts.append(c)
	uvs.append(uv_a)
	uvs.append(uv_b)
	uvs.append(uv_c)
	for i in 3:
		normals.append(n)
		colors.append(col)
		uv2s.append(uv2)


func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, uv_d := Vector2.ZERO, uv2 := Vector2.ZERO) -> void:
	add_tri(a, b, c, n, col, uv_a, uv_b, uv_c, uv2)
	add_tri(a, c, d, n, col, uv_a, uv_c, uv_d, uv2)


func to_mesh(material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
