class_name UpgradeCatalog
extends RefCounted

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const REWARD_LEVEL := "level"
const REWARD_CHEST := "chest"

const FALLBACK_UPGRADE := {
	"id": "field_medicine",
	"type": "heal",
	"rarity": RARITY_COMMON,
	"title": "战地急救",
	"desc": "立即回复 30 生命",
	"max_level": 999
}

const PASSIVE_UPGRADES := [
	{
		"id": "damage",
		"type": "passive",
		"rarity": RARITY_COMMON,
		"title": "火力强化",
		"desc": "伤害 +20%",
		"stat": "damage",
		"max_level": 8
	},
	{
		"id": "fire_rate",
		"type": "passive",
		"rarity": RARITY_COMMON,
		"title": "快速装填",
		"desc": "射击间隔 -15%",
		"stat": "fire_rate",
		"max_level": 7
	},
	{
		"id": "speed",
		"type": "passive",
		"rarity": RARITY_COMMON,
		"title": "轻装上阵",
		"desc": "移动速度 +24",
		"stat": "speed",
		"max_level": 6
	},
	{
		"id": "pickup",
		"type": "passive",
		"rarity": RARITY_UNCOMMON,
		"title": "磁力背包",
		"desc": "拾取范围 +35",
		"stat": "pickup",
		"max_level": 5
	},
	{
		"id": "health",
		"type": "passive",
		"rarity": RARITY_UNCOMMON,
		"title": "止痛针",
		"desc": "最大生命 +20 并治疗",
		"stat": "health",
		"max_level": 6
	}
]

const RELIC_UPGRADES := [
	{
		"id": "splinter_rounds",
		"type": "relic",
		"rarity": RARITY_UNCOMMON,
		"title": "分裂弹头",
		"desc": "子弹命中时有概率分裂成两枚小弹",
		"max_level": 1,
		"requires": {"level": 3}
	},
	{
		"id": "fifth_shot_crit",
		"type": "relic",
		"rarity": RARITY_UNCOMMON,
		"title": "第五发",
		"desc": "每第 5 枚子弹造成双倍伤害",
		"max_level": 1,
		"requires": {"level": 3}
	},
	{
		"id": "xp_leech",
		"type": "relic",
		"rarity": RARITY_UNCOMMON,
		"title": "汲取晶体",
		"desc": "拾取经验时回复少量生命",
		"max_level": 1,
		"requires": {"level": 2}
	},
	{
		"id": "last_stand",
		"type": "relic",
		"rarity": RARITY_RARE,
		"title": "背水契约",
		"desc": "生命越低，造成的伤害越高",
		"max_level": 1,
		"requires": {"level": 5}
	},
	{
		"id": "volatile_core",
		"type": "relic",
		"rarity": RARITY_RARE,
		"title": "爆裂核心",
		"desc": "击杀爆炸者会引发更大的安全爆炸",
		"max_level": 1,
		"requires": {"elapsed": 90.0}
	}
]


static func roll_choices(
	rng: RandomNumberGenerator,
	weapon_loadout,
	upgrade_state,
	relics,
	player_level: int,
	elapsed: float,
	count := 3,
	reward_source := REWARD_LEVEL
) -> Array:
	var options := _collect_valid_options(weapon_loadout, upgrade_state, relics, player_level, elapsed)
	if options.is_empty():
		options.append(FALLBACK_UPGRADE.duplicate(true))
	var selected := []
	while selected.size() < count and not options.is_empty():
		var option_index := _weighted_option_index(rng, options, player_level, elapsed, reward_source)
		selected.append(options[option_index])
		options.remove_at(option_index)
	return selected


static func roll_chest_choices(
	rng: RandomNumberGenerator,
	weapon_loadout,
	upgrade_state,
	relics,
	player_level: int,
	elapsed: float,
	count := 3
) -> Array:
	return roll_choices(rng, weapon_loadout, upgrade_state, relics, player_level, elapsed, count, REWARD_CHEST)


static func apply_upgrade(upgrade: Dictionary, player, weapon_loadout, upgrade_state, relics) -> bool:
	var upgrade_type: String = upgrade.get("type", "")
	match upgrade_type:
		"passive":
			if not upgrade_state.apply_passive(upgrade):
				return false
			player.apply_upgrade(String(upgrade.get("stat", "")))
			return true
		"weapon_add", "weapon_level":
			return weapon_loadout.apply_upgrade(upgrade)
		"weapon_evolve":
			return weapon_loadout.apply_upgrade(upgrade)
		"relic":
			return relics.add(String(upgrade.get("id", "")))
		"heal":
			player.heal(30.0)
			return true
	return false


