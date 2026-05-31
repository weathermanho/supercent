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
	# A fortress monolith: thick concrete slab body + stepped upper block +
	# a tall red emissive antenna spire on top + a glowing vertical core strip
	# on the FRONT face (the player aims at this) + a wide red band wrapping
	# the upper third. Reads as an intimidating bunker with a beacon — not a
	# featureless slab.
	const W := 320.0
	const H := 460.0
	const D := 320.0

	# Main slab.
	var body_mi: MeshInstance3D = BoxFactory.make_box(W, H, D, GameColors.BROWN_DARK)
	add_child(body_mi)
	_parts.append(body_mi)
	var body_mat := _wrap_first_material(body_mi, GameColors.BROWN_DARK)
	if body_mat: _mats.append(body_mat)

	# Stepped upper block — narrower roof section sitting on the main slab.
	const UW := 220.0
	const UH := 120.0
	const UD := 220.0
	var upper_mi: MeshInstance3D = BoxFactory.make_box(UW, UH, UD, GameColors.BROWN_DARK)
	upper_mi.position = Vector3(0.0, H * 0.5 + UH * 0.5, 0.0)
	add_child(upper_mi)
	_parts.append(upper_mi)
	var upper_mat := _wrap_first_material(upper_mi, GameColors.BROWN_DARK)
	if upper_mat: _mats.append(upper_mat)

	# Tall red antenna spire — towers above the stepped block, beacon-bright.
	const SW := 38.0
	const SH := 180.0
	const SD := 38.0
	var spire_mi: MeshInstance3D = BoxFactory.make_box(SW, SH, SD, GameColors.RED)
	spire_mi.position = Vector3(0.0, H * 0.5 + UH + SH * 0.5, 0.0)
	add_child(spire_mi)
	_parts.append(spire_mi)
	var spire_mat := _wrap_first_material(spire_mi, GameColors.RED)
	if spire_mat:
		spire_mat.emission_enabled = true
		spire_mat.emission = GameColors.RED
		spire_mat.emission_energy_multiplier = 3.2
		_mats.append(spire_mat)

	# Vertical red core strip on the FRONT face (-X), where the player faces it.
	var strip_w_y := H * 0.55
	var strip_d_z := W * 0.22
	var strip_mi: MeshInstance3D = BoxFactory.make_box(8.0, strip_w_y, strip_d_z, GameColors.RED)
	strip_mi.position = Vector3(-W * 0.5 - 4.0, 0.0, 0.0)
	add_child(strip_mi)
	_parts.append(strip_mi)
	var strip_mat := _wrap_first_material(strip_mi, GameColors.RED)
	if strip_mat:
		strip_mat.emission_enabled = true
		strip_mat.emission = GameColors.RED
		strip_mat.emission_energy_multiplier = 3.0
		_mats.append(strip_mat)

	# Red horizontal band wrapping the upper third.
	var band_h := H * 0.12
	var band_mi: MeshInstance3D = BoxFactory.make_box(W * 1.04, band_h, D * 1.04, GameColors.RED)
	band_mi.position = Vector3(0.0, H * 0.28, 0.0)
	add_child(band_mi)
	_parts.append(band_mi)
	var band_mat := _wrap_first_material(band_mi, GameColors.RED)
	if band_mat:
		band_mat.emission_enabled = true
		band_mat.emission = GameColors.RED
		band_mat.emission_energy_multiplier = 2.6
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
