class_name SupplyCacheState
extends RefCounted

var position: Vector2
var kind: String
var radius: float
var lifetime: float


func _init(new_position: Vector2, new_kind: String, new_radius := 18.0, new_lifetime := 95.0) -> void:
	position = new_position
	kind = new_kind
	radius = new_radius
	lifetime = new_lifetime
