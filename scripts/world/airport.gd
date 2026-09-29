class_name Airport
extends RefCounted
## A small airfield just west of I-15, a few blocks from downtown: one runway (18/36), a
## parallel taxiway, an apron, our hangar, and a tower. The hangar opens onto the west end
## of North Temple. Everything is laid out in a local frame (runway along -Z, hangar door
## facing -X) and placed so that local z = 60 lines up with North Temple.

const ROAD_Z := 60.0  # local z of the access road along the hangar's south side

const RUNWAY_X := -330.0
const RUNWAY_HALF_LEN := 1400.0
const RUNWAY_WIDTH := 45.0
const TAXIWAY_X := -150.0
const TAXIWAY_WIDTH := 23.0
const APRON := Rect2(-150, -110, 150, 220)  # local x/z

# Hangar: door on the x = 0 face, back wall at x = DEPTH, spans z = +-HALF_WIDTH.
const HANGAR_DEPTH := 30.0
const HANGAR_HALF_WIDTH := 22.0
const HANGAR_WALL_H := 8.0
const HANGAR_ROOF_H := 13.5
const DOOR_HALF_WIDTH := 17.0
const DOOR_H := 10.0

const MARKING_Y := 0.03
const WHITE := Color(0.92, 0.92, 0.9)
const YELLOW := Color(0.95, 0.75, 0.2)

## Parking spots inside the hangar, local (x, z, yaw). Yaw PI/2 faces out the door.
const SPOTS := {
	"plane": Vector3(15.0, 0.0, PI / 2),
	"frontier": Vector3(12.0, -15.5, PI / 2),
	"sedan": Vector3(12.0, 15.5, PI / 2),
	"motorcycle": Vector3(21.0, 16.0, PI / 2),
	"player": Vector3(22.0, 0.0, PI / 2),
}

## Local airport frame -> world.
var xform: Transform3D


func _init() -> void:
	# Hangar's back wall ~100 m west of I-15, access road on North Temple's line.
	var origin := Vector3(CityGen.I15_X - 100.0 - HANGAR_DEPTH, 0, CityGen.street_z(-1) - ROAD_Z)
	xform = Transform3D(Basis.IDENTITY, origin)


## World transform for a named parking spot.
func spot(spot_name: String) -> Transform3D:
	var s: Vector3 = SPOTS[spot_name]
	return xform * Transform3D(Basis(Vector3.UP, s.z), Vector3(s.x, 0, s.y))


## Adds the airfield to the map data so the city builder paints it, the maps draw it,
## and the street index can name it. Call before anything else reads the map.
func add_to_map(map: Dictionary) -> void:
	var areas: Array = map.areas
	areas.append(_area(Rect2(RUNWAY_X - RUNWAY_WIDTH * 0.5, -RUNWAY_HALF_LEN, RUNWAY_WIDTH, RUNWAY_HALF_LEN * 2.0)))
	areas.append(_area(Rect2(TAXIWAY_X - TAXIWAY_WIDTH * 0.5, -RUNWAY_HALF_LEN + 100.0, TAXIWAY_WIDTH, RUNWAY_HALF_LEN * 2.0 - 200.0)))
	for z in [-RUNWAY_HALF_LEN + 100.0, 0.0, RUNWAY_HALF_LEN - 100.0]:
		areas.append(_area(Rect2(RUNWAY_X, z - TAXIWAY_WIDTH * 0.5, TAXIWAY_X - RUNWAY_X, TAXIWAY_WIDTH)))
	areas.append(_area(APRON))
	# Concrete pad in front of the door so the apron runs right into the hangar.
	areas.append(_area(Rect2(0, -HANGAR_HALF_WIDTH, HANGAR_DEPTH, HANGAR_HALF_WIDTH * 2.0)))

	# Footprint only: shows on the maps, but the city builder leaves it to us.
	map.buildings.append({"pts": _rect_pts(Rect2(0, -HANGAR_HALF_WIDTH, HANGAR_DEPTH, HANGAR_HALF_WIDTH * 2.0)), "h": HANGAR_ROOF_H, "custom": true})

	# North Temple, from the hangar across I-15 to 600 West. The crossing points must match
	# the city's vertices exactly so they count as intersections.
	var z := CityGen.street_z(-1)
	map.roads.append(_road("North Temple", "primary", CityGen.ew_width(-1), [
		_world2(Vector2(0, ROAD_Z)), Vector2(CityGen.I15_X, z), Vector2(CityGen.street_x(CityGen.NS_RANGE.x), z),
	]))

	# Named places for the "where am I" readout; never drawn.
	var places: Array = map.get_or_add("places", [])
	places.append(_road("Runway 18/36", "place", 0.0, [
		_world2(Vector2(RUNWAY_X, -RUNWAY_HALF_LEN)), _world2(Vector2(RUNWAY_X, RUNWAY_HALF_LEN))]))
	places.append(_road("Taxiway A", "place", 0.0, [
		_world2(Vector2(TAXIWAY_X, -RUNWAY_HALF_LEN)), _world2(Vector2(TAXIWAY_X, RUNWAY_HALF_LEN))]))
	for x in [-110.0, -40.0]:
		places.append(_road("Salt Lake City International", "place", 0.0, [
			_world2(Vector2(x, APRON.position.y)), _world2(Vector2(x, APRON.end.y))]))
	places.append(_road("Joyride Hangar", "place", 0.0, [_world2(Vector2(5, 0)), _world2(Vector2(HANGAR_DEPTH, 0))]))


