class_name BulletState
extends RefCounted

var position: Vector2
var velocity: Vector2
var damage: float
var lifetime: float
var radius: float
var pierce_left: int
var color: Color
var split_depth: int
var is_critical := false
var hit_target_ids := {}


func _init(
	new_position: Vector2,
	new_velocity: Vector2,
	new_damage: float,
	new_lifetime: float,
	new_radius := 4.0,
	new_pierce_left := 0,
	new_color := Color(1.0, 0.86, 0.35),
	new_split_depth := 0
) -> void:
	position = new_position
	velocity = new_velocity
	damage = new_damage
	lifetime = new_lifetime
	radius = new_radius
	pierce_left = new_pierce_left
	color = new_color
	split_depth = new_split_depth


func has_hit(target) -> bool:
	return hit_target_ids.has(target.get_instance_id())


func register_hit(target) -> void:
	hit_target_ids[target.get_instance_id()] = true


func should_remove_after_hit() -> bool:
	if pierce_left <= 0:
		return true
	pierce_left -= 1
	return false
