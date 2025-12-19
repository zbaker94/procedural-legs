extends Node2D

@export var character_root: CharacterRoot

@export var bounce_amplitude: float = 2.0
@export var wobble_degrees: float = 2.0

func _ready() -> void:
	if character_root == null or not character_root is CharacterRoot:
		push_error("Torso must have a valid CharacterRoot assigned.")

func _physics_process(_delta: float) -> void:
	var angle_deg: float
	if character_root and "facing_degrees" in character_root:
		angle_deg = character_root.facing_degrees
	else:
		return
	var angle_rad = deg_to_rad(angle_deg)
	var facing_vec = Vector2.RIGHT.rotated(angle_rad)
	var x_comp = abs(facing_vec.x)

	# Add bounce and rotation based on motion counter
	if character_root and "motion_counter_degrees" in character_root:
		var bounce_phase = deg_to_rad(character_root.motion_counter_degrees + 80) * 2.0
		var rotation_phase = deg_to_rad(character_root.motion_counter_degrees + 80)
		var bounce = sin(bounce_phase) * bounce_amplitude
		position.y = bounce
		rotation = sin(rotation_phase) * deg_to_rad(wobble_degrees)
