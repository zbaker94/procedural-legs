class_name Hip

extends Node2D


@export var character_root: CharacterRoot

var baseline_x: float

func _ready() -> void:
	baseline_x = position.x
	if character_root == null or not character_root is CharacterRoot:
		push_error("Hip must have a valid CharacterRoot assigned.")

func _physics_process(_delta: float) -> void:
	var angle_deg: float
	if character_root and "facing_degrees" in character_root:
		angle_deg = character_root.facing_degrees
	else:
		return
	var angle_rad = deg_to_rad(angle_deg)
	var facing_vec = Vector2.RIGHT.rotated(angle_rad)
	var x_comp = abs(facing_vec.x)
	# Move x from baseline_x (when x_comp=0) to 0 (when x_comp=1)
	position.x = lerp(baseline_x, 0.0, x_comp)
