class_name CityGen
extends RefCounted
## Generates a city that's *like* Salt Lake City rather than a map of it: huge square blocks
## on a numbered grid centered on Temple Square, extra-wide streets, a tall downtown,
## warehouses along I-15, houses everywhere else, and the big parks. Output is the same map
## dictionary CityBuilder, Scenery, MapGeometry and StreetIndex already read.
## +X is east, +Z is south, the middle of Temple Square is the origin.

const P := 150.0        # block pitch, street center to street center (real SLC is ~200 m)
const SIDEWALK := 2.5   # CityBuilder paints this much sidewalk along each street
const NS_RANGE := Vector2i(-6, 9)   # north-south streets: 600 West .. 900 East
const EW_RANGE := Vector2i(-4, 13)  # east-west streets: 400 North .. 1300 South
const I15_X := -900.0

const NS_PRIMARY := [-3, 0, 1, 7]            # 300 West, Main, State, 700 East
const NS_SECONDARY := [-2, -1, 2, 3, 4, 5]
const EW_PRIMARY := [-1, 0, 4, 9]            # North Temple, South Temple, 400 South, 900 South
const EW_SECONDARY := [-2, 1, 2, 3, 5, 6]

## Hand-placed skyscrapers so the skyline has a shape: block -> [lot, height, crown].
const SIGNATURE := {
	Vector2i(1, 3): [0, 138.0, "spire"],
	Vector2i(0, 2): [3, 122.0, "pyramid"],
	Vector2i(1, 0): [1, 128.0, "cap"],
	Vector2i(-1, 3): [1, 104.0, "mast"],
}

const GLASS_TINTS := [
	Color(0.35, 0.5, 0.62), Color(0.3, 0.42, 0.45), Color(0.5, 0.45, 0.36),
	Color(0.55, 0.58, 0.62), Color(0.28, 0.36, 0.5),
]
const STONE_COLORS := [
	Color(0.86, 0.84, 0.78), Color(0.72, 0.7, 0.66), Color(0.8, 0.74, 0.62),
	Color(0.62, 0.64, 0.66), Color(0.92, 0.9, 0.86),
]
const BRICK_COLORS := [
	Color(0.62, 0.34, 0.26), Color(0.7, 0.45, 0.32), Color(0.52, 0.3, 0.24),
	Color(0.76, 0.6, 0.45), Color(0.58, 0.42, 0.36),
]
const WAREHOUSE_COLORS := [
	Color(0.7, 0.66, 0.58), Color(0.55, 0.57, 0.58), Color(0.6, 0.42, 0.32), Color(0.75, 0.72, 0.64),
]
const HOUSE_COLORS := [
	Color(0.92, 0.9, 0.84), Color(0.85, 0.78, 0.62), Color(0.7, 0.78, 0.82), Color(0.9, 0.85, 0.6),
	Color(0.7, 0.42, 0.34), Color(0.78, 0.82, 0.72), Color(0.6, 0.66, 0.74), Color(0.88, 0.72, 0.6),
]
const AWNING_COLORS := [
	Color(0.7, 0.12, 0.1), Color(0.1, 0.35, 0.2), Color(0.12, 0.2, 0.4), Color(0.85, 0.7, 0.35),
	Color(0.1, 0.45, 0.45), Color(0.3, 0.3, 0.32),
]
const CROWNS := ["", "", "pyramid", "cap", "mast", "spire"]

var map := {"roads": [], "buildings": [], "areas": [], "trees": [], "props": [], "places": []}
var rng := RandomNumberGenerator.new()


static func generate() -> Dictionary:
	var gen := CityGen.new()
	gen._build()
	return gen.map


# --- The grid -------------------------------------------------------------

static func street_x(k: int) -> float:
	return (k + 0.5) * P


static func street_z(k: int) -> float:
	return (k + 0.5) * P


static func ns_width(k: int) -> float:
	return 24.0 if k in NS_PRIMARY else (20.0 if k in NS_SECONDARY else 15.0)


static func ew_width(k: int) -> float:
	return 24.0 if k in EW_PRIMARY else (20.0 if k in EW_SECONDARY else 15.0)


