class_name RelicCollection
extends RefCounted

const BulletStateResource := preload("res://scripts/entities/bullet_state.gd")

const SPLINTER_ROUNDS := "splinter_rounds"
const FIFTH_SHOT_CRIT := "fifth_shot_crit"
const XP_LEECH := "xp_leech"
const LAST_STAND := "last_stand"
const VOLATILE_CORE := "volatile_core"

var owned := {}
var shot_counter := 0


func reset() -> void:
	owned.clear()
	shot_counter = 0


func add(relic_id: String) -> bool:
	if has(relic_id):
		return false
	owned[relic_id] = true
	return true


func has(relic_id: String) -> bool:
	return owned.has(relic_id)


func status_text() -> String:
	if owned.is_empty():
		return "无"
	var titles := []
	for relic_id in owned.keys():
		titles.append(title_for(relic_id))
	return " / ".join(titles)


func prepare_new_bullets(bullets: Array, start_index: int) -> void:
	if not has(FIFTH_SHOT_CRIT):
		return
	for bullet_index in range(start_index, bullets.size()):
		var bullet: BulletState = bullets[bullet_index]
		shot_counter += 1
		if shot_counter % 5 != 0:
			continue
		bullet.damage *= 2.0
		bullet.radius += 1.2
		bullet.color = Color(1.0, 0.2, 0.16)
		bullet.is_critical = true


func damage_for_hit(base_damage: float, player) -> float:
	var damage := base_damage
	if has(LAST_STAND):
		var hp_ratio := clampf(player.hp / player.max_hp, 0.0, 1.0)
		damage *= lerpf(1.45, 1.0, hp_ratio)
	return damage


func on_bullet_hit(bullet: BulletState, hit_position: Vector2, bullets: Array, rng: RandomNumberGenerator) -> void:
	if not has(SPLINTER_ROUNDS):
		return
	if bullet.split_depth > 0 or rng.randf() > 0.18:
		return
	var direction := bullet.velocity.normalized()
	if direction.length_squared() <= 0.0:
		return
	for angle in [-0.62, 0.62]:
		var split_direction := direction.rotated(angle)
		bullets.append(BulletStateResource.new(
			hit_position + split_direction * 6.0,
			split_direction * 520.0,
			bullet.damage * 0.45,
			0.55,
			maxf(bullet.radius * 0.75, 2.8),
			0,
			Color(0.7, 1.0, 0.62),
			bullet.split_depth + 1
		))


func heal_on_xp_pickup(xp_value: int) -> float:
	if not has(XP_LEECH):
		return 0.0
	return float(xp_value) * 0.75


func should_empower_exploder_kill() -> bool:
	return has(VOLATILE_CORE)


func exploder_blast_radius_multiplier() -> float:
	return 1.35 if has(VOLATILE_CORE) else 1.0


func exploder_blast_damage_multiplier() -> float:
	return 1.2 if has(VOLATILE_CORE) else 1.0


func title_for(relic_id: String) -> String:
	match relic_id:
		SPLINTER_ROUNDS:
			return "分裂弹头"
		FIFTH_SHOT_CRIT:
			return "第五发"
		XP_LEECH:
			return "汲取晶体"
		LAST_STAND:
			return "背水契约"
		VOLATILE_CORE:
			return "爆裂核心"
		_:
			return relic_id
