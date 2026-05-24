class_name MerchantCatalog
extends RefCounted

const UpgradeCatalog := preload("res://scripts/upgrades/upgrade_catalog.gd")

const OFFER_HEAL := "heal"
const OFFER_WEAPON_TUNE := "weapon_tune"
const OFFER_PASSIVE := "passive_training"


static func default_offers(merchant_id: int, peer_id: int) -> Array:
	return [
		make_offer(merchant_id, peer_id, OFFER_HEAL, "急救包", "回复自己 35% 最大生命", 25),
		make_offer(merchant_id, peer_id, OFFER_WEAPON_TUNE, "武器调校", "随机强化自己一件未满级武器", 45),
		make_offer(merchant_id, peer_id, OFFER_PASSIVE, "被动训练", "获得一个普通或优秀被动", 50)
	]


static func make_offer(merchant_id: int, peer_id: int, kind: String, title: String, desc: String, price: int) -> Dictionary:
	return {
		"offer_id": "%d:%d:%s" % [merchant_id, peer_id, kind],
		"kind": kind,
		"title": title,
		"desc": desc,
		"price": price
	}


static func validate_offer(
	offer: Dictionary,
	gold: int,
	target_player,
	is_active_peer: bool,
	is_in_range: bool,
	is_in_cooldown: bool,
	already_purchased: bool,
	weapon_level_count: int,
	passive_option_count: int
) -> Dictionary:
	if already_purchased:
		return {"can_buy": false, "reason": "已购买"}
	if is_in_cooldown:
		return {"can_buy": false, "reason": "刚被攻击，暂时不能交易"}
	if not is_active_peer:
		return {"can_buy": false, "reason": "不能购买"}
	if target_player == null or not target_player.is_combat_active():
		return {"can_buy": false, "reason": "倒地不能购买"}
	if not is_in_range:
		return {"can_buy": false, "reason": "离商人太远"}
	var price := int(offer.get("price", 0))
	if gold < price:
		return {"can_buy": false, "reason": "金币不足"}
	match String(offer.get("kind", "")):
		OFFER_HEAL:
			if target_player.hp >= target_player.max_hp:
				return {"can_buy": false, "reason": "生命已满"}
		OFFER_WEAPON_TUNE:
			if weapon_level_count <= 0:
				return {"can_buy": false, "reason": "没有可强化武器"}
		OFFER_PASSIVE:
			if passive_option_count <= 0:
				return {"can_buy": false, "reason": "没有可训练被动"}
		_:
			return {"can_buy": false, "reason": "商品不可用"}
	return {"can_buy": true, "reason": ""}


static func weapon_level_options(loadout) -> Array:
	var options := []
	for option in loadout.get_upgrade_options():
		if String(option.get("type", "")) == "weapon_level":
			options.append(option)
	return options


static func passive_training_options(upgrade_state) -> Array:
	var options := []
	for passive_upgrade in UpgradeCatalog.PASSIVE_UPGRADES:
		var option: Dictionary = passive_upgrade.duplicate(true)
		if String(option.get("rarity", UpgradeCatalog.RARITY_COMMON)) == UpgradeCatalog.RARITY_RARE:
			continue
		if upgrade_state.can_upgrade_passive(option):
			options.append(option)
	return options


static func apply_offer_effect(offer: Dictionary, target_player, loadout, upgrade_state, relics, rng: RandomNumberGenerator) -> bool:
	if target_player == null:
		return false
	match String(offer.get("kind", "")):
		OFFER_HEAL:
			target_player.heal(target_player.max_hp * 0.35)
			return true
		OFFER_WEAPON_TUNE:
			var weapon_options := weapon_level_options(loadout)
			if weapon_options.is_empty():
				return false
			return loadout.apply_upgrade(weapon_options[rng.randi_range(0, weapon_options.size() - 1)])
		OFFER_PASSIVE:
			var passive_options := passive_training_options(upgrade_state)
			if passive_options.is_empty():
				return false
			var upgrade: Dictionary = passive_options[rng.randi_range(0, passive_options.size() - 1)]
			return UpgradeCatalog.apply_upgrade(upgrade, target_player, loadout, upgrade_state, relics)
	return false
