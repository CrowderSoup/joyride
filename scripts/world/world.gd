class_name World
extends Node3D
## Everything static: the land, the city, the airport and landmarks. The order matters -
## anything that levels the ground (the airport, landmarks, ponds) has to happen before
## anything is built on it.

var map: Dictionary
var airport: Airport
var streets: StreetIndex


func _init() -> void:
	name = "World"
	Ground.load_data()
	map = CityGen.generate()
	airport = Airport.new()
	airport.add_to_map(map)
	Landmarks.level_ground()
	CityBuilder.level_water(map)

	var intersections := CityBuilder.find_intersections(map.roads)
	add_child(Terrain.build())
	add_child(CityBuilder.build(map, intersections))
	add_child(Scenery.build(map, intersections))
	add_child(Landmarks.build())
	add_child(airport.build())
	streets = StreetIndex.new(map.roads + map.places)
