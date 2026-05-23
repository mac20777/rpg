extends RefCounted

const WeaponHelpers := preload("res://scripts/weapons/weapon_helpers.gd")

var weapon_id := "shotgun"
var title := "霰弹"
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
	var pellet_count := 9 if evolved else 4 + level
	var spread: float = deg_to_rad(30.0 if evolved else 42.0)
	var damage: float = player.damage * (0.58 + float(level - 1) * 0.06) if evolved else player.damage * (0.42 + float(level - 1) * 0.05)
	var pierce_left := 2 if evolved else 0
	var pellet_color := Color(0.85, 0.92, 1.0) if evolved else Color(1.0, 0.55, 0.18)
	for pellet_index in range(pellet_count):
		var weight: float = 0.5 if pellet_count <= 1 else float(pellet_index) / float(pellet_count - 1)
		var angle_offset: float = lerpf(-spread * 0.5, spread * 0.5, weight) + rng.randf_range(-0.035, 0.035)
		var pellet_direction: Vector2 = direction.rotated(angle_offset)
		WeaponHelpers.spawn_bullet(
			bullets,
			player.position + pellet_direction * 22.0,
			pellet_direction,
			625.0,
			damage,
			0.72 if evolved else 0.55,
			4.2 if evolved else 3.4,
			pierce_left,
			pellet_color
		)


func cooldown(player) -> float:
	var reload_multiplier: float = clampf(player.fire_interval / 0.45, 0.45, 1.0)
	if evolved:
		return maxf(1.08 * reload_multiplier, 0.62)
	return maxf((1.55 - float(level - 1) * 0.09) * reload_multiplier, 0.72)


func can_upgrade() -> bool:
	return not evolved and level < max_level


func upgrade() -> void:
	level = mini(level + 1, max_level)


func upgrade_title() -> String:
	return "强化%s" % title


func upgrade_desc() -> String:
	return "增加霰弹数量、伤害与发射频率"


func can_evolve() -> bool:
	return not evolved and level >= max_level


func evolve(new_evolution_id: String) -> void:
	evolved = true
	evolution_id = new_evolution_id
	title = "穿甲霰弹"
	timer = 0.0