static func _kind(width: float) -> String:
	return "primary" if width >= 24.0 else ("secondary" if width >= 20.0 else "tertiary")


static func ns_name(k: int) -> String:
	match k:
		0: return "Main Street"
		1: return "State Street"
		-1: return "West Temple"
	return "%d00 East" % k if k > 0 else "%d00 West" % -k


static func ew_name(k: int) -> String:
	match k:
		-1: return "North Temple"
		0: return "South Temple"
	return "%d00 South" % k if k > 0 else "%d00 North" % -k


## Buildable area of block (i, j), inside the sidewalks. Block i sits between north-south
## streets i-1 and i, so block (0, 0) is Temple Square.
static func block_rect(i: int, j: int) -> Rect2:
	var x0 := street_x(i - 1) + ns_width(i - 1) * 0.5 + SIDEWALK
	var x1 := street_x(i) - ns_width(i) * 0.5 - SIDEWALK
	var z0 := street_z(j - 1) + ew_width(j - 1) * 0.5 + SIDEWALK
	var z1 := street_z(j) - ew_width(j) * 0.5 - SIDEWALK
	return Rect2(x0, z0, x1 - x0, z1 - z0)


static func zone(i: int, j: int) -> String:
	if i == 0 and j == 0:
		return "temple"
	if j == -3 and (i == 1 or i == 2):
		return "capitol"
	if i == -2 and j == 1:
		return "arena"
	if i == 2 and j == 5:
		return "civic"
	if i == -3 and j == 4:
		return "pioneer"
	if (i == 6 or i == 7) and j >= 10:
		return "liberty"
	if i >= -1 and i <= 2 and j >= 0 and j <= 4:
		return "core"
	if i >= -3 and i <= 4 and j >= -1 and j <= 7:
		return "ring"
	if i <= -4:
		return "industrial"
	return "residential"


## State Street stops short of the Capitol, so its two blocks merge into one lawn.
static func capitol_rect() -> Rect2:
	return block_rect(1, -3).merge(block_rect(2, -3))


static func liberty_rect() -> Rect2:
	return block_rect(6, 10).merge(block_rect(7, 13))


## Street k (north-south) has no pavement alongside block row j.
static func _ns_closed(k: int, j: int) -> bool:
	return (k == 1 and j == -3) or (k == 6 and j >= 10)


## Street k (east-west) has no pavement alongside block column i.
static func _ew_closed(k: int, i: int) -> bool:
	return k >= 10 and k <= 12 and (i == 6 or i == 7)


# --- Build ----------------------------------------------------------------

func _build() -> void:
	rng.seed = 1847
	_streets()
	for i in range(NS_RANGE.x + 1, NS_RANGE.y + 1):
		for j in range(EW_RANGE.x + 1, EW_RANGE.y + 1):
			var r := block_rect(i, j)
			match zone(i, j):
				"core": _core_block(r, i, j)
				"ring": _ring_block(r, i, j)
				"industrial": _industrial_block(r)
				"residential":
					if rng.randf() < 0.05:
						_park(r, "", [])
					else:
						_residential_block(r)
				"pioneer": _park(r, "Pioneer Park", [])
				"civic": _park(r, "Washington Square", Landmarks.keep_out("civic"))
				"temple": _park(r, "Temple Square", Landmarks.keep_out("temple"), 0.35)
				"arena":
					_area("parking", r)
					_place("The Arena", r)
				"capitol":
					if i == 1:
						_park(capitol_rect(), "State Capitol", Landmarks.keep_out("capitol"))
				"liberty":
					if i == 6 and j == 10:
						_liberty_park()
	Landmarks.add_to_map(map)


func _streets() -> void:
	for k in range(NS_RANGE.x, NS_RANGE.y + 1):
		var run := []
		for j in range(EW_RANGE.x, EW_RANGE.y + 1):
			if not run.is_empty() and _ns_closed(k, j):
				_street(ns_name(k), ns_width(k), run)
				run = []
			run.append(Vector2(street_x(k), street_z(j)))
		_street(ns_name(k), ns_width(k), run)
	for k in range(EW_RANGE.x, EW_RANGE.y + 1):
		var run := []
		for i in range(NS_RANGE.x, NS_RANGE.y + 1):
			if not run.is_empty() and _ew_closed(k, i):
				_street(ew_name(k), ew_width(k), run)
				run = []
			run.append(Vector2(street_x(i), street_z(k)))
		_street(ew_name(k), ew_width(k), run)
	# I-15 runs along the west side of town. North Temple crosses it out to the airport.
	map.roads.append(_road("I-15", "motorway", 28.0, [
		Vector2(I15_X, -1400), Vector2(I15_X, street_z(-1)), Vector2(I15_X, 3500)]))


