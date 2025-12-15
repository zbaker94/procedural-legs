extends Node2D

@export var character_root: CharacterRoot
@export var min_x_scale: float = 0.1
@export var max_x_scale: float = 1.0

@export var bounce_amplitude: float = 2.0
@export var wobble_degrees: float = 2.0

@export var debug_draw: bool = true
@export var torso_width: float = 20.0
@export var torso_height: float = 50.0

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
	# Map x_comp from [-1, 1] to [min_x_scale, max_x_scale] using remap
	scale.x = remap(x_comp, 0, 1.0, max_x_scale, min_x_scale)

	# Add bounce and rotation based on motion counter
	if character_root and "motion_counter_degrees" in character_root:
		var bounce_phase = deg_to_rad(character_root.motion_counter_degrees + 90) * 2.0
		var rotation_phase = deg_to_rad(character_root.motion_counter_degrees + 90)
		var bounce = sin(bounce_phase) * bounce_amplitude
		position.y = bounce
		rotation = sin(rotation_phase) * deg_to_rad(wobble_degrees)

	if debug_draw:
		queue_redraw()

func _draw() -> void:
	if not debug_draw:
		return
	# Draw a rectangle with its bottom middle at (0,0)
	var rect = Rect2(Vector2(-torso_width/2, -torso_height + 2), Vector2(torso_width, torso_height))
	draw_rect(rect, Color.WHITE, true)
