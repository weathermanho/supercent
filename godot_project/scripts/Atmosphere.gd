extends Node3D
## Owns the world look: gradient sky, sand-colored fog, sand ground plane,
## warm directional light. Replaces Main._setup_lighting().

const SKY_TOP := Color8(70, 170, 195)          # vivid teal — match reference image
const SKY_HORIZON := Color8(228, 210, 170)     # sand horizon (matches ground)
const GROUND_COLOR := Color8(232, 210, 165)
const FOG_COLOR := Color8(232, 210, 165)
const SUN_COLOR := Color(1.0, 0.93, 0.82)

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
	psm.sun_curve = 0.25  # sharper horizon split — matches reference's strong cool/warm cut
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient — use the sky for soft fill.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6

	# Fog — depth-based haze on the GROUND only. fog_sky_affect defaults to 1.0
	# in Godot 4, which tints the whole sky to the sand fog color and erases the
	# teal — set it to 0 so the sky keeps its vivid cool gradient and fog only
	# softens distant ground geometry.
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_sky_affect = 0.0
	env.fog_density = 0.0006
	env.fog_depth_begin = 2200.0
	env.fog_depth_end = 7000.0

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
