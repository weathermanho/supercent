# Supercent Showpiece Core Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the existing Godot 4.3 project in-place so the 60–90s core loop builds up from a tiny missile → escalated weapon → giant-target finish with full destruction juice, against a desert+teal-sky atmosphere matching `e:\vive\0_new_supercent\image.png`. Goal metric: a Supercent reviewer subagent (cold) scores the 30-second clip ≥ 18/25.

**Architecture:** Existing nodes stay (`AirPlane`, `Missle`, `Building`, `Target`, `Particle`, `WhiteSphere`, `Main`, `GameConfig`). Add four thin manager scripts: `Atmosphere`, `CameraShaker`, `TimeScaler`, `ShowpieceDirector`, plus two single-shot effect scripts: `ShockwaveRing`, `FlashOverlay`, and a save helper `SaveData`. All tuning lives in `GameConfig` (existing autoload). Time scale is applied **once** in `Main._process` to `dt_ms` so all `step(dt_ms)` consumers automatically slow during hitstop/slowmo.

**Tech Stack:** Godot 4.3, GDScript, Forward+ renderer. No third-party libs, no networking, no sound (deferred), no tests framework (visual + manual + evaluator subagent for QA).

**Source spec:** `docs/superpowers/specs/2026-05-27-supercent-showpiece-design.md`

---

## File Map

**Create:**

- `godot_project/scripts/Atmosphere.gd` — sky gradient, fog, ground plane, lighting tweak.
- `godot_project/scripts/CameraShaker.gd` — applies noise offset to camera transform.
- `godot_project/scripts/TimeScaler.gd` — manages `GameConfig.time_scale` for hitstop + slowmo.
- `godot_project/scripts/ShockwaveRing.gd` — single-shot expanding ring effect.
- `godot_project/scripts/FlashOverlay.gd` — single-shot white screen flash.
- `godot_project/scripts/ShowpieceDirector.gd` — distance-driven escalation (weapon stage + giant trigger).
- `godot_project/scripts/SaveData.gd` — load/save best_distance to `user://best.save`.

**Modify:**

- `godot_project/scripts/GameConfig.gd` — add tuning vars (`time_scale`, `weapon_stage`, `best_distance`, missile constants, juice constants, giant thresholds).
- `godot_project/scripts/AirPlane.gd` — track `estimated_velocity`, multiply process delta by time_scale.
- `godot_project/scripts/Missle.gd` — gravity in boost phase, weakened homing, configurable scale.
- `godot_project/scripts/Target.gd` — `hp`, `take_damage`, giant variant geometry.
- `godot_project/scripts/Main.gd` — scale dt_ms by time_scale, instantiate new managers, hit-juice wiring, weapon-stage missile spawn, retry/best HUD.
- `godot_project/scripts/Particle.gd` — derive timing from dt_ms instead of fixed `+= 0.01`.
- `godot_project/scenes/Main.tscn` — add `WorldEnvironment`, `CameraShaker` child of Camera3D, `TimeScaler`, `ShowpieceDirector`, `Atmosphere`, `FlashOverlay` (ColorRect in HUD), `BestLabel`.

**Untouched (preserved):** `BoxFactory.gd`, `GameColors.gd`, `Pilot.gd`, `Building.gd`, `WhiteSphere.gd`, `Coin.gd`, `Sky.gd`, `Terrain.gd`, `GuideOverlay.gd`, `Ennemy.gd`, scene files for those.

---

## Task 0: Initialize git + baseline commit

**Files:**
- Modify: `E:\vive\0_new_supercent\.gitignore` (create)

- [ ] **Step 1: Run from repo root** `E:\vive\0_new_supercent`

```powershell
git init
git config user.email "dreamhighkwon@gmail.com"
git config user.name "kwon"
```

- [ ] **Step 2: Create `.gitignore`** at `E:\vive\0_new_supercent\.gitignore`

```
godot_project/.godot/
godot_project/.import/
*.tmp
*.log
```

- [ ] **Step 3: Baseline commit**

```powershell
git add .gitignore docs godot_project Aviator_To_Sky_핸드오프.md image.png
git commit -m "chore: baseline before showpiece work"
```

Expected: commit succeeds with both spec, plan, and source.

---

## Task 1: Add `time_scale` + new tuning vars to GameConfig

**Files:**
- Modify: `godot_project/scripts/GameConfig.gd` (append new vars after line 77, before `func reset_to_defaults`)

- [ ] **Step 1: Add tuning vars**

Open `godot_project/scripts/GameConfig.gd`. After the `var status: int = STATUS_PLAYING` line, before `func reset_to_defaults()`, insert:

```gdscript
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
var missile_boost_gravity: float = 120.0      # NEW: gravity also during boost phase
var missile_boost_accel: float = 800.0        # WEAKENED from 4500 → 800 (less homing)
var missile_max_speed: float = 2200.0
var missile_drop_duration: float = 0.3
var missile_scale_stage1: float = 0.4
var missile_scale_stage2: float = 0.55
var missile_scale_stage3: float = 0.7
var missile_lock_radius: float = 8.0          # WAS 18, narrowed so player must aim

# Showpiece distances (m)
var giant_distance_thresholds: Array[int] = [800, 1600, 2400]
var weapon_upgrade_distances: Array[int] = [400, 1200]

# Juice constants
var shake_hit_intensity: float = 8.0
var shake_hit_duration: float = 0.12
var hitstop_duration: float = 0.05
var slowmo_giant_scale: float = 0.25
var slowmo_giant_duration: float = 1.5
var shake_giant_intensity: float = 30.0
var shake_giant_duration: float = 0.6
```

- [ ] **Step 2: Reset showpiece state in `reset_to_defaults`**

Find `func reset_to_defaults() -> void:` and add at the end (inside the function):

```gdscript
	time_scale = 1.0
	weapon_stage = 1
```

