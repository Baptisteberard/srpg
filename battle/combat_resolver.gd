extends RefCounted
class_name CombatResolver

signal unit_defeated(unit: Unit, victor: Unit)
signal combat_state_changed

var rng: RandomNumberGenerator


static func forecast(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"can_attack": false,
		"defender_can_counter": false,
		"attacker_strikes_first": true,
		"attacker_hp_after": 0,
		"defender_hp_after": 0,
	}
	if attacker == null or defender == null:
		return result

	result["attacker_hp_after"] = attacker.current_hp
	result["defender_hp_after"] = defender.current_hp
	if not attacker.is_alive() or not defender.is_alive() or attacker.faction == defender.faction:
		return result

	var attacker_can: bool = _can_attack_from_cell(attacker, attacker_cell, defender.cell)
	var defender_can: bool = _can_attack_from_cell(defender, defender.cell, attacker_cell)
	result["can_attack"] = attacker_can
	result["defender_can_counter"] = defender_can
	if not attacker_can:
		return result

	var attacker_hp_after: int = attacker.current_hp
	var defender_hp_after: int = defender.current_hp
	var attacker_strikes_first: bool = not (defender.speed > attacker.speed and defender_can)
	result["attacker_strikes_first"] = attacker_strikes_first

	if attacker_strikes_first:
		defender_hp_after = maxi(0, defender_hp_after - attacker.get_physical_damage())
		if defender_hp_after > 0 and defender_can:
			attacker_hp_after = maxi(0, attacker_hp_after - defender.get_physical_damage())
	else:
		attacker_hp_after = maxi(0, attacker_hp_after - defender.get_physical_damage())
		if attacker_hp_after > 0:
			defender_hp_after = maxi(0, defender_hp_after - attacker.get_physical_damage())

	result["attacker_hp_after"] = attacker_hp_after
	result["defender_hp_after"] = defender_hp_after
	return result


static func _can_attack_from_cell(attacker: Unit, attacker_cell: Vector2i, defender_cell: Vector2i) -> bool:
	return attacker != null \
		and attacker.is_alive() \
		and abs(attacker_cell.x - defender_cell.x) + abs(attacker_cell.y - defender_cell.y) <= attacker.attack_range


func configure(random_source: RandomNumberGenerator) -> void:
	rng = random_source


func resolve(attacker: Unit, defender: Unit) -> void:
	if attacker == null or defender == null or not attacker.can_attack(defender):
		return

	var first: Unit = attacker
	var second: Unit = defender
	if defender.speed > attacker.speed and defender.can_attack(attacker):
		first = defender
		second = attacker

	await _perform_strike(first, second)
	if not is_instance_valid(first) or not is_instance_valid(second):
		return
	if not first.is_alive() or not second.is_alive():
		return
	if not second.can_attack(first):
		combat_state_changed.emit()
		return
	await _perform_strike(second, first)


func _perform_strike(attacker: Unit, defender: Unit) -> void:
	if attacker == null or defender == null or not attacker.can_attack(defender):
		return

	await attacker.play_attack_animation(defender.global_position)
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return

	var random_roll: int = rng.randi_range(1, 100) if rng != null else 1
	if random_roll <= attacker.get_hit_chance_against(defender):
		defender.take_damage(attacker.get_physical_damage())
		if not defender.is_alive():
			unit_defeated.emit(defender, attacker)
	combat_state_changed.emit()
