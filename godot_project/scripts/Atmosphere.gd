extends Node3D
## Owns the world look: gradient sky, sand-colored fog, sand ground plane,
## warm directional light. Replaces Main._setup_lighting().

# image.png mood: tiny figures dwarfed by colossal concrete monoliths fading
# into a luminous cool mist. High-key haze (not black), desaturated steel sky,
# cool concrete floor. The warm red pillar cores + giant silhouette pop against
# this grey.
const SKY_TOP := Color8(132, 152, 170)         # muted steel blue
const SKY_HORIZON := Color8(196, 203, 210)     # misty light grey
const GROUND_COLOR := Color8(138, 140, 147)    # cool concrete floor
const FOG_COLOR := Color8(200, 206, 213)       # luminous cool mist
const SUN_COLOR := Color(0.95, 0.96, 1.0)      # cool white

@onready var _env: WorldEnvironment = $WorldEnv


func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_setup_sun()


func _setup_environment() -> void:
	var env := Environment.new()

	# Sky.
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = SKY_TOP
	psm.sky_horizon_color = SKY_HORIZON
	psm.ground_horizon_color = SKY_HORIZON
	psm.ground_bottom_color = GROUND_COLOR
	psm.sun_angle_max = 30.0
	psm.sun_curve = 0.5   # soft, mist-like horizon blend (no hard cut)
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient — misty scenes are high-ambient (soft, shadow-fill).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85

	# Fog — depth-based haze on the GROUND only. fog_sky_affect defaults to 1.0
	# in Godot 4, which tints the whole sky to the sand fog color and erases the
	# teal — set it to 0 so the sky keeps its vivid cool gradient and fog only
	# softens distant ground geometry.
	# Background fog disabled per user request — the steel/concrete palette
	# carries the mood by itself; the haze was crowding the picture.
	env.fog_enabled = false

	# Tonemap for warmer look.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	_env.environment = env


func _setup_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(20000.0, 20000.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.set_surface_override_material(0, mat)
	mi.position = Vector3(2000.0, -120.0, 0.0)
	add_child(mi)


func _setup_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-40.0), 0.0)
	sun.light_energy = 1.1
	sun.light_color = SUN_COLOR
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3000.0
	add_child(sun)
