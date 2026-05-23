class_name MapEventDirector
extends RefCounted

const SUPPLY_HEAL := "heal"
const SUPPLY_MAGNET := "magnet"
const SUPPLY_BOMB := "bomb"

const FIRST_SUPPLY_TIME := 28.0
const MIN_SUPPLY_INTERVAL := 42.0
const MAX_SUPPLY_INTERVAL := 58.0
const MAX_ACTIVE_SUPPLIES := 3

const FIRST_HOLDOUT_TIME := 95.0
const MIN_HOLDOUT_INTERVAL := 120.0
const MAX_HOLDOUT_INTERVAL := 150.0
const MAX_ACTIVE_HOLDOUTS := 1

var supply_timer := 0.0
var holdout_timer := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	supply_timer = FIRST_SUPPLY_TIME
	holdout_timer = FIRST_HOLDOUT_TIME


func update(delta: float, active_supply_count: int, active_holdout_count: int, hp_ratio: float, rng: RandomNumberGenerator) -> Dictionary:
	var requests := {"supplies": [], "holdout": false}

	if active_supply_count < MAX_ACTIVE_SUPPLIES:
		supply_timer -= delta
		if supply_timer <= 0.0:
			requests["supplies"].append(_choose_supply_kind(hp_ratio, rng))
			supply_timer = rng.randf_range(MIN_SUPPLY_INTERVAL, MAX_SUPPLY_INTERVAL)

	if active_holdout_count < MAX_ACTIVE_HOLDOUTS:
		holdout_timer -= delta
		if holdout_timer <= 0.0:
			requests["holdout"] = true
			holdout_timer = rng.randf_range(MIN_HOLDOUT_INTERVAL, MAX_HOLDOUT_INTERVAL)

	return requests


func _choose_supply_kind(hp_ratio: float, rng: RandomNumberGenerator) -> String:
	var heal_weight := 0.75
	var magnet_weight := 0.85
	var bomb_weight := 0.7
	if hp_ratio < 0.45:
		heal_weight += 0.9
	var total_weight := heal_weight + magnet_weight + bomb_weight
	var roll := rng.randf() * total_weight
	if roll < heal_weight:
		return SUPPLY_HEAL
	roll -= heal_weight
	if roll < magnet_weight:
		return SUPPLY_MAGNET
	return SUPPLY_BOMB
