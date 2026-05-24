class_name WeaponLoadout
extends RefCounted

const PistolWeaponResource := preload("res://scripts/weapons/pistol_weapon.gd")
const ShotgunWeaponResource := preload("res://scripts/weapons/shotgun_weapon.gd")
const KnifeWeaponResource := preload("res://scripts/weapons/knife_weapon.gd")
const FlameWeaponResource := preload("res://scripts/weapons/flame_weapon.gd")
const LightningWeaponResource := preload("res://scripts/weapons/lightning_weapon.gd")

const PISTOL := "pistol"
const SHOTGUN := "shotgun"
const KNIFE := "knife"
const FLAME := "flame"
const LIGHTNING := "lightning"
const UNLOCKABLE_WEAPON_IDS := [PISTOL, SHOTGUN, KNIFE, FLAME, LIGHTNING]
const EVOLUTION_DEFINITIONS := [
	{
		"id": "gatling",
		"type": "weapon_evolve",
		"rarity": "rare",
		"weapon_id": PISTOL,
		"title": "进化：加特林",
		"desc": "手枪满级 + 快速装填 5 级，转为极高速自动火力",
		"requires": {"passive": {"fire_rate": 5}}
	},
	{
		"id": "armor_shotgun",
		"type": "weapon_evolve",
		"rarity": "rare",
		"weapon_id": SHOTGUN,
		"title": "进化：穿甲霰弹",
		"desc": "霰弹满级 + 火力强化 4 级，霰弹获得穿透和更高爆发",
		"requires": {"passive": {"damage": 4}}
	},
	{
		"id": "shadow_knives",
		"type": "weapon_evolve",
		"rarity": "rare",
		"weapon_id": KNIFE,
		"title": "进化：暗影飞刃",
		"desc": "飞刀满级 + 第五发遗物，改为三向高穿透飞刃",
		"requires": {"relic": "fifth_shot_crit"}
	},
	{
		"id": "meteor_barrage",
		"type": "weapon_evolve",
		"rarity": "rare",
		"weapon_id": FLAME,
		"title": "进化：陨石雨",
		"desc": "火球满级 + 火力强化 4 级，改为连续投射多枚巨大火球",
		"requires": {"passive": {"damage": 4}}
	},
	{
		"id": "magnetic_storm",
		"type": "weapon_evolve",
		"rarity": "rare",
		"weapon_id": LIGHTNING,
		"title": "进化：磁暴场",
		"desc": "电弧满级 + 磁力背包 4 级，改为扇形多道穿透电束",
		"requires": {"passive": {"pickup": 4}}
	}
]

var weapons: Array = []


func reset(starting_weapon_id := PISTOL) -> void:
	weapons.clear()
	if add_weapon(starting_weapon_id) == null:
		add_weapon(PISTOL)


func update(delta: float, player, zombies: Array, bullets: Array, rng: RandomNumberGenerator) -> void:
	for weapon in weapons:
		weapon.update(delta, player, zombies, bullets, rng)


func apply_upgrade(upgrade: Dictionary) -> bool:
	var upgrade_type: String = upgrade.get("type", "")
	var target_weapon_id: String = upgrade.get("weapon_id", "")
	match upgrade_type:
		"weapon_add":
			return add_weapon(target_weapon_id) != null
		"weapon_level":
			var weapon = get_weapon(target_weapon_id)
			if weapon == null or not weapon.can_upgrade():
				return false
			weapon.upgrade()
			return true
		"weapon_evolve":
			return evolve_weapon(String(upgrade.get("id", "")), target_weapon_id)
	return false


func get_upgrade_options() -> Array:
	var options := []
	for weapon in weapons:
		if weapon.can_upgrade():
			options.append({
				"id": "weapon_level_%s" % weapon.weapon_id,
				"type": "weapon_level",
				"rarity": "common",
				"weapon_id": weapon.weapon_id,
				"title": weapon.upgrade_title(),
				"desc": "%s（%d/%d）" % [weapon.upgrade_desc(), weapon.level + 1, weapon.max_level],
				"max_level": weapon.max_level
			})

	for weapon_id in UNLOCKABLE_WEAPON_IDS:
		if has_weapon(weapon_id):
			continue
		options.append({
			"id": "weapon_add_%s" % weapon_id,
			"type": "weapon_add",
			"rarity": "common",
			"weapon_id": weapon_id,
			"title": "获得%s" % weapon_title(weapon_id),
			"desc": weapon_unlock_desc(weapon_id),
			"max_level": 1
		})
	return options


func get_evolution_options(upgrade_state, relics) -> Array:
	var options := []
	for evolution in EVOLUTION_DEFINITIONS:
		var option: Dictionary = evolution.duplicate(true)
		if _can_offer_evolution(option, upgrade_state, relics):
			options.append(option)
	return options


func add_weapon(target_weapon_id: String):
	if has_weapon(target_weapon_id):
		return get_weapon(target_weapon_id)
	var weapon = _make_weapon(target_weapon_id)
	if weapon == null:
		return null
	weapons.append(weapon)
	return weapon


func has_weapon(target_weapon_id: String) -> bool:
	return get_weapon(target_weapon_id) != null


func get_weapon(target_weapon_id: String):
	for weapon in weapons:
		if weapon.weapon_id == target_weapon_id:
			return weapon
	return null


func evolve_weapon(evolution_id: String, target_weapon_id: String) -> bool:
	var weapon = get_weapon(target_weapon_id)
	if weapon == null or not weapon.can_evolve():
		return false
	weapon.evolve(evolution_id)
	return true


func status_text() -> String:
	var parts := []
	for weapon in weapons:
		if weapon.evolved:
			parts.append("%s ★" % weapon.title)
		else:
			parts.append("%s Lv%d" % [weapon.title, weapon.level])
	return " / ".join(parts)


func weapon_title(target_weapon_id: String) -> String:
	match target_weapon_id:
		SHOTGUN:
			return "霰弹"
		KNIFE:
			return "飞刀"
		FLAME:
			return "火球"
		LIGHTNING:
			return "电弧"
		_:
			return "手枪"


func weapon_unlock_desc(target_weapon_id: String) -> String:
	match target_weapon_id:
		SHOTGUN:
			return "周期性发射近距离扇形弹幕"
		KNIFE:
			return "周期性投掷可穿透敌人的飞刀"
		FLAME:
			return "发射大范围高伤害火球，适合清理密集尸潮"
		LIGHTNING:
			return "发射高速穿透电弧，优先处理一条线上的敌人"
		_:
			return "基础自动射击武器"


func _make_weapon(target_weapon_id: String):
	match target_weapon_id:
		PISTOL:
			return PistolWeaponResource.new()
		SHOTGUN:
			return ShotgunWeaponResource.new()
		KNIFE:
			return KnifeWeaponResource.new()
		FLAME:
			return FlameWeaponResource.new()
		LIGHTNING:
			return LightningWeaponResource.new()
	return null


func _can_offer_evolution(evolution: Dictionary, upgrade_state, relics) -> bool:
	var target_weapon_id: String = evolution.get("weapon_id", "")
	var weapon = get_weapon(target_weapon_id)
	if weapon == null or not weapon.can_evolve():
		return false

	var requires: Dictionary = evolution.get("requires", {})
	if requires.has("passive"):
		var passive_requirements: Dictionary = requires["passive"]
		for passive_id in passive_requirements.keys():
			if upgrade_state.get_passive_level(String(passive_id)) < int(passive_requirements[passive_id]):
				return false
	if requires.has("relic") and not relics.has(String(requires["relic"])):
		return false
	return true
