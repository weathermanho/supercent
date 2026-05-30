extends Node3D
## Layered destruction VFX. Per-situation RECIPES so a pillar-shatter, an
## ineffective giant chip and a screen-erasing finish all look distinct — not
## the same cartoony round puff every time. Each recipe mixes:
##   - CHUNKS: irregular concrete blocks (random asymmetric box scales + random
##     rotation), dark to ash-gray, slowly rise and dissipate. NOT spheres —
##     spheres read as bubblegum. Boxes read as concrete dust.
##   - FIRE:  short bright unshaded warm cores.
##   - EMBER: tiny bright dots that arc out under gravity and fade.
##   - DEBRIS: dark concrete shards spinning under gravity.
##
## Ticked by Main via step(dt_ms); honours GameConfig.time_scale (dt is
## pre-scaled) so plumes slew into slow-motion during the finish.

enum Kind { PILLAR_BREAK, GIANT_CHIP, GIANT_HIT, GIANT_FINISH, GROUND_DUST, PLANE_HIT, BLOCK_SPARK }

var kind: int = Kind.PILLAR_BREAK
var power: float = 1.0

class Puff:
	var node: MeshInstance3D
	var mat: StandardMaterial3D
	var vel: Vector3
	var age: float = 0.0
	var life: float = 1.0
	var s0: Vector3 = Vector3.ONE
	var s1: Vector3 = Vector3.ONE
	var base_alpha: float = 0.4
	var ptype: int = 0   # 0=smoke chunk, 1=fire, 2=debris, 3=ember
	var spin: Vector3 = Vector3.ZERO
	var grav: float = 0.0
	var drag: float = 1.6

var _puffs: Array = []


func _ready() -> void:
	match kind:
		Kind.PILLAR_BREAK: _build_pillar_break()
		Kind.GIANT_CHIP:   _build_giant_chip()
		Kind.GIANT_HIT:    _build_giant_hit()
		Kind.GIANT_FINISH: _build_giant_finish()
		Kind.GROUND_DUST:  _build_ground_dust()
		Kind.PLANE_HIT:    _build_plane_hit()
		Kind.BLOCK_SPARK:  _build_block_spark()


# ----- Recipes ---------------------------------------------------------------

func _build_pillar_break() -> void:
	# Concrete shatter: chunky gray plume + a brief warm core + bouncing shards.
	var p: float = maxf(power, 0.6)
	var n_chunks: int = int(6 + p * 3.0)
	var base_sz: float = 20.0 + p * 8.0
	for i in n_chunks:
		_add_chunk(_gray_jitter(0.30, 0.55), base_sz, Vector3(0.0, 18.0 + randf() * 20.0, 0.0), 0.9 + randf() * 0.5)
	for i in 3:
		_add_fire(Color(1.0, 0.55, 0.18), 9.0 + p * 4.0, 0.18 + randf() * 0.12)
	for i in int(5 + p * 2.0):
		_add_debris(_gray_jitter(0.12, 0.22), 4.0 + p * 2.0 + randf() * 4.0, 0.6 + randf() * 0.5)
	for i in 2:
		_add_ember(0.6 + randf() * 0.4)


func _build_giant_chip() -> void:
	# Ineffective hit. Tight warm spark cluster, almost no smoke — reads as
	# "missile bounced off". This is the moment that should say "you're too
	# weak, grow your combo".
	for i in 5:
		_add_fire(Color(1.0, 0.7, 0.25), 7.0 + randf() * 5.0, 0.14 + randf() * 0.1)
	for i in 2:
		_add_chunk(_gray_jitter(0.45, 0.6), 12.0, Vector3(0.0, 6.0, 0.0), 0.4)
	for i in 4:
		_add_ember(0.35 + randf() * 0.25)


func _build_giant_hit() -> void:
	# Effective body shot before the finish. Mid-size plume + visible damage.
	var p: float = 2.0
	for i in 8:
		_add_chunk(_gray_jitter(0.22, 0.45), 22.0 + p * 5.0, Vector3(0.0, 22.0, 0.0), 0.9)
	for i in 4:
		_add_fire(Color(1.0, 0.6, 0.20), 12.0, 0.22)
	for i in 7:
		_add_debris(_gray_jitter(0.10, 0.20), 6.0 + randf() * 5.0, 0.7)
	for i in 4:
		_add_ember(0.7)


