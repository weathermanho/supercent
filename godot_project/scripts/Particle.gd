extends Node3D
## Single explosion fragment. `Tester::explode()` builds these with random
## velocity + rotation; `MainGame._update_particles()` ticks them.

var color_index: int = 1  # 1 = red, 2 = teal (coin)
var inc_y: float = 0.0
var inc_z: float = 0.0
var inc_rx: float = 0.0
var inc_rz: float = 0.0
var on_time: float = 0.0
var duration: float = 0.3
var sprite_scale: float = 1.0
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(2.0, 2.0, 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameColors.RED if color_index == 1 else Color8(0, 153, 153)
	mat.roughness = 0.8
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.set_surface_override_material(0, mat)
	add_child(_mesh_instance)


## Returns false once expired, so the manager can free it.
func step(dt_ms: float) -> bool:
	on_time += dt_ms / 1000.0
	position.z += inc_z
	position.y += inc_y
	position.x -= GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	sprite_scale = maxf(sprite_scale - 0.1, 0.05)
	scale = Vector3.ONE * sprite_scale
	rotation.x += inc_rx * 0.01
	rotation.z += inc_rz * 0.01
	return on_time <= duration
