extends Node3D
## Player airplane. Mirrors `Tester::AirPlane()` and `Tester::updatePlane()`.
## The plane is rebuilt from cubes at `_ready` and steered by mouse position.

const PilotScript := preload("res://scripts/Pilot.gd")

@export var width: float = 60.0
@export var height: float = 40.0
@export var depth: float = 60.0

var _propeller: Node3D
var _p_angle: float = 0.0

## Mouse position normalized to [-1, 1] (used for speed control).
var _mouse_pos: Vector2 = Vector2.ZERO

## World-space point under the cursor on the plane's X-plane, supplied by
## `Main.gd` via camera projection. When set, the airplane steers directly
## toward this point — so the cursor and the plane stay visually aligned.
var _world_target: Vector3 = Vector3.ZERO
var _world_target_set: bool = false

## Axis-aligned corners updated each frame for collision queries elsewhere.
var corners: Array[Vector3] = []

## Smoothed instantaneous velocity in world space (units/sec).
## Used by missile launch to add inheritance — feels like the plane "throws" the missile.
var estimated_velocity: Vector3 = Vector3.ZERO
var _prev_position: Vector3 = Vector3.ZERO
const VEL_SMOOTHING := 0.3  # 0=instant, 1=never updates


func _ready() -> void:
	corners.resize(8)

	# Cockpit (tapered box)
	add_child(BoxFactory.make_tapered_box(80, 50, 50, GameColors.RED))

	# Engine
	var engine := BoxFactory.make_box(20, 50, 50, GameColors.WHITE)
	engine.position = Vector3(50.0, 0.0, 0.0)
	add_child(engine)

	# Tail
	var tail := BoxFactory.make_box(15, 20, 5, GameColors.WHITE)
	tail.position = Vector3(-40.0, 20.0, 0.0)
	add_child(tail)

	# Wings
	var wings := BoxFactory.make_box(30, 5, 120, GameColors.WHITE)
	wings.position = Vector3(0.0, 15.0, 0.0)
	add_child(wings)

	# Wind shield (transparent)
	var shield := BoxFactory.make_transparent_box(3, 15, 20, GameColors.BLUE, 0.7)
	shield.position = Vector3(5.0, 27.0, 0.0)
	add_child(shield)

	# Propeller (rotates around X)
	_propeller = Node3D.new()
	_propeller.position = Vector3(60.0, 0.0, 0.0)
	add_child(_propeller)

	_propeller.add_child(BoxFactory.make_box(20, 10, 10, GameColors.BROWN))

	var blade1 := BoxFactory.make_box(1, 80, 10, GameColors.BROWN_DARK)
	blade1.position = Vector3(8.0, 0.0, 0.0)
	_propeller.add_child(blade1)

	var blade2 := BoxFactory.make_box(1, 80, 10, GameColors.BROWN_DARK)
	blade2.position = Vector3(8.0, 0.0, 0.0)
	blade2.rotation.x = PI / 2.0
	_propeller.add_child(blade2)

	# Pilot
	var pilot_holder := Node3D.new()
	pilot_holder.position = Vector3(-10, 27, 0)
	var pilot := PilotScript.new()
	pilot_holder.add_child(pilot)
	add_child(pilot_holder)

	# Wheels
	var wheel_protec_r := BoxFactory.make_box(30, 15, 10, GameColors.RED)
	wheel_protec_r.position = Vector3(25.0, -20.0, 25.0)
	add_child(wheel_protec_r)

	var wheel_tire_r := BoxFactory.make_box(24, 24, 4, GameColors.BROWN_DARK)
	wheel_tire_r.position = Vector3(25.0, -28.0, 25.0)
	add_child(wheel_tire_r)
	var wheel_axis_r := BoxFactory.make_box(10, 10, 6, GameColors.BROWN)
	wheel_axis_r.position = Vector3(25.0, -28.0, 25.0)
	add_child(wheel_axis_r)

	var wheel_tire_l := BoxFactory.make_box(24, 24, 4, GameColors.BROWN_DARK)
	wheel_tire_l.position = Vector3(25.0, -28.0, -25.0)
	add_child(wheel_tire_l)
	var wheel_axis_l := BoxFactory.make_box(10, 10, 6, GameColors.BROWN)
	wheel_axis_l.position = Vector3(25.0, -28.0, -25.0)
	add_child(wheel_axis_l)

	var wheel_tire_b := BoxFactory.make_box(24, 24, 4, GameColors.BROWN_DARK)
	wheel_tire_b.position = Vector3(-35.0, -5.0, 0.0)
	wheel_tire_b.scale = Vector3(0.5, 0.5, 0.5)
	add_child(wheel_tire_b)

	var wheel_protec_l := BoxFactory.make_box(30, 15, 10, GameColors.RED)
	wheel_protec_l.position = Vector3(25.0, -20.0, -25.0)
	add_child(wheel_protec_l)

	var suspension := BoxFactory.make_box(4, 20, 4, GameColors.RED)
	suspension.position = Vector3(-32.5, 5.0, 0.0)
	suspension.rotation.z = -deg_to_rad(0.3)
	add_child(suspension)

	_prev_position = global_position


