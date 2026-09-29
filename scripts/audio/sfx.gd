class_name Sfx
extends RefCounted
## Short one-shot sounds, synthesized once at first use.

const RATE := 22050

static var _cache := {}


## Car door: a low thump with a latch click on top.
static func door() -> AudioStreamWAV:
	return _cached("door", func() -> PackedFloat32Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1
		var n := int(RATE * 0.28)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			var thump := sin(TAU * (95.0 - 40.0 * t / 0.28) * t) * exp(-t * 22.0)
			var click := rng.randf_range(-1.0, 1.0) * exp(-t * 180.0) * 0.5
			out[i] = (thump + click) * 0.9
		return out)


## One footstep on pavement: a soft, short noise burst.
static func step() -> AudioStreamWAV:
	return _cached("step", func() -> PackedFloat32Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		var n := int(RATE * 0.09)
		var out := PackedFloat32Array()
		out.resize(n)
		var lp := 0.0
		for i in n:
			var t := float(i) / RATE
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
			out[i] = (lp * 1.6 + sin(TAU * 70.0 * t) * 0.4) * exp(-t * 55.0)
		return out)


## A positional player for these, parented to node. Replays cut the previous one off,
## which is what you want for footsteps and doors.
static func player(node: Node3D, volume_db := 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	node.add_child(p)
	return p


static func _cached(key: String, make: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		var samples: PackedFloat32Array = make.call()
		var data := PackedByteArray()
		data.resize(samples.size() * 2)
		for i in samples.size():
			data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = RATE
		wav.data = data
		_cache[key] = wav
	return _cache[key]
