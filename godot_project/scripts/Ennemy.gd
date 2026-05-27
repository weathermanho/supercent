extends Node3D
## Single enemy. Drawn as a red icosahedron (PrismMesh with low resolution
## is not exactly an icosahedron — Godot exposes SphereMesh as the closest
## primitive, but for the spiky look we build one from SurfaceTool).

var angle: float = 0.0
var distance: float = 0.0
var spin_y: float = 0.0
var spin_z: float = 0.0


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 15.0
	mesh.height = 30.0
	mesh.radial_segments = 6   # low-poly so the silhouette looks faceted, like an icosahedron
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameColors.RED
	mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func update_orbit(dt_ms: float) -> void:
	angle += GameConfig.speed * dt_ms * GameConfig.ennemies_speed
	if angle > TAU:
		angle -= TAU
	position.y = -GameConfig.sea_radius + sin(angle) * distance
	position.x = cos(angle) * distance
	position.z = 0.0

	spin_z += randf() * 0.1
	spin_y += randf() * 0.1
	rotation.z = spin_z
	rotation.y = spin_y
