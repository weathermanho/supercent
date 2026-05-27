extends Node3D
## Animated wave terrain. Ported from the `Terrain` class in tester.h.
## The C++ project allocated a 2D heightmap and walked it each frame; we do
## the same here and rebuild an `ArrayMesh` so the surface ripples.
##
## The original draw loop is commented out in `Tester::Draw()`, but we wire
## it up here so the conversion includes a usable ocean.

@export var grid_w: int = 20
@export var grid_l: int = 10
@export var grid_scale: float = 80.0

class _Wave:
	var ang: float
	var amp: float
	var speed: float

var _heights: Array = []
var _waves: Array = []
var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_init_waves()
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(GameColors.BLUE.r, GameColors.BLUE.g, GameColors.BLUE.b, 0.5)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.roughness = 0.6
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	position = Vector3(-grid_w * grid_scale * 0.5, -100.0, -grid_l * grid_scale * 0.5)
	scale = Vector3(grid_scale, grid_scale, grid_scale)
	_rebuild_mesh()


func _init_waves() -> void:
	_heights.clear()
	for z in grid_l:
		var row: Array[float] = []
		for x in grid_w:
			row.append(randf() * 2.0)
			var w := _Wave.new()
			w.ang = randf() * TAU
			w.amp = GameConfig.waves_min_amp + randf() * (GameConfig.waves_max_amp - GameConfig.waves_min_amp)
			w.speed = GameConfig.waves_min_speed + randf() * (GameConfig.waves_max_speed - GameConfig.waves_min_speed)
			_waves.append(w)
		_heights.append(row)


func step(dt_ms: float) -> void:
	var i := 0
	for z in grid_l:
		for x in grid_w:
			var w: _Wave = _waves[i]
			var h := cos(w.ang) * w.amp * 0.03
			w.ang += w.speed * dt_ms
			_heights[z][x] = h
			i += 1
	_rebuild_mesh()


func _rebuild_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in grid_l - 1:
		for x in grid_w - 1:
			var p00 := Vector3(x, _heights[z][x], z)
			var p10 := Vector3(x + 1, _heights[z][x + 1], z)
			var p01 := Vector3(x, _heights[z + 1][x], z + 1)
			var p11 := Vector3(x + 1, _heights[z + 1][x + 1], z + 1)
			var n: Vector3 = (p10 - p00).cross(p01 - p00).normalized()
			st.set_normal(n); st.add_vertex(p00)
			st.set_normal(n); st.add_vertex(p01)
			st.set_normal(n); st.add_vertex(p10)
			st.set_normal(n); st.add_vertex(p10)
			st.set_normal(n); st.add_vertex(p01)
			st.set_normal(n); st.add_vertex(p11)
	_mesh_instance.mesh = st.commit()
	_mesh_instance.set_surface_override_material(0, _material)
