class_name Hud
extends CanvasLayer

signal waypoint_changed(pos: Variant)
signal map_toggled(open: bool)

const HELP_TEXT := """WASD  walk / drive     Shift  run     Space  jump / handbrake     Mouse  look (Q/E on foot)
F  get in / out     Plane in the air:  W/S pitch   A/D roll   Q/E rudder   Shift/Ctrl throttle
M  map      R  unstick vehicle (on foot: back to the hangar)      H  hide help      Esc  free mouse, again to quit"""

const MINIMAP_SIZE := Vector2(280, 280)

var _status := Label.new()
var _street := Label.new()
var _help := Label.new()
var _prompt := Label.new()
var _minimap: MapView
var _full_map: MapView


func _init() -> void:
	# Keep running while the full map pauses the game.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_status.label_settings = _settings(30)
	_status.position = Vector2(24, 18)
	add_child(_status)

	_street.label_settings = _settings(40)
	_street.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_street.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_street.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_street.position.y = 18
	add_child(_street)

	_help.label_settings = _settings(18)
	_help.text = HELP_TEXT
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.position += Vector2(24, -18)
	add_child(_help)

	_prompt.label_settings = _settings(26)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.position.y -= 110
	add_child(_prompt)



func setup_map(geometry: MapGeometry, player: Node3D) -> void:
	_minimap = MapView.new(MapView.Mode.MINI, geometry)
	_minimap.size = MINIMAP_SIZE
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 20)
	add_child(_minimap)

	_full_map = MapView.new(MapView.Mode.FULL, geometry)
	_full_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full_map.visible = false
	_full_map.waypoint_set.connect(_set_waypoint)
	_full_map.waypoint_cleared.connect(_set_waypoint.bind(null))
	add_child(_full_map)
	set_player(player)


func set_player(player: Node3D) -> void:
	_minimap.player = player
	_full_map.player = player


## Vehicles to mark on the maps, so you can find where you left them.
func set_vehicles(vehicles: Array) -> void:
	_minimap.vehicles = vehicles
	_full_map.vehicles = vehicles


func set_prompt(text: String) -> void:
	_prompt.text = text


func clear_waypoint() -> void:
	_set_waypoint(null)


func _set_waypoint(pos: Variant) -> void:
	_minimap.waypoint = pos
	_full_map.waypoint = pos
	waypoint_changed.emit(pos)


func _unhandled_input(event: InputEvent) -> void:
	if _full_map == null:
		return
	if event.is_action_pressed("toggle_map") or (_full_map.visible and event.is_action_pressed("ui_cancel")):
		_full_map.visible = not _full_map.visible
		_minimap.visible = not _full_map.visible
		if _full_map.visible:
			_full_map.fit_to_map()
		get_tree().paused = _full_map.visible
		map_toggled.emit(_full_map.visible)
		get_viewport().set_input_as_handled()


## Pass show_speed = false on foot.
func update(vehicle_name: String, speed_mps: float, extra: String, street: String, waypoint_dist := -1.0, show_speed := true) -> void:
	var line := vehicle_name
	if show_speed:
		line += "   %d mph" % roundi(absf(speed_mps) * 2.237)
	if extra != "":
		line += "   " + extra
	if waypoint_dist >= 0.0:
		line += "\nWaypoint  %.1f mi" % (waypoint_dist / 1609.34)
	_status.text = line
	_street.text = street


func toggle_help() -> void:
	_help.visible = not _help.visible


static func _settings(size: int) -> LabelSettings:
	var s := LabelSettings.new()
	s.font_size = size
	s.outline_size = maxi(4, size / 5)
	s.outline_color = Color(0, 0, 0, 0.8)
	return s
