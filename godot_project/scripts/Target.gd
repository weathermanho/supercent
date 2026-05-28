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
	# Sized so the composite reads as a distinct boss silhouette against the
	# teal sky rather than engulfing the camera. Colored near-black so it reads
	# as a dark silhouette (the reference's giant is a dark shape against a
	# bright cool sky), with a red emissive accent that pops as the "lock here".
	const R := 70.0

	# Base orb.
	var orb := SphereMesh.new()
	orb.radius = R
	orb.height = R * 2.0
	orb.radial_segments = 32
	orb.rings = 20
	var orb_mat := _make_mat(GameColors.BROWN_DARK, 0.85)
	var orb_mi := MeshInstance3D.new()
	orb_mi.mesh = orb
	orb_mi.set_surface_override_material(0, orb_mat)
	add_child(orb_mi)
	_parts.append(orb_mi)
	_mats.append(orb_mat)

	# Body — column on top of the orb (the "rider" silhouette).
	var body_mi: MeshInstance3D = BoxFactory.make_box(40, 60, 34, GameColors.BROWN_DARK)
	body_mi.position = Vector3(0.0, R + 30.0, 0.0)
	add_child(body_mi)
	_parts.append(body_mi)
	var body_mat := _wrap_first_material(body_mi, GameColors.BROWN_DARK)
	if body_mat: _mats.append(body_mat)

	# Head.
	var head_mi: MeshInstance3D = BoxFactory.make_box(24, 24, 20, GameColors.BROWN_DARK)
	head_mi.position = Vector3(0.0, R + 60.0 + 12.0, 0.0)
	add_child(head_mi)
	_parts.append(head_mi)
	var head_mat := _wrap_first_material(head_mi, GameColors.BROWN_DARK)
	if head_mat: _mats.append(head_mat)

	# Red cap — emissive accent / lock indicator.
	var cap_mi: MeshInstance3D = BoxFactory.make_box(6, 34, 5, GameColors.RED)
	cap_mi.position = Vector3(0.0, R + 60.0 + 24.0 + 17.0, 0.0)
	add_child(cap_mi)
	_parts.append(cap_mi)
	var cap_mat := _wrap_first_material(cap_mi, GameColors.RED)
	if cap_mat:
		cap_mat.emission_enabled = true
		cap_mat.emission = GameColors.RED
		cap_mat.emission_energy_multiplier = 2.5
		_mats.append(cap_mat)


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
