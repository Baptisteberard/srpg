extends Resource
class_name ArmorDefinition

@export var display_name: String = "No Armor"
@export var armor_type: StringName = &"None"
@export_multiline var description: String = ""
@export_range(0, 99, 1) var armor_value: int = 0
@export_range(0, 99, 1) var weight: int = 0
