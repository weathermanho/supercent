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

# --- Showpiece additions -----------------------------------------------------

## Global game-time multiplier. 1.0 = normal. <1.0 = slowmo. 0.0 = freeze.
## Main._process multiplies dt_ms by this before passing to all step() callers.
var time_scale: float = 1.0

## Current weapon power level (1..3). ShowpieceDirector increments by distance.
var weapon_stage: int = 1

## Loaded from user://best.save at boot. Updated on game over.
var best_distance: int = 0

# Missile tuning (moved out of Missle.gd so it can be tweaked at runtime).
var missile_initial_forward_speed: float = 120.0
var missile_initial_drop_speed: float = 60.0
var missile_drop_gravity: float = 500.0       # gravity during drop phase (0..DROP_DURATION)
var missile_boost_gravity: float = 120.0      # gravity also during boost phase
var missile_boost_accel: float = 800.0        # weakened from 4500 -> 800 (less homing)
var missile_max_speed: float = 2200.0
var missile_drop_duration: float = 0.3
var missile_scale_stage1: float = 0.4
var missile_scale_stage2: float = 0.8
var missile_scale_stage3: float = 1.4
var missile_lock_radius: float = 22.0         # generous so ad cuts show confident chained hits

# Showpiece distances (m) — tuned for a 30-second ad cut at default scroll speed.
# At init_speed=0.00035 the player reaches ~525 distance in 30s, so escalation
# beats must fit inside that window.
var giant_distance_thresholds: Array[int] = [120, 240, 380]
var weapon_upgrade_distances: Array[int] = [60, 180]

# Juice constants
var shake_hit_intensity: float = 8.0
var shake_hit_duration: float = 0.12
var hitstop_duration: float = 0.05
var slowmo_giant_scale: float = 0.25
var slowmo_giant_duration: float = 1.5
var shake_giant_intensity: float = 30.0
var shake_giant_duration: float = 0.6


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
	time_scale = 1.0
	weapon_stage = 1


## Mirrors `normalize(v, vmin, vmax, tmin, tmax)` in tester.cpp.
static func remap_clamped(v: float, vmin: float, vmax: float, tmin: float, tmax: float) -> float:
	var nv: float = clampf(v, vmin, vmax)
	var pc: float = (nv - vmin) / (vmax - vmin)
	return tmin + pc * (tmax - tmin)


const SaveData := preload("res://scripts/SaveData.gd")

func _ready() -> void:
	best_distance = SaveData.load_best()
