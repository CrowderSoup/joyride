extends SceneTree
## Run: godot --headless --path . --script tests/run.gd

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	await _test_terrain()
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	paused = true
	_test_entry(scene)
	_test_respawn(scene)
	_test_camera(scene)
	_test_motorcycle_lean(scene)
	_test_hud(scene)
	print("Joyride regression checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)


func _test_terrain() -> void:
	var grid := Ground.Grid.new()
	grid.x0 = 0.0
	grid.z0 = 0.0
	grid.step = 20.0
	grid.nx = 2
	grid.nz = 2
	grid.h = PackedFloat32Array([0, 0, 0, 10])
	grid.heightmap_diagonal = true
	Ground._near = grid
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain._build_near(FastNoiseLite.new())
	world.add_child(terrain)
	await physics_frame
	await physics_frame
	for point in [Vector2(5, 5), Vector2(15, 15), Vector2(5, 15), Vector2(20, 20)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 20, point.y), Vector3(point.x, -20, point.y), 1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "Terrain ray missed at %s" % point)
		if not hit.is_empty():
			_check(absf(hit.position.y - Ground.height(point.x, point.y)) < 0.001, "Height lookup differs from near collision at %s" % point)
	# The drawn near mesh must agree too, accounting for its intentional sink.
	var rendered := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(terrain.get_child(0).mesh.get_faces())
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	rendered.add_child(col)
	rendered.collision_layer = 4
	rendered.position.y = -Terrain.SINK
	world.add_child(rendered)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(15, 20, 15), Vector3(15, -20, 15), 4)
	var mesh_hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not mesh_hit.is_empty() and absf(mesh_hit.position.y + Terrain.SINK - grid.sample(15, 15)) < 0.001, "Rendered terrain differs from heightmap collision")
	grid.heightmap_diagonal = false
	_check(is_equal_approx(grid.sample(5, 5), 2.5), "Far-grid diagonal changed")
	_check(is_equal_approx(grid.sample(20, 20), 10.0), "Grid boundary does not reach its final vertex")
	world.free()


func _test_entry(scene: Node3D) -> void:
	var car: Vehicle = scene.vehicles[2]
	var start: Vector3 = scene.walker.global_position
	scene.walker.global_position = car.global_position + Vector3(1.8, 0, 0)
	_check(scene._nearest_vehicle() == car, "Nearby vehicle cannot be entered")
	for height in [100.0, -100.0]:
		scene.walker.global_position = car.global_position + Vector3.UP * height
		_check(scene._nearest_vehicle() == null, "Vehicle can be entered across floors")
	scene.walker.global_position = start


func _test_respawn(scene: Node3D) -> void:
	var props = scene.smashables
	var car: Vehicle = scene.vehicles[2]
	var car_start := car.global_transform
	var walker_start: Transform3D = scene.walker.global_transform
	var p: Vector3 = props._xform[0].origin
	props._alive[0] = 0
	props._broken.append(0)
	props._broken_at[0] = 0.0
	props._time = props.RESPAWN_AFTER + 1.0
	scene.walker.global_position = p + Vector3(500, 0, 0)
	car.global_position = p
	props._respawn()
	_check(props._alive[0] == 0, "Prop respawns inside a parked vehicle")
	car.global_position = p + Vector3(100, 0, 0)
	scene.walker.global_position = p + Vector3(100, 0, 0)
	props._respawn()
	_check(props._alive[0] == 0, "Prop respawns while player is nearby")
	scene.walker.global_position = p + Vector3(500, 0, 0)
	props._respawn()
	_check(props._alive[0] == 1, "Abandoned vehicle blocks distant prop respawn")
	car.global_transform = car_start
	scene.walker.global_transform = walker_start
	car.reset_physics_interpolation()
	scene.walker.reset_physics_interpolation()


