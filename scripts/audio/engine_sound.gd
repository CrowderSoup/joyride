class_name EngineSound
extends AudioStreamPlayer3D
## A synthesized engine (and tire squeal), so there are no audio files to ship. The owner
## sets rpm, load and slip every frame; this turns them into sound while running is on.
## A few harmonics of the firing frequency, a half-order "lope" for lumpy engines, a little
## cycle-to-cycle roughness, and some hiss.

# Voices. idle/redline are firing frequencies in Hz; lope is the half-order level (V-twins
# and V6s burble, inline-4s don't); rough is cycle-to-cycle jitter; bright is how much the
# upper harmonics come in under load.
const TRUCK := {"idle": 30.0, "redline": 170.0, "lope": 0.35, "rough": 0.12, "bright": 0.6, "db": -2.0}
const SEDAN := {"idle": 27.0, "redline": 200.0, "lope": 0.1, "rough": 0.06, "bright": 0.45, "db": -4.0}
const BIKE := {"idle": 16.0, "redline": 150.0, "lope": 0.6, "rough": 0.25, "bright": 0.8, "db": -2.0}
const PROP := {"idle": 22.0, "redline": 85.0, "lope": 0.3, "rough": 0.1, "bright": 0.7, "db": 2.0}

const MIX_RATE := 16000.0
const SQUEAL_HZ := 1150.0

var running := false
var rpm := 0.0       # 0 idle .. 1 redline
var load := 0.0      # throttle, 0..1
var slip := 0.0      # tire squeal, 0..1

var _voice: Dictionary
var _playback: AudioStreamGeneratorPlayback
var _buffer := PackedVector2Array()
var _level := 0.0
var _rpm := 0.0
var _load := 0.0
var _slip := 0.0
var _phase := 0.0
var _half := 0.0
var _squeal := 0.0
var _wobble := 0.0
var _amp := 1.0
var _noise := 0.0
var _rng := RandomNumberGenerator.new()


func _init(voice: Dictionary) -> void:
	_voice = voice
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.12
	stream = gen
	volume_db = voice.db
	unit_size = 10.0
	max_distance = 250.0
	position.y = 0.8


func _ready() -> void:
	play()
	_playback = get_stream_playback()


func _process(delta: float) -> void:
	# Fade in on start, out on shutdown; once silent, stop feeding it (it just plays nothing).
	_level = move_toward(_level, 1.0 if running else 0.0, delta * (3.0 if running else 1.5))
	if _level <= 0.0 or _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_buffer.resize(frames)
	var idle: float = _voice.idle
	var redline: float = _voice.redline
	var lope: float = _voice.lope
	var rough: float = _voice.rough
	var bright: float = _voice.bright
	# Parameters glide per buffer; fine at these frame sizes.
	_rpm = lerpf(_rpm, rpm, 1.0 - exp(-8.0 * delta))
	_load = lerpf(_load, load, 1.0 - exp(-10.0 * delta))
	_slip = lerpf(_slip, slip, 1.0 - exp(-12.0 * delta))
	var hz := lerpf(idle, redline, _rpm)
	var step := hz / MIX_RATE
	var gain := _level * (0.3 + 0.5 * _load) * (0.7 + 0.3 * _rpm)
	var upper := bright * (0.3 + 0.7 * _load)
	var squeal_gain := _slip * 0.3 * _level
	for i in frames:
		_phase += step
		if _phase >= 1.0:
			_phase -= 1.0
			_amp = 1.0 + _rng.randf_range(-rough, rough)
		_half = fmod(_half + step * 0.5, 1.0)
		var p := TAU * _phase
		var s := sin(p) * 0.55 + sin(2.0 * p + 0.4) * 0.3 * upper + sin(3.0 * p + 1.1) * 0.18 * upper
		s += sin(TAU * _half) * lope * 0.4
		_noise = lerpf(_noise, _rng.randf_range(-1.0, 1.0), 0.15)
		var out := (s * _amp + _noise * (0.08 + 0.15 * _load)) * gain
		if squeal_gain > 0.001:
			_wobble += 7.0 / MIX_RATE
			_squeal = fmod(_squeal + (SQUEAL_HZ + sin(TAU * _wobble) * 60.0) / MIX_RATE, 1.0)
			out += (sin(TAU * _squeal) + _noise * 0.5) * squeal_gain
		_buffer[i] = Vector2(out, out)
	_playback.push_buffer(_buffer)
