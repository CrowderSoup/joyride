class_name MapView
extends Control
## Draws the shared map mesh. MINI = heading-up minimap locked to the player.
## FULL = north-up full-screen map you can zoom (wheel), pan (drag), and click to set a waypoint.

signal waypoint_set(pos: Vector2)
signal waypoint_cleared

enum Mode { MINI, FULL }

const MINI_BG_COLOR := Color(0.04, 0.075, 0.09, 0.94)
const FULL_BG_COLOR := Color(0.1, 0.11, 0.1)
const PLAYER_COLOR := Color(0.3, 0.9, 1.0)
const WAYPOINT_COLOR := Color(1.0, 0.3, 0.6)
const VEHICLE_COLOR := Color(1.0, 0.85, 0.3)
const MINI_ZOOM := 0.35  # pixels per meter
const MIN_ZOOM := 0.05
const MAX_ZOOM := 3.0
const DRAG_THRESHOLD := 6.0

var mode := Mode.MINI
var geometry: MapGeometry
var player: Node3D
var waypoint: Variant = null  # Vector2 or null
var vehicles: Array = []  # parked vehicles to mark (the one you're in is skipped)

var _zoom := MINI_ZOOM
var _offset := Vector2.ZERO  # FULL mode: screen = world * _zoom + _offset
var _press_pos := Vector2.ZERO
var _dragging := false


func _init(p_mode: Mode, p_geometry: MapGeometry) -> void:
	mode = p_mode
	geometry = p_geometry
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == Mode.FULL else Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		if mode == Mode.MINI and player and player.is_inside_tree():
			var target_zoom := lerpf(MINI_ZOOM, 0.2, clampf(absf(player.get_speed()) / 55.0, 0, 1))
			if player is Airplane:
				target_zoom = lerpf(0.24, 0.09, clampf(absf(player.get_speed()) / 75.0, 0, 1))
			_zoom = lerpf(_zoom, target_zoom, 1.0 - exp(-2.0 * delta))
		queue_redraw()


## FULL mode: fit the whole map on screen.
func fit_to_map() -> void:
	var b := geometry.bounds
	_zoom = minf(size.x / b.size.x, size.y / b.size.y) * 0.95
	_offset = size * 0.5 - b.get_center() * _zoom


func world_to_screen(world: Vector2) -> Vector2:
	return _transform() * world


func _player_pos() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z) if player else Vector2.ZERO


func _player_yaw() -> float:
	if not player:
		return 0.0
	var forward := -player.global_basis.z
	return atan2(-forward.x, -forward.z)


