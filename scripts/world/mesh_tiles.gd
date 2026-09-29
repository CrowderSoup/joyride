class_name MeshTiles
extends RefCounted
## A grid of MeshBuffers. Splitting big static geometry into tiles lets Godot frustum-cull
## (and shadow-cull) the parts you can't see, instead of drawing the whole city every frame.

const TILE := 500.0

var _tiles := {}


func at(pos: Vector3) -> MeshBuffer:
	var key := Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))
	var buf: MeshBuffer = _tiles.get(key)
	if buf == null:
		buf = MeshBuffer.new()
		_tiles[key] = buf
	return buf


## One MeshInstance3D per tile under a StaticBody3D (with trimesh collision if asked).
func build(node_name: String, material: Material, cast_shadows: bool, with_collision: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	for key in _tiles:
		var buf: MeshBuffer = _tiles[key]
		if buf.verts.is_empty():
			continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = buf.to_mesh(material)
		if not cast_shadows:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
		if with_collision:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(buf.verts)
			shape.backface_collision = true
			var col := CollisionShape3D.new()
			col.shape = shape
			body.add_child(col)
	return body
