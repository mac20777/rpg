extends RefCounted

const WeaponHelpers := preload("res://scripts/weapons/weapon_helpers.gd")

var weapon_id := "knife"
var title := "飞刀"
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
		_fire_shadow_knives(player, direction, bullets)
		return

	var damage: float = player.damage * (0.74 + float(level - 1) * 0.13)
	var pierce_left := 2 + level
	WeaponHelpers.spawn_bullet(
		bullets,
		player.position + direction * 24.0,
		direction,
		575.0 + float(level - 1) * 18.0,
		damage,
		1.7,
		5.8,
		pierce_left,
		Color(0.55, 0.88, 1.0)
	)


func cooldown(player) -> float:
	var reload_multiplier: float = clampf(player.fire_interval / 0.45, 0.45, 1.0)
	if evolved:
		return maxf(0.78 * reload_multiplier, 0.42)
	return maxf((1.25 - float(level - 1) * 0.07) * reload_multiplier, 0.62)


func can_upgrade() -> bool:
	return not evolved and level < max_level


func upgrade() -> void:
	level = mini(level + 1, max_level)


func upgrade_title() -> String:
	return "强化%s" % title


func upgrade_desc() -> String:
	return "提升飞刀伤害、穿透和发射频率"


func can_evolve() -> bool:
	return not evolved and level >= max_level


func evolve(new_evolution_id: String) -> void:
	evolved = true
	evolution_id = new_evolution_id
	title = "暗影飞刃"
	timer = 0.0


func _fire_shadow_knives(player, direction: Vector2, bullets: Array) -> void:
	for angle_offset in [-0.18, 0.0, 0.18]:
		var knife_direction := direction.rotated(angle_offset)
		WeaponHelpers.spawn_bullet(
			bullets,
			player.position + knife_direction * 25.0,
			knife_direction,
			690.0,
			player.damage * 1.18,
			1.9,
			5.8,
			8,
			Color(0.74, 0.48, 1.0)
		)
