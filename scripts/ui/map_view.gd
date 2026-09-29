class_name MapView
extends Control
## Draws the shared map mesh. MINI = heading-up minimap locked to the player.
## FULL = north-up full-screen map you can zoom (wheel), pan (drag), and click to set a waypoint.

signal waypoint_set(pos: Vector2)
signal waypoint_cleared

enum Mode { MINI, FULL }

const MINI_BG_COLOR := Color(0.12, 0.14, 0.12, 0.85)
const FULL_BG_COLOR := Color(0.1, 0.11, 0.1)
const PLAYER_COLOR := Color(0.3, 0.9, 1.0)
const WAYPOINT_COLOR := Color(1.0, 0.3, 0.6)
const MINI_ZOOM := 0.35  # pixels per meter
const MIN_ZOOM := 0.05
const MAX_ZOOM := 3.0
const DRAG_THRESHOLD := 6.0

var mode := Mode.MINI
var geometry: MapGeometry
var player: Node3D
var waypoint: Variant = null  # Vector2 or null

var _zoom := MINI_ZOOM
var _offset := Vector2.ZERO  # FULL mode: screen = world * _zoom + _offset
var _press_pos := Vector2.ZERO
var _dragging := false


func _init(p_mode: Mode, p_geometry: MapGeometry) -> void:
	mode = p_mode
	geometry = p_geometry
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == Mode.FULL else Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if is_visible_in_tree():
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
	return player.global_rotation.y if player else 0.0


func _transform() -> Transform2D:
	if mode == Mode.FULL:
		return Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, _offset)
	# Rotating by yaw turns the player's heading to screen-up (see arrow math in _draw).
	var rot := Transform2D(_player_yaw(), Vector2.ZERO)
	return Transform2D(0.0, size * 0.5) * rot * Transform2D(0.0, Vector2(_zoom, _zoom), 0.0, -_player_pos() * _zoom)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FULL_BG_COLOR if mode == Mode.FULL else MINI_BG_COLOR)
	var xf := _transform()
	draw_set_transform_matrix(xf)
	draw_mesh(geometry.mesh, null)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	if mode == Mode.FULL:
		_draw_labels(xf)

	if waypoint != null:
		var wp: Vector2 = xf * waypoint
		if mode == Mode.MINI:
			wp = _clamp_to_edge(wp, 12.0)
		draw_circle(wp, 9.0, Color.BLACK)
		draw_circle(wp, 7.0, WAYPOINT_COLOR)

	# In map space the player's heading is (-sin yaw, -cos yaw); an up-pointing arrow
	# rotated by -yaw matches it. On the minimap the map itself is rotated, so it stays up.
	var arrow_rot := -_player_yaw() if mode == Mode.FULL else 0.0
	var arrow_pos := xf * _player_pos()
	var s := 11.0
	var arrow := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, s * 0.8), Vector2(0, s * 0.35), Vector2(-s * 0.7, s * 0.8)])
	var arrow_xf := Transform2D(arrow_rot, arrow_pos)
	draw_colored_polygon(arrow_xf * arrow, PLAYER_COLOR)
	draw_polyline(arrow_xf * (arrow + PackedVector2Array([arrow[0]])), Color.BLACK, 2.0, true)

	if mode == Mode.MINI:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)
		_draw_north_marker()
	else:
		var font := get_theme_default_font()
		var hint := "Click: set waypoint    Right-click: clear    Wheel: zoom    Drag: pan    M: close"
		draw_string_outline(font, Vector2(24, size.y - 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, Vector2(24, size.y - 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_labels(xf: Transform2D) -> void:
	var font := get_theme_default_font()
	var font_size := 14
	var show_minor := _zoom > 0.3
	var screen := Rect2(Vector2.ZERO, size)
	var drawn: Array[Rect2] = []
	for label in geometry.labels:
		if not label.major and not show_minor:
			continue
		var pos: Vector2 = xf * label.pos
		if not screen.has_point(pos):
			continue
		var w := font.get_string_size(label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var at := pos - Vector2(w * 0.5, -font_size * 0.35)
		# Skip labels that would overlap one already drawn.
		var rect := Rect2(at - Vector2(0, font_size), Vector2(w, font_size * 1.3)).grow(4)
		if drawn.any(func(r: Rect2) -> bool: return r.intersects(rect)):
			continue
		drawn.append(rect)
		draw_string_outline(font, at, label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
		draw_string(font, at, label.name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_north_marker() -> void:
	# North is map -Y; after the heading-up rotation it points wherever yaw sends it.
	var north_dir := Transform2D(_player_yaw(), Vector2.ZERO) * Vector2.UP
	var pos := _clamp_to_edge(size * 0.5 + north_dir * size.length(), 14.0)
	var font := get_theme_default_font()
	draw_circle(pos, 11.0, Color(0, 0, 0, 0.7))
	draw_string(font, pos + Vector2(-5.5, 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


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
