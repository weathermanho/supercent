extends Node3D
## Top-level coordinator for the "걸리버 모놀리스 관문" stage.
##
## The run: fly through a forest of colossal monoliths that ERUPT from the
## ground. Shoot the glowing red cores of BREAKABLE pillars to chain a combo —
## each tier grows the missile (size + blast + pierce + juice). Crash, or let
## the chain lapse, and the missile shrinks. Reach the giant with a big-enough
## missile to land the screen-erasing finish; arrive weak and you only chip it.

const AirPlaneScene := preload("res://scenes/AirPlane.tscn")
const MissleScene := preload("res://scenes/Missle.tscn")
const BuildingScene := preload("res://scenes/Building.tscn")
const TargetScene := preload("res://scenes/Target.tscn")
const PillarScript := preload("res://scripts/Pillar.gd")
const ParticleScript := preload("res://scripts/Particle.gd")
const WhiteSphereScript := preload("res://scripts/WhiteSphere.gd")
const GuideOverlayScript := preload("res://scripts/GuideOverlay.gd")
const ShockwaveRingScript := preload("res://scripts/ShockwaveRing.gd")
const SmokeBurstScript := preload("res://scripts/SmokeBurst.gd")

const STEP_TIME := 0.01
const PLANE_BASE_X := -100.0
## A giant only becomes lockable / hittable once it has loomed in to this x.
const GIANT_VULNERABLE_X := 950.0
const SPAWN_X := 4000.0

## Distances at which the run advances to the next stage. Sequential introduction
## of mechanics so the visceral feel ("sweat + duck") isn't lost in cognitive
## overload from the start:
##   1) 0–30   WARMUP  — ground breakables only, learn shoot+combo
##   2) 30–80  분별    — unbreakable ground pillars enter (must distinguish)
##   3) 80–150 반사    — ground SPIKES + first giant looms
##   4) 150–250 하늘   — CEILING pillars first appear + giant kill
##   5) 250+    혼돈   — FAKES + everything mixed, full chaos
const STAGE_BOUNDS := [30.0, 80.0, 150.0, 250.0]

@onready var camera: Camera3D = $Camera3D
@onready var shaker: Node = $Camera3D/Shaker
@onready var time_scaler: Node = $TimeScaler
@onready var director: Node = $Director
@onready var hud: CanvasLayer = $HUD
@onready var flash_overlay: ColorRect = $HUD/Flash
@onready var distance_label: Label = $HUD/Margin/VBox/DistanceLabel
@onready var best_label: Label = $HUD/Margin/VBox/BestLabel
@onready var energy_bar: ProgressBar = $HUD/Margin/VBox/EnergyBar
@onready var status_label: Label = $HUD/Margin/VBox/StatusLabel

var airplane: Node3D

var _missles: Array[Node3D] = []
var _pillars: Array[Node3D] = []
var _structures: Array[Node3D] = []
var _targets: Array[Node3D] = []        # giants only
var _particles: Array[Node3D] = []
var _white_spheres: Array[Node3D] = []
var _shockwaves: Array[Node3D] = []
var _smokes: Array[Node3D] = []
var _guide_overlay: Node3D

# Dynamic-camera state: an extra pull-back/up offset that eases in when a big
# monolith or the giant is looming, for a "scale-overwhelm" framing.
var _cam_pull: float = 0.0
var _cam_lift: float = 0.0

## Currently-active stage (1..5). Watched in _tick_playing to fire one-shot
## "stage advance" beats (e.g. the first ceiling pillar moment).
var _current_stage: int = 1

## Rhythmic pillar placement — gap positions follow a smooth sine-like sequence
## that the player can groove into instead of zig-zagging frantically. Wave
## and spike counters advance independently. Both reset on _start_game.
var _wave_beat: int = 0
var _spike_beat: int = 0
const GAP_SEQUENCE: Array[float] = [-150.0, -50.0, 50.0, 150.0, 50.0, -50.0]
const SPIKE_SEQUENCE: Array[float] = [0.0, 90.0, 180.0, 90.0, 0.0, -90.0, -180.0, -90.0]
## Maximum z shift the plane can reasonably traverse between waves at current
## scroll speed. Gap positions are clamped within this window from the plane's
## current z so a target is always *reachable*.
const MAX_GAP_REACH: float = 180.0

## Vertical weave pattern. Most waves are lateral (mode 0 = normal cluster
## with a gap). Every few waves a HOP wave (mode 1: low ground pillars across
## ALL lanes — plane flies OVER) or DUCK wave (mode 2: low-hanging ceiling
## pillars across all lanes — plane flies UNDER) interrupts the rhythm.
const ALT_SEQUENCE: Array[int] = [0, 0, 0, 1, 0, 0, 0, 2, 0, 0]
const ALT_NORMAL: int = 0
const ALT_HOP: int = 1     # fly OVER short cluster
const ALT_DUCK: int = 2    # fly UNDER hanging cluster

# --- Per-run stats (shown on the game-over screen) ----------------------------
var _max_combo_run: int = 0
var _max_tier_run: int = 0
var _giants_killed_run: int = 0

# --- Title / game-over overlays (built programmatically in _ready) ------------
var _title_layer: ColorRect
var _gameover_layer: ColorRect
var _tap_label: Label
var _gameover_title: Label
var _gameover_dist: Label
var _gameover_best: Label
var _gameover_combo: Label
var _gameover_giants: Label
var _gameover_tap: Label

# --- In-play HUD widgets (replace the legacy labels) --------------------------
var _hud_dist: Label
var _hud_dist_caption: Label
var _hud_best: Label
var _hud_combo: Label
var _hud_tier: Label
var _hud_heart_rects: Array = []
var _hud_ult_bg: ColorRect
var _hud_ult_bar: ColorRect
var _hud_ult_label: Label
var _seen_first_hit: bool = false
var _seen_ult_ready: bool = false

# --- Touch (mobile) controls -------------------------------------------------
## On touchscreens we show a twin-stick layout: a floating analog joystick on
## the left (push to steer), a FIRE button on the right (tap = one shot), and
## the ULT gauge bar (tap when full). PC keeps mouse-steer + click/SPACE.
var _touch_mode: bool = false
var _steer_y: float = 0.0
var _steer_z: float = 0.0
var _joy_base: Panel
var _joy_knob: Panel
var _fire_btn: Panel
var _ult_btn: Panel
var _joy_touch_index: int = -1
var _joy_vec: Vector2 = Vector2.ZERO
const JOY_RADIUS := 95.0
const STEER_SPEED := 330.0       # world units/sec at full stick deflection


func _ready() -> void:
	GameConfig.reset_to_defaults()
	director.reset()
	_current_stage = 1
	# Register a custom "fire_ult" action bound to SPACE + right-click so SPACE
	# can't be consumed by UI defaults or focus elsewhere — this guarantees
	# the press reaches us via is_action_pressed.
	if not InputMap.has_action("fire_ult"):
		InputMap.add_action("fire_ult")
		var ev_space := InputEventKey.new()
		ev_space.keycode = KEY_SPACE
		InputMap.action_add_event("fire_ult", ev_space)
		var ev_rmb := InputEventMouseButton.new()
		ev_rmb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("fire_ult", ev_rmb)
	_max_combo_run = 0
	_max_tier_run = 0
	_giants_killed_run = 0

	airplane = AirPlaneScene.instantiate()
	airplane.position = Vector3(PLANE_BASE_X, GameConfig.plane_default_height, 0.0)
	airplane.scale = Vector3.ONE * GameConfig.plane_scale
	add_child(airplane)

	_guide_overlay = GuideOverlayScript.new()
	add_child(_guide_overlay)

	_update_camera()

	# No background scenery — the world is an empty concrete stage so each
	# pillar emergence is the only event. Theatrical, image.png-clean.
	_prime_opening()

	# Containers around the run: title screen first, then game-over recap.
	# Each frames the run so it doesn't feel like a demo that just starts and
	# stops mid-air.
	_build_title_overlay()
	_build_gameover_overlay()
	_build_play_hud()
	_hide_legacy_labels()

	# Touchscreen? Use the on-screen twin-stick controls.
	_touch_mode = DisplayServer.is_touchscreen_available()
	_steer_y = GameConfig.plane_default_height
	_build_touch_controls()

	_show_title()


func _prime_opening() -> void:
	# Stage 1 (워밍업) seed: two GROUND side-lane colossi for scale presence
	# (purely framing — they're far in z, not in the dodge lane) plus a few
	# easy breakable normals so the player learns "shoot red core, combo grows
	# missile" in the first 2 seconds. No ceiling, no unbreakable, no spike.
	_spawn_colossus(false, 2600.0, -1.0, false)
	_spawn_colossus(false, 3800.0, 1.0, false)
	for i in 4:
		var z: float = -150.0 + randf() * 300.0
		_spawn_pillar(PillarScript.Kind.NORMAL, true, 1300.0 + i * 600.0, z, false)


func _process(delta: float) -> void:
	var dt_ms: float = delta * 1000.0 * GameConfig.time_scale

	# Pillars can queue_free themselves (after the shatter-collapse tween) so
	# clean up stale references ONCE here before any system iterates _pillars
	# this frame. Without this, _update_camera / _fly_missles / etc. can poke
	# a freed node.
	_filter_invalid_pillars()

	if _touch_mode:
		# Mobile: analog joystick PUSHES the steer target (direction + magnitude).
		# Release → stick centres → plane settles. Firing is manual (FIRE button).
		if _joy_touch_index == -1:
			_recenter_knob()    # keep knob parked on the base while idle
		if GameConfig.status == GameConfig.STATUS_PLAYING:
			_steer_z = clampf(_steer_z + _joy_vec.x * STEER_SPEED * delta, -200.0, 200.0)
			_steer_y = clampf(_steer_y - _joy_vec.y * STEER_SPEED * delta,
				GameConfig.plane_default_height - GameConfig.plane_amp_height,
				GameConfig.plane_default_height + GameConfig.plane_amp_height)
		airplane.set_world_target(Vector3(PLANE_BASE_X, _steer_y, _steer_z))
	else:
		# PC: steer toward the camera-projected mouse cursor.
		airplane.set_mouse_pos(_get_normalized_mouse())
		airplane.set_world_target(_get_world_cursor())

	if GameConfig.status == GameConfig.STATUS_PLAYING:
		_tick_playing(dt_ms)
		_fly_missles(dt_ms)
		_move_pillars(dt_ms)
		_move_targets(dt_ms)
	elif GameConfig.status == GameConfig.STATUS_GAME_OVER:
		_tick_falling()
	# STATUS_TITLE: world is frozen — the airplane idles in place. Vfx still
	# decay below so any leftover smoke fades.

	_move_structures(dt_ms)
	_update_white_spheres(dt_ms)
	_update_particles(dt_ms)
	_update_shockwaves(dt_ms)
	_update_smokes(dt_ms)

	_update_camera()
	_update_aim_overlay()
	_update_hud()
	_update_tap_pulse()


