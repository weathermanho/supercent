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

	# Fuselage / cockpit (tapered box) — green body.
	add_child(BoxFactory.make_tapered_box(80, 50, 50, GameColors.PLANE_GREEN))

	# Cockpit tub that WRAPS the pilot only up to ELBOW height — head, shoulders
	# and arms stay visible above the rim (open-cockpit look). Pilot sits at
	# y≈27 (head) / y≈15 (body), so the tub rim is kept around y≈20.
	# Slimmer body (narrower z) so it doesn't look bulky.
	var rear_body := BoxFactory.make_box(48, 30, 36, GameColors.PLANE_GREEN)
	rear_body.position = Vector3(-20.0, 3.0, 0.0)   # top ≈ y18
	add_child(rear_body)
	var cockpit_wall_l := BoxFactory.make_box(42, 16, 5, GameColors.PLANE_GREEN_DARK)
	cockpit_wall_l.position = Vector3(-12.0, 12.0, 15.0)   # top ≈ y20
	add_child(cockpit_wall_l)
	var cockpit_wall_r := BoxFactory.make_box(42, 16, 5, GameColors.PLANE_GREEN_DARK)
	cockpit_wall_r.position = Vector3(-12.0, 12.0, -15.0)
	add_child(cockpit_wall_r)
	# Seat back behind the pilot.
	var cockpit_back := BoxFactory.make_box(8, 24, 30, GameColors.PLANE_GREEN_DARK)
	cockpit_back.position = Vector3(-34.0, 17.0, 0.0)
	add_child(cockpit_back)

	# Engine cowl — orange nose block (the reference's bright orange front).
	var engine := BoxFactory.make_box(22, 52, 52, GameColors.PLANE_ORANGE)
	engine.position = Vector3(50.0, 0.0, 0.0)
	add_child(engine)

	# Orange trim band where cowl meets the green body.
	var trim := BoxFactory.make_box(8, 52, 54, GameColors.PLANE_ORANGE)
	trim.position = Vector3(36.0, 0.0, 0.0)
	add_child(trim)

	# Tail — a short tapered tail cone CONTINUES from the rear of the body
	# (body rear ≈ x-44), narrowing backward; the trapezoidal vertical fin
	# rises from the END of that cone (not stabbed into the mid-body), with
	# small auxiliary horizontal wings on its left/right base.
	var tail_cone := BoxFactory.make_tapered_box(40, 22, 22, GameColors.PLANE_GREEN)
	tail_cone.position = Vector3(-60.0, 8.0, 0.0)   # spans x-80..-40, overlaps body rear
	add_child(tail_cone)

	var fin := _make_trapezoid_fin(30.0, 14.0, 32.0, 5.0, GameColors.PLANE_GREEN)
	fin.position = Vector3(-66.0, 14.0, 0.0)        # rises from the tail-cone end
	add_child(fin)
	var fin_tip := BoxFactory.make_box(10, 7, 6, GameColors.PLANE_ORANGE)
	fin_tip.position = Vector3(-72.0, 44.0, 0.0)
	add_child(fin_tip)
	# Auxiliary horizontal stabilizers either side of the fin base (orange).
	var stab_l := BoxFactory.make_box(16, 5, 22, GameColors.PLANE_ORANGE)
	stab_l.position = Vector3(-68.0, 10.0, 14.0)
	add_child(stab_l)
	var stab_r := BoxFactory.make_box(16, 5, 22, GameColors.PLANE_ORANGE)
	stab_r.position = Vector3(-68.0, 10.0, -14.0)
	add_child(stab_r)

	# Low wings — TWO-TONE: green trailing half + orange leading edge stripe
	# running the full span, plus orange tips. (Low-wing monoplane like the ref.)
	var wings := BoxFactory.make_box(20, 6, 110, GameColors.PLANE_GREEN)
	wings.position = Vector3(-7.0, -2.0, 0.0)        # green rear half
	add_child(wings)
	var wing_lead := BoxFactory.make_box(16, 6, 110, GameColors.PLANE_ORANGE)
	wing_lead.position = Vector3(10.0, -2.0, 0.0)     # orange leading-edge stripe
	add_child(wing_lead)
	var wingtip_l := BoxFactory.make_box(34, 6, 14, GameColors.PLANE_GREEN_DARK)
	wingtip_l.position = Vector3(0.0, -2.0, 61.0)
	add_child(wingtip_l)
	var wingtip_r := BoxFactory.make_box(34, 6, 14, GameColors.PLANE_GREEN_DARK)
	wingtip_r.position = Vector3(0.0, -2.0, -61.0)
	add_child(wingtip_r)

	# Wind shield (transparent)
	var shield := BoxFactory.make_transparent_box(3, 15, 20, GameColors.BLUE, 0.7)
	shield.position = Vector3(5.0, 27.0, 0.0)
	add_child(shield)

	# Propeller (rotates around X)
	_propeller = Node3D.new()
	_propeller.position = Vector3(60.0, 0.0, 0.0)
	add_child(_propeller)

	_propeller.add_child(BoxFactory.make_box(16, 14, 14, GameColors.BROWN_DARK))  # hub

	var blade1 := BoxFactory.make_box(4, 90, 12, GameColors.PLANE_WOOD)
	blade1.position = Vector3(6.0, 0.0, 0.0)
	_propeller.add_child(blade1)

	var blade2 := BoxFactory.make_box(4, 90, 12, GameColors.PLANE_WOOD)
	blade2.position = Vector3(6.0, 0.0, 0.0)
	blade2.rotation.x = PI / 2.0
	_propeller.add_child(blade2)

	# Pilot
	var pilot_holder := Node3D.new()
	pilot_holder.position = Vector3(-10, 27, 0)
	var pilot := PilotScript.new()
	pilot_holder.add_child(pilot)
	add_child(pilot_holder)

	# Wheels
	var wheel_protec_r := BoxFactory.make_box(30, 15, 10, GameColors.PLANE_ORANGE)
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

	var wheel_protec_l := BoxFactory.make_box(30, 15, 10, GameColors.PLANE_ORANGE)
	wheel_protec_l.position = Vector3(25.0, -20.0, -25.0)
	add_child(wheel_protec_l)

	var suspension := BoxFactory.make_box(4, 20, 4, GameColors.PLANE_ORANGE)
	suspension.position = Vector3(-32.5, 5.0, 0.0)
	suspension.rotation.z = -deg_to_rad(0.3)
	add_child(suspension)

	_prev_position = global_position


