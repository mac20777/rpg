class_name VisualEffectState
extends RefCounted

var position: Vector2
var color: Color
var lifetime: float
var max_lifetime: float
var start_radius: float
var end_radius: float
var kind: String


func _init(
	new_position: Vector2,
	new_color: Color,
	new_lifetime: float,
	new_start_radius: float,
	new_end_radius: float,
	new_kind := "ring"
) -> void:
	position = new_position
	color = new_color
	lifetime = new_lifetime
	max_lifetime = new_lifetime
	start_radius = new_start_radius
	end_radius = new_end_radius
	kind = new_kind
