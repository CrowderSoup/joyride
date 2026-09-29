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


## Coin pickup: two quick bright notes, the classic "ding-ding".
static func coin() -> AudioStreamWAV:
	return _cached("coin", func() -> PackedFloat32Array:
		var n := int(RATE * 0.22)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var t := float(i) / RATE
			var hz := 988.0 if t < 0.06 else 1319.0  # B5, then E6
			var local := t if t < 0.06 else t - 0.06
			var tone := sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)
			out[i] = tone * exp(-local * 18.0) * 0.45
		return out)


## Something getting smashed. kind: "metal" (clang), "plastic" (thwack and rattle) or
## "wood" (crack and clatter).
static func crash(kind: String) -> AudioStreamWAV:
	return _cached("crash_" + kind, func() -> PackedFloat32Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = kind.hash()
		var n := int(RATE * 0.6)
		var out := PackedFloat32Array()
		out.resize(n)
		var lp := 0.0
		for i in n:
			var t := float(i) / RATE
			var noise := rng.randf_range(-1.0, 1.0)
			var v := 0.0
			match kind:
				"metal":
					# Inharmonic partials ring out over a hit.
					var ring := sin(TAU * 523.0 * t) + 0.7 * sin(TAU * 1187.0 * t) + 0.5 * sin(TAU * 1931.0 * t)
					v = ring * exp(-t * 7.0) * 0.35 + noise * exp(-t * 40.0) * 0.8
				"wood":
					lp = lerpf(lp, noise, 0.5)
					var knocks := exp(-fmod(t, 0.09) * 60.0) * exp(-t * 6.0)
					v = lp * (exp(-t * 30.0) * 1.2 + knocks * 0.6) + sin(TAU * 180.0 * t) * exp(-t * 25.0) * 0.5
				_:
					lp = lerpf(lp, noise, 0.25)
					var rattle := exp(-fmod(t + 0.03, 0.07) * 80.0) * exp(-t * 8.0)
					v = sin(TAU * (140.0 - 60.0 * t) * t) * exp(-t * 20.0) * 0.8 + lp * (exp(-t * 25.0) + rattle * 0.8)
			out[i] = clampf(v, -1.0, 1.0) * 0.8
		return out)


## Fire-and-forget positional sound at pos; the player frees itself when done.
static func play_at(parent: Node, stream: AudioStream, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 8.0
	p.max_distance = 120.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


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
