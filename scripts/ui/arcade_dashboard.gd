class_name ArcadeDashboard
extends Control
## Code-drawn arcade dials: speed, flight altitude and throttle.

const INK := Color(0.94, 0.93, 0.85)
const MUTED := Color(0.59, 0.65, 0.68)
const GOLD := Color(1.0, 0.8, 0.28)
const PANEL := Color(0.045, 0.065, 0.08, 0.9)

var telemetry := {}
var needle_speed := 0.0
var needle_altitude := 0.0
var _primed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_telemetry(data: Dictionary) -> void:
	if telemetry.get("name", "") != data.name:
		_primed = false
	telemetry = data
	visible = data.vehicle
	size = Vector2(460 if data.flight else 226, 252)
	if not _primed:
		needle_speed = absf(data.speed)
		needle_altitude = data.altitude
		_primed = true
	queue_redraw()


func _process(delta: float) -> void:
	if telemetry.is_empty() or not visible:
		return
	var blend := 1.0 - exp(-12.0 * delta)
	needle_speed = lerpf(needle_speed, absf(telemetry.speed), blend)
	needle_altitude = lerpf(needle_altitude, telemetry.altitude, blend)
	queue_redraw()


func _text(at: Vector2, value: String, font_size: int, color := INK, centered := true) -> void:
	var font := get_theme_default_font()
	if centered:
		at.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if telemetry.is_empty():
		return
	var flight: bool = telemetry.flight
	var width := 460.0 if flight else 226.0
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = Color(0.32, 0.38, 0.4, 0.8)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(18)
	draw_style_box(panel, Rect2(0, 0, width, 252))
	_text(Vector2(16, 25), telemetry.name.to_upper(), 14, MUTED, false)
	_speed_dial(Vector2(113, 124))
	if flight:
		_altitude_dial(Vector2(305, 124))
		_throttle(Vector2(413, 54))
	else:
		_text(Vector2(113, 224), "R  REVERSE" if telemetry.speed < -0.5 else "V  CHANGE VIEW", 12, GOLD if telemetry.speed < -0.5 else MUTED)


func _face(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0, 3), radius + 4, Color(0, 0, 0, 0.3))
	draw_circle(center, radius, Color(0.075, 0.095, 0.11))
	draw_arc(center, radius, 0, TAU, 96, Color(0.4, 0.46, 0.48), 2, true)
	draw_arc(center, radius - 5, 0, TAU, 96, Color(0.17, 0.22, 0.24), 1, true)


func _needle(center: Vector2, angle: float, length: float) -> void:
	var direction := Vector2.from_angle(angle)
	var side := direction.orthogonal() * 3.0
	draw_colored_polygon(PackedVector2Array([center - direction * 12 + side, center + direction * length, center - direction * 12 - side]), GOLD)
	draw_circle(center, 7, Color(0.15, 0.18, 0.2))
	draw_circle(center, 3, INK)


func _speed_dial(center: Vector2) -> void:
	const RADIUS := 86.0
	_face(center, RADIUS)
	var maximum: float = telemetry.speed_max
	var ratio := clampf(needle_speed / maximum, 0.0, 1.0)
	draw_arc(center, 79, deg_to_rad(135), deg_to_rad(135 + 270 * ratio), 64, GOLD, 3, true)
	var tick_count := 32 if telemetry.flight else 28
	for tick in tick_count + 1:
		var angle := deg_to_rad(135.0 + float(tick) / tick_count * 270.0)
		var direction := Vector2.from_angle(angle)
		var major := tick % 4 == 0
		draw_line(center + direction * (65 if major else 72), center + direction * 77, INK if major else MUTED, 2 if major else 1, true)
		if major:
			_text(center + direction * 60 + Vector2(0, 4), str(roundi(float(tick) / tick_count * maximum)), 12)
	_text(center + Vector2(0, -22), "AIRSPEED" if telemetry.flight else "SPEED", 11, MUTED)
	_needle(center, deg_to_rad(135 + ratio * 270), 62)
	draw_rect(Rect2(center + Vector2(-33, 19), Vector2(66, 37)), PANEL)
	_text(center + Vector2(0, 49), str(roundi(absf(telemetry.speed))), 32)
	_text(center + Vector2(0, 70), "MPH", 11, GOLD)


func _altitude_dial(center: Vector2) -> void:
	_face(center, 78)
	for tick in 50:
		var direction := Vector2.from_angle(-PI * 0.5 + tick / 50.0 * TAU)
		var major := tick % 5 == 0
		draw_line(center + direction * (62 if major else 66), center + direction * 70, INK if major else MUTED, 2 if major else 1, true)
		if major:
			_text(center + direction * 54 + Vector2(0, 4), str(tick / 5), 11)
	_text(center + Vector2(0, -23), "ALT ×100 FT", 10, MUTED)
	_needle(center, -PI * 0.5 + fposmod(needle_altitude, 1000.0) / 1000.0 * TAU, 54)
	draw_rect(Rect2(center + Vector2(-47, 8), Vector2(94, 31)), PANEL)
	_text(center + Vector2(0, 33), str(roundi(telemetry.altitude)), 27)
	_text(center + Vector2(0, 48), "FT", 10, MUTED)
	_text(center + Vector2(0, 93), "ALT RELATIVE TO TEMPLE SQUARE", 9, MUTED)
	_text(center + Vector2(0, 112), "%d FT ABOVE GROUND" % roundi(telemetry.agl), 12, GOLD)


func _throttle(at: Vector2) -> void:
	_text(at + Vector2(13, -10), "THR", 11, MUTED)
	draw_rect(Rect2(at, Vector2(26, 134)), Color(0.13, 0.17, 0.19))
	var fill := clampf(telemetry.throttle, 0, 1) * 130
	draw_rect(Rect2(at + Vector2(3, 132 - fill), Vector2(20, fill)), GOLD)
	for tick in 5:
		var y := at.y + tick * 33.5
		draw_line(Vector2(at.x - 4, y), Vector2(at.x + 30, y), MUTED, 1)
	_text(at + Vector2(-6, 4), "100", 8, MUTED)
	_text(at + Vector2(-6, 134), "0", 8, MUTED)
	_text(at + Vector2(13, 157), "%d%%" % roundi(telemetry.throttle * 100), 14)
