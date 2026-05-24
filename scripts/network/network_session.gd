class_name NetworkSession
extends Node

signal mode_changed(mode: String, status_text: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal world_snapshot_received(snapshot: Dictionary)
signal upgrade_choice_received(peer_id: int, choice_index: int)
signal restart_requested(peer_id: int)
signal lobby_ready_received(peer_id: int, is_ready: bool)
signal game_start_received()
signal protocol_accepted()
signal protocol_rejected(reason: String)
signal discovered_rooms_changed()

const MODE_OFFLINE := "offline"
const MODE_HOST := "host"
const MODE_CLIENT := "client"
const MODE_CONNECTING := "connecting"
const DEFAULT_PORT := 24567
const DISCOVERY_PORT := 24568
const DISCOVERY_REQUEST_PORT := 24569
const DISCOVERY_MAGIC := "ROGUELITE_RPG_LAN_ROOM"
const DISCOVERY_QUERY_MAGIC := "ROGUELITE_RPG_LAN_QUERY"
const DISCOVERY_BROADCAST_ADDRESS := "255.255.255.255"
const DISCOVERY_INTERVAL := 1.0
const DISCOVERY_PROBE_INTERVAL := 0.8
const DISCOVERY_ROOM_TIMEOUT := 3.5
const MAX_PLAYERS := 15
const SERVER_PEER_ID := 1
const PROTOCOL_VERSION := 7
const MAX_UPGRADE_CHOICE_INDEX := 8
const MAX_MOUSE_TARGET_ABS := 100000.0

var mode := MODE_OFFLINE
var status_text := "单人模式"
var latest_inputs := {}
var latest_world_snapshot := {}
var pending_protocol_peers := {}
var peer_protocol_versions := {}
var discovery_sender: PacketPeerUDP
var discovery_request_listener: PacketPeerUDP
var discovery_listener: PacketPeerUDP
var discovery_probe_sender: PacketPeerUDP
var discovery_broadcast_timer := 0.0
var discovery_probe_timer := 0.0
var discovery_game_port := DEFAULT_PORT
var discovery_room_name := "RPG 房间"
var discovery_room_state := "lobby"
var discovery_player_count := 1
var discovered_rooms := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	_update_room_advertising(delta)
	_poll_room_discovery_requests()
	_update_room_discovery_probe(delta)
	_poll_room_discovery()


func host_game(port := DEFAULT_PORT) -> Error:
	_close_peer()
	stop_room_discovery()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		_set_mode(MODE_OFFLINE, "开房失败：%s" % error)
		return error
	multiplayer.multiplayer_peer = peer
	latest_inputs.clear()
	pending_protocol_peers.clear()
	peer_protocol_versions.clear()
	latest_inputs[SERVER_PEER_ID] = {}
	peer_protocol_versions[SERVER_PEER_ID] = PROTOCOL_VERSION
	_set_mode(MODE_HOST, "房主模式，端口 %d" % port)
	start_room_advertising(port)
	peer_joined.emit(SERVER_PEER_ID)
	return OK


func join_game(address: String, port := DEFAULT_PORT) -> Error:
	_close_peer()
	stop_room_advertising()
	stop_room_discovery()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_set_mode(MODE_OFFLINE, "加入失败：%s" % error)
		return error
	multiplayer.multiplayer_peer = peer
	_set_mode(MODE_CONNECTING, "正在连接 %s:%d" % [address, port])
	return OK


func use_offline_mode() -> void:
	_close_peer()
	stop_room_advertising()
	latest_inputs.clear()
	latest_world_snapshot.clear()
	pending_protocol_peers.clear()
	peer_protocol_versions.clear()
	_set_mode(MODE_OFFLINE, "单人模式")


func is_offline() -> bool:
	return mode == MODE_OFFLINE


func is_host() -> bool:
	return mode == MODE_HOST


func is_client() -> bool:
	return mode == MODE_CLIENT or mode == MODE_CONNECTING


func local_peer_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return SERVER_PEER_ID
	return multiplayer.get_unique_id()


func send_player_input(input_state: Dictionary) -> void:
	var sanitized_input := _sanitize_input_state(input_state)
	if mode == MODE_CLIENT:
		_submit_player_input.rpc_id(SERVER_PEER_ID, sanitized_input)
	elif mode == MODE_HOST or mode == MODE_OFFLINE:
		latest_inputs[SERVER_PEER_ID] = sanitized_input


func send_upgrade_choice(choice_index: int) -> void:
	if not _is_valid_upgrade_choice_index(choice_index):
		return
	if mode == MODE_CLIENT:
		_submit_upgrade_choice.rpc_id(SERVER_PEER_ID, choice_index)
	elif mode == MODE_HOST or mode == MODE_OFFLINE:
		upgrade_choice_received.emit(SERVER_PEER_ID, choice_index)


func request_restart() -> void:
	if mode == MODE_CLIENT:
		_submit_restart_request.rpc_id(SERVER_PEER_ID)
	elif mode == MODE_HOST or mode == MODE_OFFLINE:
		restart_requested.emit(SERVER_PEER_ID)


func send_lobby_ready(is_ready: bool) -> void:
	if mode == MODE_CLIENT:
		_submit_lobby_ready.rpc_id(SERVER_PEER_ID, is_ready)
	elif mode == MODE_HOST or mode == MODE_OFFLINE:
		lobby_ready_received.emit(SERVER_PEER_ID, is_ready)


func broadcast_game_start() -> void:
	if mode != MODE_HOST:
		return
	_receive_game_start.rpc()


func input_for_peer(peer_id: int) -> Dictionary:
	return latest_inputs.get(peer_id, {})


func broadcast_world_snapshot(snapshot: Dictionary) -> void:
	if mode != MODE_HOST:
		return
	_receive_world_snapshot.rpc(snapshot)


func connected_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = [SERVER_PEER_ID]
	if multiplayer.multiplayer_peer == null:
		return peer_ids
	for peer_id in multiplayer.get_peers():
		peer_ids.append(int(peer_id))
	return peer_ids


func start_room_advertising(game_port := DEFAULT_PORT) -> void:
	stop_room_advertising()
	discovery_game_port = game_port
	discovery_sender = PacketPeerUDP.new()
	discovery_sender.set_broadcast_enabled(true)
	discovery_request_listener = PacketPeerUDP.new()
	var request_error := discovery_request_listener.bind(DISCOVERY_REQUEST_PORT)
	if request_error != OK:
		discovery_request_listener = null
	discovery_broadcast_timer = 0.0


func stop_room_advertising() -> void:
	if discovery_sender != null:
		discovery_sender.close()
	discovery_sender = null
	if discovery_request_listener != null:
		discovery_request_listener.close()
	discovery_request_listener = null


func update_room_advertisement(room_state: String, player_count: int, room_name := "") -> void:
	if not room_name.strip_edges().is_empty():
		discovery_room_name = room_name.strip_edges().left(32)
	discovery_room_state = room_state
	discovery_player_count = clampi(player_count, 1, MAX_PLAYERS)


func start_room_discovery() -> Error:
	if discovery_listener != null and discovery_listener.is_bound():
		return OK
	discovered_rooms.clear()
	discovery_listener = PacketPeerUDP.new()
	var error := discovery_listener.bind(DISCOVERY_PORT)
	if error != OK:
		discovery_listener = null
		return error
	discovery_probe_sender = PacketPeerUDP.new()
	discovery_probe_sender.set_broadcast_enabled(true)
	discovery_probe_timer = 0.0
	discovered_rooms_changed.emit()
	return OK


func stop_room_discovery() -> void:
	if discovery_listener != null:
		discovery_listener.close()
	discovery_listener = null
	if discovery_probe_sender != null:
		discovery_probe_sender.close()
	discovery_probe_sender = null


func is_room_discovery_active() -> bool:
	return discovery_listener != null and discovery_listener.is_bound()


func discovered_room_list() -> Array:
	_prune_discovered_rooms()
	var rooms := []
	for room_key in discovered_rooms.keys():
		rooms.append(discovered_rooms[room_key])
	rooms.sort_custom(func(a, b): return String(a.get("address", "")) < String(b.get("address", "")))
	return rooms


func first_discovered_room() -> Dictionary:
	var rooms := discovered_room_list()
	return rooms[0] if not rooms.is_empty() else {}


@rpc("any_peer", "unreliable")
func _submit_player_input(input_state: Dictionary) -> void:
	if mode != MODE_HOST:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _is_verified_peer(sender_id):
		return
	if not latest_inputs.has(sender_id):
		return
	latest_inputs[sender_id] = _sanitize_input_state(input_state)


@rpc("any_peer", "reliable")
func _submit_upgrade_choice(choice_index: int) -> void:
	if mode != MODE_HOST:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _is_verified_peer(sender_id):
		return
	if not _is_valid_upgrade_choice_index(choice_index):
		return
	upgrade_choice_received.emit(sender_id, choice_index)


@rpc("any_peer", "reliable")
func _submit_restart_request() -> void:
	if mode != MODE_HOST:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _is_verified_peer(sender_id):
		return
	restart_requested.emit(sender_id)


@rpc("any_peer", "reliable")
func _submit_lobby_ready(is_ready: bool) -> void:
	if mode != MODE_HOST:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _is_verified_peer(sender_id):
		return
	lobby_ready_received.emit(sender_id, is_ready)


@rpc("any_peer", "reliable")
func _submit_protocol_version(client_protocol_version: int) -> void:
	if mode != MODE_HOST:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if client_protocol_version != PROTOCOL_VERSION:
		var reason := "版本不一致：房主协议 %d，客户端协议 %d" % [PROTOCOL_VERSION, client_protocol_version]
		_receive_protocol_rejected.rpc_id(sender_id, reason)
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return
	pending_protocol_peers.erase(sender_id)
	peer_protocol_versions[sender_id] = client_protocol_version
	latest_inputs[sender_id] = {}
	_receive_protocol_accepted.rpc_id(sender_id, PROTOCOL_VERSION)
	peer_joined.emit(sender_id)


@rpc("authority", "unreliable")
func _receive_world_snapshot(snapshot: Dictionary) -> void:
	latest_world_snapshot = snapshot
	world_snapshot_received.emit(snapshot)


@rpc("authority", "reliable")
func _receive_game_start() -> void:
	game_start_received.emit()


@rpc("authority", "reliable")
func _receive_protocol_accepted(server_protocol_version: int) -> void:
	_set_mode(MODE_CLIENT, "已连接房主，协议 %d" % server_protocol_version)
	protocol_accepted.emit()


@rpc("authority", "reliable")
func _receive_protocol_rejected(reason: String) -> void:
	_close_peer()
	_set_mode(MODE_OFFLINE, reason)
	protocol_rejected.emit(reason)


func _on_peer_connected(peer_id: int) -> void:
	if mode == MODE_HOST:
		pending_protocol_peers[int(peer_id)] = true
		_set_mode(MODE_HOST, "玩家 %d 已连接，等待版本校验" % int(peer_id))


func _on_peer_disconnected(peer_id: int) -> void:
	latest_inputs.erase(int(peer_id))
	pending_protocol_peers.erase(int(peer_id))
	peer_protocol_versions.erase(int(peer_id))
	peer_left.emit(int(peer_id))


func _on_connected_to_server() -> void:
	_set_mode(MODE_CLIENT, "已连接房主，正在校验版本")
	_submit_protocol_version.rpc_id(SERVER_PEER_ID, PROTOCOL_VERSION)


func _on_connection_failed() -> void:
	_close_peer()
	_set_mode(MODE_OFFLINE, "连接失败，已回到单人模式")


func _on_server_disconnected() -> void:
	_close_peer()
	_set_mode(MODE_OFFLINE, "房主已断开，已回到单人模式")


func _set_mode(new_mode: String, new_status_text: String) -> void:
	mode = new_mode
	status_text = new_status_text
	mode_changed.emit(mode, status_text)


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func _update_room_advertising(delta: float) -> void:
	if mode != MODE_HOST or discovery_sender == null:
		return
	discovery_broadcast_timer -= delta
	if discovery_broadcast_timer > 0.0:
		return
	discovery_broadcast_timer = DISCOVERY_INTERVAL
	for address in _discovery_broadcast_addresses():
		_send_room_advertisement(String(address), DISCOVERY_PORT)


func _send_room_advertisement(address: String, port: int) -> void:
	if discovery_sender == null:
		return
	var payload := {
		"magic": DISCOVERY_MAGIC,
		"protocol_version": PROTOCOL_VERSION,
		"room_name": discovery_room_name,
		"game_port": discovery_game_port,
		"room_state": discovery_room_state,
		"player_count": discovery_player_count,
		"max_players": MAX_PLAYERS
	}
	discovery_sender.set_dest_address(address, port)
	discovery_sender.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _poll_room_discovery_requests() -> void:
	if mode != MODE_HOST or discovery_request_listener == null or not discovery_request_listener.is_bound():
		return
	while discovery_request_listener.get_available_packet_count() > 0:
		var packet := discovery_request_listener.get_packet()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not (data is Dictionary):
			continue
		if String(data.get("magic", "")) != DISCOVERY_QUERY_MAGIC:
			continue
		if int(data.get("protocol_version", -1)) != PROTOCOL_VERSION:
			continue
		var reply_port := int(data.get("reply_port", DISCOVERY_PORT))
		if reply_port <= 0 or reply_port > 65535:
			continue
		_send_room_advertisement(discovery_request_listener.get_packet_ip(), reply_port)


func _update_room_discovery_probe(delta: float) -> void:
	if discovery_listener == null or not discovery_listener.is_bound() or discovery_probe_sender == null:
		return
	discovery_probe_timer -= delta
	if discovery_probe_timer > 0.0:
		return
	discovery_probe_timer = DISCOVERY_PROBE_INTERVAL
	_send_room_discovery_probe()


func _send_room_discovery_probe() -> void:
	if discovery_probe_sender == null:
		return
	var payload := {
		"magic": DISCOVERY_QUERY_MAGIC,
		"protocol_version": PROTOCOL_VERSION,
		"reply_port": DISCOVERY_PORT
	}
	var packet := JSON.stringify(payload).to_utf8_buffer()
	for address in _discovery_broadcast_addresses():
		discovery_probe_sender.set_dest_address(String(address), DISCOVERY_REQUEST_PORT)
		discovery_probe_sender.put_packet(packet)


func _poll_room_discovery() -> void:
	if discovery_listener == null or not discovery_listener.is_bound():
		return
	var changed := false
	while discovery_listener.get_available_packet_count() > 0:
		var packet := discovery_listener.get_packet()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if not (data is Dictionary):
			continue
		if String(data.get("magic", "")) != DISCOVERY_MAGIC:
			continue
		if int(data.get("protocol_version", -1)) != PROTOCOL_VERSION:
			continue
		var address := discovery_listener.get_packet_ip()
		var game_port := int(data.get("game_port", DEFAULT_PORT))
		var room_key := "%s:%d" % [address, game_port]
		discovered_rooms[room_key] = {
			"address": address,
			"port": game_port,
			"room_name": String(data.get("room_name", "RPG 房间")),
			"room_state": String(data.get("room_state", "lobby")),
			"player_count": int(data.get("player_count", 1)),
			"max_players": int(data.get("max_players", MAX_PLAYERS)),
			"protocol_version": int(data.get("protocol_version", PROTOCOL_VERSION)),
			"last_seen_msec": Time.get_ticks_msec()
		}
		changed = true
	if _prune_discovered_rooms():
		changed = true
	if changed:
		discovered_rooms_changed.emit()


func _prune_discovered_rooms() -> bool:
	var now := Time.get_ticks_msec()
	var changed := false
	for room_key in discovered_rooms.keys().duplicate():
		var room: Dictionary = discovered_rooms[room_key]
		if now - int(room.get("last_seen_msec", 0)) > int(DISCOVERY_ROOM_TIMEOUT * 1000.0):
			discovered_rooms.erase(room_key)
			changed = true
	return changed


func _discovery_broadcast_addresses() -> Array:
	var addresses := [DISCOVERY_BROADCAST_ADDRESS]
	var seen := {DISCOVERY_BROADCAST_ADDRESS: true}
	for raw_address in IP.get_local_addresses():
		var address := String(raw_address)
		if not _is_private_ipv4_for_discovery(address):
			continue
		var broadcast_address := _directed_broadcast_address(address)
		if broadcast_address.is_empty() or seen.has(broadcast_address):
			continue
		addresses.append(broadcast_address)
		seen[broadcast_address] = true
	return addresses


func _is_private_ipv4_for_discovery(address: String) -> bool:
	var octets := _ipv4_octets(address)
	if octets.is_empty():
		return false
	var first := int(octets[0])
	var second := int(octets[1])
	if first == 10 or (first == 192 and second == 168):
		return true
	if first == 172 and second >= 16 and second <= 31:
		return true
	return first == 169 and second == 254


func _directed_broadcast_address(address: String) -> String:
	var octets := _ipv4_octets(address)
	if octets.is_empty():
		return ""
	return "%d.%d.%d.255" % [int(octets[0]), int(octets[1]), int(octets[2])]


func _ipv4_octets(address: String) -> Array:
	var parts := address.split(".")
	if parts.size() != 4:
		return []
	var octets := []
	for part in parts:
		var text := String(part)
		if not text.is_valid_int():
			return []
		var value := int(text)
		if value < 0 or value > 255:
			return []
		octets.append(value)
	return octets


func _is_verified_peer(peer_id: int) -> bool:
	return peer_id == SERVER_PEER_ID or peer_protocol_versions.has(peer_id)


func _is_valid_upgrade_choice_index(choice_index: int) -> bool:
	return choice_index >= 0 and choice_index <= MAX_UPGRADE_CHOICE_INDEX


func _sanitize_input_state(input_state: Dictionary) -> Dictionary:
	var movement := Vector2.ZERO
	var raw_movement = input_state.get("movement", Vector2.ZERO)
	if raw_movement is Vector2:
		movement = raw_movement
	if not _is_valid_vector2(movement):
		movement = Vector2.ZERO
	if movement.length_squared() > 1.0:
		movement = movement.normalized()

	var mouse_target := Vector2.ZERO
	var raw_mouse_target = input_state.get("mouse_target", Vector2.ZERO)
	if raw_mouse_target is Vector2:
		mouse_target = raw_mouse_target
	if not _is_valid_vector2(mouse_target):
		mouse_target = Vector2.ZERO

	return {
		"movement": movement,
		"updates_mouse_target": bool(input_state.get("updates_mouse_target", false)),
		"mouse_target": mouse_target
	}


func _is_valid_vector2(value: Vector2) -> bool:
	return (
		value.x == value.x
		and value.y == value.y
		and absf(value.x) <= MAX_MOUSE_TARGET_ABS
		and absf(value.y) <= MAX_MOUSE_TARGET_ABS
	)
