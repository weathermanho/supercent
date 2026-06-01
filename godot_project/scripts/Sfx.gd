extends Node
## Autoload. PROCEDURAL sound effects — synthesized into AudioStreamWAV buffers
## at boot, so the game ships with sound without any external audio assets.
## Call Sfx.play("name") from anywhere. A small pool of AudioStreamPlayers is
## round-robined so overlapping sounds don't cut each other off.

const MIX_RATE := 22050
const POOL_SIZE := 12

var _sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

	# Build the SFX bank.
	_sounds["fire"]        = _make(_sfx_fire())
	_sounds["core_break"]  = _make(_sfx_core_break())
	_sounds["block"]       = _make(_sfx_block())
	_sounds["crash"]       = _make(_sfx_crash())
	_sounds["tier_up"]     = _make(_sfx_tier_up())
	_sounds["giant_hit"]   = _make(_sfx_giant_hit())
	_sounds["giant_finish"]= _make(_sfx_giant_finish())
	_sounds["ult"]         = _make(_sfx_ult())
	_sounds["near_miss"]   = _make(_sfx_near_miss())
	_sounds["milestone"]   = _make(_sfx_milestone())
	_sounds["ui"]          = _make(_sfx_ui())


## Play a named sound. `pitch_var` randomizes pitch ±var for organic variety.
func play(name: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if not _sounds.has(name):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _sounds[name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * pitch_var
	p.play()


# ----- Encoding --------------------------------------------------------------

func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: float = clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


# ----- Synthesis primitives --------------------------------------------------

func _n(dur: float) -> int:
	return maxi(1, int(dur * MIX_RATE))


## Sine tone with exponential decay envelope.
func _tone(freq: float, dur: float, decay: float, amp: float = 0.7) -> PackedFloat32Array:
	var n := _n(dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var step := TAU * freq / float(MIX_RATE)
	for i in n:
		var t := float(i) / float(MIX_RATE)
		out[i] = sin(phase) * exp(-t * decay) * amp
		phase += step
	return out


## Frequency sweep f0 → f1 with decay.
func _sweep(f0: float, f1: float, dur: float, decay: float, amp: float = 0.7) -> PackedFloat32Array:
	var n := _n(dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(MIX_RATE)
		var f: float = lerpf(f0, f1, u)
		phase += TAU * f / float(MIX_RATE)
		out[i] = sin(phase) * exp(-t * decay) * amp
	return out


## Filtered noise burst (one-pole low-pass) with decay — for impacts/explosions.
func _noise(dur: float, decay: float, lp: float = 0.5, amp: float = 0.7) -> PackedFloat32Array:
	var n := _n(dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / float(MIX_RATE)
		var white := randf() * 2.0 - 1.0
		prev = lerpf(prev, white, lp)   # low-pass
		out[i] = prev * exp(-t * decay) * amp
	return out


## Mix several buffers (sum, padded to the longest), then soft-clip.
func _mix(buffers: Array) -> PackedFloat32Array:
	var maxn := 0
	for b in buffers:
		maxn = maxi(maxn, b.size())
	var out := PackedFloat32Array()
	out.resize(maxn)
	for b in buffers:
		for i in b.size():
			out[i] += b[i]
	for i in maxn:
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


# ----- The sound bank --------------------------------------------------------

func _sfx_fire() -> PackedFloat32Array:
	# Quick downward "pew" + air whoosh.
	return _mix([_sweep(620.0, 230.0, 0.16, 22.0, 0.5), _noise(0.10, 40.0, 0.7, 0.18)])

func _sfx_core_break() -> PackedFloat32Array:
	# Bright glassy two-tone ping + small shatter noise.
	return _mix([_tone(880.0, 0.18, 16.0, 0.45), _tone(1320.0, 0.16, 18.0, 0.30),
		_noise(0.12, 30.0, 0.85, 0.22)])

func _sfx_block() -> PackedFloat32Array:
	# Dull clank — missile bounced off unbreakable concrete.
	return _mix([_tone(180.0, 0.12, 30.0, 0.4), _noise(0.08, 45.0, 0.35, 0.25)])

func _sfx_crash() -> PackedFloat32Array:
	# Low thud + body noise.
	return _mix([_sweep(220.0, 70.0, 0.30, 14.0, 0.55), _noise(0.25, 16.0, 0.3, 0.4)])

func _sfx_tier_up() -> PackedFloat32Array:
	# Rising 3-note arpeggio — reward.
	var a := _tone(523.0, 0.10, 14.0, 0.4)
	var b := _tone(659.0, 0.10, 14.0, 0.4)
	var c := _tone(784.0, 0.16, 12.0, 0.45)
	var out := PackedFloat32Array()
	out.append_array(a); out.append_array(b); out.append_array(c)
	return out

func _sfx_giant_hit() -> PackedFloat32Array:
	return _mix([_sweep(300.0, 120.0, 0.28, 12.0, 0.55), _noise(0.22, 14.0, 0.4, 0.4)])

func _sfx_giant_finish() -> PackedFloat32Array:
	# Big layered boom — low sweep + long rumble noise + a bright crack.
	return _mix([_sweep(260.0, 50.0, 0.7, 6.0, 0.7), _noise(0.7, 7.0, 0.25, 0.55),
		_tone(900.0, 0.2, 14.0, 0.25)])

func _sfx_ult() -> PackedFloat32Array:
	# Charging rising whoosh into a bright pop.
	return _mix([_sweep(180.0, 1200.0, 0.45, 5.0, 0.5), _noise(0.5, 8.0, 0.6, 0.3),
		_tone(1500.0, 0.18, 12.0, 0.3)])

func _sfx_near_miss() -> PackedFloat32Array:
	# Fast airy swish.
	return _noise(0.18, 18.0, 0.8, 0.4)

func _sfx_milestone() -> PackedFloat32Array:
	return _mix([_tone(784.0, 0.12, 12.0, 0.4), _tone(1047.0, 0.16, 11.0, 0.4)])

func _sfx_ui() -> PackedFloat32Array:
	return _tone(660.0, 0.10, 16.0, 0.5)
