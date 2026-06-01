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


## Tanh soft-saturation — adds harmonics + perceived loudness/punch. `drive`
## > 1 pushes harder into clipping for grit.
func _sat(buf: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] = tanh(buf[i] * drive)
	return buf


## SUB-BASS boom: a low sine whose pitch DROPS over the sound (the classic
## "whoomph" of an explosion), with a punchy fast attack and long body.
func _sub_boom(f0: float, f1: float, dur: float, decay: float, amp: float = 1.0) -> PackedFloat32Array:
	var n := _n(dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(MIX_RATE)
		var f: float = lerpf(f0, f1, sqrt(u))      # fast pitch drop early
		phase += TAU * f / float(MIX_RATE)
		# Fast attack (first 4ms) then exponential body.
		var atk: float = clampf(t / 0.004, 0.0, 1.0)
		out[i] = sin(phase) * atk * exp(-t * decay) * amp
	return out


## Band-ish noise body: white noise through a low-pass whose cutoff FALLS over
## time (explosion getting muffled as it dissipates). The workhorse of a
## believable boom.
func _noise_body(dur: float, decay: float, lp0: float, lp1: float, amp: float = 0.7) -> PackedFloat32Array:
	var n := _n(dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var u := float(i) / float(n)
		var t := float(i) / float(MIX_RATE)
		var lp: float = lerpf(lp0, lp1, u)
		var white := randf() * 2.0 - 1.0
		prev = lerpf(prev, white, lp)
		out[i] = prev * exp(-t * decay) * amp
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
	# Punchy launch: a quick pitch-drop body + bright transient click + air.
	return _sat(_mix([
		_sub_boom(420.0, 150.0, 0.16, 20.0, 0.7),
		_noise_body(0.13, 26.0, 0.85, 0.4, 0.35),
		_tone(900.0, 0.04, 60.0, 0.3),          # click transient
	]), 1.6)

func _sfx_core_break() -> PackedFloat32Array:
	# Concrete crack + glassy ring + debris noise tail.
	return _sat(_mix([
		_sub_boom(300.0, 90.0, 0.22, 18.0, 0.6),
		_noise_body(0.20, 20.0, 0.9, 0.3, 0.4),
		_tone(1180.0, 0.14, 18.0, 0.28),
		_tone(1760.0, 0.10, 22.0, 0.16),
	]), 1.7)

func _sfx_block() -> PackedFloat32Array:
	# Dull heavy clank — missile bounced off solid concrete.
	return _sat(_mix([
		_sub_boom(220.0, 120.0, 0.12, 30.0, 0.6),
		_noise_body(0.10, 38.0, 0.45, 0.2, 0.3),
		_tone(150.0, 0.10, 34.0, 0.4),
	]), 1.5)

func _sfx_crash() -> PackedFloat32Array:
	# Heavy impact: deep sub thump + crunchy body + metal tail.
	return _sat(_mix([
		_sub_boom(180.0, 45.0, 0.45, 9.0, 1.0),
		_noise_body(0.40, 11.0, 0.5, 0.12, 0.5),
		_tone(260.0, 0.18, 16.0, 0.3),
	]), 2.0)

func _sfx_tier_up() -> PackedFloat32Array:
	# Rising 3-note arpeggio with a little shine — reward.
	var a := _tone(523.0, 0.10, 13.0, 0.4)
	var b := _tone(659.0, 0.10, 13.0, 0.4)
	var c := _mix([_tone(784.0, 0.20, 10.0, 0.45), _tone(1568.0, 0.18, 12.0, 0.12)])
	var out := PackedFloat32Array()
	out.append_array(a); out.append_array(b); out.append_array(c)
	return _sat(out, 1.3)

func _sfx_giant_hit() -> PackedFloat32Array:
	# Big chunky impact on the giant.
	return _sat(_mix([
		_sub_boom(260.0, 70.0, 0.34, 11.0, 0.9),
		_noise_body(0.30, 12.0, 0.55, 0.15, 0.5),
		_tone(420.0, 0.14, 16.0, 0.25),
	]), 1.8)

func _sfx_giant_finish() -> PackedFloat32Array:
	# CINEMATIC explosion — deep long sub drop + huge muffling rumble + crack +
	# long debris tail. The ad's money sound.
	return _sat(_mix([
		_sub_boom(220.0, 32.0, 1.1, 3.5, 1.0),
		_sub_boom(120.0, 28.0, 0.9, 4.0, 0.8),     # second detuned layer
		_noise_body(1.1, 4.0, 0.6, 0.06, 0.7),     # long muffling rumble
		_noise_body(0.18, 26.0, 0.95, 0.5, 0.5),   # initial crack
		_tone(700.0, 0.18, 14.0, 0.2),
	]), 2.2)

func _sfx_ult() -> PackedFloat32Array:
	# Charge-up rising whoosh → detonation. Long + dramatic.
	return _sat(_mix([
		_sweep(120.0, 1400.0, 0.5, 4.0, 0.45),     # rising charge
		_sub_boom(300.0, 40.0, 0.9, 4.0, 0.9),     # the release boom
		_noise_body(0.9, 5.0, 0.7, 0.08, 0.55),
		_tone(1600.0, 0.16, 12.0, 0.25),
	]), 2.0)

func _sfx_near_miss() -> PackedFloat32Array:
	# Fast doppler-ish airy swish.
	return _sat(_mix([
		_noise_body(0.22, 14.0, 0.9, 0.5, 0.45),
		_sweep(700.0, 400.0, 0.18, 16.0, 0.2),
	]), 1.3)

func _sfx_milestone() -> PackedFloat32Array:
	return _sat(_mix([_tone(784.0, 0.14, 11.0, 0.4), _tone(1047.0, 0.18, 10.0, 0.4),
		_tone(1568.0, 0.16, 12.0, 0.15)]), 1.3)

func _sfx_ui() -> PackedFloat32Array:
	return _sat(_mix([_tone(660.0, 0.10, 15.0, 0.45), _tone(990.0, 0.08, 18.0, 0.2)]), 1.3)
