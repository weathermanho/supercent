extends Node3D
## Ring of cube-clusters that rotates slowly around the world. Mirrors the
## `cloud` setup from `Tester::Tester()` (the for-loop building `clouds`).
## The original commented out the draw call; here we keep it visible by
## default since it's part of the conversion.

const N_CLOUDS := 20

var _sky_angle: float = 0.0


func _ready() -> void:
	var step_angle := TAU / float(N_CLOUDS)
	for i in N_CLOUDS:
		var c := Node3D.new()
		var a := step_angle * i
		var h := GameConfig.sea_radius * 0.5 + randf() * 10.0
		c.position = Vector3(cos(a) * h, sin(a) * h, -100.0 - randf() * 100.0)
		c.rotation.z = a + PI * 0.5
		var s := 1.0 + randf() * 2.0
		c.scale = Vector3(s, s, s)

		var n_blocs := 3 + int(randf() * 1.0)
		for j in n_blocs:
			var b := BoxFactory.make_box(5, 5, 5, GameColors.PURE_WHITE)
			b.position = Vector3(j * 5.0, randf() * 10.0, randf() * 10.0)
			b.rotation = Vector3(0.0, randf() * TAU, randf() * TAU)
			var bs := 1.0 + randf() * 0.9
			b.scale = Vector3(bs, bs, bs)
			c.add_child(b)

		add_child(c)
	position.y = -100.0


func _process(delta: float) -> void:
	# Rotate the whole sky slowly. The C++ code accumulated skyAngle from
	# game.speed * deltaTime in radians; we approximate.
	_sky_angle += GameConfig.speed * delta * 1000.0
	rotation.z = _sky_angle