(Don't reset `best_distance` — it persists across runs.)

- [ ] **Step 3: Launch the game once to confirm autoload still loads**

Run the project. Expected: no script parse errors in console. Plane still flies, mouse fire still works.

- [ ] **Step 4: Commit**

```powershell
git add godot_project/scripts/GameConfig.gd
git commit -m "feat(config): add showpiece tuning vars and time_scale"
```

---

## Task 2: Apply `time_scale` once in Main._process

**Files:**
- Modify: `godot_project/scripts/Main.gd:67-87` (the `_process` function)
- Modify: `godot_project/scripts/AirPlane.gd:119-133` (the `_process` function)
- Modify: `godot_project/scripts/Particle.gd:29-38` (the `step` function — derive on_time from dt_ms)

- [ ] **Step 1: In `Main.gd`, change `_process` to multiply dt_ms by time_scale**

Replace:

```gdscript
func _process(delta: float) -> void:
	var dt_ms: float = delta * 1000.0
```

with:

```gdscript
func _process(delta: float) -> void:
	var dt_ms: float = delta * 1000.0 * GameConfig.time_scale
```

- [ ] **Step 2: In `AirPlane.gd`, mirror the same scaling**

Replace the line in `_process`:

```gdscript
	var dt_ms: float = delta * 1000.0
```

with:

```gdscript
	var dt_ms: float = delta * 1000.0 * GameConfig.time_scale
```

(Leave propeller spin on raw delta — propeller spinning during slowmo looks wrong if synced, but raw delta makes it spin normally; either works visually. Keep raw delta for propeller — it's cosmetic, off-screen during slowmo anyway.)

- [ ] **Step 3: Fix `Particle.gd` to use dt_ms for on_time**

Replace:

```gdscript
func step(dt_ms: float) -> bool:
	on_time += 0.01
```

with:

```gdscript
func step(dt_ms: float) -> bool:
	on_time += dt_ms / 1000.0
```

(So particle aging respects time_scale via the dt_ms cascade.)

- [ ] **Step 4: Smoke test**

Launch the game. Open the script editor REPL is not needed — just play. Press F8 in Godot to step into editor, then temporarily add this at top of `_process` in Main.gd:

```gdscript
	if Input.is_key_pressed(KEY_T): GameConfig.time_scale = 0.2
	else: GameConfig.time_scale = 1.0
```

Hold T while playing — the world should slow to ~20% speed (plane drifts, missiles slow). Release T — back to normal.

- [ ] **Step 5: Remove the debug T-key code** (we'll trigger slowmo properly later)

Delete the two debug lines from Step 4.

- [ ] **Step 6: Commit**

```powershell
git add godot_project/scripts/Main.gd godot_project/scripts/AirPlane.gd godot_project/scripts/Particle.gd
git commit -m "feat(time): plumb GameConfig.time_scale through dt_ms"
```

---

## Task 3: AirPlane.estimated_velocity

**Files:**
- Modify: `godot_project/scripts/AirPlane.gd` (top vars + `_process`)

- [ ] **Step 1: Add fields**

Open `AirPlane.gd`. After `var corners: Array[Vector3] = []` (around line 24), add:

```gdscript
## Smoothed instantaneous velocity in world space (units/sec).
## Used by missile launch to add inheritance — feels like the plane "throws" the missile.
var estimated_velocity: Vector3 = Vector3.ZERO
var _prev_position: Vector3 = Vector3.ZERO
const VEL_SMOOTHING := 0.3  # 0=instant, 1=never updates
```

- [ ] **Step 2: Initialize prev_position in `_ready`**

At the end of `func _ready() -> void:`, add:

```gdscript
	_prev_position = global_position
```

- [ ] **Step 3: Update estimated_velocity each frame**

In `_process`, just before the final `_update_corners()` call, insert:

```gdscript
	var dt_s: float = max(delta, 0.0001)
	var instant: Vector3 = (global_position - _prev_position) / dt_s
	estimated_velocity = estimated_velocity.lerp(instant, 1.0 - VEL_SMOOTHING)
	_prev_position = global_position
```

(Note: use raw `delta`, not time-scaled, so velocity is in real units/sec.)

- [ ] **Step 4: Smoke test**

Add temporary print in `Main.gd._process`:

```gdscript
	print(airplane.estimated_velocity)
```

Play, move mouse — values should be non-zero, in the hundreds when moving fast. Stop mouse — values converge near zero. Remove the print.

- [ ] **Step 5: Commit**

```powershell
git add godot_project/scripts/AirPlane.gd
git commit -m "feat(plane): track estimated_velocity for missile inheritance"
```

---

## Task 4: Missile ballistics — weaken homing + velocity inheritance + boost-phase gravity

**Files:**
- Modify: `godot_project/scripts/Missle.gd` (replace constants block + `step` body + `_ready` initial velocity)
- Modify: `godot_project/scripts/Main.gd` (`_fire_missle`, `_find_missle_target`)

- [ ] **Step 1: Replace Missle.gd top-of-file constants**

In `godot_project/scripts/Missle.gd`, delete the constant block (lines 13–20) and the per-instance constants used elsewhere. Replace the block:

```gdscript
const SCALE := 0.4

const DROP_DURATION := 0.3
const INITIAL_FORWARD_SPEED := 120.0
const INITIAL_DROP_SPEED := 60.0
const GRAVITY := 500.0
const BOOST_ACCEL := 4500.0
const MAX_SPEED := 2200.0
```

with:

```gdscript
## Per-instance scale; set by Main before adding child. Default = stage 1.
var missile_scale: float = 0.4
```

- [ ] **Step 2: Replace `_ready()`'s initial-velocity line and SCALE usage**

Find this line in `_ready()`:

```gdscript
	velocity = Vector3(INITIAL_FORWARD_SPEED, -INITIAL_DROP_SPEED, 0.0)
```

Replace with:

```gdscript
	# Initial velocity is set by Main._fire_missle() *before* this scene is added,
	# via `m.velocity = ...`. Just normalize the orientation here.
	if velocity.length_squared() < 0.01:
		velocity = Vector3(GameConfig.missile_initial_forward_speed,
						   -GameConfig.missile_initial_drop_speed, 0.0)
```

Then in `_orient_to_velocity()`, change:

```gdscript
	transform.basis = Basis(forward, up, side).scaled(Vector3(SCALE, SCALE, SCALE))
```

to:

```gdscript
	transform.basis = Basis(forward, up, side).scaled(Vector3(missile_scale, missile_scale, missile_scale))
```

- [ ] **Step 3: Replace `step()` body with config-driven version + boost-phase gravity**

Replace the entire `func step(dt_ms: float) -> void:` body with:

```gdscript
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
		velocity.y -= GameConfig.missile_boost_gravity * delta  # NEW: keep gravity in boost

	position += velocity * delta
	_orient_to_velocity()
```

- [ ] **Step 4: Update `Main._fire_missle()` to inherit plane velocity + set scale**

In `godot_project/scripts/Main.gd`, find `_fire_missle()`. Replace its body:

```gdscript
func _fire_missle() -> void:
	var m := MissleScene.instantiate()
	add_child(m); _missles.append(m)
	# Fire from the plane's own position (matches the lock-circle's source).
	m.position = airplane.position + Vector3(40.0, 0.0, 0.0)
	# Pick a target: prefer a locked one (YZ within OVERLAP_TOLERANCE), else
	# the nearest forward target. Missile homes on whatever it gets.
	m.target = _find_missle_target()
```

with:

```gdscript
func _fire_missle() -> void:
	_spawn_missle(0.0)  # single straight shot — multi-fan added in Task 12

func _spawn_missle(yaw_offset_deg: float) -> void:
	var m: Node3D = MissleScene.instantiate()
	add_child(m); _missles.append(m)
	m.position = airplane.position + Vector3(40.0, 0.0, 0.0)

	# Set scale per current weapon stage.
	match GameConfig.weapon_stage:
		1: m.missile_scale = GameConfig.missile_scale_stage1
		2: m.missile_scale = GameConfig.missile_scale_stage2
		_: m.missile_scale = GameConfig.missile_scale_stage3

	# Aim direction: from plane to current world cursor target.
	var aim: Vector3 = Vector3.RIGHT
	var to_cursor: Vector3 = _get_world_cursor() - m.position
	if to_cursor.length_squared() > 1.0:
		aim = to_cursor.normalized()
	# Tilt by yaw_offset (rotate around Y).
	if absf(yaw_offset_deg) > 0.01:
		aim = aim.rotated(Vector3.UP, deg_to_rad(yaw_offset_deg))

	# Inherit plane velocity (the "throw" feel).
	var forward_speed: float = GameConfig.missile_initial_forward_speed
	var drop_speed: float = GameConfig.missile_initial_drop_speed
	m.velocity = aim * forward_speed + Vector3.DOWN * drop_speed + airplane.estimated_velocity

	# Target: lock-on only — no nearest fallback (handoff §부록C "완전 유도 금지").
	m.target = _find_missle_target()
```

- [ ] **Step 5: Tighten `_find_missle_target()` — no nearest fallback**

Replace the entire `_find_missle_target` function in `Main.gd`:

```gdscript
func _find_missle_target() -> Node3D:
	var lock_radius: float = GameConfig.missile_lock_radius
	var locked: Node3D = null
	var locked_dist: float = INF
	for t in _targets:
		if t.position.x <= airplane.position.x:
			continue
		var dy: float = t.position.y - airplane.position.y
		var dz: float = t.position.z - airplane.position.z
		var d: float = sqrt(dy * dy + dz * dz)
		if d < lock_radius and d < locked_dist:
			locked_dist = d
			locked = t
	return locked  # may be null — missile then flies straight (with gravity)
```

- [ ] **Step 6: Smoke test**

Launch. Fire missiles:
- Without aiming near a target, missiles should arc down (gravity) and miss.
- Aim mouse cursor near a red target — locked, missile bends *gently* (not violently) toward it.
- Move the mouse fast horizontally just before firing — missile should visibly carry sideways momentum.

If missiles vanish offscreen too fast, lower `missile_initial_forward_speed` in `GameConfig.gd`. If they fall like rocks, lower `missile_boost_gravity`.

- [ ] **Step 7: Commit**

```powershell
git add godot_project/scripts/Missle.gd godot_project/scripts/Main.gd
git commit -m "feat(missile): weak homing + velocity inheritance + boost gravity"
```

---

## Task 5: CameraShaker

**Files:**
- Create: `godot_project/scripts/CameraShaker.gd`
- Modify: `godot_project/scenes/Main.tscn` (add child of Camera3D)
- Modify: `godot_project/scripts/Main.gd` (`@onready` ref, initial setup)

- [ ] **Step 1: Create `CameraShaker.gd`**

File `godot_project/scripts/CameraShaker.gd`:

```gdscript
extends Node
## Attach as child of a Camera3D. Call `shake(intensity, duration)` to add
## random offsets to the camera's translation each frame for `duration` seconds.
## The base transform is read once on entry and restored on exit, so this does
## not interfere with whatever positions the camera (Main.gd sets it once at boot).

@export var trauma_decay: float = 4.0  # how fast intensity decays per second

var _camera: Camera3D
var _base_position: Vector3
var _trauma: float = 0.0   # current intensity (0..N)
var _time_left: float = 0.0


func _ready() -> void:
	_camera = get_parent() as Camera3D
	assert(_camera != null, "CameraShaker must be a child of Camera3D")
	_base_position = _camera.position


## Public API. Call repeatedly — uses max of (current, new) so it doesn't stack.
func shake(intensity: float, duration: float) -> void:
	_trauma = maxf(_trauma, intensity)
	_time_left = maxf(_time_left, duration)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		if _camera.position != _base_position:
			_camera.position = _base_position
		return

	_time_left -= delta
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var t: float = _trauma
	_camera.position = _base_position + Vector3(
		(randf() * 2.0 - 1.0) * t,
		(randf() * 2.0 - 1.0) * t,
		(randf() * 2.0 - 1.0) * t,
	)
```

- [ ] **Step 2: Attach CameraShaker to Camera3D in Main.tscn**

Open `godot_project/scenes/Main.tscn` in Godot. In the scene tree, right-click `Camera3D` → Add Child Node → `Node`. Name it `Shaker`. Select it → Inspector → Script → load `res://scripts/CameraShaker.gd`. Save scene.

(Alternative if editing the .tscn directly: at the end of the file, append:)

```
[node name="Shaker" type="Node" parent="Camera3D"]
script = ExtResource("CameraShaker_id")
```

with the corresponding `[ext_resource type="Script" path="res://scripts/CameraShaker.gd" id="2"]` near the top. Easier to do in the editor.

- [ ] **Step 3: Add ref in Main.gd**

In `Main.gd`, just under `@onready var camera: Camera3D = $Camera3D`, add:

```gdscript
@onready var shaker: Node = $Camera3D/Shaker
```

- [ ] **Step 4: Smoke test**

Add a temporary key trigger at the top of `Main._process`:

```gdscript
	if Input.is_key_pressed(KEY_K):
		shaker.shake(8.0, 0.15)
```

Hold K — camera should jitter visibly. Release — camera returns to base.

Remove the debug line after verification.

- [ ] **Step 5: Commit**

```powershell
git add godot_project/scripts/CameraShaker.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(juice): camera shaker"
```

---

## Task 6: TimeScaler

**Files:**
- Create: `godot_project/scripts/TimeScaler.gd`
- Modify: `godot_project/scenes/Main.tscn` (add as child of Main)
- Modify: `godot_project/scripts/Main.gd` (`@onready` ref)

- [ ] **Step 1: Create `TimeScaler.gd`**

File `godot_project/scripts/TimeScaler.gd`:

```gdscript
extends Node
## Owns GameConfig.time_scale. Two effects:
##   - hitstop: drives time_scale to ~0 briefly.
##   - slowmo: drives time_scale to a fraction (e.g. 0.25) for a longer beat.
## Hitstop trumps slowmo when both are active (the shortest, sharpest is what
## you want to read as "impact").

const HITSTOP_SCALE := 0.05  # near-freeze, not zero so animation stays smooth

var _hitstop_left: float = 0.0
var _slowmo_left: float = 0.0
var _slowmo_scale: float = 1.0


func request_hitstop(duration: float) -> void:
	_hitstop_left = maxf(_hitstop_left, duration)


func request_slowmo(scale: float, duration: float) -> void:
	# A new slowmo replaces the old (don't accumulate — last director's intent wins).
	_slowmo_scale = scale
	_slowmo_left = duration


func _process(delta: float) -> void:
	# Use unscaled real-time delta — but Godot's _process delta is raw; we apply
	# our own scale to gameplay via GameConfig.time_scale, not to _process itself.
	# So delta here is real seconds.
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		GameConfig.time_scale = HITSTOP_SCALE
	elif _slowmo_left > 0.0:
		_slowmo_left -= delta
		GameConfig.time_scale = _slowmo_scale
	else:
		GameConfig.time_scale = 1.0
```

- [ ] **Step 2: Add TimeScaler node to Main.tscn**

In the editor, with the `Main` root selected, Add Child Node → `Node`, name `TimeScaler`, attach `res://scripts/TimeScaler.gd`. Save scene.

- [ ] **Step 3: Add ref in Main.gd**

Under the `shaker` line:

```gdscript
@onready var time_scaler: Node = $TimeScaler
```

- [ ] **Step 4: Smoke test**

Add temporary keys to Main._process:

```gdscript
	if Input.is_key_pressed(KEY_H): time_scaler.request_hitstop(0.05)
	if Input.is_key_pressed(KEY_J): time_scaler.request_slowmo(0.25, 1.5)
```

Tap H — world freezes briefly. Tap J — world goes to slowmo for 1.5s. Then remove the debug lines.

- [ ] **Step 5: Commit**

```powershell
git add godot_project/scripts/TimeScaler.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(juice): time scaler for hitstop and slowmo"
```

---

## Task 7: ShockwaveRing + FlashOverlay

**Files:**
- Create: `godot_project/scripts/ShockwaveRing.gd`
- Create: `godot_project/scripts/FlashOverlay.gd`
- Modify: `godot_project/scenes/Main.tscn` (add FlashOverlay ColorRect under HUD)
- Modify: `godot_project/scripts/Main.gd` (`@onready` ref + spawn helper)

- [ ] **Step 1: Create `ShockwaveRing.gd`**

File `godot_project/scripts/ShockwaveRing.gd`:

```gdscript
extends Node3D
## One-shot expanding ring. Spawned at hit position, scales 1 → end_scale over
## `duration`, fades alpha 0.6 → 0, then queue_free. Built from a thin TorusMesh
## so it works without external assets.

@export var end_scale: float = 8.0
@export var duration: float = 0.4

var _t: float = 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 10.0
	torus.rings = 24
	torus.ring_segments = 6
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.6)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh = MeshInstance3D.new()
	_mesh.mesh = torus
	_mesh.set_surface_override_material(0, _mat)
	# Lay flat so it expands as a ring on the XZ plane (vertical Y is the axis).
	_mesh.rotation.x = PI / 2.0
	add_child(_mesh)
	scale = Vector3.ONE


func step(dt_ms: float) -> bool:
	_t += dt_ms / 1000.0
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var s: float = lerpf(1.0, end_scale, p)
	scale = Vector3(s, s, s)
	_mat.albedo_color.a = lerpf(0.6, 0.0, p)
	return _t < duration
```

- [ ] **Step 2: Create `FlashOverlay.gd`**

File `godot_project/scripts/FlashOverlay.gd`:

```gdscript
extends ColorRect
## Full-screen white flash. Call `flash(intensity, duration)`.
## Sits in the HUD CanvasLayer and is initially fully transparent.

var _t: float = 0.0
var _duration: float = 0.06
var _start_alpha: float = 0.0


func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0; anchor_top = 0.0; anchor_right = 1.0; anchor_bottom = 1.0
	offset_left = 0.0; offset_top = 0.0; offset_right = 0.0; offset_bottom = 0.0


func flash(intensity: float, duration: float) -> void:
	_start_alpha = clampf(intensity, 0.0, 1.0)
	_duration = maxf(duration, 0.001)
	_t = 0.0
	color.a = _start_alpha


func _process(delta: float) -> void:
	if color.a <= 0.0:
		return
	_t += delta
	var p: float = clampf(_t / _duration, 0.0, 1.0)
	color.a = lerpf(_start_alpha, 0.0, p)
```

- [ ] **Step 3: Add FlashOverlay to Main.tscn under HUD**

In editor: select `HUD` (CanvasLayer). Add Child Node → `ColorRect`. Name it `Flash`. Set anchors to "Full Rect" preset (anchor preset 15). Attach `res://scripts/FlashOverlay.gd`. Save scene.

- [ ] **Step 4: Add refs + spawn helper in Main.gd**

Under existing @onready refs:

```gdscript
@onready var flash_overlay: ColorRect = $HUD/Flash
```

At the top of `Main.gd`, near the other `const`s, add:

```gdscript
const ShockwaveRingScript := preload("res://scripts/ShockwaveRing.gd")
```

In Main.gd's `_particles` declaration block, declare a new array:

```gdscript
var _shockwaves: Array[Node3D] = []
```

Add a spawn helper somewhere after `_spawn_particles_at`:

```gdscript
func _spawn_shockwave(pos: Vector3, end_scale_: float, duration_: float) -> void:
	var ring: Node3D = ShockwaveRingScript.new()
	ring.end_scale = end_scale_
	ring.duration = duration_
	add_child(ring)
	ring.position = pos
	_shockwaves.append(ring)
```

And a tick:

```gdscript
func _update_shockwaves(dt_ms: float) -> void:
	var to_remove: Array[int] = []
	for i in _shockwaves.size():
		if not _shockwaves[i].step(dt_ms):
			to_remove.append(i)
	_cleanup(to_remove, _shockwaves)
```

Call `_update_shockwaves(dt_ms)` from `_process`, just below the existing `_update_particles(dt_ms)` line.

- [ ] **Step 5: Smoke test**

Add temporary keys in Main._process:

```gdscript
	if Input.is_key_pressed(KEY_L):
		flash_overlay.flash(0.4, 0.15)
		_spawn_shockwave(airplane.position + Vector3(200,0,0), 8.0, 0.4)
```

Hold L briefly — see screen flash + ring expand near the plane. Remove the debug lines.

- [ ] **Step 6: Commit**

```powershell
git add godot_project/scripts/ShockwaveRing.gd godot_project/scripts/FlashOverlay.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(juice): shockwave ring + flash overlay"
```

---

## Task 8: Wire juice into hits (normal target + wall)

**Files:**
- Modify: `godot_project/scripts/Main.gd` (`_fly_missles`, `_spawn_particles_at`, `_make_white_spheres`)

- [ ] **Step 1: Boost particle density and spread**

Find `_spawn_particles_at` in Main.gd. Replace it with:

```gdscript
func _spawn_particles_at(pos: Vector3, density: int, color: int, scale_: int) -> void:
	for i in density:
		var p: Node3D = ParticleScript.new()
		p.color_index = color
		p.sprite_scale = float(scale_)
		p.inc_y = -2.0 + randf() * 4.0
		p.inc_z = -2.0 + randf() * 4.0
		p.inc_rx = randf() * 18.0
		p.inc_rz = randf() * 18.0
		p.duration = 0.5
		add_child(p)
		p.position = pos
		_particles.append(p)
```

- [ ] **Step 2: Boost white_spheres**

Find `_make_white_spheres`. Replace with:

```gdscript
func _make_white_spheres(pos: Vector3, big: bool = false) -> void:
	var n: int = (80 + int(randf() * 40.0)) if big else (20 + int(randf() * 30.0))
	for i in n:
		var s: Node3D = WhiteSphereScript.new()
		s.color = GameColors.BROWN_DARK if i % 5 == 0 else GameColors.PURE_WHITE
		var max_scale: float = 18.0 if big else 8.0
		var min_scale: float = 10.0 if big else 3.0
		s.sphere_scale = min_scale + randf() * (max_scale - min_scale)
		s.duration = 1.4 if big else 0.9
		add_child(s)
		var spread: float = 35.0 if big else 18.0
		s.position = pos + Vector3(
			-spread + randf() * spread * 2.0,
			-spread + randf() * spread * 2.0,
			-spread + randf() * spread * 2.0
		)
		_white_spheres.append(s)
```

- [ ] **Step 3: Wire camera shake + hitstop + ring + flash into `_fly_missles` hit branches**

In `_fly_missles`, find the **target hit** block:

```gdscript
			if _segment_point_distance(m.prev_position, m.position, t_pos) < HIT_RADIUS:
				_spawn_particles_at(t_pos, 15, 1, 7)
				_targets[j].queue_free()
				_targets.remove_at(j)
				hit = true
				break
```

Replace with:

```gdscript
			if _segment_point_distance(m.prev_position, m.position, t_pos) < HIT_RADIUS:
				_spawn_particles_at(t_pos, 30, 1, 8)
				_spawn_shockwave(t_pos, 8.0, 0.4)
				shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
				time_scaler.request_hitstop(GameConfig.hitstop_duration)
				flash_overlay.flash(0.15, 0.06)
				_targets[j].queue_free()
				_targets.remove_at(j)
				hit = true
				break
```

Find the **wall hit** block:

```gdscript
			if not hit:
				for b in _buildings:
					if absf(m.position.x - b.position.x) < b.w * 0.5 \
					and absf(m.position.y - b.position.y) < b.h * 0.5 \
					and absf(m.position.z - b.position.z) < b.d * 0.5:
						_make_white_spheres(m.position)
						hit = true
						break
```

Replace with:

```gdscript
			if not hit:
				for b in _buildings:
					if absf(m.position.x - b.position.x) < b.w * 0.5 \
					and absf(m.position.y - b.position.y) < b.h * 0.5 \
					and absf(m.position.z - b.position.z) < b.d * 0.5:
						_make_white_spheres(m.position, false)
						_spawn_shockwave(m.position, 10.0, 0.45)
						shaker.shake(GameConfig.shake_hit_intensity * 1.4, GameConfig.shake_hit_duration * 1.2)
						time_scaler.request_hitstop(GameConfig.hitstop_duration)
						flash_overlay.flash(0.15, 0.08)
						hit = true
						break
```

- [ ] **Step 4: Smoke test**

Play. Fire missiles into targets and walls:
- Target hit: screen jitters briefly, brief freeze, white flash, ring expands, particle burst.
- Wall hit: same juice + ground dust spheres.

If hitstop feels too sticky, lower `GameConfig.hitstop_duration` to 0.04. If shake is nauseating, drop `shake_hit_intensity` to 6.

- [ ] **Step 5: Commit**

```powershell
git add godot_project/scripts/Main.gd
git commit -m "feat(juice): wire shake+hitstop+flash+ring into target and wall hits"
```

---

## Task 9: Target.hp + take_damage + giant variant

**Files:**
- Modify: `godot_project/scripts/Target.gd` (add hp + take_damage + giant flag)
- Modify: `godot_project/scripts/Main.gd` (use take_damage in hit branch)

- [ ] **Step 1: Replace `Target.gd`** entirely with:

```gdscript
extends Node3D
## Lock-on target. Normal targets: hp=1, small red icosahedron.
## Giant target: hp=3, large brown silhouette, marks the cinematic "boss" beat.

var wall: Node3D = null
var hp: int = 1
var is_giant: bool = false

var _mesh_instance: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	if is_giant:
		hp = 3
	var mesh := SphereMesh.new()
	if is_giant:
		mesh.radius = 120.0
		mesh.height = 240.0
	else:
		mesh.radius = 15.0
		mesh.height = 30.0
	mesh.radial_segments = 6 if not is_giant else 12
	mesh.rings = 4 if not is_giant else 8

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = GameColors.BROWN if is_giant else GameColors.RED
	_mat.roughness = 0.9
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA  # so fade works
	_mat.albedo_color.a = 1.0
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.set_surface_override_material(0, _mat)
	add_child(_mesh_instance)


## Returns true if this hit killed the target.
func take_damage(amt: int) -> bool:
	hp -= amt
	return hp <= 0


## Called by the giant-finish branch — kicks off a 0.6s alpha fade then frees.
func start_fade(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(queue_free)
```

- [ ] **Step 2: Update `Main._fly_missles` target branch to use take_damage**

In the target-hit block in `_fly_missles`, change:

```gdscript
			if _segment_point_distance(m.prev_position, m.position, t_pos) < HIT_RADIUS:
				_spawn_particles_at(t_pos, 30, 1, 8)
				_spawn_shockwave(t_pos, 8.0, 0.4)
				shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
				time_scaler.request_hitstop(GameConfig.hitstop_duration)
				flash_overlay.flash(0.15, 0.06)
				_targets[j].queue_free()
				_targets.remove_at(j)
				hit = true
				break
```

to:

```gdscript
			if _segment_point_distance(m.prev_position, m.position, t_pos) < (HIT_RADIUS * (8.0 if _targets[j].is_giant else 1.0)):
				# Capture flag BEFORE _on_giant_hit mutates _targets.
				var is_g: bool = _targets[j].is_giant
				var killed: bool = _targets[j].take_damage(1)
				if is_g:
					_on_giant_hit(_targets[j], killed)
				else:
					_spawn_particles_at(t_pos, 30, 1, 8)
					_spawn_shockwave(t_pos, 8.0, 0.4)
					shaker.shake(GameConfig.shake_hit_intensity, GameConfig.shake_hit_duration)
					time_scaler.request_hitstop(GameConfig.hitstop_duration)
					flash_overlay.flash(0.15, 0.06)
					if killed:
						_targets[j].queue_free()
						_targets.remove_at(j)
				hit = true
				break
```

(Giant hit-radius is multiplied by 8 to match the larger collision footprint. Giant removal is handled inside `_on_giant_hit` via fade.)

- [ ] **Step 3: Add `_on_giant_hit` stub for now**

In Main.gd, add a placeholder (will be fleshed out in Task 11):

```gdscript
func _on_giant_hit(g: Node3D, killed: bool) -> void:
	# Per-hit juice (small): a chip, not a kill yet.
	_spawn_particles_at(g.position, 20, 1, 8)
	_spawn_shockwave(g.position, 12.0, 0.4)
	shaker.shake(GameConfig.shake_hit_intensity * 1.5, GameConfig.shake_hit_duration)
	time_scaler.request_hitstop(GameConfig.hitstop_duration)
	flash_overlay.flash(0.2, 0.08)
	# Full giant-kill juice is added in Task 11.
	if killed:
		print("giant killed (juice combo TBD in Task 11)")
```

- [ ] **Step 4: Smoke test**

Game still plays. Normal targets die in one hit (no behavior change visible yet).

- [ ] **Step 5: Commit**

```powershell
git add godot_project/scripts/Target.gd godot_project/scripts/Main.gd
git commit -m "feat(target): hp + take_damage + giant variant (no spawner yet)"
```

---

## Task 10: ShowpieceDirector + giant spawning

**Files:**
- Create: `godot_project/scripts/ShowpieceDirector.gd`
- Modify: `godot_project/scenes/Main.tscn` (add ShowpieceDirector child of Main)
- Modify: `godot_project/scripts/Main.gd` (consult director in `_construct_building`)

- [ ] **Step 1: Create `ShowpieceDirector.gd`**

File `godot_project/scripts/ShowpieceDirector.gd`:

```gdscript
extends Node
## Watches GameConfig.distance and decides:
##   - when the next building spawn should be replaced by a giant
##   - when weapon_stage should increment
## Owns no state besides "what thresholds have already fired".

var _giant_thresholds_fired: Array[int] = []
var _weapon_thresholds_fired: Array[int] = []


## Returns true at most once per giant threshold. Call from Main._construct_building().
func consume_giant_due() -> bool:
	var d: int = floori(GameConfig.distance)
	for thresh in GameConfig.giant_distance_thresholds:
		if d >= thresh and not (thresh in _giant_thresholds_fired):
			_giant_thresholds_fired.append(thresh)
			return true
	return false


## Increment weapon_stage when distance crosses thresholds. Call every frame.
func tick_weapon(delta: float) -> void:
	var d: int = floori(GameConfig.distance)
	for thresh in GameConfig.weapon_upgrade_distances:
		if d >= thresh and not (thresh in _weapon_thresholds_fired):
			_weapon_thresholds_fired.append(thresh)
			GameConfig.weapon_stage = mini(GameConfig.weapon_stage + 1, 3)


func reset() -> void:
	_giant_thresholds_fired.clear()
	_weapon_thresholds_fired.clear()
```

- [ ] **Step 2: Add ShowpieceDirector node to Main.tscn**

Editor: under root `Main`, Add Child Node → `Node`, name `Director`, attach `res://scripts/ShowpieceDirector.gd`. Save.

- [ ] **Step 3: Use director in Main.gd**

Add `@onready` ref:

```gdscript
@onready var director: Node = $Director
```

In `_ready()`, after `GameConfig.reset_to_defaults()`, add:

```gdscript
	director.reset()
```

In `_tick_playing`, after `GameConfig.energy = maxf(...)` line and before `if GameConfig.energy < 1.0:`, add:

```gdscript
	director.tick_weapon(dt_ms / 1000.0)
```

Modify `_construct_building` to check the director:

```gdscript
func _construct_building() -> void:
	if director.consume_giant_due():
		_construct_giant()
		return
	# (existing body — two big buildings + transparent wall + normal red target)
	# ... unchanged ...
```

(Keep the existing body below the `return`.)

Add the new spawner:

```gdscript
func _construct_giant() -> void:
	# A standalone giant target — no flanking buildings, so it dominates the frame.
	var giant := TargetScene.instantiate()
	giant.is_giant = true
	add_child(giant)
	giant.position = Vector3(4000.0, 150.0, 0.0)
	giant.wall = null
	_targets.append(giant)
```

- [ ] **Step 4: Scroll the giant**

Find the `_targets` scroll loop in `_move_buildings`:

```gdscript
	var scroll: float = GameConfig.speed * dt_ms * GameConfig.ennemies_speed * 5000.0
	for i in _targets.size():
		_targets[i].position.x -= scroll
		if _targets[i].position.x <= -1000.0:
			to_remove_targets.append(i)
```

This already handles the giant correctly (it's just another `_targets` entry). No change needed — verify visually.

- [ ] **Step 5: Smoke test**

Play. Reach distance 800 — a huge brown sphere should approach. It takes 3 missile hits. (Full kill juice still in Task 11.)

- [ ] **Step 6: Commit**

```powershell
git add godot_project/scripts/ShowpieceDirector.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(director): giant target spawner + weapon stage trigger"
```

---

## Task 11: Giant kill — full juice combo

**Files:**
- Modify: `godot_project/scripts/Main.gd` (`_on_giant_hit`)

- [ ] **Step 1: Replace `_on_giant_hit` with full version**

```gdscript
func _on_giant_hit(g: Node3D, killed: bool) -> void:
	if not killed:
		# Chip hit: medium juice.
		_spawn_particles_at(g.position, 25, 1, 9)
		_spawn_shockwave(g.position, 14.0, 0.4)
		shaker.shake(GameConfig.shake_hit_intensity * 1.6, GameConfig.shake_hit_duration * 1.3)
		time_scaler.request_hitstop(GameConfig.hitstop_duration * 1.5)
		flash_overlay.flash(0.22, 0.10)
		_make_white_spheres(g.position, false)
		return

	# Kill: full showpiece combo.
	time_scaler.request_slowmo(GameConfig.slowmo_giant_scale, GameConfig.slowmo_giant_duration)
	shaker.shake(GameConfig.shake_giant_intensity, GameConfig.shake_giant_duration)
	flash_overlay.flash(0.4, 0.35)
	_spawn_shockwave(g.position, 40.0, 0.8)
	_make_white_spheres(g.position, true)
	_spawn_particles_at(g.position, 80, 1, 12)

	# Remove from _targets array (so it stops being hit-tested) but fade the mesh.
	var idx: int = _targets.find(g)
	if idx >= 0:
		_targets.remove_at(idx)
	g.start_fade(0.6)
```

- [ ] **Step 2: Smoke test**

Play to distance 800. Hit giant 3 times — final hit should:
1. Slow the world to ~25% for 1.5s.
2. Heavy camera shake for 0.6s.
3. Strong white flash.
4. Huge expanding ring (40× scale).
5. Big dust cloud.
6. Giant fades out smoothly over 0.6s.

If the fade looks weird because the slowmo also slows the tween — that's actually fine, it adds to the cinematic feel. If it bugs you, change `start_fade` to use a `Tween` with `set_process_mode(Tween.TWEEN_PROCESS_IDLE)` (independent of slowmo). For first cut, leave it.

- [ ] **Step 3: Commit**

```powershell
git add godot_project/scripts/Main.gd
git commit -m "feat(director): giant-kill full juice combo"
```

---

## Task 12: Weapon stages — multi-missile fan

**Files:**
- Modify: `godot_project/scripts/Main.gd` (`_fire_missle`)

- [ ] **Step 1: Replace `_fire_missle` body** to fan based on stage:

```gdscript
func _fire_missle() -> void:
	match GameConfig.weapon_stage:
		1:
			_spawn_missle(0.0)
		2:
			_spawn_missle(-6.0)
			_spawn_missle(6.0)
		_:
			_spawn_missle(-10.0)
			_spawn_missle(0.0)
			_spawn_missle(10.0)
```

- [ ] **Step 2: Smoke test**

Play. At start: 1 missile per click. Reach 400m — 2 missiles (slight spread). Reach 1200m — 3 missiles (wider fan). Each missile also scales up (bigger mesh).

- [ ] **Step 3: Commit**

```powershell
git add godot_project/scripts/Main.gd
git commit -m "feat(weapon): stage-based multi-missile fan"
```

---

## Task 13: Atmosphere — sky, fog, ground, lighting

**Files:**
- Create: `godot_project/scripts/Atmosphere.gd`
- Modify: `godot_project/scenes/Main.tscn` (add WorldEnvironment + Atmosphere node + remove old default_clear_color clash)
- Modify: `godot_project/scripts/Main.gd` (remove `_setup_lighting`, defer to Atmosphere)

- [ ] **Step 1: Create `Atmosphere.gd`**

File `godot_project/scripts/Atmosphere.gd`:

```gdscript
extends Node3D
## Owns the world look: gradient sky, sand-colored fog, sand ground plane,
## warm directional light. Replaces Main._setup_lighting().

const SKY_TOP := Color8(118, 180, 180)         # teal
const SKY_HORIZON := Color8(228, 210, 170)     # sand horizon (matches ground)
const GROUND_COLOR := Color8(232, 210, 165)
const FOG_COLOR := Color8(232, 210, 165)
const SUN_COLOR := Color(1.0, 0.93, 0.82)

@onready var _env: WorldEnvironment = $WorldEnv


func _ready() -> void:
	_setup_environment()
	_setup_ground()
	_setup_sun()


func _setup_environment() -> void:
	var env := Environment.new()

	# Sky.
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = SKY_TOP
	psm.sky_horizon_color = SKY_HORIZON
	psm.ground_horizon_color = SKY_HORIZON
	psm.ground_bottom_color = GROUND_COLOR
	psm.sun_angle_max = 30.0
	psm.sun_curve = 0.15
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY

	# Ambient — use the sky for soft fill.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6

	# Fog — depth-based haze.
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = 0.0008
	env.fog_depth_begin = 1500.0
	env.fog_depth_end = 6000.0

	# Tonemap for warmer look.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0

	_env.environment = env


func _setup_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(20000.0, 20000.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.set_surface_override_material(0, mat)
	mi.position = Vector3(2000.0, -120.0, 0.0)
	add_child(mi)


func _setup_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-40.0), 0.0)
	sun.light_energy = 1.1
	sun.light_color = SUN_COLOR
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 3000.0
	add_child(sun)
```

- [ ] **Step 2: Add Atmosphere + WorldEnvironment to Main.tscn**

In editor: with `Main` root selected, Add Child Node → `Node3D`, name `Atmosphere`, attach `res://scripts/Atmosphere.gd`. Then under `Atmosphere`, Add Child Node → `WorldEnvironment`, name `WorldEnv`. Save scene.

- [ ] **Step 3: Remove old lighting from Main.gd**

In `Main.gd._ready()`, delete this line:

```gdscript
	_setup_lighting()
```

And delete the `_setup_lighting()` function entirely (lines 59–64).

- [ ] **Step 4: (Optional) Clear the legacy clear_color so the sky is visible**

Open `godot_project/project.godot`. In `[rendering]` section, you may keep the existing `default_clear_color` — it's overridden by `BG_SKY`. No change required, but if you see a stripe of the old cream color at the very edge, you can comment out the line.

- [ ] **Step 5: Smoke test**

Launch. You should see:
- Teal sky on top, sand-colored horizon.
- Warm sandy ground stretching away.
- Distant buildings fading into the sand-toned haze.
- Plane and missiles look against the new backdrop.

If sky looks too uniform, lower `sun_curve` toward 0.05 (sharper horizon). If fog eats the giant too early, raise `fog_depth_begin` to 2000.

- [ ] **Step 6: Commit**

```powershell
git add godot_project/scripts/Atmosphere.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(atmosphere): teal sky + sand ground + haze fog"
```

---

## Task 14: Retry + local best

**Files:**
- Create: `godot_project/scripts/SaveData.gd`
- Modify: `godot_project/scripts/GameConfig.gd` (load best at boot)
- Modify: `godot_project/scenes/Main.tscn` (add BestLabel)
- Modify: `godot_project/scripts/Main.gd` (`_ready` loads best, `_update_hud` shows it, game-over writes it)

- [ ] **Step 1: Create `SaveData.gd`**

File `godot_project/scripts/SaveData.gd`:

```gdscript
extends Object
## Tiny key/value store backed by user://best.save. Best-effort: silent on failure.

const SAVE_PATH := "user://best.save"


static func load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var v: int = f.get_32()
	f.close()
	return v


static func save_best(best: int) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_32(best)
	f.close()
```

- [ ] **Step 2: Load best at GameConfig autoload init**

In `GameConfig.gd`, add at the bottom of the file:

```gdscript
const SaveData := preload("res://scripts/SaveData.gd")

func _ready() -> void:
	best_distance = SaveData.load_best()
```

- [ ] **Step 3: Add BestLabel to HUD in Main.tscn**

Editor: in `HUD/Margin/VBox`, Add Child Node → `Label`, name `BestLabel`. Text "Best: 0". Save.

- [ ] **Step 4: Update Main.gd HUD + game over logic**

Add ref:

```gdscript
@onready var best_label: Label = $HUD/Margin/VBox/BestLabel
```

Replace `_update_hud()`:

```gdscript
func _update_hud() -> void:
	distance_label.text = "Distance: %d   Level: %d" % [int(GameConfig.distance), GameConfig.level]
	energy_bar.value = GameConfig.energy
	best_label.text = "Best: %d" % GameConfig.best_distance
	if GameConfig.status == GameConfig.STATUS_GAME_OVER:
		var is_new_best: bool = int(GameConfig.distance) > GameConfig.best_distance
		status_label.text = ("NEW BEST!  Press R to fly again" if is_new_best
							 else "GAME OVER  —  Press R to fly again")
	else:
		status_label.text = ""
```

Add a transition-into-game-over hook. Modify `_tick_playing`:

Find the existing end-of-game check:

```gdscript
	if GameConfig.energy < 1.0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
```

Replace with:

```gdscript
	if GameConfig.energy < 1.0:
		GameConfig.status = GameConfig.STATUS_GAME_OVER
		_on_game_over()
```

Add the new function:

```gdscript
func _on_game_over() -> void:
	var traveled: int = int(GameConfig.distance)
	if traveled > GameConfig.best_distance:
		GameConfig.best_distance = traveled
		var SaveData := preload("res://scripts/SaveData.gd")
		SaveData.save_best(GameConfig.best_distance)
```

- [ ] **Step 5: Smoke test**

Play once, die (let energy drain). HUD shows "NEW BEST! Press R …". Close game. Re-launch. HUD shows previous best in the Best: line. Press R to reset — best is preserved.

- [ ] **Step 6: Commit**

```powershell
git add godot_project/scripts/SaveData.gd godot_project/scripts/GameConfig.gd godot_project/scenes/Main.tscn godot_project/scripts/Main.gd
git commit -m "feat(meta): persist best_distance via user://best.save"
```

---

## Task 15: Final smoke + Supercent evaluator subagent loop

**Files:**
- None to modify in this task — this is the QA loop.

- [ ] **Step 1: Full manual playthrough**

Launch the game. Play from start for 90 seconds. Verify:
- Sky/ground/fog match image.png direction.
- Targets and walls explode with shake + ring + flash.
- Distance 400 → 2 missiles; 1200 → 3 missiles.
- Distance 800, 1600, 2400 → giant target appears, dies on 3rd hit with full slowmo + heavy juice.
- Press R restarts immediately.
- Best persists across launches.
- FPS stays near 60 (check with F3 stats if needed).

- [ ] **Step 2: Capture screenshots for evaluator**

Run the game, press PrintScreen at:
- t=0s (first frame after boot)
- t=5s (early flight)
- After first weapon upgrade (~400m)
- Mid-air during a missile hit
- Approach to the first giant target
- Final frame of the giant kill (slowmo peak)

Save these as `e:\vive\0_new_supercent\eval\capture_<n>.png`. If you have a screen recorder (OBS), capture a 30-second clip showing start → first giant kill and save as `eval\clip.mp4` (optional but stronger evidence).

- [ ] **Step 3: Dispatch `supercent-evaluator` subagent**

The orchestrator (main session) will dispatch a fresh subagent with this prompt template (do not include any spec/plan content — cold eval):

```
You are a Supercent challenge reviewer. Your job is to score a 30-second
gameplay clip from a small studio's submission on whether it looks like a
profitable hyper-casual / hybrid-casual ad.

Reference aesthetic the studio is aiming for: e:\vive\0_new_supercent\image.png
Captures of the current build: e:\vive\0_new_supercent\eval\capture_*.png
(Optional clip: e:\vive\0_new_supercent\eval\clip.mp4)

Score each item 0–5 with one short sentence of justification:
1. First 3-second hook — does the opening grab attention?
2. Small → big build-up — is the escalation visible within 30 seconds?
3. Giant finish — would the final beat work as an ad thumbnail?
4. Color/mood — does it match the reference image's tone?
5. Impact strength — does destruction feel weighty? (juice quality)

Then give: total /25, list any item < 3 with a concrete fix suggestion,
and a one-paragraph overall verdict ending with PASS or FAIL.

PASS criteria: total >= 18 AND every item >= 3.

Do NOT read the project spec or plan files. Judge only from the images
(and clip if present) versus the reference image. Be honest — a generous
review wastes the studio's iteration budget.
```

- [ ] **Step 4: Apply feedback**

If FAIL: implement the single highest-leverage fix per the evaluator's notes, re-capture, re-dispatch. Iterate. Do not make broad changes — only the specific fix called out, then re-evaluate.

If PASS: lock the build, tag the commit:

```powershell
git tag -a v0.1-showpiece -m "Supercent showpiece spec passed evaluator"
```

- [ ] **Step 5: Final commit (only if any tuning was done in Step 4)**

```powershell
git add -A
git commit -m "tune: showpiece final pass per evaluator feedback"
```

---

## Acceptance Criteria (must hold before declaring this plan done)

- [ ] All 15 tasks committed.
- [ ] Game launches without script errors.
- [ ] 60 fps sustained on a development machine for a 90-second run.
- [ ] Atmosphere visibly matches `image.png` direction (teal sky + sand + haze).
- [ ] Missiles inherit plane velocity AND fall under gravity AND home weakly only when locked.
- [ ] Hits produce screen shake + hitstop + flash + ring + boosted particles.
- [ ] Distance 800/1600/2400 spawn a giant target. 3 hits kills it with full slowmo combo.
- [ ] Weapon stage increments at 400m and 1200m (visible: more missiles per click + larger meshes).
- [ ] Best distance persists across game launches.
- [ ] Supercent evaluator subagent returns PASS (≥ 18/25, no item < 3).

---

## Notes for the Implementing Subagent

- **YAGNI hard.** If a feature isn't in this plan, don't add it. The spec explicitly excludes ads, IAP, meta progression, sound, complex bosses.
- **No tests** — there is no test framework wired up and the spec opts out. Each task's "smoke test" step IS the test.
- **Commits per task** — each task ends with a commit. Do not batch.
- **Tuning is expected** — the numeric values in the plan are starting points. If a smoke step looks wrong, adjust the value in `GameConfig.gd` (single source of truth) and note the change in the commit message.
- **Editor vs .tscn text** — prefer the Godot editor for scene tree edits (less error-prone than hand-editing `.tscn`). Save scene after every change.
- **If a step fails** — stop, surface the error. Do not skip ahead. The plan is sequential.
