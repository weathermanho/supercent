extends Node3D
## A scrolling box. Two flavors:
##   - type 0: solid colored building/wall.
##   - type 1: semi-transparent wall (the original called this a "wall").
## The big "structure" boxes (small white blocks scattered in the background)
## reuse this same script via `init()` with a SOLID type.

const TYPE_SOLID := 0
const TYPE_TRANSPARENT_WALL := 1

var w: float
var h: float
var d: float
var color: Color
var type: int = TYPE_SOLID

## 8 AABB corner positions (b0..b7), recomputed each tick.
var corners: Array[Vector3] = []
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	corners.resize(8)


func init_geometry(w_: float, h_: float, d_: float, color_: Color, type_: int) -> void:
	w = w_; h = h_; d = d_; color = color_; type = type_
	if _mesh_instance != null:
		_mesh_instance.queue_free()
	if type == TYPE_TRANSPARENT_WALL:
		_mesh_instance = BoxFactory.make_transparent_box(w, h, d, color, 0.7)
	else:
		_mesh_instance = BoxFactory.make_box(w, h, d, color)
	add_child(_mesh_instance)


func step(dt_ms: float) -> void:
	position.x -= GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	_update_corners()


func _update_corners() -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var hd := d * 0.5
	corners[0] = position + Vector3(hw, -hh, hd)
	corners[1] = position + Vector3(hw, -hh, -hd)
	corners[2] = position + Vector3(hw, hh, -hd)
	corners[3] = position + Vector3(hw, hh, hd)
	corners[4] = position + Vector3(-hw, -hh, hd)
	corners[5] = position + Vector3(-hw, -hh, -hd)
	corners[6] = position + Vector3(-hw, hh, -hd)
	corners[7] = position + Vector3(-hw, hh, hd)
