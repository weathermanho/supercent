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
	_line_mat = _make_unshaded(Color(1.0, 1.0, 1.0, 0.35))
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_white_mat = _make_unshaded(Color(1.0, 1.0, 1.0, 0.9))
	_white_mat.no_depth_test = true
	_red_mat = _make_unshaded(Color(1.0, 0.15, 0.15, 1.0))
	_red_mat.no_depth_test = true  # reticle always visible, even through geometry

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


## `candidate` is the target the player is pointing at (nearest ahead), or null.
## `locked` is true when it's aligned enough that a fired missile will home onto
## it. We draw a faint forward aim-line plus a camera-facing bracket reticle on
## the candidate — WHITE while merely in sight, RED + pulsing once locked — so
## the player can always see the target and tell when the shot will connect.
## Works for giants too (they have no wall and were previously un-marked).
func update_overlay(plane_pos: Vector3, candidate: Node3D, locked: bool) -> void:
	_line_mesh.clear_surfaces()
	_circle_mesh.clear_surfaces()

	# Faint forward aim line — shows where "straight ahead" points.
	var ray_end: Vector3 = plane_pos + Vector3(FORWARD_LENGTH, 0.0, 0.0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	_line_mesh.surface_add_vertex(plane_pos)
	_line_mesh.surface_add_vertex(ray_end)
	_line_mesh.surface_end()

	if candidate == null or not is_instance_valid(candidate):
		return
	_draw_reticle(candidate, locked)


## Camera-facing square bracket (4 corner L's) centred on the target. White when
## merely in sight; red and pulsing once locked.
func _draw_reticle(target: Node3D, locked: bool) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var is_giant: bool = ("is_giant" in target and target.is_giant)
	var base: float = 95.0 if is_giant else 28.0
	var pulse: float = (1.0 + 0.14 * sin(_time * TAU * 3.0)) if locked else 1.0
	var half: float = base * pulse
	var arm: float = half * 0.4
	var right: Vector3 = cam.global_transform.basis.x
	var up: Vector3 = cam.global_transform.basis.y
	var c: Vector3 = target.position
	if is_giant:
		c += Vector3(0.0, 30.0, 0.0)  # bias up toward the rider silhouette

	# Thickness scaled by distance so the bracket stays a roughly constant,
	# clearly-visible width on screen (1px lines were invisible).
	var dist: float = cam.global_position.distance_to(c)
	var thick: float = clampf(dist * 0.006, 2.5, 16.0)

	var mat: StandardMaterial3D = _red_mat if locked else _white_mat
	_circle_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner: Vector3 = c + right * (half * sx) + up * (half * sy)
			# Horizontal arm (toward centre) + vertical arm (toward centre).
			_add_bar(corner, corner - right * (arm * sx), up, thick)
			_add_bar(corner, corner - up * (arm * sy), right, thick)
	_circle_mesh.surface_end()


## Adds a flat rectangle (two triangles) from `a` to `b`, `2*half_w` wide along
## `perp` — a thick, camera-facing line segment.
func _add_bar(a: Vector3, b: Vector3, perp: Vector3, half_w: float) -> void:
	var p: Vector3 = perp.normalized() * half_w
	var v0: Vector3 = a - p
	var v1: Vector3 = a + p
	var v2: Vector3 = b + p
	var v3: Vector3 = b - p
	_circle_mesh.surface_add_vertex(v0)
	_circle_mesh.surface_add_vertex(v1)
	_circle_mesh.surface_add_vertex(v2)
	_circle_mesh.surface_add_vertex(v0)
	_circle_mesh.surface_add_vertex(v2)
	_circle_mesh.surface_add_vertex(v3)


func _make_unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # quads visible from either side
	return m
