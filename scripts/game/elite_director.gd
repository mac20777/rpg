class_name EliteDirector
extends RefCounted

const FIRST_SPAWN_TIME := 150.0
const MIN_RESPAWN_INTERVAL := 78.0
const MAX_RESPAWN_INTERVAL := 98.0
const MAX_ACTIVE_ELITES := 1

var spawn_timer := 0.0
var next_rank := 1


func reset() -> void:
	spawn_timer = FIRST_SPAWN_TIME
	next_rank = 1


func update(delta: float, active_elite_count: int, rng: RandomNumberGenerator) -> int:
	if active_elite_count >= MAX_ACTIVE_ELITES:
		return 0

	spawn_timer -= delta
	if spawn_timer > 0.0:
		return 0

	var rank := next_rank
	next_rank += 1
	spawn_timer = rng.randf_range(MIN_RESPAWN_INTERVAL, MAX_RESPAWN_INTERVAL)
	return rank
