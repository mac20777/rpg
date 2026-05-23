extends Node2D

const EnemyCatalog := preload("res://scripts/enemies/enemy_catalog.gd")
const SpawnDirector := preload("res://scripts/game/spawn_director.gd")
const EliteDirector := preload("res://scripts/game/elite_director.gd")
const MapEventDirector := preload("res://scripts/events/map_event_director.gd")
const UpgradeCatalog := preload("res://scripts/upgrades/upgrade_catalog.gd")
const UpgradeState := preload("res://scripts/upgrades/upgrade_state.gd")
const WeaponLoadout := preload("res://scripts/weapons/weapon_loadout.gd")
const RelicCollection := preload("res://scripts/relics/relic_collection.gd")
const MetaProgression := preload("res://scripts/meta/meta_progression.gd")
const RewardChestState := preload("res://scripts/entities/reward_chest_state.gd")
const SupplyCacheState := preload("res://scripts/entities/supply_cache_state.gd")
const HoldoutEventState := preload("res://scripts/entities/holdout_event_state.gd")
const VisualEffectState := preload("res://scripts/entities/visual_effect_state.gd")
const FeedbackAudioResource := preload("res://scripts/feedback/feedback_audio.gd")
const VisualEffectPoolResource := preload("res://scripts/feedback/visual_effect_pool.gd")
const NetworkSessionResource := preload("res://scripts/network/network_session.gd")

const ARENA_SIZE := Vector2(1800.0, 1100.0)
const PLAYER_RADIUS := 16.0
const XP_RADIUS := 6.0
const CHEST_PICKUP_RADIUS := 34.0
const SUPPLY_PICKUP_RADIUS := 34.0
const SUPPLY_BOMB_RADIUS := 460.0
const PLAYER_XP_COLLISION_RADIUS := PLAYER_RADIUS + XP_RADIUS
const PLAYER_XP_COLLISION_RADIUS_SQ := PLAYER_XP_COLLISION_RADIUS * PLAYER_XP_COLLISION_RADIUS
const COLLISION_CELL_SIZE := 96.0
const DETAILED_ZOMBIE_DRAW_LIMIT := 180
const DETAILED_XP_DRAW_LIMIT := 220
const HUD_REFRESH_INTERVAL := 0.1
const MAP_TILE_SIZE := Vector2i(50, 50)
const MAP_COLUMNS := 36
const MAP_ROWS := 22
const MAP_SOURCE_ID := 0
const MAP_FLOOR_ATLAS := Vector2i(0, 0)
const MAP_BORDER_ATLAS := Vector2i(1, 0)
const DEFAULT_ARENA_TILESET_PATH := "res://resources/arena_tileset.tres"
const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const GAME_VERSION := "0.1.0-dev"
const SERVER_PEER_ID := 1
const NETWORK_INPUT_INTERVAL := 0.033
const WORLD_SNAPSHOT_INTERVAL := 0.08
const LOBBY_AUTO_START_DELAY := 3.0
const UPGRADE_SELECTION_TIME_LIMIT := 20.0
const REVIVE_RADIUS := 72.0
const REVIVE_RADIUS_SQ := REVIVE_RADIUS * REVIVE_RADIUS
const REVIVE_BASE_TIME := 3.5
const REVIVE_DOWN_PENALTY := 1.0
const REVIVE_HEALTH_RATIO := 0.35
const NET_STATE_OFFLINE_LOBBY := "OfflineLobby"
const NET_STATE_OFFLINE_RUNNING := "OfflineRunning"
const NET_STATE_HOST_LOBBY := "HostLobby"
const NET_STATE_CLIENT_LOBBY := "ClientLobby"
const NET_STATE_HOST_RUNNING := "HostRunning"
const NET_STATE_CLIENT_RUNNING_ACTIVE := "ClientRunningActive"
const NET_STATE_CLIENT_RUNNING_SPECTATOR := "ClientRunningSpectator"
const NET_STATE_RESULTS := "Results"
const NET_STATE_DISCONNECTED := "Disconnected"
const PLAYER_COLORS := [
	Color(0.12, 0.75, 0.78),
	Color(0.92, 0.54, 0.20),
	Color(0.54, 0.72, 0.25),
	Color(0.75, 0.48, 0.90),
	Color(0.92, 0.32, 0.42),
	Color(0.30, 0.58, 0.95),
	Color(0.95, 0.78, 0.24),
	Color(0.20, 0.88, 0.48),
	Color(0.96, 0.42, 0.78),
	Color(0.48, 0.86, 0.96),
	Color(0.70, 0.52, 0.22),
	Color(0.62, 0.78, 0.96),
	Color(0.95, 0.62, 0.55),
	Color(0.68, 0.88, 0.30),
	Color(0.82, 0.64, 0.98)
]

var rng := RandomNumberGenerator.new()
var arena_map: TileMapLayer
var player: Player
var players := {}
var player_weapon_loadouts := {}
var camera: Camera2D
var hud_layer: CanvasLayer
var hud_label: Label
var weapon_label: Label
var relic_label: Label
var network_session
var network_status_label: Label
var debug_label: Label
var version_label: Label
var network_ip_input: LineEdit
var network_port_spin_box: SpinBox
var lobby_overlay: ColorRect
var lobby_title_label: Label
var lobby_status_label: Label
var lobby_players_label: Label
var lobby_ready_button: Button
var lobby_start_button: Button
var lobby_single_button: Button
var lobby_host_button: Button
var lobby_join_button: Button
var lobby_discovery_button: Button
var lobby_leave_button: Button
var lobby_discovery_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var upgrade_overlay: ColorRect
var upgrade_title_label: Label
var upgrade_hint_label: Label
var upgrade_buttons_box: VBoxContainer
var game_over_overlay: ColorRect
var game_over_label: Label
var feedback_audio

var zombies: Array[ZombieState] = []
var bullets: Array[BulletState] = []
var xp_orbs: Array[XpOrbState] = []
var reward_chests: Array = []
var supply_caches: Array = []
var holdout_events: Array = []
var visual_effects := VisualEffectPoolResource.new()
var upgrade_choices: Array = []
var upgrade_choices_by_peer := {}
var upgrade_selected_peer_ids := {}
var upgrade_reward_source := UpgradeCatalog.REWARD_LEVEL
var upgrade_selection_timer := -1.0
var zombie_grid := {}
var spawn_director := SpawnDirector.new()
var elite_director := EliteDirector.new()
var map_event_director := MapEventDirector.new()
var weapon_loadout := WeaponLoadout.new()
var player_upgrade_states := {}
var relics := RelicCollection.new()
var meta_progression := MetaProgression.new()

var hud_refresh_timer := 0.0
var network_input_timer := 0.0
var world_snapshot_timer := 0.0
var elapsed := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_to_next := 6
var game_over := false
var choosing_upgrade := false
var selected_starting_weapon := WeaponLoadout.PISTOL
var selected_character := "survivor"
var last_unlock_messages := []
var local_peer_id := SERVER_PEER_ID
var synced_weapon_status_text := ""
var synced_relic_status_text := ""
var synced_upgrade_choice_key := ""
var run_started := false
var lobby_ready := {}
var waiting_peer_ids := {}
var run_participant_peer_ids := {}
var lobby_auto_start_timer := -1.0
var local_run_recorded := false
var network_state := NET_STATE_OFFLINE_LOBBY
var debug_overlay_visible := false
var snapshot_debug := {
	"last_size": 0,
	"last_received_msec": 0,
	"received_count": 0,
	"sent_count": 0
}


func _ready() -> void:
	rng.randomize()
	_setup_arena_map()
	_setup_network_session()
	_setup_player()
	_setup_feedback_audio()
	camera = Camera2D.new()
	camera.enabled = true
	add_child(camera)
	_create_ui()
	meta_progression.load()
	selected_starting_weapon = meta_progression.preferred_starting_weapon
	selected_character = meta_progression.preferred_character
	_enter_lobby()


