class_name Coins
extends Node3D
## Coins that pop out of smashed stuff. They spray out, bounce, and once they've had a
## moment in the air they home in on you - fast enough to catch a car. Unclaimed ones
## blink out after a while.

const GRAVITY := 22.0
const MAGNET_DELAY := 0.45   # seconds of flying free before they come to you
const MAGNET_RANGE := 16.0
const COLLECT_DISTANCE := 1.6
const LIFETIME := 25.0
const STREAK_WINDOW := 1.2   # pickups this close together climb in pitch

var player: Node3D           # whoever's collecting: the walker or the vehicle you're in

var _mesh := _coin_mesh()
var _coins: Array = []       # [node, velocity, age]
var _ding := AudioStreamPlayer.new()
var _streak := 0
var _since_pickup := 99.0


func _init() -> void:
	name = "Coins"
	_ding.stream = Sfx.coin()
	_ding.volume_db = -8.0
	_ding.max_polyphony = 6
	add_child(_ding)


## Throw out count coins from pos, carrying some of the smasher's momentum.
func spawn(pos: Vector3, count: int, carry: Vector3) -> void:
	for i in count:
		var node := MeshInstance3D.new()
		node.mesh = _mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = pos
		var out := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.5, 4.0)
		_coins.append([node, carry * 0.6 + out + Vector3.UP * randf_range(5.0, 8.0), 0.0])


func _process(delta: float) -> void:
	_since_pickup += delta
	if _since_pickup > STREAK_WINDOW:
		_streak = 0
	var target := Vector3.INF
	var chase := 0.0
	if player and player.is_inside_tree():
		target = player.global_position + Vector3.UP * 1.0
		chase = absf(player.get_speed())
	for i in range(_coins.size() - 1, -1, -1):
		var c: Array = _coins[i]
		var node: MeshInstance3D = c[0]
		var vel: Vector3 = c[1]
		c[2] += delta
		var age: float = c[2]
		var pos := node.global_position
		var dist := pos.distance_to(target)
		if dist < COLLECT_DISTANCE:
			_collect(i)
			continue
		if age > MAGNET_DELAY and dist < MAGNET_RANGE:
			var speed := maxf(18.0, chase + 14.0)
			vel = vel.lerp((target - pos) / dist * speed, 1.0 - exp(-8.0 * delta))
			pos += vel * delta
		else:
			vel.y -= GRAVITY * delta
			pos += vel * delta
			var floor_y := Ground.height(pos.x, pos.z) + 0.35
			if pos.y < floor_y:
				pos.y = floor_y
				vel = Vector3(vel.x * 0.6, absf(vel.y) * 0.4, vel.z * 0.6)
		c[1] = vel
		node.global_position = pos
		node.rotate_y(7.0 * delta)
		if age > LIFETIME - 3.0:
			node.visible = fmod(age, 0.25) < 0.15
		if age > LIFETIME:
			node.queue_free()
			_coins.remove_at(i)


func _collect(i: int) -> void:
	_coins[i][0].queue_free()
	_coins.remove_at(i)
	_since_pickup = 0.0
	_streak += 1
	_ding.pitch_scale = 1.0 + minf(_streak - 1, 12) * 0.045
	_ding.play()
	Game.add_coins(1)


static func _coin_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.07
	mesh.radial_segments = 16
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.15)
	mat.metallic = 0.7
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.6, 0.1)
	mat.emission_energy_multiplier = 0.4
	mesh.material = mat
	# Stand it on edge so the spin shows the face.
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.RIGHT, PI / 2)
	for v in verts.size():
		verts[v] = turn * verts[v]
		normals[v] = turn * normals[v]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mat)
	return out
