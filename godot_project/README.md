# Aviator To Sky — Godot 4 port

A Godot 4.x (GDScript) conversion of the original C++/OpenGL/GLUT project
`AVIATOR TO SKY` that lives in the parent directory.

## Requirements

- **Godot Engine 4.2+** (any 4.x release will work).

## Running

1. Open Godot 4.
2. Click **Import** and select the `godot_project/project.godot` file.
3. Press **F5** to run, or open `scenes/Main.tscn` and click ▶.

## Controls

| Input          | Action                                |
|----------------|---------------------------------------|
| Mouse          | Steer the airplane                    |
| Right-click    | Fire a missile from the plane         |
| `R`            | Restart the level                     |
| `Esc`          | Quit                                  |

## What's where

| File                                | Original counterpart             |
|-------------------------------------|----------------------------------|
| `scripts/GameConfig.gd` (autoload)  | `Game` struct in tester.h        |
| `scripts/GameColors.gd` (autoload)  | `Colors` palette in tester.cpp   |
| `scripts/BoxFactory.gd` (autoload)  | `BoxGeometry` / `tBoxGeometry` / `cBoxGeometry` helpers |
| `scripts/Main.gd` + `scenes/Main.tscn` | `Tester::Update()` + `Tester::Draw()` |
| `scripts/AirPlane.gd` + scene       | `Tester::AirPlane()` / `Tester::updatePlane()` |
| `scripts/Pilot.gd`                  | `Tester::pilot()`                |
| `scripts/Ennemy.gd` + scene         | `Ennemy` struct + spawn/rotate   |
| `scripts/Missle.gd` + scene         | `Missle` struct + `drawMissle()` / `flyMissles()` |
| `scripts/Coin.gd` + scene           | `Coin` struct + `spawn/rotateCoins` |
| `scripts/Building.gd` + scene       | `Building` struct + `construct/move` |
| `scripts/Particle.gd`               | `Particle` struct + `updateParticles` |
| `scripts/WhiteSphere.gd`            | `whiteSphere` struct + `makeWhiteSpheres` |
| `scripts/Terrain.gd`                | `Terrain` class + `moveWaves`    |
| `scripts/Sky.gd`                    | cloud setup in `Tester::Tester()` |

## Notes on the conversion

- The original used the Win32-only `timeGetTime()` for timing. The Godot port
  uses `_process(delta)` and converts `delta` to milliseconds where the
  original arithmetic was tuned to ms (`dt_ms = delta * 1000.0`).
- OpenGL fixed-function `glRotatef` used degrees; GDScript trigonometry uses
  radians. All angles were converted accordingly.
- The C++ project's bespoke shadow-mapping pass (`RegenerateShadowMap` /
  `RenderScene`) is replaced by Godot's built-in `DirectionalLight3D` with
  shadows enabled.
- The cube-based "icosahedron" enemy is approximated with a low-resolution
  `SphereMesh`. The "tetrahedron" coin uses `PrismMesh`. The aesthetic stays
  faceted to match the original boxy look.
- The original kept the "missile" spelling as `Missle` (a typo). That spelling
  is preserved here so anyone searching the C++ source can map names 1:1.
- The terrain and the cloud ring were commented out in the original
  `Tester::Draw()`. They are wired up and visible in this port — comment out
  the `add_child(sky)` / `add_child(terrain)` calls in `Main.gd` to disable.
