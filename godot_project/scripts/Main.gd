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
var _seen_first_hit: bool = false


func _ready() -> void:
	GameConfig.reset_to_defaults()
	director.reset()
	_current_stage = 1
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
	_spawn_pillar(PillarScript.Kind.NORMAL, true, SPAWN_X + randf() * 200.0, z, false)


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
		var z1: float = -150.0 + randf() * 120.0
		var z2: float = 30.0 + randf() * 120.0
		_spawn_pillar(PillarScript.Kind.NORMAL, true, SPAWN_X, z1, false)
		_spawn_pillar(PillarScript.Kind.NORMAL, false, SPAWN_X + 180.0, z2, false)


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


## Fired once when the run crosses into a new stage. Stage 4 entry gets a
## deliberate beat (camera kick + an immediate hanging colossus on a safe side
## lane) so the FIRST ceiling pillar is an intentional moment, not just one
## more piece of noise — preserving the "head-duck" reflex impact.
func _on_stage_advance(_old: int, new_stage: int) -> void:
	if new_stage == 4:
		shaker.shake(GameConfig.shake_hit_intensity * 1.4, 0.35)
		flash_overlay.flash(0.18, 0.18, false)
		# Force-spawn the first ceiling moment: a side-lane hanging colossus,
		# guaranteed not in the dodge lane so it reads as "wow" not as
		# "unfair death". Player learns ceiling exists, ducks instinctively.
		var side: float = -1.0 if randf() < 0.5 else 1.0
		var z: float = side * (340.0 + randf() * 130.0)
		_spawn_pillar(PillarScript.Kind.COLOSSUS, false, SPAWN_X - 400.0, z, true)


## A row of NORMAL pillars across z, deliberately leaving one open lane so the
## formation is always passable. Lanes are trimmed to ±200 so they stay inside
## the plane's reachable z (cores are never unreachable). When `allow_ceiling`,
## each member rolls 35% ceiling for vertical-dodge variety.
func _spawn_normal_cluster(count: int, allow_ceiling: bool = true) -> void:
	var lanes: Array[float] = [-200.0, -120.0, -45.0, 45.0, 120.0, 200.0]
	lanes.shuffle()
	var open_lane: int = int(randf() * lanes.size())
	for i in mini(count, lanes.size()):
		if i == open_lane:
			continue
		var breakable: bool = randf() < 0.55
		var from_ceiling: bool = allow_ceiling and randf() < 0.35
		_spawn_pillar(PillarScript.Kind.NORMAL, breakable, SPAWN_X + randf() * 240.0, lanes[i], from_ceiling)


func _spawn_spike_line(count: int, allow_ceiling: bool = true) -> void:
	for i in count:
		var z: float = -190.0 + randf() * 380.0    # ±190 → inside plane reach
		var from_ceiling: bool = allow_ceiling and randf() < 0.35   # stalactite vs spike
		_spawn_pillar(PillarScript.Kind.SPIKE, randf() < 0.7, SPAWN_X + i * 220.0, z, from_ceiling)


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


func _spawn_pillar(kind: int, breakable: bool, x: float, z: float, from_ceiling: bool = false) -> void:
	var p: Node3D = PillarScript.new()
	p.configure(kind, breakable, from_ceiling)
	add_child(p)
	_pillars.append(p)
	p.position = Vector3(x, p.position.y, z)


## Drop any freed pillar references so the rest of the frame only ever
## iterates valid nodes. Called at the top of _process.
func _filter_invalid_pillars() -> void:
	var i: int = _pillars.size() - 1
	while i >= 0:
		if not is_instance_valid(_pillars[i]):
			_pillars.remove_at(i)
		i -= 1


