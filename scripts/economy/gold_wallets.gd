class_name GoldWallets
extends RefCounted

var balances := {}


func reset() -> void:
	balances.clear()


func ensure_peer(peer_id: int) -> void:
	if not balances.has(peer_id):
		balances[peer_id] = 0


func remove_peer(peer_id: int) -> void:
	balances.erase(peer_id)


func gold_for(peer_id: int) -> int:
	return int(balances.get(peer_id, 0))


func grant_to_peer(peer_id: int, amount: int) -> void:
	if amount <= 0:
		return
	balances[peer_id] = gold_for(peer_id) + amount


func grant_to_peers(peer_ids: Array, amount: int) -> void:
	if amount <= 0:
		return
	for peer_id in peer_ids:
		grant_to_peer(int(peer_id), amount)


func spend(peer_id: int, amount: int) -> bool:
	if amount < 0:
		return false
	var current_gold := gold_for(peer_id)
	if current_gold < amount:
		return false
	balances[peer_id] = current_gold - amount
	return true


func serialize() -> Dictionary:
	var data := {}
	for peer_id in balances.keys():
		data[str(peer_id)] = int(balances[peer_id])
	return data


func apply_snapshot(raw_data) -> void:
	balances.clear()
	if not (raw_data is Dictionary):
		return
	for peer_key in raw_data.keys():
		balances[int(str(peer_key))] = int(raw_data[peer_key])
