extends Node3D
## Puts it all together and handles you: walking around, getting in and out of vehicles,
## the waypoint, and the HUD. The world itself is built by World.

const VEHICLES := ["plane", "frontier", "sedan", "motorcycle"]
const ARRIVE_DISTANCE := 20.0
const AIRBORNE := 30.0  # meters above the ground where street names and arrivals stop counting
const ENTER_HEIGHT := 2.0  # allow slopes, but not vehicles on a different floor

## Every vehicle lives in the world the whole game and stays wherever you leave it.
var vehicles: Array[Vehicle] = []
var walker := Walker.new()
var driving: Vehicle = null  # the vehicle you're in, or null on foot
var camera := ChaseCamera.new()
var hud := Hud.new()
var world: World
var lighting := Lighting.new()
var coins := Coins.new()
var smashables: Smashables
var _street_name := ""
var _street_timer := 0.0
var _waypoint: Variant = null  # Vector2 in map space (world X/Z), or null
var _beacon := _make_beacon()


func _ready() -> void:
	Controls.setup()
	add_child(lighting)
	world = World.new()
	add_child(world)

	add_child(camera)
	add_child(hud)
	hud.setup_map(MapGeometry.new(world.map), walker)
	hud.waypoint_changed.connect(_on_waypoint_changed)
	hud.map_toggled.connect(_on_map_toggled)
	add_child(_beacon)

	# Start in the hangar with everything parked in its bay.
	for vehicle_name in VEHICLES:
		var v := _make_vehicle(vehicle_name)
		add_child(v)
		v.global_transform = world.airport.spot(vehicle_name)
		v.reset_physics_interpolation()
		vehicles.append(v)
	hud.set_vehicles(vehicles)
	add_child(coins)
	smashables = Smashables.new(world.map.smashables, vehicles, coins)
	smashables.smashed.connect(_on_smashed)
	add_child(smashables)
	add_child(walker)
	_place_walker(world.airport.spot("player"))
	camera.set_target(walker)
	coins.player = walker
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var body := _controlled()
	var pos := body.global_position
	var altitude := pos.y - Ground.height(pos.x, pos.z)
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = 0.25
		var found := world.streets.nearest(pos)
		if found != "" or altitude > AIRBORNE:
			_street_name = found
	var waypoint_dist := -1.0
	if _waypoint != null:
		waypoint_dist = Vector2(pos.x, pos.z).distance_to(_waypoint)
		if waypoint_dist < ARRIVE_DISTANCE and altitude < AIRBORNE:
			hud.clear_waypoint()
			waypoint_dist = -1.0
	hud.update_player(body, _street_name, waypoint_dist, camera.first_person)
	hud.set_prompt(_prompt_text())


func _notification(what: int) -> void:
	# While you're driving, the walker is out of the tree and nothing else will free it.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(walker) and not walker.is_inside_tree():
		walker.free()


func _controlled() -> Node3D:
	return driving if driving else walker


func _prompt_text() -> String:
	if driving == null:
		var v := _nearest_vehicle()
		return "F  Get in the %s" % v.display_name if v else ""
	if not driving.can_exit():
		return ""
	return "F  Get out" if _exit_spot(driving) != null else "No room to get out here"


func _on_waypoint_changed(pos: Variant) -> void:
	_waypoint = pos
	_beacon.visible = pos != null
	if pos != null:
		_beacon.position = Vector3(pos.x, Ground.height(pos.x, pos.y) + _beacon.mesh.height * 0.5, pos.y)


func _on_smashed(kind: String, _pos: Vector3, vehicle: Vehicle) -> void:
	if vehicle == driving:
		camera.shake(0.35 if kind in ["hydrant", "mailbox"] else 0.18)


func _on_map_toggled(open: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


static func _make_beacon() -> MeshInstance3D:
	# Tall glowing pillar so you can spot the waypoint over the rooftops.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.5
	mesh.bottom_radius = 2.5
	mesh.height = 400.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.3, 0.6, 0.45)
	mesh.material = mat
	var beacon := MeshInstance3D.new()
	beacon.mesh = mesh
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	return beacon


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		if driving:
			_get_out()
		else:
			var v := _nearest_vehicle()
			if v:
				_get_in(v)
	elif event.is_action_pressed("reset_vehicle"):
		if driving:
			driving.unstick()
		else:
			_place_walker(world.airport.spot("player"))
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_ao"):
		lighting.toggle_ao()
	elif event.is_action_pressed("ui_cancel"):
		# First Esc lets go of the mouse; the next one quits.
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()


static func _make_vehicle(vehicle_name: String) -> Vehicle:
	match vehicle_name:
		"frontier": return Frontier.make()
		"sedan": return Sedan.make()
		"motorcycle": return Motorcycle.make()
		_: return Airplane.new()


## Closest vehicle you're standing close enough to get into, or null.
func _nearest_vehicle() -> Vehicle:
	var best: Vehicle = null
	var best_gap := 0.0
	var here := Vector2(walker.global_position.x, walker.global_position.z)
	for v in vehicles:
		if absf(walker.global_position.y - v.global_position.y) > ENTER_HEIGHT:
			continue
		var gap: float = here.distance_to(Vector2(v.global_position.x, v.global_position.z)) - v.enter_radius
		if gap < best_gap:
			best_gap = gap
			best = v
	return best


func _get_in(v: Vehicle) -> void:
	remove_child(walker)
	driving = v
	v.set_driving(true)
	v.play_door()
	camera.set_target(v, false)
	hud.set_player(v)
	coins.player = v


func _get_out() -> void:
	if not driving.can_exit():
		return
	var spot: Variant = _exit_spot(driving)
	if spot == null:
		return
	var v := driving
	v.play_door()
	driving = null
	v.set_driving(false)
	add_child(walker)
	_place_walker(Transform3D(Basis(Vector3.UP, v.global_rotation.y), spot))
	camera.set_target(walker, false)
	hud.set_player(walker)
	coins.player = walker


## Where to stand when getting out of v: its exit side, else the other side. null = boxed in.
func _exit_spot(v: Vehicle) -> Variant:
	var yaw_only := Transform3D(Basis(Vector3.UP, v.global_rotation.y), v.global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = walker.shape
	query.exclude = [v.get_rid()]
	query.collision_mask = 1  # flying debris doesn't block the door
	for side in [1.0, -1.0]:
		var local: Vector3 = v.exit_offset * Vector3(side, 1, 1)
		var p := yaw_only * local
		p.y = maxf(p.y, Ground.height(p.x, p.z)) + 0.05
		query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return p
	return null


func _place_walker(xf: Transform3D) -> void:
	walker.global_transform = xf
	walker.stop()
	walker.reset_physics_interpolation()
