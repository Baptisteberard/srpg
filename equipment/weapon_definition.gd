extends Resource
class_name WeaponDefinition

@export var display_name: String = "Unarmed"
@export var weapon_type: StringName = &"Unarmed"
@export_multiline var description: String = ""
@export_range(0, 99, 1) var damage: int = 0
@export_range(0, 99, 1) var weight: int = 0
@export_range(0, 100, 1) var base_hit: int = 90
@export_range(0, 100, 1) var base_crit: int = 5
@export_range(0, 99, 1) var healing_bonus: int = 0
@export_range(1, 10, 1) var minimum_range: int = 1
@export_range(1, 10, 1) var maximum_range: int = 1


func get_safe_minimum_range() -> int:
	return maxi(1, minimum_range)


func get_safe_maximum_range() -> int:
	return maxi(get_safe_minimum_range(), maximum_range)
