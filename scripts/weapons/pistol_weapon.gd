extends RefCounted

const WeaponHelpers := preload("res://scripts/weapons/weapon_helpers.gd")

var weapon_id := "pistol"
var title := "手枪"
var level := 1
var max_level := 5
var timer := 0.0
var evolved := false
var evolution_id := ""


func _init() -> void:
	reset()


func reset() -> void:
	timer = 0.0


func update(delta: float, player, zombies: Array, bullets: Array, rng: RandomNumberGenerator) -> void:
	timer -= delta
	if timer > 0.0 or zombies.is_empty():
		return
	var target = WeaponHelpers.nearest_zombie(player.position, zombies)
	if target == null:
		return
	fire(player, target, bullets, rng)
	timer = cooldown(player)


func fire(player, target, bullets: Array, _rng: RandomNumberGenerator) -> void:
	var direction: Vector2 = WeaponHelpers.direction_to_target(player, target)
	player.set_aim_direction(direction)
	if evolved:
		_fire_gatling(player, direction, bullets)
		return

	var damage: float = player.damage * (1.0 + float(level - 1) * 0.18)
	var speed: float = 720.0 + float(level - 1) * 25.0
	WeaponHelpers.spawn_bullet(
		bullets,
		player.position + direction * 22.0,
		direction,
		speed,
		damage,
		1.25,
		4.0,
		0,
		Color(1.0, 0.86, 0.35)
	)


func cooldown(player) -> float:
	if evolved:
		return maxf(player.fire_interval * 0.32, 0.06)
	return maxf(player.fire_interval * pow(0.92, level - 1), 0.1)


func can_upgrade() -> bool:
	return not evolved and level < max_level


func upgrade() -> void:
	level = mini(level + 1, max_level)


func upgrade_title() -> String:
	return "强化%s" % title


func upgrade_desc() -> String:
	return "提升手枪伤害与射击频率"


func can_evolve() -> bool:
	return not evolved and level >= max_level


func evolve(new_evolution_id: String) -> void:
	evolved = true
	evolution_id = new_evolution_id
	title = "加特林"
	timer = 0.0


func _fire_gatling(player, direction: Vector2, bullets: Array) -> void:
	WeaponHelpers.spawn_bullet(
		bullets,
		player.position + direction * 24.0,
		direction,
		920.0,
		player.damage * 0.82,
		1.05,
		3.6,
		0,
		Color(1.0, 0.74, 0.22)
	)
