class_name FlightHorizon
extends Control
## Transparent attitude reference, centered in either camera view.

var pitch := 0.0
var roll := 0.0
var airborne := false
var takeoff := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _line(a: Vector2, b: Vector2, color: Color, width := 2.0) -> void:
	draw_line(a, b, Color(0, 0, 0, 0.45), width + 2, true)
	draw_line(a, b, color, width, true)


func _draw() -> void:
	var center := size * 0.5
	if not airborne:
		if takeoff:
			var font := get_theme_default_font()
			var text := "LIFT OFF  ·  S / LEFT STICK BACK"
			var at := center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5, 60)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.8, 0.28))
		return
	var ink := Color(0.94, 0.95, 0.87, 0.8)
	draw_set_transform_matrix(Transform2D(roll, center))
	var offset := rad_to_deg(pitch) * 2.4
	_line(Vector2(-120, offset), Vector2(-30, offset), ink)
	_line(Vector2(30, offset), Vector2(120, offset), ink)
	var font := get_theme_default_font()
	for degree in [-30, -20, -10, 10, 20, 30]:
		var y: float = offset - degree * 2.4
		var width := 40.0 if absi(degree) % 20 == 0 else 27.0
		_line(Vector2(-width, y), Vector2(width, y), Color(0.9, 0.94, 0.9, 0.55), 1)
		draw_string_outline(font, Vector2(width + 8, y + 4), str(degree), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(width + 8, y + 4), str(degree), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var gold := Color(1, 0.8, 0.28)
	_line(center + Vector2(-48, 0), center + Vector2(-16, 0), gold, 3)
	_line(center + Vector2(-16, 0), center + Vector2(-8, 8), gold, 3)
	_line(center + Vector2(48, 0), center + Vector2(16, 0), gold, 3)
	_line(center + Vector2(16, 0), center + Vector2(8, 8), gold, 3)
	draw_circle(center, 3, gold)