func _street(street_name: String, width: float, pts: Array) -> void:
	if pts.size() >= 2:
		map.roads.append(_road(street_name, _kind(width), width, pts))


static func _road(road_name: String, kind: String, width: float, pts: Array) -> Dictionary:
	var arr := []
	for p in pts:
		arr.append([p.x, p.y])
	return {"name": road_name, "kind": kind, "width": width, "pts": arr}


# --- Downtown -------------------------------------------------------------

func _core_block(r: Rect2, i: int, j: int) -> void:
	var sig: Array = SIGNATURE.get(Vector2i(i, j), [-1])
	var lots := _split(r, 2, 2, 8.0)
	for li in lots.size():
		var lot: Rect2 = lots[li]
		if li == sig[0]:
			_tower(lot, sig[1], sig[2])
		elif rng.randf() < 0.55:
			_tower(lot, rng.randf_range(50.0, 105.0), CROWNS[rng.randi() % CROWNS.size()])
		elif rng.randf() < 0.3:
			_plaza(lot)
		else:
			_midrise(lot, r, rng.randf_range(18.0, 42.0))


func _tower(lot: Rect2, height: float, crown: String) -> void:
	# Podium fills the lot to hold the street wall; the tower rises out of it.
	var podium_h := rng.randf_range(8.0, 15.0)
	_building(_rect_poly(lot.grow(-1.5)), podium_h, {
		"mat": 1 if rng.randf() < 0.6 else 3, "col": _pick(STONE_COLORS)})
	var fp := lot.grow(-rng.randf_range(6.0, 10.0))
	if rng.randf() < 0.4:
		var cut := rng.randf_range(0.15, 0.3)
		if rng.randf() < 0.5:
			fp = fp.grow_individual(-fp.size.x * cut * 0.5, 0, -fp.size.x * cut * 0.5, 0)
		else:
			fp = fp.grow_individual(0, -fp.size.y * cut * 0.5, 0, -fp.size.y * cut * 0.5)
	var glass := rng.randf() < 0.6
	var col: Color = _pick(GLASS_TINTS) if glass else _pick(STONE_COLORS)
	var chamfer := rng.randf() < 0.3
	var tiers := rng.randi_range(1, 3)
	var fractions: Array = [[1.0], [0.65, 1.0], [0.5, 0.78, 1.0]][tiers - 1]
	var y0 := podium_h
	for t in tiers:
		var top := lerpf(podium_h, height, fractions[t])
		var poly := _chamfer_poly(fp, minf(fp.size.x, fp.size.y) * 0.18) if chamfer else _rect_poly(fp)
		var b := {"y0": y0, "mat": 2 if glass else 1, "col": col}
		if t == tiers - 1:
			b.crown = crown
		_building(poly, top, b)
		y0 = top
		fp = fp.grow(-rng.randf_range(2.5, 5.0))


func _midrise(lot: Rect2, block: Rect2, h: float) -> void:
	var brick := rng.randf() < 0.45
	var fp := lot.grow(-1.5)
	_building(_rect_poly(fp), h, {"mat": 3 if brick else 1, "col": _pick(BRICK_COLORS if brick else STONE_COLORS)})
	if rng.randf() < 0.6:
		_awnings(fp, block)


func _plaza(lot: Rect2) -> void:
	_area("green", lot.grow(-1.0))
	var x := lot.position.x + 6.0
	while x < lot.end.x - 4.0:
		for z in [lot.position.y + 6.0, lot.end.y - 6.0]:
			_tree(Vector2(x, z))
		x += 11.0


