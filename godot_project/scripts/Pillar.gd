extends Node3D
class_name Pillar
## A colossal monolith that ERUPTS from the ground as it scrolls toward the
## player (the "걸리버" stage). Replaces the old desert-corridor walls.
##
## Two readabilities the player must parse in ~0.5s:
##   1. BREAKABLE (glowing red weak-point core) vs UNBREAKABLE (solid concrete).
##      Shoot a core -> pillar shatters, combo++, path opens.
##      No core -> pure dodge.
##   2. RISE BEHAVIOUR (kind): each telegraphs differently. Faster = louder
##      telegraph, so a hit always reads as "I could have seen that".
##
## Lifecycle: PRE (underground, scrolling) -> TELEGRAPH (ground crack/dust at
## footprint) -> RISING (lerp up) -> RISEN. FAKE pauses mid-rise then completes.

enum Kind { COLOSSUS, SPIKE, NORMAL, FAKE }
enum Phase { PRE, TELEGRAPH, RISING, RISEN, DEAD }

const GROUND_Y := 0.0

var kind: int = Kind.NORMAL
var breakable: bool = false

# Footprint / height (full extents).
var w: float = 90.0
var h: float = 240.0
var d: float = 90.0

# Tuning per kind, filled in configure().
var telegraph_time: float = 0.6
var rise_time: float = 0.6
var telegraph_x: float = 1900.0   # start telegraph once scrolled in to this x

var _phase: int = Phase.PRE
var _t: float = 0.0
var _y_hidden: float
var _y_risen: float
var core_alive: bool = false

var _body: MeshInstance3D
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _tele: MeshInstance3D
var _tele_mat: StandardMaterial3D
var _fake_done: bool = false
var _pending_erupt: bool = false

# Cached for Main's collision query: half-extents of the *emerged* part.
var emerged_top_y: float = GROUND_Y   # world y of the current top of the pillar


func configure(kind_: int, breakable_: bool) -> void:
	kind = kind_
	breakable = breakable_

	match kind:
		Kind.COLOSSUS:
			w = 220.0 + randf() * 120.0
			d = 220.0 + randf() * 120.0
			h = 620.0 + randf() * 260.0
			telegraph_time = 0.9
			rise_time = 1.6
			telegraph_x = 2200.0
		Kind.SPIKE:
			w = 42.0 + randf() * 16.0
			d = 42.0 + randf() * 16.0
			h = 340.0 + randf() * 120.0
			telegraph_time = 0.32
			rise_time = 0.22
			telegraph_x = 1500.0
		Kind.FAKE:
			w = 80.0 + randf() * 50.0
			d = 80.0 + randf() * 50.0
			h = 240.0 + randf() * 120.0
			telegraph_time = 0.5
			rise_time = 0.7
			telegraph_x = 1800.0
		_:  # NORMAL / cluster member
			w = 70.0 + randf() * 60.0
			d = 70.0 + randf() * 60.0
			h = 220.0 + randf() * 140.0
			telegraph_time = 0.55
			rise_time = 0.55
			telegraph_x = 1800.0

	_y_risen = GROUND_Y + h * 0.5
	_y_hidden = GROUND_Y - h * 0.5 - 40.0


func _ready() -> void:
	position.y = _y_hidden

	# Concrete body. Solid dark for unbreakable; slightly lighter & warmer for
	# breakable so even before you spot the core the silhouette hints "target".
	var body_color: Color = GameColors.BROWN if breakable else GameColors.BROWN_DARK
	_body = BoxFactory.make_box(w, h, d, body_color)
	add_child(_body)

	if breakable:
		# Glowing red weak-point core on the FRONT (-X) face, at roughly plane
		# altitude so the player aims at it head-on. Sized to the pillar.
		core_alive = true
		var cs: float = clampf(minf(w, d) * 0.5, 24.0, 80.0)
		_core = BoxFactory.make_box(cs, cs, cs, GameColors.RED)
		# Local position: front face (-X half-extent), height ~ plane altitude.
		var core_local_y: float = clampf(GameConfig.plane_default_height - _y_risen, -h * 0.4, h * 0.4)
		_core.position = Vector3(-w * 0.5 - cs * 0.3, core_local_y, 0.0)
		_core_mat = StandardMaterial3D.new()
		_core_mat.albedo_color = GameColors.RED
		_core_mat.emission_enabled = true
		_core_mat.emission = GameColors.RED
		_core_mat.emission_energy_multiplier = 3.0
		_core.set_surface_override_material(0, _core_mat)
		add_child(_core)

	# Telegraph footprint marker (flat, on the ground). Hidden until TELEGRAPH.
	_tele = BoxFactory.make_box(w * 1.05, 4.0, d * 1.05, GameColors.RED)
	_tele_mat = StandardMaterial3D.new()
	_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Warm warning colour for unbreakable (orange), red for breakable.
	var tcol: Color = Color(1.0, 0.2, 0.2, 0.0) if breakable else Color(1.0, 0.55, 0.1, 0.0)
	_tele_mat.albedo_color = tcol
	_tele_mat.emission_enabled = true
	_tele_mat.emission = Color(tcol.r, tcol.g, tcol.b)
	_tele_mat.emission_energy_multiplier = 2.0
	_tele.set_surface_override_material(0, _tele_mat)
	_tele.visible = false
	add_child(_tele)


