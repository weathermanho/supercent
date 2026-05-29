extends Node3D
## Premium layered destruction smoke. Replaces flat box-puffs with a roiling
## plume built from many overlapping semi-transparent puffs:
##   - SMOKE: dark grey spheres that rise, swell and dissipate (the volume).
##   - FIRE:  short, bright warm cores that flash then vanish (the heat).
##   - DEBRIS: dark concrete shards thrown out under gravity (the mass).
## Overlapping translucency + slow rise + warm/cool contrast = the "고급/사실적"
## read inside the game's flat-shaded palette. Scaled by `power` (≈ tier 0..4).
##
## Ticked by Main via step(dt_ms); honours GameConfig.time_scale (dt is pre-scaled)
## so the plume slews into slow-motion during the giant finish.

var power: float = 1.0
var ground_burst: bool = false   # wide low dust (pillar eruption), no fire

const SMOKE_LO := Color(0.16, 0.16, 0.18)
const SMOKE_HI := Color(0.38, 0.37, 0.40)
const FIRE_HOT := Color(1.0, 0.78, 0.30)
const FIRE_CORE := Color(1.0, 0.45, 0.12)

class Puff:
	var node: MeshInstance3D
	var mat: StandardMaterial3D
	var vel: Vector3
	var age: float = 0.0
	var life: float = 1.0
	var s0: float = 1.0
	var s1: float = 2.0
	var base_alpha: float = 0.35
	var kind: int = 0   # 0 smoke, 1 fire, 2 debris
	var spin: Vector3 = Vector3.ZERO

var _puffs: Array = []


func _ready() -> void:
	var p: float = maxf(power, 0.4)
	var smoke_n: int = int(7 + p * 3.5)
	var fire_n: int = 0 if ground_burst else int(3 + p * 1.6)
	var debris_n: int = 0 if ground_burst else int(4 + p * 2.5)
	var base_r: float = (28.0 + p * 13.0) * (1.5 if ground_burst else 1.0)

	for i in smoke_n:
		_add_smoke(p, base_r)
	for i in fire_n:
		_add_fire(p)
	for i in debris_n:
		_add_debris(p)


func _add_smoke(p: float, base_r: float) -> void:
	var pf := Puff.new()
	pf.kind = 0
	pf.mat = _mat(SMOKE_LO.lerp(SMOKE_HI, randf()), false)
	pf.node = _sphere(pf.mat)
	add_child(pf.node)
	var ang: float = randf() * TAU
	var rad: float = randf() * base_r * 0.5
	pf.node.position = Vector3(cos(ang) * rad, randf() * base_r * 0.3, sin(ang) * rad)
	var rise: float = (18.0 + randf() * 26.0) * (0.6 if ground_burst else 1.0)
	pf.vel = Vector3((randf() - 0.5) * 24.0, rise, (randf() - 0.5) * 24.0)
	pf.s0 = base_r * (0.35 + randf() * 0.3)
	pf.s1 = base_r * (1.1 + randf() * 0.8)
	pf.life = (0.7 if ground_burst else 1.1) + randf() * 0.6
	pf.base_alpha = 0.30 + randf() * 0.18
	pf.node.scale = Vector3.ONE * pf.s0
	_puffs.append(pf)


func _add_fire(p: float) -> void:
	var pf := Puff.new()
	pf.kind = 1
	pf.mat = _mat(FIRE_CORE.lerp(FIRE_HOT, randf()), true)
	pf.node = _sphere(pf.mat)
	add_child(pf.node)
	pf.node.position = Vector3((randf() - 0.5) * 20.0, randf() * 14.0, (randf() - 0.5) * 20.0)
	pf.vel = Vector3((randf() - 0.5) * 30.0, 30.0 + randf() * 30.0, (randf() - 0.5) * 30.0)
	pf.s0 = (16.0 + p * 7.0) * (0.6 + randf() * 0.5)
	pf.s1 = pf.s0 * 0.25
	pf.life = 0.2 + randf() * 0.18
	pf.base_alpha = 1.0
	pf.node.scale = Vector3.ONE * pf.s0
	_puffs.append(pf)


func _add_debris(p: float) -> void:
	var pf := Puff.new()
	pf.kind = 2
	pf.mat = _mat(SMOKE_LO.darkened(0.2), false)
	var mesh := PrismMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	pf.node = MeshInstance3D.new()
	pf.node.mesh = mesh
	pf.node.set_surface_override_material(0, pf.mat)
	add_child(pf.node)
	pf.vel = Vector3((randf() - 0.5) * 120.0, 60.0 + randf() * 90.0, (randf() - 0.5) * 120.0)
	pf.s0 = 5.0 + p * 3.0 + randf() * 6.0
	pf.s1 = pf.s0
	pf.life = 0.6 + randf() * 0.5
	pf.base_alpha = 1.0
	pf.spin = Vector3(randf() * 12.0, randf() * 12.0, randf() * 12.0)
	pf.node.scale = Vector3.ONE * pf.s0
	_puffs.append(pf)


func step(dt_ms: float) -> bool:
	var delta: float = dt_ms / 1000.0
	# Scroll the whole plume with the world.
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
		if pf.kind == 2:
			pf.vel.y -= 240.0 * delta            # debris gravity
			pf.node.rotation += pf.spin * delta
		else:
			pf.vel *= (1.0 - 1.6 * delta)         # smoke/fire drag
			pf.vel.y += 8.0 * delta               # gentle buoyancy

		var s: float = lerpf(pf.s0, pf.s1, _ease_out(t))
		pf.node.scale = Vector3.ONE * s

		match pf.kind:
			0:  # smoke: pop in, long fade out; lighten as it cools
				var a: float = pf.base_alpha * (clampf(t / 0.15, 0.0, 1.0)) * (1.0 - t)
				pf.mat.albedo_color.a = a
			1:  # fire: bright, fast fade
				pf.mat.albedo_color.a = pf.base_alpha * (1.0 - t)
				pf.mat.emission_energy_multiplier = 4.0 * (1.0 - t)
			2:  # debris: fade only near the end
				pf.mat.albedo_color.a = clampf((1.0 - t) / 0.3, 0.0, 1.0)

	return alive


func _sphere(mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	return mi


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
		m.emission_energy_multiplier = 4.0
	return m


func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 2.0)
