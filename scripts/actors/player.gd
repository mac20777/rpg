class_name Player
extends Node2D

const RADIUS := 16.0
const MOUSE_MOVE_STOP_DISTANCE := 12.0
const LOCAL_MARKER_COLOR := Color(1.0, 0.86, 0.24)

var hp := 100.0
var max_hp := 100.0
var speed := 250.0
var damage := 30.0
var fire_interval := 0.45
var pickup_radius := 85.0
var aim_direction := Vector2.RIGHT
var mouse_move_target := Vector2.ZERO
var has_mouse_move_target := false
var body_color := Color(0.12, 0.75, 0.78)
var outline_color := Color(0.06, 0.13, 0.14)
var downed := false
var revive_progress := 0.0
var down_count := 0
var identity_label_text := ""
var is_local_player := false
var identity_label: Label


func reset(spawn_position: Vector2, character_id := "survivor") -> void:
	position = spawn_position
	_apply_character_base_stats(character_id)
	aim_direction = Vector2.RIGHT
	mouse_move_target = spawn_position
	has_mouse_move_target = false
	downed = false
	revive_progress = 0.0
	down_count = 0
	queue_redraw()


func _ready() -> void:
	_refresh_identity_label()


func _apply_character_base_stats(character_id: String) -> void:
	match character_id:
		"scout":
			max_hp = 85.0
			speed = 285.0
			damage = 28.0
			fire_interval = 0.43
			pickup_radius = 120.0
		"bruiser":
			max_hp = 130.0
			speed = 220.0
			damage = 36.0
			fire_interval = 0.48
			pickup_radius = 75.0
		_:
			max_hp = 100.0
			speed = 250.0
			damage = 30.0
			fire_interval = 0.45
			pickup_radius = 85.0
	hp = max_hp


func update_movement(delta: float, arena_rect: Rect2) -> void:
	update_movement_from_input(delta, arena_rect, read_local_input_state())


func update_movement_from_input(delta: float, arena_rect: Rect2, input_state: Dictionary) -> void:
	if downed:
		return
	var movement: Vector2 = input_state.get("movement", Vector2.ZERO)
	if movement.length_squared() > 1.0:
		movement = movement.normalized()
	if movement.length_squared() > 0.0:
		has_mouse_move_target = false
	else:
		if bool(input_state.get("updates_mouse_target", false)):
			mouse_move_target = input_state.get("mouse_target", global_position)
			has_mouse_move_target = true
		if has_mouse_move_target:
			var to_target := mouse_move_target - global_position
			if to_target.length_squared() <= MOUSE_MOVE_STOP_DISTANCE * MOUSE_MOVE_STOP_DISTANCE:
				has_mouse_move_target = false
			else:
				movement = to_target.normalized()
	position += movement * speed * delta
	position.x = clampf(position.x, arena_rect.position.x + RADIUS, arena_rect.end.x - RADIUS)
	position.y = clampf(position.y, arena_rect.position.y + RADIUS, arena_rect.end.y - RADIUS)


func apply_upgrade(stat: String) -> void:
	match stat:
		"damage":
			damage *= 1.2
		"fire_rate":
			fire_interval = maxf(fire_interval * 0.85, 0.16)
		"speed":
			speed += 24.0
		"pickup":
			pickup_radius += 35.0
			queue_redraw()
		"health":
			max_hp += 20.0
			hp = minf(hp + 45.0, max_hp)


func set_aim_direction(new_direction: Vector2) -> void:
	if downed:
		return
	if new_direction.length_squared() <= 0.0:
		return
	aim_direction = new_direction.normalized()
	queue_redraw()


func take_damage(amount: float) -> void:
	if downed:
		return
	hp -= amount
	if hp <= 0.0:
		enter_downed()


func heal(amount: float) -> void:
	if downed:
		return
	hp = minf(hp + amount, max_hp)


func enter_downed() -> void:
	if downed:
		return
	downed = true
	hp = 0.0
	revive_progress = 0.0
	down_count += 1
	has_mouse_move_target = false
	queue_redraw()


func revive(health_ratio := 0.35) -> void:
	downed = false
	revive_progress = 0.0
	hp = maxf(max_hp * health_ratio, 1.0)
	queue_redraw()


func is_combat_active() -> bool:
	return hp > 0.0 and not downed


func set_display_color(new_body_color: Color) -> void:
	if body_color == new_body_color:
		return
	body_color = new_body_color
	outline_color = Color(
		maxf(new_body_color.r * 0.34, 0.04),
		maxf(new_body_color.g * 0.28, 0.04),
		maxf(new_body_color.b * 0.28, 0.04)
	)
	queue_redraw()


func set_identity_label(new_label: String, local_player: bool) -> void:
	if identity_label_text == new_label and is_local_player == local_player:
		return
	identity_label_text = new_label
	is_local_player = local_player
	_refresh_identity_label()
	queue_redraw()


func _refresh_identity_label() -> void:
	if identity_label == null:
		identity_label = Label.new()
		identity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		identity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		identity_label.custom_minimum_size = Vector2(82.0, 22.0)
		identity_label.size = Vector2(82.0, 22.0)
		identity_label.position = Vector2(-41.0, -54.0)
		identity_label.add_theme_font_size_override("font_size", 13)
		identity_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		identity_label.add_theme_constant_override("shadow_offset_x", 1)
		identity_label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(identity_label)
	identity_label.text = identity_label_text
	identity_label.visible = not identity_label_text.is_empty()
	identity_label.add_theme_color_override(
		"font_color",
		LOCAL_MARKER_COLOR if is_local_player else Color(0.94, 0.96, 0.9)
	)


func read_local_input_state() -> Dictionary:
	var movement := _get_keyboard_input()
	var updates_mouse_target := false
	var target := mouse_move_target
	if movement.length_squared() <= 0.0 and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		target = get_global_mouse_position()
		updates_mouse_target = true
	return {
		"movement": movement,
		"updates_mouse_target": updates_mouse_target,
		"mouse_target": target
	}


func _get_keyboard_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	if input.length_squared() > 0.0:
		return input.normalized()
	return Vector2.ZERO


func _draw() -> void:
	var pickup_alpha := 0.13 if is_local_player else 0.045
	draw_circle(Vector2.ZERO, pickup_radius, Color(0.1, 0.55, 0.55, pickup_alpha))
	var current_body_color := Color(0.78, 0.18, 0.16) if downed else body_color
	var current_outline_color := Color(0.2, 0.04, 0.04) if downed else outline_color
	if is_local_player:
		draw_arc(Vector2.ZERO, RADIUS + 10.0, 0.0, TAU, 48, LOCAL_MARKER_COLOR, 4.0)
		draw_circle(Vector2(0.0, -RADIUS - 18.0), 4.0, LOCAL_MARKER_COLOR)
	draw_circle(Vector2.ZERO, RADIUS + 3.0, current_outline_color)
	draw_circle(Vector2.ZERO, RADIUS, current_body_color)
	if downed:
		draw_arc(Vector2.ZERO, RADIUS + 10.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(revive_progress, 0.0, 1.0), 32, Color(0.35, 0.95, 0.68), 4.0)
	draw_line(Vector2.ZERO, aim_direction * 28.0, Color(0.95, 0.95, 0.85), 5.0)