func _process(delta: float) -> void:
	_update_feedback_audio(delta)
	_refresh_network_state()
	_update_room_advertisement_state()
	_update_debug_overlay()
	if _is_lobby_state():
		_update_lobby_network(delta)
		if player != null:
			camera.global_position = player.position
		queue_redraw()
		return

	if _is_network_client():
		_update_client_network(delta)
		if player != null:
			camera.global_position = player.position
		_refresh_hud(delta)
		queue_redraw()
		return

	if game_over:
		_send_local_input(delta)
		_update_network_snapshot(delta)
		queue_redraw()
		return

	if choosing_upgrade:
		_send_local_input(delta)
		_update_upgrade_selection(delta)
		if player != null:
			camera.global_position = player.position
		_update_network_snapshot(delta)
		queue_redraw()
		return

	elapsed += delta
	_send_local_input(delta)
	_update_players(delta)
	_update_map_events(delta)
	if choosing_upgrade:
		if player != null:
			camera.global_position = player.position
		_update_network_snapshot(delta)
		queue_redraw()
		return
	_update_spawning(delta)
	_update_elite_spawning(delta)
	_update_zombies(delta)
	_update_revives(delta)
	_update_weapons(delta)
	_update_bullets(delta)
	_update_visual_effects(delta)
	_update_xp_orbs(delta)
	if not choosing_upgrade:
		_update_reward_chests()
	_refresh_hud(delta)
	if player != null:
		camera.global_position = player.position
	_update_network_snapshot(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_overlay_visible = not debug_overlay_visible
			_update_debug_overlay()
			return
		if game_over:
			match event.keycode:
				KEY_R:
					_request_restart()
				KEY_Q:
					if not _is_network_client():
						_cycle_starting_weapon(-1)
				KEY_E:
					if not _is_network_client():
						_cycle_starting_weapon(1)
				KEY_Z:
					if not _is_network_client():
						_cycle_character(-1)
				KEY_C:
					if not _is_network_client():
						_cycle_character(1)
			return
		if choosing_upgrade:
			if event.keycode >= KEY_1 and event.keycode <= KEY_3:
				_choose_upgrade(int(event.keycode) - int(KEY_1))


func _draw() -> void:
	var draw_rect := _get_draw_rect()
	var draw_xp_details := xp_orbs.size() <= DETAILED_XP_DRAW_LIMIT
	var draw_zombie_details := zombies.size() <= DETAILED_ZOMBIE_DRAW_LIMIT
	for holdout in holdout_events:
		if draw_rect.has_point(holdout.position):
			_draw_holdout_event(holdout)
	for orb: XpOrbState in xp_orbs:
		if not draw_rect.has_point(orb.position):
			continue
		draw_circle(orb.position, XP_RADIUS, Color(0.35, 0.95, 0.95))
		if draw_xp_details:
			draw_arc(orb.position, XP_RADIUS + 3.0, 0.0, TAU, 16, Color(0.1, 0.4, 0.45), 2.0)
	for chest in reward_chests:
		if draw_rect.has_point(chest.position):
			_draw_reward_chest(chest)
	for supply in supply_caches:
		if draw_rect.has_point(supply.position):
			_draw_supply_cache(supply)
	for effect: VisualEffectState in visual_effects.effects:
		if draw_rect.has_point(effect.position):
			_draw_visual_effect(effect)
	for bullet: BulletState in bullets:
		if draw_rect.has_point(bullet.position):
			draw_circle(bullet.position, bullet.radius, bullet.color)
	for zombie: ZombieState in zombies:
		if not draw_rect.has_point(zombie.position):
			continue
		_draw_zombie(zombie, draw_zombie_details)


func _update_players(delta: float) -> void:
	var arena_rect := _get_arena_rect()
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player == null or not active_player.is_combat_active():
			continue
		var input_state: Dictionary = network_session.input_for_peer(int(peer_id)) if network_session != null else {}
		active_player.update_movement_from_input(delta, arena_rect, input_state)


func _update_map_events(delta: float) -> void:
	var hp_ratio := _lowest_player_hp_ratio()
	var event_requests := map_event_director.update(delta, supply_caches.size(), holdout_events.size(), hp_ratio, rng)
	for supply_kind in event_requests["supplies"]:
		_spawn_supply_cache(String(supply_kind))
	if bool(event_requests["holdout"]):
		_spawn_holdout_event()

	_update_supply_caches(delta)
	if choosing_upgrade:
		return
	_update_holdout_events(delta)


func _spawn_supply_cache(kind: String) -> void:
	var arena_rect := _get_arena_rect()
	var position := _random_event_position(arena_rect, 120.0)
	supply_caches.append(SupplyCacheState.new(position, kind))


func _spawn_holdout_event() -> void:
	var arena_rect := _get_arena_rect()
	var position := _random_event_position(arena_rect, 140.0)
	holdout_events.append(HoldoutEventState.new(position))


func _random_event_position(arena_rect: Rect2, margin: float) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(430.0, 760.0)
	var position := _team_focus_position() + Vector2.RIGHT.rotated(angle) * distance
	position.x = clampf(position.x, arena_rect.position.x + margin, arena_rect.end.x - margin)
	position.y = clampf(position.y, arena_rect.position.y + margin, arena_rect.end.y - margin)
	return position


func _update_spawning(delta: float) -> void:
	if spawn_director.should_cleanup(delta):
		_reposition_far_zombies()
		_trim_zombies_to_cap()

	var pressure_elapsed := _scaled_elapsed_for_player_count()
	var spawn_requests := spawn_director.update(delta * _player_count_pressure_multiplier(), pressure_elapsed, zombies.size(), rng)
	for enemy_type: String in spawn_requests:
		_spawn_zombie(enemy_type)


func _update_elite_spawning(delta: float) -> void:
	var elite_rank := elite_director.update(delta * _player_count_pressure_multiplier(), _active_elite_count(), rng)
	if elite_rank <= 0:
		return
	_spawn_elite(elite_rank)


func _spawn_zombie(enemy_type: String) -> void:
	var arena_rect := _get_arena_rect()
	var radius := EnemyCatalog.radius_for(enemy_type)
	var position := _random_spawn_position(arena_rect, radius)
	zombies.append(EnemyCatalog.create_zombie(rng, enemy_type, position, _scaled_elapsed_for_player_count()))


func _spawn_elite(rank: int) -> void:
	var arena_rect := _get_arena_rect()
	var position := _random_spawn_position(arena_rect, EnemyCatalog.ELITE_RADIUS)
	zombies.append(EnemyCatalog.create_elite(rng, position, _scaled_elapsed_for_player_count(), rank))


func _active_elite_count() -> int:
	var count := 0
	for zombie: ZombieState in zombies:
		if zombie.is_elite and not zombie.dead:
			count += 1
	return count


func _random_spawn_position(arena_rect: Rect2, radius := EnemyCatalog.NORMAL_RADIUS) -> Vector2:
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(520.0, 680.0)
	var position := _team_focus_position() + Vector2.RIGHT.rotated(angle) * distance
	position.x = clampf(position.x, arena_rect.position.x + radius, arena_rect.end.x - radius)
	position.y = clampf(position.y, arena_rect.position.y + radius, arena_rect.end.y - radius)
	return position


func _reposition_far_zombies() -> void:
	var arena_rect := _get_arena_rect()
	for zombie: ZombieState in zombies:
		if _nearest_player_distance_sq(zombie.position) > SpawnDirector.FAR_REPOSITION_DISTANCE_SQ:
			zombie.position = _random_spawn_position(arena_rect, zombie.radius)


func _trim_zombies_to_cap() -> void:
	while zombies.size() > SpawnDirector.MAX_COMMON_ZOMBIES:
		var farthest_index := _farthest_non_elite_zombie_index()
		if farthest_index < 0:
			return
		_remove_zombie_at(farthest_index)


func _farthest_non_elite_zombie_index() -> int:
	var farthest_index := -1
	var farthest_distance := -INF
	for zombie_index in range(zombies.size()):
		if zombies[zombie_index].is_elite:
			continue
		var distance := _nearest_player_distance_sq(zombies[zombie_index].position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_index = zombie_index
	return farthest_index


func _update_zombies(delta: float) -> void:
	var killed_zombies := false
	for zombie: ZombieState in zombies:
		if zombie.dead:
			continue
		var target_player := _closest_alive_player(zombie.position)
		if target_player == null:
			_end_game()
			return
		var to_player: Vector2 = target_player.position - zombie.position
		var distance_sq: float = to_player.length_squared()
		if distance_sq <= 0.0:
			continue
		var distance := sqrt(distance_sq)
		var direction: Vector2 = to_player / distance
		var movement_speed := EnemyCatalog.update_behavior(zombie, delta, rng)
		zombie.position += direction * movement_speed * delta
		var collision_radius := PLAYER_RADIUS + zombie.radius
		if zombie.position.distance_squared_to(target_player.position) <= collision_radius * collision_radius:
			if EnemyCatalog.is_exploder(zombie):
				_explode_zombie(zombie)
				killed_zombies = true
			else:
				target_player.take_damage(zombie.damage * delta)
				zombie.position -= direction * 24.0 * delta
			if _are_all_players_downed():
				_end_game()
				return
	if killed_zombies:
		_remove_dead_zombies()


func _update_revives(delta: float) -> void:
	for active_player in players.values():
		var downed_player := active_player as Player
		if downed_player == null or not downed_player.downed:
			continue
		if _has_reviver_nearby(downed_player):
			var required_time := _revive_required_time(downed_player)
			downed_player.revive_progress = minf(downed_player.revive_progress + delta / required_time, 1.0)
			if downed_player.revive_progress >= 1.0:
				downed_player.revive(REVIVE_HEALTH_RATIO)
				_add_visual_effect(downed_player.position, Color(0.24, 0.92, 0.62, 0.7), 0.3, 20.0, 96.0, "burst")
				_play_feedback_sound("level", 0.18)
			else:
				downed_player.queue_redraw()
		else:
			downed_player.revive_progress = maxf(downed_player.revive_progress - delta * 0.22, 0.0)
			downed_player.queue_redraw()


func _update_weapons(delta: float) -> void:
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player == null or not active_player.is_combat_active():
			continue
		if zombies.is_empty():
			active_player.set_aim_direction(Vector2.RIGHT)
		var loadout = _ensure_player_loadout(int(peer_id))
		var first_new_bullet_index := bullets.size()
		loadout.update(delta, active_player, zombies, bullets, rng)
		relics.prepare_new_bullets(bullets, first_new_bullet_index)
		if bullets.size() > first_new_bullet_index:
			_add_visual_effect(
				active_player.position + active_player.aim_direction * 24.0,
				Color(1.0, 0.82, 0.28, 0.62),
				0.08,
				4.0,
				16.0,
				"flash"
			)
			_play_feedback_sound("shoot", 0.045)


func _update_bullets(delta: float) -> void:
	if bullets.is_empty():
		return

	_rebuild_zombie_grid()
	var killed_zombies := false
	for bullet_index in range(bullets.size() - 1, -1, -1):
		var bullet: BulletState = bullets[bullet_index]
		bullet.position += bullet.velocity * delta
		bullet.lifetime -= delta
		if bullet.lifetime <= 0.0:
			_remove_bullet_at(bullet_index)
			continue

		var remove_bullet := false
		var cell := _collision_cell(bullet.position)
		for cell_x in range(cell.x - 1, cell.x + 2):
			for cell_y in range(cell.y - 1, cell.y + 2):
				var bucket = zombie_grid.get(Vector2i(cell_x, cell_y))
				if bucket == null:
					continue
				for candidate in bucket:
					var zombie := candidate as ZombieState
					if zombie == null or zombie.dead:
						continue
					if bullet.has_hit(zombie):
						continue
					var hit_radius := bullet.radius + zombie.radius
					if bullet.position.distance_squared_to(zombie.position) > hit_radius * hit_radius:
						continue
					bullet.register_hit(zombie)
					_add_visual_effect(
						zombie.position,
						Color(bullet.color.r, bullet.color.g, bullet.color.b, 0.72),
						0.14,
						maxf(bullet.radius * 0.8, 4.0),
						maxf(bullet.radius * 2.7, 11.0),
						"hit"
					)
					_play_feedback_sound("hit", 0.03)
					var damage_source_player := _lowest_hp_alive_player()
					zombie.hp -= relics.damage_for_hit(bullet.damage, damage_source_player if damage_source_player != null else player)
					relics.on_bullet_hit(bullet, zombie.position, bullets, rng)
					if zombie.hp <= 0.0:
						_defeat_zombie(zombie)
						killed_zombies = true
						if _are_all_players_downed():
							_end_game()
							return
					if bullet.should_remove_after_hit():
						remove_bullet = true
						break
				if remove_bullet:
					break
			if remove_bullet:
				break

		if remove_bullet:
			_remove_bullet_at(bullet_index)

	if killed_zombies:
		_remove_dead_zombies()


func _defeat_zombie(zombie: ZombieState) -> void:
	if zombie.dead:
		return
	if EnemyCatalog.is_exploder(zombie):
		if relics.should_empower_exploder_kill():
			_explode_zombie(zombie, false, true)
		else:
			_explode_zombie(zombie)
		return
	_mark_zombie_dead(zombie)


func _explode_zombie(zombie: ZombieState, damages_player := true, damages_enemies := false) -> void:
	if zombie.dead:
		return
	var radius := zombie.explosion_radius
	var damage := zombie.explosion_damage
	if damages_enemies:
		radius *= relics.exploder_blast_radius_multiplier()
		damage *= relics.exploder_blast_damage_multiplier()
	_add_visual_effect(
		zombie.position,
		Color(1.0, 0.42, 0.12, 0.68),
		0.28,
		18.0,
		minf(radius * 0.35, 132.0),
		"burst"
	)
	_play_feedback_sound("boom", 0.16)
	var radius_sq := radius * radius
	if damages_player and radius > 0.0:
		for active_player in players.values():
			var target_player := active_player as Player
			if target_player != null and target_player.is_combat_active() and zombie.position.distance_squared_to(target_player.position) <= radius_sq:
				target_player.take_damage(damage)
	if damages_enemies:
		_mark_zombie_dead(zombie)
		_damage_zombies_in_radius(zombie.position, radius, damage, zombie)
	else:
		_mark_zombie_dead(zombie)


func _damage_zombies_in_radius(center: Vector2, radius: float, damage: float, source_zombie: ZombieState) -> void:
	var radius_sq := radius * radius
	for zombie: ZombieState in zombies:
		if zombie == source_zombie or zombie.dead:
			continue
		if zombie.position.distance_squared_to(center) > radius_sq:
			continue
		zombie.hp -= damage
		if zombie.hp <= 0.0:
			_defeat_zombie(zombie)


func _damage_zombies_from_supply(center: Vector2, radius: float, damage: float) -> void:
	var radius_sq := radius * radius
	var killed_zombies := false
	for zombie: ZombieState in zombies:
		if zombie.dead or zombie.is_elite:
			continue
		if zombie.position.distance_squared_to(center) > radius_sq:
			continue
		zombie.hp -= damage
		if zombie.hp <= 0.0:
			_defeat_zombie(zombie)
			killed_zombies = true
	if killed_zombies:
		_remove_dead_zombies()


func _mark_zombie_dead(zombie: ZombieState) -> void:
	zombie.dead = true
	var death_color := Color(1.0, 0.76, 0.2, 0.7) if zombie.is_elite else Color(0.86, 0.18, 0.12, 0.48)
	_add_visual_effect(zombie.position, death_color, 0.18, zombie.radius * 0.8, zombie.radius * 2.2, "ring")
	xp_orbs.append(XpOrbState.new(zombie.position, zombie.xp_value))
	if zombie.is_elite:
		reward_chests.append(RewardChestState.new(zombie.position))
	kills += 1


func _rebuild_zombie_grid() -> void:
	zombie_grid.clear()
	for zombie: ZombieState in zombies:
		if zombie.dead:
			continue
		var cell := _collision_cell(zombie.position)
		var bucket = zombie_grid.get(cell)
		if bucket == null:
			bucket = []
			zombie_grid[cell] = bucket
		bucket.append(zombie)


func _collision_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / COLLISION_CELL_SIZE), floori(position.y / COLLISION_CELL_SIZE))


func _remove_bullet_at(index: int) -> void:
	var last_index := bullets.size() - 1
	if index != last_index:
		bullets[index] = bullets[last_index]
	bullets.pop_back()


func _remove_dead_zombies() -> void:
	for zombie_index in range(zombies.size() - 1, -1, -1):
		if zombies[zombie_index].dead:
			_remove_zombie_at(zombie_index)


func _remove_zombie_at(index: int) -> void:
	var last_index := zombies.size() - 1
	if index != last_index:
		zombies[index] = zombies[last_index]
	zombies.pop_back()


func _remove_xp_orb_at(index: int) -> void:
	var last_index := xp_orbs.size() - 1
	if index != last_index:
		xp_orbs[index] = xp_orbs[last_index]
	xp_orbs.pop_back()


func _remove_reward_chest_at(index: int) -> void:
	var last_index := reward_chests.size() - 1
	if index != last_index:
		reward_chests[index] = reward_chests[last_index]
	reward_chests.pop_back()


func _remove_supply_cache_at(index: int) -> void:
	var last_index := supply_caches.size() - 1
	if index != last_index:
		supply_caches[index] = supply_caches[last_index]
	supply_caches.pop_back()


func _remove_holdout_event_at(index: int) -> void:
	var last_index := holdout_events.size() - 1
	if index != last_index:
		holdout_events[index] = holdout_events[last_index]
	holdout_events.pop_back()


func _update_feedback_audio(delta: float) -> void:
	if feedback_audio != null:
		feedback_audio.update(delta)


func _play_feedback_sound(sound_id: String, cooldown := 0.04) -> void:
	if feedback_audio != null:
		feedback_audio.play(sound_id, cooldown)


func _update_visual_effects(delta: float) -> void:
	visual_effects.update(delta)


func _add_visual_effect(
	position: Vector2,
	color: Color,
	lifetime: float,
	start_radius: float,
	end_radius: float,
	kind := "ring"
) -> void:
	visual_effects.add(position, color, lifetime, start_radius, end_radius, kind)