func _transform() -> Transform2D:
	if mode == Mode.FULL:
		return Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, _offset)
	# Rotating by yaw turns the player's heading to screen-up (see arrow math in _draw).
	var rot := Transform2D(_player_yaw(), Vector2.ZERO)
	return Transform2D(0.0, size * Vector2(0.5, 0.65)) * rot * Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, -_player_pos() * _zoom)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FULL_BG_COLOR if mode == Mode.FULL else MINI_BG_COLOR)
	var xf := _transform()
	draw_set_transform_matrix(xf)
	draw_mesh(geometry.mesh, null)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	if mode == Mode.FULL or _zoom >= 0.22:
		_draw_labels(xf)

	if waypoint != null:
		var wp: Vector2 = xf * waypoint
		if mode == Mode.MINI:
			wp = _clamp_to_edge(wp, 12.0)
			draw_dashed_line(xf * _player_pos(), wp, Color(1, 0.3, 0.6, 0.4), 2, 7, true)
		draw_circle(wp, 11.0, Color(0.03, 0.04, 0.05, 0.95))
		draw_colored_polygon(PackedVector2Array([wp + Vector2(0, -8), wp + Vector2(7, 0), wp + Vector2(0, 8), wp + Vector2(-7, 0)]), WAYPOINT_COLOR)

	_draw_vehicles(xf)

	# In map space the player's heading is (-sin yaw, -cos yaw); an up-pointing arrow
	# rotated by -yaw matches it. On the minimap the map itself is rotated, so it stays up.
	var arrow_rot := -_player_yaw() if mode == Mode.FULL else 0.0
	var arrow_pos := xf * _player_pos()
	var s := 15.0
	var arrow := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, s * 0.8), Vector2(0, s * 0.35), Vector2(-s * 0.7, s * 0.8)])
	var arrow_xf := Transform2D(arrow_rot, arrow_pos)
	draw_colored_polygon(arrow_xf * arrow, PLAYER_COLOR)
	draw_polyline(arrow_xf * (arrow + PackedVector2Array([arrow[0]])), Color.BLACK, 2.0, true)

	if mode == Mode.MINI:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.64, 0.72, 0.71, 0.75), false, 2.0)
		_draw_north_marker()
		_draw_scale()
	else:
		var font := get_theme_default_font()
		var hint := "Click: set waypoint    Right-click: clear    Wheel: zoom    Drag: pan    M: close"
		draw_string_outline(font, Vector2(24, size.y - 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, Vector2(24, size.y - 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_labels(xf: Transform2D) -> void:
	var font := get_theme_default_font()
	var font_size := 14 if mode == Mode.FULL else 10
	var show_minor := mode == Mode.FULL and _zoom > 0.3
	var screen := Rect2(Vector2.ZERO, size).grow(-18 if mode == Mode.MINI else 0)
	var drawn: Array[Rect2] = []
	var mini_count := 0
	if mode == Mode.MINI:
		drawn.append(Rect2(xf * _player_pos() - Vector2(25, 25), Vector2(50, 50)))
		var north_dir := Transform2D(_player_yaw(), Vector2.ZERO) * Vector2.UP
		var north_pos := _clamp_to_edge(size * 0.5 + north_dir * size.length(), 18.0)
		drawn.append(Rect2(north_pos - Vector2(20, 20), Vector2(40, 40)))
		drawn.append(Rect2(8, size.y - 44, 80, 40))
		if waypoint != null:
			drawn.append(Rect2(_clamp_to_edge(xf * waypoint, 12) - Vector2(14, 14), Vector2(28, 28)))
	for label in geometry.labels:
		if mode == Mode.MINI and mini_count >= 3:
			break
		if not label.major and not show_minor:
			continue
		var pos: Vector2 = xf * label.pos
		if not screen.has_point(pos):
			continue
		var w := font.get_string_size(label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := pos - Vector2(w * 0.5, -font_size * 0.35)
		# Skip labels that would overlap one already drawn.
		var rect := Rect2(at - Vector2(0, font_size), Vector2(w, font_size * 1.3)).grow(4)
		if mode == Mode.MINI and not screen.encloses(rect):
			continue
		if drawn.any(func(r: Rect2) -> bool: return r.intersects(rect)):
			continue
		drawn.append(rect)
		mini_count += 1
		draw_string_outline(font, at, label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
		draw_string(font, at, label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_vehicles(xf: Transform2D) -> void:
	var font := get_theme_default_font()
	for v: Node3D in vehicles:
		if v == player:
			continue
		var pos := xf * Vector2(v.global_position.x, v.global_position.z)
		if mode == Mode.MINI and not Rect2(Vector2.ZERO, size).has_point(pos):
			continue
		_draw_vehicle_icon(pos, v)
		if mode == Mode.FULL:
			var at := pos + Vector2(10, 5)
			draw_string_outline(font, at, v.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
			draw_string(font, at, v.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, VEHICLE_COLOR)


func _draw_vehicle_icon(pos: Vector2, vehicle: Node3D) -> void:
	draw_circle(pos, 11, Color(0.03, 0.04, 0.05, 0.95))
	if vehicle is Airplane:
		draw_line(pos + Vector2(0, -7), pos + Vector2(0, 7), VEHICLE_COLOR, 3, true)
		draw_line(pos + Vector2(-7, -2), pos + Vector2(7, -2), VEHICLE_COLOR, 3, true)
		draw_line(pos + Vector2(-3, 5), pos + Vector2(3, 5), VEHICLE_COLOR, 2, true)
	elif vehicle.display_name == "Motorcycle":
		draw_circle(pos + Vector2(0, -5), 3, VEHICLE_COLOR)
		draw_circle(pos + Vector2(0, 5), 3, VEHICLE_COLOR)
		draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), VEHICLE_COLOR, 2)
	else:
		draw_rect(Rect2(pos - Vector2(5, 7), Vector2(10, 14)), VEHICLE_COLOR, false, 2)
		draw_line(pos + Vector2(-4, -2), pos + Vector2(4, -2), VEHICLE_COLOR, 2)
		if vehicle.display_name == "Frontier NISMO":
			draw_line(pos + Vector2(-4, 2), pos + Vector2(4, 2), VEHICLE_COLOR, 2)


static func distance_text(meters: float) -> String:
	return "%d FT" % roundi(meters * 3.281) if meters < 160.0 else "%.1f MI" % (meters / 1609.34)


func _draw_scale() -> void:
	var meters := 100.0 if _zoom >= 0.2 else 250.0
	var width := meters * _zoom
	var at := Vector2(14, size.y - 14)
	draw_rect(Rect2(at + Vector2(-6, -22), Vector2(width + 12, 30)), Color(0.03, 0.05, 0.06, 0.9))
	draw_line(at, at + Vector2(width, 0), Color.WHITE, 2)
	draw_line(at + Vector2(0, -4), at + Vector2(0, 3), Color.WHITE, 2)
	draw_line(at + Vector2(width, -4), at + Vector2(width, 3), Color.WHITE, 2)
	draw_string(get_theme_default_font(), at + Vector2(0, -7), "%d FT" % roundi(meters * 3.281), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.86, 0.85))


func _draw_north_marker() -> void:
	# North is map -Y; after the heading-up rotation it points wherever yaw sends it.
	var north_dir := Transform2D(_player_yaw(), Vector2.ZERO) * Vector2.UP
	var pos := _clamp_to_edge(size * 0.5 + north_dir * size.length(), 18.0)
	var font := get_theme_default_font()
	draw_circle(pos, 15.0, Color(0.03, 0.05, 0.06, 0.95))
	draw_colored_polygon(PackedVector2Array([pos + north_dir * 12, pos + north_dir.orthogonal() * 5, pos - north_dir.orthogonal() * 5]), Color(1, 0.8, 0.28))
	draw_string_outline(font, pos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
	draw_string(font, pos + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _clamp_to_edge(p: Vector2, inset: float) -> Vector2:
	var c := size * 0.5
	var half := c - Vector2(inset, inset)
	var d := p - c
	var t := maxf(absf(d.x) / half.x, absf(d.y) / half.y)
	return c + d / t if t > 1.0 else p


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.FULL:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var factor := 1.2 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2
				var world := (mb.position - _offset) / _zoom
				_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
				_offset = mb.position - world * _zoom
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_dragging = false
			elif not _dragging:
				waypoint_set.emit((mb.position - _offset) / _zoom)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			waypoint_cleared.emit()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _dragging or event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragging = true
			_offset += event.relative
		accept_event()
