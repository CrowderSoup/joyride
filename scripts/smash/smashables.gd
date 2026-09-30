class_name Smashables
extends Node3D
## All the street furniture you can plow through. Intact props are just MultiMesh
## instances (thousands of them, no physics); every physics frame each moving vehicle
## checks the few props near its footprint. A hit hides the instance and throws a real
## rigid body copy of the prop, plus coins. Props quietly come back once you're long gone.

signal smashed(kind: String, pos: Vector3, vehicle: Vehicle)

const CELL := 16.0             # hit-test grid
const CHUNK := 400.0           # draw batches, so far ones get culled
const VIEW_RANGE := 700.0
const MIN_SPEED := 1.5         # m/s; slower than this you just nudge things
const RESPAWN_AFTER := 150.0   # seconds
const RESPAWN_DISTANCE := 150.0
const MAX_DEBRIS := 40
const DEBRIS_LIFE := 6.0
const DEBRIS_LAYER := 2        # debris gets knocked around by vehicles but doesn't slow them

var vehicles: Array[Vehicle] = []
var coins: Coins

var _kind := PackedStringArray()
var _xform: Array[Transform3D] = []
var _tint := PackedColorArray()
var _alive := PackedByteArray()
var _broken_at := PackedFloat32Array()
var _batch: Array[MultiMesh] = []
var _slot := PackedInt32Array()
var _cells := {}
var _broken: Array[int] = []
var _debris: Array = []        # [body, born]
var _time := 0.0
var _respawn_check := 0.0


## items: map.smashables ({kind, p, yaw}).
func _init(items: Array, p_vehicles: Array[Vehicle], p_coins: Coins) -> void:
	name = "Smashables"
	vehicles = p_vehicles
	coins = p_coins
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var groups := {}
	for item in items:
		var i := _kind.size()
		var kind: String = item.kind
		var p := Ground.at(Vector2(item.p[0], item.p[1]))
		var tints: Array = SmashProps.KINDS[kind].tints
		_kind.append(kind)
		_xform.append(Transform3D(Basis(Vector3.UP, item.yaw + rng.randf_range(-0.15, 0.15)), p))
		_tint.append(tints[rng.randi() % tints.size()])
		_alive.append(1)
		_broken_at.append(0.0)
		_cells.get_or_add(_cell(p), []).append(i)
		groups.get_or_add([kind, Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))], []).append(i)
	_batch.resize(_kind.size())
	_slot.resize(_kind.size())
	for key in groups:
		_build_batch(key[0], key[1], groups[key])


func count() -> int:
	return _kind.size()


func _build_batch(kind: String, chunk: Vector2i, members: Array) -> void:
	var center := Vector3((chunk.x + 0.5) * CHUNK, 0, (chunk.y + 0.5) * CHUNK)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = SmashProps.mesh(kind)
	mm.instance_count = members.size()
	for k in members.size():
		var i: int = members[k]
		mm.set_instance_transform(k, _xform[i].translated(-center))
		mm.set_instance_color(k, _tint[i])
		_batch[i] = mm
		_slot[i] = k
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.position = center
	inst.visibility_range_end = VIEW_RANGE
	inst.visibility_range_end_margin = 100.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(inst)


static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func _physics_process(delta: float) -> void:
	_time += delta
	for v in vehicles:
		if v.is_inside_tree() and absf(v.get_speed()) > MIN_SPEED:
			_check_hits(v)
	_expire_debris()
	_respawn_check -= delta
	if _respawn_check <= 0.0:
		_respawn_check = 2.0
		_respawn()


func _check_hits(v: Vehicle) -> void:
	var inv := v.global_transform.affine_inverse()
	var here := _cell(v.global_position)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for i in _cells.get(here + Vector2i(dx, dz), []):
				if not _alive[i]:
					continue
				var local := inv * _xform[i].origin
				var size: Vector3 = SmashProps.KINDS[_kind[i]].size
				var reach := maxf(size.x, size.z) * 0.5
				if absf(local.x) < v.footprint.x + reach and absf(local.z) < v.footprint.y + reach \
						and local.y > -1.0 and local.y < 3.0:
					_smash(i, v)


