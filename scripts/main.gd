extends Node3D

const VEHICLES := ["plane", "frontier", "sedan", "motorcycle"]
const ARRIVE_DISTANCE := 20.0

## Every vehicle lives in the world the whole game and stays wherever you leave it.
var vehicles: Array[Node3D] = []
var walker := Walker.new()
var driving: Node3D = null  # the vehicle you're in, or null on foot
var camera := ChaseCamera.new()
var hud := Hud.new()
var streets: StreetIndex
var airport: Airport
var _street_name := ""
var _street_timer := 0.0
var _waypoint: Variant = null  # Vector2 in map space (world X/Z), or null
var _beacon := _make_beacon()
var _env: Environment


func _ready() -> void:
	_setup_input()
	_setup_environment()

	var map := CityGen.generate()
	airport = Airport.new()
	airport.add_to_map(map)
	var intersections := CityBuilder.find_intersections(map.roads)
	add_child(CityBuilder.build(map, intersections))
	add_child(Scenery.build(map, intersections))
	add_child(Terrain.build())
	add_child(Landmarks.build())
	add_child(airport.build())
	streets = StreetIndex.new(map.roads + map.places)

	add_child(camera)
	add_child(hud)
	hud.setup_map(MapGeometry.new(map), walker)
	hud.waypoint_changed.connect(_on_waypoint_changed)
	add_child(_beacon)

	# Start in the hangar with everything parked in its bay.
	for vehicle_name in VEHICLES:
		var v := _make_vehicle(vehicle_name)
		add_child(v)
		v.global_transform = airport.spot(vehicle_name)
		v.reset_physics_interpolation()
		vehicles.append(v)
	hud.set_vehicles(vehicles)
	add_child(walker)
	_place_walker(airport.spot("player"))
	camera.set_target(walker)


func _process(delta: float) -> void:
	var body := _controlled()
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = 0.25
		var found := streets.nearest(body.global_position)
		if found != "" or body.global_position.y > 30.0:
			_street_name = found
	var waypoint_dist := -1.0
	if _waypoint != null:
		waypoint_dist = Vector2(body.global_position.x, body.global_position.z).distance_to(_waypoint)
		if waypoint_dist < ARRIVE_DISTANCE and body.global_position.y < 30.0:
			hud.clear_waypoint()
			waypoint_dist = -1.0
	hud.update(body.display_name, body.get_speed(), body.hud_extra(), _street_name, waypoint_dist, driving != null)
	hud.set_prompt(_prompt_text())


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
		_beacon.position = Vector3(pos.x, _beacon.mesh.height * 0.5, pos.y)


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
	if event.is_action_pressed("interact"):
		if driving:
			_get_out()
		else:
			var v := _nearest_vehicle()
			if v:
				_get_in(v)
	elif event.is_action_pressed("reset_vehicle"):
		if driving:
			_unstick(driving)
		else:
			_place_walker(airport.spot("player"))
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_ao"):
		_env.ssao_enabled = not _env.ssao_enabled
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


static func _make_vehicle(vehicle_name: String) -> Node3D:
	match vehicle_name:
		"frontier": return Frontier.make()
		"sedan": return GroundVehicle.make_sedan()
		"motorcycle": return GroundVehicle.make_motorcycle()
		_: return Airplane.new()


## Closest vehicle you're standing close enough to get into, or null.
func _nearest_vehicle() -> Node3D:
	var best: Node3D = null
	var best_gap := 0.0
	var here := Vector2(walker.global_position.x, walker.global_position.z)
	for v in vehicles:
		var gap: float = here.distance_to(Vector2(v.global_position.x, v.global_position.z)) - v.enter_radius
		if gap < best_gap:
			best_gap = gap
			best = v
	return best


func _get_in(v: Node3D) -> void:
	remove_child(walker)
	driving = v
	v.set_driving(true)
	camera.set_target(v, false)
	hud.set_player(v)


func _get_out() -> void:
	if not driving.can_exit():
		return
	var spot: Variant = _exit_spot(driving)
	if spot == null:
		return
	var v := driving
	driving = null
	v.set_driving(false)
	add_child(walker)
	_place_walker(Transform3D(Basis(Vector3.UP, v.global_rotation.y), spot))
	camera.set_target(walker, false)
	hud.set_player(walker)


## Where to stand when getting out of v: its exit side, else the other side. null = boxed in.
func _exit_spot(v: Node3D) -> Variant:
	var yaw_only := Transform3D(Basis(Vector3.UP, v.global_rotation.y), v.global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = walker.shape
	query.exclude = [v.get_rid()]
	for side in [1.0, -1.0]:
		var local: Vector3 = v.exit_offset * Vector3(side, 1, 1)
		var p := yaw_only * local
		p.y = maxf(p.y, 0.0) + 0.05
		query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return p
	return null


func _place_walker(xf: Transform3D) -> void:
	walker.global_transform = xf
	walker.stop()
	walker.reset_physics_interpolation()


## Flipped, wedged, or crashed: set it back on its wheels right where it is.
func _unstick(v: Node3D) -> void:
	var pos := v.global_position
	v.global_transform = Transform3D(Basis(Vector3.UP, v.global_rotation.y), Vector3(pos.x, 0.2 if v is GroundVehicle else 0.0, pos.z))
	v.stop()
	v.reset_physics_interpolation()


func _setup_environment() -> void:
	# Warm sun + cool ambient + haze = cheap depth. Stylized, not realistic.
	var horizon := Color(0.76, 0.8, 0.84)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.46, 0.78)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = Color(0.4, 0.42, 0.4)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.63, 0.8)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	env.fog_enabled = true
	env.fog_light_color = horizon
	env.fog_density = 0.00005
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.fog_sun_scatter = 0.15
	# Forward+ only: contact shadows in corners/under cars. Off by default - even the
	# cheapest mode costs ~6 ms/frame on the M1 at Retina res. F3 toggles it.
	env.ssao_enabled = false
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.5
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


func _setup_input() -> void:
	_action("accelerate", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("brake", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("steer_left", [KEY_A, KEY_LEFT], [_joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("steer_right", [KEY_D, KEY_RIGHT], [_joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("handbrake", [KEY_SPACE], [_joy_button(JOY_BUTTON_A)])
	_action("pitch_up", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("pitch_down", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("yaw_left", [KEY_Q], [_joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_action("yaw_right", [KEY_E], [_joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("throttle_up", [KEY_SHIFT], [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action("throttle_down", [KEY_CTRL], [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action("move_forward", [KEY_W, KEY_UP], [_joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_back", [KEY_S, KEY_DOWN], [_joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("sprint", [KEY_SHIFT], [_joy_button(JOY_BUTTON_X)])
	_action("jump", [KEY_SPACE], [_joy_button(JOY_BUTTON_A)])
	_action("interact", [KEY_F], [_joy_button(JOY_BUTTON_Y)])
	_action("reset_vehicle", [KEY_R], [_joy_button(JOY_BUTTON_BACK)])
	_action("toggle_help", [KEY_H], [])
	_action("toggle_ao", [KEY_F3], [])
	_action("toggle_map", [KEY_M], [_joy_button(JOY_BUTTON_START)])


func _action(action: StringName, keys: Array, joy_events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
	for ev in joy_events:
		InputMap.action_add_event(action, ev)


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev
