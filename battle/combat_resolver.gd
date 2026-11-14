extends RefCounted
class_name CombatResolver

signal unit_defeated(unit: Unit)
signal combat_state_changed

var rng: RandomNumberGenerator


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
			unit_defeated.emit(defender)
	combat_state_changed.emit()