func _move_pillars(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _pillars.size():
		var pl := _pillars[i]
		# A pillar may have queue_free'd itself after its shatter collapse —
		# skip + collect for removal so we don't poke a freed node.
		if not is_instance_valid(pl):
			to_remove.append(i)
			continue
		var alive: bool = pl.step(dt_ms, airplane.position.x)

		# Eruption punch — a spike snapping up kicks the camera.
		if pl.consume_erupt():
			if pl.kind == PillarScript.Kind.SPIKE:
				shaker.shake(GameConfig.shake_hit_intensity * 0.7, 0.12)
			elif pl.kind == PillarScript.Kind.COLOSSUS:
				shaker.shake(GameConfig.shake_hit_intensity * 1.1, 0.25)
			_spawn_dust(Vector3(pl.global_position.x, PillarScript.GROUND_Y + 6.0, pl.global_position.z), pl.w)

		# Plane crash — vertical check uses both top AND bottom so hanging
		# ceiling pillars (high up) don't false-trigger.
		if alive and pl.is_solid_hazard() and GameConfig.crash_iframes <= 0.0:
			if absf(pl.global_position.x - airplane.position.x) < pl.w * 0.5 + 28.0 \
			and absf(pl.global_position.z - airplane.position.z) < pl.d * 0.5 + 28.0 \
			and airplane.position.y < pl.emerged_top_y + 26.0 \
			and airplane.position.y > pl.emerged_bottom_y - 26.0:
				_on_crash(pl)

		if not alive:
			to_remove.append(i)
	_cleanup(to_remove, _pillars)


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

	shaker.shake(GameConfig.shake_giant_intensity * 0.7, 0.35)
	time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
	flash_overlay.flash(0.35, 0.12)   # warm/red damage flash
	_spawn_explosion(airplane.position, SmokeBurstScript.Kind.PLANE_HIT, 1.0)

	if GameConfig.hp <= 0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
		_on_game_over()


# ----- Giants ----------------------------------------------------------------

func _construct_giant() -> void:
	var giant := TargetScene.instantiate()
	giant.is_giant = true
	add_child(giant)
	giant.position = Vector3(2200.0, 170.0, 0.0)
	giant.scale = Vector3.ONE * 2.2   # loom huge — the screen-erasing climax
	giant.wall = null
	_targets.append(giant)


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

		# Pillar hit. A BREAKABLE pillar shatters on ANY body hit (the glowing
		# core is the aim point, not a pixel-perfect weak spot — far better feel
		# with manual aim); an UNBREAKABLE pillar just sparks and stops the shot.
		var broke := false
		var blocked := false
		for pl in _pillars:
			if not pl.is_solid_hazard():
				continue
			# AABB overlap with a small margin (front face emphasised in -X).
			if m.position.x > pl.global_position.x - pl.w * 0.5 - HIT_RADIUS \
			and m.position.x < pl.global_position.x + pl.w * 0.5 + HIT_RADIUS \
			and absf(m.position.y - pl.global_position.y) < pl.h * 0.5 + HIT_RADIUS \
			and absf(m.position.z - pl.global_position.z) < pl.d * 0.5 + HIT_RADIUS:
				if pl.breakable and pl.core_alive:
					_on_core_hit(pl, m)
					broke = true
				else:
					_spawn_explosion(m.position, SmokeBurstScript.Kind.BLOCK_SPARK, 1.0)
					shaker.shake(GameConfig.shake_hit_intensity * 0.6, 0.08)
					blocked = true
				break
		if broke:
			if m.pierce > 0:
				m.pierce -= 1            # punch through, keep flying
			else:
				to_remove.append(i)
			continue
		if blocked:
			to_remove.append(i)
			continue

		if m.position.x > 15000.0 or m.position.y < -1000.0:
			to_remove.append(i)
	_cleanup(to_remove, _missles)


func _on_core_hit(pl: Node3D, m: Node3D) -> void:
	var prev_tier: int = GameConfig.combo_tier
	pl.shatter()
	GameConfig.register_core_hit()
	if GameConfig.combo > _max_combo_run:
		_max_combo_run = GameConfig.combo
	if GameConfig.combo_tier > _max_tier_run:
		_max_tier_run = GameConfig.combo_tier

	# Moment text — First Hit happens at most once per run; Tier Up at each new
	# threshold. They land OVER the action so the player FEELS the milestone.
	# First Hit teaches the COMBO concept with a "+1 COMBO" subtitle (the player
	# learns that hitting cores grows a counter).
	if not _seen_first_hit:
		_seen_first_hit = true
		_show_moment("First Hit!", Color(1.0, 0.95, 0.55), 72, "+1 COMBO")
	_bump_combo_widget()

	var pos: Vector3 = pl.core_world_pos()
	_spawn_explosion(pos, SmokeBurstScript.Kind.PILLAR_BREAK, float(m.tier + 1))

	# Tier-up celebration.
	if GameConfig.combo_tier > prev_tier:
		_show_moment("Tier %d!" % GameConfig.combo_tier, _tier_color(GameConfig.combo_tier), 88)
		shaker.shake(GameConfig.shake_hit_intensity * 1.6, 0.2)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.4)
		flash_overlay.flash(0.28, 0.12, false)
	else:
		shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
		time_scaler.request_hitstop(GameConfig.hitstop_duration)


