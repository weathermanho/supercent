extends Node
## Autoload singleton. Mirrors the C++ `Game` struct from tester.h.
## All gameplay tuning lives here so any scene can read/modify it.

const STATUS_GAME_OVER := 0
const STATUS_PLAYING := 1
const STATUS_TITLE := 2

var speed: float = 0.0
var init_speed: float = 0.00014        # calmer still — room to breathe between beats
var base_speed: float = 0.00014
var target_base_speed: float = 0.00014
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
var plane_amp_height: float = 160.0   # vertical range up/down (was 100)
var plane_low_height: float = 80.0
var plane_amp_width: float = 75.0
var plane_move_sensitivity: float = 0.0038
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
var base_ennemies_speed: float = 0.6                          # multiplied by stage
var ennemies_speed: float = 0.6
var ennemy_last_spawn: int = 0
var distance_for_ennemies_spawn: int = 22   # legacy; replaced by stage tables

## Per-stage pacing — stage 1 (warmup) is slow + sparse; stage 5 (chaos) is fast
## + dense. Driven by Main._tick_playing using _current_stage as the index.
var stage_spawn_intervals: Array[int] = [30, 22, 18, 16, 14]
var stage_speed_mults: Array[float] = [0.85, 1.0, 1.1, 1.2, 1.4]

var status: int = STATUS_PLAYING

# --- Showpiece additions -----------------------------------------------------

## Global game-time multiplier. 1.0 = normal. <1.0 = slowmo. 0.0 = freeze.
## Main._process multiplies dt_ms by this before passing to all step() callers.
var time_scale: float = 1.0

## Current weapon power level (1..3). Driven by combo tier now (was distance).
var weapon_stage: int = 1

# --- Combo gigantification (부록 C P0, 앞당김) -------------------------------
## Consecutive breakable-pillar-core hits grow the missile through tiers. A
## crash or a too-long gap with no hit resets it (forgiving: not per-miss).
var combo: int = 0
var combo_tier: int = 0
var combo_timer: float = 0.0
var combo_timeout: float = 4.5                       # sec without a hit -> reset
var combo_thresholds: Array[int] = [2, 5, 9]         # hits to reach tier 1 / 2 / 3
var max_combo_tier: int = 3
## Missile scale per tier (0..3). 4축 ①크기.
var missile_tier_scales: Array[float] = [0.24, 0.36, 0.52, 0.74]

# --- HP / fail-state (역경의 이빨) -------------------------------------------
var hp: int = 3
var max_hp: int = 3
var crash_iframes_max: float = 0.9                   # grace after a crash
var crash_iframes: float = 0.0

# --- Giant finish = skill check ---------------------------------------------
## The missile must be at least this tier to actually finish a giant; below it,
## hits only chip (so a sloppy approach arrives too weak to see the payoff).
var giant_required_tier: int = 2

# --- Ultimate gauge (부록 C P1: 궁극기 게이지) -------------------------------
## Builds with every meaningful action; right-click / SPACE unleashes a
## screen-clearing T3 missile fan when full. Gives the run an active goal
## INSIDE every play session (retention) + a guaranteed spectacle beat (CPI).
var ultimate_gauge: float = 0.0
var ultimate_gauge_max: float = 100.0
var ultimate_charge_per_kill: float = 9.0      # killing a breakable core
var ultimate_charge_per_chip: float = 4.5      # chipping a multi-HP core
var ultimate_charge_per_tier_up: float = 22.0  # crossing a tier threshold
var ultimate_charge_per_giant_chip: float = 14.0
var ultimate_charge_per_giant_kill: float = 35.0

## Loaded from user://best.save at boot. Updated on game over.
var best_distance: int = 0

# Missile tuning (moved out of Missle.gd so it can be tweaked at runtime).
# Two-phase flight: the missile FREE-FALLS straight down out of the fuselage
# (no forward component), then the booster lights and it flies/homes to the
# target. forward_speed is 0 so the drop is purely vertical (not a forward arc).
var missile_initial_forward_speed: float = 0.0    # no forward push — pure vertical drop
var missile_initial_drop_speed: float = 70.0      # initial downward kick out of the bay
var missile_drop_gravity: float = 320.0       # gravity accelerates the free-fall
var missile_boost_gravity: float = 60.0       # mild gravity once boosting (unlocked shots)
var missile_boost_accel: float = 1400.0       # homing strength for normal targets
var missile_max_speed: float = 2200.0
var missile_drop_duration: float = 0.22       # free-fall time before the booster ignites
var missile_scale_stage1: float = 0.22
var missile_scale_stage2: float = 0.38
var missile_scale_stage3: float = 0.6
var missile_lock_radius: float = 120.0        # generous: lock without putting the plane ON the target (which would occlude it)

# Showpiece distances (m) — tuned for a 30-second ad cut at default scroll speed.
# At init_speed=0.00035 the player reaches ~525 distance in 30s, so escalation
# beats must fit inside that window.
## Aligned with stage boundaries: first giant looms during stage 3 (반사),
## second giant is the climactic kill of stage 4 (하늘).
var giant_distance_thresholds: Array[int] = [110, 230]
var weapon_upgrade_distances: Array[int] = [40, 120]

# Juice constants — per-hit shake kept low to avoid eye fatigue. Giant-kill
# and OVERCHARGE use shake_giant_intensity which stays heavy for impact.
var shake_hit_intensity: float = 3.0
var shake_hit_duration: float = 0.07
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
	combo = 0
	combo_tier = 0
	combo_timer = 0.0
	hp = max_hp
	crash_iframes = 0.0
	ultimate_gauge = 0.0


# --- Combo helpers -----------------------------------------------------------

## A breakable pillar core was destroyed: extend the chain and (maybe) grow.
func register_core_hit() -> void:
	combo += 1
	combo_timer = 0.0
	_recompute_tier()


func reset_combo() -> void:
	combo = 0
	combo_tier = 0
	combo_timer = 0.0


func _recompute_tier() -> void:
	var t: int = 0
	for i in combo_thresholds.size():
		if combo >= combo_thresholds[i]:
			t = i + 1
	combo_tier = mini(t, max_combo_tier)
	weapon_stage = clampi(combo_tier + 1, 1, 3)  # fan-fire count rides along


## Call every frame with scaled delta-seconds. Decays the combo if the player
## goes too long without a hit, and ticks down crash i-frames.
func tick_combo(delta: float) -> void:
	if crash_iframes > 0.0:
		crash_iframes = maxf(0.0, crash_iframes - delta)
	if combo > 0:
		combo_timer += delta
		if combo_timer >= combo_timeout:
			reset_combo()


func missile_scale_for_tier() -> float:
	return missile_tier_scales[clampi(combo_tier, 0, missile_tier_scales.size() - 1)]


## Mirrors `normalize(v, vmin, vmax, tmin, tmax)` in tester.cpp.
static func remap_clamped(v: float, vmin: float, vmax: float, tmin: float, tmax: float) -> float:
	var nv: float = clampf(v, vmin, vmax)
	var pc: float = (nv - vmin) / (vmax - vmin)
	return tmin + pc * (tmax - tmin)


const SaveData := preload("res://scripts/SaveData.gd")

func _ready() -> void:
	best_distance = SaveData.load_best()
