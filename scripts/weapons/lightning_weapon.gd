extends RefCounted

const WeaponHelpers := preload("res://scripts/weapons/weapon_helpers.gd")

var weapon_id := "lightning"
var title := "电弧"
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


func fire(player, target, bullets: Array, rng: RandomNumberGenerator) -> void:
	var direction: Vector2 = WeaponHelpers.direction_to_target(player, target)
	direction = direction.rotated(rng.randf_range(-0.04, 0.04))
	player.set_aim_direction(direction)
	if evolved:
		_fire_magnetic_storm(player, direction, bullets)
		return

	var damage: float = player.damage * (0.66 + float(level - 1) * 0.12)
	var pierce_left := 3 + level
	WeaponHelpers.spawn_bullet(
		bullets,
		player.position + direction * 25.0,
		direction,
		980.0,
		damage,
		0.82,
		4.6,
		pierce_left,
		Color(0.34, 0.92, 1.0)
	)


func cooldown(player) -> float:
	var reload_multiplier: float = clampf(player.fire_interval / 0.45, 0.45, 1.0)
	if evolved:
		return maxf(0.82 * reload_multiplier, 0.42)
	return maxf((1.24 - float(level - 1) * 0.07) * reload_multiplier, 0.58)


func can_upgrade() -> bool:
	return not evolved and level < max_level


func upgrade() -> void:
	level = mini(level + 1, max_level)


func upgrade_title() -> String:
	return "强化%s" % title


func upgrade_desc() -> String:
	return "提升电弧伤害、穿透和发射频率"


func can_evolve() -> bool:
	return not evolved and level >= max_level


func evolve(new_evolution_id: String) -> void:
	evolved = true
	evolution_id = new_evolution_id
	title = "磁暴场"
	timer = 0.0


func _fire_magnetic_storm(player, direction: Vector2, bullets: Array) -> void:
	for angle_offset in [-0.28, -0.14, 0.0, 0.14, 0.28]:
		var arc_direction := direction.rotated(angle_offset)
		WeaponHelpers.spawn_bullet(
			bullets,
			player.position + arc_direction * 26.0,
			arc_direction,
			1050.0,
			player.damage * 0.72,
			0.9,
			4.9,
			8,
			Color(0.46, 1.0, 0.96)
		)
