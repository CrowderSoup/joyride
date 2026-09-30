class_name CompassRibbon
extends Control
## Heading increases clockwise from north. Waypoint bearing shares that convention.

const LABELS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const PIXELS_PER_DEGREE := 3.0
const PINK := Color(1, 0.35, 0.58)

var heading := 0.0
var waypoint_bearing: Variant = null
var street := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func bearing(from: Vector2, to: Vector2) -> float:
	var direction := to - from
	return fposmod(rad_to_deg(atan2(direction.x, -direction.y)), 360.0)


func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	at.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5
	draw_string_outline(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	var middle := size.x * 0.5
	draw_rect(Rect2(0, 0, size.x, 51), Color(0.04, 0.065, 0.08, 0.86))
	draw_line(Vector2(8, 50), Vector2(size.x - 8, 50), Color(0.5, 0.57, 0.59), 1)
	for degree in range(0, 360, 5):
		var difference := wrapf(float(degree) - heading, -180, 180)
		var x := middle + difference * PIXELS_PER_DEGREE
		if x < 14 or x > size.x - 14:
			continue
		var major := degree % 45 == 0
		draw_line(Vector2(x, 36 if major else 41), Vector2(x, 48), Color(0.88, 0.9, 0.84), 2 if major else 1, true)
		if major:
			_text(Vector2(x, 28), LABELS[degree / 45], 17, Color(1, 0.8, 0.28) if degree == 0 else Color(0.95, 0.94, 0.86))
		elif degree % 15 == 0:
			_text(Vector2(x, 28), str(degree), 11, Color(0.6, 0.68, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(middle - 6, 0), Vector2(middle + 6, 0), Vector2(middle, 9)]), Color(1, 0.8, 0.28))
	_text(Vector2(middle, 70), "%03d°" % (roundi(heading) % 360), 15, Color(1, 0.8, 0.28))
	if waypoint_bearing != null:
		var difference := wrapf(float(waypoint_bearing) - heading, -180, 180)
		var x := middle + difference * PIXELS_PER_DEGREE
		if x >= 14 and x <= size.x - 14:
			draw_colored_polygon(PackedVector2Array([Vector2(x, 31), Vector2(x + 5, 37), Vector2(x, 43), Vector2(x - 5, 37)]), PINK)
		else:
			var direction := signf(difference)
			x = size.x - 8 if direction > 0 else 8
			draw_colored_polygon(PackedVector2Array([Vector2(x, 25), Vector2(x - direction * 9, 18), Vector2(x - direction * 9, 32)]), PINK)
	if street != "":
		_text(Vector2(middle, 96), street, 20, Color(0.95, 0.94, 0.86))
