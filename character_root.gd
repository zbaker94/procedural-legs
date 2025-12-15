class_name CharacterRoot
extends Node2D

@export var character_bus: CharacterBus


var velocity: Vector2
var facing_degrees: float
var motion_counter_degrees: float = 0.0
var leg_speed: float = 0.0

func _ready():
	var legs_root_count = 0
	for child in get_children():
		if child is LegsRoot:
			legs_root_count += 1
	if legs_root_count != 1:
		push_error(
			"CharacterRoot must have exactly one LegsRoot child. "
			+ "Found %d." % legs_root_count
		)
	

const MOTION_COUNTER_SPEED = 5.2
const MOTION_COUNTER_VEL_SCALE = 3.0
const MOTION_COUNTER_EXP = 0.4
const MOTION_COUNTER_MAX = 360.0

func _physics_process(_delta: float) -> void:
	velocity = character_bus.character_body.velocity
	# Cap velocity length for stability
	var max_velocity_length := 1.0
	if velocity.length() > max_velocity_length:
		velocity = velocity.normalized() * max_velocity_length
	facing_degrees = character_bus.character_facing.facing_degrees
	leg_speed = velocity.length()
	_update_motion_counter()

func _update_motion_counter() -> void:
	motion_counter_degrees += MOTION_COUNTER_SPEED * pow(leg_speed * MOTION_COUNTER_VEL_SCALE, MOTION_COUNTER_EXP)
	motion_counter_degrees = fmod(motion_counter_degrees, MOTION_COUNTER_MAX)
