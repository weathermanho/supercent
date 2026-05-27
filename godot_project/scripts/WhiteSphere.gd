extends Node3D
## Spherical impact puff. From `Tester::makeWhiteSpheres()` — fired when a
## missile hits a wall.

var sphere_scale: float = 2.0
var on_time: float = 0.0
var duration: float = 0.9
var color: Color = GameColors.PURE_WHITE
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.set_surface_override_material(0, mat)
	add_child(_mesh_instance)
	scale = Vector3.ONE * sphere_scale


func step(dt_ms: float) -> bool:
	on_time += 0.01
	position.x -= GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	sphere_scale += 0.2
	scale = Vector3.ONE * sphere_scale
	return on_time <= duration