func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Airport"
	root.transform = xform
	root.add_child(_build_markings())
	root.add_child(_build_hangar())
	root.add_child(_build_tower(Vector3(-60, 0, -300)))
	root.add_child(_build_windsock(Vector3(-40, 0, -130)))
	return root


func _world2(local: Vector2) -> Vector2:
	var p := xform * Vector3(local.x, 0, local.y)
	return Vector2(p.x, p.z)


func _rect_pts(r: Rect2) -> Array:
	var pts := []
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var w := _world2(c)
		pts.append([w.x, w.y])
	return pts


func _area(r: Rect2) -> Dictionary:
	return {"kind": "aeroway", "pts": _rect_pts(r)}


static func _road(road_name: String, kind: String, width: float, pts: Array) -> Dictionary:
	var arr := []
	for p in pts:
		arr.append([p.x, p.y])
	return {"name": road_name, "kind": kind, "width": width, "pts": arr}


# --- Runway and taxiway paint, edge lights ---------------------------------

static func _build_markings() -> MeshInstance3D:
	var buf := MeshBuffer.new()
	var y := MARKING_Y
	var rx := RUNWAY_X
	var half := RUNWAY_HALF_LEN
	# Centerline dashes and edge stripes.
	var z := -half + 150.0
	while z < half - 150.0:
		_rect(buf, Rect2(rx - 0.45, z, 0.9, 30.0), y, WHITE)
		z += 50.0
	for side in [-1.0, 1.0]:
		_rect(buf, Rect2(rx + side * (RUNWAY_WIDTH * 0.5 - 1.5) - 0.45, -half, 0.9, half * 2.0), y, WHITE)
	# Threshold "piano keys" and aiming-point blocks at both ends.
	for end in [-1.0, 1.0]:
		var edge: float = end * half
		var inward: float = -end
		for side in [-1.0, 1.0]:
			for k in 5:
				var x0: float = rx + side * (3.0 + k * 3.2) - (1.8 if side < 0.0 else 0.0)
				_rect(buf, Rect2(x0, minf(edge + inward * 8.0, edge + inward * 38.0), 1.8, 30.0), y, WHITE)
			var zc: float = edge + inward * 330.0
			_rect(buf, Rect2(rx + side * 7.0 - (4.0 if side < 0.0 else 0.0), zc - 22.5, 4.0, 45.0), y, WHITE)
	# Taxiway centerlines, yellow.
	var tx := TAXIWAY_X
	_rect(buf, Rect2(tx - 0.2, -half + 100.0, 0.4, half * 2.0 - 200.0), y, YELLOW)
	for zc in [-half + 100.0, 0.0, half - 100.0]:
		_rect(buf, Rect2(rx + RUNWAY_WIDTH * 0.5, zc - 0.2, tx - rx - RUNWAY_WIDTH * 0.5, 0.4), y, YELLOW)
	# Lead-in line from the taxiway across the apron to the hangar door.
	_rect(buf, Rect2(tx, -0.2, -tx, 0.4), y, YELLOW)
	# Hold-short bars where the connectors meet the runway.
	for zc in [-half + 100.0, 0.0, half - 100.0]:
		for k in 2:
			_rect(buf, Rect2(rx + RUNWAY_WIDTH * 0.5 + 25.0 + k * 1.2, zc - TAXIWAY_WIDTH * 0.5, 0.4, TAXIWAY_WIDTH), y, YELLOW)
	# Edge lights: little white posts along the runway, blue along the taxiway.
	z = -half
	while z <= half:
		for side in [-1.0, 1.0]:
			_post(buf, Vector3(rx + side * (RUNWAY_WIDTH * 0.5 + 2.0), 0, z), Color(1.0, 0.95, 0.8))
			if absf(z) < half - 100.0:
				_post(buf, Vector3(tx + side * (TAXIWAY_WIDTH * 0.5 + 1.5), 0, z), Color(0.3, 0.45, 1.0))
		z += 60.0

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	var inst := MeshInstance3D.new()
	inst.name = "Markings"
	inst.mesh = buf.to_mesh(mat)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Runway numbers, painted flat and readable on approach.
	for n in [["36", half - 70.0, 0.0], ["18", -half + 70.0, PI]]:
		var label := Label3D.new()
		label.text = n[0]
		label.font_size = 256
		label.pixel_size = 0.07
		label.modulate = WHITE
		label.outline_size = 0
		label.shaded = true
		label.double_sided = false
		label.position = Vector3(rx, y, n[1])
		label.rotation = Vector3(-PI / 2, n[2], 0)
		inst.add_child(label)
	return inst