static func rarity_label(rarity: String) -> String:
	match rarity:
		RARITY_UNCOMMON:
			return "优秀"
		RARITY_RARE:
			return "稀有"
		_:
			return "普通"


static func _collect_valid_options(weapon_loadout, upgrade_state, relics, player_level: int, elapsed: float) -> Array:
	var options := []
	for passive_upgrade in PASSIVE_UPGRADES:
		var option: Dictionary = passive_upgrade.duplicate(true)
		if upgrade_state.can_upgrade_passive(option) and _requirements_met(option, weapon_loadout, upgrade_state, relics, player_level, elapsed):
			_add_level_hint(option, upgrade_state.get_passive_level(String(option["id"])))
			options.append(option)

	for weapon_upgrade in weapon_loadout.get_upgrade_options():
		var option: Dictionary = weapon_upgrade.duplicate(true)
		if _requirements_met(option, weapon_loadout, upgrade_state, relics, player_level, elapsed):
			options.append(option)

	for evolution_upgrade in weapon_loadout.get_evolution_options(upgrade_state, relics):
		var option: Dictionary = evolution_upgrade.duplicate(true)
		if _requirements_met(option, weapon_loadout, upgrade_state, relics, player_level, elapsed):
			options.append(option)

	for relic_upgrade in RELIC_UPGRADES:
		var option: Dictionary = relic_upgrade.duplicate(true)
		if relics.has(String(option["id"])):
			continue
		if _requirements_met(option, weapon_loadout, upgrade_state, relics, player_level, elapsed):
			options.append(option)
	return options


static func _requirements_met(
	option: Dictionary,
	weapon_loadout,
	upgrade_state,
	relics,
	player_level: int,
	elapsed: float
) -> bool:
	var requires: Dictionary = option.get("requires", {})
	if requires.has("level") and player_level < int(requires["level"]):
		return false
	if requires.has("elapsed") and elapsed < float(requires["elapsed"]):
		return false
	if requires.has("weapon") and not weapon_loadout.has_weapon(String(requires["weapon"])):
		return false
	if requires.has("relic") and not relics.has(String(requires["relic"])):
		return false
	if requires.has("passive"):
		var passive_requirements: Dictionary = requires["passive"]
		for passive_id in passive_requirements.keys():
			if upgrade_state.get_passive_level(String(passive_id)) < int(passive_requirements[passive_id]):
				return false
	return true


static func _add_level_hint(option: Dictionary, current_level: int) -> void:
	var max_level := int(option.get("max_level", 1))
	option["desc"] = "%s（%d/%d）" % [option["desc"], current_level + 1, max_level]


static func _weighted_option_index(rng: RandomNumberGenerator, options: Array, player_level: int, elapsed: float, reward_source: String) -> int:
	var total_weight := 0.0
	for option in options:
		total_weight += _option_weight(option, player_level, elapsed, reward_source)

	var roll := rng.randf() * total_weight
	for option_index in range(options.size()):
		roll -= _option_weight(options[option_index], player_level, elapsed, reward_source)
		if roll <= 0.0:
			return option_index
	return options.size() - 1


static func _option_weight(option: Dictionary, player_level: int, elapsed: float, reward_source: String) -> float:
	var base_weight := _rarity_weight(option.get("rarity", RARITY_COMMON), player_level, elapsed, reward_source)
	match String(option.get("type", "")):
		"weapon_level":
			return base_weight * 2.15
		"weapon_add":
			return base_weight * 1.75
		"weapon_evolve":
			return base_weight * 1.65
		"relic":
			return base_weight * 1.18
		"passive":
			return base_weight * 0.82
		"heal":
			return base_weight * 0.45
	return base_weight


static func _rarity_weight(rarity: String, player_level: int, elapsed: float, reward_source: String) -> float:
	if reward_source == REWARD_CHEST:
		match rarity:
			RARITY_UNCOMMON:
				return 1.25
			RARITY_RARE:
				return 0.86 + minf(elapsed / 420.0, 1.0) * 0.24
			_:
				return 0.24

	var time_bonus := minf(elapsed / 360.0, 1.0)
	var level_bonus := minf(float(maxi(player_level - 3, 0)) / 12.0, 1.0)
	match rarity:
		RARITY_UNCOMMON:
			return 0.55 + time_bonus * 0.2
		RARITY_RARE:
			return 0.16 + time_bonus * 0.24 + level_bonus * 0.18
		_:
			return 1.0