func _smash(i: int, v: Vehicle) -> void:
	var kind := _kind[i]
	var info: Dictionary = SmashProps.KINDS[kind]
	_alive[i] = 0
	_broken_at[i] = _time
	_broken.append(i)
	var hidden := _batch[i].get_instance_transform(_slot[i])
	_batch[i].set_instance_transform(_slot[i], Transform3D(Basis.from_scale(Vector3.ZERO), hidden.origin))

	var xf := _xform[i]
	var vel := v.get_real_velocity()
	var speed := vel.length()
	_throw_debris(i, info, vel, speed)
	if kind == "hydrant":
		_geyser(xf.origin)
	Sfx.play_at(self, Sfx.crash(info.sound), xf.origin + Vector3.UP * 0.5, -2.0, randf_range(0.9, 1.1))
	coins.spawn(xf.origin + Vector3.UP * 0.8, info.coins, vel)
	v.bump(info.slow)
	smashed.emit(kind, xf.origin, v)


## A real rigid-body copy of the prop, launched off the front of whatever hit it.
func _throw_debris(i: int, info: Dictionary, vel: Vector3, speed: float) -> void:
	var size: Vector3 = info.size
	var body := RigidBody3D.new()
	body.collision_layer = DEBRIS_LAYER
	body.collision_mask = 1 | DEBRIS_LAYER
	body.mass = info.mass
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = size.y * 0.5
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SmashProps.mesh(_kind[i])
	body.add_child(mesh)
	if _tint[i] != Color.WHITE:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.7
		mat.albedo_color = _tint[i]
		mesh.material_override = mat
	add_child(body)
	body.global_transform = _xform[i].translated(Vector3.UP * 0.05)
	# Light things fly; heavy ones mostly topple.
	var lift := clampf(40.0 / info.mass, 0.4, 3.0)
	var flat := Vector3(vel.x, 0, vel.z)
	body.linear_velocity = flat * lerpf(0.9, 0.5, clampf(info.mass / 60.0, 0.0, 1.0)) \
		+ Vector3.UP * (2.0 + speed * 0.12 * lift) \
		+ Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 1.5
	body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (3.0 + speed * 0.15)
	_debris.append([body, _time])
	while _debris.size() > MAX_DEBRIS:
		var oldest: RigidBody3D = _debris.pop_front()[0]
		oldest.queue_free()


func _expire_debris() -> void:
	while not _debris.is_empty() and _time - _debris[0][1] > DEBRIS_LIFE:
		var body: RigidBody3D = _debris.pop_front()[0]
		var tween := body.create_tween()
		tween.tween_property(body, "scale", Vector3.ONE * 0.01, 0.4)
		tween.tween_callback(body.queue_free)


## A busted hydrant sprays for a while.
func _geyser(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 1.6
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 7.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 13.0
	mat.gravity = Vector3(0, -12.0, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	p.process_material = mat
	var drop := SphereMesh.new()
	drop.radius = 0.1
	drop.height = 0.2
	drop.radial_segments = 6
	drop.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(0.75, 0.88, 1.0, 0.75)
	dmat.roughness = 0.1
	dmat.emission_enabled = true
	dmat.emission = Color(0.4, 0.5, 0.6)
	drop.material = dmat
	p.draw_pass_1 = drop
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 20, 12))
	add_child(p)
	p.global_position = pos + Vector3.UP * 0.2
	p.emitting = true
	var tween := p.create_tween()
	tween.tween_interval(10.0)
	tween.tween_callback(func() -> void: p.emitting = false)
	tween.tween_interval(2.0)
	tween.tween_callback(p.queue_free)


## Put things back once they've been gone a while and nobody's around to see it.
func _respawn() -> void:
	var watchers: Array[Vector3] = []
	if coins.player and coins.player.is_inside_tree():
		watchers.append(coins.player.global_position)
	for k in range(_broken.size() - 1, -1, -1):
		var i := _broken[k]
		if _time - _broken_at[i] < RESPAWN_AFTER:
			continue
		var p := _xform[i].origin
		if watchers.any(func(w: Vector3) -> bool: return w.distance_to(p) < RESPAWN_DISTANCE):
			continue
		# Unoccupied vehicles aren't observers. Only keep props out of their footprint.
		var occupied := false
		var size: Vector3 = SmashProps.KINDS[_kind[i]].size
		var reach := maxf(size.x, size.z) * 0.5 + 0.5
		for v in vehicles:
			if not v.is_inside_tree():
				continue
			var local := v.global_transform.affine_inverse() * p
			if absf(local.x) < v.footprint.x + reach and absf(local.z) < v.footprint.y + reach \
					and local.y > -1.0 and local.y < 3.0:
				occupied = true
				break
		if occupied:
			continue
		var center := Vector3((floori(p.x / CHUNK) + 0.5) * CHUNK, 0, (floori(p.z / CHUNK) + 0.5) * CHUNK)
		_batch[i].set_instance_transform(_slot[i], _xform[i].translated(-center))
		_alive[i] = 1
		_broken.remove_at(k)