## Subtle pulse on the "TAP TO START" / "TAP TO RETRY" labels so the player
## sees they're waiting for input.
func _update_tap_pulse() -> void:
	var a: float = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.003))
	if _tap_label != null and _tap_label.visible:
		_tap_label.modulate.a = a
	if _gameover_tap != null and _gameover_tap.visible:
		_gameover_tap.modulate.a = a


func _tick_playing(dt_ms: float) -> void:
	var delta_s: float = dt_ms / 1000.0

	# Drive stage-based pacing: stage 1 sparse+slow → stage 5 dense+fast.
	var stage_idx: int = clampi(_current_stage - 1, 0, GameConfig.stage_spawn_intervals.size() - 1)
	var spawn_interval: int = GameConfig.stage_spawn_intervals[stage_idx]
	GameConfig.ennemies_speed = GameConfig.base_ennemies_speed * GameConfig.stage_speed_mults[stage_idx]

	var d_int := floori(GameConfig.distance)

	if d_int % GameConfig.distance_for_speed_update == 0 and d_int > GameConfig.speed_last_update:
		GameConfig.speed_last_update = d_int
		GameConfig.target_base_speed += GameConfig.increment_speed_by_time * dt_ms

	# Pillar-wave / giant spawn tick (was enemy spawn).
	if d_int % spawn_interval == 0 and d_int > GameConfig.ennemy_last_spawn:
		GameConfig.ennemy_last_spawn = d_int
		if director.consume_giant_due():
			_construct_giant()
		else:
			_construct_pillar_wave()

	if d_int % GameConfig.distance_for_level_update == 0 and d_int > GameConfig.level_last_update:
		GameConfig.level_last_update = d_int
		GameConfig.level += 1
		GameConfig.target_base_speed = GameConfig.init_speed + GameConfig.increment_speed_by_level * GameConfig.level

	GameConfig.distance += GameConfig.speed * dt_ms * GameConfig.ratio_speed_distance
	GameConfig.energy -= GameConfig.speed * dt_ms * GameConfig.ratio_speed_energy
	GameConfig.energy = maxf(0.0, GameConfig.energy)
	GameConfig.tick_combo(delta_s)

	# Stage-advance beat (one-shot per crossing).
	var stage_now: int = _stage_for_distance(GameConfig.distance)
	if stage_now != _current_stage:
		_on_stage_advance(_current_stage, stage_now)
		_current_stage = stage_now

	if GameConfig.energy < 1.0 or GameConfig.hp <= 0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
		_on_game_over()

	GameConfig.base_speed += (GameConfig.target_base_speed - GameConfig.base_speed) * dt_ms * 0.02
	GameConfig.speed = GameConfig.base_speed * GameConfig.plane_speed


func _tick_falling() -> void:
	for p in _particles:
		p.queue_free()
	_particles.clear()


# ----- Camera ----------------------------------------------------------------

## Chase cam behind + above the plane, looking forward. A dynamic pull-back/lift
## eases in when a colossus or giant looms, dramatizing the scale contrast.
func _update_camera() -> void:
	var p: Vector3 = airplane.position

	# Target extra offset from the biggest looming thing ahead.
	var want_pull: float = 0.0
	var want_lift: float = 0.0
	for pl in _pillars:
		if pl.kind == PillarScript.Kind.COLOSSUS and pl.is_solid_hazard():
			var ahead: float = pl.global_position.x - p.x
			if ahead > 0.0 and ahead < 2200.0:
				var prox: float = 1.0 - ahead / 2200.0
				want_pull = maxf(want_pull, 150.0 * prox)
				want_lift = maxf(want_lift, 70.0 * prox)
	for g in _targets:
		if g.is_giant and g.position.x > 0.0 and g.position.x < 2400.0:
			var prox2: float = clampf(1.0 - g.position.x / 2400.0, 0.0, 1.0)
			want_pull = maxf(want_pull, 220.0 * prox2)
			want_lift = maxf(want_lift, 110.0 * prox2)

	_cam_pull += (want_pull - _cam_pull) * 0.05
	_cam_lift += (want_lift - _cam_lift) * 0.05

	# Camera barely tracks the plane (Y and Z) and look_at is FIXED — so the
	# plane really moves up/down/left/right on screen instead of being pinned
	# to centre. Camera tilts naturally with plane y because cam_y moves but
	# look_y doesn't.
	const CAM_FOLLOW := 0.15
	var cam_y: float = GameConfig.plane_default_height + 55.0 + _cam_lift \
		+ (p.y - GameConfig.plane_default_height) * CAM_FOLLOW
	var look_y: float = GameConfig.plane_default_height - 10.0
	var cam_z: float = p.z * CAM_FOLLOW
	camera.position = Vector3(PLANE_BASE_X - 230.0 - _cam_pull, cam_y, cam_z)
	camera.look_at(Vector3(PLANE_BASE_X + 1400.0, look_y, 0.0), Vector3.UP)
	shaker.refresh_base()


# ----- Pillars ---------------------------------------------------------------

## Routes each wave by current stage. Each stage unlocks new pillar mechanics:
## earlier stages stay clean so the player can *learn one thing at a time*.
func _construct_pillar_wave() -> void:
	match _stage_for_distance(GameConfig.distance):
		1: _wave_warmup()
		2: _wave_discern()
		3: _wave_reflex()
		4: _wave_sky()
		_: _wave_chaos()


## Stage 1 — WARMUP. Single breakable ground pillar at a time. Goal: teach the
## "shoot red core → missile grows" loop in 1-2 seconds. No threat variety yet.
func _wave_warmup() -> void:
	var z: float = -180.0 + randf() * 360.0
	var x: float = SPAWN_X + randf() * 200.0
	# Even a single warmup spawn re-tries z if a stale unbreakable would mask it.
	for attempt in 5:
		if not _has_blocker_for_breakable_at(x, z):
			break
		z = -180.0 + randf() * 360.0
	_spawn_pillar(PillarScript.Kind.NORMAL, true, x, z, false)


## Stage 2 — 분별. Unbreakable ground pillars enter; player must distinguish
## "red-core vs no-core" in real time. Small clusters, occasional side colossus.
func _wave_discern() -> void:
	var r: float = randf()
	if r < 0.25:
		_spawn_colossus(false, SPAWN_X, 0.0, false)
	if r < 0.7:
		_spawn_normal_cluster(2 + int(randf() * 2.0), false)
	else:
		# A pair of normals, one breakable, one not — clean compare-and-pick beat.
		# Place the breakable in a lane that's not blocked by a stale unbreakable.
		var z_break: float = -150.0 + randf() * 120.0
		for attempt in 5:
			if not _has_blocker_for_breakable_at(SPAWN_X, z_break):
				break
			z_break = -200.0 + randf() * 400.0
		var z_solid: float = 30.0 + randf() * 120.0
		_spawn_pillar(PillarScript.Kind.NORMAL, true, SPAWN_X, z_break, false)
		_spawn_pillar(PillarScript.Kind.NORMAL, false, SPAWN_X + 180.0, z_solid, false)


## Stage 3 — 반사. SPIKES (fast, short-telegraph) unlock — reaction layer. First
## giant looms during this stage. Still ground-only.
func _wave_reflex() -> void:
	var r: float = randf()
	if r < 0.4:
		_spawn_spike_line(2 + int(randf() * 2.0), false)
	elif r < 0.75:
		_spawn_normal_cluster(3 + int(randf() * 2.0), false)
	else:
		_spawn_colossus(false, SPAWN_X, 0.0, false)
		_spawn_spike_line(2, false)


## Stage 4 — 하늘. CEILING pillars first appear — the "head-duck" moment. Giant
## kill happens here. Ground rate stays high; ceiling rate moderate so the new
## axis lands hard each time it appears.
func _wave_sky() -> void:
	var r: float = randf()
	if r < 0.35:
		_spawn_normal_cluster(3 + int(randf() * 2.0), true)
	elif r < 0.65:
		_spawn_spike_line(2 + int(randf() * 2.0), true)
	else:
		_spawn_colossus(randf() < 0.3, SPAWN_X, 0.0, true)
		_spawn_normal_cluster(2, true)


## Stage 5 — 혼돈. FAKES enter, formations stack, everything mixed at max
## density. Survival mode. This is where best-distance is earned.
func _wave_chaos() -> void:
	var r: float = randf()
	if r < 0.3:
		_spawn_normal_cluster(4 + int(randf() * 2.0), true)
		_spawn_spike_line(2 + int(randf() * 2.0), true)
	elif r < 0.55:
		_spawn_pillar(PillarScript.Kind.FAKE, randf() < 0.4, SPAWN_X, -80.0 + randf() * 160.0, randf() < 0.3)
		_spawn_normal_cluster(4, true)
	elif r < 0.8:
		_spawn_colossus(true, SPAWN_X, 0.0, true)
		_spawn_spike_line(3, true)
	else:
		_spawn_pillar(PillarScript.Kind.FAKE, false, SPAWN_X, -100.0 + randf() * 200.0, randf() < 0.35)
		_spawn_spike_line(2, true)
		_spawn_normal_cluster(3, true)


func _stage_for_distance(d: float) -> int:
	var i: int = 0
	for b in STAGE_BOUNDS:
		if d >= b:
			i += 1
	return i + 1


## Fired once when the run crosses into a new stage. Every stage entry shows
## a big "STAGE N: NAME" beat so the run feels like it's progressing through
## acts, not just an endless treadmill. Stage 4 gets the extra ceiling-pillar
## moment + camera kick on top.
func _on_stage_advance(_old: int, new_stage: int) -> void:
	var stage_names: Array = [
		"",                  # stage 1 is the opening — no banner
		"STAGE 2: DISCERN",
		"STAGE 3: REFLEX",
		"STAGE 4: SKY",
		"STAGE 5: CHAOS",
	]
	var stage_subs: Array = [
		"",
		"red core only — ignore the rest",
		"spikes incoming · stay sharp",
		"watch the ceiling",
		"survive · everything mixed",
	]
	var stage_colors: Array = [
		Color(1, 1, 1, 1),
		Color(0.95, 0.95, 0.65),
		Color(1.0, 0.78, 0.35),
		Color(0.75, 0.85, 1.0),
		Color(1.0, 0.45, 0.30),
	]
	var idx: int = clampi(new_stage - 1, 0, stage_names.size() - 1)
	if stage_names[idx] != "":
		_show_moment(stage_names[idx], stage_colors[idx], 80, stage_subs[idx])
		shaker.shake(GameConfig.shake_hit_intensity * 0.8, 0.18)
		flash_overlay.flash(0.16, 0.20, false)

	if new_stage == 4:
		shaker.shake(GameConfig.shake_hit_intensity * 1.4, 0.35)
		# Force-spawn the first ceiling moment: a side-lane hanging colossus,
		# guaranteed not in the dodge lane so it reads as "wow" not as
		# "unfair death". Player learns ceiling exists, ducks instinctively.
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var z: float = side * (340.0 + randf() * 130.0)
		_spawn_pillar(PillarScript.Kind.COLOSSUS, false, SPAWN_X - 400.0, z, true)