func _update_supply_caches(delta: float) -> void:
	if supply_caches.is_empty():
		return
	var pickup_radius := PLAYER_RADIUS + SUPPLY_PICKUP_RADIUS
	var pickup_radius_sq := pickup_radius * pickup_radius
	for supply_index in range(supply_caches.size() - 1, -1, -1):
		var supply = supply_caches[supply_index]
		supply.lifetime -= delta
		if supply.lifetime <= 0.0:
			_remove_supply_cache_at(supply_index)
			continue
		var collecting_player := _first_player_in_radius_sq(supply.position, pickup_radius_sq)
		if collecting_player == null:
			continue
		_apply_supply_cache(supply, collecting_player)
		_remove_supply_cache_at(supply_index)
		if choosing_upgrade:
			return


func _apply_supply_cache(supply, collecting_player: Player) -> void:
	match supply.kind:
		MapEventDirector.SUPPLY_HEAL:
			collecting_player.heal(maxf(45.0, collecting_player.max_hp * 0.35))
			_add_visual_effect(supply.position, Color(0.18, 0.86, 0.45, 0.66), 0.24, 14.0, 54.0, "ring")
			_play_feedback_sound("pickup", 0.05)
		MapEventDirector.SUPPLY_MAGNET:
			_collect_all_xp_orbs(collecting_player)
			_add_visual_effect(supply.position, Color(0.25, 0.78, 1.0, 0.66), 0.24, 14.0, 64.0, "ring")
			_play_feedback_sound("pickup", 0.05)
		MapEventDirector.SUPPLY_BOMB:
			_damage_zombies_from_supply(collecting_player.position, SUPPLY_BOMB_RADIUS, 180.0 + elapsed * 0.08)
			_add_visual_effect(collecting_player.position, Color(1.0, 0.46, 0.16, 0.5), 0.32, 32.0, 150.0, "burst")
			_play_feedback_sound("boom", 0.12)
	_update_hud()


func _collect_all_xp_orbs(collecting_player: Player) -> void:
	if xp_orbs.is_empty():
		return
	var gained_xp := 0
	var gained_heal := 0.0
	for orb: XpOrbState in xp_orbs:
		gained_xp += orb.value
		gained_heal += relics.heal_on_xp_pickup(orb.value)
	xp_orbs.clear()
	xp += gained_xp
	collecting_player.heal(gained_heal)
	_check_level_up()


func _update_holdout_events(delta: float) -> void:
	for event_index in range(holdout_events.size() - 1, -1, -1):
		var event = holdout_events[event_index]
		_update_holdout_event_progress(event, delta)
		if event.is_complete():
			_remove_holdout_event_at(event_index)
			choosing_upgrade = true
			_show_upgrade_choices(UpgradeCatalog.REWARD_CHEST)
			return
		if event.is_expired():
			_remove_holdout_event_at(event_index)


func _update_xp_orbs(delta: float) -> void:
	for orb_index in range(xp_orbs.size() - 1, -1, -1):
		var orb: XpOrbState = xp_orbs[orb_index]
		var collecting_player := _closest_alive_player(orb.position)
		if collecting_player == null:
			return
		var pickup_radius_sq := collecting_player.pickup_radius * collecting_player.pickup_radius
		var to_player: Vector2 = collecting_player.position - orb.position
		var distance_sq: float = to_player.length_squared()
		if distance_sq < PLAYER_XP_COLLISION_RADIUS_SQ:
			xp += orb.value
			collecting_player.heal(relics.heal_on_xp_pickup(orb.value))
			_remove_xp_orb_at(orb_index)
			_play_feedback_sound("pickup", 0.08)
			continue

		if distance_sq < pickup_radius_sq and distance_sq > 0.0:
			var direction: Vector2 = to_player / sqrt(distance_sq)
			orb.position += direction * (260.0 + collecting_player.pickup_radius * 2.0) * delta
	_check_level_up()


func _update_reward_chests() -> void:
	if reward_chests.is_empty():
		return
	var pickup_radius := PLAYER_RADIUS + CHEST_PICKUP_RADIUS
	var pickup_radius_sq := pickup_radius * pickup_radius
	for chest_index in range(reward_chests.size() - 1, -1, -1):
		var chest = reward_chests[chest_index]
		if _first_player_in_radius_sq(chest.position, pickup_radius_sq) == null:
			continue
		_add_visual_effect(chest.position, Color(1.0, 0.8, 0.2, 0.75), 0.28, 18.0, 82.0, "burst")
		_play_feedback_sound("chest", 0.12)
		_remove_reward_chest_at(chest_index)
		choosing_upgrade = true
		_show_upgrade_choices(UpgradeCatalog.REWARD_CHEST)
		return


func _check_level_up() -> void:
	if xp < xp_to_next:
		return
	xp -= xp_to_next
	level += 1
	xp_to_next = int(ceil(float(xp_to_next) * 1.35 + 2.0))
	_add_visual_effect(_team_focus_position(), Color(0.35, 0.95, 1.0, 0.72), 0.34, 26.0, 118.0, "burst")
	_play_feedback_sound("level", 0.18)
	choosing_upgrade = true
	_show_upgrade_choices(UpgradeCatalog.REWARD_LEVEL)


func _show_upgrade_choices(reward_source := UpgradeCatalog.REWARD_LEVEL) -> void:
	choosing_upgrade = true
	upgrade_reward_source = reward_source
	upgrade_selection_timer = UPGRADE_SELECTION_TIME_LIMIT
	upgrade_choices_by_peer.clear()
	upgrade_selected_peer_ids.clear()
	for peer_id in _upgrade_participant_peer_ids():
		upgrade_choices_by_peer[peer_id] = _roll_upgrade_choices_for_peer(peer_id, reward_source)
	_show_current_local_upgrade_choices()
	_broadcast_world_snapshot_now()


func _roll_upgrade_choices_for_peer(peer_id: int, reward_source := UpgradeCatalog.REWARD_LEVEL) -> Array:
	var loadout = _ensure_player_loadout(peer_id)
	var state = _ensure_player_upgrade_state(peer_id)
	if reward_source == UpgradeCatalog.REWARD_CHEST:
		return UpgradeCatalog.roll_chest_choices(rng, loadout, state, relics, level, elapsed, 3)
	return UpgradeCatalog.roll_choices(rng, loadout, state, relics, level, elapsed, 3)


func _update_upgrade_selection(delta: float) -> void:
	if _is_network_client() or not choosing_upgrade:
		return
	if upgrade_selection_timer < 0.0:
		upgrade_selection_timer = UPGRADE_SELECTION_TIME_LIMIT
	upgrade_selection_timer -= delta
	_show_current_local_upgrade_choices()
	if upgrade_selection_timer > 0.0:
		return
	var pending_peer_ids := []
	for peer_id in _upgrade_participant_peer_ids():
		if not upgrade_selected_peer_ids.has(peer_id):
			pending_peer_ids.append(peer_id)
	for peer_id in pending_peer_ids:
		if choosing_upgrade:
			_apply_upgrade_for_peer(int(peer_id), 0)


func _show_current_local_upgrade_choices() -> void:
	if not _has_local_active_player() or not upgrade_choices_by_peer.has(local_peer_id):
		upgrade_overlay.visible = false
		upgrade_choices.clear()
		synced_upgrade_choice_key = ""
		return
	var already_selected := upgrade_selected_peer_ids.has(local_peer_id)
	var hint := _upgrade_hint_for_source(upgrade_reward_source)
	if already_selected:
		hint = "已选择，等待其他玩家确认%s" % _upgrade_timer_suffix()
	_show_local_upgrade_choices(
		_upgrade_title_for_source(upgrade_reward_source),
		hint,
		upgrade_choices_by_peer.get(local_peer_id, []),
		already_selected
	)


func _show_local_upgrade_choices(title: String, hint: String, choices: Array, already_selected: bool) -> void:
	var choice_key := "%s|%s|%s" % [title, _upgrade_choice_key(choices), str(already_selected)]
	if upgrade_overlay.visible and synced_upgrade_choice_key == choice_key:
		upgrade_hint_label.text = hint
		return
	for child in upgrade_buttons_box.get_children():
		child.queue_free()
	upgrade_title_label.text = title
	upgrade_hint_label.text = hint
	upgrade_choices = choices.duplicate(true)
	for i in range(upgrade_choices.size()):
		var upgrade: Dictionary = upgrade_choices[i]
		var button := Button.new()
		button.text = "%d. [%s] %s - %s" % [
			i + 1,
			UpgradeCatalog.rarity_label(upgrade.get("rarity", "common")),
			upgrade["title"],
			upgrade["desc"]
		]
		button.custom_minimum_size = Vector2(360.0, 44.0)
		button.disabled = already_selected
		button.pressed.connect(_choose_upgrade.bind(i))
		upgrade_buttons_box.add_child(button)
	synced_upgrade_choice_key = choice_key
	upgrade_overlay.visible = true


func _choose_upgrade(index: int) -> void:
	if _is_network_client():
		if _has_local_active_player() and network_session != null:
			network_session.send_upgrade_choice(index)
		if upgrade_hint_label != null:
			upgrade_hint_label.text = "已提交选择，等待房主确认" if _has_local_active_player() else "观战中，不能选择升级"
		for child in upgrade_buttons_box.get_children():
			var button := child as Button
			if button != null:
				button.disabled = true
		return
	_apply_upgrade_for_peer(local_peer_id, index)


func _apply_upgrade_for_peer(peer_id: int, index: int) -> void:
	if not choosing_upgrade:
		return
	if not _is_peer_active_in_current_run(peer_id):
		return
	if upgrade_selected_peer_ids.has(peer_id):
		return
	var choices: Array = upgrade_choices_by_peer.get(peer_id, [])
	if index < 0 or index >= choices.size():
		return
	var upgrade: Dictionary = choices[index]
	if not _apply_upgrade_to_peer(peer_id, upgrade):
		upgrade = UpgradeCatalog.FALLBACK_UPGRADE.duplicate(true)
		if not _apply_upgrade_to_peer(peer_id, upgrade):
			return
	match String(upgrade.get("type", "")):
		"weapon_add", "weapon_evolve", "relic":
			_play_feedback_sound("power", 0.16)
		_:
			_play_feedback_sound("upgrade", 0.1)
	upgrade_selected_peer_ids[peer_id] = true
	_show_current_local_upgrade_choices()
	_finish_upgrade_phase_if_complete()
	_broadcast_world_snapshot_now()


func _finish_upgrade_phase_if_complete() -> void:
	if _is_network_client():
		return
	if not choosing_upgrade:
		return
	for peer_id in _upgrade_participant_peer_ids():
		if not upgrade_selected_peer_ids.has(peer_id):
			return
	choosing_upgrade = false
	upgrade_selection_timer = -1.0
	upgrade_overlay.visible = false
	synced_upgrade_choice_key = ""
	upgrade_choices_by_peer.clear()
	upgrade_selected_peer_ids.clear()
	upgrade_choices.clear()
	_update_hud()
	if xp >= xp_to_next:
		_check_level_up()


func _upgrade_title_for_source(reward_source: String) -> String:
	return "打开精英宝箱" if reward_source == UpgradeCatalog.REWARD_CHEST else "选择一个个人强化"


func _upgrade_hint_for_source(reward_source: String) -> String:
	var base := "选择自己的高品质奖励" if reward_source == UpgradeCatalog.REWARD_CHEST else "按 1/2/3 或点击按钮"
	return "%s%s" % [base, _upgrade_timer_suffix()]


func _upgrade_timer_suffix() -> String:
	if upgrade_selection_timer < 0.0:
		return ""
	return "，剩余 %.0f 秒" % ceilf(upgrade_selection_timer)