func _test_camera(scene: Node3D) -> void:
	var camera: ChaseCamera = scene.camera
	var toggle := InputEventAction.new()
	toggle.action = "toggle_camera"
	toggle.pressed = true
	camera._unhandled_input(toggle)
	_check(not camera.first_person, "On-foot camera toggle changes vehicle preference")
	var bindings := InputMap.action_get_events("toggle_camera")
	_check(bindings.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_V), "Missing V camera binding")
	_check(bindings.any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_RIGHT_STICK), "Missing gamepad camera binding")
	for vehicle: Vehicle in scene.vehicles:
		scene._get_in(vehicle)
		camera._unhandled_input(toggle)
		_check(camera.first_person, "Vehicle toggle did not enter first person")
		camera._process(0.016)
		var mount := vehicle.first_person_transform()
		_check(camera.global_position.distance_to(mount.origin) < 0.001, "First person isn't at the driver's eye in %s" % vehicle.display_name)
		_check(camera.global_basis.z.dot(mount.basis.z) > 0.999, "First person doesn't face forward in %s" % vehicle.display_name)
		_check(not camera._hidden_geometry.is_empty(), "Own vehicle geometry wasn't hidden")
		for mesh in camera._hidden_geometry:
			_check((mesh.layers & camera.cull_mask) == 0, "Own vehicle obstructs first-person view")
		# The headless display cannot capture a mouse; exercise the stick actions instead.
		Input.action_press("look_right")
		Input.action_press("look_down")
		camera._process(0.05)
		Input.action_release("look_right")
		Input.action_release("look_down")
		_check(camera.global_basis.z.dot(mount.basis.z) < 0.999, "First-person stick look did not turn")
		camera._unhandled_input(toggle)
		_check(not camera.first_person and camera._hidden_geometry.is_empty(), "Third person did not restore vehicle geometry")
		_check(camera.global_position.distance_to(mount.origin) > 2.0, "Third person remains inside the vehicle")
		camera._unhandled_input(toggle)
		scene._get_out()
		_check(scene.driving == null and camera.target == scene.walker, "Getting out did not return to on-foot camera")
		_check(camera._hidden_geometry.is_empty(), "Getting out left the vehicle hidden")
		camera._unhandled_input(toggle)
		_check(camera.first_person, "On-foot toggle changed saved view preference")
		scene._get_in(vehicle)
		_check(camera.global_position.distance_to(vehicle.first_person_transform().origin) < 0.001, "Re-entering lost first-person preference")
		camera._unhandled_input(toggle)
		scene._get_out()