## RHYTHMIC normal cluster — most waves leave a lateral gap (mode 0). Some
## waves are HOP (mode 1: short ground cluster across ALL lanes, plane flies
## over) or DUCK (mode 2: hanging cluster across all lanes, plane flies under)
## so vertical weaving becomes part of the rhythm too.
func _spawn_normal_cluster(count: int, allow_ceiling: bool = true) -> void:
	var alt_mode: int = ALT_SEQUENCE[_wave_beat % ALT_SEQUENCE.size()]
	if alt_mode == ALT_HOP:
		_wave_beat += 1
		_spawn_hop_wave()
		return
	if alt_mode == ALT_DUCK:
		_wave_beat += 1
		_spawn_duck_wave()
		return

	var lanes: Array[float] = [-200.0, -120.0, -45.0, 45.0, 120.0, 200.0]
	var plane_z: float = airplane.position.z

	# Beat-driven gap z. Clamp within reach of the plane so it's always
	# physically dodgeable in the time available.
	var beat_z: float = GAP_SEQUENCE[_wave_beat % GAP_SEQUENCE.size()]
	_wave_beat += 1
	if absf(beat_z - plane_z) > MAX_GAP_REACH:
		beat_z = plane_z + MAX_GAP_REACH * signf(beat_z - plane_z)

	# Pick the lane nearest the beat_z as the open gap.
	var gap_idx: int = 0
	var best_d: float = INF
	for i in lanes.size():
		var d: float = absf(lanes[i] - beat_z)
		if d < best_d:
			best_d = d
			gap_idx = i

	# Collect remaining lanes in z order (left → right).
	var available: Array = []
	for i in lanes.size():
		if i != gap_idx:
			available.append(lanes[i])

	# Cluster breakables in consecutive lanes so a single sweep chains combos.
	var n_breakable: int = mini(int(round(float(count) * 0.55)), available.size() - 1)
	n_breakable = maxi(n_breakable, 1)
	var cluster_start: int = int(randf() * maxi(1, available.size() - n_breakable + 1))

	for i in mini(count, available.size()):
		var z: float = available[i]
		var x: float = SPAWN_X + randf() * 240.0
		var want_breakable: bool = (i >= cluster_start) and (i < cluster_start + n_breakable)
		# LOS safety using actual depth (catches fat-pillar shadows).
		if want_breakable and _has_blocker_for_breakable_at(x, z, 100.0):
			want_breakable = false
		var from_ceiling: bool = allow_ceiling and randf() < 0.35
		_spawn_pillar(PillarScript.Kind.NORMAL, want_breakable, x, z, from_ceiling)


## RHYTHMIC spike line — z follows SPIKE_SEQUENCE (sine wave traversing the
## corridor). Plane weaves with it. Each spike clamped within plane reach so
## the cascade is always passable.
func _spawn_spike_line(count: int, allow_ceiling: bool = true) -> void:
	var plane_z: float = airplane.position.z
	for i in count:
		var beat_z: float = SPIKE_SEQUENCE[(_spike_beat + i) % SPIKE_SEQUENCE.size()]
		if absf(beat_z - plane_z) > MAX_GAP_REACH:
			beat_z = plane_z + MAX_GAP_REACH * signf(beat_z - plane_z)
		var z: float = clampf(beat_z, -190.0, 190.0)
		var x: float = SPAWN_X + i * 220.0
		var want_breakable: bool = randf() < 0.7
		if want_breakable and _has_blocker_for_breakable_at(x, z, 50.0):
			want_breakable = false
		var from_ceiling: bool = allow_ceiling and randf() < 0.35
		_spawn_pillar(PillarScript.Kind.SPIKE, want_breakable, x, z, from_ceiling)
	_spike_beat += count


## Colossi: an UNBREAKABLE one looms from a SIDE lane (frames the corridor,
## doesn't bury the camera). A BREAKABLE one stands roughly center so its core
## is inside the plane's reachable z range — otherwise the player would see a
## target they can't physically line up on. When `allow_ceiling`, ~30% of side
## colossi hang from the ceiling (image.png motif).
func _spawn_colossus(breakable: bool, x: float, side: float, allow_ceiling: bool = true) -> void:
	var z: float
	if breakable:
		z = -120.0 + randf() * 240.0   # inside plane reach (±~120)
	else:
		var s: float = side
		if absf(s) < 0.5:
			s = -1.0 if randf() < 0.5 else 1.0
		z = s * (340.0 + randf() * 130.0)
	var from_ceiling: bool = allow_ceiling and (not breakable) and randf() < 0.3
	_spawn_pillar(PillarScript.Kind.COLOSSUS, breakable, x, z, from_ceiling)


func _spawn_pillar(kind: int, breakable: bool, x: float, z: float, from_ceiling: bool = false,
		h_override: float = 0.0) -> void:
	var p: Node3D = PillarScript.new()
	p.configure(kind, breakable, from_ceiling, h_override)
	add_child(p)
	_pillars.append(p)
	p.position = Vector3(x, p.position.y, z)


## HOP wave — a short ground cluster filling every lane. There is NO lateral
## gap; the player must FLY OVER by climbing the plane to a higher altitude.
func _spawn_hop_wave() -> void:
	_show_moment("HOP!", Color(0.7, 0.95, 1.0), 56, "climb over")
	var lanes: Array[float] = [-200.0, -100.0, 0.0, 100.0, 200.0]
	for z in lanes:
		var h_force: float = 240.0 + randf() * 40.0   # top y ≈ 130
		_spawn_pillar(PillarScript.Kind.NORMAL, false,
			SPAWN_X + randf() * 200.0, z, false, h_force)


## DUCK wave — a hanging ceiling cluster filling every lane. NO lateral gap;
## the player must FLY UNDER by dropping the plane to a low altitude.
func _spawn_duck_wave() -> void:
	_show_moment("DUCK!", Color(1.0, 0.85, 0.5), 56, "drop under")
	var lanes: Array[float] = [-200.0, -100.0, 0.0, 100.0, 200.0]
	for z in lanes:
		var h_force: float = 360.0 + randf() * 30.0   # bottom y ≈ 80
		_spawn_pillar(PillarScript.Kind.NORMAL, false,
			SPAWN_X + randf() * 200.0, z, true, h_force)


## Would a BREAKABLE spawned at (target_x, target_z) be masked by an existing
## UNBREAKABLE pillar in the same z lane closer to the plane? Uses each
## pillar's ACTUAL d (depth) instead of a fixed lane tolerance, so a fat
## colossus correctly shadows breakables in adjacent lanes that would
## otherwise read as "different lane".
func _has_blocker_for_breakable_at(target_x: float, target_z: float, target_d: float = 80.0) -> bool:
	const X_LOOK_AHEAD := 2200.0
	for pl in _pillars:
		if not is_instance_valid(pl):
			continue
		if pl.breakable:
			continue
		if absf(pl.global_position.z - target_z) > pl.d * 0.5 + target_d * 0.5 + 10.0:
			continue
		if pl.global_position.x >= target_x:
			continue
		if target_x - pl.global_position.x > X_LOOK_AHEAD:
			continue
		return true
	return false


## Drop any freed pillar references so the rest of the frame only ever
## iterates valid nodes. Called at the top of _process.
func _filter_invalid_pillars() -> void:
	var i: int = _pillars.size() - 1
	while i >= 0:
		if not is_instance_valid(_pillars[i]):
			_pillars.remove_at(i)
		i -= 1


func _move_pillars(dt_ms: float) -> void:
	# Plane's "swept volume" — the box ahead of the plane representing where
	# it WILL physically be. Any pillar AABB-overlapping this box is on a
	# collision course (threat) and will glow red. Same z/y math as the actual
	# crash check, just extended forward in x.
	const SWEEP_LEN: float = 2500.0
	const SWEEP_HALF_Y: float = 22.0
	const SWEEP_HALF_Z: float = 30.0
	var p: Vector3 = airplane.position
	var sweep_x_min: float = p.x
	var sweep_x_max: float = p.x + SWEEP_LEN
	var sweep_y_min: float = p.y - SWEEP_HALF_Y
	var sweep_y_max: float = p.y + SWEEP_HALF_Y
	var sweep_z_min: float = p.z - SWEEP_HALF_Z
	var sweep_z_max: float = p.z + SWEEP_HALF_Z

	var to_remove: Array[int] = []
	for i in _pillars.size():
		var pl := _pillars[i]
		# A pillar may have queue_free'd itself after its shatter collapse —
		# skip + collect for removal so we don't poke a freed node.
		if not is_instance_valid(pl):
			to_remove.append(i)
			continue
		var alive: bool = pl.step(dt_ms, airplane.position.x)

		# Threat check — does this pillar overlap the plane's swept volume?
		var is_threat: bool = false
		if pl.is_solid_hazard():
			var pl_x_min: float = pl.global_position.x - pl.w * 0.5
			var pl_x_max: float = pl.global_position.x + pl.w * 0.5
			var pl_z_min: float = pl.global_position.z - pl.d * 0.5
			var pl_z_max: float = pl.global_position.z + pl.d * 0.5
			if pl_x_max > sweep_x_min and pl_x_min < sweep_x_max \
			and pl_z_max > sweep_z_min and pl_z_min < sweep_z_max \
			and pl.emerged_top_y > sweep_y_min and pl.emerged_bottom_y < sweep_y_max:
				is_threat = true
		pl.set_threat(is_threat)

		# Eruption punch — a spike snapping up kicks the camera.
		if pl.consume_erupt():
			# SPIKE erupt: no shake (the snap is already visually loud, and
			# spikes fire frequently → shake fatigue). COLOSSUS erupt: half the
			# previous trauma — keeps the "looming" beat without tiring the eye.
			if pl.kind == PillarScript.Kind.COLOSSUS:
				shaker.shake(GameConfig.shake_hit_intensity * 0.55, 0.2)
			_spawn_dust(Vector3(pl.global_position.x, PillarScript.GROUND_Y + 6.0, pl.global_position.z), pl.w)

		# Plane crash — vertical check uses both top AND bottom so hanging
		# ceiling pillars (high up) don't false-trigger.
		if alive and pl.is_solid_hazard() and GameConfig.crash_iframes <= 0.0:
			if absf(pl.global_position.x - airplane.position.x) < pl.w * 0.5 + 28.0 \
			and absf(pl.global_position.z - airplane.position.z) < pl.d * 0.5 + 28.0 \
			and airplane.position.y < pl.emerged_top_y + 26.0 \
			and airplane.position.y > pl.emerged_bottom_y - 26.0:
				_on_crash(pl)

		# Near-miss bonus — pillar that was a threat at some point during its
		# flight has just passed the plane without colliding. Reward the skilled
		# dodge with +1 combo bonus + "Close!" moment.
		if alive and pl.was_threat_ever and not pl.near_miss_awarded \
		and pl.global_position.x < airplane.position.x - pl.w * 0.5:
			pl.near_miss_awarded = true
			_on_near_miss(pl)

		if not alive:
			to_remove.append(i)
	_cleanup(to_remove, _pillars)


