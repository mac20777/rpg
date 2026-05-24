class_name MerchantEventState
extends RefCounted

var merchant_id: int
var position: Vector2
var radius: float
var lifetime: float
var offer_seed: int


func _init(
	new_merchant_id: int,
	new_position: Vector2,
	new_radius := 116.0,
	new_lifetime := 42.0,
	new_offer_seed := 0
) -> void:
	merchant_id = new_merchant_id
	position = new_position
	radius = new_radius
	lifetime = new_lifetime
	offer_seed = new_offer_seed


func is_player_inside(player_position: Vector2) -> bool:
	return position.distance_squared_to(player_position) <= radius * radius


func is_expired() -> bool:
	return lifetime <= 0.0