func _test_hud(scene: Node3D) -> void:
	var hud = scene.hud
	var car: Vehicle = scene.vehicles[2]
	var car_start := car.global_transform
	var plane: Airplane = scene.vehicles[0]
	var plane_start := plane.global_transform
	var plane_speed := plane._speed
	var plane_throttle := plane.throttle
	var car_speed: float = car.get("_speed")
	car.rotation = Vector3.ZERO
	_check(is_equal_approx(HudTelemetry.read(car).heading, 0.0), "North heading is incorrect")
	car.rotation.y = -PI * 0.5
	_check(is_equal_approx(HudTelemetry.read(car).heading, 90.0), "East heading is incorrect")
	car.set("_speed", -4.0)
	hud.set_player(car)
	hud.update_player(car, "Airport")
	_check(hud._dashboard.visible and hud._dashboard.telemetry.speed < 0 and not hud._horizon.visible, "Ground vehicle reverse instruments are incorrect")
	_check(is_equal_approx(CompassRibbon.bearing(Vector2.ZERO, Vector2(0, -10)), 0.0), "North waypoint bearing is incorrect")
	_check(is_equal_approx(CompassRibbon.bearing(Vector2.ZERO, Vector2(10, 0)), 90.0), "East waypoint bearing is incorrect")
	plane.global_position.y = Ground.height(plane.global_position.x, plane.global_position.z) + 100.0
	plane.global_basis = Basis.from_euler(Vector3(0.3, 0, 0.4))
	plane._speed = 45.0
	plane.throttle = 0.75
	var data := HudTelemetry.read(plane)
	_check(absf(data.agl - 328.1) < 0.01, "Above-ground altitude conversion is incorrect")
	_check(data.airborne and data.pitch > 0 and data.roll > 0, "Flight attitude telemetry is incorrect")
	_check(absf(data.speed - 100.665) < 0.01 and data.throttle == 0.75, "Flight speed/throttle telemetry is incorrect")
	hud.set_player(plane)
	hud.update_player(plane, "Airport")
	_check(hud._dashboard.visible and not hud._horizon.visible, "Chase-view horizon obscures the plane")
	hud.update_player(plane, "Airport", -1.0, true)
	_check(hud._dashboard.visible and hud._horizon.visible and hud._horizon.airborne, "Flight instruments are missing")
	var flying_position := plane.global_position
	plane.global_position.y = Ground.height(plane.global_position.x, plane.global_position.z)
	hud.update_player(plane, "Airport", -1.0, true)
	_check(hud._horizon.visible and not hud._horizon.airborne and hud._horizon.takeoff, "Grounded plane does not show its cockpit takeoff cue")
	plane.global_position = flying_position
	hud.update_player(plane, "Airport")
	hud._minimap._process(5.0)
	var flight_zoom: float = hud._minimap._zoom
	hud.set_player(scene.walker)
	hud.update_player(scene.walker, "Airport")
	_check(not hud._dashboard.visible and not hud._horizon.visible, "Vehicle instruments remain on foot")
	hud._minimap._process(5.0)
	_check(hud._minimap._zoom > flight_zoom, "Flight minimap does not zoom out")
	var marker: Vector2 = hud._minimap.world_to_screen(Vector2(scene.walker.global_position.x, scene.walker.global_position.z))
	_check(marker.distance_to(hud._minimap.size * Vector2(0.5, 0.65)) < 0.01, "Minimap does not leave space ahead of the player")
	var waypoint := Vector2(scene.walker.global_position.x + 250, scene.walker.global_position.z)
	hud._set_waypoint(waypoint)
	hud.update_player(scene.walker, "Airport", 250)
	_check(hud._compass.waypoint_bearing != null and hud._waypoint_label.text != "", "Waypoint navigation cues are missing")
	hud.clear_waypoint()
	hud.update_player(scene.walker, "Airport")
	_check(hud._compass.waypoint_bearing == null and hud._waypoint_label.text == "", "Cleared waypoint leaves navigation cues behind")
	var map_toggle := InputEventAction.new()
	map_toggle.action = "toggle_map"
	map_toggle.pressed = true
	hud._unhandled_input(map_toggle)
	_check(not hud._overlay.visible and hud._full_map.visible and paused, "Full map does not hide the HUD and pause")
	hud._unhandled_input(map_toggle)
	_check(hud._overlay.visible and not hud._full_map.visible and not paused, "Closing the full map does not restore the HUD")
	paused = true
	car.global_transform = car_start
	plane.global_transform = plane_start
	plane._speed = plane_speed
	plane.throttle = plane_throttle
	car.set("_speed", car_speed)


func _test_motorcycle_lean(scene: Node3D) -> void:
	var bike: GroundVehicle = scene.vehicles[3]
	var start := bike.global_transform
	bike.global_position.y += 10.0  # avoid the ground while checking local lean direction
	bike.global_basis = Basis.IDENTITY
	bike._speed = 15.0
	for steer in [1.0, -1.0]:
		bike._steer = steer
		bike._lean = 0.0
		bike._animate(0.1, 0.0, 0.0)
		# Positive steering turns left (-X); the bike and rider's up axes must lean left too.
		_check(bike.visual.basis.y.x * steer < 0.0, "Motorcycle leans out of its turn")
		_check(bike.rider.global_basis.y.x * steer < 0.0, "Rider leans out of the motorcycle's turn")
	bike._speed = 0.0
	bike._steer = 0.0
	for frame in 60:
		bike._animate(1.0 / 60.0, 0.0, 0.0)
	_check(absf(bike.visual.basis.y.x) < 0.001, "Motorcycle does not return upright at rest")
	bike.global_transform = start
	bike.stop()
