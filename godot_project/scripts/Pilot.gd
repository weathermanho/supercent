extends Node3D
## Pilot model built from boxes. Mirrors `Tester::pilot()` in tester.cpp.

var _hair_blocks: Array[MeshInstance3D] = []
var _angle_hairs: float = 0.0


func _ready() -> void:
	# Body
	var body := BoxFactory.make_box(15, 15, 15, GameColors.BROWN)
	body.position = Vector3(2.0, -12.0, 0.0)
	add_child(body)

	# Face
	add_child(BoxFactory.make_box(10, 10, 10, GameColors.PINK))

	# Hair grid (12 small cubes, animated). The original used a 4x3 grid offset.
	var hair_root := Node3D.new()
	hair_root.position = Vector3(-5, 5, 0)
	add_child(hair_root)
	for i in 12:
		var col := i % 3
		var row := i / 3
		var px := -4 + row * 4.0
		var pz := -4 + col * 4.0
		var hair := BoxFactory.make_box(4, 4, 4, GameColors.BROWN_DARK)
		hair.position = Vector3(px, 2, pz)
		hair_root.add_child(hair)
		_hair_blocks.append(hair)

	# Hair sides + back
	var hair_side_r := BoxFactory.make_box(12, 4, 2, GameColors.BROWN)
	hair_side_r.position = Vector3(2.0, -2.0, 6.0)
	hair_root.add_child(hair_side_r)

	var hair_side_l := BoxFactory.make_box(12, 4, 2, GameColors.BROWN)
	hair_side_l.position = Vector3(2.0, -2.0, -6.0)
	hair_root.add_child(hair_side_l)

	var hair_back := BoxFactory.make_box(2, 8, 10, GameColors.BROWN)
	hair_back.position = Vector3(-6.0, -4.0, 0.0)
	hair_root.add_child(hair_back)

	# Glasses
	var glass_r := BoxFactory.make_box(5, 5, 5, GameColors.BROWN)
	glass_r.position = Vector3(6.0, 0.0, 3.0)
	add_child(glass_r)
	var glass_l := BoxFactory.make_box(5, 5, 5, GameColors.BROWN)
	glass_l.position = Vector3(6.0, 0.0, -3.0)
	add_child(glass_l)
	add_child(BoxFactory.make_box(11, 1, 11, GameColors.BROWN))  # frame

	# Ears
	var ear_l := BoxFactory.make_box(2, 3, 2, GameColors.PINK)
	ear_l.position = Vector3(0.0, 0.0, -6.0)
	add_child(ear_l)
	var ear_r := BoxFactory.make_box(2, 3, 2, GameColors.PINK)
	ear_r.position = Vector3(0.0, 0.0, 6.0)
	add_child(ear_r)


func _process(_delta: float) -> void:
	_angle_hairs += GameConfig.speed * 1000.0 * 40.0 * 0.001
	for i in _hair_blocks.size():
		var hs := 0.95 + cos(_angle_hairs + i / 3.0) * 0.25
		_hair_blocks[i].scale = Vector3(1.0, hs, 1.0)
