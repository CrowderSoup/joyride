class_name HudTelemetry
extends RefCounted
## Numerical HUD data; no instrument has to parse a vehicle's help string.

static func read(player: Node3D) -> Dictionary:
	var forward := -player.global_basis.z
	var flight := player is Airplane
	var data := {
		"name": player.display_name,
		"vehicle": player is Vehicle,
		"flight": flight,
		"speed": player.get_speed() * 2.237,
		"speed_max": 140.0,
		"heading": fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0),
		"pitch": asin(clampf(forward.y, -1.0, 1.0)),
		"roll": atan2(player.global_basis.x.y, player.global_basis.y.y),
		"altitude": player.global_position.y * 3.281,
		"agl": maxf(0.0, player.global_position.y - Ground.height(player.global_position.x, player.global_position.z)) * 3.281,
		"throttle": 0.0,
		"airborne": false,
		"takeoff": false,
	}
	if flight:
		data.speed_max = 200.0
		data.throttle = player.throttle
		data.airborne = not player._is_grounded()
		data.takeoff = not data.airborne and player.get_speed() > player.takeoff_speed
	return data