func _create_ui() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(root)

	hud_label = Label.new()
	hud_label.position = Vector2(20.0, 18.0)
	hud_label.add_theme_color_override("font_color", Color.WHITE)
	hud_label.add_theme_font_size_override("font_size", 18)
	root.add_child(hud_label)

	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(20.0, 52.0)
	hp_bar.size = Vector2(260.0, 18.0)
	hp_bar.show_percentage = false
	root.add_child(hp_bar)

	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(20.0, 78.0)
	xp_bar.size = Vector2(260.0, 16.0)
	xp_bar.show_percentage = false
	root.add_child(xp_bar)

	weapon_label = Label.new()
	weapon_label.position = Vector2(20.0, 102.0)
	weapon_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.92))
	weapon_label.add_theme_font_size_override("font_size", 14)
	root.add_child(weapon_label)

	relic_label = Label.new()
	relic_label.position = Vector2(20.0, 124.0)
	relic_label.add_theme_color_override("font_color", Color(0.88, 0.8, 0.95))
	relic_label.add_theme_font_size_override("font_size", 14)
	root.add_child(relic_label)

	network_status_label = Label.new()
	network_status_label.position = Vector2(930.0, 18.0)
	network_status_label.text = "单人模式"
	network_status_label.add_theme_font_size_override("font_size", 13)
	network_status_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.92))
	root.add_child(network_status_label)

	debug_label = Label.new()
	debug_label.position = Vector2(930.0, 42.0)
	debug_label.custom_minimum_size = Vector2(330.0, 220.0)
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.add_theme_color_override("font_color", Color(0.72, 0.95, 0.78))
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.visible = false
	root.add_child(debug_label)

	version_label = Label.new()
	version_label.text = "v%s  协议 %d" % [GAME_VERSION, NetworkSessionResource.PROTOCOL_VERSION]
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.position = Vector2(-190.0, -28.0)
	version_label.size = Vector2(170.0, 20.0)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.74))
	root.add_child(version_label)

	_create_lobby_overlay(root)

	upgrade_overlay = _make_overlay(root)
	var upgrade_center := CenterContainer.new()
	upgrade_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(upgrade_center)
	var upgrade_panel := PanelContainer.new()
	upgrade_panel.custom_minimum_size = Vector2(460.0, 270.0)
	upgrade_center.add_child(upgrade_panel)
	var upgrade_margin := MarginContainer.new()
	upgrade_margin.add_theme_constant_override("margin_left", 22)
	upgrade_margin.add_theme_constant_override("margin_right", 22)
	upgrade_margin.add_theme_constant_override("margin_top", 18)
	upgrade_margin.add_theme_constant_override("margin_bottom", 18)
	upgrade_panel.add_child(upgrade_margin)
	var upgrade_box := VBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 12)
	upgrade_margin.add_child(upgrade_box)
	upgrade_title_label = Label.new()
	upgrade_title_label.text = "选择一个变异强化"
	upgrade_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title_label.add_theme_font_size_override("font_size", 24)
	upgrade_box.add_child(upgrade_title_label)
	upgrade_hint_label = Label.new()
	upgrade_hint_label.text = "按 1/2/3 或点击按钮"
	upgrade_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_box.add_child(upgrade_hint_label)
	upgrade_buttons_box = VBoxContainer.new()
	upgrade_buttons_box.add_theme_constant_override("separation", 8)
	upgrade_box.add_child(upgrade_buttons_box)

	game_over_overlay = _make_overlay(root)
	var game_over_center := CenterContainer.new()
	game_over_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.add_child(game_over_center)
	var game_over_panel := PanelContainer.new()
	game_over_panel.custom_minimum_size = Vector2(620.0, 340.0)
	game_over_center.add_child(game_over_panel)
	var game_over_margin := MarginContainer.new()
	game_over_margin.add_theme_constant_override("margin_left", 24)
	game_over_margin.add_theme_constant_override("margin_right", 24)
	game_over_margin.add_theme_constant_override("margin_top", 20)
	game_over_margin.add_theme_constant_override("margin_bottom", 20)
	game_over_panel.add_child(game_over_margin)
	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_label.add_theme_font_size_override("font_size", 22)
	game_over_margin.add_child(game_over_label)


func _make_overlay(root: Control) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	overlay.visible = false
	root.add_child(overlay)
	return overlay


func _create_lobby_overlay(root: Control) -> void:
	lobby_overlay = _make_overlay(root)
	lobby_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	lobby_overlay.visible = true

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 705.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	lobby_title_label = Label.new()
	lobby_title_label.text = "作战大厅"
	lobby_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_title_label.add_theme_font_size_override("font_size", 28)
	box.add_child(lobby_title_label)

	lobby_status_label = Label.new()
	lobby_status_label.text = "选择单人开始，或开房等待队友加入。"
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lobby_status_label)

	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", 8)
	box.add_child(address_row)

	network_ip_input = LineEdit.new()
	network_ip_input.text = "127.0.0.1"
	network_ip_input.placeholder_text = "房主 IP"
	network_ip_input.custom_minimum_size = Vector2(300.0, 32.0)
	address_row.add_child(network_ip_input)

	network_port_spin_box = SpinBox.new()
	network_port_spin_box.min_value = 1024
	network_port_spin_box.max_value = 65535
	network_port_spin_box.value = NetworkSessionResource.DEFAULT_PORT
	network_port_spin_box.custom_minimum_size = Vector2(120.0, 32.0)
	address_row.add_child(network_port_spin_box)

	var network_row := HBoxContainer.new()
	network_row.add_theme_constant_override("separation", 8)
	box.add_child(network_row)

	lobby_single_button = Button.new()
	lobby_single_button.text = "单人开始"
	lobby_single_button.pressed.connect(_start_offline_game)
	network_row.add_child(lobby_single_button)

	lobby_host_button = Button.new()
	lobby_host_button.text = "开房"
	lobby_host_button.pressed.connect(_host_lan_game)
	network_row.add_child(lobby_host_button)

	lobby_join_button = Button.new()
	lobby_join_button.text = "加入"
	lobby_join_button.pressed.connect(_join_lan_game)
	network_row.add_child(lobby_join_button)

	lobby_discovery_button = Button.new()
	lobby_discovery_button.text = "搜索房间"
	lobby_discovery_button.pressed.connect(_search_lan_rooms)
	network_row.add_child(lobby_discovery_button)

	lobby_leave_button = Button.new()
	lobby_leave_button.text = "退出房间"
	lobby_leave_button.pressed.connect(_use_offline_mode)
	network_row.add_child(lobby_leave_button)

	lobby_discovery_label = Label.new()
	lobby_discovery_label.text = "未搜索房间"
	lobby_discovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_discovery_label.custom_minimum_size = Vector2(500.0, 44.0)
	box.add_child(lobby_discovery_label)

	var ready_row := HBoxContainer.new()
	ready_row.add_theme_constant_override("separation", 8)
	box.add_child(ready_row)

	lobby_ready_button = Button.new()
	lobby_ready_button.text = "准备"
	lobby_ready_button.pressed.connect(_toggle_lobby_ready)
	ready_row.add_child(lobby_ready_button)

	lobby_start_button = Button.new()
	lobby_start_button.text = "开始游戏"
	lobby_start_button.pressed.connect(_start_lobby_game)
	ready_row.add_child(lobby_start_button)

	lobby_players_label = Label.new()
	lobby_players_label.text = ""
	lobby_players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_players_label.custom_minimum_size = Vector2(540.0, 300.0)
	box.add_child(lobby_players_label)


func _setup_network_session() -> void:
	network_session = NetworkSessionResource.new()
	network_session.name = "NetworkSession"
	add_child(network_session)
	network_session.mode_changed.connect(_on_network_mode_changed)
	network_session.peer_joined.connect(_on_network_peer_joined)
	network_session.peer_left.connect(_on_network_peer_left)
	network_session.world_snapshot_received.connect(_on_world_snapshot_received)
	network_session.upgrade_choice_received.connect(_on_network_upgrade_choice_received)
	network_session.restart_requested.connect(_on_network_restart_requested)
	network_session.lobby_ready_received.connect(_on_network_lobby_ready_received)
	network_session.game_start_received.connect(_on_network_game_start_received)
	network_session.protocol_accepted.connect(_on_network_protocol_accepted)
	network_session.protocol_rejected.connect(_on_network_protocol_rejected)
	network_session.discovered_rooms_changed.connect(_on_discovered_rooms_changed)


func _setup_player() -> void:
	player = get_node_or_null("Player") as Player
	if player == null:
		player = PLAYER_SCENE.instantiate() as Player
		add_child(player)
	player.name = "Player_%d" % SERVER_PEER_ID
	players.clear()
	player_weapon_loadouts.clear()
	player_upgrade_states.clear()
	players[SERVER_PEER_ID] = player
	player.set_display_color(_player_color(SERVER_PEER_ID))
	_ensure_player_loadout(SERVER_PEER_ID)
	_ensure_player_upgrade_state(SERVER_PEER_ID)
	_refresh_player_identity_markers()


func _setup_feedback_audio() -> void:
	feedback_audio = FeedbackAudioResource.new()
	add_child(feedback_audio)


func _is_network_client() -> bool:
	return network_session != null and network_session.is_client()


func _refresh_network_state() -> void:
	if game_over:
		network_state = NET_STATE_RESULTS
		return
	if network_session == null:
		network_state = NET_STATE_OFFLINE_RUNNING if run_started else NET_STATE_OFFLINE_LOBBY
		return
	if network_session.is_offline():
		network_state = NET_STATE_OFFLINE_RUNNING if run_started else NET_STATE_OFFLINE_LOBBY
	elif network_session.is_host():
		network_state = NET_STATE_HOST_RUNNING if run_started else NET_STATE_HOST_LOBBY
	elif network_session.is_client():
		if not run_started:
			network_state = NET_STATE_CLIENT_LOBBY
		elif waiting_peer_ids.has(local_peer_id):
			network_state = NET_STATE_CLIENT_RUNNING_SPECTATOR
		else:
			network_state = NET_STATE_CLIENT_RUNNING_ACTIVE
	else:
		network_state = NET_STATE_DISCONNECTED


func _is_lobby_state() -> bool:
	return network_state == NET_STATE_OFFLINE_LOBBY or network_state == NET_STATE_HOST_LOBBY or network_state == NET_STATE_CLIENT_LOBBY or network_state == NET_STATE_DISCONNECTED


func _can_submit_game_input() -> bool:
	return network_state == NET_STATE_OFFLINE_RUNNING or network_state == NET_STATE_HOST_RUNNING or network_state == NET_STATE_CLIENT_RUNNING_ACTIVE


func _has_local_active_player() -> bool:
	return players.has(local_peer_id) and not waiting_peer_ids.has(local_peer_id)


func _update_room_advertisement_state() -> void:
	if network_session == null or not network_session.is_host():
		return
	var room_state := "running" if run_started else "lobby"
	network_session.update_room_advertisement(room_state, players.size())


func _is_peer_active_in_current_run(peer_id: int) -> bool:
	return run_started and players.has(peer_id) and not waiting_peer_ids.has(peer_id)


func _is_peer_participant(peer_id: int) -> bool:
	return run_participant_peer_ids.has(peer_id)


func _update_debug_overlay() -> void:
	if debug_label == null:
		return
	debug_label.visible = debug_overlay_visible
	if not debug_overlay_visible:
		return
	debug_label.text = _debug_overlay_text()


func _debug_overlay_text() -> String:
	var mode: String = network_session.mode if network_session != null else "none"
	var peer_count: int = network_session.connected_peer_ids().size() if network_session != null else 1
	var local_status := "观战" if waiting_peer_ids.has(local_peer_id) else "参战"
	if player != null and player.downed:
		local_status = "倒地"
	var ms_since_snapshot := 0
	if int(snapshot_debug.get("last_received_msec", 0)) > 0:
		ms_since_snapshot = Time.get_ticks_msec() - int(snapshot_debug["last_received_msec"])
	return (
		"F3 联机调试\n"
		+ "state: %s\n" % network_state
		+ "mode: %s  peer: %d/%d\n" % [mode, local_peer_id, peer_count]
		+ "local: %s\n" % local_status
		+ "active: %s\n" % _debug_peer_list(players.keys())
		+ "participants: %s\n" % _debug_peer_list(run_participant_peer_ids.keys())
		+ "waiting: %s\n" % _debug_peer_list(waiting_peer_ids.keys())
		+ "ready: %s\n" % _debug_ready_list()
		+ "auto start: %.1f\n" % lobby_auto_start_timer
		+ "upgrade timer: %.1f\n" % upgrade_selection_timer
		+ "entities: P%d Z%d B%d XP%d\n" % [players.size(), zombies.size(), bullets.size(), xp_orbs.size()]
		+ "snapshot: %d bytes  recv %d  sent %d  age %dms\n" % [
			int(snapshot_debug.get("last_size", 0)),
			int(snapshot_debug.get("received_count", 0)),
			int(snapshot_debug.get("sent_count", 0)),
			ms_since_snapshot
		]
	)


func _debug_peer_list(peer_ids) -> String:
	var parts := []
	for peer_id in peer_ids:
		parts.append(str(int(peer_id)))
	return ",".join(parts) if not parts.is_empty() else "-"


func _debug_ready_list() -> String:
	var parts := []
	for peer_id in lobby_ready.keys():
		parts.append("%d:%s" % [int(peer_id), "Y" if bool(lobby_ready[peer_id]) else "N"])
	parts.sort()
	return ",".join(parts) if not parts.is_empty() else "-"


func _update_client_network(delta: float) -> void:
	_send_local_input(delta)
	if _has_local_active_player() and player != null and not game_over and not choosing_upgrade:
		player.update_movement_from_input(delta, _get_arena_rect(), player.read_local_input_state())


func _send_local_input(delta: float) -> void:
	if network_session == null or player == null:
		return
	if not _can_submit_game_input():
		return
	if network_session.is_client():
		network_input_timer -= delta
		if network_input_timer > 0.0:
			return
		network_input_timer = NETWORK_INPUT_INTERVAL
		if network_session.mode == NetworkSessionResource.MODE_CLIENT:
			network_session.send_player_input(player.read_local_input_state())
		return
	network_session.send_player_input(player.read_local_input_state())


func _update_network_snapshot(delta: float) -> void:
	if network_session == null or not network_session.is_host():
		return
	world_snapshot_timer -= delta
	if world_snapshot_timer > 0.0:
		return
	world_snapshot_timer = WORLD_SNAPSHOT_INTERVAL
	_broadcast_world_snapshot_now()


func _broadcast_world_snapshot_now() -> void:
	if network_session == null or not network_session.is_host():
		return
	world_snapshot_timer = WORLD_SNAPSHOT_INTERVAL
	var snapshot := _make_world_snapshot()
	snapshot_debug["last_size"] = str(snapshot).to_utf8_buffer().size()
	snapshot_debug["sent_count"] = int(snapshot_debug.get("sent_count", 0)) + 1
	network_session.broadcast_world_snapshot(snapshot)


func _update_lobby_network(delta: float) -> void:
	_update_lobby_auto_start(delta)
	if network_session != null and network_session.is_host():
		world_snapshot_timer -= delta
		if world_snapshot_timer <= 0.0:
			_broadcast_world_snapshot_now()
	_update_lobby_ui()


func _update_lobby_auto_start(delta: float) -> void:
	if network_session == null or not network_session.is_host() or run_started:
		return
	if not _all_lobby_players_ready():
		_cancel_lobby_auto_start()
		return
	if lobby_auto_start_timer < 0.0:
		lobby_auto_start_timer = LOBBY_AUTO_START_DELAY
		_broadcast_world_snapshot_now()
		return
	lobby_auto_start_timer -= delta
	if lobby_auto_start_timer <= 0.0:
		lobby_auto_start_timer = -1.0
		_start_run_from_lobby(true)


func _cancel_lobby_auto_start() -> void:
	if lobby_auto_start_timer >= 0.0:
		lobby_auto_start_timer = -1.0


func _request_restart() -> void:
	if network_session != null:
		network_session.request_restart()
	else:
		_restart_game()


func _use_offline_mode() -> void:
	local_peer_id = SERVER_PEER_ID
	network_session.use_offline_mode()
	for peer_id in players.keys().duplicate():
		if int(peer_id) != SERVER_PEER_ID:
			_remove_player(int(peer_id))
	waiting_peer_ids.clear()
	player = _ensure_player(SERVER_PEER_ID)
	_enter_lobby()


func _enter_lobby() -> void:
	run_started = false
	game_over = false
	choosing_upgrade = false
	lobby_auto_start_timer = -1.0
	local_run_recorded = false
	run_participant_peer_ids.clear()
	_clear_network_view_state()
	if not players.has(SERVER_PEER_ID):
		_ensure_player(SERVER_PEER_ID)
	for peer_id in waiting_peer_ids.keys():
		_ensure_player(int(peer_id))
	waiting_peer_ids.clear()
	lobby_ready.clear()
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player != null:
			active_player.reset(_spawn_position_for_peer(int(peer_id)), selected_character)
		lobby_ready[int(peer_id)] = false
	player = players.get(local_peer_id, players.get(SERVER_PEER_ID, player)) as Player
	_refresh_player_identity_markers()
	if lobby_overlay != null:
		lobby_overlay.visible = true
	if game_over_overlay != null:
		game_over_overlay.visible = false
	if upgrade_overlay != null:
		upgrade_overlay.visible = false
	_update_lobby_ui()
	_update_hud()


func _start_offline_game() -> void:
	if network_session != null and not network_session.is_offline():
		network_session.use_offline_mode()
	local_peer_id = SERVER_PEER_ID
	for peer_id in players.keys().duplicate():
		if int(peer_id) != SERVER_PEER_ID:
			_remove_player(int(peer_id))
	waiting_peer_ids.clear()
	lobby_ready.clear()
	lobby_ready[SERVER_PEER_ID] = true
	lobby_auto_start_timer = -1.0
	_start_run_from_lobby(false)


func _toggle_lobby_ready() -> void:
	var peer_id := local_peer_id
	var next_ready := not bool(lobby_ready.get(peer_id, false))
	if network_session != null:
		network_session.send_lobby_ready(next_ready)
	else:
		_on_network_lobby_ready_received(peer_id, next_ready)


func _start_lobby_game() -> void:
	if network_session != null and network_session.is_client():
		return
	if not _all_lobby_players_ready():
		if lobby_status_label != null:
			lobby_status_label.text = "还有队员未准备。"
		return
	_start_run_from_lobby(network_session != null and network_session.is_host())


func _start_run_from_lobby(should_broadcast_start: bool) -> void:
	run_started = true
	lobby_auto_start_timer = -1.0
	local_run_recorded = false
	waiting_peer_ids.clear()
	_set_run_participants_from_current_players()
	if lobby_overlay != null:
		lobby_overlay.visible = false
	if should_broadcast_start and network_session != null:
		network_session.broadcast_game_start()
	_restart_game()
	_broadcast_world_snapshot_now()


func _host_lan_game() -> void:
	local_peer_id = SERVER_PEER_ID
	var port := int(network_port_spin_box.value) if network_port_spin_box != null else NetworkSessionResource.DEFAULT_PORT
	var error = network_session.host_game(port)
	if error == OK:
		if network_status_label != null:
			network_status_label.text = "%s  IP %s" % [network_session.status_text, _lan_address_hint()]
		player = _ensure_player(SERVER_PEER_ID)
		run_started = false
		waiting_peer_ids.clear()
		lobby_ready.clear()
		lobby_ready[SERVER_PEER_ID] = false
		lobby_auto_start_timer = -1.0
		_clear_network_view_state()
		_refresh_player_identity_markers()
		_update_lobby_ui()
		_broadcast_world_snapshot_now()


func _join_lan_game() -> void:
	var address := network_ip_input.text.strip_edges() if network_ip_input != null else "127.0.0.1"
	if address.is_empty():
		address = "127.0.0.1"
	var port := int(network_port_spin_box.value) if network_port_spin_box != null else NetworkSessionResource.DEFAULT_PORT
	var error = network_session.join_game(address, port)
	if error != OK:
		return
	local_peer_id = network_session.local_peer_id()
	player = _ensure_player(local_peer_id)
	run_started = false
	lobby_auto_start_timer = -1.0
	_clear_network_view_state()
	_refresh_player_identity_markers()
	_update_lobby_ui()


func _on_network_mode_changed(_mode: String, status: String) -> void:
	if network_status_label != null:
		network_status_label.text = status
	local_peer_id = network_session.local_peer_id() if network_session != null else SERVER_PEER_ID
	if _mode == NetworkSessionResource.MODE_OFFLINE:
		local_peer_id = SERVER_PEER_ID
		for peer_id in players.keys().duplicate():
			if int(peer_id) != SERVER_PEER_ID:
				_remove_player(int(peer_id))
		player = _ensure_player(SERVER_PEER_ID)
		_enter_lobby()
	elif network_session != null and network_session.is_client():
		player = _ensure_player(local_peer_id)
		lobby_ready[local_peer_id] = false
		run_started = false
		lobby_auto_start_timer = -1.0
		if lobby_overlay != null:
			lobby_overlay.visible = true
	else:
		local_peer_id = SERVER_PEER_ID
		player = _ensure_player(SERVER_PEER_ID)
		if not run_started:
			lobby_ready[SERVER_PEER_ID] = bool(lobby_ready.get(SERVER_PEER_ID, false))
	_refresh_player_identity_markers()
	_update_lobby_ui()


func _on_network_peer_joined(peer_id: int) -> void:
	if not run_started:
		_ensure_player(peer_id)
		lobby_ready[peer_id] = false
		_cancel_lobby_auto_start()
		_refresh_player_identity_markers()
		_update_lobby_ui()
		_broadcast_world_snapshot_now()
	else:
		waiting_peer_ids[peer_id] = true
		if network_status_label != null:
			network_status_label.text = "玩家 %d 正在观战，下一局加入" % peer_id
		_broadcast_world_snapshot_now()
	world_snapshot_timer = 0.0
	_update_hud()


func _on_network_peer_left(peer_id: int) -> void:
	if players.has(peer_id):
		_remove_player(peer_id)
	waiting_peer_ids.erase(peer_id)
	lobby_ready.erase(peer_id)
	_cancel_lobby_auto_start()
	_finish_upgrade_phase_if_complete()
	_refresh_player_identity_markers()
	_update_lobby_ui()
	_broadcast_world_snapshot_now()
	_update_hud()


func _on_world_snapshot_received(snapshot: Dictionary) -> void:
	if not _is_network_client():
		return
	_apply_world_snapshot(snapshot)


func _on_network_upgrade_choice_received(peer_id: int, choice_index: int) -> void:
	if network_session != null and network_session.is_client():
		return
	if not choosing_upgrade:
		return
	if not _is_peer_active_in_current_run(peer_id):
		return
	_apply_upgrade_for_peer(peer_id, choice_index)
	if network_status_label != null and network_session != null and network_session.is_host():
		network_status_label.text = "玩家 %d 选择了升级" % peer_id


func _on_network_restart_requested(_peer_id: int) -> void:
	if network_session != null and network_session.is_client():
		return
	if not game_over:
		return
	_enter_lobby()
	_broadcast_world_snapshot_now()


func _on_network_lobby_ready_received(peer_id: int, is_ready: bool) -> void:
	if run_started:
		return
	if network_session != null and network_session.is_client():
		return
	_ensure_player(peer_id)
	_refresh_player_identity_markers()
	lobby_ready[peer_id] = is_ready
	_cancel_lobby_auto_start()
	_update_lobby_ui()
	_broadcast_world_snapshot_now()


func _on_network_game_start_received() -> void:
	run_started = true
	if lobby_overlay != null:
		lobby_overlay.visible = false
	_clear_network_view_state()


func _on_network_protocol_accepted() -> void:
	if lobby_status_label != null:
		lobby_status_label.text = "协议校验通过，等待房主同步大厅。"
	_refresh_network_state()
	_update_lobby_ui()


func _on_network_protocol_rejected(reason: String) -> void:
	_enter_lobby()
	if lobby_status_label != null:
		lobby_status_label.text = reason


func _ensure_player(peer_id: int) -> Player:
	if players.has(peer_id):
		return players[peer_id] as Player
	var new_player := PLAYER_SCENE.instantiate() as Player
	new_player.name = "Player_%d" % peer_id
	add_child(new_player)
	players[peer_id] = new_player
	new_player.reset(_spawn_position_for_peer(peer_id), selected_character)
	new_player.set_display_color(_player_color(peer_id))
	_ensure_player_loadout(peer_id)
	_ensure_player_upgrade_state(peer_id)
	return new_player


func _remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	var old_player := players[peer_id] as Player
	players.erase(peer_id)
	player_weapon_loadouts.erase(peer_id)
	player_upgrade_states.erase(peer_id)
	upgrade_choices_by_peer.erase(peer_id)
	upgrade_selected_peer_ids.erase(peer_id)
	if old_player != null and old_player != player:
		old_player.queue_free()
	if player == old_player:
		player = _first_player()


func _ensure_player_loadout(peer_id: int):
	if player_weapon_loadouts.has(peer_id):
		return player_weapon_loadouts[peer_id]
	var loadout := WeaponLoadout.new()
	loadout.reset(selected_starting_weapon)
	player_weapon_loadouts[peer_id] = loadout
	return loadout


func _ensure_player_upgrade_state(peer_id: int):
	if player_upgrade_states.has(peer_id):
		return player_upgrade_states[peer_id]
	var state := UpgradeState.new()
	player_upgrade_states[peer_id] = state
	return state


func _player_color(peer_id: int) -> Color:
	var slot := _player_visual_slot(peer_id)
	return PLAYER_COLORS[slot % PLAYER_COLORS.size()]


func _player_visual_slot(peer_id: int) -> int:
	var peer_ids := []
	for active_peer_id in players.keys():
		peer_ids.append(int(active_peer_id))
	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)
	peer_ids.sort()
	return max(peer_ids.find(peer_id), 0)


func _refresh_player_identity_markers() -> void:
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player == null:
			continue
		var peer_int := int(peer_id)
		var slot := _player_visual_slot(peer_int)
		active_player.set_display_color(_player_color(peer_int))
		active_player.set_identity_label(_player_identity_label(peer_int, slot), peer_int == local_peer_id)


func _player_identity_label(peer_id: int, slot: int) -> String:
	var label := "P%d" % (slot + 1)
	if peer_id == local_peer_id:
		return "你 %s" % label
	if peer_id == SERVER_PEER_ID:
		return "房主 %s" % label
	return label


func _spawn_position_for_peer(peer_id: int) -> Vector2:
	var offsets := [
		Vector2.ZERO,
		Vector2(58.0, 0.0),
		Vector2(29.0, 50.0),
		Vector2(-29.0, 50.0),
		Vector2(-58.0, 0.0),
		Vector2(-29.0, -50.0),
		Vector2(29.0, -50.0),
		Vector2(118.0, 0.0),
		Vector2(83.0, 83.0),
		Vector2(0.0, 118.0),
		Vector2(-83.0, 83.0),
		Vector2(-118.0, 0.0),
		Vector2(-83.0, -83.0),
		Vector2(0.0, -118.0),
		Vector2(83.0, -83.0)
	]
	var slot := _player_visual_slot(peer_id) % offsets.size()
	return _get_arena_rect().get_center() + offsets[slot]


func _first_player() -> Player:
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player != null:
			return typed_player
	return null


