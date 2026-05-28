extends Node3D
## Top-level coordinator. Spawns/updates/draws everything that the original
## `Tester` class managed inside its `Update()` / `Draw()` pair.
##
## The original game-loop branches:
##   - status PLAYING:  spawn ennemies, structures, coins; advance distance / level / energy.
##   - status GAME_OVER: plane falls; particles freeze.

const AirPlaneScene := preload("res://scenes/AirPlane.tscn")
const MissleScene := preload("res://scenes/Missle.tscn")
const BuildingScene := preload("res://scenes/Building.tscn")
const TargetScene := preload("res://scenes/Target.tscn")
const ParticleScript := preload("res://scripts/Particle.gd")
const WhiteSphereScript := preload("res://scripts/WhiteSphere.gd")
const GuideOverlayScript := preload("res://scripts/GuideOverlay.gd")
const ShockwaveRingScript := preload("res://scripts/ShockwaveRing.gd")

const STEP_TIME := 0.01
const PLANE_BASE_X := -100.0
## A giant only becomes lockable / hittable once it has loomed in to this x, so
## the climax kill lands in the mid-frame "hero zone" (big, centered, juice
## on-screen) rather than as a tiny pop on the horizon or below the camera.
const GIANT_VULNERABLE_X := 950.0

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
var _buildings: Array[Node3D] = []
var _structures: Array[Node3D] = []
var _targets: Array[Node3D] = []  # red lock-on targets attached to walls
var _particles: Array[Node3D] = []
var _white_spheres: Array[Node3D] = []
var _shockwaves: Array[Node3D] = []
var _guide_overlay: Node3D


func _ready() -> void:
	GameConfig.reset_to_defaults()
	director.reset()

	# Airplane.
	airplane = AirPlaneScene.instantiate()
	airplane.position = Vector3(PLANE_BASE_X, GameConfig.plane_default_height, 0.0)
	airplane.scale = Vector3.ONE * GameConfig.plane_scale
	add_child(airplane)

	# Guide-line + lock-on circle overlay.
	_guide_overlay = GuideOverlayScript.new()
	add_child(_guide_overlay)

	# Chase camera (see _update_camera): sits just behind + slightly above the
	# plane, looking forward along +X so the plane's tail is in frame and the
	# action approaches from ahead. Lighting is owned by the Atmosphere node.
	_update_camera()

	# 0-3s ad hook: prime the corridor so frame 1 isn't an empty desert.
	# Pre-spawn background ruins + one immediate building+target staggered along +X.
	for k in 4:
		_build_structures()
	_prime_opening_corridor()


func _prime_opening_corridor() -> void:
	# Three building+target pairs at staggered x, so the camera sees a depth chain
	# of "stuff coming" from frame 0.
	var distances: Array[float] = [1200.0, 2200.0, 3400.0]
	for x in distances:
		var ww := 300.0 + randf() * 200.0
		var wh := 110.0 + randf() * 40.0
		var wd := 130.0
		var wall := BuildingScene.instantiate()
		add_child(wall); _buildings.append(wall)
		wall.position = Vector3(x, randf() * 60.0 + wh * 0.5, -60.0 + randf() * 120.0)
		wall.init_geometry(ww, wh, wd, GameColors.BROWN, 1)

		var target := TargetScene.instantiate()
		add_child(target)
		target.position = Vector3(wall.position.x - ww * 0.5 - 30.0, wall.position.y, wall.position.z)
		target.wall = wall
		_targets.append(target)


func _process(delta: float) -> void:
	var dt_ms: float = delta * 1000.0 * GameConfig.time_scale

	# Pass current mouse position (normalized) to airplane.
	airplane.set_mouse_pos(_get_normalized_mouse())
	airplane.set_world_target(_get_world_cursor())

	if GameConfig.status == GameConfig.STATUS_PLAYING:
		_tick_playing(dt_ms)
	else:
		_tick_falling()

	_fly_missles(dt_ms)
	_move_buildings(dt_ms)
	_move_structures(dt_ms)
	_update_white_spheres(dt_ms)
	_update_particles(dt_ms)
	_update_shockwaves(dt_ms)

	_update_camera()
	_guide_overlay.update_overlay(airplane.position, _targets)
	_update_hud()


