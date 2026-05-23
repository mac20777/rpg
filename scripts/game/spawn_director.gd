class_name SpawnDirector
extends RefCounted

const EnemyCatalog := preload("res://scripts/enemies/enemy_catalog.gd")

const TICK := 0.75
const MAX_COMMON_ZOMBIES := 160
const MIN_TARGET_ZOMBIES := 22
const MAX_TARGET_ZOMBIES := 135
const MAX_SPAWNS_PER_TICK := 8
const MAX_SPAWN_BUDGET_BANK := 16.0
const MINOR_WAVE_INTERVAL := 30.0
const MAJOR_WAVE_INTERVAL := 120.0
const CLEANUP_INTERVAL := 2.0
const FAR_REPOSITION_DISTANCE := 1400.0
const FAR_REPOSITION_DISTANCE_SQ := FAR_REPOSITION_DISTANCE * FAR_REPOSITION_DISTANCE

var spawn_timer := 0.0
var spawn_budget := 0.0
var minor_wave_timer := 0.0
var major_wave_timer := 0.0
var cleanup_timer := 0.0
var wave_index := 0


func _init() -> void:
	reset()


func reset() -> void:
	spawn_timer = 0.25
	spawn_budget = 0.0
	minor_wave_timer = MINOR_WAVE_INTERVAL
	major_wave_timer = MAJOR_WAVE_INTERVAL
	cleanup_timer = CLEANUP_INTERVAL
	wave_index = 0


func update(delta: float, elapsed: float, current_count: int, rng: RandomNumberGenerator) -> Array[String]:
	var spawn_requests: Array[String] = []
	minor_wave_timer -= delta
	major_wave_timer -= delta

	if minor_wave_timer <= 0.0:
		minor_wave_timer += MINOR_WAVE_INTERVAL
		wave_index += 1
		_append_wave(spawn_requests, _minor_wave_size(), elapsed, rng, 0.35, current_count)

	if major_wave_timer <= 0.0:
		major_wave_timer += MAJOR_WAVE_INTERVAL
		_append_wave(spawn_requests, _major_wave_size(elapsed), elapsed, rng, 0.75, current_count)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = TICK
		_append_budget_spawns(spawn_requests, elapsed, current_count, rng)

	return spawn_requests


func should_cleanup(delta: float) -> bool:
	cleanup_timer -= delta
	if cleanup_timer > 0.0:
		return false
	cleanup_timer = CLEANUP_INTERVAL
	return true


func _append_wave(spawn_requests: Array[String], count: int, elapsed: float, rng: RandomNumberGenerator, special_bias: float, current_count: int) -> void:
	var spawn_room := MAX_COMMON_ZOMBIES - current_count - spawn_requests.size()
	if spawn_room <= 0:
		return
	for i in range(mini(count, spawn_room)):
		spawn_requests.append(EnemyCatalog.choose_type(rng, elapsed, special_bias))


func _append_budget_spawns(spawn_requests: Array[String], elapsed: float, current_count: int, rng: RandomNumberGenerator) -> void:
	var spawn_room := mini(_target_zombie_count(elapsed) - current_count - spawn_requests.size(), MAX_COMMON_ZOMBIES - current_count - spawn_requests.size())
	if spawn_room <= 0:
		spawn_budget = minf(spawn_budget, MAX_SPAWN_BUDGET_BANK)
		return

	spawn_budget = minf(spawn_budget + _spawn_budget_per_tick(elapsed), MAX_SPAWN_BUDGET_BANK)
	var spawn_count := mini(int(spawn_budget), spawn_room)
	spawn_count = mini(spawn_count, MAX_SPAWNS_PER_TICK)
	if spawn_count <= 0:
		return

	spawn_budget -= float(spawn_count)
	for i in range(spawn_count):
		spawn_requests.append(EnemyCatalog.choose_type(rng, elapsed))


func _target_zombie_count(elapsed: float) -> int:
	var pressure := minf(elapsed / 300.0, 1.0)
	return roundi(lerpf(MIN_TARGET_ZOMBIES, MAX_TARGET_ZOMBIES, pressure))


func _spawn_budget_per_tick(elapsed: float) -> float:
	var pressure := minf(elapsed / 300.0, 1.0)
	return lerpf(0.9, 3.2, pressure)


func _minor_wave_size() -> int:
	return mini(6 + wave_index * 2, 22)


func _major_wave_size(elapsed: float) -> int:
	return mini(18 + int(elapsed / MAJOR_WAVE_INTERVAL) * 6, 42)