func _closest_alive_player(position: Vector2) -> Player:
	var closest_player: Player = null
	var closest_distance := INF
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player == null or not typed_player.is_combat_active():
			continue
		var distance := typed_player.position.distance_squared_to(position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = typed_player
	return closest_player


func _lowest_hp_alive_player() -> Player:
	var lowest_player: Player = null
	var lowest_ratio := INF
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player == null or not typed_player.is_combat_active():
			continue
		var ratio := typed_player.hp / maxf(typed_player.max_hp, 1.0)
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			lowest_player = typed_player
	return lowest_player


func _nearest_player_distance_sq(position: Vector2) -> float:
	var closest_player := _closest_alive_player(position)
	if closest_player == null:
		return INF
	return closest_player.position.distance_squared_to(position)


func _team_focus_position() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player == null or not typed_player.is_combat_active():
			continue
		total += typed_player.position
		count += 1
	if count > 0:
		return total / float(count)
	if player != null:
		return player.position
	return _get_arena_rect().get_center()


func _first_player_in_radius_sq(position: Vector2, radius_sq: float) -> Player:
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player != null and typed_player.is_combat_active() and typed_player.position.distance_squared_to(position) <= radius_sq:
			return typed_player
	return null


func _are_all_players_downed() -> bool:
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player != null and typed_player.is_combat_active():
			return false
	return true


func _has_reviver_nearby(downed_player: Player) -> bool:
	for active_player in players.values():
		var reviver := active_player as Player
		if reviver == null or reviver == downed_player or not reviver.is_combat_active():
			continue
		if reviver.position.distance_squared_to(downed_player.position) <= REVIVE_RADIUS_SQ:
			return true
	return false


func _revive_required_time(downed_player: Player) -> float:
	return REVIVE_BASE_TIME + maxf(float(downed_player.down_count - 1), 0.0) * REVIVE_DOWN_PENALTY


func _lowest_player_hp_ratio() -> float:
	var lowest_ratio := 1.0
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player == null:
			continue
		lowest_ratio = minf(lowest_ratio, typed_player.hp / maxf(typed_player.max_hp, 1.0))
	return clampf(lowest_ratio, 0.0, 1.0)


func _is_any_player_inside_holdout(event) -> bool:
	for active_player in players.values():
		var typed_player := active_player as Player
		if typed_player != null and typed_player.is_combat_active() and event.is_player_inside(typed_player.position):
			return true
	return false


func _update_holdout_event_progress(event, delta: float) -> void:
	event.lifetime -= delta
	if _is_any_player_inside_holdout(event):
		event.progress = minf(event.progress + delta, event.required_time)
	else:
		event.progress = maxf(event.progress - delta * 0.35, 0.0)


func _upgrade_participant_peer_ids() -> Array:
	var peer_ids := []
	for peer_id in run_participant_peer_ids.keys():
		var peer_int := int(peer_id)
		if players.has(peer_int) and not waiting_peer_ids.has(peer_int):
			peer_ids.append(peer_int)
	peer_ids.sort()
	return peer_ids


func _apply_upgrade_to_peer(peer_id: int, upgrade: Dictionary) -> bool:
	var target_player := players.get(peer_id, null) as Player
	if target_player == null:
		return false
	return UpgradeCatalog.apply_upgrade(
		upgrade,
		target_player,
		_ensure_player_loadout(peer_id),
		_ensure_player_upgrade_state(peer_id),
		relics
	)


func _upgrade_choice_key(choices: Array) -> String:
	var key := ""
	for option in choices:
		var upgrade := option as Dictionary
		if upgrade == null:
			continue
		key += "%s:%s|" % [upgrade.get("id", ""), upgrade.get("title", "")]
	return key


func _player_count_pressure_multiplier() -> float:
	var extra_players := maxf(float(players.size() - 1), 0.0)
	var early_scale := minf(extra_players, 5.0) * 0.35
	var high_count_scale := maxf(extra_players - 5.0, 0.0) * 0.16
	return 1.0 + early_scale + high_count_scale


func _scaled_elapsed_for_player_count() -> float:
	return elapsed * _player_count_pressure_multiplier()


func _lan_address_hint() -> String:
	var fallback := "127.0.0.1"
	for address in IP.get_local_addresses():
		var value := String(address)
		if _is_private_lan_ipv4(value):
			return value
		if value.find(".") >= 0 and not value.begins_with("127."):
			fallback = value
	return fallback


func _is_private_lan_ipv4(address: String) -> bool:
	if address.begins_with("192.168.") or address.begins_with("10."):
		return true
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	if parts.size() < 2:
		return false
	var second_octet := int(parts[1])
	return second_octet >= 16 and second_octet <= 31


func _search_lan_rooms() -> void:
	if network_session == null:
		return
	var error: Error = network_session.start_room_discovery()
	if error != OK:
		if lobby_discovery_label != null:
			lobby_discovery_label.text = "搜索失败：UDP 端口 %d 不可用（错误 %s）" % [NetworkSessionResource.DISCOVERY_PORT, error]
		return
	_apply_first_discovered_room_to_inputs()
	_update_discovery_ui()


func _on_discovered_rooms_changed() -> void:
	_apply_first_discovered_room_to_inputs()
	_update_discovery_ui()


func _apply_first_discovered_room_to_inputs() -> void:
	if network_session == null:
		return
	var room: Dictionary = network_session.first_discovered_room()
	if room.is_empty():
		return
	if network_ip_input != null:
		network_ip_input.text = String(room.get("address", network_ip_input.text))
	if network_port_spin_box != null:
		network_port_spin_box.value = int(room.get("port", NetworkSessionResource.DEFAULT_PORT))


func _update_discovery_ui() -> void:
	if lobby_discovery_label == null or network_session == null:
		return
	var rooms: Array = network_session.discovered_room_list()
	if rooms.is_empty():
		if network_session.is_room_discovery_active():
			lobby_discovery_label.text = "正在搜索局域网房间..."
		else:
			lobby_discovery_label.text = "未搜索房间"
		return
	var lines := ["发现房间"]
	for room in rooms:
		var state_text := _room_state_text(String(room.get("room_state", "lobby")))
		lines.append("%s:%d  %s  %d/%d" % [
			String(room.get("address", "")),
			int(room.get("port", NetworkSessionResource.DEFAULT_PORT)),
			state_text,
			int(room.get("player_count", 1)),
			int(room.get("max_players", NetworkSessionResource.MAX_PLAYERS))
		])
	lines.append("已自动填入第一个房间，点击加入。")
	lobby_discovery_label.text = "\n".join(lines)


func _room_state_text(room_state: String) -> String:
	return "游戏中" if room_state == "running" else "大厅"


func _update_lobby_ui() -> void:
	if lobby_overlay == null:
		return
	var in_network_session: bool = network_session != null and not network_session.is_offline()
	var is_client: bool = network_session != null and network_session.is_client()
	var is_host: bool = network_session != null and network_session.is_host()
	var local_ready := bool(lobby_ready.get(local_peer_id, false))
	var can_ready: bool = not run_started and (is_host or network_session == null or network_session.is_offline() or network_session.mode == NetworkSessionResource.MODE_CLIENT)
	lobby_overlay.visible = not run_started
	if lobby_status_label != null:
		lobby_status_label.text = _lobby_status_text(is_host, is_client)
	if lobby_ready_button != null:
		lobby_ready_button.visible = in_network_session
		lobby_ready_button.disabled = not can_ready
		lobby_ready_button.text = "取消准备" if local_ready else "准备"
	if lobby_start_button != null:
		lobby_start_button.visible = false
		lobby_start_button.disabled = true
	if lobby_single_button != null:
		lobby_single_button.disabled = in_network_session
	if lobby_host_button != null:
		lobby_host_button.disabled = in_network_session
	if lobby_join_button != null:
		lobby_join_button.disabled = in_network_session
	if lobby_discovery_button != null:
		lobby_discovery_button.disabled = in_network_session
		lobby_discovery_button.text = "刷新房间" if network_session != null and network_session.is_room_discovery_active() else "搜索房间"
	if lobby_leave_button != null:
		lobby_leave_button.visible = in_network_session
	if lobby_discovery_label != null:
		lobby_discovery_label.visible = not in_network_session
		_update_discovery_ui()
	if lobby_players_label != null:
		lobby_players_label.text = _lobby_players_text()
	if network_status_label != null:
		if is_host:
			network_status_label.text = "大厅：房主  IP %s" % _lan_address_hint()
		elif is_client:
			network_status_label.text = "大厅：%s" % network_session.status_text
		else:
			network_status_label.text = "大厅：单人"


func _lobby_status_text(is_host: bool, is_client: bool) -> String:
	if is_host:
		if lobby_auto_start_timer >= 0.0:
			return "全员已准备，%.1f 秒后自动开始。" % maxf(lobby_auto_start_timer, 0.0)
		return "房间 IP %s  端口 %d，已广播房间，所有玩家准备后自动开始。" % [_lan_address_hint(), int(network_port_spin_box.value)]
	if is_client:
		if lobby_auto_start_timer >= 0.0:
			return "全员已准备，等待房主自动开局 %.1f 秒。" % maxf(lobby_auto_start_timer, 0.0)
		return network_session.status_text
	return "选择单人开始，或开房等待队友加入。"


func _lobby_players_text() -> String:
	var lines := ["队伍"]
	for peer_id in _lobby_player_ids():
		var peer_int := int(peer_id)
		var label := "P%d" % (_player_visual_slot(peer_int) + 1)
		if peer_int == SERVER_PEER_ID:
			label += " 房主"
		elif peer_int != local_peer_id:
			label += " 玩家 %d" % peer_int
		if peer_int == local_peer_id:
			label += " 你"
		var ready_text := "已准备" if bool(lobby_ready.get(int(peer_id), false)) else "未准备"
		lines.append("%s  %s" % [label, ready_text])
	if lines.size() == 1:
		lines.append("尚未创建房间")
	if network_session != null and network_session.is_host() and lobby_auto_start_timer >= 0.0:
		lines.append("")
		lines.append("即将自动开始。")
	elif network_session != null and network_session.is_host() and not _all_lobby_players_ready():
		lines.append("")
		lines.append("所有玩家准备后自动开始。")
	return "\n".join(lines)


func _lobby_player_ids() -> Array:
	var peer_ids := []
	for peer_id in players.keys():
		peer_ids.append(int(peer_id))
	peer_ids.sort()
	return peer_ids


func _all_lobby_players_ready() -> bool:
	var peer_ids := _lobby_player_ids()
	if peer_ids.is_empty():
		return false
	for peer_id in peer_ids:
		if not bool(lobby_ready.get(int(peer_id), false)):
			return false
	return true


func _serialize_lobby_ready() -> Dictionary:
	var ready_data := {}
	for peer_id in lobby_ready.keys():
		ready_data[str(peer_id)] = bool(lobby_ready[peer_id])
	return ready_data


func _apply_lobby_ready_snapshot(ready_data) -> void:
	if not (ready_data is Dictionary):
		return
	lobby_ready.clear()
	for peer_key in ready_data.keys():
		lobby_ready[int(str(peer_key))] = bool(ready_data[peer_key])


func _serialize_waiting_peer_ids() -> Array:
	var ids := []
	for peer_id in waiting_peer_ids.keys():
		ids.append(int(peer_id))
	return ids


func _serialize_run_participant_peer_ids() -> Array:
	var ids := []
	for peer_id in run_participant_peer_ids.keys():
		ids.append(int(peer_id))
	ids.sort()
	return ids


func _set_run_participants_from_current_players() -> void:
	run_participant_peer_ids.clear()
	for peer_id in players.keys():
		run_participant_peer_ids[int(peer_id)] = true


func _apply_run_participant_peer_ids_snapshot(participant_data) -> void:
	run_participant_peer_ids.clear()
	if not (participant_data is Array):
		return
	for peer_id in participant_data:
		run_participant_peer_ids[int(peer_id)] = true


func _serialize_upgrade_choices_by_peer() -> Dictionary:
	var data := {}
	for peer_id in upgrade_choices_by_peer.keys():
		data[str(peer_id)] = upgrade_choices_by_peer[peer_id]
	return data


func _apply_upgrade_choices_by_peer_snapshot(raw_data) -> void:
	upgrade_choices_by_peer.clear()
	if not (raw_data is Dictionary):
		return
	for peer_key in raw_data.keys():
		var choices = raw_data[peer_key]
		if choices is Array:
			upgrade_choices_by_peer[int(str(peer_key))] = choices


func _serialize_upgrade_selected_peer_ids() -> Array:
	var ids := []
	for peer_id in upgrade_selected_peer_ids.keys():
		ids.append(int(peer_id))
	ids.sort()
	return ids


func _apply_upgrade_selected_peer_ids_snapshot(raw_data) -> void:
	upgrade_selected_peer_ids.clear()
	if not (raw_data is Array):
		return
	for peer_id in raw_data:
		upgrade_selected_peer_ids[int(peer_id)] = true


func _apply_waiting_peer_ids_snapshot(waiting_data) -> void:
	waiting_peer_ids.clear()
	if not (waiting_data is Array):
		return
	for peer_id in waiting_data:
		waiting_peer_ids[int(peer_id)] = true


func _clear_network_view_state() -> void:
	zombies.clear()
	bullets.clear()
	xp_orbs.clear()
	reward_chests.clear()
	supply_caches.clear()
	holdout_events.clear()
	visual_effects.clear()
	upgrade_choices.clear()
	upgrade_choices_by_peer.clear()
	upgrade_selected_peer_ids.clear()
	upgrade_reward_source = UpgradeCatalog.REWARD_LEVEL
	upgrade_selection_timer = -1.0
	zombie_grid.clear()
	choosing_upgrade = false
	synced_upgrade_choice_key = ""
	upgrade_overlay.visible = false
	game_over_overlay.visible = false


func _make_world_snapshot() -> Dictionary:
	var players_data := {}
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player == null:
			continue
		players_data[str(peer_id)] = {
			"position": active_player.position,
			"hp": active_player.hp,
			"max_hp": active_player.max_hp,
			"speed": active_player.speed,
			"damage": active_player.damage,
			"fire_interval": active_player.fire_interval,
			"pickup_radius": active_player.pickup_radius,
			"aim_direction": active_player.aim_direction,
			"body_color": active_player.body_color,
			"weapon_status": _ensure_player_loadout(int(peer_id)).status_text(),
			"downed": active_player.downed,
			"revive_progress": active_player.revive_progress,
			"down_count": active_player.down_count
		}

	var zombies_data := []
	for zombie: ZombieState in zombies:
		zombies_data.append(_serialize_zombie(zombie))

	var bullets_data := []
	for bullet: BulletState in bullets:
		bullets_data.append({
			"position": bullet.position,
			"radius": bullet.radius,
			"color": bullet.color
		})

	var xp_data := []
	for orb: XpOrbState in xp_orbs:
		xp_data.append({
			"position": orb.position,
			"value": orb.value
		})

	var chests_data := []
	for chest in reward_chests:
		chests_data.append({
			"position": chest.position,
			"radius": chest.radius
		})

	var supplies_data := []
	for supply in supply_caches:
		supplies_data.append({
			"position": supply.position,
			"kind": supply.kind,
			"radius": supply.radius,
			"lifetime": supply.lifetime
		})

	var holdouts_data := []
	for event in holdout_events:
		holdouts_data.append({
			"position": event.position,
			"radius": event.radius,
			"required_time": event.required_time,
			"lifetime": event.lifetime,
			"progress": event.progress
		})

	return {
		"protocol_version": NetworkSessionResource.PROTOCOL_VERSION,
		"host_network_state": network_state,
		"run_started": run_started,
		"lobby_auto_start_timer": lobby_auto_start_timer,
		"lobby_ready": _serialize_lobby_ready(),
		"waiting_peer_ids": _serialize_waiting_peer_ids(),
		"run_participant_peer_ids": _serialize_run_participant_peer_ids(),
		"elapsed": elapsed,
		"kills": kills,
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"game_over": game_over,
		"choosing_upgrade": choosing_upgrade,
		"upgrade_reward_source": upgrade_reward_source,
		"upgrade_selection_timer": upgrade_selection_timer,
		"upgrade_title": _upgrade_title_for_source(upgrade_reward_source),
		"upgrade_hint": _upgrade_hint_for_source(upgrade_reward_source),
		"upgrade_choices_by_peer": _serialize_upgrade_choices_by_peer(),
		"upgrade_selected_peer_ids": _serialize_upgrade_selected_peer_ids(),
		"wave_index": spawn_director.wave_index,
		"players": players_data,
		"zombies": zombies_data,
		"bullets": bullets_data,
		"xp_orbs": xp_data,
		"reward_chests": chests_data,
		"supply_caches": supplies_data,
		"holdout_events": holdouts_data,
		"weapon_status": _local_weapon_status_text(),
		"relic_status": relics.status_text(),
		"game_over_text": game_over_label.text if game_over_label != null else ""
	}


func _apply_world_snapshot(snapshot: Dictionary) -> void:
	snapshot_debug["last_size"] = str(snapshot).to_utf8_buffer().size()
	snapshot_debug["last_received_msec"] = Time.get_ticks_msec()
	snapshot_debug["received_count"] = int(snapshot_debug.get("received_count", 0)) + 1
	var was_game_over := game_over
	local_peer_id = network_session.local_peer_id() if network_session != null else local_peer_id
	run_started = bool(snapshot.get("run_started", run_started))
	lobby_auto_start_timer = float(snapshot.get("lobby_auto_start_timer", lobby_auto_start_timer))
	_apply_lobby_ready_snapshot(snapshot.get("lobby_ready", {}))
	_apply_waiting_peer_ids_snapshot(snapshot.get("waiting_peer_ids", []))
	_apply_run_participant_peer_ids_snapshot(snapshot.get("run_participant_peer_ids", []))
	elapsed = float(snapshot.get("elapsed", elapsed))
	kills = int(snapshot.get("kills", kills))
	level = int(snapshot.get("level", level))
	xp = int(snapshot.get("xp", xp))
	xp_to_next = int(snapshot.get("xp_to_next", xp_to_next))
	game_over = bool(snapshot.get("game_over", false))
	if not game_over:
		local_run_recorded = false
	choosing_upgrade = bool(snapshot.get("choosing_upgrade", false))
	upgrade_reward_source = String(snapshot.get("upgrade_reward_source", upgrade_reward_source))
	upgrade_selection_timer = float(snapshot.get("upgrade_selection_timer", upgrade_selection_timer))
	_apply_upgrade_choices_by_peer_snapshot(snapshot.get("upgrade_choices_by_peer", {}))
	_apply_upgrade_selected_peer_ids_snapshot(snapshot.get("upgrade_selected_peer_ids", []))
	spawn_director.wave_index = int(snapshot.get("wave_index", spawn_director.wave_index))
	synced_weapon_status_text = String(snapshot.get("weapon_status", synced_weapon_status_text))
	synced_relic_status_text = String(snapshot.get("relic_status", synced_relic_status_text))

	var players_data: Dictionary = snapshot.get("players", {})
	var active_peer_ids := {}
	for peer_key in players_data.keys():
		var peer_id := int(str(peer_key))
		var player_data: Dictionary = players_data[peer_key]
		var synced_player := _ensure_player(peer_id)
		synced_player.position = player_data.get("position", synced_player.position)
		synced_player.hp = float(player_data.get("hp", synced_player.hp))
		synced_player.max_hp = float(player_data.get("max_hp", synced_player.max_hp))
		synced_player.speed = float(player_data.get("speed", synced_player.speed))
		synced_player.damage = float(player_data.get("damage", synced_player.damage))
		synced_player.fire_interval = float(player_data.get("fire_interval", synced_player.fire_interval))
		synced_player.pickup_radius = float(player_data.get("pickup_radius", synced_player.pickup_radius))
		synced_player.aim_direction = player_data.get("aim_direction", synced_player.aim_direction)
		synced_player.downed = bool(player_data.get("downed", synced_player.downed))
		synced_player.revive_progress = float(player_data.get("revive_progress", synced_player.revive_progress))
		synced_player.down_count = int(player_data.get("down_count", synced_player.down_count))
		synced_player.set_display_color(player_data.get("body_color", synced_player.body_color))
		if peer_id == local_peer_id:
			synced_weapon_status_text = String(player_data.get("weapon_status", synced_weapon_status_text))
		active_peer_ids[peer_id] = true

	for peer_id in players.keys().duplicate():
		if not active_peer_ids.has(int(peer_id)):
			_remove_player(int(peer_id))

	player = players.get(local_peer_id, players.get(SERVER_PEER_ID, player)) as Player
	_refresh_player_identity_markers()

	zombies.clear()
	for zombie_data in snapshot.get("zombies", []):
		zombies.append(_zombie_from_snapshot(zombie_data))

	bullets.clear()
	for bullet_data in snapshot.get("bullets", []):
		bullets.append(BulletState.new(
			bullet_data.get("position", Vector2.ZERO),
			Vector2.ZERO,
			0.0,
			1.0,
			float(bullet_data.get("radius", 4.0)),
			0,
			bullet_data.get("color", Color(1.0, 0.86, 0.35))
		))

	xp_orbs.clear()
	for orb_data in snapshot.get("xp_orbs", []):
		xp_orbs.append(XpOrbState.new(
			orb_data.get("position", Vector2.ZERO),
			int(orb_data.get("value", 1))
		))

	reward_chests.clear()
	for chest_data in snapshot.get("reward_chests", []):
		reward_chests.append(RewardChestState.new(
			chest_data.get("position", Vector2.ZERO),
			float(chest_data.get("radius", 18.0))
		))

	supply_caches.clear()
	for supply_data in snapshot.get("supply_caches", []):
		supply_caches.append(SupplyCacheState.new(
			supply_data.get("position", Vector2.ZERO),
			String(supply_data.get("kind", "")),
			float(supply_data.get("radius", 18.0)),
			float(supply_data.get("lifetime", 95.0))
		))

	holdout_events.clear()
	for event_data in snapshot.get("holdout_events", []):
		var event := HoldoutEventState.new(
			event_data.get("position", Vector2.ZERO),
			float(event_data.get("radius", 112.0)),
			float(event_data.get("required_time", 20.0)),
			float(event_data.get("lifetime", 90.0))
		)
		event.progress = float(event_data.get("progress", 0.0))
		holdout_events.append(event)

	if not run_started:
		if lobby_overlay != null:
			lobby_overlay.visible = true
		_update_lobby_ui()
		return

	if lobby_overlay != null:
		lobby_overlay.visible = false
	if network_status_label != null and waiting_peer_ids.has(local_peer_id):
		network_status_label.text = "本局进行中：观战中，下一局加入"
	elif network_status_label != null and _is_network_client():
		network_status_label.text = "局内：已连接房主"
	if choosing_upgrade and _has_local_active_player():
		_show_current_local_upgrade_choices()
	else:
		upgrade_overlay.visible = false
		upgrade_choices.clear()
		synced_upgrade_choice_key = ""
	game_over_overlay.visible = game_over
	if game_over and game_over_label != null:
		_record_synced_run_if_needed(was_game_over)
		if _is_peer_participant(local_peer_id):
			_update_game_over_label()
		else:
			game_over_label.text = String(snapshot.get("game_over_text", "游戏结束")) + "\n\n你是观战玩家，本局不结算局外进度。"
	_update_hud()


func _serialize_zombie(zombie: ZombieState) -> Dictionary:
	return {
		"position": zombie.position,
		"hp": zombie.hp,
		"max_hp": zombie.max_hp,
		"speed": zombie.speed,
		"damage": zombie.damage,
		"type_id": zombie.type_id,
		"radius": zombie.radius,
		"body_color": zombie.body_color,
		"accent_color": zombie.accent_color,
		"xp_value": zombie.xp_value,
		"behavior_timer": zombie.behavior_timer,
		"charge_timer": zombie.charge_timer,
		"explosion_radius": zombie.explosion_radius,
		"explosion_damage": zombie.explosion_damage,
		"is_elite": zombie.is_elite,
		"elite_rank": zombie.elite_rank,
		"elite_title": zombie.elite_title,
		"dead": zombie.dead
	}


func _zombie_from_snapshot(data: Dictionary) -> ZombieState:
	var zombie := ZombieState.new(
		data.get("position", Vector2.ZERO),
		float(data.get("hp", 1.0)),
		float(data.get("speed", 0.0)),
		float(data.get("damage", 0.0)),
		String(data.get("type_id", EnemyCatalog.NORMAL)),
		float(data.get("radius", EnemyCatalog.NORMAL_RADIUS)),
		data.get("body_color", Color(0.42, 0.72, 0.28)),
		data.get("accent_color", Color(0.95, 0.12, 0.08)),
		int(data.get("xp_value", 1)),
		float(data.get("explosion_radius", 0.0)),
		float(data.get("explosion_damage", 0.0))
	)
	zombie.max_hp = float(data.get("max_hp", zombie.hp))
	zombie.behavior_timer = float(data.get("behavior_timer", 0.0))
	zombie.charge_timer = float(data.get("charge_timer", 0.0))
	zombie.is_elite = bool(data.get("is_elite", false))
	zombie.elite_rank = int(data.get("elite_rank", 0))
	zombie.elite_title = String(data.get("elite_title", ""))
	zombie.dead = bool(data.get("dead", false))
	return zombie


func _setup_arena_map() -> void:
	arena_map = get_node_or_null("ArenaMap") as TileMapLayer
	if arena_map == null:
		arena_map = TileMapLayer.new()
		arena_map.name = "ArenaMap"
		add_child(arena_map)
		move_child(arena_map, 0)
		arena_map.position = -ARENA_SIZE * 0.5

	arena_map.z_index = -100
	var created_default_tileset := false
	if arena_map.tile_set == null:
		arena_map.tile_set = load(DEFAULT_ARENA_TILESET_PATH) as TileSet
		if arena_map.tile_set == null:
			arena_map.tile_set = _create_default_arena_tileset()
		created_default_tileset = true
	if created_default_tileset and arena_map.get_used_rect().size == Vector2i.ZERO:
		_paint_default_arena_map()


func _create_default_arena_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = MAP_TILE_SIZE

	var image := Image.create(MAP_TILE_SIZE.x * 2, MAP_TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	_paint_tile_region(image, Rect2i(Vector2i.ZERO, MAP_TILE_SIZE), Color(0.055, 0.08, 0.065), Color(0.09, 0.13, 0.1))
	_paint_tile_region(image, Rect2i(Vector2i(MAP_TILE_SIZE.x, 0), MAP_TILE_SIZE), Color(0.08, 0.11, 0.075), Color(0.28, 0.35, 0.22))

	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = MAP_TILE_SIZE
	source.create_tile(MAP_FLOOR_ATLAS)
	source.create_tile(MAP_BORDER_ATLAS)
	tile_set.add_source(source, MAP_SOURCE_ID)
	return tile_set


func _paint_tile_region(image: Image, region: Rect2i, fill_color: Color, grid_color: Color) -> void:
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			var local_x := x - region.position.x
			var local_y := y - region.position.y
			var is_grid_line := local_x == 0 or local_y == 0
			image.set_pixel(x, y, grid_color if is_grid_line else fill_color)


func _paint_default_arena_map() -> void:
	for x in range(MAP_COLUMNS):
		for y in range(MAP_ROWS):
			var is_edge := x == 0 or y == 0 or x == MAP_COLUMNS - 1 or y == MAP_ROWS - 1
			var atlas_coords := MAP_BORDER_ATLAS if is_edge else MAP_FLOOR_ATLAS
			arena_map.set_cell(Vector2i(x, y), MAP_SOURCE_ID, atlas_coords)


func _get_arena_rect() -> Rect2:
	if arena_map != null and arena_map.tile_set != null:
		var used_rect := arena_map.get_used_rect()
		if used_rect.size != Vector2i.ZERO:
			var tile_size := Vector2(arena_map.tile_set.tile_size)
			return Rect2(arena_map.position + Vector2(used_rect.position) * tile_size, Vector2(used_rect.size) * tile_size)
	return Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)


func _refresh_hud(delta: float) -> void:
	hud_refresh_timer -= delta
	if hud_refresh_timer > 0.0:
		return
	hud_refresh_timer = HUD_REFRESH_INTERVAL
	_update_hud()


func _update_hud() -> void:
	var status_player := player if player != null else _first_player()
	if status_player == null:
		return
	var seconds := int(elapsed)
	var time_text := "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]
	var player_state := "倒地" if status_player.downed else "作战"
	hud_label.text = "等级 %d  击杀 %d  波次 %d  生存 %s  玩家 %d  状态 %s  角色 %s" % [
		level,
		kills,
		spawn_director.wave_index,
		time_text,
		players.size(),
		player_state,
		meta_progression.character_title(selected_character)
	]
	hp_bar.max_value = status_player.max_hp
	hp_bar.value = status_player.hp
	xp_bar.max_value = xp_to_next
	xp_bar.value = xp
	var weapon_text := _local_weapon_status_text()
	var relic_text := synced_relic_status_text if _is_network_client() and not synced_relic_status_text.is_empty() else relics.status_text()
	weapon_label.text = "武器 %s" % weapon_text
	relic_label.text = "遗物 %s" % relic_text


func _local_weapon_status_text() -> String:
	if _is_network_client() and not synced_weapon_status_text.is_empty():
		return synced_weapon_status_text
	if player_weapon_loadouts.has(local_peer_id):
		return player_weapon_loadouts[local_peer_id].status_text()
	return weapon_loadout.status_text()


func _end_game() -> void:
	game_over = true
	_record_local_run_if_needed()
	_update_game_over_label()
	game_over_overlay.visible = true
	_broadcast_world_snapshot_now()


func _record_synced_run_if_needed(was_game_over: bool) -> void:
	if was_game_over:
		return
	_record_local_run_if_needed()


func _record_local_run_if_needed() -> void:
	if local_run_recorded:
		return
	if not _is_peer_participant(local_peer_id):
		last_unlock_messages.clear()
		return
	last_unlock_messages = meta_progression.record_run(elapsed, kills)
	local_run_recorded = true
	selected_starting_weapon = meta_progression.coerce_starting_weapon(selected_starting_weapon)
	selected_character = meta_progression.coerce_character(selected_character)


func _restart_game() -> void:
	if players.is_empty():
		_ensure_player(SERVER_PEER_ID)
	if run_participant_peer_ids.is_empty():
		_set_run_participants_from_current_players()
	local_run_recorded = false
	player_weapon_loadouts.clear()
	player_upgrade_states.clear()
	weapon_loadout.reset(selected_starting_weapon)
	for peer_id in players.keys():
		var active_player := players[peer_id] as Player
		if active_player == null:
			continue
		active_player.reset(_spawn_position_for_peer(int(peer_id)), selected_character)
		active_player.set_display_color(_player_color(int(peer_id)))
		var loadout := WeaponLoadout.new()
		loadout.reset(selected_starting_weapon)
		player_weapon_loadouts[int(peer_id)] = loadout
		player_upgrade_states[int(peer_id)] = UpgradeState.new()
	_refresh_player_identity_markers()
	zombies.clear()
	bullets.clear()
	xp_orbs.clear()
	reward_chests.clear()
	supply_caches.clear()
	holdout_events.clear()
	visual_effects.clear()
	upgrade_choices.clear()
	upgrade_choices_by_peer.clear()
	upgrade_selected_peer_ids.clear()
	upgrade_reward_source = UpgradeCatalog.REWARD_LEVEL
	upgrade_selection_timer = -1.0
	zombie_grid.clear()
	spawn_director.reset()
	elite_director.reset()
	map_event_director.reset()
	weapon_loadout.reset(selected_starting_weapon)
	relics.reset()
	hud_refresh_timer = 0.0
	network_input_timer = 0.0
	world_snapshot_timer = 0.0
	elapsed = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_to_next = 6
	game_over = false
	choosing_upgrade = false
	last_unlock_messages.clear()
	synced_weapon_status_text = ""
	synced_relic_status_text = ""
	upgrade_overlay.visible = false
	game_over_overlay.visible = false
	player = players.get(local_peer_id, players.get(SERVER_PEER_ID, player)) as Player
	if camera != null and player != null:
		camera.global_position = player.position
	_update_hud()
	queue_redraw()


func _cycle_starting_weapon(direction: int) -> void:
	selected_starting_weapon = meta_progression.next_starting_weapon(selected_starting_weapon, direction)
	meta_progression.set_preferred_starting_weapon(selected_starting_weapon)
	_update_game_over_label()


func _cycle_character(direction: int) -> void:
	selected_character = meta_progression.next_character(selected_character, direction)
	meta_progression.set_preferred_character(selected_character)
	_update_game_over_label()


func _update_game_over_label() -> void:
	var unlock_text := ""
	if not last_unlock_messages.is_empty():
		unlock_text = "\n\n新解锁：\n%s" % "\n".join(last_unlock_messages)
	game_over_label.text = (
		"你被尸潮吞没了\n\n"
		+ "本局：等级 %d   击杀 %d   生存 %s\n" % [level, kills, _format_time(elapsed)]
		+ "最佳：击杀 %d   生存 %s   局数 %d" % [
			meta_progression.best_kills,
			_format_time(meta_progression.best_time),
			meta_progression.total_runs
		]
		+ unlock_text
		+ "\n\n下局角色：%s - %s\n" % [
			meta_progression.character_title(selected_character),
			meta_progression.character_desc(selected_character)
		]
		+ "初始武器：%s\n\n" % meta_progression.weapon_title(selected_starting_weapon)
		+ "Q/E 切换武器    Z/C 切换角色    R 开始"
	)


func _format_time(value: float) -> String:
	var seconds := int(value)
	return "%02d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _get_draw_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var camera_center := camera.global_position if camera != null else _team_focus_position()
	var padding := Vector2(COLLISION_CELL_SIZE, COLLISION_CELL_SIZE)
	return Rect2(camera_center - viewport_size * 0.5 - padding, viewport_size + padding * 2.0)


func _draw_visual_effect(effect: VisualEffectState) -> void:
	var remaining_ratio := clampf(effect.lifetime / maxf(effect.max_lifetime, 0.001), 0.0, 1.0)
	var progress := 1.0 - remaining_ratio
	var radius := lerpf(effect.start_radius, effect.end_radius, progress)
	var color := effect.color
	color.a *= remaining_ratio
	match effect.kind:
		"flash":
			draw_circle(effect.position, radius, color)
		"burst":
			var fill_color := color
			fill_color.a *= 0.22
			draw_circle(effect.position, radius, fill_color)
			draw_arc(effect.position, radius, 0.0, TAU, 32, color, 3.0)
		"hit":
			draw_circle(effect.position, radius * 0.55, color)
			draw_arc(effect.position, radius, 0.0, TAU, 16, color, 2.0)
		_:
			draw_arc(effect.position, radius, 0.0, TAU, 24, color, 2.0)


func _draw_zombie(zombie: ZombieState, draw_details: bool) -> void:
	var zombie_position := zombie.position
	if zombie.is_elite:
		draw_circle(zombie_position, zombie.radius + 7.0, Color(1.0, 0.74, 0.16, 0.36))
	draw_circle(zombie_position, zombie.radius + 3.0, Color(0.08, 0.05, 0.04))
	draw_circle(zombie_position, zombie.radius, zombie.body_color)
	if not draw_details:
		return
	var hp_ratio := clampf(zombie.hp / zombie.max_hp, 0.0, 1.0)
	draw_circle(zombie_position + Vector2(-zombie.radius * 0.35, -zombie.radius * 0.25), 2.2, zombie.accent_color)
	draw_circle(zombie_position + Vector2(zombie.radius * 0.35, -zombie.radius * 0.25), 2.2, zombie.accent_color)
	if hp_ratio < 1.0:
		var bar_width := zombie.radius * 2.0
		var bar_position := zombie_position + Vector2(-zombie.radius, -zombie.radius - 9.0)
		draw_rect(Rect2(bar_position, Vector2(bar_width, 4.0)), Color(0.16, 0.05, 0.04), true)
		draw_rect(Rect2(bar_position, Vector2(bar_width * hp_ratio, 4.0)), Color(0.86, 0.16, 0.1), true)


func _draw_reward_chest(chest) -> void:
	var position: Vector2 = chest.position
	var size := Vector2(chest.radius * 1.7, chest.radius * 1.25)
	var top_left := position - size * 0.5
	draw_rect(Rect2(top_left + Vector2(0.0, size.y * 0.36), Vector2(size.x, size.y * 0.64)), Color(0.56, 0.25, 0.09), true)
	draw_rect(Rect2(top_left, Vector2(size.x, size.y * 0.45)), Color(0.78, 0.42, 0.12), true)
	draw_rect(Rect2(top_left + Vector2(size.x * 0.42, 0.0), Vector2(size.x * 0.16, size.y)), Color(1.0, 0.78, 0.18), true)
	draw_rect(Rect2(top_left + Vector2(0.0, size.y * 0.36), Vector2(size.x, 3.0)), Color(1.0, 0.78, 0.18), true)
	draw_arc(position, chest.radius + 6.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.28, 0.72), 2.0)


