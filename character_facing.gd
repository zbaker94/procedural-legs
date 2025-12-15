class_name CharacterFacing

extends Node

@export var character_body: CharacterBody2D

var facing_degrees: float

func _physics_process(_delta: float) -> void:
	if character_body and character_body.velocity.length() > 0:
		var current_rads = deg_to_rad(facing_degrees)
		var desired_rads = character_body.velocity.angle()
		facing_degrees = rad_to_deg(lerp_angle(current_rads, desired_rads, 0.1))
	