func set_mouse_pos(p: Vector2) -> void:
	_mouse_pos = p


func set_world_target(pos: Vector3) -> void:
	_world_target = pos
	_world_target_set = true


func _process(delta: float) -> void:
	# Spin the propeller. The original does `pAngle += DEG(0.3)` per frame,
	# where DEG converts radians→degrees: 0.3 rad ≈ 17.19° per frame at 60fps,
	# i.e. ~1032°/sec ≈ 18 rad/sec. We make it frame-rate independent here.
	const PROP_SPEED_RAD_PER_SEC := 18.0
	_p_angle += PROP_SPEED_RAD_PER_SEC * delta
	_propeller.rotation.x = _p_angle

	# Delta in milliseconds (the original used `timeGetTime()`), scaled by global time_scale.
	var dt_ms: float = delta * 1000.0 * GameConfig.time_scale

	if GameConfig.status == GameConfig.STATUS_PLAYING:
		_update_playing(dt_ms)
	elif GameConfig.status == GameConfig.STATUS_GAME_OVER:
		_update_falling(dt_ms)
	# else (STATUS_TITLE): idle, propeller still spins via the unconditional
	# block above; the plane just hovers in place.

	var dt_s: float = max(delta, 0.0001)
	var instant: Vector3 = (global_position - _prev_position) / dt_s
	estimated_velocity = estimated_velocity.lerp(instant, 1.0 - VEL_SMOOTHING)
	_prev_position = global_position

	_update_corners()


func _update_playing(dt_ms: float) -> void:
	GameConfig.plane_speed = GameConfig.remap_clamped(
		_mouse_pos.x, -0.5, 0.5,
		GameConfig.plane_min_speed, GameConfig.plane_max_speed
	)

	# Prefer the world cursor (camera-projected) for position so the cursor
	# stays visually pinned to the airplane. Fall back to the legacy mouse
	# remap if Main hasn't supplied it yet (first frame).
	var target_y: float
	var target_z: float
	if _world_target_set:
		target_y = clampf(_world_target.y,
			GameConfig.plane_default_height - GameConfig.plane_amp_height,
			GameConfig.plane_default_height + GameConfig.plane_amp_height)
		target_z = clampf(_world_target.z, -200.0, 200.0)
	else:
		target_y = GameConfig.remap_clamped(
			_mouse_pos.y, -1.0, 1.0,
			GameConfig.plane_default_height - GameConfig.plane_amp_height,
			GameConfig.plane_default_height + GameConfig.plane_amp_height)
		target_z = GameConfig.remap_clamped(_mouse_pos.x, -1.0, 1.0, -200.0, 200.0)

	GameConfig.plane_collision_displacement_x += GameConfig.plane_collision_speed_x
	target_z += GameConfig.plane_collision_displacement_x
	GameConfig.plane_collision_displacement_y += GameConfig.plane_collision_speed_y
	target_y += GameConfig.plane_collision_displacement_y

	# Original-style smooth lag tracking. Slow lerp creates the aerodynamic
	# "drifting" feel and produces visible tilt from the residual gap.
	position.y += (target_y - position.y) * dt_ms * GameConfig.plane_move_sensitivity
	position.z += (target_z - position.z) * dt_ms * GameConfig.plane_move_sensitivity

	rotation.z = (target_y - position.y) * 0.0128
	rotation.x = (target_z - position.z) * 0.0128

	GameConfig.plane_collision_speed_x += (0.0 - GameConfig.plane_collision_speed_x) * dt_ms * 0.03
	GameConfig.plane_collision_displacement_x += (0.0 - GameConfig.plane_collision_displacement_x) * dt_ms * 0.01
	GameConfig.plane_collision_speed_y += (0.0 - GameConfig.plane_collision_speed_y) * dt_ms * 0.03
	GameConfig.plane_collision_displacement_y += (0.0 - GameConfig.plane_collision_displacement_y) * dt_ms * 0.01


func _update_falling(dt_ms: float) -> void:
	GameConfig.speed *= 0.99
	rotation.z += (PI / 2.0 - rotation.z) * 0.0002 * dt_ms
	rotation.x += 0.0003 * dt_ms
	GameConfig.plane_fall_speed *= 1.05
	position.y -= GameConfig.plane_fall_speed * dt_ms


## Refresh the 8 corner positions of the AABB (used by buildings/missles for hit tests).
func _update_corners() -> void:
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var origin := global_position + Vector3(-20.0, 0.0, 0.0)  # original offsets center by ~ -20 on X
	corners[0] = origin + Vector3(hw, -hh, hd)
	corners[1] = origin + Vector3(hw, -hh, -hd)
	corners[2] = origin + Vector3(hw, hh, -hd)
	corners[3] = origin + Vector3(hw, hh, hd)
	corners[4] = origin + Vector3(-hw, -hh, hd)
	corners[5] = origin + Vector3(-hw, -hh, -hd)
	corners[6] = origin + Vector3(-hw, hh, -hd)
	corners[7] = origin + Vector3(-hw, hh, hd)
