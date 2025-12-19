class_name Leg

extends Node2D

# --- Constants ---

const STRIDE_VEL_SCALE = 2.0
const STRIDE_EXP = 0.4

const FORWARD_OFFSET_DIV = 4.0
const FORWARD_OFFSET_VEL_SCALE = 1.25
const FORWARD_OFFSET_MULT = 2.0

const VERTICAL_OFFSET_DIV = 6.0
const VERTICAL_OFFSET_SHIFT = -1.0

const TO_TARGET_EPSILON = 0.001

const KNEE_VEC_MIN_LEN = 1e-6

const BONE_WIDTH = 3.0
const CALF_WIDTH = 1.5
const HIP_RADIUS = 3.0
const KNEE_RADIUS = 3.0
const FOOT_RADIUS = 3.0
const TARGET_RADIUS = 2.0

var FOOT_COLOR := Color.hex(0x55aaffff)
var TARGET_COLOR := Color.hex(0xff5555ff)


# Facing and motion (driven by parent CharacterBody2D)

@export var hip: Hip

# Lengths
@export_group("Bone Lengths")
@export var thigh_length: float = 20.0
@export var calf_length: float = 15.0


# Animation shaping
@export_group("Animation Shaping")
@export_range(0.0, 360.0, 0.01) var phase_offset_degrees: float = 0.0
@export_range(0.1, 0.9, 0.1) var gait_factor: float = 0.4


# Stride amplitude scaling
# The X-axis of this curve is velocity (leg_speed), Y-axis is stride amplitude multiplier (0 to max)
# Set the rightmost X value to the velocity where stride amplitude should cap.
@export var stride_amplitude_curve: Curve

# Step length and height shaping
# The X-axis of these curves is velocity (leg_speed), Y-axis is the multiplier for horizontal (length) and vertical (height) step characteristics.
# At low speeds, you can set step_length_curve Y low (short steps) and step_height_curve Y high (high knees), etc.
@export var step_length_curve: Curve
@export var step_height_curve: Curve

# Foreshortening strength
@export_subgroup("Foreshorten + Bend")
@export_range(0.0, 1.0, 0.05) var foreshorten_strength: float = 1.0
# Knee bend strength
@export var bend_strength: float = 1.0


# Debug
@export_group("Debug")
@export var debug_draw: bool = true
@export var debug_labels: bool = false

# Internal state (all in global space)
var hip_position: Vector2
var knee_position: Vector2
var foot_position: Vector2
var foot_target: Vector2


var moving_direction_radians: float = 0.0

# Sprite support
@export_group("Sprites")
@export var thigh_sprite: Texture2D
@export var calf_sprite: Texture2D

# Orientation: "left-right" or "top-bottom"
enum SpriteOrientation { LEFT_RIGHT, TOP_BOTTOM }
@export var thigh_orientation: SpriteOrientation = SpriteOrientation.LEFT_RIGHT
@export var calf_orientation: SpriteOrientation = SpriteOrientation.LEFT_RIGHT


var legs_root:LegsRoot


## HELPERS
func lengthdir(length: float, angle_rad: float) -> Vector2:
	return Vector2.RIGHT.rotated(angle_rad) * length

# --- Startup Validation ---
func _ready():
	var parent = get_parent()
	if parent == null or not parent is LegsRoot:
		push_error("Leg must be a child of LegsRoot.")
	else:
		legs_root = parent


# --- Main Update Loop ---

func _physics_process(_delta: float) -> void:
	hip_position = hip.global_position # always global

	var facing_direction_degrees := legs_root.character_root.facing_degrees
	var velocity := legs_root.character_root.velocity
	var motion_counter_degrees := legs_root.character_root.motion_counter_degrees
	var leg_speed := legs_root.character_root.leg_speed

	# limit velocity for stability
	var max_velocity_length := 1.0
	if velocity.length() > max_velocity_length:
		velocity = velocity.normalized() * max_velocity_length

	var total_len: float = thigh_length + calf_length
	var max_reach: float = total_len

	var facing_rad: float = deg_to_rad(facing_direction_degrees)
	var move_rad: float = velocity.angle() if leg_speed > 0.0001 else facing_rad

	var stride: float = _calc_stride(leg_speed)
	var phase_rad: float = deg_to_rad(motion_counter_degrees + phase_offset_degrees)

	# Sample stride amplitude, step length, and step height from curves using current velocity
	# Stride amplitude is overall scale; step length/height are normalized [0,1] for shape only
	var stride_amplitude := 1.0
	if stride_amplitude_curve:
		stride_amplitude = stride_amplitude_curve.sample(leg_speed)

	var step_length_shape := 1.0
	if step_length_curve:
		step_length_shape = step_length_curve.sample(leg_speed)

	var step_height_shape := 1.0
	if step_height_curve:
		step_height_shape = step_height_curve.sample(leg_speed)
	var forward_offset: float = _calc_forward_offset(stride, total_len, phase_rad) * stride_amplitude * step_length_shape
	var vertical_offset: float = _calc_vertical_offset(stride, total_len, phase_rad) * stride_amplitude * step_height_shape

	foot_target = hip_position + Vector2(0, max_reach)
	foot_target += lengthdir(forward_offset, move_rad)
	foot_target.y += vertical_offset

	var to_target = foot_target - hip_position
	if to_target.length() > max_reach:
		foot_target = hip_position + to_target.normalized() * (max_reach - TO_TARGET_EPSILON)

	_solve_leg_ik(hip_position, foot_target, max_reach, facing_rad)
	queue_redraw()

