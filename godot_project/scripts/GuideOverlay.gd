extends Node3D
## Per-frame guide visuals. Ported from `Tester::guideLines()` in tester.cpp.
##
## Behavior in this port:
##   - A long forward line is always drawn from the plane in +X.
##   - For each wall, the line is intersected with the wall's -X face.
##     If the intersection lies inside the wall bounds, a circle is drawn there.
##   - The circle stays **white and steady** while it sits on the wall.
##   - When the circle visually overlaps the target sphere on that wall, it
##     turns **red and blinks** — that's the "locked on" cue.

const CIRCLE_SEGMENTS := 24
const CIRCLE_RADIUS := 15.0
const TARGET_RADIUS := 15.0       # matches Target.gd's SphereMesh radius
const OVERLAP_TOLERANCE := 18.0   # how close hit-point must be to target center
const FORWARD_LENGTH := 12000.0
const BLINK_HZ := 4.0

var _line_mesh: ImmediateMesh
var _circle_mesh: ImmediateMesh
var _line_mat: StandardMaterial3D
var _white_mat: StandardMaterial3D
var _red_mat: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	_line_mat = _make_unshaded(Color(1.0, 1.0, 1.0, 1.0))
	_white_mat = _make_unshaded(Color(1.0, 1.0, 1.0, 1.0))
	_red_mat = _make_unshaded(Color(1.0, 0.25, 0.25, 1.0))

	_line_mesh = ImmediateMesh.new()
	var line_mi := MeshInstance3D.new()
	line_mi.mesh = _line_mesh
	line_mi.material_override = _line_mat
	add_child(line_mi)

	_circle_mesh = ImmediateMesh.new()
	var circle_mi := MeshInstance3D.new()
	circle_mi.mesh = _circle_mesh
	add_child(circle_mi)


func _process(delta: float) -> void:
	_time += delta


func update_overlay(plane_pos: Vector3, targets: Array) -> void:
	_line_mesh.clear_surfaces()
	_circle_mesh.clear_surfaces()

	# Forward line.
	var ray_end: Vector3 = plane_pos + Vector3(FORWARD_LENGTH, 0.0, 0.0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	_line_mesh.surface_add_vertex(plane_pos)
	_line_mesh.surface_add_vertex(ray_end)
	_line_mesh.surface_end()

	var blink_on: bool = sin(_time * TAU * BLINK_HZ) > 0.0

	for target in targets:
		var wall: Node3D = target.wall
		if wall == null or not is_instance_valid(wall):
			continue
		var hw: float = wall.w * 0.5
		var hh: float = wall.h * 0.5
		var hd: float = wall.d * 0.5
		var wall_x_face: float = wall.position.x - hw

		if wall_x_face <= plane_pos.x or wall_x_face > plane_pos.x + FORWARD_LENGTH:
			continue

		var hit := Vector3(wall_x_face, plane_pos.y, plane_pos.z)
		var y_min: float = wall.position.y - hh
		var y_max: float = wall.position.y + hh
		var z_min: float = wall.position.z - hd
		var z_max: float = wall.position.z + hd
		if hit.y < y_min or hit.y > y_max or hit.z < z_min or hit.z > z_max:
			continue

		# Is the hit point on the target? Compare YZ distance only — both
		# the target and the hit live on the same wall face, so X matches.
		var dy: float = hit.y - target.position.y
		var dz: float = hit.z - target.position.z
		var locked: bool = sqrt(dy * dy + dz * dz) < OVERLAP_TOLERANCE

		var mat: StandardMaterial3D
		if locked:
			if not blink_on:
				continue  # blink-off phase: skip drawing
			mat = _red_mat
		else:
			mat = _white_mat

		_circle_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for i in CIRCLE_SEGMENTS + 1:
			var a: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
			_circle_mesh.surface_add_vertex(
				hit + Vector3(0.0, sin(a) * CIRCLE_RADIUS, cos(a) * CIRCLE_RADIUS)
			)
		_circle_mesh.surface_end()


func _make_unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m