func _build_giant_finish() -> void:
	# Climactic. Multiple layers: a thick dark plume rising tall, a bright core,
	# long ember arcs, big debris. Sized so a cluster of these (Main spawns ~5)
	# reads as a screen-erasing detonation.
	var p: float = maxf(power, 3.0)
	for i in int(12 + p * 2.0):
		var sz: float = 30.0 + p * 10.0 + randf() * 14.0
		_add_chunk(_gray_jitter(0.12, 0.32), sz, Vector3((randf() - 0.5) * 30.0, 28.0 + randf() * 26.0, (randf() - 0.5) * 30.0), 1.3 + randf() * 0.7)
	for i in 6:
		_add_fire(Color(1.0, 0.6, 0.18), 18.0 + p * 5.0, 0.28 + randf() * 0.18)
	for i in 12:
		_add_debris(_gray_jitter(0.08, 0.18), 7.0 + randf() * 8.0, 0.9 + randf() * 0.6)
	for i in 10:
		_add_ember(1.0 + randf() * 0.8)


func _build_ground_dust() -> void:
	# Wide low brown-grey dust when a pillar erupts. Pure ground burst — no
	# fire, no debris. The light tan tint (warmer than concrete chunks) so the
	# eruption reads as kicked-up earth, not "explosion".
	var p: float = clampf(power, 0.5, 3.0)
	var base_sz: float = 24.0 + p * 12.0
	for i in int(7 + p * 4.0):
		var ang: float = randf() * TAU
		var rad: float = randf() * base_sz * 1.4
		var pf := _make_chunk(Color(0.42 + randf() * 0.1, 0.39 + randf() * 0.1, 0.33 + randf() * 0.08), base_sz)
		pf.node.position = Vector3(cos(ang) * rad, randf() * 6.0, sin(ang) * rad)
		pf.vel = Vector3((randf() - 0.5) * 26.0, 8.0 + randf() * 14.0, (randf() - 0.5) * 26.0)
		pf.life = 0.6 + randf() * 0.5
		pf.s1 = pf.s0 * 2.2
		pf.base_alpha = 0.35 + randf() * 0.15
		_puffs.append(pf)


func _build_plane_hit() -> void:
	# The plane just crashed into a pillar. Quick scrape — gray dust + 1 fire pop.
	for i in 5:
		_add_chunk(_gray_jitter(0.38, 0.55), 14.0, Vector3((randf() - 0.5) * 16.0, 12.0, (randf() - 0.5) * 16.0), 0.55)
	for i in 2:
		_add_fire(Color(1.0, 0.55, 0.20), 8.0, 0.12)


func _build_block_spark() -> void:
	# Missile bounced off an UNBREAKABLE pillar. Minimal: a couple of tiny grey
	# chips + a faint spark — "denied", not "destroyed".
	for i in 2:
		_add_chunk(_gray_jitter(0.45, 0.6), 8.0, Vector3((randf() - 0.5) * 10.0, 6.0, (randf() - 0.5) * 10.0), 0.32)
	for i in 2:
		_add_fire(Color(1.0, 0.75, 0.30), 5.0, 0.10)
	for i in 3:
		_add_ember(0.3)


# ----- Puff builders ---------------------------------------------------------

func _add_chunk(color: Color, sz: float, vel: Vector3, life: float) -> void:
	var pf := _make_chunk(color, sz)
	pf.vel = vel + Vector3((randf() - 0.5) * 20.0, 0.0, (randf() - 0.5) * 20.0)
	pf.life = life
	pf.s1 = pf.s0 * (1.5 + randf() * 0.8)
	pf.base_alpha = 0.32 + randf() * 0.2
	_puffs.append(pf)


## Irregular concrete-chunk shaped puff: a box mesh with each axis scaled
## independently and random rotation, so it doesn't read as a sphere/balloon.
func _make_chunk(color: Color, sz: float) -> Puff:
	var pf := Puff.new()
	pf.mat = _mat(color, false)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	pf.node = MeshInstance3D.new()
	pf.node.mesh = mesh
	pf.node.set_surface_override_material(0, pf.mat)
	add_child(pf.node)
	pf.node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	pf.ptype = 0
	pf.s0 = Vector3(
		sz * (0.55 + randf() * 0.7),
		sz * (0.45 + randf() * 0.85),
		sz * (0.55 + randf() * 0.7))
	pf.node.scale = pf.s0
	pf.drag = 1.6
	return pf


