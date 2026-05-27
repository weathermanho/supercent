extends Node3D
## A spinning energy pickup. The original draws a tetrahedron — Godot's PrismMesh
## gives a similar look.

var angle: float = 0.0
var distance: float = 0.0
var spin_y: float = 0.0
var spin_z: float = 0.0


func _ready() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(8.0, 8.0, 8.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color8(0, 153, 153)
	mat.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func update_orbit(dt_ms: float) -> void:
	angle += GameConfig.speed * dt_ms * GameConfig.coins_speed
	if angle > TAU:
		angle -= TAU
	position.y = -GameConfig.sea_radius + sin(angle) * distance
	position.x = cos(angle) * distance
	spin_z += randf() * 0.1
	spin_y += randf() * 0.1
	rotation.z = spin_z
	rotation.y = spin_y
