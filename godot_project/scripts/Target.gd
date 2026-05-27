extends Node3D
## Lock-on target. Normal: hp=1, small red icosahedron.
## Giant: hp=3, composite silhouette (sphere base + tall body box + red cap)
##        evoking the armored-rider-on-orb motif of the reference image.

var wall: Node3D = null
var hp: int = 1
var is_giant: bool = false

var _parts: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	if is_giant:
		hp = 3
		_build_giant()
	else:
		_build_normal()


func _build_normal() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 15.0
	mesh.height = 30.0
	mesh.radial_segments = 6
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameColors.RED
	mat.roughness = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	add_child(mi)
	_parts.append(mi)
	_mats.append(mat)


func _build_giant() -> void:
	# Base orb — large brown sphere.
	var orb := SphereMesh.new()
	orb.radius = 110.0
	orb.height = 220.0
	orb.radial_segments = 24
	orb.rings = 16
	var orb_mat := _make_mat(GameColors.BROWN, 0.95)
	var orb_mi := MeshInstance3D.new()
	orb_mi.mesh = orb
	orb_mi.set_surface_override_material(0, orb_mat)
	add_child(orb_mi)
	_parts.append(orb_mi)
	_mats.append(orb_mat)

	# Body — taller dark column on top of the orb (the "rider" silhouette).
	var body_mi: MeshInstance3D = BoxFactory.make_box(60, 90, 50, GameColors.BROWN_DARK)
	body_mi.position = Vector3(0.0, 110.0 + 45.0, 0.0)
	add_child(body_mi)
	_parts.append(body_mi)
	var body_mat := _wrap_first_material(body_mi, GameColors.BROWN_DARK)
	if body_mat: _mats.append(body_mat)

	# Head — smaller dark cube.
	var head_mi: MeshInstance3D = BoxFactory.make_box(35, 35, 30, GameColors.BROWN_DARK)
	head_mi.position = Vector3(0.0, 110.0 + 90.0 + 18.0, 0.0)
	add_child(head_mi)
	_parts.append(head_mi)
	var head_mat := _wrap_first_material(head_mi, GameColors.BROWN_DARK)
	if head_mat: _mats.append(head_mat)

	# Red cap — small silhouette accent on top (the "pennant" / lock indicator).
	var cap_mi: MeshInstance3D = BoxFactory.make_box(8, 50, 6, GameColors.RED)
	cap_mi.position = Vector3(0.0, 110.0 + 90.0 + 36.0 + 25.0, 0.0)
	add_child(cap_mi)
	_parts.append(cap_mi)
	var cap_mat := _wrap_first_material(cap_mi, GameColors.RED)
	if cap_mat: _mats.append(cap_mat)


func _make_mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## BoxFactory.make_box doesn't expose its material; wrap a fresh one so we can
## fade it. Returns the new material on success, null if we can't override.
func _wrap_first_material(mi: MeshInstance3D, c: Color) -> StandardMaterial3D:
	var m := _make_mat(c, 0.95)
	mi.set_surface_override_material(0, m)
	return m


## Returns true if this hit killed the target.
func take_damage(amt: int) -> bool:
	hp -= amt
	return hp <= 0


## Called by the giant-finish branch — kicks off a `duration` alpha fade
## across all materials, then queue_free.
func start_fade(duration: float) -> void:
	for m in _mats:
		var tw := create_tween()
		tw.tween_property(m, "albedo_color:a", 0.0, duration)
	# Schedule free after the longest tween — they're all the same duration here.
	get_tree().create_timer(duration + 0.05).timeout.connect(queue_free)
