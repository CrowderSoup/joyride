extends Node3D

const MAP_PATH := "res://data/slc_map.json"
# Main St & South Temple, pointed south down Main.
const SPAWN_LATLON := Vector2(40.7690, -111.8910)
const SPAWN_YAW := PI
const VEHICLES := ["frontier", "sedan", "motorcycle", "plane"]
const ARRIVE_DISTANCE := 20.0

var vehicle: Node3D
var vehicle_index := 0
var camera := ChaseCamera.new()
var hud := Hud.new()
var streets: StreetIndex
var _spawn_point := Vector3.ZERO
var _street_name := ""
var _street_timer := 0.0
var _waypoint: Variant = null  # Vector2 in map space (world X/Z), or null
var _beacon := _make_beacon()
var _env: Environment


func _ready() -> void:
	_setup_input()
	_setup_environment()

	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	var intersections := CityBuilder.find_intersections(map.roads)
	add_child(CityBuilder.build(map, intersections))
	add_child(Scenery.build(map, intersections))
	add_child(Terrain.build())
	streets = StreetIndex.new(map.roads)
	_spawn_point = _project(SPAWN_LATLON, map.origin)

	add_child(camera)
	add_child(hud)
	hud.setup_map(MapGeometry.new(map), null)
	hud.waypoint_changed.connect(_on_waypoint_changed)
	add_child(_beacon)
	_spawn(0, _spawn_point, SPAWN_YAW)


func _process(delta: float) -> void:
	if vehicle == null:
		return
	_street_timer -= delta
	if _street_timer <= 0.0:
		_street_timer = 0.25
		var found := streets.nearest(vehicle.global_position)
		if found != "" or vehicle.global_position.y > 30.0:
			_street_name = found
	var waypoint_dist := -1.0
	if _waypoint != null:
		waypoint_dist = Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(_waypoint)
		if waypoint_dist < ARRIVE_DISTANCE and vehicle.global_position.y < 30.0:
			hud.clear_waypoint()
			waypoint_dist = -1.0
	hud.update(vehicle.display_name, vehicle.get_speed(), vehicle.hud_extra(), _street_name, waypoint_dist)


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
	if event.is_action_pressed("switch_vehicle"):
		var next := (vehicle_index + 1) % VEHICLES.size()
		_spawn(next, vehicle.global_position, vehicle.global_rotation.y)
	elif event.is_action_pressed("reset_vehicle"):
		_spawn(vehicle_index, _spawn_point, SPAWN_YAW)
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("toggle_ao"):
		_env.ssao_enabled = not _env.ssao_enabled
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _spawn(index: int, pos: Vector3, yaw: float) -> void:
	if vehicle != null:
		vehicle.queue_free()
	vehicle_index = index
	match VEHICLES[index]:
		"frontier": vehicle = Frontier.make()
		"sedan": vehicle = GroundVehicle.make_sedan()
		"motorcycle": vehicle = GroundVehicle.make_motorcycle()
		"plane": vehicle = Airplane.new()
	add_child(vehicle)
	vehicle.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0.2, pos.z))
	vehicle.reset_physics_interpolation()
	vehicle.active = true
	camera.set_target(vehicle)
	hud.set_player(vehicle)


## Same equirectangular projection as tools/osm_to_map.py.
static func _project(latlon: Vector2, origin: Array) -> Vector3:
	var lat0: float = origin[0]
	var lon0: float = origin[1]
	var x := (latlon.y - lon0) * 111320.0 * cos(deg_to_rad(lat0))
	var z := -(latlon.x - lat0) * 110540.0
	return Vector3(x, 0, z)


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
	_action("switch_vehicle", [KEY_TAB], [_joy_button(JOY_BUTTON_Y)])
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
