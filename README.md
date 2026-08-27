# Horror Game

A first-person horror parkour game built in Godot. You run an endless industrial path that generates as you go: jumps, slides, vaults, climbs, drops, and branching walkways in a dark, foggy machine world.

Keep moving. A charge meter drains over time. Slash wooden crates with a knife to spill batteries, then click them to restore charge.

## Getting started

### What you need

- **[Godot 4.7](https://godotengine.org/download)** (Standard build, not .NET). The project uses the Forward Plus renderer.
- A mouse and keyboard.

No extra SDKs, packages, or command-line tools are required.

### How to run

1. Install Godot 4.7 and open it.
2. Click **Import**, select this folder’s `project.godot`, and import the project.
3. Press **F5** (or **Play** in the top-right) to run the main scene (`scenes/world.tscn`).

The mouse is captured as soon as the game starts. Press **Escape** to free the cursor; click the game window to capture it again.

## Controls

| Action | Input |
| --- | --- |
| Move | **W A S D** |
| Look | **Mouse** |
| Jump | **Space** |
| Slide | **Ctrl** (hold) |
| Draw knife / slash / pick up battery | **Left mouse button** |
| Holster knife | **Right mouse button** |
| Free / recapture mouse | **Escape** / click the window |

There is no dedicated sprint key. You run at full speed by holding a movement key; sprint camera and arm motion kick in automatically.

## How to play

The world is an infinite grid of metal pads. Stay on the path as it turns, splits, and changes height.

**Movement**

- **Jump** gaps. Release Space early for a shorter hop.
- **Slide** under low bars. You can also tap Ctrl near the ground after a short hop to drop into a slide.
- **Vault** by running at a vault block and tapping Space.
- **Wall climb** by holding Space against a climbable wall. Strafe with A/D, climb with W/Space, and drop with S.
- **Ledge grab** by tapping Space at a platform lip while airborne. Press W or Space to pull up, or S to drop.

**Knife and loot**

- First left-click draws the knife. While it is out, you move a bit slower.
- Left-click again to slash. Wooden crates take **3** hits to open.
- Open crates can drop **0–3 batteries**. Look at a battery (within about 2 meters) and left-click to pick it up.
- Right-click puts the knife away.

**Charge**

The bottom-left HUD shows your speed and a percent that drains from 100% to 0% over about **60 seconds**. Each battery restores **30%** charge (capped at 100%).

The top-left debug overlay lists loaded platforms and FPS. It is for development and does not affect play.

## Project layout

```
scenes/     world, player, and platform chunk
scripts/    player, level generator, knife, crates, HUD
assets/     pixel arm and battery sprites
```

Tune movement feel in `scripts/movement_settings.gd`. Tune path generation, crates, and batteries on the `LevelSpawner` node in `scenes/world.tscn` (or the exports at the top of `scripts/level_spawner.gd`).