func _ring_block(r: Rect2, i: int, j: int) -> void:
	# Closer to the core = taller.
	var dist := maxf(absf(i - 0.5), absf(j - 2.0))
	var max_h := lerpf(38.0, 16.0, clampf((dist - 2.0) / 3.0, 0.0, 1.0))
	var cols := 3 if rng.randf() < 0.5 else 2
	for lot in _split(r, cols, 2, 4.0):
		var roll := rng.randf()
		if roll < 0.14:
			_area("parking", lot.grow(-1.0))
		elif roll < 0.2:
			_plaza(lot)
		else:
			_midrise(lot, r, rng.randf_range(10.0, max_h))


## Striped awnings over the storefronts on every side of fp that faces a street.
func _awnings(fp: Rect2, block: Rect2) -> void:
	var col_a: Color = _pick(AWNING_COLORS)
	var col_b := col_a.lightened(0.35) if rng.randf() < 0.5 else col_a
	for side in 4:
		var on_street: bool = [
			absf(fp.position.y - block.position.y) < 3.0, absf(fp.end.x - block.end.x) < 3.0,
			absf(fp.end.y - block.end.y) < 3.0, absf(fp.position.x - block.position.x) < 3.0,
		][side]
		if not on_street:
			continue
		var along_x: bool = side % 2 == 0
		var length := fp.size.x if along_x else fp.size.y
		var n := maxi(1, floori(length / 11.0))
		var seg := length / n
		for k in n:
			var t := (k + 0.5) * seg
			var c: Vector3
			match side:
				0: c = Vector3(fp.position.x + t, 3.3, fp.position.y - 0.9)
				1: c = Vector3(fp.end.x + 0.9, 3.3, fp.position.y + t)
				2: c = Vector3(fp.position.x + t, 3.3, fp.end.y + 0.9)
				_: c = Vector3(fp.position.x - 0.9, 3.3, fp.position.y + t)
			var size := Vector3(seg * 0.8, 0.3, 1.8) if along_x else Vector3(1.8, 0.3, seg * 0.8)
			var col := col_a if k % 2 == 0 else col_b
			map.props.append({"c": [c.x, c.y, c.z], "s": [size.x, size.y, size.z], "col": [col.r, col.g, col.b]})


# --- West side -----------------------------------------------------------

func _industrial_block(r: Rect2) -> void:
	for lot in _split(r, 1, 2, 10.0):
		_area("parking", lot.grow(-2.0))
		# Leave a truck apron along the south side of each lot.
		var fp := lot.grow_individual(-6.0, -6.0, -6.0, -20.0)
		var gable := rng.randf() < 0.35
		var col: Color = _pick(WAREHOUSE_COLORS)
		_building(_rect_poly(fp), rng.randf_range(8.0, 12.0), {"mat": 4, "col": col, "roof": "gable" if gable else ""})
		# Loading doors on the apron side.
		var x := fp.position.x + 8.0
		while x < fp.end.x - 6.0:
			map.props.append({"c": [x, 2.25, fp.end.y + 0.1], "s": [4.0, 4.5, 0.2], "col": [0.25, 0.26, 0.28]})
			x += 10.0


# --- Neighborhoods ---------------------------------------------------------

func _residential_block(r: Rect2) -> void:
	const SETBACK := 7.0
	# North and south rows run the full width; east and west rows fill between them.
	for north in [true, false]:
		var x := r.position.x + 8.0
		while x < r.end.x - 20.0:
			var w := rng.randf_range(10.0, 14.0)
			var d := rng.randf_range(10.0, 13.0)
			var z0 := r.position.y + SETBACK if north else r.end.y - SETBACK - d
			_house(Rect2(x, z0, w, d))
			x += w + rng.randf_range(8.0, 12.0)
	for west in [true, false]:
		var z := r.position.y + 32.0
		while z < r.end.y - 44.0:
			var w := rng.randf_range(10.0, 14.0)
			var d := rng.randf_range(10.0, 13.0)
			var x0 := r.position.x + SETBACK if west else r.end.x - SETBACK - d
			_house(Rect2(x0, z, d, w))
			z += w + rng.randf_range(8.0, 12.0)
	# Street trees in the front yards, and a few big ones out back.
	for edge in 4:
		var t := 10.0
		var length := r.size.x if edge % 2 == 0 else r.size.y
		while t < length - 10.0:
			var p: Vector2
			match edge:
				0: p = Vector2(r.position.x + t, r.position.y + 2.0)
				1: p = Vector2(r.end.x - 2.0, r.position.y + t)
				2: p = Vector2(r.position.x + t, r.end.y - 2.0)
				_: p = Vector2(r.position.x + 2.0, r.position.y + t)
			_tree(p)
			t += rng.randf_range(14.0, 20.0)
	var yard := r.grow(-34.0)
	for k in rng.randi_range(6, 12):
		_tree(Vector2(rng.randf_range(yard.position.x, yard.end.x), rng.randf_range(yard.position.y, yard.end.y)))