func _tick_playing(dt_ms: float) -> void:
	# Every ~5m: drop background structures.
	if floori(GameConfig.distance) % 5 == 0:
		_build_structures()

	var d_int := floori(GameConfig.distance)

	# Speed update tick.
	if d_int % GameConfig.distance_for_speed_update == 0 and d_int > GameConfig.speed_last_update:
		GameConfig.speed_last_update = d_int
		GameConfig.target_base_speed += GameConfig.increment_speed_by_time * dt_ms

	# Building spawn tick (formerly enemy spawn).
	if d_int % GameConfig.distance_for_ennemies_spawn == 0 and d_int > GameConfig.ennemy_last_spawn:
		GameConfig.ennemy_last_spawn = d_int
		_construct_building()

	# Level update.
	if d_int % GameConfig.distance_for_level_update == 0 and d_int > GameConfig.level_last_update:
		GameConfig.level_last_update = d_int
		GameConfig.level += 1
		GameConfig.target_base_speed = GameConfig.init_speed + GameConfig.increment_speed_by_level * GameConfig.level

	GameConfig.distance += GameConfig.speed * dt_ms * GameConfig.ratio_speed_distance
	GameConfig.energy -= GameConfig.speed * dt_ms * GameConfig.ratio_speed_energy
	GameConfig.energy = maxf(0.0, GameConfig.energy)
	director.tick_weapon(dt_ms / 1000.0)
	if GameConfig.energy < 1.0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
		_on_game_over()

	GameConfig.base_speed += (GameConfig.target_base_speed - GameConfig.base_speed) * dt_ms * 0.02
	GameConfig.speed = GameConfig.base_speed * GameConfig.plane_speed


func _tick_falling() -> void:
	# Plane animation is handled inside AirPlane.gd. We just clear particles.
	for p in _particles:
		p.queue_free()
	_particles.clear()


## Chase cam: stand a fixed distance behind (-X) and above the plane, follow it
## laterally (z) so it never steers out of frame, and partly vertically (y) to
## keep it framed without bobbing the whole world. Looks forward along +X. The
## shaker's rest pose is refreshed to this transform each frame so screen-shake
## offsets ride on top of the moving rig instead of fighting it.
func _update_camera() -> void:
	var p: Vector3 = airplane.position
	var cam_y: float = GameConfig.plane_default_height \
		+ (p.y - GameConfig.plane_default_height) * 0.6 + 55.0
	camera.position = Vector3(PLANE_BASE_X - 230.0, cam_y, p.z)
	camera.look_at(Vector3(PLANE_BASE_X + 1400.0, p.y - 10.0, p.z), Vector3.UP)
	shaker.refresh_base()


func _get_normalized_mouse() -> Vector2:
	var win := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	return Vector2(-1.0 + (m.x / win.x) * 2.0, 1.0 - (m.y / win.y) * 2.0)


## Casts a ray from the camera through the mouse cursor and returns the world
## point where it hits the airplane's x-plane (x = PLANE_BASE_X). With this,
## the cursor lines up with the airplane on screen pixel-for-pixel.
func _get_world_cursor() -> Vector3:
	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(ray_dir.x) < 0.0001:
		return Vector3(PLANE_BASE_X, GameConfig.plane_default_height, 0.0)
	var t: float = (PLANE_BASE_X - ray_origin.x) / ray_dir.x
	return ray_origin + ray_dir * t


# ----- Buildings -------------------------------------------------------------

