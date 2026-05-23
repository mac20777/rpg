class_name RewardChestState
extends RefCounted

var position: Vector2
var radius: float


func _init(new_position: Vector2, new_radius := 18.0) -> void:
	position = new_position
	radius = new_radius
