class_name ZombieState
extends RefCounted

var position: Vector2
var hp: float
var max_hp: float
var speed: float
var damage: float
var type_id: String
var radius: float
var body_color: Color
var accent_color: Color
var xp_value: int
var behavior_timer := 0.0
var charge_timer := 0.0
var explosion_radius := 0.0
var explosion_damage := 0.0
var is_elite := false
var elite_rank := 0
var elite_title := ""
var dead := false


func _init(
	new_position: Vector2,
	new_hp: float,
	new_speed: float,
	new_damage: float,
	new_type_id: String,
	new_radius: float,
	new_body_color: Color,
	new_accent_color: Color,
	new_xp_value: int,
	new_explosion_radius := 0.0,
	new_explosion_damage := 0.0
) -> void:
	position = new_position
	hp = new_hp
	max_hp = new_hp
	speed = new_speed
	damage = new_damage
	type_id = new_type_id
	radius = new_radius
	body_color = new_body_color
	accent_color = new_accent_color
	xp_value = new_xp_value
	explosion_radius = new_explosion_radius
	explosion_damage = new_explosion_damage
