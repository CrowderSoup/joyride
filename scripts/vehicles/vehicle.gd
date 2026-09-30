class_name Vehicle
extends CharacterBody3D
## Anything you can get into. main.gd, the camera, the HUD and the maps only talk to
## vehicles through what's declared here; subclasses override the functions.

var display_name := "Vehicle"
var camera_distance := 9.0
var camera_height := 3.5
var first_person_offset := Vector3(-0.35, 1.2, -0.15)  # driver's eye, in model space
var enter_radius := 3.0                  # how close you have to walk to get in
var exit_offset := Vector3(-1.6, 0, 0)   # where you step out (driver's side); mirrored if blocked
var footprint := Vector2(0.9, 2.4)       # half width, half length: what plows into things

var active := false                      # someone's driving it
var visual := Node3D.new()
var engine: EngineSound                  # optional; runs while active
var _door: AudioStreamPlayer3D


func _init() -> void:
	add_child(visual)


## voice is one of EngineSound's presets.
func add_engine(voice: Dictionary) -> void:
	engine = EngineSound.new(voice)
	add_child(engine)


func play_door() -> void:
	if _door == null:
		_door = Sfx.player(self, -3.0)
		_door.stream = Sfx.door()
		_door.position.y = 1.0
	_door.pitch_scale = randf_range(0.9, 1.1)
	_door.play()


func get_speed() -> float:
	return 0.0


## Follow the interpolated model, including its slope tilt (and the plane's bank).
func first_person_transform() -> Transform3D:
	return visual.get_global_transform_interpolated() * Transform3D(Basis.IDENTITY, first_person_offset)


## Extra HUD readout (the plane's altitude and throttle).
func hud_extra() -> String:
	return ""


func set_driving(on: bool) -> void:
	active = on
	if engine:
		engine.running = on


func can_exit() -> bool:
	return absf(get_speed()) < 2.0


func stop() -> void:
	velocity = Vector3.ZERO


## Plowed through something: lose this fraction of your speed.
func bump(_fraction: float) -> void:
	pass


## Flipped, wedged, or crashed: set it back upright right where it is.
func unstick() -> void:
	var pos := global_position
	global_transform = Transform3D(Basis(Vector3.UP, global_rotation.y), Vector3(pos.x, Ground.height(pos.x, pos.z) + 0.2, pos.z))
	stop()
	reset_physics_interpolation()
