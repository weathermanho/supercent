extends Node3D
## A missile lock-on target. The original drew this as a red icosahedron
## just in front of a wall (`Tester::constructBuilding()`'s Target struct).
## Holds a back-reference to the wall it was spawned on so the GuideOverlay
## can compute ray-plane intersection (the original `guideLines()` did this
## per-building).

var wall: Node3D = null


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 15.0
	mesh.height = 30.0
	mesh.radial_segments = 6
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameColors.RED
	mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	add_child(mi)