## Build a trapezoidal vertical fin (thin in Z) as an ArrayMesh. Profile lies
## in the X-Y plane: bottom edge length `bottom`, top edge length `top`
## (centered, so it's a symmetric trapezoid narrowing upward), height `h`,
## thickness `thick`. Origin is at the bottom-centre.
func _make_trapezoid_fin(bottom: float, top: float, h: float, thick: float, color: Color) -> MeshInstance3D:
	var hb := bottom * 0.5
	var ht := top * 0.5
	var hz := thick * 0.5
	# 4 profile points (front +X, rear -X), front/back faces at ±hz.
	# front face (z=+hz)
	var f0 := Vector3(hb, 0.0, hz)    # bottom-front
	var f1 := Vector3(-hb, 0.0, hz)   # bottom-rear
	var f2 := Vector3(-ht, h, hz)     # top-rear
	var f3 := Vector3(ht, h, hz)      # top-front
	# back face (z=-hz)
	var b0 := Vector3(hb, 0.0, -hz)
	var b1 := Vector3(-hb, 0.0, -hz)
	var b2 := Vector3(-ht, h, -hz)
	var b3 := Vector3(ht, h, -hz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
		var n: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		for v in [p0, p1, p2, p0, p2, p3]:
			st.set_normal(n); st.add_vertex(v)
	quad.call(f0, f1, f2, f3)   # front
	quad.call(b3, b2, b1, b0)   # back
	quad.call(f3, f2, b2, b3)   # top
	quad.call(b0, b1, f1, f0)   # bottom
	quad.call(f0, f3, b3, b0)   # leading (+X)
	quad.call(b1, b2, f2, f1)   # trailing (-X)

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	# Render both sides so an inconsistent winding can't leave a face black.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.set_surface_override_material(0, mat)
	return mi


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
