extends RefCounted

const WeaponHelpers := preload("res://scripts/weapons/weapon_helpers.gd")

var weapon_id := "flame"
var title := "火球"
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
	player.set_aim_direction(direction)
	if evolved:
		_fire_meteor_barrage(player, direction, bullets, rng)
		return

	var damage: float = player.damage * (1.12 + float(level - 1) * 0.2)
	var radius: float = 7.5 + float(level - 1) * 0.65
	var pierce_left := 1 + int(level >= 4)
	WeaponHelpers.spawn_bullet(
		bullets,
		player.position + direction * 26.0,
		direction,
		430.0 + float(level - 1) * 18.0,
		damage,
		1.55,
		radius,
		pierce_left,
		Color(1.0, 0.38, 0.12)
	)


func cooldown(player) -> float:
	var reload_multiplier: float = clampf(player.fire_interval / 0.45, 0.45, 1.0)
	if evolved:
		return maxf(1.08 * reload_multiplier, 0.66)
	return maxf((1.72 - float(level - 1) * 0.1) * reload_multiplier, 0.82)


func can_upgrade() -> bool:
	return not evolved and level < max_level


func upgrade() -> void:
	level = mini(level + 1, max_level)


func upgrade_title() -> String:
	return "强化%s" % title


func upgrade_desc() -> String:
	return "提升火球伤害、体积、穿透和发射频率"


func can_evolve() -> bool:
	return not evolved and level >= max_level


func evolve(new_evolution_id: String) -> void:
	evolved = true
	evolution_id = new_evolution_id
	title = "陨石雨"
	timer = 0.0


func _fire_meteor_barrage(player, direction: Vector2, bullets: Array, rng: RandomNumberGenerator) -> void:
	for angle_offset in [-0.18, 0.0, 0.18]:
		var fire_direction := direction.rotated(angle_offset + rng.randf_range(-0.035, 0.035))
		WeaponHelpers.spawn_bullet(
			bullets,
			player.position + fire_direction * 28.0,
			fire_direction,
			500.0,
			player.damage * 1.35,
			1.75,
			9.6,
			3,
			Color(1.0, 0.25, 0.08)
		)
