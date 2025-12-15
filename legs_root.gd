class_name LegsRoot
extends Node2D

var character_root: CharacterRoot

func _ready():
	# Check parent is CharacterRoot
	var parent = get_parent()
	if parent == null or not parent is CharacterRoot:
		push_error("LegsRoot must be a child of CharacterRoot.")
	else:
		character_root = parent
	# Check for at least one Leg child
	var has_leg = false
	for child in get_children():
		if child is Leg:
			has_leg = true
			break
	if not has_leg:
		push_error("LegsRoot must have at least one Leg child.")
