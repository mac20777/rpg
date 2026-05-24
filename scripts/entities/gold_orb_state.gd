class_name GoldOrbState
extends RefCounted

var position: Vector2
var value: int
var lifetime: float


func _init(new_position: Vector2, new_value: int, new_lifetime := 45.0) -> void:
	position = new_position
	value = new_value
	lifetime = new_lifetime