func _construct_building() -> void:
	if director.consume_giant_due():
		_construct_giant()
		return
	# Low desert-ruin blocks flanking the path. Kept SHORT (so the teal sky and
	# the giant silhouette stay visible above them) and pushed well out in z (so
	# they frame the corridor instead of engulfing the camera as tan walls), with
	# varied length so gaps reveal the open desert behind.
	var top := BuildingScene.instantiate()
	add_child(top); _buildings.append(top)
	var top_len := 350.0 + randf() * 300.0
	var top_h := 90.0 + randf() * 70.0
	top.position = Vector3(4000.0, top_h * 0.5, -340.0 - randf() * 120.0)
	top.init_geometry(top_len, top_h, 90, GameColors.BROWN, 0)

	var bot := BuildingScene.instantiate()
	add_child(bot); _buildings.append(bot)
	var bot_len := 350.0 + randf() * 300.0
	var bot_h := 90.0 + randf() * 70.0
	bot.position = Vector3(4000.0, bot_h * 0.5, 340.0 + randf() * 120.0)
	bot.init_geometry(bot_len, bot_h, 90, GameColors.BROWN, 0)

	# A wall in the middle (transparent, type=1).
	var wall := BuildingScene.instantiate()
	add_child(wall); _buildings.append(wall)
	var ww := 200.0 + randf() * 700.0
	var wh := 90.0 + randf() * 70.0
	var wd := 110.0 + randf() * 110.0
	wall.position = Vector3(4000.0, randf() * 150.0 + wh * 0.5, -100.0 + randf() * 200.0)
	wall.init_geometry(ww, wh, wd, GameColors.BROWN_DARK, 1)

	# Target attached to the wall — a red icosahedron in front of it. The
	# guide overlay uses `target.wall` to compute the forward-ray/wall-face
	# intersection (matches `Tester::guideLines()` in the original).
	var target := TargetScene.instantiate()
	add_child(target)
	target.position = Vector3(wall.position.x - ww * 0.5 - 30.0, wall.position.y, wall.position.z)
	target.wall = wall
	_targets.append(target)


func _construct_giant() -> void:
	# A standalone giant target — no flanking buildings, so it dominates the frame.
	var giant := TargetScene.instantiate()
	giant.is_giant = true
	add_child(giant)
	giant.position = Vector3(2200.0, 125.0, 0.0)
	giant.wall = null
	_targets.append(giant)


func _build_structures() -> void:
	var n := 1 + floori(randf() * 5.0)
	for i in n:
		var s := BuildingScene.instantiate()
		add_child(s); _structures.append(s)
		var h := 30.0 + randf() * 50.0
		s.position = Vector3(4000.0, h * 0.5, -1000.0 + randf() * 650.0)
		s.init_geometry(30.0 + randf() * 50.0, h, 30.0 + randf() * 50.0, GameColors.WHITE, 0)
	for i in n:
		var s2 := BuildingScene.instantiate()
		add_child(s2); _structures.append(s2)
		var h2 := 30.0 + randf() * 50.0
		s2.position = Vector3(4000.0, h2 * 0.5, 350.0 + randf() * 1000.0)
		s2.init_geometry(30.0 + randf() * 50.0, h2, 30.0 + randf() * 50.0, GameColors.WHITE, 0)