func _house(fp: Rect2) -> void:
	if rng.randf() < 0.1:
		# Little brick walk-up apartments sprinkled in.
		_building(_rect_poly(fp.grow(2.0)), rng.randf_range(10.0, 13.0), {"mat": 3, "col": _pick(BRICK_COLORS), "roof": "flat"})
		return
	var h := 4.5 if rng.randf() < 0.55 else 7.0
	_building(_rect_poly(fp), h, {"col": _pick(HOUSE_COLORS), "roof": "hip" if rng.randf() < 0.5 else "gable"})


# --- Parks ------------------------------------------------------------------

func _park(r: Rect2, park_name: String, avoid: Array, density := 0.6) -> void:
	_area("green", r)
	var x := r.position.x + 6.0
	while x < r.end.x - 4.0:
		var z := r.position.y + 6.0
		while z < r.end.y - 4.0:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			if rng.randf() < density and not avoid.any(func(a: Rect2) -> bool: return a.has_point(p)):
				_tree(p)
			z += 13.0
		x += 13.0
	if park_name != "":
		_place(park_name, r)


func _liberty_park() -> void:
	var r := liberty_rect()
	var pond_center := r.get_center() + Vector2(0, r.size.y * 0.15)
	var pond := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pond.append(pond_center + Vector2(cos(a) * 55.0, sin(a) * 30.0 * (1.0 + 0.15 * sin(a * 3.0))))
	_park(r, "Liberty Park", [Rect2(pond_center - Vector2(62, 38), Vector2(124, 76))], 0.55)
	map.areas.append({"kind": "water", "pts": Array(pond).map(func(p: Vector2) -> Array: return [p.x, p.y])})


## A named spot for the "where am I" readout: a cross through the middle of r.
func _place(place_name: String, r: Rect2) -> void:
	var c := r.get_center()
	map.places.append(_road(place_name, "place", 0.0, [c - Vector2(r.size.x * 0.35, 0), c + Vector2(r.size.x * 0.35, 0)]))
	map.places.append(_road(place_name, "place", 0.0, [c - Vector2(0, r.size.y * 0.35), c + Vector2(0, r.size.y * 0.35)]))


# --- Helpers ----------------------------------------------------------------

func _building(poly: PackedVector2Array, h: float, extra: Dictionary) -> void:
	var pts := []
	for p in poly:
		pts.append([p.x, p.y])
	var b := {"pts": pts, "h": h}
	if extra.has("col"):
		var c: Color = extra.col
		extra.col = [c.r, c.g, c.b]
	b.merge(extra)
	map.buildings.append(b)


func _area(kind: String, r: Rect2) -> void:
	var pts := []
	for p in _rect_poly(r):
		pts.append([p.x, p.y])
	map.areas.append({"kind": kind, "pts": pts})


func _tree(p: Vector2) -> void:
	map.trees.append([p.x, p.y])


func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


## cols x rows lots with gap meters between them.
static func _split(r: Rect2, cols: int, rows: int, gap: float) -> Array[Rect2]:
	var lots: Array[Rect2] = []
	var w := (r.size.x - gap * (cols - 1)) / cols
	var h := (r.size.y - gap * (rows - 1)) / rows
	for cy in rows:
		for cx in cols:
			lots.append(Rect2(r.position.x + cx * (w + gap), r.position.y + cy * (h + gap), w, h))
	return lots


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _chamfer_poly(r: Rect2, c: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c),
	])