func _add_fire(color: Color, sz: float, life: float) -> void:
	var pf := Puff.new()
	pf.mat = _mat(color, true)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	pf.node = MeshInstance3D.new()
	pf.node.mesh = mesh
	pf.node.set_surface_override_material(0, pf.mat)
	add_child(pf.node)
	pf.node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	pf.ptype = 1
	pf.node.position = Vector3((randf() - 0.5) * 16.0, randf() * 10.0, (randf() - 0.5) * 16.0)
	pf.vel = Vector3((randf() - 0.5) * 26.0, 20.0 + randf() * 24.0, (randf() - 0.5) * 26.0)
	pf.s0 = Vector3.ONE * sz * (0.7 + randf() * 0.5)
	pf.s1 = pf.s0 * 0.25
	pf.life = life
	pf.base_alpha = 1.0
	pf.node.scale = pf.s0
	pf.drag = 2.0
	_puffs.append(pf)


func _add_debris(color: Color, sz: float, life: float) -> void:
	var pf := Puff.new()
	pf.mat = _mat(color, false)
	var mesh := PrismMesh.new()
	mesh.size = Vector3.ONE
	pf.node = MeshInstance3D.new()
	pf.node.mesh = mesh
	pf.node.set_surface_override_material(0, pf.mat)
	add_child(pf.node)
	pf.ptype = 2
	pf.vel = Vector3((randf() - 0.5) * 140.0, 40.0 + randf() * 80.0, (randf() - 0.5) * 140.0)
	pf.s0 = Vector3.ONE * sz
	pf.s1 = pf.s0
	pf.life = life
	pf.base_alpha = 1.0
	pf.spin = Vector3(randf() * 14.0, randf() * 14.0, randf() * 14.0)
	pf.grav = 220.0
	pf.node.scale = pf.s0
	_puffs.append(pf)


func _add_ember(life: float) -> void:
	var pf := Puff.new()
	pf.mat = _mat(Color(1.0, 0.65 + randf() * 0.2, 0.25), true)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 4
	pf.node = MeshInstance3D.new()
	pf.node.mesh = mesh
	pf.node.set_surface_override_material(0, pf.mat)
	add_child(pf.node)
	pf.ptype = 3
	pf.vel = Vector3((randf() - 0.5) * 160.0, 60.0 + randf() * 90.0, (randf() - 0.5) * 160.0)
	pf.s0 = Vector3.ONE * (2.5 + randf() * 2.0)
	pf.s1 = pf.s0 * 0.6
	pf.life = life
	pf.base_alpha = 1.0
	pf.grav = 180.0
	pf.node.scale = pf.s0
	_puffs.append(pf)


# ----- Tick ------------------------------------------------------------------

func step(dt_ms: float) -> bool:
	var delta: float = dt_ms / 1000.0
	position.x -= GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0

	var alive := false
	for pf in _puffs:
		if pf.node == null:
			continue
		pf.age += delta
		var t: float = pf.age / pf.life
		if t >= 1.0:
			pf.node.queue_free()
			pf.node = null
			continue
		alive = true

		pf.node.position += pf.vel * delta
		if pf.grav > 0.0:
			pf.vel.y -= pf.grav * delta
		else:
			pf.vel *= maxf(1.0 - pf.drag * delta, 0.0)
			pf.vel.y += 6.0 * delta   # gentle buoyancy for smoke
		if pf.spin.length_squared() > 0.0:
			pf.node.rotation += pf.spin * delta

		var s_lerp: float = _ease_out(t)
		pf.node.scale = pf.s0.lerp(pf.s1, s_lerp)

		match pf.ptype:
			0:   # chunk smoke: pop in then long fade
				var a: float = pf.base_alpha * clampf(t / 0.12, 0.0, 1.0) * (1.0 - t)
				pf.mat.albedo_color.a = a
			1:   # fire: fast fade, emission falls off
				pf.mat.albedo_color.a = pf.base_alpha * (1.0 - t)
				pf.mat.emission_energy_multiplier = 5.0 * (1.0 - t)
			2:   # debris: hold opaque then fade near the end
				pf.mat.albedo_color.a = clampf((1.0 - t) / 0.3, 0.0, 1.0)
			3:   # ember: glow falls off
				pf.mat.albedo_color.a = (1.0 - t)
				pf.mat.emission_energy_multiplier = 6.0 * (1.0 - t)

	return alive


# ----- Helpers ---------------------------------------------------------------

func _gray_jitter(lo: float, hi: float) -> Color:
	var v: float = lo + randf() * (hi - lo)
	# Small RGB jitter so puffs vary in tone (not perfectly identical greys).
	return Color(v + (randf() - 0.5) * 0.04, v + (randf() - 0.5) * 0.04, v + (randf() - 0.5) * 0.05)


func _mat(c: Color, fire: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.metallic = 0.0
	if fire:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 5.0
	return m


func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 2.0)