func _move_buildings(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _buildings.size():
		var b := _buildings[i]
		b.step(dt_ms)

		# Plane collision (only check center distance with a generous tolerance).
		if absf(b.position.y - airplane.position.y) < b.h * 0.5 + 30.0:
			if absf(b.position.z - airplane.position.z) < b.d * 0.5 + 30.0:
				if absf(b.position.x - airplane.position.x) < b.w * 0.5 + 30.0:
					var diff := airplane.position - b.position
					var d := diff.length()
					if d > 0.0:
						GameConfig.plane_collision_speed_x = 100.0 * diff.x / d
						GameConfig.plane_collision_speed_y = 100.0 * diff.y / d

		if b.position.x < -1000.0:
			to_remove.append(i)
	_cleanup(to_remove, _buildings)

	# Targets scroll along with their walls. Giants scroll slower so they loom in
	# the mid-frame "hero zone" long enough to be destroyed on-screen (otherwise
	# they reach the camera and the kill juice fires below the visible frame).
	var to_remove_targets: Array[int] = []
	var scroll: float = GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	for i in _targets.size():
		var f: float = 0.6 if _targets[i].is_giant else 1.0
		_targets[i].position.x -= scroll * f
		if _targets[i].position.x <= -1000.0:
			to_remove_targets.append(i)
	_cleanup(to_remove_targets, _targets)


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
	match GameConfig.weapon_stage:
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
	m.position = airplane.position + Vector3(40.0, 0.0, 0.0)

	# Set scale per current weapon stage.
	match GameConfig.weapon_stage:
		1: m.missile_scale = GameConfig.missile_scale_stage1
		2: m.missile_scale = GameConfig.missile_scale_stage2
		_: m.missile_scale = GameConfig.missile_scale_stage3

	# Aim direction: from plane to current world cursor target.
	var aim: Vector3 = Vector3.RIGHT
	var to_cursor: Vector3 = _get_world_cursor() - m.position
	if to_cursor.length_squared() > 1.0:
		aim = to_cursor.normalized()
	# Tilt by yaw_offset (rotate around Y).
	if absf(yaw_offset_deg) > 0.01:
		aim = aim.rotated(Vector3.UP, deg_to_rad(yaw_offset_deg))

	# Inherit plane velocity (the "throw" feel).
	var forward_speed: float = GameConfig.missile_initial_forward_speed
	var drop_speed: float = GameConfig.missile_initial_drop_speed
	m.velocity = aim * forward_speed + Vector3.DOWN * drop_speed + airplane.estimated_velocity

	# Target: lock-on only — no nearest fallback (handoff §부록C "완전 유도 금지").
	m.target = _find_missle_target()


func _find_missle_target() -> Node3D:
	var locked: Node3D = null
	var locked_dist: float = INF
	for t in _targets:
		if t.position.x <= airplane.position.x:
			continue
		# Hold fire on a giant until it has loomed into the hero zone.
		if t.is_giant and t.position.x > GIANT_VULNERABLE_X:
			continue
		# Giants are big looming bosses — lock from much farther so the climax
		# volley always acquires them; normal targets keep the tight lock.
		var lock_radius: float = GameConfig.missile_lock_radius * (14.0 if t.is_giant else 1.0)
		var dy: float = t.position.y - airplane.position.y
		var dz: float = t.position.z - airplane.position.z
		var d: float = sqrt(dy * dy + dz * dz)
		if d < lock_radius and d < locked_dist:
			locked_dist = d
			locked = t
	return locked  # may be null — missile then flies straight (with gravity)


func _fly_missles(dt_ms: float) -> void:
	const HIT_RADIUS := 22.0
	var to_remove: Array[int] = []
	for i in _missles.size():
		var m := _missles[i]
		m.step(dt_ms)

		var hit := false
		# Target hit: swept segment-sphere check (missile moves in 3D now).
		for j in _targets.size():
			var t_pos: Vector3 = _targets[j].position
			if _targets[j].is_giant and t_pos.x > GIANT_VULNERABLE_X:
				continue
			if _segment_point_distance(m.prev_position, m.position, t_pos) < (HIT_RADIUS * (8.0 if _targets[j].is_giant else 1.0)):
				# Capture flag BEFORE _on_giant_hit mutates _targets.
				var is_g: bool = _targets[j].is_giant
				var killed: bool = _targets[j].take_damage(1)
				if is_g:
					_on_giant_hit(_targets[j], killed)
				else:
					_spawn_particles_at(t_pos, 30, 1, 8)
					_spawn_shockwave(t_pos, 8.0, 0.4)
					shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
					time_scaler.request_hitstop(GameConfig.hitstop_duration)
					flash_overlay.flash(0.15, 0.06)
					if killed:
						_targets[j].queue_free()
						_targets.remove_at(j)
				hit = true
				break

		# Wall (building) hit: missile is inside an AABB.
		if not hit:
			for b in _buildings:
				if absf(m.position.x - b.position.x) < b.w * 0.5 \
				and absf(m.position.y - b.position.y) < b.h * 0.5 \
				and absf(m.position.z - b.position.z) < b.d * 0.5:
					_make_white_spheres(m.position, false)
					_spawn_shockwave(m.position, 10.0, 0.45)
					shaker.shake(GameConfig.shake_hit_intensity * 1.4, GameConfig.shake_hit_duration * 1.2)
					time_scaler.request_hitstop(GameConfig.hitstop_duration)
					flash_overlay.flash(0.15, 0.08)
					hit = true
					break

		# Off-screen / underground.
		if not hit and (m.position.x > 15000.0 or m.position.y < -1000.0):
			hit = true

		if hit:
			to_remove.append(i)
	_cleanup(to_remove, _missles)


## Closest distance from point `p` to segment `a→b`.
func _segment_point_distance(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab: Vector3 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return a.distance_to(p)
	var u: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return (a + ab * u).distance_to(p)


# ----- Particles + white spheres --------------------------------------------

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


func _on_giant_hit(g: Node3D, killed: bool) -> void:
	if not killed:
		# Chip hit: medium juice.
		_spawn_particles_at(g.position, 25, 1, 9)
		_spawn_shockwave(g.position, 14.0, 0.4)
		shaker.shake(GameConfig.shake_hit_intensity * 1.6, GameConfig.shake_hit_duration * 1.3)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
		flash_overlay.flash(0.22, 0.10)
		_make_white_spheres(g.position, false)
		return

	# Kill: full showpiece combo. Use bright (cooler) flash to read as climactic.
	time_scaler.request_slowmo(GameConfig.slowmo_giant_scale, GameConfig.slowmo_giant_duration)
	shaker.shake(GameConfig.shake_giant_intensity, GameConfig.shake_giant_duration)
	flash_overlay.flash(0.5, 0.35, false)
	_spawn_shockwave(g.position, 40.0, 0.8)
	_make_white_spheres(g.position, true)
	_spawn_particles_at(g.position, 80, 1, 12)

	# Remove from _targets array (so it stops being hit-tested) but fade the mesh.
	var idx: int = _targets.find(g)
	if idx >= 0:
		_targets.remove_at(idx)
	g.start_fade(0.6)


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


# ----- Helpers ---------------------------------------------------------------

## Removes indices (sorted ascending) from `arr`, freeing the nodes.
func _cleanup(indices: Array[int], arr: Array[Node3D]) -> void:
	for k in range(indices.size() - 1, -1, -1):
		var idx := indices[k]
		var n := arr[idx]
		n.queue_free()
		arr.remove_at(idx)


func _update_hud() -> void:
	distance_label.text = "Distance: %d   Level: %d" % [int(GameConfig.distance), GameConfig.level]
	energy_bar.value = GameConfig.energy
	best_label.text = "Best: %d" % GameConfig.best_distance
	if GameConfig.status == GameConfig.STATUS_GAME_OVER:
		var is_new_best: bool = int(GameConfig.distance) > GameConfig.best_distance
		status_label.text = ("NEW BEST!  Press R to fly again" if is_new_best
							 else "GAME OVER  —  Press R to fly again")
	else:
		status_label.text = ""


func _on_game_over() -> void:
	var traveled: int = int(GameConfig.distance)
	if traveled > GameConfig.best_distance:
		GameConfig.best_distance = traveled
		var SaveDataScript := preload("res://scripts/SaveData.gd")
		SaveDataScript.save_best(GameConfig.best_distance)


# ----- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire_missle"):
		_fire_missle()
	elif event.is_action_pressed("reset_game"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()
