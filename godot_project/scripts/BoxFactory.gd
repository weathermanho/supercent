extends Node
## Autoload. Builds `MeshInstance3D`s for the boxy art style used by the original.
## The C++ code defined three "box" helpers — BoxGeometry, tBoxGeometry (transparent),
## and cBoxGeometry (a tapered "cockpit" box). We replicate that here.

const _MAT_CACHE_KEY_OPAQUE := "_opaque_"
const _MAT_CACHE_KEY_TRANSPARENT := "_transparent_"

var _material_cache: Dictionary = {}


func make_box(width: float, height: float, depth: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	mi.mesh = mesh
	mi.set_surface_override_material(0, _get_material(color, false))
	return mi


func make_transparent_box(width: float, height: float, depth: float, color: Color, alpha: float) -> MeshInstance3D:
	var c := Color(color.r, color.g, color.b, alpha)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, depth)
	mi.mesh = mesh
	mi.set_surface_override_material(0, _get_material(c, true))
	return mi


## Tapered "cockpit" box. Mirrors `Tester::cBoxGeometry`: the back face
## (x = -w/2) is pinched smaller than the front. Built as an ArrayMesh.
func make_tapered_box(width: float, height: float, depth: float, color: Color) -> MeshInstance3D:
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5

	# Front face corners (full size).
	var b0 := Vector3(hw, hh, -hd)
	var b1 := Vector3(hw, hh, hd)
	var b2 := Vector3(hw, -hh, hd)
	var b3 := Vector3(hw, -hh, -hd)

	# Rear face corners (offset/pinched per cBoxGeometry).
	var b4 := Vector3(-hw, hh - 10.0, -hd + 20.0)
	var b5 := Vector3(-hw, hh - 10.0, hd - 20.0)
	var b6 := Vector3(-hw, -hh + 30.0, hd - 20.0)
	var b7 := Vector3(-hw, -hh + 30.0, -hd + 20.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Helper closure: add a quad with computed normal.
	var add_quad := func(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
		var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		st.set_normal(normal); st.add_vertex(p0)
		st.set_normal(normal); st.add_vertex(p1)
		st.set_normal(normal); st.add_vertex(p2)
		st.set_normal(normal); st.add_vertex(p0)
		st.set_normal(normal); st.add_vertex(p2)
		st.set_normal(normal); st.add_vertex(p3)

	add_quad.call(b1, b5, b6, b2)  # front-top
	add_quad.call(b0, b3, b7, b4)  # back-top
	add_quad.call(b0, b1, b2, b3)  # +X side
	add_quad.call(b4, b7, b6, b5)  # -X side
	add_quad.call(b0, b4, b5, b1)  # top
	add_quad.call(b2, b6, b7, b3)  # bottom

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.set_surface_override_material(0, _get_material(color, false))
	return mi


func _get_material(color: Color, transparent: bool) -> StandardMaterial3D:
	var key := "%s_%d_%d_%d_%d" % [
		"t" if transparent else "o",
		int(color.r * 255), int(color.g * 255), int(color.b * 255), int(color.a * 255)
	]
	if _material_cache.has(key):
		return _material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.0
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_cache[key] = mat
	return mat
