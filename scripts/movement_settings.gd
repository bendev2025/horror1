extends Resource
class_name MovementSettings

## All player movement, first-person arm feel, and display knobs in one place.
## Edit the values in this script, then run the game. The player reads these
## defaults at startup.

@export_group("Walk")
@export var move_speed: float = 10
## Seconds to accelerate from a standstill to move_speed.
@export var accel_time: float = 0.05
## Keeps the capsule stuck to platform edges instead of floating off.
@export var floor_snap_length: float = 0.2

@export_group("Jump")
@export var jump_velocity: float = 5.5
## If true, releasing jump while rising cuts upward speed (short hop).
@export var variable_jump: bool = true

@export_group("Ledge Grab")
## How far ahead to look for a platform lip.
@export var ledge_detect_distance: float = 2.2
## Chest-height ray that must hit the vertical face.
@export var ledge_grab_height: float = 1.1
## Head-height ray that must miss (open air above the lip).
@export var ledge_over_height: float = 2.2
## Extra height band around the grab ray (bigger Space window).
@export var ledge_grab_height_range: float = 1.0
## How far below the lip the feet sit while hanging.
@export var ledge_hang_offset: float = 1.25
@export var ledge_climb_duration: float = 0.2
## How far onto the pad to land when pulling up.
@export var ledge_climb_forward: float = 0.9
## How far below the lip you can still press Space to grab.
@export var ledge_grab_below: float = 1.5

@export_group("Wall Climb")
## How far away you can be and still grab the ladder while holding Space.
@export var wall_climb_detect: float = 2.4
## Chest-height ray that must hit a climbable face.
@export var wall_climb_height: float = 1.0
## Vertical climb speed, meters per second.
@export var wall_climb_speed: float = 4.2
## Sideways speed while on a climbable wall.
@export var wall_climb_strafe: float = 2.2
## How far onto the top pad to land after a climb.
@export var wall_climb_mount: float = 1.45
## Must face the wall at least this much (1 = dead-on).
@export var wall_climb_dot: float = 0.15

@export_group("Fall Flip")
## How far a ladder drop must be to play the landing front flip. Ignores hops.
@export var fall_flip_min_drop: float = 2
## Seconds for one full front flip after landing.
@export var fall_flip_duration: float = 0.9

@export_group("Slide")
## How long a slide lasts before the character stands back up.
@export var slide_duration: float = 2.0
## Peak slide speed at the start of the move, before slowing down.
@export var slide_speed: float = 15
## Extra m/s added once when a slide starts.
@export var slide_boost: float = 3.0
## Capsule height while sliding. Must stay >= 2 * radius (0.8 with the default 0.4).
@export var slide_height: float = 0.9
@export var slide_head_height: float = 0.72
@export var camera_lerp_speed: float = 14.0
## First-person camera tilt while sliding (degrees). Positive leans back (looks up).
@export var slide_lean_degrees: float = 14.0
## How close to the floor (meters) an airborne slide press is allowed.
@export var slide_air_drop_height: float = 1.8
## Downward slam speed when sliding from a short hop.
@export var slide_air_drop_speed: float = 18.0

@export_group("Vault")
## Seconds to clear a vaultable obstacle. Keep this shorter than a jump hang-time.
@export var vault_duration: float = 0.30
## How far ahead to look for a vaultable collider.
@export var vault_detect_distance: float = 2.6
## Ignore vaults when nearly standing still.
@export var vault_min_speed: float = 0.5
## Require movement to face the obstacle (1 = dead-on, 0 = any side-swipe).
@export var vault_approach_dot: float = 0.2
## Width/height of the Space-to-vault probe in front of the player.
@export var vault_probe_size: Vector3 = Vector3(2.6, 2.2, 3.6)
## Chest-height probe so we hit vault blocks (~0.8m) and miss slide bars (~1.08m+).
@export var vault_probe_height: float = 0.55
## Extra height of the feet above the obstacle top at the apex.
@export var vault_clearance: float = 0.12
## How far past the far face to land.
@export var vault_land_clearance: float = 1.45

@export_group("Mouse Look")
## Temporary debug camera. true = view from behind the capsule.
@export var third_person: bool = false
@export var third_person_distance: float = 6.0
@export var third_person_height: float = 1.2
## Radians of rotation per pixel of mouse motion.
@export var mouse_sensitivity: float = 0.002
@export var min_pitch_deg: float = -89.0
@export var max_pitch_deg: float = 89.0

@export_group("Sprint Camera")
## First-person camera bob at full sprint, in meters.
## X = left/right sway, Y = up/down bounce.
@export var sprint_camera_shift: Vector3 = Vector3(0.150, 0.150, 0.0)
## Idle first-person field of view, in degrees.
@export var camera_fov: float = 68.0
## Extra FOV added as speed rises, in degrees. Full extra at speed_fov_at.
@export var speed_fov: float = 80.0
## Horizontal speed (m/s) that reaches the full extra FOV.
@export var speed_fov_at: float = 50.0

