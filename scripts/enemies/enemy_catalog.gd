class_name EnemyCatalog
extends RefCounted

const ZombieStateResource := preload("res://scripts/entities/zombie_state.gd")

const NORMAL := "normal"
const RUSHER := "rusher"
const EXPLODER := "exploder"
const ELITE := "elite"

const NORMAL_RADIUS := 15.0
const RUSHER_RADIUS := 12.0
const EXPLODER_RADIUS := 17.0
const ELITE_RADIUS := 26.0

const RUSHER_UNLOCK_TIME := 45.0
const EXPLODER_UNLOCK_TIME := 90.0
const RUSHER_CHARGE_DURATION := 0.42
const RUSHER_CHARGE_SPEED_MULTIPLIER := 2.35


static func choose_type(rng: RandomNumberGenerator, elapsed: float, special_bias := 0.0) -> String:
	var normal_weight := 1.0
	var rusher_weight := 0.0
	var exploder_weight := 0.0
	if elapsed >= RUSHER_UNLOCK_TIME:
		rusher_weight = lerpf(0.14, 0.42, minf((elapsed - RUSHER_UNLOCK_TIME) / 180.0, 1.0))
	if elapsed >= EXPLODER_UNLOCK_TIME:
		exploder_weight = lerpf(0.08, 0.30, minf((elapsed - EXPLODER_UNLOCK_TIME) / 210.0, 1.0))

	rusher_weight += special_bias * 0.12
	exploder_weight += special_bias * 0.16
	var total_weight := normal_weight + rusher_weight + exploder_weight
	var roll := rng.randf() * total_weight
	if roll < exploder_weight:
		return EXPLODER
	roll -= exploder_weight
	if roll < rusher_weight:
		return RUSHER
	return NORMAL


static func radius_for(enemy_type: String) -> float:
	match enemy_type:
		RUSHER:
			return RUSHER_RADIUS
		EXPLODER:
			return EXPLODER_RADIUS
		ELITE:
			return ELITE_RADIUS
		_:
			return NORMAL_RADIUS


static func create_elite(rng: RandomNumberGenerator, position: Vector2, elapsed: float, rank: int):
	var scaling := 1.0 + elapsed / 220.0
	var zombie = ZombieStateResource.new(
		position,
		260.0 * scaling + float(rank - 1) * 80.0,
		rng.randf_range(72.0, 92.0) + elapsed * 0.045,
		22.0 + elapsed * 0.028,
		ELITE,
		ELITE_RADIUS,
		Color(0.78, 0.2, 0.16),
		Color(1.0, 0.78, 0.18),
		10 + rank * 2
	)
	zombie.is_elite = true
	zombie.elite_rank = rank
	zombie.elite_title = "腐化精英"
	return zombie


static func create_zombie(rng: RandomNumberGenerator, enemy_type: String, position: Vector2, elapsed: float):
	var scaling := 1.0 + elapsed / 240.0
	var zombie
	match enemy_type:
		RUSHER:
			zombie = ZombieStateResource.new(
				position,
				28.0 * scaling,
				rng.randf_range(138.0, 168.0) + elapsed * 0.1,
				12.0 + elapsed * 0.02,
				RUSHER,
				RUSHER_RADIUS,
				Color(0.86, 0.42, 0.16),
				Color(1.0, 0.9, 0.18),
				1
			)
			zombie.behavior_timer = rng.randf_range(0.7, 1.8)
			return zombie
		EXPLODER:
			return ZombieStateResource.new(
				position,
				40.0 * scaling,
				rng.randf_range(66.0, 88.0) + elapsed * 0.045,
				8.0 + elapsed * 0.012,
				EXPLODER,
				EXPLODER_RADIUS,
				Color(0.58, 0.34, 0.76),
				Color(1.0, 0.36, 0.24),
				2,
				92.0,
				28.0 + elapsed * 0.035
			)
		_:
			return ZombieStateResource.new(
				position,
				46.0 * scaling,
				rng.randf_range(82.0, 118.0) + elapsed * 0.08,
				16.0 + elapsed * 0.025,
				NORMAL,
				NORMAL_RADIUS,
				Color(0.42, 0.72, 0.28),
				Color(0.95, 0.12, 0.08),
				1
			)


static func update_behavior(zombie, delta: float, rng: RandomNumberGenerator) -> float:
	if zombie.type_id != RUSHER:
		return zombie.speed

	if zombie.charge_timer > 0.0:
		zombie.charge_timer -= delta
		return zombie.speed * RUSHER_CHARGE_SPEED_MULTIPLIER

	zombie.behavior_timer -= delta
	if zombie.behavior_timer <= 0.0:
		zombie.charge_timer = RUSHER_CHARGE_DURATION
		zombie.behavior_timer = rng.randf_range(1.25, 2.25)
		return zombie.speed * RUSHER_CHARGE_SPEED_MULTIPLIER
	return zombie.speed


static func is_exploder(zombie) -> bool:
	return zombie.type_id == EXPLODER
