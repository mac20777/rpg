class_name MerchantShopState
extends RefCounted

const MerchantCatalog := preload("res://scripts/merchants/merchant_catalog.gd")

var offers_by_peer := {}
var purchases_by_peer := {}
var reopen_cooldowns := {}


func reset() -> void:
	offers_by_peer.clear()
	purchases_by_peer.clear()
	reopen_cooldowns.clear()


func update_cooldowns(delta: float) -> void:
	for peer_id in reopen_cooldowns.keys().duplicate():
		var remaining := maxf(float(reopen_cooldowns[peer_id]) - delta, 0.0)
		if remaining <= 0.0:
			reopen_cooldowns.erase(peer_id)
		else:
			reopen_cooldowns[peer_id] = remaining


func interrupt(peer_id: int, cooldown: float) -> void:
	reopen_cooldowns[peer_id] = cooldown


func is_in_cooldown(peer_id: int) -> bool:
	return reopen_cooldowns.has(peer_id)


func ensure_offers(peer_id: int, merchant) -> Array:
	var key := merchant_peer_key(merchant.merchant_id, peer_id)
	if offers_by_peer.has(key):
		return offers_by_peer[key]
	var offers := MerchantCatalog.default_offers(merchant.merchant_id, peer_id)
	offers_by_peer[key] = offers
	return offers


func has_purchased(peer_id: int, offer_id: String) -> bool:
	var purchases: Dictionary = purchases_by_peer.get(peer_id, {})
	return purchases.has(offer_id)


func mark_purchased(peer_id: int, offer_id: String) -> void:
	var purchases: Dictionary = purchases_by_peer.get(peer_id, {})
	purchases[offer_id] = true
	purchases_by_peer[peer_id] = purchases


func clear_merchant(merchant_id: int) -> void:
	for key in offers_by_peer.keys().duplicate():
		if String(key).begins_with("%d:" % merchant_id):
			offers_by_peer.erase(key)
	for peer_id in purchases_by_peer.keys().duplicate():
		var purchases: Dictionary = purchases_by_peer[peer_id]
		for offer_id in purchases.keys().duplicate():
			if String(offer_id).begins_with("%d:" % merchant_id):
				purchases.erase(offer_id)
		if purchases.is_empty():
			purchases_by_peer.erase(peer_id)
		else:
			purchases_by_peer[peer_id] = purchases


func remove_peer(peer_id: int) -> void:
	reopen_cooldowns.erase(peer_id)
	purchases_by_peer.erase(peer_id)
	for key in offers_by_peer.keys().duplicate():
		if String(key).ends_with(":%d" % peer_id):
			offers_by_peer.erase(key)


func merchant_peer_key(merchant_id: int, peer_id: int) -> String:
	return "%d:%d" % [merchant_id, peer_id]


func serialize_offers() -> Dictionary:
	return offers_by_peer.duplicate(true)


func apply_offers_snapshot(raw_data) -> void:
	offers_by_peer.clear()
	if not (raw_data is Dictionary):
		return
	for key in raw_data.keys():
		var offers = raw_data[key]
		if offers is Array:
			offers_by_peer[String(key)] = offers


func serialize_purchases() -> Dictionary:
	var data := {}
	for peer_id in purchases_by_peer.keys():
		data[str(peer_id)] = purchases_by_peer[peer_id]
	return data


func apply_purchases_snapshot(raw_data) -> void:
	purchases_by_peer.clear()
	if not (raw_data is Dictionary):
		return
	for peer_key in raw_data.keys():
		var purchases = raw_data[peer_key]
		if purchases is Dictionary:
			purchases_by_peer[int(str(peer_key))] = purchases


func serialize_cooldowns() -> Dictionary:
	var data := {}
	for peer_id in reopen_cooldowns.keys():
		data[str(peer_id)] = float(reopen_cooldowns[peer_id])
	return data


func apply_cooldowns_snapshot(raw_data) -> void:
	reopen_cooldowns.clear()
	if not (raw_data is Dictionary):
		return
	for peer_key in raw_data.keys():
		var remaining := float(raw_data[peer_key])
		if remaining > 0.0:
			reopen_cooldowns[int(str(peer_key))] = remaining
