extends Node3D
## One-shot expanding ring. Spawned at hit position, scales 1 → end_scale over
## `duration`, fades alpha 0.6 → 0, then queue_free. Faces the active camera
## each frame so it reads as a frontal blast, not a flat ground ellipse.

@export var end_scale: float = 8.0
@export var duration: float = 0.4
## When true the ring grows on REAL wall-clock time, ignoring
## GameConfig.time_scale (slowmo / hitstop). Used by the ULT pulse so the
## release punch still reads sharply through the slowmo it triggers.
var real_time: bool = false
## Tube thickness override. Default torus is 1 unit thick — for the ULT pulse
## we want a much fatter, more visible ring (set before _ready).
var tube_thickness: float = 1.0

var _t: float = 0.0
var _start_msec: int = 0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 9.0 + tube_thickness
	torus.rings = 24
	torus.ring_segments = 8
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.95)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = true   # always drawn on top so pillars/plane don't hide it
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.85, 0.5)
	_mat.emission_energy_multiplier = 2.5
	_mesh = MeshInstance3D.new()
	_mesh.mesh = torus
	_mesh.set_surface_override_material(0, _mat)
	add_child(_mesh)
	scale = Vector3.ONE
	_start_msec = Time.get_ticks_msec()


func step(dt_ms: float) -> bool:
	if real_time:
		_t = (Time.get_ticks_msec() - _start_msec) / 1000.0
	else:
		_t += dt_ms / 1000.0
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var s: float = lerpf(1.0, end_scale, p)
	scale = Vector3(s, s, s)
	_mat.albedo_color.a = lerpf(0.95, 0.0, p)

	# Billboard the ring toward the camera so its disc faces the viewer.
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var to_cam: Vector3 = cam.global_position - global_position
		if to_cam.length_squared() > 0.01:
			look_at(cam.global_position, Vector3.UP)
			# TorusMesh axis is along its local +Y, so rotate to put the ring's
			# face perpendicular to the look-at vector (default look_at points
			# local -Z at the target — we need the *ring axis* there).
			rotate_object_local(Vector3.RIGHT, PI / 2.0)
	return _t < duration