## Advance scroll + rise. Returns false when the pillar is off-screen and should
## be removed.
func step(dt_ms: float, plane_x: float) -> bool:
	var delta: float = dt_ms / 1000.0
	position.x -= GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0

	match _phase:
		Phase.PRE:
			if position.x <= telegraph_x:
				_phase = Phase.TELEGRAPH
				_t = 0.0
				_tele.global_position = Vector3(global_position.x, GROUND_Y + 2.0, global_position.z)
				_tele.visible = true
		Phase.TELEGRAPH:
			_t += delta
			_pulse_telegraph()
			# Keep marker pinned to the ground footprint as we scroll.
			_tele.global_position = Vector3(global_position.x, GROUND_Y + 2.0, global_position.z)
			if _t >= telegraph_time:
				_phase = Phase.RISING
				_t = 0.0
				_pending_erupt = true
		Phase.RISING:
			_t += delta
			var u: float = clampf(_t / rise_time, 0.0, 1.0)
			# FAKE: stall at ~55% until the plane is nearly level in x, then finish.
			if kind == Kind.FAKE and not _fake_done:
				if u >= 0.55 and global_position.x - plane_x > 220.0:
					u = 0.55
					_t = rise_time * 0.55
					_pulse_telegraph()  # blink = 2nd telegraph
				else:
					_fake_done = true
			var eased: float = _ease_out(u) if kind != Kind.SPIKE else _ease_spike(u)
			position.y = lerpf(_y_hidden, _y_risen, eased)
			_fade_telegraph(1.0 - u)
			if u >= 1.0:
				position.y = _y_risen
				_phase = Phase.RISEN
				_tele.visible = false
		Phase.RISEN, Phase.DEAD:
			pass

	emerged_top_y = position.y + h * 0.5
	return position.x > -1200.0


## Is the pillar a *current* solid hazard the plane can crash into? Only when it
## has emerged enough to reach toward the play volume.
func is_solid_hazard() -> bool:
	if _phase == Phase.DEAD:
		return false
	return emerged_top_y > GROUND_Y + 40.0


## One-shot: true on the single frame the pillar begins erupting (for camera
## punch / dust). Clears itself.
func consume_erupt() -> bool:
	if _pending_erupt:
		_pending_erupt = false
		return true
	return false


## The core MeshInstance3D, used as a missile homing target (its global_position
## is the world core point). Null for unbreakable pillars.
func core_node() -> Node3D:
	return _core


## World position of the weak-point core (for missile hit tests).
func core_world_pos() -> Vector3:
	if _core == null:
		return global_position
	return _core.global_position


## Core is shootable once the pillar has risen enough to expose it.
func is_core_hittable() -> bool:
	return breakable and core_alive and _phase != Phase.DEAD \
		and emerged_top_y > GameConfig.plane_default_height - 60.0


## Called when a missile destroys the core. Triggers collapse; pillar should be
## removed by Main after this (it returns to a non-hazard DEAD state immediately).
func shatter() -> void:
	core_alive = false
	_phase = Phase.DEAD
	if _core != null:
		_core.visible = false
	_tele.visible = false
	# Quick collapse: sink + fade so the path visibly opens.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - h * 0.6, 0.35)
	tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.35)


func _pulse_telegraph() -> void:
	var hz: float = 9.0 if kind == Kind.SPIKE else 5.0
	var a: float = 0.35 + 0.45 * absf(sin(_t * TAU * hz))
	_tele_mat.albedo_color.a = a
	_tele_mat.emission_energy_multiplier = 1.5 + 2.0 * a


func _fade_telegraph(k: float) -> void:
	_tele_mat.albedo_color.a = clampf(k, 0.0, 1.0) * 0.5


func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


## Spike: a violent snap with a small overshoot (reads as "punched up out of
## the earth" rather than a smooth elevator).
func _ease_spike(u: float) -> float:
	if u >= 1.0:
		return 1.0
	# Back-ease-out: overshoots past 1 then settles.
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var p: float = u - 1.0
	return 1.0 + c3 * p * p * p + c1 * p * p
