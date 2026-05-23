class_name WeaponHelpers
extends RefCounted

const BulletStateResource := preload("res://scripts/entities/bullet_state.gd")


static func nearest_zombie(origin: Vector2, zombies: Array):
	var best = null
	var best_distance := INF
	for zombie in zombies:
		if zombie.dead:
			continue
		var distance := origin.distance_squared_to(zombie.position)
		if distance < best_distance:
			best_distance = distance
			best = zombie
	return best


static func direction_to_target(player, target) -> Vector2:
	var direction: Vector2 = target.position - player.position
	if direction.length_squared() <= 0.0:
		return player.aim_direction
	return direction.normalized()


static func spawn_bullet(
	bullets: Array,
	position: Vector2,
	direction: Vector2,
	speed: float,
	damage: float,
	lifetime: float,
	radius: float,
	pierce_left: int,
	color: Color
) -> void:
	if direction.length_squared() <= 0.0:
		return
	bullets.append(BulletStateResource.new(position, direction.normalized() * speed, damage, lifetime, radius, pierce_left, color))
