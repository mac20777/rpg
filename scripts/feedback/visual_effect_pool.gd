extends RefCounted

const VisualEffectState := preload("res://scripts/entities/visual_effect_state.gd")

const MAX_EFFECTS := 260

var effects: Array = []


func clear() -> void:
	effects.clear()


func update(delta: float) -> void:
	for effect_index in range(effects.size() - 1, -1, -1):
		var effect: VisualEffectState = effects[effect_index]
		effect.lifetime -= delta
		if effect.lifetime <= 0.0:
			_remove_at(effect_index)


func add(
	position: Vector2,
	color: Color,
	lifetime: float,
	start_radius: float,
	end_radius: float,
	kind := "ring"
) -> void:
	if effects.size() >= MAX_EFFECTS:
		_remove_at(0)
	effects.append(VisualEffectState.new(position, color, lifetime, start_radius, end_radius, kind))


func _remove_at(index: int) -> void:
	var last_index := effects.size() - 1
	if index != last_index:
		effects[index] = effects[last_index]
	effects.pop_back()
