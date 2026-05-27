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
	_orient_to_velocity()


func step(dt_ms: float) -> void:
	prev_position = position
	var delta: float = dt_ms / 1000.0
	time_alive += delta

	if time_alive < GameConfig.missile_drop_duration:
		# Drop phase — strong gravity, no homing yet.
		velocity.y -= GameConfig.missile_drop_gravity * delta
	else:
		# Boost + (weak) homing + mild gravity.
		var desired_dir: Vector3
		if target != null and is_instance_valid(target):
			desired_dir = (target.position - position).normalized()
		else:
			desired_dir = velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.RIGHT
		var desired_velocity: Vector3 = desired_dir * GameConfig.missile_max_speed
		velocity = velocity.move_toward(desired_velocity, GameConfig.missile_boost_accel * delta)
		velocity.y -= GameConfig.missile_boost_gravity * delta  # keep gravity in boost

	position += velocity * delta
	_orient_to_velocity()


## Reorients the mesh so its nose (local +X) points along the velocity vector.
func _orient_to_velocity() -> void:
	if velocity.length_squared() < 0.01:
		return
	var forward: Vector3 = velocity.normalized()
	var world_up := Vector3.UP
	var side: Vector3 = world_up.cross(forward)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT.cross(forward)
	side = side.normalized()
	var up: Vector3 = forward.cross(side).normalized()
	# Basis columns are X, Y, Z axes in world space. Local +X = forward.
	transform.basis = Basis(forward, up, side).scaled(Vector3(missile_scale, missile_scale, missile_scale))