func _on_giant_chip(g: Node3D) -> void:
	# Missile too weak: visible "bounce" so the player learns to grow first.
	_spawn_explosion(g.position, SmokeBurstScript.Kind.GIANT_CHIP, 1.0)
	shaker.shake(GameConfig.shake_hit_intensity * 0.8, 0.1)
	flash_overlay.flash(0.12, 0.06)


func _on_giant_hit(g: Node3D, killed: bool) -> void:
	if not killed:
		_spawn_explosion(g.position, SmokeBurstScript.Kind.GIANT_HIT, 2.0)
		shaker.shake(GameConfig.shake_hit_intensity * 1.8, GameConfig.shake_hit_duration * 1.3)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
		flash_overlay.flash(0.22, 0.10)
		return

	# Giant defeated: bump the run-stats counter for the recap screen.
	_giants_killed_run += 1
	_show_moment("Giant Down!", Color(1.0, 0.45, 0.25), 92)
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
		for pl in _pillars:
			if not is_instance_valid(pl):
				continue
			if not pl.is_solid_hazard():
				continue
			var ppos: Vector3 = pl.global_position
			_spawn_explosion(ppos, SmokeBurstScript.Kind.PILLAR_BREAK, 3.0)
			if pl.breakable and pl.core_alive:
				pl.shatter()

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


func _spawn_shockwave(pos: Vector3, end_scale_: float, duration_: float) -> void:
	var ring: Node3D = ShockwaveRingScript.new()
	ring.end_scale = end_scale_
	ring.duration = duration_
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


func _on_game_over() -> void:
	var traveled: int = int(GameConfig.distance)
	var old_best: int = GameConfig.best_distance
	var is_new_best: bool = traveled > old_best
	if is_new_best:
		GameConfig.best_distance = traveled
		var SaveDataScript := preload("res://scripts/SaveData.gd")
		SaveDataScript.save_best(GameConfig.best_distance)
	# Brief delay so the death juice (shake / falling plane) reads before the
	# recap screen swoops in.
	get_tree().create_timer(1.2).timeout.connect(func(): _show_gameover_screen(is_new_best))


# ----- Title / Game-over overlays --------------------------------------------

func _build_title_overlay() -> void:
	_title_layer = ColorRect.new()
	_title_layer.anchor_right = 1.0
	_title_layer.anchor_bottom = 1.0
	_title_layer.color = Color(0.0, 0.0, 0.0, 0.45)
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_title_layer)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
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
	_gameover_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameover_layer.visible = false
	hud.add_child(_gameover_layer)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gameover_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
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
	return l


func _show_title() -> void:
	GameConfig.status = GameConfig.STATUS_TITLE
	_title_layer.visible = true
	_gameover_layer.visible = false
	_set_play_hud_visible(false)


func _start_game() -> void:
	GameConfig.status = GameConfig.STATUS_PLAYING
	_title_layer.visible = false
	_gameover_layer.visible = false
	_set_play_hud_visible(true)
	_seen_first_hit = false


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
	for r in _hud_heart_rects:
		r.visible = v


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


## Color tied to combo tier — white -> warm yellow -> orange -> hot red.
func _tier_color(tier: int) -> Color:
	match tier:
		1: return Color(1.0, 0.95, 0.55)
		2: return Color(1.0, 0.7, 0.30)
		3: return Color(1.0, 0.42, 0.22)
		_: return Color(1, 1, 1, 1)


# ----- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var left_click: bool = (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT)
	var primary: bool = left_click or event.is_action_pressed("fire_missle")

	if event.is_action_pressed("reset_game"):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
		return

	if not primary:
		return

	match GameConfig.status:
		GameConfig.STATUS_TITLE:
			_start_game()
		GameConfig.STATUS_PLAYING:
			_fire_missle()
		GameConfig.STATUS_GAME_OVER:
			get_tree().reload_current_scene()
