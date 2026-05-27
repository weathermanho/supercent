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

const SCALE := 0.4

const DROP_DURATION := 0.3            # seconds before the booster ignites
const INITIAL_FORWARD_SPEED := 120.0  # +X velocity at launch
const INITIAL_DROP_SPEED := 60.0      # downward velocity at launch
const GRAVITY := 500.0                # during drop phase only
const BOOST_ACCEL := 4500.0           # how aggressively velocity bends to target
const MAX_SPEED := 2200.0             # capped flight speed after booster

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

	velocity = Vector3(INITIAL_FORWARD_SPEED, -INITIAL_DROP_SPEED, 0.0)
	prev_position = position
	_orient_to_velocity()


func step(dt_ms: float) -> void:
	prev_position = position
	var delta: float = dt_ms / 1000.0
	time_alive += delta

	if time_alive < DROP_DURATION:
		# Drop phase — gravity only, no homing yet.
		velocity.y -= GRAVITY * delta
	else:
		# Booster + homing.
		var desired_dir: Vector3
		if target != null and is_instance_valid(target):
			desired_dir = (target.position - position).normalized()
		else:
			desired_dir = Vector3.RIGHT  # fallback: keep flying forward
		var desired_velocity: Vector3 = desired_dir * MAX_SPEED
		velocity = velocity.move_toward(desired_velocity, BOOST_ACCEL * delta)

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
	transform.basis = Basis(forward, up, side).scaled(Vector3(SCALE, SCALE, SCALE))