static func _rect(buf: MeshBuffer, r: Rect2, y: float, col: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	buf.add_quad(a, b, c, d, Vector3.UP, col)


static func _post(buf: MeshBuffer, p: Vector3, col: Color) -> void:
	var s := 0.18
	var h := 0.45
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var side := Vector3(-n.z, 0, n.x) * s
		var c := p + n * s
		buf.add_quad(c - side, c + side, c + side + Vector3.UP * h, c - side + Vector3.UP * h, n, col)
	buf.add_quad(p + Vector3(-s, h, -s), p + Vector3(s, h, -s), p + Vector3(s, h, s), p + Vector3(-s, h, s), Vector3.UP, col)


# --- Hangar ---------------------------------------------------------------

## Quonset-ish hangar. ModelBuilder profiles are (z, y) extruded along x, which here is
## the hangar's depth, so the profiles are its cross-section.
static func _build_hangar() -> StaticBody3D:
	var m := ModelBuilder.new()  # solid, collides
	var deco := ModelBuilder.new()  # floor paint and lamps; no collision so nothing snags on it
	deco.add_material("floor", Color(0.62, 0.62, 0.6), 0.95)
	deco.add_material("paint", YELLOW, 0.8)
	deco.add_material("lamp", Color(1.0, 0.95, 0.85), 0.3, 0.0, 2.0)
	m.add_material("shell", Color(0.66, 0.69, 0.72), 0.45, 0.5)
	m.add_material("wall", Color(0.88, 0.87, 0.83), 0.8)
	m.add_material("trim", Color(0.8, 0.28, 0.2), 0.7)
	m.add_material("door", Color(0.55, 0.58, 0.6), 0.5, 0.4)
	m.add_material("dark", Color(0.15, 0.15, 0.16), 0.8)
	m.add_material("bench", Color(0.45, 0.32, 0.2), 0.9)
	m.add_material("red", Color(0.75, 0.12, 0.1), 0.5, 0.3)

	var hw := HANGAR_HALF_WIDTH
	var d := HANGAR_DEPTH
	var t := 0.3
	var outer := _arch(hw, 0.0)
	var inner := _arch(hw - t, t)
	var shell := outer.duplicate()
	var inner_rev := inner.duplicate()
	inner_rev.reverse()
	shell.append_array(inner_rev)
	m.extrude("shell", shell, d * 0.5, d * 0.5)

	# Back wall fills the arch; the front wall is the arch minus the door opening.
	m.extrude("wall", inner, 0.2, d - 0.2)
	var front := PackedVector2Array([Vector2(-(hw - t), 0), Vector2(-DOOR_HALF_WIDTH, 0), Vector2(-DOOR_HALF_WIDTH, DOOR_H),
		Vector2(DOOR_HALF_WIDTH, DOOR_H), Vector2(DOOR_HALF_WIDTH, 0), Vector2(hw - t, 0)])
	for i in range(inner.size() - 2, 0, -1):
		front.append(inner[i])
	m.extrude("wall", front, 0.2, 0.2)
	m.box("trim", Vector3(-0.05, DOOR_H + 0.25, 0), Vector3(0.12, 0.5, DOOR_HALF_WIDTH * 2.0 + 0.4))
	for side in [-1.0, 1.0]:
		m.box("trim", Vector3(-0.05, DOOR_H * 0.5, side * (DOOR_HALF_WIDTH + 0.2)), Vector3(0.12, DOOR_H, 0.4))
		# Sliding doors, stacked open against the jambs.
		for layer in 2:
			var x := -0.4 - layer * 0.35
			m.box("door", Vector3(x, DOOR_H * 0.5, side * 19.4), Vector3(0.3, DOOR_H, 4.6))
			for k in 4:
				m.box("dark", Vector3(x - 0.17, 1.5 + k * 2.4, side * 19.4), Vector3(0.04, 0.08, 4.4))

	# Floor slab with painted bays for each vehicle.
	deco.box("floor", Vector3(d * 0.5, 0.02, 0), Vector3(d, 0.04, (hw - t) * 2.0))
	for s in SPOTS:
		if s == "player":
			continue
		var p: Vector3 = SPOTS[s]
		var half := Vector2(6.0, 6.0) if s == "plane" else Vector2(3.4, 1.8)
		for side in [-1.0, 1.0]:
			deco.box("paint", Vector3(p.x, 0.045, p.y + side * half.y), Vector3(half.x * 2.0, 0.01, 0.15))
		deco.box("paint", Vector3(p.x + half.x, 0.045, p.y), Vector3(0.15, 0.01, half.y * 2.0))

	# Shop corner: workbench, tool chest, tire stack, drums.
	m.box("bench", Vector3(d - 1.2, 0.9, -8.0), Vector3(1.2, 0.08, 5.0))
	for z in [-10.3, -5.7]:
		m.box("dark", Vector3(d - 1.2, 0.45, z), Vector3(1.0, 0.9, 0.1))
	m.box("red", Vector3(d - 1.0, 0.6, -3.5), Vector3(0.9, 1.2, 1.4))
	for k in 4:
		var tire := Vector3(d - 2.5 + (k % 2) * 0.8, 0.13 + (k / 2) * 0.26, 19.5)
		m.box("dark", tire, Vector3(0.75, 0.25, 0.75))
	for k in 3:
		m.box("red" if k != 1 else "trim", Vector3(d - 1.0, 0.45, 12.0 + k * 0.8), Vector3(0.6, 0.9, 0.6))
	# Hanging lamps.
	for x in [8.0, 22.0]:
		for z in [-10.0, 10.0]:
			deco.box("lamp", Vector3(x, 11.0, z), Vector3(1.4, 0.15, 0.5))

	var body := StaticBody3D.new()
	body.name = "Hangar"
	var mesh := MeshInstance3D.new()
	mesh.mesh = m.build()
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(col)
	var deco_mesh := MeshInstance3D.new()
	deco_mesh.mesh = deco.build()
	deco_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(deco_mesh)

	for x in [8.0, 22.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 10.5, 0)
		light.light_color = Color(1.0, 0.93, 0.8)
		light.light_energy = 2.5
		light.omni_range = 26.0
		body.add_child(light)

	var sign := Label3D.new()
	sign.text = "JOYRIDE AVIATION"
	sign.font_size = 128
	sign.pixel_size = 0.012
	sign.outline_size = 12
	sign.modulate = Color(0.8, 0.2, 0.15)
	sign.outline_modulate = Color(1, 1, 1)
	sign.shaded = true
	sign.double_sided = false
	sign.position = Vector3(-0.08, DOOR_H + 1.6, 0)
	sign.rotation.y = -PI / 2
	body.add_child(sign)
	return body


## Arch cross-section from (-hw, base) up the wall, over the barrel roof, down to (hw, base).
static func _arch(hw: float, inset: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-hw, 0.0)])
	var wall := HANGAR_WALL_H
	var rise := HANGAR_ROOF_H - inset - wall
	var segments := 12
	for i in segments + 1:
		var a := PI - PI * i / segments
		pts.append(Vector2(cos(a) * hw, wall + sin(a) * rise))
	pts.append(Vector2(hw, 0.0))
	return pts


