extends Node3D
## Lock-on target. Normal targets: hp=1, small red icosahedron.
## Giant targets: hp=3, large brown silhouette, marks the cinematic "boss" beat.

var wall: Node3D = null
var hp: int = 1
var is_giant: bool = false

var _mesh_instance: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	if is_giant:
		hp = 3
	var mesh := SphereMesh.new()
	if is_giant:
		mesh.radius = 120.0
		mesh.height = 240.0
		mesh.radial_segments = 12
		mesh.rings = 8
	else:
		mesh.radius = 15.0
		mesh.height = 30.0
		mesh.radial_segments = 6
		mesh.rings = 4

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = GameColors.BROWN if is_giant else GameColors.RED
	_mat.roughness = 0.9
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # so fade works
	_mat.albedo_color.a = 1.0
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.set_surface_override_material(0, _mat)
	add_child(_mesh_instance)


## Returns true if this hit killed the target.
func take_damage(amt: int) -> bool:
	hp -= amt
	return hp <= 0


## Called by the giant-finish branch — kicks off a 0.6s alpha fade then frees.
func start_fade(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(queue_free)
