extends Node2D

# Lengths
@export var thigh_length: float = 20.0
@export var calf_length: float = 15.0

# Animation shaping
@export_range(0.0, 360.0, 0.01) var phase_offset_degrees: float = 0.0
@export_range(0.1, 0.9, 0.1) var gait_factor: float = 0.4
@export_range(0, 4.5, 0.01) var leg_extension_offset: float = 30
@export var flip_sway: bool = false
@export var hip_sway_amount: float = 0.4     # amplitude of hip sway in pixels
@export var foot_sway_amount: float = 0.4   # fraction of stride applied as lateral swing
@export_range(0.0, 1.0, 0.05) var sway_follow_movement: float = 0.5 # blend between facing and movement when swaying

@export var step_length_factor: float = 0.5  # scales stride amplitude with speed

# Facing and motion (driven by parent CharacterBody2D)
@export_range(0.0, 360.0, 0.1) var facing_direction_degrees: float = 90.0
@export var velocity: Vector2 = Vector2.ZERO

# Debug
@export var debug_draw: bool = true
@export var debug_labels: bool = true

# Foreshortening strength
@export_range(0.0, 1.0, 0.05) var foreshorten_strength: float = 0.75
# Knee bend strength
@export var bend_strength: float = 0.7

# Internal state (all in global space)
var hip_position: Vector2
var knee_position: Vector2
var foot_position: Vector2
var foot_target: Vector2

var leg_speed: float = 0.0
var motion_counter_degrees: float = 0.0
var moving_direction_radians: float = 0.0


## HELPERS
func lengthdir(length: float, angle_rad: float) -> Vector2:
	return Vector2.RIGHT.rotated(angle_rad) * length

# UPDATE LOOP
func _physics_process(_delta: float) -> void:
	# set globals
	hip_position = global_position # always global

	leg_speed = velocity.length()
	motion_counter_degrees += 5.2 * pow(leg_speed * 3.0, 0.4)
	motion_counter_degrees = fmod(motion_counter_degrees, 360.0)
	
	# set locals
	var total_len: float = thigh_length + calf_length
	var max_reach: float = total_len - leg_extension_offset
	
	#print("motion counter: " + str(motion_counter_degrees))

	var facing_rad: float = deg_to_rad(facing_direction_degrees)
	var move_rad: float = velocity.angle() if leg_speed > 0.001 else facing_rad
	
	# Foot oscillation
	var stride: float = pow(leg_speed * 2.0, 0.4)
	
	# Apply phase offset to motion counter
	var phase_rad: float = deg_to_rad(motion_counter_degrees + phase_offset_degrees)
	
	## Horizontal oscillation (sine)
	var forward_scale: float = 1.0 + leg_speed * step_length_factor
	var forward_offset: float = stride * (total_len / 4.0) * sin(phase_rad) * forward_scale
	forward_offset -= (leg_speed * 1.25) * 2.0
	
	## Vertical oscillation (cosine)
	var vertical_offset: float = stride * (total_len / 6.0) * (-cos(phase_rad) - 1.0)
	
	## Apply offsets in moving direction
	foot_target = hip_position + Vector2(0, max_reach)
	foot_target += lengthdir(forward_offset, move_rad)
	foot_target.y += vertical_offset
	
	# Secondary Animation
	## Hip Sway
	var sway_axis: Vector2 = Vector2.RIGHT.rotated(facing_rad + PI/2.0).normalized()
	if leg_speed > 0.001:
		var move_axis: Vector2 = Vector2.RIGHT.rotated(move_rad + PI/2.0).normalized()
		sway_axis = sway_axis.lerp(move_axis, sway_follow_movement)
	var hip_sway: float = hip_sway_amount * cos(phase_rad) if flip_sway == false else cos(-phase_rad)
	hip_position += sway_axis * hip_sway
	
	## Lateral foot swing
	var foot_swing_axis: Vector2 = Vector2.RIGHT.rotated(move_rad + PI/2.0).normalized()
	if leg_speed > 0.001:
		var facing_axis: Vector2 = Vector2.RIGHT.rotated(facing_rad + PI/2.0).normalized()
		foot_swing_axis = foot_swing_axis.lerp(facing_axis, 1.0 - sway_follow_movement)
	var foot_swing: float = foot_sway_amount * stride * sin(phase_rad) if flip_sway == false else sin(-phase_rad)
	foot_target += foot_swing_axis * foot_swing
	
	# IK triangle calculation (law of cosines)
	var c_raw: float = hip_position.distance_to(foot_target)
	var c: float = min(c_raw, max_reach)
	var alpha: float = hip_position.angle_to_point(foot_target) # radians
	
	## Foot position
	foot_position = hip_position + lengthdir(c, alpha)
	
	## Law of Cosines for thigh angle
	var cos_beta: float = clamp(
		(pow(thigh_length, 2) + pow(c, 2) - pow(calf_length, 2)) / (2.0 * thigh_length * c),
		-1.0, 1.0
	)
	var beta: float = acos(cos_beta)
	
	## Flat Knee position (basic 2D triangle)
	var knee_flat: Vector2 = hip_position + lengthdir(thigh_length, alpha - beta)
	
	## Intersection point along hip→foot line (for foreshortening)
	var ix: Vector2 = hip_position + lengthdir(thigh_length * cos(beta), alpha)
	
	## Vector from intersection to flat knee
	var knee_vec: Vector2 = knee_flat - ix
	var knee_vec_len := knee_vec.length()
	var knee_vec_dir := knee_vec / knee_vec_len if (knee_vec_len > 1e-6) else Vector2.ZERO
	
	## Bend offset ALONG knee_vec, signed by knee_mod
	var knee_mod: float = cos(facing_rad) # near 0 for up/down (90/270), ±1 for left/right (0/180)
	var bend_offset: Vector2 = knee_vec_dir * (knee_vec_len * knee_mod * bend_strength)
	
	## Blend between flat knee and bent knee using foreshorten_strength
	knee_position = ix + knee_vec * (1.0 - foreshorten_strength) + bend_offset * foreshorten_strength
	
	
	queue_redraw()
	
# DRAWING (local space relative to node)
func _draw() -> void:
	# Bones
	draw_line(to_local(hip_position), to_local(knee_position), Color(1, 1, 1), 3.0)
	draw_line(to_local(knee_position), to_local(foot_position), Color(1, 1, 1), 1.5)
	
	if not debug_draw:
		return

	# Joints
	#draw_circle(to_local(hip_position), 3.0, Color.GREEN)
	#draw_circle(to_local(knee_position), 3.0, Color.hex(0xffaa00ff))
	#draw_circle(to_local(foot_position), 3.0, Color.hex(0x55aaffff))

	# Target
	#draw_circle(to_local(foot_target), 2.0, Color.hex(0xff5555ff))
	#draw_line(to_local(hip_position), to_local(foot_target), Color(0.3, 0.3, 0.3), 1.0)

	if debug_labels:
		_draw_label(to_local(hip_position) + Vector2(6, -6), "HIP")
		_draw_label(to_local(knee_position) + Vector2(6, -6), "KNEE")
		_draw_label(to_local(foot_position) + Vector2(6, -6), "FOOT")
		_draw_label(to_local(foot_target) + Vector2(6, -6), "TARGET")

func _draw_label(pos: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0, Color.WHITE)