## Successful dodge of a previously-threatening pillar. Awards bonus combo +
## a short "Close!" moment. Slight ult charge bump as well so a clean flying
## run is meaningfully rewarded.
func _on_near_miss(pl: Node3D) -> void:
	GameConfig.register_core_hit()           # +1 combo (uses same machinery)
	if GameConfig.combo > _max_combo_run:
		_max_combo_run = GameConfig.combo
	_bump_combo_widget()
	_show_combo_tick()
	_show_moment("Close!", Color(0.7, 1.0, 0.85), 44)
	_add_ultimate_charge(GameConfig.ultimate_charge_per_kill * 0.4)
	Sfx.play("near_miss", -8.0)


func _on_crash(pl: Node3D) -> void:
	GameConfig.hp -= 1
	_animate_heart_lost(GameConfig.hp)
	GameConfig.reset_combo()
	GameConfig.crash_iframes = GameConfig.crash_iframes_max

	# Knock the plane away from the pillar.
	var diff: Vector3 = airplane.position - pl.global_position
	var dl: float = maxf(diff.length(), 0.001)
	GameConfig.plane_collision_speed_x = 140.0 * diff.z / dl
	GameConfig.plane_collision_speed_y = 90.0 * (1.0 if diff.y >= 0.0 else -1.0)

	# Crash shake — minimal. Flash + hitstop + heart anim do the heavy lifting;
	# adding much shake on top fatigued the eye.
	shaker.shake(GameConfig.shake_hit_intensity * 0.5, 0.12)
	time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
	flash_overlay.flash(0.35, 0.12)   # warm/red damage flash
	_spawn_explosion(airplane.position, SmokeBurstScript.Kind.PLANE_HIT, 1.0)
	Sfx.play("crash", -2.0)

	if GameConfig.hp <= 0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
		_on_game_over()


# ----- Giants ----------------------------------------------------------------

func _construct_giant() -> void:
	var giant := TargetScene.instantiate()
	giant.is_giant = true
	add_child(giant)
	giant.position = Vector3(2200.0, 110.0, 0.0)   # main slab bottom on the floor
	giant.wall = null
	_targets.append(giant)
	# Surround the climax with breakable cores so the giant isn't alone on stage
	# and so the OVERCHARGE chain has real fuel to propagate through. Marked as
	# escort so they scroll at the giant's pace and stay with him.
	_spawn_giant_escort(giant.position.x)


## Breakable-pillar "honor guard" that scrolls AT THE GIANT'S PACE so the giant
## isn't standing alone by the time he becomes vulnerable. Wraps the giant on
## all sides (in front, flanks, behind) for both combo-building during the
## approach and the post-kill OVERCHARGE chain.
func _spawn_giant_escort(gx: float) -> void:
	# Layer 1 — front wedge (player meets these first as the giant looms).
	var front_lanes: Array[float] = [-200.0, -100.0, 100.0, 200.0]
	front_lanes.shuffle()
	for i in 4:
		_spawn_escort_pillar(gx - 500.0 + i * 80.0 + randf() * 40.0, front_lanes[i])
	# Layer 2 — flanks (alongside the giant — these get caught in OVERCHARGE).
	_spawn_escort_pillar(gx, -180.0)
	_spawn_escort_pillar(gx + 60.0, 180.0)
	# Layer 3 — rear (gives the OVERCHARGE chain something to ripple INTO).
	var rear_lanes: Array[float] = [-160.0, -50.0, 60.0, 170.0]
	rear_lanes.shuffle()
	for k in 4:
		_spawn_escort_pillar(gx + 280.0 + k * 110.0 + randf() * 50.0, rear_lanes[k])


func _spawn_escort_pillar(x: float, z: float) -> void:
	# Nudge z if a stale unbreakable would mask the escort core.
	for attempt in 5:
		if not _has_blocker_for_breakable_at(x, z):
			break
		z = -200.0 + randf() * 400.0
	var p: Node3D = PillarScript.new()
	p.configure(PillarScript.Kind.NORMAL, true, false)
	p.is_giant_escort = true
	add_child(p)
	_pillars.append(p)
	p.position = Vector3(x, p.position.y, z)