# --- Tower and windsock ---------------------------------------------------

static func _build_tower(pos: Vector3) -> StaticBody3D:
	var m := ModelBuilder.new()
	m.add_material("concrete", Color(0.78, 0.76, 0.72), 0.9)
	m.add_material("glass", Color(0.12, 0.2, 0.26), 0.1, 0.5)
	m.add_material("roof", Color(0.3, 0.3, 0.32), 0.7)
	m.box("concrete", Vector3(0, 3.0, 0), Vector3(16, 6, 16))
	m.box("concrete", Vector3(0, 22.0, 0), Vector3(5, 44, 5))
	m.box("concrete", Vector3(0, 44.5, 0), Vector3(10, 1, 10))
	m.box("glass", Vector3(0, 47.5, 0), Vector3(9, 5, 9))
	m.box("roof", Vector3(0, 50.4, 0), Vector3(11, 0.8, 11))
	var body := StaticBody3D.new()
	body.name = "Tower"
	body.position = pos
	var mesh := MeshInstance3D.new()
	mesh.mesh = m.build()
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	col.shape = mesh.mesh.create_trimesh_shape()
	body.add_child(col)
	return body


static func _build_windsock(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	Parts.box(root, Vector3(0.15, 6.0, 0.15), Color(0.8, 0.8, 0.8), Vector3(0, 3.0, 0))
	# Stiff breeze out of the north, like most afternoons out by the lake.
	for i in 5:
		var col := Color(0.95, 0.4, 0.1) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
		var s := 0.9 - i * 0.12
		Parts.box(root, Vector3(s, s, 0.7), col, Vector3(0, 5.8 - i * 0.08, 0.5 + i * 0.7))
	return root