func _draw_supply_cache(supply) -> void:
	var position: Vector2 = supply.position
	var color := _supply_color(supply.kind)
	draw_circle(position, supply.radius + 7.0, Color(color.r, color.g, color.b, 0.2))
	draw_rect(Rect2(position - Vector2(16.0, 13.0), Vector2(32.0, 26.0)), Color(0.09, 0.1, 0.1), true)
	draw_rect(Rect2(position - Vector2(13.0, 10.0), Vector2(26.0, 20.0)), color, true)
	match supply.kind:
		MapEventDirector.SUPPLY_HEAL:
			draw_rect(Rect2(position - Vector2(2.0, 8.0), Vector2(4.0, 16.0)), Color.WHITE, true)
			draw_rect(Rect2(position - Vector2(8.0, 2.0), Vector2(16.0, 4.0)), Color.WHITE, true)
		MapEventDirector.SUPPLY_MAGNET:
			draw_arc(position, 8.0, PI * 0.18, PI * 1.82, 18, Color.WHITE, 3.0)
			draw_line(position + Vector2(-7.0, -3.0), position + Vector2(-11.0, -8.0), Color.WHITE, 2.0)
			draw_line(position + Vector2(7.0, -3.0), position + Vector2(11.0, -8.0), Color.WHITE, 2.0)
		MapEventDirector.SUPPLY_BOMB:
			draw_circle(position, 7.0, Color(0.08, 0.06, 0.04))
			draw_line(position + Vector2(4.0, -6.0), position + Vector2(10.0, -12.0), Color.WHITE, 2.0)
	draw_arc(position, supply.radius + 8.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.72), 2.0)


func _supply_color(kind: String) -> Color:
	match kind:
		MapEventDirector.SUPPLY_HEAL:
			return Color(0.18, 0.86, 0.45)
		MapEventDirector.SUPPLY_MAGNET:
			return Color(0.25, 0.78, 1.0)
		MapEventDirector.SUPPLY_BOMB:
			return Color(1.0, 0.46, 0.16)
		_:
			return Color(0.8, 0.8, 0.8)


func _draw_holdout_event(event) -> void:
	var position: Vector2 = event.position
	var progress_ratio: float = event.progress_ratio()
	var inside := _is_any_player_inside_holdout(event)
	var base_color := Color(0.35, 0.72, 1.0, 0.14 if inside else 0.08)
	draw_circle(position, event.radius, base_color)
	draw_arc(position, event.radius, 0.0, TAU, 48, Color(0.28, 0.58, 0.88, 0.85), 3.0)
	draw_arc(position, event.radius + 7.0, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 48, Color(1.0, 0.86, 0.28), 5.0)
	draw_circle(position, 10.0, Color(1.0, 0.86, 0.28, 0.82))
	draw_arc(position, 22.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.28, 0.5), 2.0)
