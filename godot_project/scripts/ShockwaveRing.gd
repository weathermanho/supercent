extends Node3D
## One-shot expanding ring. Spawned at hit position, scales 1 → end_scale over
## `duration`, fades alpha 0.6 → 0, then queue_free. Built from a thin TorusMesh
## so it works without external assets.

@export var end_scale: float = 8.0
@export var duration: float = 0.4

var _t: float = 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 10.0
	torus.rings = 24
	torus.ring_segments = 6
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.6)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh = MeshInstance3D.new()
	_mesh.mesh = torus
	_mesh.set_surface_override_material(0, _mat)
	# Lay flat so it expands as a ring on the XZ plane (vertical Y is the axis).
	_mesh.rotation.x = PI / 2.0
	add_child(_mesh)
	scale = Vector3.ONE


func step(dt_ms: float) -> bool:
	_t += dt_ms / 1000.0
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var s: float = lerpf(1.0, end_scale, p)
	scale = Vector3(s, s, s)
	_mat.albedo_color.a = lerpf(0.6, 0.0, p)
	return _t < duration
