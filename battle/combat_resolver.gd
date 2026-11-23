extends RefCounted
class_name CombatResolver

const Presentation = preload("res://battle/battle_presentation.gd")

signal unit_defeated(unit: Unit, victor: Unit)
signal combat_state_changed

var rng: RandomNumberGenerator
var presentation: Presentation


static func forecast(attacker: Unit, defender: Unit, attacker_cell: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"can_attack": false,
		"defender_can_counter": false,
		"attacker_strikes_first": true,
		"attacker_hp_after": 0,
		"defender_hp_after": 0,
		"attacker_hit": 0,
		"attacker_crit": 0,
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
	result["attacker_hit"] = attacker.get_hit_chance_against(defender)
	result["attacker_crit"] = attacker.get_critical_chance_against(defender)
	if not attacker_can:
		return result

	var attacker_hp_after: int = attacker.current_hp
	var defender_hp_after: int = defender.current_hp
	var attacker_strikes_first: bool = not (
		defender.get_battle_speed() > attacker.get_battle_speed() and defender_can
	)
	result["attacker_strikes_first"] = attacker_strikes_first

	if attacker_strikes_first:
		defender_hp_after = maxi(0, defender_hp_after - attacker.get_physical_damage_against(defender))
		if defender_hp_after > 0 and defender_can:
			attacker_hp_after = maxi(0, attacker_hp_after - defender.get_physical_damage_against(attacker))
	else:
		attacker_hp_after = maxi(0, attacker_hp_after - defender.get_physical_damage_against(attacker))
		if attacker_hp_after > 0:
			defender_hp_after = maxi(0, defender_hp_after - attacker.get_physical_damage_against(defender))

	result["attacker_hp_after"] = attacker_hp_after
	result["defender_hp_after"] = defender_hp_after
	return result


static func _can_attack_from_cell(attacker: Unit, attacker_cell: Vector2i, defender_cell: Vector2i) -> bool:
	return attacker != null \
		and attacker.is_alive() \
		and attacker.can_attack_from_cell(attacker_cell, defender_cell)


func configure(random_source: RandomNumberGenerator) -> void:
	rng = random_source


func resolve(attacker: Unit, defender: Unit) -> void:
	if attacker == null or defender == null or not attacker.can_attack(defender):
		return

	var first: Unit = attacker
	var second: Unit = defender
	if defender.get_battle_speed() > attacker.get_battle_speed() and defender.can_attack(attacker):
		first = defender
		second = attacker

	if presentation != null:
		await presentation.begin(attacker, defender)
	await _perform_strike(first, second)
	if is_instance_valid(first) and is_instance_valid(second) and second.can_attack(first):
		await _perform_strike(second, first)
	if presentation != null:
		presentation.close()


func _perform_strike(attacker: Unit, defender: Unit) -> void:
	if attacker == null or defender == null or not attacker.can_attack(defender):
		return

	var hit_roll: int = rng.randi_range(1, 100) if rng != null else 1
	var hit := hit_roll <= attacker.get_hit_chance_against(defender)
	var is_critical := false
	if hit:
		var critical_roll: int = rng.randi_range(1, 100) if rng != null else 100
		is_critical = critical_roll <= attacker.get_critical_chance_against(defender)
	if presentation != null:
		await presentation.windup(attacker, defender, is_critical)
	else:
		await attacker.play_attack_animation(defender.global_position)
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return

	var damage := 0
	if hit:
		damage = defender.take_damage(attacker.get_physical_damage_against(defender, is_critical))
	if presentation != null:
		await presentation.impact(hit, damage)
	if is_instance_valid(defender) and not defender.is_alive():
		unit_defeated.emit(defender, attacker)
	combat_state_changed.emit()