func _move_targets(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	var scroll: float = GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	for i in _targets.size():
		_targets[i].position.x -= scroll * 0.6   # giants loom slowly
		if _targets[i].position.x <= -1000.0:
			to_remove.append(i)
	_cleanup(to_remove, _targets)


# ----- Background structures -------------------------------------------------

func _build_structures() -> void:
	var n := 1 + floori(randf() * 4.0)
	for i in n:
		var s := BuildingScene.instantiate()
		add_child(s); _structures.append(s)
		var h := 40.0 + randf() * 120.0
		s.position = Vector3(SPAWN_X, h * 0.5, -1100.0 + randf() * 650.0)
		s.init_geometry(60.0 + randf() * 80.0, h, 60.0 + randf() * 80.0, Color8(110, 113, 120), 0)
	for i in n:
		var s2 := BuildingScene.instantiate()
		add_child(s2); _structures.append(s2)
		var h2 := 40.0 + randf() * 120.0
		s2.position = Vector3(SPAWN_X, h2 * 0.5, 450.0 + randf() * 1000.0)
		s2.init_geometry(60.0 + randf() * 80.0, h2, 60.0 + randf() * 80.0, GameColors.BROWN_DARK, 0)


func _move_structures(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _structures.size():
		var s := _structures[i]
		s.step(dt_ms)
		if s.position.x < -1000.0:
			to_remove.append(i)
	_cleanup(to_remove, _structures)


# ----- Missiles --------------------------------------------------------------

func _fire_missle() -> void:
	Sfx.play("fire", -5.0)
	# Fan count rides the combo tier (1 / 2 / 3 shots).
	match clampi(GameConfig.combo_tier + 1, 1, 3):
		1:
			_spawn_missle(0.0)
		2:
			_spawn_missle(-6.0)
			_spawn_missle(6.0)
		_:
			_spawn_missle(-10.0)
			_spawn_missle(0.0)
			_spawn_missle(10.0)


func _spawn_missle(yaw_offset_deg: float) -> void:
	var m: Node3D = MissleScene.instantiate()
	add_child(m); _missles.append(m)
	m.position = airplane.position + Vector3(10.0, -8.0, yaw_offset_deg * 1.5)
	m.missile_scale = GameConfig.missile_scale_for_tier()
	m.tier = GameConfig.combo_tier
	m.pierce = GameConfig.combo_tier   # higher tier punches through more pillars
	m.velocity = Vector3.DOWN * GameConfig.missile_initial_drop_speed
	m.target = _find_missle_target()


# ----- Aim / lock-on ---------------------------------------------------------

## "Plane = crosshair" model: the candidate is whatever hittable thing is
## closest to the plane's current (y, z), with a mild forward-distance penalty
## so closer pillars still win when proximity is similar. Cores BLOCKED by an
## unbreakable pillar in the line of fire are skipped, so the player never
## locks onto something a fired missile can't physically reach. A vulnerable
## giant takes priority over pillars.
func _pick_candidate() -> Node3D:
	for g in _targets:
		if g.is_giant and g.position.x <= GIANT_VULNERABLE_X and g.position.x > airplane.position.x:
			return g
	var best: Node3D = null
	var best_score: float = INF
	for pl in _pillars:
		if not pl.is_core_hittable():
			continue
		if pl.global_position.x <= airplane.position.x:
			continue
		var p: Vector3 = pl.core_world_pos()
		if _is_los_blocked(p):
			continue
		var dy: float = p.y - airplane.position.y
		var dz: float = p.z - airplane.position.z
		var score: float = sqrt(dy * dy + dz * dz) \
			+ (p.x - airplane.position.x) * 0.05
		if score < best_score:
			best_score = score
			best = pl
	return best


## True if any UNBREAKABLE solid pillar sits between the plane and `target` in
## the AABB sense. Used to filter out cores whose shot would be blocked.
func _is_los_blocked(target: Vector3) -> bool:
	for pl in _pillars:
		if not is_instance_valid(pl):
			continue
		if pl.breakable:
			continue
		if not pl.is_solid_hazard():
			continue
		if pl.global_position.x <= airplane.position.x:
			continue
		if pl.global_position.x >= target.x:
			continue
		if _seg_pillar_aabb_hits(airplane.position, target, pl):
			return true
	return false


## Slab-test: does the segment a→b intersect the pillar's current AABB?
func _seg_pillar_aabb_hits(a: Vector3, b: Vector3, pl: Node3D) -> bool:
	var d: Vector3 = b - a
	var cy: float = (pl.emerged_top_y + pl.emerged_bottom_y) * 0.5
	var hy: float = (pl.emerged_top_y - pl.emerged_bottom_y) * 0.5
	var center: Vector3 = Vector3(pl.global_position.x, cy, pl.global_position.z)
	var half: Vector3 = Vector3(pl.w * 0.5, hy, pl.d * 0.5)
	var t_min: float = 0.0
	var t_max: float = 1.0
	for i in 3:
		if absf(d[i]) < 0.0001:
			if absf(a[i] - center[i]) > half[i]:
				return false
			continue
		var inv: float = 1.0 / d[i]
		var t1: float = (center[i] - half[i] - a[i]) * inv
		var t2: float = (center[i] + half[i] - a[i]) * inv
		if t1 > t2:
			var tmp: float = t1
			t1 = t2
			t2 = tmp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false
	return true


func _is_giant_node(node: Node3D) -> bool:
	return "is_giant" in node and node.is_giant


func _aim_pos(node: Node3D) -> Vector3:
	if node.has_method("core_world_pos"):
		return node.core_world_pos()
	return node.position + Vector3(0.0, 30.0, 0.0)


func _aim_radius(node: Node3D) -> float:
	return 170.0 if _is_giant_node(node) else 32.0


func _lock_window(node: Node3D) -> float:
	return GameConfig.missile_lock_radius * (14.0 if _is_giant_node(node) else 1.0)


## "Locked" = the plane is positioned close enough to the candidate (y, z) that
## a fired missile will land. Reticle goes red+pulsing when locked.
func _is_locked(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var ap: Vector3 = _aim_pos(node)
	var dy: float = ap.y - airplane.position.y
	var dz: float = ap.z - airplane.position.z
	return sqrt(dy * dy + dz * dz) < _lock_window(node)


## Homing target for a fired missile: the candidate's aim node (a pillar core
## node, or the giant). The missile homes whenever there's a candidate — the
## skill is dodging + picking + chaining, not pixel-aiming (oto-fire + dodge
## blueprint). Lock state only drives reticle feedback. Null -> fly straight.
func _find_missle_target() -> Node3D:
	var c: Node3D = _pick_candidate()
	if c == null:
		return null
	if c.has_method("core_node"):
		var cn: Node3D = c.core_node()
		return cn if cn != null else c
	return c


func _update_aim_overlay() -> void:
	var c: Node3D = _pick_candidate()
	if c == null:
		_guide_overlay.update_overlay(airplane.position, Vector3.ZERO, 0.0, false, false, false)
		return
	_guide_overlay.update_overlay(airplane.position, _aim_pos(c), _aim_radius(c),
		_is_locked(c), true, _is_giant_node(c))


func _fly_missles(dt_ms: float) -> void:
	const HIT_RADIUS := 22.0
	var to_remove: Array[int] = []
	for i in _missles.size():
		var m := _missles[i]
		m.step(dt_ms)
		var consumed := false

		# Giant hit (skill-checked by tier).
		for g in _targets:
			if not g.is_giant or g.position.x > GIANT_VULNERABLE_X:
				continue
			if _segment_point_distance(m.prev_position, m.position, g.position) < HIT_RADIUS * 8.0:
				if m.tier >= GameConfig.giant_required_tier:
					var killed: bool = g.take_damage(1)
					_on_giant_hit(g, killed)
				else:
					_on_giant_chip(g)
				consumed = true
				break
		if consumed:
			to_remove.append(i)
			continue

		# Pillar hit. A BREAKABLE pillar's core takes damage (multi-hit for big
		# targets); the missile pierces ON A KILL only. An UNBREAKABLE pillar
		# sparks and stops the shot. A missile never re-hits the same pillar
		# (pillars_hit set), so a pierce shot doesn't drain HP every frame while
		# sitting in the AABB.
		var broke := false
		var killed := false
		var blocked := false
		for pl in _pillars:
			if not pl.is_solid_hazard():
				continue
			if m.position.x > pl.global_position.x - pl.w * 0.5 - HIT_RADIUS \
			and m.position.x < pl.global_position.x + pl.w * 0.5 + HIT_RADIUS \
			and absf(m.position.y - pl.global_position.y) < pl.h * 0.5 + HIT_RADIUS \
			and absf(m.position.z - pl.global_position.z) < pl.d * 0.5 + HIT_RADIUS:
				if pl.breakable and pl.core_alive:
					if pl in m.pillars_hit:
						continue
					m.pillars_hit.append(pl)
					killed = _on_core_hit(pl, m)
					broke = true
				else:
					_spawn_explosion(m.position, SmokeBurstScript.Kind.BLOCK_SPARK, 1.0)
					shaker.shake(GameConfig.shake_hit_intensity * 0.6, 0.08)
					Sfx.play("block", -10.0)
					blocked = true
				break
		if broke:
			# Pierce only on a kill — chip hits don't waste pierce charges.
			if killed and m.pierce > 0:
				m.pierce -= 1
			else:
				to_remove.append(i)
			continue
		if blocked:
			to_remove.append(i)
			continue

		if m.position.x > 15000.0 or m.position.y < -1000.0:
			to_remove.append(i)
	_cleanup(to_remove, _missles)


## Returns true if this hit killed the pillar (multi-HP cores chip first, then
## the killing shot fires the full kill juice + combo bookkeeping).
func _on_core_hit(pl: Node3D, m: Node3D) -> bool:
	var pos: Vector3 = pl.core_world_pos()
	var killed: bool = pl.take_core_damage()

	# Every hit (chip OR kill) counts toward combo so big targets feel rewarding
	# all the way through, not only on the killing shot.
	var prev_tier: int = GameConfig.combo_tier
	GameConfig.register_core_hit()
	if GameConfig.combo > _max_combo_run:
		_max_combo_run = GameConfig.combo
	if GameConfig.combo_tier > _max_tier_run:
		_max_tier_run = GameConfig.combo_tier
	if not _seen_first_hit:
		_seen_first_hit = true
		_show_moment("First Hit!", Color(1.0, 0.95, 0.55), 72, "+1 COMBO")
	else:
		_show_combo_tick()
	_bump_combo_widget()

	if not killed:
		# Chip on a multi-HP target — visible bounce, no full explosion.
		_spawn_explosion(pos, SmokeBurstScript.Kind.BLOCK_SPARK, 1.5)
		shaker.shake(GameConfig.shake_hit_intensity * 0.7, 0.09)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 0.7)
		_add_ultimate_charge(GameConfig.ultimate_charge_per_chip)
		Sfx.play("giant_hit", -8.0)
		# Tier may still rise on a chip hit — still celebrate it.
		if GameConfig.combo_tier > prev_tier:
			_show_moment("Tier %d!" % GameConfig.combo_tier, _tier_color(GameConfig.combo_tier), 88)
			flash_overlay.flash(0.22, 0.10, false)
			_add_ultimate_charge(GameConfig.ultimate_charge_per_tier_up)
			Sfx.play("tier_up", -3.0)
		return false

	# Kill — full juice.
	_spawn_explosion(pos, SmokeBurstScript.Kind.PILLAR_BREAK, float(m.tier + 1))
	_add_ultimate_charge(GameConfig.ultimate_charge_per_kill)
	Sfx.play("core_break", -5.0)
	if GameConfig.combo_tier > prev_tier:
		_show_moment("Tier %d!" % GameConfig.combo_tier, _tier_color(GameConfig.combo_tier), 88)
		shaker.shake(GameConfig.shake_hit_intensity * 1.6, 0.2)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.4)
		flash_overlay.flash(0.28, 0.12, false)
		_add_ultimate_charge(GameConfig.ultimate_charge_per_tier_up)
		Sfx.play("tier_up", -2.0)
	else:
		shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
		time_scaler.request_hitstop(GameConfig.hitstop_duration)
	return true


## Single pillar's OVERCHARGE detonation — scheduled by a staggered timer so
## the chain ripples out. Safe to fire on a queue_freed pillar (the validity
## check just skips).
func _overcharge_blast(pl: Node3D) -> void:
	if not is_instance_valid(pl):
		return
	if not pl.is_solid_hazard():
		return
	_spawn_explosion(pl.global_position, SmokeBurstScript.Kind.PILLAR_BREAK, 3.0)
	if pl.breakable and pl.core_alive:
		pl.shatter()


func _on_giant_chip(g: Node3D) -> void:
	# Missile too weak: visible "bounce" so the player learns to grow first.
	_spawn_explosion(g.position, SmokeBurstScript.Kind.GIANT_CHIP, 1.0)
	shaker.shake(GameConfig.shake_hit_intensity * 0.8, 0.1)
	flash_overlay.flash(0.12, 0.06)
	_add_ultimate_charge(GameConfig.ultimate_charge_per_giant_chip * 0.5)


func _on_giant_hit(g: Node3D, killed: bool) -> void:
	if not killed:
		_spawn_explosion(g.position, SmokeBurstScript.Kind.GIANT_HIT, 2.0)
		shaker.shake(GameConfig.shake_hit_intensity * 1.8, GameConfig.shake_hit_duration * 1.3)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
		flash_overlay.flash(0.22, 0.10)
		_add_ultimate_charge(GameConfig.ultimate_charge_per_giant_chip)
		Sfx.play("giant_hit", -3.0)
		return

	# Giant defeated: bump the run-stats counter for the recap screen.
	_giants_killed_run += 1
	_show_moment("Giant Down!", Color(1.0, 0.45, 0.25), 92)
	Sfx.play("giant_finish", 0.0)
	_add_ultimate_charge(GameConfig.ultimate_charge_per_giant_kill)
	# Finish: full showpiece combo — a cluster of big plumes across the giant so
	# it reads as a screen-erasing detonation.
	time_scaler.request_slowmo(GameConfig.slowmo_giant_scale, GameConfig.slowmo_giant_duration)
	shaker.shake(GameConfig.shake_giant_intensity, GameConfig.shake_giant_duration)
	flash_overlay.flash(0.45, 0.3, false)
	for k in 5:
		var off := Vector3((randf() - 0.5) * 220.0, (randf() - 0.5) * 260.0, (randf() - 0.5) * 160.0)
		_spawn_explosion(g.position + off, SmokeBurstScript.Kind.GIANT_FINISH, 3.0 + randf())
	_spawn_shockwave(g.position, 60.0, 1.0)

	# OVERCHARGE — killing the giant at max tier (T3) cascade-detonates every
	# breakable pillar on the field. Earns the player a screen-clearing reward
	# for arriving strong. (Appendix C: P2 과충전 폭발.)
	if GameConfig.combo_tier >= 3:
		_show_moment("OVERCHARGE!", Color(1.0, 0.55, 0.18), 108)
		flash_overlay.flash(0.5, 0.4, false)
		shaker.shake(GameConfig.shake_giant_intensity * 1.2, 0.6)
		Sfx.play("ult", 0.0)
		var giant_pos: Vector3 = g.position
		var ordered: Array = _pillars.duplicate()
		ordered.sort_custom(func(a, b):
			if not is_instance_valid(a):
				return false
			if not is_instance_valid(b):
				return true
			return a.global_position.distance_squared_to(giant_pos) \
				< b.global_position.distance_squared_to(giant_pos))
		var delay: float = 0.0
		for pl in ordered:
			if not is_instance_valid(pl):
				continue
			if not pl.is_solid_hazard():
				continue
			get_tree().create_timer(delay).timeout.connect(_overcharge_blast.bind(pl))
			delay += 0.06

	var idx: int = _targets.find(g)
	if idx >= 0:
		_targets.remove_at(idx)
	g.start_fade(0.6)


## Closest distance from point `p` to segment `a→b`.
func _segment_point_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab: Vector3 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_to(p)
	var u: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * u).distance_to(p)


# ----- Explosions / particles ------------------------------------------------

## Unified destruction burst. `kind` chooses the recipe (pillar shatter, giant
## chip, giant finish, block spark, plane scrape…); `power` modulates scale
## inside the recipe.
func _spawn_explosion(pos: Vector3, kind: int, power: float = 1.0) -> void:
	var smoke: Node3D = SmokeBurstScript.new()
	smoke.kind = kind
	smoke.power = power
	add_child(smoke)
	smoke.global_position = pos
	_smokes.append(smoke)
	_spawn_shockwave(pos, 10.0 + power * 8.0, 0.4 + power * 0.08)


