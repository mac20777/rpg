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

const MODE_OFFLINE := "offline"
const MODE_HOST := "host"
const MODE_CLIENT := "client"
const MODE_CONNECTING := "connecting"
const DEFAULT_PORT := 24567
const MAX_PLAYERS := 4
const SERVER_PEER_ID := 1
const PROTOCOL_VERSION := 2
const MAX_UPGRADE_CHOICE_INDEX := 8
const MAX_MOUSE_TARGET_ABS := 100000.0

var mode := MODE_OFFLINE
var status_text := "单人模式"
var latest_inputs := {}
var latest_world_snapshot := {}
var pending_protocol_peers := {}
var peer_protocol_versions := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port := DEFAULT_PORT) -> Error:
	_close_peer()
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
	peer_joined.emit(SERVER_PEER_ID)
	return OK


func join_game(address: String, port := DEFAULT_PORT) -> Error:
	_close_peer()
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
