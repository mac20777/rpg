class_name UpgradeState
extends RefCounted

var passive_levels := {}


func reset() -> void:
	passive_levels.clear()


func get_passive_level(upgrade_id: String) -> int:
	return int(passive_levels.get(upgrade_id, 0))


func can_upgrade_passive(upgrade: Dictionary) -> bool:
	var upgrade_id: String = upgrade.get("id", "")
	var max_level := int(upgrade.get("max_level", 1))
	return get_passive_level(upgrade_id) < max_level


func apply_passive(upgrade: Dictionary) -> bool:
	if not can_upgrade_passive(upgrade):
		return false
	var upgrade_id: String = upgrade.get("id", "")
	passive_levels[upgrade_id] = get_passive_level(upgrade_id) + 1
	return true
