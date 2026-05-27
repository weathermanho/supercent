extends Node
## Autoload singleton. Mirrors the C++ `Game` struct from tester.h.
## All gameplay tuning lives here so any scene can read/modify it.

const STATUS_GAME_OVER := 0
const STATUS_PLAYING := 1

var speed: float = 0.0
var init_speed: float = 0.00035
var base_speed: float = 0.00035
var target_base_speed: float = 0.00035
var increment_speed_by_time: float = 0.0
var increment_speed_by_level: float = 0.000003
var distance_for_speed_update: int = 100
var speed_last_update: int = 0

var distance: float = 0.0
var ratio_speed_distance: float = 50.0
var energy: float = 70.0
var ratio_speed_energy: float = 3.0

var level: int = 1
var level_last_update: int = 0
var distance_for_level_update: int = 1000

var plane_scale: float = 0.5
var plane_default_height: float = 100.0
var plane_amp_height: float = 100.0
var plane_low_height: float = 80.0
var plane_amp_width: float = 75.0
var plane_move_sensitivity: float = 0.005
var plane_rot_x_sensitivity: float = 0.0008
var plane_rot_z_sensitivity: float = 0.0004
var plane_fall_speed: float = 0.001
# NOTE: in the original C++ source `planeSpeed` was declared `int`, so the
# float result of `normalize(mousePos.x, -.5, .5, 1.2, 1.6)` was truncated to
# **1** every frame — meaning mouse-X never actually accelerated the plane,
# and the effective multiplier was always 1.0. We preserve that behavior by
# clamping the remap range to [1.0, 1.0] (instead of the apparent [1.2, 1.6]
# that the original code looked like it intended). This makes the Godot port
# match the original real-time pacing.
var plane_min_speed: float = 1.0
var plane_max_speed: float = 1.0
var plane_speed: float = 1.0
var plane_collision_displacement_x: float = 0.0
var plane_collision_speed_x: float = 0.0
var plane_collision_displacement_y: float = 0.0
var plane_collision_speed_y: float = 0.0

var sea_radius: float = 600.0
var sea_length: float = 800.0

var wave_length: int = 20
var wave_height: int = 10
var wave_scale: float = 80.0
var waves_min_amp: float = 5.0
var waves_max_amp: float = 20.0
var waves_min_speed: float = 0.001
var waves_max_speed: float = 0.003

var camera_far_pos: float = 700.0
var camera_near_pos: float = 100.0
var camera_sensitivity: float = 0.000001

var coin_distance_tolerance: float = 15.0
var coin_value: int = 3
var coins_speed: float = 0.5
var coin_last_spawn: int = 0
var distance_for_coins_spawn: int = 200

var ennemy_distance_tolerance: float = 10.0
var ennemy_value: int = 10
var ennemies_speed: float = 0.6
var ennemy_last_spawn: int = 0
var distance_for_ennemies_spawn: int = 50

var status: int = STATUS_PLAYING


func reset_to_defaults() -> void:
	speed = 0.0
	base_speed = init_speed
	target_base_speed = init_speed
	distance = 0.0
	energy = 70.0
	level = 1
	level_last_update = 0
	speed_last_update = 0
	coin_last_spawn = 0
	ennemy_last_spawn = 0
	plane_collision_displacement_x = 0.0
	plane_collision_displacement_y = 0.0
	plane_collision_speed_x = 0.0
	plane_collision_speed_y = 0.0
	plane_fall_speed = 0.001
	status = STATUS_PLAYING


## Mirrors `normalize(v, vmin, vmax, tmin, tmax)` in tester.cpp.
static func remap_clamped(v: float, vmin: float, vmax: float, tmin: float, tmax: float) -> float:
	var nv: float = clampf(v, vmin, vmax)
	var pc: float = (nv - vmin) / (vmax - vmin)
	return tmin + pc * (tmax - tmin)
