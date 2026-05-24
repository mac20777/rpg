class_name MapEventDirector
extends RefCounted

const SUPPLY_HEAL := "heal"
const SUPPLY_MAGNET := "magnet"
const SUPPLY_BOMB := "bomb"

const FIRST_SUPPLY_TIME := 18.0
const MIN_SUPPLY_INTERVAL := 34.0
const MAX_SUPPLY_INTERVAL := 46.0
const MAX_ACTIVE_SUPPLIES := 3

const FIRST_HOLDOUT_TIME := 82.0
const MIN_HOLDOUT_INTERVAL := 108.0
const MAX_HOLDOUT_INTERVAL := 136.0
const MAX_ACTIVE_HOLDOUTS := 1

const FIRST_MERCHANT_TIME := 150.0
const MIN_MERCHANT_INTERVAL := 180.0
const MAX_MERCHANT_INTERVAL := 240.0
const MAX_ACTIVE_MERCHANTS := 1

var supply_timer := 0.0
var holdout_timer := 0.0
var merchant_timer := 0.0


func _init() -> void:
	reset()


func reset() -> void:
	supply_timer = FIRST_SUPPLY_TIME
	holdout_timer = FIRST_HOLDOUT_TIME
	merchant_timer = FIRST_MERCHANT_TIME


func update(
	delta: float,
	active_supply_count: int,
	active_holdout_count: int,
	active_merchant_count: int,
	hp_ratio: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var requests := {"supplies": [], "holdout": false, "merchant": false}

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

	if active_merchant_count < MAX_ACTIVE_MERCHANTS:
		merchant_timer -= delta
		if merchant_timer <= 0.0:
			requests["merchant"] = true
			merchant_timer = rng.randf_range(MIN_MERCHANT_INTERVAL, MAX_MERCHANT_INTERVAL)

	return requests


func _choose_supply_kind(hp_ratio: float, rng: RandomNumberGenerator) -> String:
	var heal_weight := 0.65
	var magnet_weight := 1.05
	var bomb_weight := 0.9
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