# --- Private Calculation Helpers ---


func _calc_stride(vel: float) -> float:
	return pow(vel * STRIDE_VEL_SCALE, STRIDE_EXP)

func _calc_forward_offset(stride: float, total_len: float, phase_rad: float) -> float:
	# Amplitude is handled by stride_amplitude_curve
	var offset = stride * (total_len / FORWARD_OFFSET_DIV) * sin(phase_rad)
	return offset

func _calc_vertical_offset(stride: float, total_len: float, phase_rad: float) -> float:
	# Amplitude is handled by stride_amplitude_curve
	return stride * (total_len / VERTICAL_OFFSET_DIV) * (-cos(phase_rad) + VERTICAL_OFFSET_SHIFT)

func _solve_leg_ik(hip_pos: Vector2, foot: Vector2, max_reach: float, facing_rad: float) -> void:
	var c_raw: float = hip_pos.distance_to(foot)
	var c: float = min(c_raw, max_reach)
	var alpha: float = hip_pos.angle_to_point(foot)
	foot_position = hip_pos + lengthdir(c, alpha)

	var cos_beta: float = clamp(
		(pow(thigh_length, 2) + pow(c, 2) - pow(calf_length, 2)) / (2.0 * thigh_length * c),
		-1.0, 1.0
	)
	var beta: float = acos(cos_beta)

	var knee_flat: Vector2 = hip_pos + lengthdir(thigh_length, alpha - beta)
	var ix: Vector2 = hip_pos + lengthdir(thigh_length * cos(beta), alpha)
	var knee_vec: Vector2 = knee_flat - ix
	var knee_vec_len := knee_vec.length()
	var knee_vec_dir := knee_vec / knee_vec_len if (knee_vec_len > KNEE_VEC_MIN_LEN) else Vector2.ZERO
	var knee_mod: float = cos(facing_rad)
	var bend_offset: Vector2 = knee_vec_dir * (knee_vec_len * knee_mod * bend_strength)
	knee_position = ix + knee_vec * (1.0 - foreshorten_strength) + bend_offset * foreshorten_strength
	

# --- Drawing (local space relative to node) ---
func _draw() -> void:

	# Draw sprites for thigh and calf if assigned
	_draw_leg_sprites()

	# Optionally draw debug info
	if not debug_draw:
		pass
	_draw_joints_and_target()
	if debug_labels:
		_draw_labels()

func _draw_bone_sprite(tex: Texture2D, A_global: Vector2, B_global: Vector2, orientation: SpriteOrientation) -> void:
	if tex == null:
		return

	var A = to_local(A_global)
	var B = to_local(B_global)

	var d = B - A
	var L = d.length()
	if L < 0.0001:
		return

	var angle = d.angle()
	var size = tex.get_size()

	var along_x := (orientation == SpriteOrientation.LEFT_RIGHT)

	var bone_scale: Vector2
	if along_x:
		bone_scale = Vector2(L / size.x, 1.0)
	else:
		bone_scale = Vector2(1.0, L / size.y)
	
	var rot = angle
	if not along_x:
		rot -= PI/2

	var tex_offset = Vector2.ZERO
	if along_x:
		tex_offset = Vector2(0, -size.y * 0.5)
	else:
		tex_offset = Vector2(-size.x * 0.5, 0)

	# ✅ Build transform in correct order: Scale → Rotate → Translate
	var xform = Transform2D()
	xform = xform.scaled(bone_scale)
	xform = xform.rotated(rot)
	xform = xform.translated(A)

	draw_set_transform_matrix(xform)
	draw_texture(tex, tex_offset)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	if debug_draw:
		draw_circle(A, 3, Color.YELLOW)
		draw_circle(B, 3, Color.CYAN)

func _draw_leg_sprites() -> void:
	# --- THIGH ---
	if thigh_sprite:
		_draw_bone_sprite(
			thigh_sprite,
			hip_position,
			knee_position,
			thigh_orientation
		)

	# --- CALF ---
	if calf_sprite:
		_draw_bone_sprite(
			calf_sprite,
			knee_position,
			foot_position,
			calf_orientation
		)


func _draw_bones() -> void:
	draw_line(to_local(hip_position), to_local(knee_position), Color(1, 1, 1), BONE_WIDTH)
	draw_line(to_local(knee_position), to_local(foot_position), Color(1, 1, 1), CALF_WIDTH)

func _draw_joints_and_target() -> void:
	# draw_circle(to_local(hip_position), HIP_RADIUS, Color.GREEN)
	# draw_circle(to_local(knee_position), KNEE_RADIUS, Color.hex(0xffaa00ff))
	# draw_circle(to_local(foot_position), FOOT_RADIUS, FOOT_COLOR)
	# draw_circle(to_local(foot_target), TARGET_RADIUS, TARGET_COLOR)
	#draw_line(to_local(hip_position), to_local(foot_target), Color(0.3, 0.3, 0.3), 1.0)
	pass
func _draw_labels() -> void:
	_draw_label(to_local(hip_position) + Vector2(6, -6), "HIP")
	_draw_label(to_local(knee_position) + Vector2(6, -6), "KNEE")
	_draw_label(to_local(foot_position) + Vector2(6, -6), "FOOT")
	_draw_label(to_local(foot_target) + Vector2(6, -6), "TARGET")

func _draw_label(pos: Vector2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12.0, Color.WHITE)
