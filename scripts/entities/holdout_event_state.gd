class_name HoldoutEventState
extends RefCounted

var position: Vector2
var radius: float
var required_time: float
var lifetime: float
var progress := 0.0


func _init(new_position: Vector2, new_radius := 112.0, new_required_time := 20.0, new_lifetime := 90.0) -> void:
	position = new_position
	radius = new_radius
	required_time = new_required_time
	lifetime = new_lifetime


func update(delta: float, player_position: Vector2) -> void:
	lifetime -= delta
	if is_player_inside(player_position):
		progress = minf(progress + delta, required_time)
	else:
		progress = maxf(progress - delta * 0.35, 0.0)


func is_player_inside(player_position: Vector2) -> bool:
	return position.distance_squared_to(player_position) <= radius * radius


func is_complete() -> bool:
	return progress >= required_time


func is_expired() -> bool:
	return lifetime <= 0.0


func progress_ratio() -> float:
	if required_time <= 0.0:
		return 1.0
	return clampf(progress / required_time, 0.0, 1.0)
