extends Node
## Attach as child of a Camera3D. Call `shake(intensity, duration)` to add
## random translation + small rotational kicks to the camera each frame for
## `duration` seconds. The base transform is read once on entry and restored
## on exit, so this does not interfere with whatever positions the camera.

@export var trauma_decay: float = 4.0  # how fast intensity decays per second
@export var rot_kick: float = 0.0015   # radians per unit of trauma

var _camera: Camera3D
var _base_position: Vector3
var _base_rotation: Vector3
var _trauma: float = 0.0
var _time_left: float = 0.0


func _ready() -> void:
	_camera = get_parent() as Camera3D
	assert(_camera != null, "CameraShaker must be a child of Camera3D")
	_base_position = _camera.position
	_base_rotation = _camera.rotation


## Re-capture the rest position. Call after repositioning the camera (the base
## is first read in _ready, which runs before a parent overrides the transform).
func refresh_base() -> void:
	_base_position = _camera.position
	_base_rotation = _camera.rotation


## Public API. Call repeatedly — uses max of (current, new) so it doesn't stack.
func shake(intensity: float, duration: float) -> void:
	_trauma = maxf(_trauma, intensity)
	_time_left = maxf(_time_left, duration)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		if _camera.position != _base_position:
			_camera.position = _base_position
		if _camera.rotation != _base_rotation:
			_camera.rotation = _base_rotation
		return

	_time_left -= delta
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var t: float = _trauma
	_camera.position = _base_position + Vector3(
		(randf() * 2.0 - 1.0) * t,
		(randf() * 2.0 - 1.0) * t,
		(randf() * 2.0 - 1.0) * t,
	)
	_camera.rotation = _base_rotation + Vector3(
		(randf() * 2.0 - 1.0) * t * rot_kick,
		(randf() * 2.0 - 1.0) * t * rot_kick,
		(randf() * 2.0 - 1.0) * t * rot_kick,
	)