@export_group("Arms View")
## How big the arm sprites are. Raise this to see more of each arm.
@export var arm_size: float = 0.008
## Vertical placement in the view. Higher (toward 0 or above) shows more sleeve.
@export var arm_height: float = -0.20
## How far from the middle of the screen each arm sits.
@export var arm_spread: float = 0.24
## Distance in front of the camera. Lower = closer and larger.
@export var arm_distance: float = 0.32
## 0 = mostly fists, 1 = the full sleeve stays on screen.
@export_range(0.0, 1.0) var arm_visible: float = 0.64

@export_group("Arms Swing")
## How hard the arms pump. Used as a shoulder-rotation scale, not a slide.
@export var swing_amount: float = 0.05
## How quickly the stride cycle advances. Scaled by actual ground speed.
@export var swing_speed: float = 1.15
## Extra vertical bounce on both arms while moving, in meters.
@export var bob_amount: float = 0.018

@export_group("Arms Sprint")
## Ground speed where sprint flavor starts blending in.
@export var sprint_start_speed: float = 5.0
## Ground speed where sprint flavor is full. At the default 10 m/s run this is full sprint arms.
@export var sprint_full_speed: float = 9.5
## Multiplier on how high/low the sprint pump travels.
@export var sprint_intensity: float = 1.8
## Extra stride frequency at full sprint. Keep modest so it does not vibrate.
@export var sprint_freq: float = 1.1
## Unused by sprint now (walk-only leftover). Kept so old values still load.
@export var sprint_forward: float = 0.2
## How far one arm raises and the other drops at full sprint, in meters.
@export var sprint_height: float = 0.12
## Unused by sprint now (walk-only leftover). Kept so old values still load.
@export var sprint_width: float = 0.55

@export_group("Arms Idle")
## Speed at or below this (m/s) counts as stopped.
@export var idle_speed_threshold: float = 0.45
## Peak breathing offset in meters. Keep tiny.
@export var breathe_amount: float = 0.004
## Breathing cycles per second.
@export var breathe_rate: float = 1.15

@export_group("Arms Jump / Fall")
## Added to both arms when rising (x = outward, y = up, z = back).
@export var jump_pose: Vector3 = Vector3(0.018, 0.055, 0.042)
## Extra pitch (degrees) while jumping; negative tips hands up/back.
@export var jump_pitch_deg: float = -12.0
## Added to both arms when falling (x = outward, y = down, z = forward).
@export var fall_pose: Vector3 = Vector3(0.028, -0.032, -0.016)
@export var fall_pitch_deg: float = 8.0
## Vertical speed that counts as a full jump pose.
@export var jump_ref_speed: float = 5.5
## Downward speed that counts as a full fall pose.
@export var fall_ref_speed: float = 8.0

@export_group("Arms Landing")
## Multiplier on the downward/forward landing dip.
@export var landing_impact: float = 1.0
## Downward speed (m/s) that produces a full-strength landing.
@export var landing_ref_speed: float = 8.0
## How fast the landing overlay fades (higher = quicker recovery).
@export var landing_recover_speed: float = 5.5
## Peak dip at full impact (y down, z forward).
@export var landing_pose: Vector3 = Vector3(0.0, -0.07, -0.045)

@export_group("Arms Slide")
## Offset while sliding (x unused, y down, z back).
@export var slide_pose: Vector3 = Vector3(0.0, -0.04, 0.02)
@export var slide_pitch_deg: float = 6.0
## Small forward/back sway while sliding, in meters.
@export var slide_sway_amount: float = 0.016
## How fast that sway cycles, scaled by slide speed.
@export var slide_sway_speed: float = 1.6

@export_group("Arms Ledge")
## Reach while hanging (x outward, y up, z forward).
@export var hang_pose: Vector3 = Vector3(0.012, 0.07, -0.11)
@export var hang_pitch_deg: float = -10.0
## Extra motion applied as climb_t goes 0 → 1 (up and more forward).
@export var climb_pose: Vector3 = Vector3(0.0, 0.05, -0.05)
@export var climb_pitch_deg: float = -10.0

@export_group("Arms Sway / Air")
## How much the arms lag behind yaw/pitch, in degrees per rad/s. Keep subtle.
@export var turn_sway: float = 2.4
@export var max_turn_sway_deg: float = 4.5
## How quickly sway eases back to center.
@export var sway_recover: float = 10.0
## How far airborne strafe shifts the arms, in meters at full move_speed.
@export var air_control_amount: float = 0.03

@export_group("Arms Smoothing")
## How fast poses lerp toward the current state. Higher = snappier.
@export var transition_smoothness: float = 12.0
## Extra lerp speed while a landing is playing.
@export var landing_snap: float = 22.0

@export_group("Display")
## World lighting. 1 is the current dark maze, 0 is black, 2 is much brighter.
@export var map_brightness: float = 2
## Headlamp. 1 is the current lamp, 0 is off, 2 is twice as bright.
@export var head_light: float = 2
