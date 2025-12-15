extends CharacterBody2D

# Movement speed in pixels per second

@export var acceleration: float = 12.0
@export var friction: float = 9.0

func _physics_process(delta):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if input_vector.length() > 0:
		velocity = velocity.move_toward(input_vector, acceleration * delta).normalized()
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	print("input_vector: ", input_vector, " velocity: ", velocity)
	move_and_slide()
