class_name XpOrbState
extends RefCounted

var position: Vector2
var value: int


func _init(new_position: Vector2, new_value: int) -> void:
	position = new_position
	value = new_value