func _spawn_dust(pos: Vector3, footprint: float) -> void:
	# Low ground dust when a pillar erupts.
	var smoke: Node3D = SmokeBurstScript.new()
	smoke.kind = SmokeBurstScript.Kind.GROUND_DUST
	smoke.power = clampf(footprint / 120.0, 0.5, 3.0)
	add_child(smoke)
	smoke.global_position = pos
	_smokes.append(smoke)


func _spawn_particles_at(pos: Vector3, density: int, color: int, scale_: int) -> void:
	for i in density:
		var p: Node3D = ParticleScript.new()
		p.color_index = color
		p.sprite_scale = float(scale_)
		p.inc_y = -2.0 + randf() * 4.0
		p.inc_z = -2.0 + randf() * 4.0
		p.inc_rx = randf() * 18.0
		p.inc_rz = randf() * 18.0
		p.duration = 0.5
		add_child(p)
		p.position = pos
		_particles.append(p)


func _make_white_spheres(pos: Vector3, big: bool = false) -> void:
	var n: int = (80 + int(randf() * 40.0)) if big else (20 + int(randf() * 30.0))
	for i in n:
		var s: Node3D = WhiteSphereScript.new()
		s.color = GameColors.BROWN_DARK if i % 5 == 0 else GameColors.PURE_WHITE
		var max_scale: float = 18.0 if big else 8.0
		var min_scale: float = 10.0 if big else 3.0
		s.sphere_scale = min_scale + randf() * (max_scale - min_scale)
		s.duration = 1.4 if big else 0.9
		add_child(s)
		var spread: float = 35.0 if big else 18.0
		s.position = pos + Vector3(
			-spread + randf() * spread * 2.0,
			-spread + randf() * spread * 2.0,
			-spread + randf() * spread * 2.0
		)
		_white_spheres.append(s)


func _update_particles(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _particles.size():
		if not _particles[i].step(dt_ms):
			to_remove.append(i)
	_cleanup(to_remove, _particles)


func _spawn_shockwave(pos: Vector3, end_scale_: float, duration_: float,
		real_time: bool = false, thickness: float = 1.0) -> void:
	var ring: Node3D = ShockwaveRingScript.new()
	ring.end_scale = end_scale_
	ring.duration = duration_
	ring.real_time = real_time
	ring.tube_thickness = thickness
	add_child(ring)
	ring.position = pos
	_shockwaves.append(ring)


func _update_shockwaves(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _shockwaves.size():
		if not _shockwaves[i].step(dt_ms):
			to_remove.append(i)
	_cleanup(to_remove, _shockwaves)


func _update_white_spheres(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _white_spheres.size():
		if not _white_spheres[i].step(dt_ms):
			to_remove.append(i)
	_cleanup(to_remove, _white_spheres)


func _update_smokes(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _smokes.size():
		if not _smokes[i].step(dt_ms):
			to_remove.append(i)
	_cleanup(to_remove, _smokes)


# ----- Helpers ---------------------------------------------------------------

func _cleanup(indices: Array[int], arr: Array[Node3D]) -> void:
	for k in range(indices.size() - 1, -1, -1):
		var idx := indices[k]
		var n := arr[idx]
		if is_instance_valid(n):
			n.queue_free()
		arr.remove_at(idx)


func _get_normalized_mouse() -> Vector2:
	var win := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	return Vector2(-1.0 + (m.x / win.x) * 2.0, 1.0 - (m.y / win.y) * 2.0)


func _get_world_cursor() -> Vector3:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(ray_dir.x) < 0.0001:
		return Vector3(PLANE_BASE_X, GameConfig.plane_default_height, 0.0)
	var t: float = (PLANE_BASE_X - ray_origin.x) / ray_dir.x
	return ray_origin + ray_dir * t


func _update_hud() -> void:
	if _hud_dist != null:
		_hud_dist.text = "%d" % int(GameConfig.distance)
	if _hud_best != null:
		_hud_best.text = "Best %d" % GameConfig.best_distance
	if _hud_combo != null:
		_hud_combo.text = "x%d" % GameConfig.combo
		_hud_combo.add_theme_color_override("font_color", _tier_color(GameConfig.combo_tier))
	if _hud_tier != null:
		_hud_tier.text = "TIER %d" % GameConfig.combo_tier
		_hud_tier.add_theme_color_override("font_color",
			Color(_tier_color(GameConfig.combo_tier).r,
				  _tier_color(GameConfig.combo_tier).g,
				  _tier_color(GameConfig.combo_tier).b, 0.85))

	# Ultimate gauge fill + ready state.
	if _hud_ult_bar != null and _hud_ult_bg != null:
		var fill: float = clampf(GameConfig.ultimate_gauge / GameConfig.ultimate_gauge_max, 0.0, 1.0)
		_hud_ult_bar.size = Vector2(_hud_ult_bg.size.x * fill, 34.0)
		var ready: bool = fill >= 1.0
		var playing: bool = GameConfig.status == GameConfig.STATUS_PLAYING
		if ready:
			var pulse: float = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.005))
			_hud_ult_bar.color = Color(1.0, 0.88, 0.28, pulse)
			if _hud_ult_label != null:
				_hud_ult_label.text = "★ ULT READY ★"
				_hud_ult_label.add_theme_color_override("font_color", Color(1, 1, 1, pulse))
		else:
			_hud_ult_bar.color = Color(1.0, 0.62, 0.18, 0.85)
			if _hud_ult_label != null:
				_hud_ult_label.text = "ULT  %d%%" % int(fill * 100)
				_hud_ult_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		# Mobile ULT button appears only when ready.
		if _ult_btn != null:
			_ult_btn.visible = ready and playing and _touch_mode


func _on_game_over() -> void:
	var traveled: int = int(GameConfig.distance)
	var old_best: int = GameConfig.best_distance
	var is_new_best: bool = traveled > old_best
	if is_new_best:
		GameConfig.best_distance = traveled
		var SaveDataScript := preload("res://scripts/SaveData.gd")
		SaveDataScript.save_best(GameConfig.best_distance)
	Sfx.play("crash", 1.0)
	# Hide the play HUD + touch buttons immediately so a retry tap isn't eaten
	# by the (STOP) FIRE/ULT buttons during the death beat.
	_set_play_hud_visible(false)
	# Brief delay so the death juice (shake / falling plane) reads before the
	# recap screen swoops in.
	get_tree().create_timer(1.2).timeout.connect(func(): _show_gameover_screen(is_new_best))


# ----- Title / Game-over overlays --------------------------------------------

func _build_title_overlay() -> void:
	_title_layer = ColorRect.new()
	_title_layer.anchor_right = 1.0
	_title_layer.anchor_bottom = 1.0
	_title_layer.color = Color(0.0, 0.0, 0.0, 0.45)
	# Full-screen STOP + gui_input so a tap ANYWHERE reliably starts the game,
	# without depending on the event reaching _unhandled_input.
	_title_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_layer.gui_input.connect(func(e):
		var p: bool = (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventMouseButton and e.pressed)
		if p and GameConfig.status == GameConfig.STATUS_TITLE:
			_start_game()
			_title_layer.accept_event())
	hud.add_child(_title_layer)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var title := _make_centered_label("AVIATOR TO SKY", 56, Color(1, 1, 1, 1))
	vbox.add_child(title)
	var sub := _make_centered_label("MONOLITH GAUNTLET", 20, Color(1, 1, 1, 0.65))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(spacer)

	# Mini-guide — silently teaches the core loop so the player knows what to
	# do without a tutorial. Cheapest fix for the "what is combo?" UX hole.
	var guide := _make_centered_label("Shoot red cores in a row  →  bigger missile", 16, Color(1, 1, 1, 0.7))
	vbox.add_child(guide)
	var guide2 := _make_centered_label("Reach TIER 2 to beat the Giant", 16, Color(1, 1, 1, 0.6))
	vbox.add_child(guide2)
	var guide3 := _make_centered_label("Fill the ULT bar  →  TAP it to unleash", 16, Color(1, 1, 1, 0.55))
	vbox.add_child(guide3)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer2)

	_tap_label = _make_centered_label("TAP TO START", 28, Color(1, 1, 1, 1))
	vbox.add_child(_tap_label)


func _build_gameover_overlay() -> void:
	_gameover_layer = ColorRect.new()
	_gameover_layer.anchor_right = 1.0
	_gameover_layer.anchor_bottom = 1.0
	_gameover_layer.color = Color(0.0, 0.0, 0.0, 0.55)
	# Full-screen STOP + gui_input so a tap ANYWHERE retries reliably.
	_gameover_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_gameover_layer.gui_input.connect(func(e):
		var p: bool = (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventMouseButton and e.pressed)
		if p and GameConfig.status == GameConfig.STATUS_GAME_OVER:
			get_tree().reload_current_scene())
	_gameover_layer.visible = false
	hud.add_child(_gameover_layer)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameover_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	_gameover_title = _make_centered_label("RUN OVER", 48, Color(1, 1, 1, 1))
	vbox.add_child(_gameover_title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(spacer1)

	_gameover_dist   = _make_centered_label("", 22, Color(1, 1, 1, 0.92))
	_gameover_best   = _make_centered_label("", 18, Color(1, 1, 1, 0.7))
	_gameover_combo  = _make_centered_label("", 20, Color(1, 1, 1, 0.85))
	_gameover_giants = _make_centered_label("", 20, Color(1, 1, 1, 0.85))
	vbox.add_child(_gameover_dist)
	vbox.add_child(_gameover_best)
	vbox.add_child(_gameover_combo)
	vbox.add_child(_gameover_giants)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer2)

	_gameover_tap = _make_centered_label("TAP TO RETRY", 26, Color(1, 1, 1, 1))
	vbox.add_child(_gameover_tap)


func _make_centered_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# IGNORE so a tap on the title/recap text passes through to _unhandled_input
	# (otherwise the centred "TAP TO RETRY" label eats the retry tap).
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _show_title() -> void:
	GameConfig.status = GameConfig.STATUS_TITLE
	_title_layer.visible = true
	_gameover_layer.visible = false
	_set_play_hud_visible(false)


func _start_game() -> void:
	Sfx.play("ui", -3.0)
	GameConfig.status = GameConfig.STATUS_PLAYING
	_title_layer.visible = false
	_gameover_layer.visible = false
	_set_play_hud_visible(true)
	_seen_first_hit = false
	_seen_ult_ready = false
	_wave_beat = 0
	_spike_beat = 0


func _show_gameover_screen(is_new_best: bool) -> void:
	_gameover_title.text = "NEW BEST!" if is_new_best else "RUN OVER"
	_gameover_title.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.35, 1.0) if is_new_best else Color(1, 1, 1, 1))
	_gameover_dist.text   = "Distance:  %d" % int(GameConfig.distance)
	_gameover_best.text   = "Best:  %d" % GameConfig.best_distance
	_gameover_combo.text  = "Max Combo:  x%d  (T%d)" % [_max_combo_run, _max_tier_run]
	_gameover_giants.text = "Giants Defeated:  %d" % _giants_killed_run
	_gameover_layer.visible = true
	_set_play_hud_visible(false)


