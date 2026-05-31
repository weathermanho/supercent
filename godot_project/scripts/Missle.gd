extends Node3D
## Guided missile.
##
## Two-phase flight for the "간지" launch:
##   1. **Drop phase** (≈ 0.3 sec): the missile is "ejected" — gentle forward
##      push plus a downward velocity and gravity, so it visibly falls away
##      from the airplane before the booster lights.
##   2. **Homing phase**: booster ignites, the missile rapidly accelerates
##      toward its locked target and bends its path to intercept. The mesh
##      is reoriented every frame so the nose always faces the velocity
##      vector — this is what reads as "guided / heat-seeking".

## Per-instance scale; set by Main before adding child. Default = stage 1.
var missile_scale: float = 0.4

var velocity: Vector3 = Vector3.ZERO
var target: Node3D = null
var time_alive: float = 0.0
var prev_position: Vector3 = Vector3.ZERO
## Set true on the first frame the booster fires so we snap the velocity
## direction from "still falling" to "going forward" once and only once.
var _boost_started: bool = false

## Combo tier this missile was fired at (drives giant skill-check + explosion
## power). pierce = how many extra pillars it can punch through before dying
## (4축 ③관통).
var tier: int = 0
var pierce: int = 0

## Pillars this missile has already damaged this flight — so a pierce shot
## doesn't repeatedly re-hit the same target every frame while sitting inside
## its AABB.
var pillars_hit: Array = []


func _ready() -> void:
	# Geometry: same boxy missile as before, but built so the nose is at
	# local +X and the body extends in -X — that way `_orient_to_velocity()`
	# can use the local +X axis as the forward.
	var head := BoxFactory.make_box(20, 5, 5, GameColors.RED)
	add_child(head)
	var ring := BoxFactory.make_box(10, 10, 10, GameColors.DARK_BLUE)
	ring.position = Vector3(-15.0, 0.0, 0.0)
	add_child(ring)
	var shoulder := BoxFactory.make_box(10, 20, 20, GameColors.WHITE)
	shoulder.position = Vector3(-20.0, 0.0, 0.0)
	add_child(shoulder)
	var body := BoxFactory.make_box(50, 20, 20, GameColors.RED)
	body.position = Vector3(-50.0, 0.0, 0.0)
	add_child(body)
	var wing := BoxFactory.make_box(5, 2, 35, GameColors.WHITE)
	wing.position = Vector3(-70.0, 0.0, 0.0)
	add_child(wing)
	var wing2 := BoxFactory.make_box(5, 2, 35, GameColors.WHITE)
	wing2.position = Vector3(-70.0, 0.0, 0.0)
	wing2.rotation.x = PI / 2.0
	add_child(wing2)

	# Initial velocity is set by Main._fire_missle() *before* this scene is added,
	# via `m.velocity = ...`. Just normalize the orientation here.
	if velocity.length_squared() < 0.01:
		velocity = Vector3(GameConfig.missile_initial_forward_speed,
						   -GameConfig.missile_initial_drop_speed, 0.0)
	prev_position = position
	_orient_to_dir(Vector3.RIGHT)  # start nose-forward; it free-falls flat


func step(dt_ms: float) -> void:
	prev_position = position
	var delta: float = dt_ms / 1000.0
	time_alive += delta

	if time_alive < GameConfig.missile_drop_duration:
		# Phase 1 — free-fall straight down (gravity only). The NOSE stays facing
		# forward (+X) the whole time: the missile drops flat out of the bay, it
		# does not pitch nose-down to follow the fall.
		velocity.y -= GameConfig.missile_drop_gravity * delta
		position += velocity * delta
		_orient_to_dir(Vector3.RIGHT)
	else:
		# Phase 2 — booster. On the FIRST boost frame snap velocity to pure
		# forward so the curve that follows is *toward the target* (up / down /
		# left / right) instead of "smoothly out of the downward drop" (which
		# made the missile arc downward awkwardly). After the snap, a limited
		# turn rate produces a visible guided-weapon arc.
		if not _boost_started:
			_boost_started = true
			velocity = Vector3.RIGHT * 320.0

		var dir_target: Vector3 = Vector3.RIGHT
		if target != null and is_instance_valid(target):
			dir_target = (target.global_position - global_position).normalized()

		var current_dir: Vector3 = velocity.normalized() if velocity.length_squared() > 1.0 else Vector3.RIGHT

		const TURN_RATE := 5.0
		var blend: float = clampf(TURN_RATE * delta, 0.0, 1.0)
		var new_dir: Vector3 = current_dir.lerp(dir_target, blend).normalized()

		var spd: float = maxf(velocity.length(), 320.0)
		spd = minf(spd + 3000.0 * delta, GameConfig.missile_max_speed)
		velocity = new_dir * spd
		position += velocity * delta
		_orient_to_dir(velocity)


## Reorients the mesh so its nose (local +X) points along `dir`.
func _orient_to_dir(dir: Vector3) -> void:
	if dir.length_squared() < 0.01:
		return
	var forward: Vector3 = dir.normalized()
	var world_up := Vector3.UP
	var side: Vector3 = world_up.cross(forward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT.cross(forward)
	side = side.normalized()
	var up: Vector3 = forward.cross(side).normalized()
	# Basis columns are X, Y, Z axes in world space. Local +X = forward.
	transform.basis = Basis(forward, up, side).scaled(Vector3(missile_scale, missile_scale, missile_scale))
