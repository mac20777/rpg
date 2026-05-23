class_name MetaProgression
extends RefCounted

const SAVE_PATH := "user://meta_progression.cfg"
const DEFAULT_WEAPON := "pistol"
const DEFAULT_CHARACTER := "survivor"

const STARTING_WEAPON_ORDER := ["pistol", "shotgun", "knife"]
const CHARACTER_ORDER := ["survivor", "scout", "bruiser"]

const WEAPON_TITLES := {
	"pistol": "手枪",
	"shotgun": "霰弹",
	"knife": "飞刀"
}

const CHARACTER_TITLES := {
	"survivor": "幸存者",
	"scout": "游侠",
	"bruiser": "重装兵"
}

const CHARACTER_DESCS := {
	"survivor": "均衡属性",
	"scout": "更快移动与更大拾取范围，生命较低",
	"bruiser": "更高生命和伤害，移动稍慢"
}

var best_time := 0.0
var best_kills := 0
var total_runs := 0
var unlocked_starting_weapons := []
var unlocked_characters := []
var preferred_starting_weapon := DEFAULT_WEAPON
var preferred_character := DEFAULT_CHARACTER


func load() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		_reset_defaults()
		return

	best_time = float(config.get_value("stats", "best_time", 0.0))
	best_kills = int(config.get_value("stats", "best_kills", 0))
	total_runs = int(config.get_value("stats", "total_runs", 0))
	unlocked_starting_weapons = _sanitize_unlocks(config.get_value("unlocks", "starting_weapons", [DEFAULT_WEAPON]), STARTING_WEAPON_ORDER, DEFAULT_WEAPON)
	unlocked_characters = _sanitize_unlocks(config.get_value("unlocks", "characters", [DEFAULT_CHARACTER]), CHARACTER_ORDER, DEFAULT_CHARACTER)
	preferred_starting_weapon = coerce_starting_weapon(String(config.get_value("prefs", "starting_weapon", DEFAULT_WEAPON)))
	preferred_character = coerce_character(String(config.get_value("prefs", "character", DEFAULT_CHARACTER)))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "best_time", best_time)
	config.set_value("stats", "best_kills", best_kills)
	config.set_value("stats", "total_runs", total_runs)
	config.set_value("unlocks", "starting_weapons", unlocked_starting_weapons)
	config.set_value("unlocks", "characters", unlocked_characters)
	config.set_value("prefs", "starting_weapon", preferred_starting_weapon)
	config.set_value("prefs", "character", preferred_character)
	config.save(SAVE_PATH)


func record_run(run_time: float, run_kills: int) -> Array:
	total_runs += 1
	best_time = maxf(best_time, run_time)
	best_kills = maxi(best_kills, run_kills)
	var unlock_messages := _evaluate_unlocks()
	save()
	return unlock_messages


func set_preferred_starting_weapon(weapon_id: String) -> void:
	preferred_starting_weapon = coerce_starting_weapon(weapon_id)
	save()


func set_preferred_character(character_id: String) -> void:
	preferred_character = coerce_character(character_id)
	save()


func next_starting_weapon(current_weapon: String, direction: int) -> String:
	return _next_unlocked(STARTING_WEAPON_ORDER, unlocked_starting_weapons, coerce_starting_weapon(current_weapon), direction)


func next_character(current_character: String, direction: int) -> String:
	return _next_unlocked(CHARACTER_ORDER, unlocked_characters, coerce_character(current_character), direction)


func coerce_starting_weapon(weapon_id: String) -> String:
	return weapon_id if unlocked_starting_weapons.has(weapon_id) else DEFAULT_WEAPON


func coerce_character(character_id: String) -> String:
	return character_id if unlocked_characters.has(character_id) else DEFAULT_CHARACTER


func weapon_title(weapon_id: String) -> String:
	return String(WEAPON_TITLES.get(weapon_id, weapon_id))


func character_title(character_id: String) -> String:
	return String(CHARACTER_TITLES.get(character_id, character_id))


func character_desc(character_id: String) -> String:
	return String(CHARACTER_DESCS.get(character_id, ""))


func _reset_defaults() -> void:
	best_time = 0.0
	best_kills = 0
	total_runs = 0
	unlocked_starting_weapons = [DEFAULT_WEAPON]
	unlocked_characters = [DEFAULT_CHARACTER]
	preferred_starting_weapon = DEFAULT_WEAPON
	preferred_character = DEFAULT_CHARACTER


func _evaluate_unlocks() -> Array:
	var messages := []
	if best_time >= 120.0:
		_unlock_starting_weapon("shotgun", messages)
	if best_kills >= 180:
		_unlock_starting_weapon("knife", messages)
	if best_time >= 180.0:
		_unlock_character("scout", messages)
	if best_kills >= 350:
		_unlock_character("bruiser", messages)
	return messages


func _unlock_starting_weapon(weapon_id: String, messages: Array) -> void:
	if unlocked_starting_weapons.has(weapon_id):
		return
	unlocked_starting_weapons.append(weapon_id)
	messages.append("解锁初始武器：%s" % weapon_title(weapon_id))


func _unlock_character(character_id: String, messages: Array) -> void:
	if unlocked_characters.has(character_id):
		return
	unlocked_characters.append(character_id)
	messages.append("解锁角色：%s" % character_title(character_id))


func _sanitize_unlocks(raw_unlocks, valid_order: Array, default_id: String) -> Array:
	var sanitized := []
	for unlock_id in raw_unlocks:
		var id := String(unlock_id)
		if valid_order.has(id) and not sanitized.has(id):
			sanitized.append(id)
	if not sanitized.has(default_id):
		sanitized.push_front(default_id)
	return sanitized


func _next_unlocked(order: Array, unlocked: Array, current_id: String, direction: int) -> String:
	if unlocked.size() <= 1:
		return current_id
	var current_index := order.find(current_id)
	if current_index < 0:
		current_index = 0
	var step := 1 if direction >= 0 else -1
	for i in range(order.size()):
		current_index = (current_index + step + order.size()) % order.size()
		var candidate: String = order[current_index]
		if unlocked.has(candidate):
			return candidate
	return current_id