func _set_play_hud_visible(v: bool) -> void:
	if _hud_dist != null: _hud_dist.visible = v
	if _hud_dist_caption != null: _hud_dist_caption.visible = v
	if _hud_best != null: _hud_best.visible = v
	if _hud_combo != null: _hud_combo.visible = v
	if _hud_tier != null: _hud_tier.visible = v
	if _hud_ult_bg != null: _hud_ult_bg.visible = v
	if _hud_ult_bar != null: _hud_ult_bar.visible = v
	if _hud_ult_label != null: _hud_ult_label.visible = v
	for r in _hud_heart_rects:
		r.visible = v
	# Touch controls only when playing on a touchscreen.
	var tv: bool = v and _touch_mode
	if _fire_btn != null: _fire_btn.visible = tv
	if _joy_base != null: _joy_base.visible = tv
	if _joy_knob != null: _joy_knob.visible = tv
	if _ult_btn != null: _ult_btn.visible = false   # shown by _update_hud when full
	if not v:
		_release_joystick()
	if tv:
		_recenter_knob()


# ----- New in-play HUD -------------------------------------------------------

func _build_play_hud() -> void:
	# Top-centre: big DIST number + tiny caption above
	_hud_dist_caption = _anchored_label("DIST", 12, Color(1, 1, 1, 0.55),
		0.5, 0.0, -80.0, 4.0, 80.0, 22.0, HORIZONTAL_ALIGNMENT_CENTER)
	hud.add_child(_hud_dist_caption)

	_hud_dist = _anchored_label("0", 48, Color(1, 1, 1, 1.0),
		0.5, 0.0, -160.0, 22.0, 160.0, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
	_hud_dist.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hud_dist.add_theme_constant_override("outline_size", 3)
	hud.add_child(_hud_dist)
	_hud_dist.pivot_offset = Vector2(160.0, 40.0)

	# Top-left: HP hearts row
	for i in 3:
		var r := ColorRect.new()
		r.color = Color(0.96, 0.27, 0.27)
		r.size = Vector2(24.0, 24.0)
		r.position = Vector2(18.0 + i * 32.0, 20.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.pivot_offset = Vector2(12.0, 12.0)
		hud.add_child(r)
		_hud_heart_rects.append(r)

	# Top-right: COMBO + TIER badge
	_hud_combo = _anchored_label("x0", 30, Color(1, 1, 1, 1.0),
		1.0, 0.0, -150.0, 16.0, -16.0, 56.0, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_combo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_hud_combo.add_theme_constant_override("outline_size", 2)
	hud.add_child(_hud_combo)
	_hud_combo.pivot_offset = Vector2(134.0, 18.0)

	_hud_tier = _anchored_label("TIER 0", 14, Color(1, 1, 1, 0.7),
		1.0, 0.0, -150.0, 50.0, -16.0, 70.0, HORIZONTAL_ALIGNMENT_RIGHT)
	hud.add_child(_hud_tier)

	# Top-left under hearts: BEST
	_hud_best = _anchored_label("Best 0", 14, Color(1, 1, 1, 0.55),
		0.0, 0.0, 18.0, 52.0, 200.0, 72.0, HORIZONTAL_ALIGNMENT_LEFT)
	hud.add_child(_hud_best)

	# Bottom-centre: ULTIMATE gauge — a slim warm bar that fills with action,
	# pulses when ready. TAP IT (mobile) or press SPACE / right-click (desktop)
	# to unleash. mouse_filter = STOP so a tap on the bar is caught here and
	# doesn't also fire a missile. A generous tap target (taller than the bar).
	_hud_ult_bg = ColorRect.new()
	_hud_ult_bg.color = Color(0.12, 0.12, 0.16, 0.65)
	_hud_ult_bg.anchor_left = 0.5; _hud_ult_bg.anchor_right = 0.5
	_hud_ult_bg.anchor_top = 1.0; _hud_ult_bg.anchor_bottom = 1.0
	_hud_ult_bg.offset_left = -200.0; _hud_ult_bg.offset_right = 200.0
	_hud_ult_bg.offset_top = -78.0; _hud_ult_bg.offset_bottom = -34.0
	_hud_ult_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_ult_bg.gui_input.connect(_on_ult_bar_input)
	hud.add_child(_hud_ult_bg)

	_hud_ult_bar = ColorRect.new()
	_hud_ult_bar.color = Color(1.0, 0.66, 0.18, 0.92)
	_hud_ult_bar.position = Vector2(0, 0)
	_hud_ult_bar.size = Vector2(0, 34)
	_hud_ult_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ult_bg.add_child(_hud_ult_bar)

	_hud_ult_label = Label.new()
	_hud_ult_label.text = "ULT  0%"
	_hud_ult_label.add_theme_font_size_override("font_size", 16)
	_hud_ult_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_hud_ult_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud_ult_label.add_theme_constant_override("outline_size", 2)
	_hud_ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_ult_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_ult_label.anchor_right = 1.0
	_hud_ult_label.anchor_bottom = 1.0
	_hud_ult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_ult_bg.add_child(_hud_ult_label)


## Build a Label with explicit anchor + offset rectangle. The anchor pins it
## to a screen edge (e.g. 0.5/0.0 = top-centre, 1.0/0.0 = top-right).
func _anchored_label(text: String, font_size: int, color: Color,
		anchor_x: float, anchor_y: float, ox_l: float, oy_t: float,
		ox_r: float, oy_b: float, halign: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.anchor_left = anchor_x
	l.anchor_right = anchor_x
	l.anchor_top = anchor_y
	l.anchor_bottom = anchor_y
	l.offset_left = ox_l
	l.offset_top = oy_t
	l.offset_right = ox_r
	l.offset_bottom = oy_b
	l.horizontal_alignment = halign
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _hide_legacy_labels() -> void:
	distance_label.visible = false
	best_label.visible = false
	status_label.visible = false
	energy_bar.visible = false


# ----- Moment texts ----------------------------------------------------------

## Centered pop-up text that hangs for a beat and floats up out. Used for the
## key emotional beats — First Hit, Tier Up, Giant Down, Overcharge — so the
## player FEELS the milestone instead of just seeing a number tick. Optional
## `subtitle` line below (smaller, dimmer) is used to TEACH on the first beat
## (e.g. "+1 COMBO" under "First Hit!").
func _show_moment(text: String, color: Color = Color(1, 1, 1, 1), font_size: int = 64,
		subtitle: String = "") -> void:
	# Outer Control anchored at upper-centre so animating its scale+alpha moves
	# the whole stack (title + subtitle) together.
	var holder := Control.new()
	holder.anchor_left = 0.5; holder.anchor_right = 0.5
	holder.anchor_top = 0.4; holder.anchor_bottom = 0.4
	var w: float = 800.0; var h: float = 180.0
	holder.offset_left = -w * 0.5; holder.offset_right = w * 0.5
	holder.offset_top = -h * 0.5; holder.offset_bottom = h * 0.5
	holder.pivot_offset = Vector2(w * 0.5, h * 0.5)
	holder.modulate.a = 0.0
	holder.scale = Vector2(0.3, 0.3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(holder)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0; vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	holder.add_child(vbox)

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", int(font_size * 0.42))
		sub.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.92))
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		sub.add_theme_constant_override("outline_size", 3)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)

	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(holder, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(holder, "offset_top", holder.offset_top - 30.0, 0.35)
	tw.parallel().tween_property(holder, "offset_bottom", holder.offset_bottom - 30.0, 0.35)
	tw.tween_callback(holder.queue_free)


func _bump_combo_widget() -> void:
	if _hud_combo == null:
		return
	_hud_combo.scale = Vector2(1.35, 1.35)
	var tw := create_tween()
	tw.tween_property(_hud_combo, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small "+1" that drifts up from beside the combo widget on every core hit, so
## the combo count growing is FELT (the widget bump alone is too subtle and the
## big "First Hit!" only fires once per run).
func _show_combo_tick() -> void:
	var l := Label.new()
	l.text = "+1"
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", _tier_color(GameConfig.combo_tier))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 1.0; l.anchor_right = 1.0
	l.anchor_top = 0.0; l.anchor_bottom = 0.0
	# Just below + to the left of the COMBO widget (which sits at right ~-150).
	l.offset_left = -210.0
	l.offset_right = -130.0
	l.offset_top = 70.0
	l.offset_bottom = 100.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.65)
	tw.parallel().tween_property(l, "offset_top", l.offset_top + 34.0, 0.65)
	tw.parallel().tween_property(l, "offset_bottom", l.offset_bottom + 34.0, 0.65)
	tw.tween_callback(l.queue_free)


func _animate_heart_lost(slot: int) -> void:
	if slot < 0 or slot >= _hud_heart_rects.size():
		return
	var r: ColorRect = _hud_heart_rects[slot]
	# Quick scale punch then dim grey.
	r.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(r, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "color", Color(0.3, 0.3, 0.3, 0.5), 0.18)


## Fills the ultimate gauge by `amount`, capping at the max. The first time the
## gauge reaches FULL in a run, a one-shot "ULT READY!" moment teaches the
## control (right-click / SPACE).
func _add_ultimate_charge(amount: float) -> void:
	var was_ready: bool = GameConfig.ultimate_gauge >= GameConfig.ultimate_gauge_max
	GameConfig.ultimate_gauge = minf(GameConfig.ultimate_gauge_max,
		GameConfig.ultimate_gauge + amount)
	if not was_ready and GameConfig.ultimate_gauge >= GameConfig.ultimate_gauge_max:
		if not _seen_ult_ready:
			_seen_ult_ready = true
			_show_moment("ULT READY!", Color(1.0, 0.88, 0.28), 64, "right-click / SPACE")


## Tap/click on the ULT gauge bar — fires the ultimate when it's full (mobile
## has no SPACE / right-click). Only consumes the tap when actually firing.
func _on_ult_bar_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and GameConfig.status == GameConfig.STATUS_PLAYING \
	and GameConfig.ultimate_gauge >= GameConfig.ultimate_gauge_max:
		_fire_ultimate()
		_hud_ult_bg.accept_event()


## Spend the full ultimate gauge to detonate every visible breakable pillar in
## a shockwave ripple expanding outward from the plane. The chain happens in
## under a second; the player sees a SINGLE clear event ("BOOM, everything
## gone") instead of a confusing missile cloud. Counter in the moment text
## shows exactly how many targets were cleared — "ULTIMATE! 7 TARGETS CLEARED".
func _fire_ultimate() -> void:
	if GameConfig.ultimate_gauge < GameConfig.ultimate_gauge_max:
		return
	GameConfig.ultimate_gauge = 0.0
	Sfx.play("ult", 1.0)

	# Visible "energy release" — FIVE concentric shockwaves grow in lockstep
	# with the plane at the centre, plus a big bright explosion at the plane's
	# muzzle. Spawned BEFORE the slowmo request so the first frame draws at
	# real time (no creeping smear). This is the "BOOM, here it goes" pulse.
	var pulse_pos: Vector3 = airplane.global_position + Vector3(30.0, 15.0, 0.0)
	print("[ULT] fired at ", pulse_pos, " (plane=", airplane.global_position, ")")
	_spawn_ult_pulse(pulse_pos)

	flash_overlay.flash(0.7, 0.5, false)
	shaker.shake(GameConfig.shake_giant_intensity * 1.5, 0.65)
	time_scaler.request_slowmo(0.35, 1.1)

	# Sort every solid-hazard pillar by distance from the plane so the chain
	# RIPPLES OUT (nearest first). Staggered timers fire each detonation.
	var plane_pos: Vector3 = airplane.position
	var ordered: Array = _pillars.duplicate()
	ordered.sort_custom(func(a, b):
		if not is_instance_valid(a):
			return false
		if not is_instance_valid(b):
			return true
		return a.global_position.distance_squared_to(plane_pos) \
			< b.global_position.distance_squared_to(plane_pos))

	var target_count: int = 0
	var delay: float = 0.08
	for pl in ordered:
		if not is_instance_valid(pl):
			continue
		if not pl.is_solid_hazard():
			continue
		get_tree().create_timer(delay).timeout.connect(_ult_blast.bind(pl))
		delay += 0.13   # was 0.05 — wider gap so each detonation is its own beat
		target_count += 1

	var subtitle: String = ""
	if target_count > 0:
		subtitle = "%d TARGETS CLEARED" % target_count
	else:
		subtitle = "FIELD CLEAR"
	_show_moment("ULTIMATE!", Color(1.0, 0.85, 0.3), 110, subtitle)


## Tall vertical beam of light shooting up from the plane on ULT. Box scaled
## tall over a short Tween, unshaded emissive + no_depth_test so it ALWAYS
## renders on top. Anchored at the bottom and growing upward (offsetting Y as
## scale.y grows) so the beam appears to launch from the plane to the sky.
func _spawn_ult_beam(pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.35)
	mat.emission_energy_multiplier = 8.0
	mat.albedo_color = Color(1.0, 0.92, 0.55, 0.85)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	mi.global_position = pos
	var start_w: float = 36.0
	var end_w: float = 60.0
	var beam_height: float = 700.0
	mi.scale = Vector3(start_w, 8.0, start_w)
	# Anchor bottom: as scale.y grows, lift position.y by half the growth.
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(end_w, beam_height, end_w), 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "position:y", pos.y + beam_height * 0.5, 0.5)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)


## A bright "energy release" at the plane on ULT — three nested glowing spheres
## that expand outward via Tween (Tween uses Engine time, ignoring our custom
## time_scale, so the pulse stays punchy through the slowmo). Unshaded
## emissive material + no_depth_test means it's GUARANTEED to render on top of
## every scene mesh.
func _spawn_ult_pulse(pos: Vector3) -> void:
	for layer in 3:
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 10
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.78, 0.28)
		mat.emission_energy_multiplier = 4.0
		mat.albedo_color = Color(1.0, 0.85, 0.35, 0.55 - layer * 0.05)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_surface_override_material(0, mat)
		add_child(mi)
		mi.global_position = pos
		var start_s: float = 3.0 + float(layer) * 2.0
		var end_s: float = 40.0 + float(layer) * 30.0
		var dur: float = 0.275 + float(layer) * 0.09
		mi.scale = Vector3.ONE * start_s
		var tw := create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * end_s, dur) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, dur)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, dur)
		tw.tween_callback(mi.queue_free)


