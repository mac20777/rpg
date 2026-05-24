class_name GoldDropPolicy
extends RefCounted

const SOFT_ORB_CAP := 80
const HARD_ORB_CAP := 120
const ELITE_MIN := 25
const ELITE_MAX := 40
const CHEST_REWARD := 20
const HOLDOUT_REWARD := 35

var budget_window_timer := 0.0
var budget_remaining := 24


func reset() -> void:
	budget_window_timer = 0.0
	budget_remaining = budget_for_elapsed(0.0)


func update(delta: float, elapsed: float) -> void:
	budget_window_timer -= delta
	if budget_window_timer > 0.0:
		return
	budget_window_timer = 60.0
	budget_remaining = budget_for_elapsed(elapsed)


func budget_for_elapsed(value: float) -> int:
	if value < 180.0:
		return 24
	if value < 360.0:
		return 36
	if value < 600.0:
		return 48
	return 60


func roll_drop_value(enemy_type: String, active_orb_count: int, rng: RandomNumberGenerator) -> int:
	if active_orb_count >= HARD_ORB_CAP or budget_remaining <= 0:
		return 0
	var drop_chance := 0.08
	var gold_value := 2
	match enemy_type:
		"rusher":
			drop_chance = 0.12
			gold_value = 3
		"exploder":
			drop_chance = 0.14
			gold_value = 4
	if active_orb_count >= SOFT_ORB_CAP:
		drop_chance *= 0.35
	if rng.randf() > drop_chance:
		return 0
	gold_value = mini(gold_value, budget_remaining)
	if gold_value <= 0:
		return 0
	budget_remaining -= gold_value
	return gold_value


func serialize() -> Dictionary:
	return {
		"budget_remaining": budget_remaining,
		"budget_window_timer": budget_window_timer
	}


func apply_snapshot(raw_data) -> void:
	if not (raw_data is Dictionary):
		return
	budget_remaining = int(raw_data.get("budget_remaining", budget_remaining))
	budget_window_timer = float(raw_data.get("budget_window_timer", budget_window_timer))
