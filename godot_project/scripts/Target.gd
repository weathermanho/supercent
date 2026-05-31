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
	# A single colossal slab — monolithic, intense, no composite parts. Reads
	# as a giant concrete bunker. A glowing red band wraps the upper-middle as
	# the lock-on / weak-point accent.
	const W := 280.0
	const H := 480.0
	const D := 280.0

	var body_mi: MeshInstance3D = BoxFactory.make_box(W, H, D, GameColors.BROWN_DARK)
	add_child(body_mi)
	_parts.append(body_mi)
	var body_mat := _wrap_first_material(body_mi, GameColors.BROWN_DARK)
	if body_mat: _mats.append(body_mat)

	# Red emissive band wrapping the upper-middle — the "shoot here" cue.
	var band_h := H * 0.18
	var band_mi: MeshInstance3D = BoxFactory.make_box(W * 1.02, band_h, D * 1.02, GameColors.RED)
	band_mi.position = Vector3(0.0, H * 0.18, 0.0)
	add_child(band_mi)
	_parts.append(band_mi)
	var band_mat := _wrap_first_material(band_mi, GameColors.RED)
	if band_mat:
		band_mat.emission_enabled = true
		band_mat.emission = GameColors.RED
		band_mat.emission_energy_multiplier = 2.8
		_mats.append(band_mat)


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