## Single pillar's ULT chain detonation — scheduled by staggered timers. Safe
## against freed / non-hazard pillars. ULT clears the FIELD, so even
## unbreakable pillars get shattered (the player's screen-clearing payoff —
## "the ultimate destroys everything").
func _ult_blast(pl: Node3D) -> void:
	if not is_instance_valid(pl):
		return
	if not pl.is_solid_hazard():
		return
	# Smaller per-pillar plume (power 1.8) so the cascade doesn't drown the
	# screen in overlapping smoke — each detonation stays individually visible.
	_spawn_explosion(pl.global_position, SmokeBurstScript.Kind.PILLAR_BREAK, 1.8)
	pl.shatter()


## Color tied to combo tier — white -> warm yellow -> orange -> hot red.
func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 0.95, 0.55)
		2: return Color(1.0, 0.7, 0.30)
		3: return Color(1.0, 0.42, 0.22)
		_: return Color(1, 1, 1, 1)


# ----- Input -----------------------------------------------------------------

## Joystick is handled in _input (runs BEFORE GUI) so no Control can swallow the
## drag. Left-half touches drive the stick; right-half (FIRE/ULT buttons) is
## left for their gui_input. We do NOT accept_event so buttons still work.
func _input(event: InputEvent) -> void:
	if not _touch_mode:
		return
	if event is InputEventScreenTouch:
		if GameConfig.status != GameConfig.STATUS_PLAYING:
			return
		var w: float = get_viewport().get_visible_rect().size.x
		if event.pressed:
			if event.position.x < w * 0.5:
				_joy_touch_index = event.index
				_update_joy_knob(event.position)
		elif event.index == _joy_touch_index:
			_release_joystick()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch_index:
			_update_joy_knob(event.position)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_game"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
		return

	# (Joystick touch handled in _input so GUI controls can't swallow the drag.)

	# Once in touch mode, ignore mouse events entirely.
	if _touch_mode and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return

	# ULTIMATE (desktop) — SPACE / right-click via the custom action.
	if event.is_action_pressed("fire_ult") and GameConfig.status == GameConfig.STATUS_PLAYING:
		if GameConfig.ultimate_gauge >= GameConfig.ultimate_gauge_max:
			_fire_ultimate()
			get_viewport().set_input_as_handled()
			return

	# ---- PC: left-click / fire key fires while PLAYING. (Title / game-over
	# clicks are handled by the full-screen overlays' gui_input.) ----
	var left_click: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT)
	var primary: bool = left_click or event.is_action_pressed("fire_missle")
	if primary and GameConfig.status == GameConfig.STATUS_PLAYING:
		_fire_missle()


## Update knob position + analog vector from a touch point. Knob is clamped to
## JOY_RADIUS around the base centre; _joy_vec is the normalized deflection.
func _joy_center() -> Vector2:
	return _joy_base.global_position + _joy_base.size * 0.5


func _update_joy_knob(touch_pos: Vector2) -> void:
	# Knob is a HUD sibling positioned in SCREEN space → no parent-local mixups.
	var off: Vector2 = touch_pos - _joy_center()
	if off.length() > JOY_RADIUS:
		off = off.normalized() * JOY_RADIUS
	_joy_knob.global_position = _joy_center() + off - _joy_knob.size * 0.5
	_joy_vec = off / JOY_RADIUS


func _release_joystick() -> void:
	_joy_touch_index = -1
	_joy_vec = Vector2.ZERO
	_recenter_knob()


## Park the knob over the base centre (screen space). Called on release + every
## frame while idle so layout timing can't strand it.
func _recenter_knob() -> void:
	if _joy_base != null and _joy_knob != null:
		_joy_knob.global_position = _joy_center() - _joy_knob.size * 0.5


## Build the on-screen controls (touchscreens only): a FIXED joystick bottom-
## left, a FIRE button bottom-right, and an ULT button above FIRE (shown only
## when the gauge is full).
func _build_touch_controls() -> void:
	var sz := 2.0 * JOY_RADIUS

	# Fixed joystick base, bottom-left. Dark fill so it reads on bright sky.
	_joy_base = _make_circle_panel(sz, Color(0.1, 0.12, 0.16, 0.45), Color(1, 1, 1, 0.7))
	_joy_base.anchor_left = 0.0; _joy_base.anchor_right = 0.0
	_joy_base.anchor_top = 1.0; _joy_base.anchor_bottom = 1.0
	_joy_base.offset_left = 40.0; _joy_base.offset_right = 40.0 + sz
	_joy_base.offset_top = -40.0 - sz; _joy_base.offset_bottom = -40.0
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_joy_base)

	# Knob is a sibling (HUD child), positioned in screen space — avoids
	# parent-local coordinate confusion entirely.
	_joy_knob = _make_circle_panel(sz * 0.5, Color(0.95, 0.95, 1.0, 0.55), Color(1, 1, 1, 0.9))
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_joy_knob)

	# FIRE button — bottom-right, tap = one shot.
	_fire_btn = _make_circle_panel(150.0, Color(1.0, 0.4, 0.25, 0.32), Color(1.0, 0.5, 0.3, 0.7))
	_fire_btn.anchor_left = 1.0; _fire_btn.anchor_right = 1.0
	_fire_btn.anchor_top = 1.0; _fire_btn.anchor_bottom = 1.0
	_fire_btn.offset_left = -180.0; _fire_btn.offset_right = -30.0
	_fire_btn.offset_top = -180.0; _fire_btn.offset_bottom = -30.0
	_fire_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_fire_btn.gui_input.connect(_on_fire_btn_input)
	hud.add_child(_fire_btn)
	_add_btn_label(_fire_btn, "FIRE", 26)

	# ULT button — above FIRE, only visible when the gauge is full.
	_ult_btn = _make_circle_panel(130.0, Color(1.0, 0.82, 0.25, 0.4), Color(1.0, 0.9, 0.4, 0.85))
	_ult_btn.anchor_left = 1.0; _ult_btn.anchor_right = 1.0
	_ult_btn.anchor_top = 1.0; _ult_btn.anchor_bottom = 1.0
	_ult_btn.offset_left = -170.0; _ult_btn.offset_right = -40.0
	_ult_btn.offset_top = -330.0; _ult_btn.offset_bottom = -200.0
	_ult_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_ult_btn.gui_input.connect(_on_ult_btn_input)
	_ult_btn.visible = false
	hud.add_child(_ult_btn)
	_add_btn_label(_ult_btn, "ULT", 24)

	_fire_btn.visible = _touch_mode


func _add_btn_label(btn: Control, text: String, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0; l.anchor_bottom = 1.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(l)


func _on_ult_btn_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and GameConfig.status == GameConfig.STATUS_PLAYING \
	and GameConfig.ultimate_gauge >= GameConfig.ultimate_gauge_max:
		_fire_ultimate()
		_ult_btn.accept_event()


## Make a circular Panel via a StyleBoxFlat with a huge corner radius.
func _make_circle_panel(diameter: float, fill: Color, border: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size = Vector2(diameter, diameter)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(diameter * 0.5))
	sb.border_color = border
	sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _on_fire_btn_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed and GameConfig.status == GameConfig.STATUS_PLAYING:
		_fire_missle()
		_fire_btn.accept_event()
